import UIKit
import Messages

final class StickerPackViewController: MSStickerBrowserViewController, MSStickerBrowserViewDataSource {
    private var stickers: [MSSticker] = []
    private let catalog = BufoCatalog.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        stickerBrowserView.backgroundColor = UIColor.systemBackground
        stickerBrowserView.dataSource = self
        catalog.onLoaded { [weak self] in
            self?.beginNormalization()
        }
    }

    func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int {
        stickers.count
    }

    func stickerBrowserViewController(
        _ controller: MSStickerBrowserViewController,
        stickerAt index: Int
    ) -> MSSticker {
        stickers[index]
    }

    // Normalizes bufos on a background queue in batches, then appends to the
    // browser progressively. On first run each file is resized and written to
    // disk (~100ms each); on subsequent runs the cached file is reused (<1ms).
    private func beginNormalization() {
        let bufos = catalog.bufos
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var batch: [MSSticker] = []
            for bufo in bufos {
                guard
                    let url = StickerNormalizer.normalizedURL(for: bufo),
                    let sticker = try? MSSticker(
                        contentsOfFileURL: url,
                        localizedDescription: bufo.displayName
                    )
                else { continue }
                batch.append(sticker)
                if batch.count >= 20 {
                    let ready = batch
                    batch = []
                    DispatchQueue.main.async {
                        self?.stickers.append(contentsOf: ready)
                        self?.stickerBrowserView.reloadData()
                    }
                }
            }
            if !batch.isEmpty {
                let remaining = batch
                DispatchQueue.main.async {
                    self?.stickers.append(contentsOf: remaining)
                    self?.stickerBrowserView.reloadData()
                }
            }
        }
    }
}
