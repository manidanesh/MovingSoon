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

    // MARK: - Injected dependencies

    /// Set by the dashboard after the Move is loaded from SwiftData.
    var move: Move?
    var cooldownStore = CooldownStore()
    var geofenceCoordinator = GeofenceCoordinator()
    var reminderService = SmartReminderService()

    // MARK: - Private

    private let manager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Request location updates so currentLocation stays fresh for the distance gate
        manager.startUpdatingLocation()
    }

    // MARK: - Permission request

    func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - CLLocationManagerDelegate — authorization

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Record consent date on the Move if not already set
            if let move, move.locationConsentGrantedAt == nil {
                move.locationConsentGrantedAt = Date()
            }
            // Sync geofences now that we have permission
            syncGeofencesIfActive()

        default:
            break
        }

        checkConsentExpiry()
    }

    // MARK: - CLLocationManagerDelegate — location updates

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    // MARK: - CLLocationManagerDelegate — geofence entry

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        guard let move else { return }
        guard let userLocation = currentLocation else {
            logger.debug("LocationManager: didEnterRegion fired but currentLocation is nil — suppressing")
            return
        }

        // Look up the task by region identifier (task.id.uuidString)
        guard let task = move.tasks.first(where: { $0.id.uuidString == circularRegion.identifier }),
              let poiCategory = task.poiCategory else {
            logger.debug("LocationManager: no matching task for region \(circularRegion.identifier)")
            return
        }

        let destinationCoordinate = ZipBucketService.centroid(zip: move.destinationZip)

        let context = SuppressionEngine.Context(
            move: move,
            poiCategory: poiCategory,
            cooldownStore: cooldownStore,
            now: Date(),
            userLocation: userLocation,
            destinationCoordinate: destinationCoordinate
        )

        guard SuppressionEngine.shouldFire(context: context) else {
            logger.debug("LocationManager: suppression engine blocked notification for \(poiCategory.rawValue)")
            return
        }

        // All gates passed — fire the notification and record the cooldown
        reminderService.fireLocationNotification(task: task, poiCategory: poiCategory)
        cooldownStore.record(category: poiCategory, date: Date())
        logger.debug("LocationManager: fired notification for \(poiCategory.rawValue)")
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

        let destinationCoordinate = ZipBucketService.centroid(zip: move.destinationZip)

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
    }
}
