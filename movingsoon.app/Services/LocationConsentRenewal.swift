import Foundation
import UserNotifications

/// One date-based invitation per consent window. This never starts monitoring or
/// renews consent; its only action opens the in-app reminder controls.
enum LocationConsentRenewal {
    static let categoryIdentifier = "LocationConsentRenewal"
    static let reviewActionIdentifier = "REVIEW_LOCATION_RENEWAL"
    private static let prefix = "LocationConsentRenewal-"

    static func owns(_ identifier: String) -> Bool { identifier.hasPrefix(prefix) }

    private static func identifier(for move: Move) -> String? {
        guard let grant = move.locationConsentGrantedAt else { return nil }
        return "\(prefix)\(move.id.uuidString)-\(grant.timeIntervalSince1970)"
    }

    static func request(for move: Move, now: Date = Date(),
                        calendar: Calendar = .current) -> UNNotificationRequest? {
        guard let expiry = ReminderPolicy.consentExpiry(for: move, calendar: calendar),
              let identifier = identifier(for: move) else { return nil }
        // The existing consent gate includes the expiry instant. Round forward
        // and fire strictly afterwards, then respect the normal quiet hours.
        var fire = Date(timeIntervalSince1970: floor(expiry.timeIntervalSince1970) + 1)
        let hour = calendar.component(.hour, from: fire)
        if hour < 9 {
            fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: fire) ?? fire
        } else if hour >= 19 {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: fire),
                  let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) else { return nil }
            fire = morning
        }
        // A fixed date prevents reopening the app from creating repeated catch-up
        // alerts. Already-expired moves get the dashboard renewal prompt instead.
        guard fire > now,
              ReminderPolicy.shouldOfferConsentRenewal(for: move, now: fire, calendar: calendar) else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "Keep nearby reminders on?"
        content.body = "Your 30-day window ended and critical address updates remain. Open MovingSoon to choose another 30 days."
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["moveID": move.id.uuidString, "action": "reviewLocationConsent"]
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
        // Pin the consent deadline to an instant; travelling must not turn a
        // floating local calendar time into an alert before the window expires.
        components.timeZone = calendar.timeZone
        return UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }

    static func isRelevant(_ request: UNNotificationRequest, for move: Move?,
                           now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let move, request.identifier == identifier(for: move),
              request.content.userInfo["moveID"] as? String == move.id.uuidString else { return false }
        return ReminderPolicy.shouldOfferConsentRenewal(for: move, now: now, calendar: calendar)
    }
}
