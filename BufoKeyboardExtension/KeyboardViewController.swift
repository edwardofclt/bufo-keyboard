import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?
    private var searchActive: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Start with loading state - don't access BufoCatalog yet to avoid blocking
        var root = KeyboardRootView(
            hasFullAccess: hasFullAccess,
            isLoaded: false
        )
        root.onSearchActiveChanged = { [weak self] active in
            guard let self else { return }
            self.searchActive = active
            self.applyKeyboardHeight()
        }

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

        // Defer catalog access until after the view is on screen
        DispatchQueue.main.async { [weak self] in
            if BufoCatalog.shared.isLoaded {
                withAnimation(.easeIn(duration: 0.15)) {
                    self?.hostingController?.rootView.isLoaded = true
                }
            } else {
                BufoCatalog.shared.onLoaded { [weak self] in
                    withAnimation(.easeIn(duration: 0.15)) {
                        self?.hostingController?.rootView.isLoaded = true
                    }
                }
            }
        }
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
        // When search is active, the mini-QWERTY adds ~165pt. Grow the keyboard
        // to keep enough room for the bufo grid above it.
        let isCompact = traitCollection.verticalSizeClass == .compact
        let baseHeight: CGFloat = isCompact ? 260 : 320
        let height = searchActive ? baseHeight + 170 : baseHeight
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
