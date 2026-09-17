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
    var move: Move? {
        didSet {
            // Closes a real startup race: didEnterRegion (and didVisit) can fire before
            // this is set — confirmed live, logged as "didEnterRegion fired but move is
            // nil" — most plausibly exactly when the OS relaunches the app in the
            // background because of the very region crossing this feature exists to
            // catch. That event used to be silently dropped with no way to recover it.
            // requestState(for:) is CoreLocation's own sanctioned way to ask "am I
            // currently inside this region right now" — if the answer is yes, the user
            // likely hasn't left since the dropped entry, so didDetermineState below
            // reprocesses it as a fresh entry.
            if oldValue == nil, move != nil {
                for region in manager.monitoredRegions {
                    manager.requestState(for: region)
                }
            }
        }
    }
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
        logger.debug("LocationManager: authorizationStatus changed to \(String(describing: manager.authorizationStatus)) (raw=\(manager.authorizationStatus.rawValue)), move=\(self.move != nil), consentAlreadySet=\(self.move?.locationConsentGrantedAt != nil)")

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
            // Escalate to Always so the system's upgrade dialog appears. Guarded to fire once —
            // CoreLocation itself only ever presents this dialog once per install; a repeat call
            // silently does nothing, so if the user misses/declines it here, LocationAlwaysUpgradeCard
            // (ZenDashboardView) is the only remaining path back in, via Settings.
            if !hasRequestedAlwaysUpgrade {
                hasRequestedAlwaysUpgrade = true
                // Firing this the instant the WhenInUse alert closes has been observed to make iOS
                // silently skip showing the Always dialog at all — a short delay avoids stacking
                // it directly behind the system alert the user just dismissed.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    manager.requestAlwaysAuthorization()
                }
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
            // Not silently lost — see the `move` didSet above, which asks CoreLocation
            // whether we're still inside every monitored region as soon as `move`
            // becomes available, catching exactly this case.
            logger.error("LocationManager: didEnterRegion fired but move is nil — will re-check once move is set")
            return
        }
        handleRegionEntry(circularRegion, move: move)
    }

    // MARK: - CLLocationManagerDelegate — recovers entries missed while move was nil

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard state == .inside,
              let circularRegion = region as? CLCircularRegion,
              let move else { return }
        logger.debug("LocationManager: requestState confirms still inside \(circularRegion.identifier) — reprocessing as entry")
        handleRegionEntry(circularRegion, move: move)
    }

    private func handleRegionEntry(_ circularRegion: CLCircularRegion, move: Move) {
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

        // Record the cooldown synchronously, immediately — not after the async budget
        // check/fire below. Multiple tasks in the same POI category can share one
        // real-world building (e.g. a DMV office that also handles vehicle registration
        // and emissions inspection) and register overlapping geofences at the same
        // coordinate; didEnterRegion then fires once per overlapping region in the same
        // instant. Recording the cooldown only after an awaited step left a window where
        // a second/third synchronous shouldFire check for the same category — running
        // before the first call's Task had gotten around to recording anything — would
        // read the cooldown gate as still open, letting all of them through. Confirmed
        // live: three same-category geofences at one coordinate fired three notifications
        // instead of the one the cooldown gate exists to guarantee.
        cooldownStore.record(category: poiCategory, date: Date())

        Task { @MainActor in
            guard await NotificationBudget.hasRoomToday() else {
                logger.debug("LocationManager: notification budget exhausted — suppressing '\(poiCategory.rawValue)'")
                return
            }
            // All gates passed — fire the notification
            self.reminderService.fireLocationNotification(task: task, poiCategory: poiCategory)
            logger.debug("LocationManager: ✅ fired notification for '\(poiCategory.rawValue)'")
        }
    }

    // MARK: - CLLocationManagerDelegate — visit detection (citywide, not destination-bound)

    /// Unlike `didEnterRegion` (fixed geofences pre-resolved near the destination, capped at
    /// 20), `didVisit` fires anywhere the user actually dwells — driving around town, at the
    /// old apartment, wherever — via CoreLocation's lowest-power "did the user stop somewhere"
    /// detection. It doesn't tell us *what* is there, so GeofenceCoordinator resolves that
    /// afterward against only the categories we actually have a pending task for.
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard let move else {
            logger.error("LocationManager: didVisit fired but move is nil")
            return
        }

        let candidateCategories = Array(Set(
            move.tasks.compactMap { task -> POICategory? in
                guard task.status == .toDo, !task.isMuted else { return nil }
                return task.poiCategory
            }
        ))
        guard !candidateCategories.isEmpty else { return }

        let coordinate = visit.coordinate
        logger.debug("LocationManager: visit reported at \(coordinate.latitude), \(coordinate.longitude)")

        Task { @MainActor in
            guard let poiCategory = await self.geofenceCoordinator.matchVisitCategory(
                at: coordinate,
                candidateCategories: candidateCategories
            ) else {
                logger.debug("LocationManager: visit did not match any pending POI category")
                return
            }

            guard let move = self.move,
                  let task = move.tasks.first(where: { $0.status == .toDo && $0.poiCategory == poiCategory }) else { return }

            let context = SuppressionEngine.Context(
                move: move,
                poiCategory: poiCategory,
                cooldownStore: self.cooldownStore,
                now: Date(),
                userLocation: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                destinationCoordinate: coordinate // unused — shouldFireForVisit skips the distance gate
            )

            guard SuppressionEngine.shouldFireForVisit(context: context) else {
                logger.debug("LocationManager: suppression engine blocked visit notification for '\(poiCategory.rawValue)'")
                return
            }

            // Recorded immediately, before the awaited budget check — see the matching
            // comment in didEnterRegion for why this ordering matters (closes the same
            // class of race for a second visit reported before this one's Task finishes).
            self.cooldownStore.record(category: poiCategory, date: Date())

            guard await NotificationBudget.hasRoomToday() else {
                logger.debug("LocationManager: notification budget exhausted — suppressing visit notification for '\(poiCategory.rawValue)'")
                return
            }

            self.reminderService.fireLocationNotification(task: task, poiCategory: poiCategory)
            logger.debug("LocationManager: ✅ fired visit-triggered notification for '\(poiCategory.rawValue)'")
        }
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
            manager.stopMonitoringVisits()
            cooldownStore.clearAll()
        }
    }

    // MARK: - Geofence sync

    /// Syncs geofences if the consent window is active and we have a move loaded.
    func syncGeofencesIfActive() {
        guard let move else { return }
        guard let grantedAt = move.locationConsentGrantedAt,
              SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: Date()) else { return }

        // Visit monitoring covers anywhere the user dwells (see didVisit), complementing the
        // destination-only geofences below. Like region monitoring, it needs Always
        // authorization for background delivery; CLLocationManager just no-ops otherwise.
        if authorizationStatus == .authorizedAlways {
            manager.startMonitoringVisits()
        }

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
