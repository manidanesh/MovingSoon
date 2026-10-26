// NotificationBudget.swift — a daily cap for immediate nearby reminders
import Foundation

/// Date reminders are scheduled separately by iOS. A morning check-in must not
/// disable nearby reminders, and clearing Notification Center must not reset this
/// limit. Count successful nearby submissions in persistent local-day storage.
enum NotificationBudget {
    static let maximumNearbyPerDay = 2
    private static let countKey = "com.movingsoon.notificationBudget.count"
    private static let dayKey = "com.movingsoon.notificationBudget.day"

    /// True if firing one more immediate (geofence/visit) notification today would
    /// stay within budget.
    static func hasRoomToday(defaults: UserDefaults = .standard, now: Date = Date(),
                             calendar: Calendar = .current) async -> Bool {
        remainingToday(defaults: defaults, now: now, calendar: calendar) > 0
    }

    static func remainingToday(defaults: UserDefaults = .standard, now: Date = Date(),
                               calendar: Calendar = .current) -> Int {
        max(0, maximumNearbyPerDay - countToday(defaults: defaults, now: now, calendar: calendar))
    }

    /// Call after iOS accepts an immediate (geofence/visit) notification request.
    static func recordFired(defaults: UserDefaults = .standard, now: Date = Date(),
                            calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        if let storedDay = defaults.object(forKey: dayKey) as? Date,
           calendar.isDate(storedDay, inSameDayAs: today) {
            defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        } else {
            defaults.set(today, forKey: dayKey)
            defaults.set(1, forKey: countKey)
        }
    }

    private static func countToday(defaults: UserDefaults, now: Date, calendar: Calendar) -> Int {
        guard let storedDay = defaults.object(forKey: dayKey) as? Date,
              calendar.isDate(storedDay, inSameDayAs: now) else { return 0 }
        return max(0, defaults.integer(forKey: countKey))
    }
}
