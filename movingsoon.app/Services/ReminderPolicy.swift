import Foundation
import CoreLocation

enum ReminderPolicy {
    @discardableResult
    static func recordRequestedConsent(for move: Move, status: CLAuthorizationStatus, now: Date = Date()) -> Bool {
        guard move.locationConsentGrantedAt == nil, let requested = move.locationConsentRequestedAt,
              requested <= now, SuppressionEngine.consentExpiryGatePasses(grantedAt: requested, now: now),
              status == .authorizedAlways || status == .authorizedWhenInUse else { return false }
        move.locationConsentGrantedAt = requested
        return true
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
            return fields.joined(separator: "|")
        }
        return [move.id.uuidString, move.destinationZip, String(move.anchorDate.timeIntervalSince1970),
                String(move.destinationLatitude ?? 0), String(move.destinationLongitude ?? 0),
                String(move.locationConsentGrantedAt?.timeIntervalSince1970 ?? 0),
                move.phaseRaw, String(move.lifestyleProfile != nil)] .joined(separator: "|") + tasks.joined(separator: ";")
    }
}
