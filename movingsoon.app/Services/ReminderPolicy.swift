import Foundation
import CoreLocation

enum ReminderPolicy {
    /// Only a customer action creates a new request. Authorization callbacks may
    /// consume it, but never move the start date forward on their own.
    static func beginConsentRequest(for move: Move, now: Date = Date()) {
        guard move.locationConsentStoppedAt != nil
            || !SuppressionEngine.consentExpiryGatePasses(grantedAt: move.locationConsentGrantedAt, now: now) else { return }
        move.locationConsentRequestedAt = now
    }

    @discardableResult
    static func recordRequestedConsent(for move: Move, status: CLAuthorizationStatus, now: Date = Date()) -> Bool {
        guard let requested = move.locationConsentRequestedAt,
              move.locationConsentGrantedAt.map({ requested > $0 }) ?? true,
              move.locationConsentStoppedAt.map({ requested > $0 }) ?? true,
              requested <= now, SuppressionEngine.consentExpiryGatePasses(grantedAt: requested, now: now),
              status == .authorizedAlways || status == .authorizedWhenInUse else { return false }
        move.locationConsentGrantedAt = requested
        move.locationConsentStoppedAt = nil
        return true
    }

    static func stopConsent(for move: Move, now: Date = Date()) {
        move.locationConsentStoppedAt = now
        move.locationConsentRequestedAt = nil
    }

    static func consentIsActive(for move: Move, now: Date = Date()) -> Bool {
        move.locationConsentStoppedAt == nil && move.phase == .active && move.lifestyleProfile != nil
            && SuppressionEngine.consentExpiryGatePasses(grantedAt: move.locationConsentGrantedAt, now: now)
    }

    static func consentExpiry(for move: Move, calendar: Calendar = .current) -> Date? {
        guard let grantedAt = move.locationConsentGrantedAt else { return nil }
        return calendar.date(byAdding: .day, value: 30, to: grantedAt)
    }

    /// An expired window may be offered again, but only an explicit customer
    /// action can create the request that starts another window.
    static func shouldOfferConsentRenewal(for move: Move, now: Date = Date(),
                                          calendar: Calendar = .current) -> Bool {
        guard move.phase == .active, move.lifestyleProfile != nil,
              move.locationConsentStoppedAt == nil,
              let expiry = consentExpiry(for: move, calendar: calendar), now > expiry else { return false }
        return move.tasks.contains { $0.priority == .critical && isEligible($0, at: now) }
    }

    static func isEligible(_ task: ChecklistTask, at date: Date = Date()) -> Bool {
        task.status == .toDo && !task.isMuted && task.needsLocationReview != true
            && (task.snoozedUntil.map { $0 <= date } ?? true)
    }

    static func showsConsent(grantedAt: Date?, status: CLAuthorizationStatus, dismissed: Bool) -> Bool {
        grantedAt == nil && !dismissed && status != .restricted
    }

    static func needsAlwaysUpgrade(grantedAt: Date?, status: CLAuthorizationStatus,
                                   dismissed: Bool, now: Date = Date()) -> Bool {
        !dismissed && status == .authorizedWhenInUse
            && SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now)
    }

    /// Captures every input that can invalidate scheduled reminders or monitored places.
    static func revision(for move: Move) -> String {
        let tasks = move.tasks.sorted { $0.id.uuidString < $1.id.uuidString }.map { task -> String in
            var fields: [String] = [task.id.uuidString, task.title, task.statusRaw, String(task.isMuted)]
            fields += [String(task.snoozedUntil?.timeIntervalSince1970 ?? 0), String(task.tMinusDays)]
            fields += [task.poiCategoryRaw ?? "", task.catalogItemID ?? "", task.institutionName ?? ""]
            fields += [task.priorityRaw, task.deepLinkURLString ?? "", String(task.needsLocationReview == true)]
            fields += [task.accountProviderName ?? "", task.accountNickname ?? "", String(task.reminderLeadDays)]
            fields += [String(task.nextShipmentDate?.timeIntervalSince1970 ?? 0),
                       String(task.nextRenewalDate?.timeIntervalSince1970 ?? 0),
                       String(task.absoluteDueDate?.timeIntervalSince1970 ?? 0)]
            fields += [task.nextShipmentDateOnly ?? "", task.nextRenewalDateOnly ?? "", task.absoluteDueDateOnly ?? ""]
            return fields.joined(separator: "|")
        }
        return [move.id.uuidString, move.destinationZip, String(move.effectiveAnchorDate.timeIntervalSince1970),
                String(move.destinationLatitude ?? 0), String(move.destinationLongitude ?? 0),
                String(move.locationConsentGrantedAt?.timeIntervalSince1970 ?? 0),
                String(move.locationConsentStoppedAt?.timeIntervalSince1970 ?? 0),
                move.phaseRaw, String(move.lifestyleProfile != nil)] .joined(separator: "|") + tasks.joined(separator: ";")
    }
}
