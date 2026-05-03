// CooldownStore.swift — UserDefaults-backed per-POICategory notification cooldown
// Stores the last-fired Date for each POICategory. Max 1 notification per category per calendar day.
import Foundation

struct CooldownStore {

    private let defaults: UserDefaults
    private let storageKey = "com.movingsoon.cooldownStore"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Gate evaluation

    /// Returns true (gate passes) if no notification has been fired for this category today.
    func gatePasses(for category: POICategory, now: Date = Date()) -> Bool {
        guard let lastFired = lastFiredDate(for: category) else { return true }
        return !Calendar.current.isDate(lastFired, inSameDayAs: now)
    }

    // MARK: - Recording

    /// Records the current date for a category after a notification fires.
    mutating func record(category: POICategory, date: Date = Date()) {
        var dict = loadDictionary()
        dict[category.rawValue] = date
        saveDictionary(dict)
    }

    // MARK: - Clearing

    /// Clears all cooldown entries (used in tests and on consent revocation).
    mutating func clearAll() {
        defaults.removeObject(forKey: storageKey)
    }

    // MARK: - Private helpers

    private func lastFiredDate(for category: POICategory) -> Date? {
        loadDictionary()[category.rawValue]
    }

    private func loadDictionary() -> [String: Date] {
        guard let data = defaults.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func saveDictionary(_ dict: [String: Date]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
