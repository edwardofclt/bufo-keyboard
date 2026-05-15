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
            Image(uiImage: UIImage(contentsOfFile: bufo.fileURL.path) ?? UIImage())
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fit)
        }
    }
}

private struct AnimatedImage: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        configure(view: view, force: true)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Only reload if the URL bound to this view actually changed — avoids
        // restarting the GIF every time the parent re-renders.
        if context.coordinator.url != url {
            context.coordinator.url = url
            configure(view: uiView, force: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator {
        var url: URL
        init(url: URL) { self.url = url }
    }

    private func configure(view: UIImageView, force: Bool) {
        if let animated = AnimatedImageCache.shared.image(for: url) {
            view.image = animated.poster
            view.animationImages = animated.frames
            view.animationDuration = animated.duration
            view.animationRepeatCount = 0
            if !view.isAnimating { view.startAnimating() }
        } else {
            view.image = UIImage(contentsOfFile: url.path)
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

    private final class CachedAnimation {
        let value: DecodedAnimation
        init(_ value: DecodedAnimation) { self.value = value }
    }

    init() {
        cache.countLimit = 64
    }

    func image(for url: URL) -> DecodedAnimation? {
        if let cached = cache.object(forKey: url as NSURL) { return cached.value }
        guard let decoded = Self.decode(url: url) else { return nil }
        cache.setObject(CachedAnimation(decoded), forKey: url as NSURL)
        return decoded
    }

    private static func decode(url: URL) -> DecodedAnimation? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [UIImage] = []
        frames.reserveCapacity(count)
        var totalDuration: TimeInterval = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
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
