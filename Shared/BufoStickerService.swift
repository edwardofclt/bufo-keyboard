import UIKit

/// Puts a bufo onto the system pasteboard so the user can paste it as an image
/// attachment / sticker in any app that accepts pasted images (Messages, Mail,
/// Notes, Slack, WhatsApp, Discord, Telegram, etc.).
///
/// We do *not* try to insert into the host app's text field directly — iOS
/// keyboard extensions cannot insert image attachments, only text. Pasting is
/// the only reliable cross-app path. Callers in the keyboard extension must
/// check `UIInputViewController.hasFullAccess` first; without Full Access the
/// system silently refuses pasteboard writes.
enum BufoStickerService {

    enum Result {
        case copied(Bufo)
        case failed
    }

    /// Copies bufo to pasteboard asynchronously. Completion called on main thread.
    static func copy(_ bufo: Bufo, completion: @escaping (Result) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: bufo.fileURL) else {
                DispatchQueue.main.async { completion(.failed) }
                return
            }

            // Write under the file's UTI so the host app's "Paste" picks up the
            // best representation. For animated GIFs we also attach a PNG poster
            // so apps that only accept stills still get something.
            var items: [String: Any] = [bufo.fileType.pasteboardUTI: data]
            if bufo.fileType.isAnimated, let png = UIImage(data: data)?.pngData() {
                items["public.png"] = png
            }

            DispatchQueue.main.async {
                UIPasteboard.general.setItems([items], options: [:])
                completion(.copied(bufo))
            }
        }
    }

    /// Synchronous version for callers that need immediate result (deprecated).
    @discardableResult
    static func copy(_ bufo: Bufo) -> Result {
        guard let data = try? Data(contentsOf: bufo.fileURL) else {
            return .failed
        }

        var items: [String: Any] = [bufo.fileType.pasteboardUTI: data]
        if bufo.fileType.isAnimated, let png = UIImage(data: data)?.pngData() {
            items["public.png"] = png
        }
        UIPasteboard.general.setItems([items], options: [:])
        return .copied(bufo)
    }
}
