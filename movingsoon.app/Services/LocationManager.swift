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
        // Without a distanceFilter, didUpdateLocations fires on every GPS delta — in a
        // moving vehicle that's many times a second, each one re-evaluating
        // activeContextualTask (an @Observable property ZenDashboardView reads directly
        // in body), forcing a full re-render of an image-heavy view every tick. 50m is
        // well below the suppression engine's 8000m distance gate, so gating accuracy
        // is unaffected — this only throttles how often we recompute.
        manager.distanceFilter = 50
        // Deliberately NOT starting continuous updates here. Geofence entry (didEnterRegion)
        // is delivered by region monitoring regardless of whether startUpdatingLocation is
        // running, including when the app is suspended or not running — that's the whole
        // point of CLCircularRegion monitoring. Continuous updates are only useful for the
        // foreground "you're near a task right now" banner, so they're started/stopped by
        // the dashboard as it appears/disappears (see startForegroundUpdates/stop below).
        // This keeps the app off the "location" UIBackgroundModes entry entirely — no
        // persistent background GPS, no blue-pill indicator, less battery drain.
    }

    // MARK: - Foreground location updates

    /// Starts continuous updates for the foreground "near a relevant place right now" banner.
    /// Call when the dashboard becomes active; pair with `stopForegroundUpdates()`.
    func startForegroundUpdates() {
        manager.startUpdatingLocation()
    }

    /// Stops continuous updates. Geofence entries still fire via region monitoring even
    /// after this — only the foreground banner's live distance check is affected.
    func stopForegroundUpdates() {
        manager.stopUpdatingLocation()
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
        // Prefer a live fix, but fall back to the region's own center — didEnterRegion firing
        // already proves we're within its radius, and GeofenceCoordinator only ever places
        // regions near the destination, so the center is a sound stand-in for the distance
        // gate below. currentLocation depends on continuous updates, which the OS pauses in
        // the background; without this fallback, a geofence entry while backgrounded (the
        // actual real-world case this feature exists for) could silently no-op.
        let userLocation = currentLocation ?? CLLocation(
            latitude: circularRegion.center.latitude,
            longitude: circularRegion.center.longitude
        )

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
