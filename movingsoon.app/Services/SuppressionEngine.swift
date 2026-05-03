// SuppressionEngine.swift — Stateless multi-gate evaluator for location notifications
// All six gates must pass before a notification is allowed to fire.
import Foundation
import CoreLocation

enum SuppressionEngine {

    // MARK: - Context

    struct Context {
        let move: Move
        let poiCategory: POICategory
        let cooldownStore: CooldownStore
        let now: Date
        let userLocation: CLLocation
        let destinationCoordinate: CLLocationCoordinate2D
    }

    // MARK: - Main evaluator

    /// Returns true only when all six gates pass (fail-fast order).
    static func shouldFire(context: Context) -> Bool {
        // 1. Consent expiry — cheapest check, no location math needed
        guard consentExpiryGatePasses(
            grantedAt: context.move.locationConsentGrantedAt,
            now: context.now
        ) else { return false }

        // 2. Completion — if move is mostly done, stop bothering the user
        guard completionGatePasses(fraction: context.move.completionFraction) else { return false }

        // 3. Time of day — no notifications outside 9am–7pm
        guard timeOfDayGatePasses(now: context.now) else { return false }

        // 4. Distance — user must be near the destination, not still at origin
        guard distanceGatePasses(
            userLocation: context.userLocation,
            destination: context.destinationCoordinate
        ) else { return false }

        // 5. Task relevance — must have a pending task for this POI type
        guard taskRelevanceGatePasses(
            tasks: context.move.tasks,
            category: context.poiCategory
        ) else { return false }

        // 6. Cooldown — max 1 notification per category per calendar day
        guard cooldownGatePasses(
            store: context.cooldownStore,
            category: context.poiCategory,
            now: context.now
        ) else { return false }

        return true
    }

    // MARK: - Individual gate evaluators (internal for testing)

    /// Gate 1: Consent must be granted and not expired (within 30 days).
    /// nil grantedAt → gate fails (no consent recorded = no monitoring).
    static func consentExpiryGatePasses(grantedAt: Date?, now: Date) -> Bool {
        guard let grantedAt else { return false }
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: grantedAt) ?? grantedAt
        return now <= expiryDate
    }

    /// Gate 2: Move must be less than 80% complete.
    static func completionGatePasses(fraction: Double) -> Bool {
        fraction < 0.80
    }

    /// Gate 3: Current time must be between 09:00 and 19:00 local time.
    static func timeOfDayGatePasses(now: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 9 && hour < 19
    }

    /// Gate 4: User must be within 8,000 metres of the destination coordinate.
    static func distanceGatePasses(
        userLocation: CLLocation,
        destination: CLLocationCoordinate2D
    ) -> Bool {
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        return userLocation.distance(from: destinationLocation) <= 8_000
    }

    /// Gate 5: At least one pending (.toDo) task must match the POI category.
    static func taskRelevanceGatePasses(
        tasks: [ChecklistTask],
        category: POICategory
    ) -> Bool {
        tasks.contains { $0.status == .toDo && $0.poiCategory == category }
    }

    /// Gate 6: No notification for this category has been fired today.
    static func cooldownGatePasses(
        store: CooldownStore,
        category: POICategory,
        now: Date
    ) -> Bool {
        store.gatePasses(for: category, now: now)
    }
}
