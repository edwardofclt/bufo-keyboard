import UIKit
import Messages
import SwiftUI

final class MessagesViewController: MSMessagesAppViewController {

    private var hostingController: UIHostingController<MessagesRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let root = MessagesRootView(
            onSelectBufo: { [weak self] bufo in
                self?.sendBufo(bufo)
            },
            onRequestExpand: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )

        let host = UIHostingController(rootView: root)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        self.hostingController = host
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        hostingController?.rootView.isExpanded = (presentationStyle == .expanded)
    }

    private func sendBufo(_ bufo: Bufo) {
        guard let conversation = activeConversation else { return }

        // Normalize on a background thread — decoding and re-encoding GIF
        // frames is too slow for the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let normalizedURL = StickerNormalizer.normalizedURL(for: bufo) else {
                print("Failed to normalize bufo: \(bufo.id)")
                return
            }

            DispatchQueue.main.async {
                do {
                    let sticker = try MSSticker(contentsOfFileURL: normalizedURL,
                                                localizedDescription: bufo.displayName)
                    conversation.insert(sticker) { error in
                        if let error = error {
                            print("Failed to insert sticker: \(error)")
                        }
                    }
                    RecentsStore.shared.record(bufo)
                    self?.requestPresentationStyle(.compact)
                } catch {
                    print("Failed to create sticker: \(error)")
                }
            }
        }
    }
}
