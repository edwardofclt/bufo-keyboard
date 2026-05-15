import Foundation

/// Tracks recently-used bufos so the keyboard can show them at the top.
/// Stored in the standard UserDefaults of the calling process; the main app
/// and the extension each maintain their own list (no App Group required to
/// ship). If you set up an App Group, swap `UserDefaults.standard` for
/// `UserDefaults(suiteName: "group.fun.bufo.BufoKeyboard")` and recents will
/// be shared.
final class RecentsStore {
    static let shared = RecentsStore()

    private let key = "fun.bufo.BufoKeyboard.recents"
    private let limit = 32
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var recentIDs: [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func record(_ bufo: Bufo) {
        var ids = recentIDs.filter { $0 != bufo.id }
        ids.insert(bufo.id, at: 0)
        if ids.count > limit { ids = Array(ids.prefix(limit)) }
        defaults.set(ids, forKey: key)
    }

    func recents(from catalog: BufoCatalog) -> [Bufo] {
        recentIDs.compactMap { catalog.bufo(id: $0) }
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
