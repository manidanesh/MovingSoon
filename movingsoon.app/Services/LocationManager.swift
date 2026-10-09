import Foundation
import CoreLocation
import UserNotifications
import SwiftData
import OSLog

@MainActor @Observable
final class LocationManager: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = LocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    var activeContextualTask: ChecklistTask?
    var move: Move?
    var cooldownStore = CooldownStore()
    let geofenceCoordinator = GeofenceCoordinator()
    private let manager = CLLocationManager()
    private var modelContext: ModelContext?
    private var syncTask: Task<Void, Never>?
    private var visitTask: Task<Void, Never>?
    private var boundaryTimer: Timer?
    private var foreground = false
    private var hasRequestedAlwaysUpgrade = false
    private var inFlightCategories: Set<POICategory> = []
    private let logger = Logger(subsystem: "app.movingsoon", category: "LocationManager")

    override init() {
        super.init()
        authorizationStatus = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    /// Called during app startup, before a dashboard or network image has loaded.
    func configure(context: ModelContext) {
        modelContext = context
        let moves = (try? context.fetch(FetchDescriptor<Move>())) ?? []
        attach(moves.first { $0.phase == .active && $0.lifestyleProfile != nil }, context: context)
    }

    func attach(_ move: Move?, context: ModelContext) {
        if self.move?.id != move?.id {
            visitTask?.cancel()
            currentLocation = nil
            activeContextualTask = nil
            hasRequestedAlwaysUpgrade = false
        }
        self.move = move
        modelContext = context
        recordRequestedConsentIfAuthorized()
        syncGeofencesIfActive()
        for region in manager.monitoredRegions { manager.requestState(for: region) }
    }

    var consentActive: Bool {
        guard let move, move.phase == .active, move.lifestyleProfile != nil else { return false }
        return SuppressionEngine.consentExpiryGatePasses(grantedAt: move.locationConsentGrantedAt, now: Date())
    }
    var canMonitor: Bool {
        consentActive && (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse)
    }
    var backgroundRemindersEnabled: Bool { consentActive && authorizationStatus == .authorizedAlways }

    func startForegroundUpdates() {
        foreground = true
        authorizationStatus = manager.authorizationStatus
        recordRequestedConsentIfAuthorized()
        checkConsentExpiry()
        if canMonitor { manager.startUpdatingLocation() }
        else { manager.stopUpdatingLocation() }
    }
    func stopForegroundUpdates() {
        foreground = false
        manager.stopUpdatingLocation()
        currentLocation = nil
        activeContextualTask = nil
    }

    func requestPermissions() {
        guard let move else { return }
        if let granted = move.locationConsentGrantedAt,
           !SuppressionEngine.consentExpiryGatePasses(grantedAt: granted, now: Date()) { return }
        if move.locationConsentGrantedAt == nil {
            move.locationConsentRequestedAt = Date()
            modelContext?.saveOrLog()
        }
        authorizationStatus = manager.authorizationStatus
        recordRequestedConsentIfAuthorized()
        if authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if authorizationStatus == .authorizedWhenInUse { requestAlwaysUpgrade() }
        syncGeofencesIfActive()
    }

    private func recordRequestedConsentIfAuthorized() {
        guard let move, ReminderPolicy.recordRequestedConsent(for: move, status: authorizationStatus) else { return }
        modelContext?.saveOrLog()
    }

    private func requestAlwaysUpgrade() {
        guard consentActive, !hasRequestedAlwaysUpgrade else { return }
        hasRequestedAlwaysUpgrade = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.consentActive, self.manager.authorizationStatus == .authorizedWhenInUse else { return }
            self.manager.requestAlwaysAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        recordRequestedConsentIfAuthorized()
        if authorizationStatus == .authorizedWhenInUse { requestAlwaysUpgrade() }
        syncGeofencesIfActive()
        if foreground { startForegroundUpdates() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard canMonitor else { checkConsentExpiry(); return }
        currentLocation = locations.last
        evaluateForegroundContext()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        currentLocation = nil
        activeContextualTask = nil
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) { handleRegion(region) }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if state == .inside { handleRegion(region) }
    }
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        manager.requestState(for: region)
    }
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region { geofenceCoordinator.monitoringFailed(identifier: region.identifier) }
        logger.error("A nearby reminder zone could not be monitored.")
    }

    private func destination(for move: Move) -> CLLocationCoordinate2D? {
        if let coordinate = move.destinationCoordinate, CLLocationCoordinate2DIsValid(coordinate) { return coordinate }
        // Never plant zones at the old arbitrary continental-US fallback.
        guard ZipBucketService.bucket(zip: move.destinationZip).city != nil else { return nil }
        return ZipBucketService.centroid(zip: move.destinationZip)
    }

    private func handleRegion(_ region: CLRegion) {
        checkConsentExpiry()
        guard canMonitor, let region = region as? CLCircularRegion, let move,
              let destination = destination(for: move),
              let request = LocationRegionPlan.requests(for: move, destination: destination)
                .first(where: { $0.identifier == region.identifier }),
              let task = move.tasks.first(where: { $0.id == request.taskID }) else { return }
        // The event establishes proximity; a stale foreground GPS fix must not block it.
        let location = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        sendIfRelevant(task: task, move: move, location: location, destination: destination,
                       visit: false, expectedRegion: region.identifier)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        checkConsentExpiry()
        guard backgroundRemindersEnabled, let move, visit.horizontalAccuracy >= 0,
              visit.horizontalAccuracy <= 75, CLLocationCoordinate2DIsValid(visit.coordinate) else { return }
        // A departure doesn't establish current proximity. Ignore delayed arrivals too.
        guard visit.departureDate == .distantFuture,
              visit.arrivalDate.timeIntervalSinceNow <= 0,
              visit.arrivalDate.timeIntervalSinceNow >= -15 * 60 else { return }
        visitTask?.cancel()
        let version = ReminderPolicy.revision(for: move)
        let requests = LocationRegionPlan.requests(for: move, destination: destination(for: move) ?? visit.coordinate)
        visitTask = Task { [weak self] in
            guard let self, let taskID = await self.geofenceCoordinator.matchVisit(at: visit.coordinate, requests: requests),
                  !Task.isCancelled, self.move?.id == move.id,
                  ReminderPolicy.revision(for: move) == version,
                  let task = move.tasks.first(where: { $0.id == taskID }) else { return }
            self.sendIfRelevant(task: task, move: move,
                location: CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude),
                destination: visit.coordinate, visit: true, expectedRegion: nil)
        }
    }

    private func sendIfRelevant(task: ChecklistTask, move: Move, location: CLLocation,
                                destination: CLLocationCoordinate2D, visit: Bool, expectedRegion: String?) {
        guard let category = task.poiCategory, !inFlightCategories.contains(category) else { return }
        let version = ReminderPolicy.revision(for: move)
        func relevant() -> Bool {
            guard self.canMonitor, self.move?.id == move.id,
                  ReminderPolicy.revision(for: move) == version,
                  move.tasks.contains(where: { $0.id == task.id }), ReminderPolicy.isEligible(task) else { return false }
            if let expectedRegion,
               !self.manager.monitoredRegions.contains(where: { $0.identifier == expectedRegion }) { return false }
            let context = SuppressionEngine.Context(move: move, poiCategory: category, cooldownStore: self.cooldownStore,
                now: Date(), userLocation: location, destinationCoordinate: destination)
            return visit ? (self.backgroundRemindersEnabled && SuppressionEngine.shouldFireForVisit(context: context))
                         : SuppressionEngine.shouldFire(context: context)
        }
        guard relevant() else { return }
        inFlightCategories.insert(category)
        Task {
            defer { inFlightCategories.remove(category) }
            if await SmartReminderService.shared.fireLocationNotification(task: task, poiCategory: category, stillRelevant: relevant) {
                cooldownStore.record(category: category, date: Date())
            }
        }
    }

    func checkConsentExpiry() {
        guard canMonitor else {
            syncTask?.cancel()
            visitTask?.cancel()
            geofenceCoordinator.removeAllGeofences(manager: manager)
            manager.stopMonitoringVisits()
            manager.stopUpdatingLocation()
            boundaryTimer?.invalidate()
            activeContextualTask = nil
            return
        }
    }

    func syncGeofencesIfActive() {
        syncTask?.cancel()
        geofenceCoordinator.invalidate()
        checkConsentExpiry()
        guard canMonitor, let move else { return }
        if backgroundRemindersEnabled { manager.startMonitoringVisits() }
        else { manager.stopMonitoringVisits() }
        scheduleBoundaryCheck(for: move)
        guard let destination = destination(for: move) else {
            geofenceCoordinator.removeAllGeofences(manager: manager)
            return
        }
        let requests = LocationRegionPlan.requests(for: move, destination: destination)
        syncTask = Task {
            await geofenceCoordinator.syncGeofences(requests: requests, destination: destination, manager: manager)
            evaluateForegroundContext()
        }
    }

    private func scheduleBoundaryCheck(for move: Move) {
        boundaryTimer?.invalidate()
        let now = Date()
        var boundaries = move.tasks.compactMap(\.snoozedUntil).filter { $0 > now }
        if let granted = move.locationConsentGrantedAt,
           let end = Calendar.current.date(byAdding: .day, value: 30, to: granted) { boundaries.append(end.addingTimeInterval(1)) }
        guard let next = boundaries.filter({ $0 > now }).min() else { return }
        boundaryTimer = Timer.scheduledTimer(withTimeInterval: next.timeIntervalSince(now), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.syncGeofencesIfActive() }
        }
    }

    func taskStatusDidChange(_ task: ChecklistTask) {
        if !ReminderPolicy.isEligible(task), activeContextualTask?.id == task.id { activeContextualTask = nil }
        syncGeofencesIfActive()
    }

    func evaluateForegroundContext(now: Date = Date()) {
        activeContextualTask = nil
        guard canMonitor, let move, let currentLocation, let destination = destination(for: move) else { return }
        let requests = LocationRegionPlan.requests(for: move, destination: destination, now: now)
        for request in requests {
            guard let region = manager.monitoredRegions.first(where: { $0.identifier == request.identifier }) as? CLCircularRegion,
                  region.contains(currentLocation.coordinate),
                  let task = move.tasks.first(where: { $0.id == request.taskID }), let category = task.poiCategory else { continue }
            let context = SuppressionEngine.Context(move: move, poiCategory: category, cooldownStore: cooldownStore,
                now: now, userLocation: currentLocation, destinationCoordinate: destination)
            if SuppressionEngine.shouldFire(context: context) { activeContextualTask = task; return }
        }
    }
}
