import Foundation

/// A single bufo sticker.
struct Bufo: Hashable, Identifiable, Sendable {
    let id: String
    let fileType: FileType
    let tags: [String]
    let fileURL: URL

    enum FileType: String, Hashable, Sendable {
        case png
        case gif
        case jpg
        case jpeg

        init?(extension ext: String) {
            switch ext.lowercased() {
            case "png": self = .png
            case "gif": self = .gif
            case "jpg": self = .jpg
            case "jpeg": self = .jpeg
            default: return nil
            }
        }

        /// Uniform Type Identifier used when writing to the pasteboard.
        var pasteboardUTI: String {
            switch self {
            case .png:  return "public.png"
            case .gif:  return "com.compuserve.gif"
            case .jpg, .jpeg: return "public.jpeg"
            }
        }

        var isAnimated: Bool { self == .gif }
    }

    /// Title shown to the user. Converts "bufo-thumbs-up" → "Bufo Thumbs Up".
    var displayName: String {
        id.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Words used for free-text search: id + tags.
    var searchText: String {
        (id + " " + tags.joined(separator: " "))
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }
}
