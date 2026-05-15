import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        let root = KeyboardRootView(
            hasFullAccess: hasFullAccess,
            onAdvance: { [weak self] in self?.advanceToNextInputMode() },
            onBackspace: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            onInsertText: { [weak self] text in self?.textDocumentProxy.insertText(text) }
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyKeyboardHeight()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        applyKeyboardHeight()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Re-read hasFullAccess on every appearance — the user might have just
        // toggled it in Settings.
        hostingController?.rootView.hasFullAccess = hasFullAccess
    }

    private func applyKeyboardHeight() {
        let height: CGFloat = traitCollection.verticalSizeClass == .compact ? 260 : 320
        if let existing = heightConstraint {
            existing.constant = height
        } else {
            let c = view.heightAnchor.constraint(equalToConstant: height)
            c.priority = .defaultHigh
            c.isActive = true
            heightConstraint = c
        }
    }
}
