import Foundation

/// Tracks recently-used bufos. Stored in the shared App Group container so the
/// main app, keyboard extension, and iMessage extension all see the same list —
/// tapping a bufo in any surface populates the keyboard's Recent tab next time
/// it's used. Falls back to standard defaults if the App Group isn't
/// provisioned (e.g. development builds without entitlements).
final class RecentsStore {
    static let shared = RecentsStore()

    /// Must match the value declared in every target's .entitlements file.
    static let appGroupID = "group.com.edwardofclt.bufoKeyboard"

    private let key = "com.edwardofclt.bufoKeyboard.recents"
    private let limit = 32
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: RecentsStore.appGroupID) ?? .standard) {
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
