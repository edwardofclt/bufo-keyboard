import Foundation

/// Loads the bundled bufo collection. Uses a compile-time generated index
/// (GeneratedBufoIndex) to avoid runtime file scanning and JSON parsing.
/// Bundled image files live in each target's Resources folder under `Bufos/`.
final class BufoCatalog: @unchecked Sendable {
    static let shared = BufoCatalog()

    private(set) var bufos: [Bufo] = []
    private(set) var allTags: [String] = []
    private(set) var bufosByTag: [String: [Bufo]] = [:]
    private(set) var isLoaded: Bool = false
    private var index: [String: Bufo] = [:]
    private var loadCallbacks: [() -> Void] = []
    private let lock = NSLock()

    private init() {
        // Load asynchronously to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.load()
        }
    }

    func bufo(id: String) -> Bufo? { index[id] }

    /// Bufos for a specific tag. O(1) lookup using precomputed index.
    func bufos(forTag tag: String) -> [Bufo] {
        bufosByTag[tag] ?? []
    }

    /// Call this to be notified when loading completes. If already loaded, callback fires immediately.
    func onLoaded(_ callback: @escaping () -> Void) {
        lock.lock()
        if isLoaded {
            lock.unlock()
            DispatchQueue.main.async { callback() }
        } else {
            loadCallbacks.append(callback)
            lock.unlock()
        }
    }

    func search(query: String, tag: String? = nil) -> [Bufo] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source: [Bufo]
        if let tag {
            source = bufosByTag[tag] ?? []
        } else {
            source = bufos
        }
        if q.isEmpty { return source }
        return source.filter { $0.searchText.contains(q) }
    }

    private func load() {
        let bundle = Bundle(for: BufoCatalog.self)

        // Resolve bundle URL once. Falls back to main bundle if not found
        // (e.g. when running in the host app target).
        let bufosDir = bundle.url(forResource: "Bufos", withExtension: nil)
            ?? Bundle.main.url(forResource: "Bufos", withExtension: nil)

        var loaded: [Bufo] = []
        loaded.reserveCapacity(GeneratedBufoIndex.entries.count)
        var indexMap: [String: Bufo] = [:]
        indexMap.reserveCapacity(GeneratedBufoIndex.entries.count)
        var tagBuckets: [String: [Bufo]] = [:]

        for entry in GeneratedBufoIndex.entries {
            guard let fileType = Bufo.FileType(extension: entry.ext) else { continue }
            // Build URL directly from known filename — no directory enumeration.
            let fileURL: URL
            if let dir = bufosDir {
                fileURL = dir.appendingPathComponent("\(entry.id).\(entry.ext)")
            } else if let url = bundle.url(forResource: entry.id, withExtension: entry.ext, subdirectory: "Bufos") {
                fileURL = url
            } else {
                continue
            }

            let bufo = Bufo(id: entry.id, fileType: fileType, tags: entry.tags, fileURL: fileURL)
            loaded.append(bufo)
            indexMap[entry.id] = bufo
            for tag in entry.tags {
                tagBuckets[tag, default: []].append(bufo)
            }
        }

        let tags = GeneratedBufoIndex.allTags

        // Update on main thread and notify callbacks
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bufos = loaded
            self.allTags = tags
            self.bufosByTag = tagBuckets
            self.index = indexMap

            self.lock.lock()
            self.isLoaded = true
            let callbacks = self.loadCallbacks
            self.loadCallbacks = []
            self.lock.unlock()

            for callback in callbacks {
                callback()
            }
        }
    }
}
