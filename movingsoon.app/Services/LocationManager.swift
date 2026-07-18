// LocationManager.swift — Geofencing, location awareness, and smart suppression
import Foundation
import CoreLocation
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.movingsoon", category: "LocationManager")

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Public state

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var activeContextualTask: ChecklistTask?

    // MARK: - Injected dependencies

    /// Set by the dashboard after the Move is loaded from SwiftData.
    var move: Move?
    var cooldownStore = CooldownStore()
    var geofenceCoordinator = GeofenceCoordinator()
    var reminderService = SmartReminderService()

    // MARK: - Private

    private let manager = CLLocationManager()

    /// Guards the WhenInUse → Always escalation so it's only attempted once per grant,
    /// not every time authorizationStatus is re-read.
    private var hasRequestedAlwaysUpgrade = false

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Request location updates so currentLocation stays fresh for the distance gate
        manager.startUpdatingLocation()
    }

    // MARK: - Permission request

    /// Requests "When In Use" first. Apple's system prompt for "Always" only appears
    /// as a follow-up upgrade after a WhenInUse grant — asking for Always cold risks
    /// the OS silently granting WhenInUse only and never surfacing the upgrade dialog.
    func requestPermissions() {
        manager.requestWhenInUseAuthorization()
    }

    // MARK: - CLLocationManagerDelegate — authorization

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways:
            // Record consent date on the Move if not already set — the 30-day promise
            // in LocationConsentCard only makes sense once background geofencing can work.
            if let move, move.locationConsentGrantedAt == nil {
                move.locationConsentGrantedAt = Date()
            }
            // Sync geofences now that we have permission
            syncGeofencesIfActive()

        case .authorizedWhenInUse:
            // Escalate to Always so the system's upgrade dialog appears. Guarded to fire once.
            if !hasRequestedAlwaysUpgrade {
                hasRequestedAlwaysUpgrade = true
                manager.requestAlwaysAuthorization()
            }
            // Attempt sync anyway — it's a no-op until locationConsentGrantedAt is set.
            syncGeofencesIfActive()

        default:
            break
        }

        checkConsentExpiry()
    }

    // MARK: - CLLocationManagerDelegate — location updates

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        evaluateForegroundContext()
    }

    // MARK: - CLLocationManagerDelegate — geofence entry

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        guard let move else {
            logger.error("LocationManager: didEnterRegion fired but move is nil")
            return
        }
        guard let userLocation = currentLocation else {
            logger.debug("LocationManager: didEnterRegion fired but currentLocation is nil — suppressing")
            return
        }

        logger.debug("LocationManager: entered region \(circularRegion.identifier)")

        // Look up the task by region identifier (task.id.uuidString)
        guard let task = move.tasks.first(where: { $0.id.uuidString == circularRegion.identifier }),
              let poiCategory = task.poiCategory else {
            logger.debug("LocationManager: no matching task for region \(circularRegion.identifier)")
            return
        }

        logger.debug("LocationManager: matched task '\(task.title)' category '\(poiCategory.rawValue)'")

        let destinationCoordinate = move.destinationCoordinate ?? ZipBucketService.centroid(zip: move.destinationZip)

        let context = SuppressionEngine.Context(
            move: move,
            poiCategory: poiCategory,
            cooldownStore: cooldownStore,
            now: Date(),
            userLocation: userLocation,
            destinationCoordinate: destinationCoordinate
        )

        guard SuppressionEngine.shouldFire(context: context) else {
            logger.debug("LocationManager: suppression engine blocked notification for '\(poiCategory.rawValue)' — consent=\(move.locationConsentGrantedAt != nil) completion=\(move.completionFraction) hour=\(Calendar.current.component(.hour, from: Date()))")
            return
        }

        // All gates passed — fire the notification and record the cooldown
        reminderService.fireLocationNotification(task: task, poiCategory: poiCategory)
        cooldownStore.record(category: poiCategory, date: Date())
        logger.debug("LocationManager: ✅ fired notification for '\(poiCategory.rawValue)'")
    }

    // MARK: - CLLocationManagerDelegate — monitoring errors

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        logger.error("LocationManager: geofence monitoring failed for \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
    }

    // MARK: - Consent expiry

    /// Checks whether the 30-day consent window has expired and tears down geofences if so.
    func checkConsentExpiry() {
        guard let move else { return }
        guard let grantedAt = move.locationConsentGrantedAt else { return }

        let expired = !SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: Date())
        if expired {
            logger.debug("LocationManager: consent window expired — removing all geofences")
            geofenceCoordinator.removeAllGeofences(manager: manager)
            cooldownStore.clearAll()
        }
    }

    // MARK: - Geofence sync

    /// Syncs geofences if the consent window is active and we have a move loaded.
    func syncGeofencesIfActive() {
        guard let move else { return }
        guard let grantedAt = move.locationConsentGrantedAt,
              SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: Date()) else { return }

        // Resolve destination coordinate — prefer geocoded, fall back to ZIP centroid
        let destinationCoordinate = move.destinationCoordinate
            ?? ZipBucketService.centroid(zip: move.destinationZip)

        Task {
            await geofenceCoordinator.syncGeofences(
                for: move.tasks,
                destinationCoordinate: destinationCoordinate,
                manager: manager
            )
        }
    }

    /// Called when a task's status changes to completed or pendingVerification
    /// so its geofence is removed immediately.
    func taskStatusDidChange(_ task: ChecklistTask) {
        guard task.status == .completed || task.status == .pendingVerification else { return }
        geofenceCoordinator.removeGeofence(for: task, manager: manager)
        if activeContextualTask?.id == task.id {
            activeContextualTask = nil
        }
    }

    // MARK: - Foreground Context Evaluator

    func evaluateForegroundContext(now: Date = Date()) {
        guard let move else {
            activeContextualTask = nil
            return
        }
        guard let userLocation = currentLocation else {
            activeContextualTask = nil
            return
        }

        let destinationCoordinate = move.destinationCoordinate ?? ZipBucketService.centroid(zip: move.destinationZip)

        for region in manager.monitoredRegions {
            guard let circularRegion = region as? CLCircularRegion else { continue }
            guard circularRegion.contains(userLocation.coordinate) else { continue }

            guard let task = move.tasks.first(where: { $0.id.uuidString == circularRegion.identifier }),
                  let poiCategory = task.poiCategory else { continue }

            let context = SuppressionEngine.Context(
                move: move,
                poiCategory: poiCategory,
                cooldownStore: cooldownStore,
                now: now,
                userLocation: userLocation,
                destinationCoordinate: destinationCoordinate
            )

            if SuppressionEngine.shouldFire(context: context) {
                activeContextualTask = task
                return
            }
        }

        activeContextualTask = nil
    }
}
