// NotificationBudget.swift — a soft daily cap across ALL notification channels combined
import Foundation
import UserNotifications

/// `SuppressionEngine`'s cooldown gate caps firing *per POI category*, but nothing
/// previously stopped a geofence hit and a visit-triggered hit (different categories)
/// from both firing the same day, on top of whatever the hero/digest channels already
/// sent. This is only enforceable for the two channels fired by our own code at the
/// moment of delivery (geofence entry, visit match) — the hero and T-minus digest
/// channels are pre-scheduled via `UNCalendarNotificationTrigger` and delivered by the
/// OS with no app code running at delivery time to consult this budget. So this also
/// checks already-delivered notifications for today, to avoid piling a third
/// immediate notification on top of a hero/digest that already landed.
enum NotificationBudget {
    private static let maxImmediatePerDay = 2
    private static let countKey = "com.movingsoon.notificationBudget.count"
    private static let dayKey = "com.movingsoon.notificationBudget.day"

    /// True if firing one more immediate (geofence/visit) notification today would
    /// stay within budget.
    static func hasRoomToday(defaults: UserDefaults = .standard) async -> Bool {
        guard countToday(defaults: defaults) < maxImmediatePerDay else { return false }

        let today = Date()
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let heroOrDigestAlreadyDeliveredToday = delivered.contains { notification in
            Calendar.current.isDate(notification.date, inSameDayAs: today) &&
            (notification.request.identifier == "HeroTaskReminder" ||
             notification.request.identifier == "HeroTaskReminderEvening" ||
             notification.request.identifier.hasPrefix("Hero-") ||
             notification.request.identifier.hasPrefix("Digest-"))
        }
        return !heroOrDigestAlreadyDeliveredToday
    }

    /// Call immediately after an immediate (geofence/visit) notification is actually fired.
    static func recordFired(defaults: UserDefaults = .standard) {
        let today = Calendar.current.startOfDay(for: Date())
        if let storedDay = defaults.object(forKey: dayKey) as? Date,
           Calendar.current.isDate(storedDay, inSameDayAs: today) {
            defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        } else {
            defaults.set(today, forKey: dayKey)
            defaults.set(1, forKey: countKey)
        }
    }

    private static func countToday(defaults: UserDefaults) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        guard let storedDay = defaults.object(forKey: dayKey) as? Date,
              Calendar.current.isDate(storedDay, inSameDayAs: today) else { return 0 }
        return defaults.integer(forKey: countKey)
    }
}
