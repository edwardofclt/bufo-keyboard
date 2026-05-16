import SwiftUI
import UIKit
import ImageIO

/// Displays a bufo image. Static PNG/JPEG renders through SwiftUI's Image;
/// animated GIFs go through a UIImageView wrapper that decodes frames with
/// ImageIO so animation plays in the grid.
struct BufoImageView: View {
    let bufo: Bufo

    var body: some View {
        if bufo.fileType.isAnimated {
            AnimatedImage(url: bufo.fileURL)
        } else {
            CachedStaticImage(bufo: bufo)
        }
    }
}

/// Loads and displays a static image using the shared thumbnail cache.
private struct CachedStaticImage: View {
    let bufo: Bufo
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: bufo.id) {
            image = await ThumbnailCache.shared.thumbnail(for: bufo.fileURL)
        }
    }
}

/// Cache for downsampled static image thumbnails. Loads images at display size
/// to reduce memory and improve scroll performance.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, UIImage>()
    private let thumbnailSize: CGFloat = 128 // 64pt * 2x scale

    init() {
        cache.countLimit = 256
        // ~8 MB ceiling. The keyboard extension's 70 MB process cap means
        // we'd rather evict aggressively than risk being killed.
        cache.totalCostLimit = 8 * 1024 * 1024
    }

    func thumbnail(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                let thumbnail = self.loadThumbnail(from: url)
                if let thumbnail {
                    self.cache.setObject(thumbnail, forKey: url as NSURL, cost: byteCost(of: thumbnail))
                }
                continuation.resume(returning: thumbnail)
            }
        }
    }

    func purge() {
        cache.removeAllObjects()
    }

    private func loadThumbnail(from url: URL) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            // Fallback to standard loading if thumbnail creation fails
            return UIImage(contentsOfFile: url.path)
        }

        return UIImage(cgImage: cgImage)
    }
}

/// Decoded-RGBA byte cost approximation for NSCache eviction.
private func byteCost(of image: UIImage) -> Int {
    guard let cg = image.cgImage else { return 0 }
    return cg.width * cg.height * 4
}

/// Drops every decoded image held in memory. Call in response to
/// `didReceiveMemoryWarning` — the keyboard extension is killed silently
/// if it exceeds the ~70 MB process cap, so reclaim aggressively.
func purgeBufoImageCaches() {
    ThumbnailCache.shared.purge()
    AnimatedImageCache.shared.purge()
}

private struct AnimatedImage: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.15)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        loadAnimation(into: view, url: url)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Only reload if the URL bound to this view actually changed — avoids
        // restarting the GIF every time the parent re-renders.
        if context.coordinator.url != url {
            context.coordinator.url = url
            loadAnimation(into: uiView, url: url)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator {
        var url: URL
        init(url: URL) { self.url = url }
    }

    private func loadAnimation(into view: UIImageView, url: URL) {
        // Check cache first (fast path)
        if let animated = AnimatedImageCache.shared.cachedImage(for: url) {
            applyAnimation(animated, to: view)
            return
        }

        // Decode in background
        DispatchQueue.global(qos: .userInitiated).async {
            let animated = AnimatedImageCache.shared.image(for: url)
            DispatchQueue.main.async {
                if let animated {
                    applyAnimation(animated, to: view)
                }
            }
        }
    }

    private func applyAnimation(_ animated: DecodedAnimation, to view: UIImageView) {
        view.backgroundColor = .clear
        view.image = animated.poster
        view.animationImages = animated.frames
        view.animationDuration = animated.duration
        view.animationRepeatCount = 0
        // Respect the Reduce Motion accessibility setting — show only the
        // poster frame instead of looping. The poster is already set above,
        // so simply skipping startAnimating() leaves the static image visible.
        if !UIAccessibility.isReduceMotionEnabled && !view.isAnimating {
            view.startAnimating()
        }
    }
}

private struct DecodedAnimation {
    let frames: [UIImage]
    let duration: TimeInterval
    let poster: UIImage
}

private final class AnimatedImageCache {
    static let shared = AnimatedImageCache()
    private let cache = NSCache<NSURL, CachedAnimation>()

    /// Per-frame decode size. Matches `ThumbnailCache.thumbnailSize` — cells
    /// render at 48–56pt @2x, so 128px gives some headroom without wasting
    /// memory. A typical native-resolution GIF frame is ~17× larger.
    private static let frameThumbnailSize: CGFloat = 128

    private final class CachedAnimation {
        let value: DecodedAnimation
        init(_ value: DecodedAnimation) { self.value = value }
    }

    init() {
        // Animated entries are heavy (each holds N decoded frames), so the
        // count limit is far lower than the static cache. The cost ceiling
        // is the real bound; count guards against pathological many-tiny.
        cache.countLimit = 64
        // ~16 MB ceiling. With 128×128 RGBA frames (~64 KB each), this lets
        // ~256 frames total live in cache before eviction kicks in. The
        // keyboard extension's 70 MB process cap is the constraint.
        cache.totalCostLimit = 16 * 1024 * 1024
    }

    /// Returns cached animation if available, nil otherwise. Does not decode.
    func cachedImage(for url: URL) -> DecodedAnimation? {
        cache.object(forKey: url as NSURL)?.value
    }

    /// Returns animation, decoding and caching if needed. Call from background thread.
    func image(for url: URL) -> DecodedAnimation? {
        if let cached = cache.object(forKey: url as NSURL) { return cached.value }
        guard let decoded = Self.decode(url: url) else { return nil }
        cache.setObject(CachedAnimation(decoded), forKey: url as NSURL, cost: cost(of: decoded))
        return decoded
    }

    func purge() {
        cache.removeAllObjects()
    }

    private func cost(of animation: DecodedAnimation) -> Int {
        byteCost(of: animation.poster) * animation.frames.count
    }

    private static func decode(url: URL) -> DecodedAnimation? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        // Decode each frame at thumbnail size instead of native resolution.
        // CGImageSourceCreateThumbnailAtIndex respects the index parameter for
        // animated sources, so each GIF frame is downsampled independently.
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: frameThumbnailSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        var frames: [UIImage] = []
        frames.reserveCapacity(count)
        var totalDuration: TimeInterval = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, i, options as CFDictionary) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            totalDuration += frameDuration(source: source, index: i)
        }

        guard let poster = frames.first else { return nil }
        if totalDuration <= 0 { totalDuration = Double(frames.count) * 0.1 }

        return DecodedAnimation(frames: frames, duration: totalDuration, poster: poster)
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let unclamped = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? 0
        let clamped = (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0
        let value = unclamped > 0 ? unclamped : clamped
        return value > 0.01 ? value : 0.1
    }
}
