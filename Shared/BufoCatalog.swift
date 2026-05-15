import Foundation

/// Loads the bundled bufo collection. Bundled in each target's Resources folder
/// under `Bufos/` alongside `bufo-data.json`.
final class BufoCatalog: @unchecked Sendable {
    static let shared = BufoCatalog()

    private(set) var bufos: [Bufo] = []
    private(set) var allTags: [String] = []
    private var index: [String: Bufo] = [:]

    private init() {
        load()
    }

    func bufo(id: String) -> Bufo? { index[id] }

    func search(query: String, tag: String? = nil) -> [Bufo] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return bufos.filter { b in
            if let tag, !b.tags.contains(tag) { return false }
            if q.isEmpty { return true }
            return b.searchText.contains(q)
        }
    }

    private func load() {
        let bundle = Bundle(for: BufoCatalog.self)

        let dataMap = loadDataMap(in: bundle)

        guard let bufosDirURL = bundle.url(forResource: "Bufos", withExtension: nil)
                ?? Bundle.main.url(forResource: "Bufos", withExtension: nil) else {
            assertionFailure("Bufos/ directory missing from bundle")
            return
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: bufosDirURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        var loaded: [Bufo] = []
        loaded.reserveCapacity(files.count)
        var tagSet = Set<String>()

        for url in files {
            let ext = url.pathExtension
            guard let fileType = Bufo.FileType(extension: ext) else { continue }
            let id = url.deletingPathExtension().lastPathComponent
            let tags = dataMap[id] ?? []
            tagSet.formUnion(tags)
            loaded.append(Bufo(id: id, fileType: fileType, tags: tags, fileURL: url))
        }

        loaded.sort { $0.id < $1.id }
        self.bufos = loaded
        self.allTags = tagSet.sorted()
        self.index = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
    }

    private func loadDataMap(in bundle: Bundle) -> [String: [String]] {
        guard let url = bundle.url(forResource: "bufo-data", withExtension: "json")
                ?? Bundle.main.url(forResource: "bufo-data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }

        struct BufoData: Decodable {
            struct Entry: Decodable {
                let id: String
                let tags: [String]?
            }
            let bufos: [Entry]
        }

        guard let decoded = try? JSONDecoder().decode(BufoData.self, from: data) else {
            return [:]
        }
        var map: [String: [String]] = [:]
        map.reserveCapacity(decoded.bufos.count)
        for entry in decoded.bufos {
            map[entry.id] = entry.tags ?? []
        }
        return map
    }
}
