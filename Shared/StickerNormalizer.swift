import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Normalizes bufo sticker files to a consistent pixel size before handing them
/// to MSSticker. Without this, source PNGs/GIFs of varying pixel dimensions
/// render at wildly different sizes in iMessage (anything below 100px renders
/// tiny, large source images render at the full ~408px cap).
///
/// Normalized files are written to a per-launch cache directory and reused on
/// repeat sends of the same bufo.
enum StickerNormalizer {

    /// Apple's recommended max sticker pixel dimension. We resize so the
    /// longest edge equals this value (preserving aspect ratio), then pad
    /// to a square so every bufo ends up the same on-disk size and renders
    /// identically in the conversation.
    static let targetEdge: CGFloat = 408

    /// Returns a URL to a normalized sticker file suitable for
    /// `MSSticker(contentsOfFileURL:)`. Safe to call from any thread; does
    /// disk I/O so prefer a background queue. Returns nil if decoding fails.
    static func normalizedURL(for bufo: Bufo) -> URL? {
        let cacheURL = cacheURL(for: bufo)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            return cacheURL
        }
        do {
            if bufo.fileType.isAnimated {
                try normalizeAnimated(source: bufo.fileURL, destination: cacheURL)
            } else {
                try normalizeStatic(source: bufo.fileURL, destination: cacheURL)
            }
            return cacheURL
        } catch {
            // Clean up partial files so the next attempt can retry from scratch.
            try? FileManager.default.removeItem(at: cacheURL)
            return nil
        }
    }

    // MARK: - Cache

    private static let cacheDir: URL = {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("NormalizedStickers", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private static func cacheURL(for bufo: Bufo) -> URL {
        let ext = bufo.fileType.isAnimated ? "gif" : "png"
        return cacheDir.appendingPathComponent("\(bufo.id)-\(Int(targetEdge)).\(ext)")
    }

    // MARK: - Static (PNG / JPEG)

    private enum NormalizeError: Error { case decodeFailed, encodeFailed }

    private static func normalizeStatic(source: URL, destination: URL) throws {
        guard let image = UIImage(contentsOfFile: source.path) else {
            throw NormalizeError.decodeFailed
        }
        let canvas = CGSize(width: targetEdge, height: targetEdge)
        let drawRect = aspectFitRect(for: image.size, in: canvas)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        let resized = renderer.image { _ in
            image.draw(in: drawRect)
        }
        guard let data = resized.pngData() else {
            throw NormalizeError.encodeFailed
        }
        try data.write(to: destination, options: .atomic)
    }

    // MARK: - Animated (GIF)

    private static func normalizeAnimated(source: URL, destination: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw NormalizeError.decodeFailed
        }
        let count = CGImageSourceGetCount(imageSource)
        guard count > 0 else { throw NormalizeError.decodeFailed }

        // Loop count is a top-level GIF property. Default to 0 (loop forever).
        let sourceProps = CGImageSourceCopyProperties(imageSource, nil) as? [CFString: Any]
        let sourceGIF = sourceProps?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let loopCount = (sourceGIF?[kCGImagePropertyGIFLoopCount] as? Int) ?? 0

        let destProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: loopCount
            ] as [CFString: Any]
        ]

        let gifUTI = UTType.gif.identifier as CFString
        guard let dest = CGImageDestinationCreateWithURL(destination as CFURL, gifUTI, count, nil) else {
            throw NormalizeError.encodeFailed
        }
        CGImageDestinationSetProperties(dest, destProps as CFDictionary)

        let canvas = CGSize(width: targetEdge, height: targetEdge)
        let canvasW = Int(canvas.width)
        let canvasH = Int(canvas.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // premultipliedLast = RGBA. Required for transparency in GIFs.
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        for i in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(imageSource, i, nil) else { continue }

            let frameSize = CGSize(width: frame.width, height: frame.height)
            let drawRect = aspectFitRect(for: frameSize, in: canvas)

            guard let ctx = CGContext(
                data: nil,
                width: canvasW,
                height: canvasH,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { continue }

            ctx.interpolationQuality = .medium
            ctx.clear(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
            ctx.draw(frame, in: drawRect)
            guard let resized = ctx.makeImage() else { continue }

            // Preserve per-frame delay. Prefer the unclamped value (the real
            // authored delay); fall back to clamped, then a safe default.
            let frameProps = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as? [CFString: Any]
            let frameGIF = frameProps?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclamped = (frameGIF?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? 0
            let clamped = (frameGIF?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0
            let delay = unclamped > 0 ? unclamped : (clamped > 0 ? clamped : 0.1)

            let frameDestProps: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFUnclampedDelayTime: delay,
                    kCGImagePropertyGIFDelayTime: delay
                ] as [CFString: Any]
            ]
            CGImageDestinationAddImage(dest, resized, frameDestProps as CFDictionary)
        }

        guard CGImageDestinationFinalize(dest) else {
            throw NormalizeError.encodeFailed
        }
    }

    // MARK: - Geometry

    /// Returns the rect inside `canvas` that `size` should be drawn into,
    /// preserving aspect ratio and centering. Handles upscaling so small
    /// source images grow to fill the sticker frame instead of staying tiny.
    private static func aspectFitRect(for size: CGSize, in canvas: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: canvas)
        }
        let scale = min(canvas.width / size.width, canvas.height / size.height)
        let w = (size.width * scale).rounded()
        let h = (size.height * scale).rounded()
        let x = ((canvas.width - w) * 0.5).rounded()
        let y = ((canvas.height - h) * 0.5).rounded()
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
