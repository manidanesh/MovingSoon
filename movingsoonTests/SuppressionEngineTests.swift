// SuppressionEngineTests.swift — Unit tests for all SuppressionEngine gates
import XCTest
import CoreLocation
import SwiftData
@testable import movingsoon_app

final class SuppressionEngineTests: XCTestCase {

    // MARK: - Helpers

    private var container: ModelContainer!
    private var move: Move!

    override func setUp() {
        super.setUp()
        let schema = Schema([Move.self, ChecklistTask.self, VerificationEvent.self,
                             PendingSignal.self, FinancialInstitution.self, LifestyleProfile.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        move = Move(anchorDate: Date().addingTimeInterval(30 * 86400),
                    originZip: "80202",
                    destinationZip: "80202",
                    destinationStateBucket: "CO",
                    destinationCityBucket: "DENVER")
        move.locationConsentGrantedAt = Date()
        ModelContext(container).insert(move)
    }

    override func tearDown() {
        container = nil
        move = nil
        super.tearDown()
    }

    private func makePOITask(category: POICategory, status: TaskStatus = .toDo) -> ChecklistTask {
        let task = ChecklistTask(title: "Test Task", category: .financial,
                                 priority: .medium, tMinusDays: 0)
        task.poiCategory = category
        task.statusRaw = status.rawValue
        task.move = move
        return task
    }

    private func makeContext(
        now: Date? = nil,
        consentGrantedAt: Date? = Date(),
        completionFraction: Double = 0.5,
        tasks: [ChecklistTask] = [],
        poiCategory: POICategory = .bank,
        cooldownStore: CooldownStore = CooldownStore(defaults: .init(suiteName: UUID().uuidString)!)
    ) -> SuppressionEngine.Context {
        move.locationConsentGrantedAt = consentGrantedAt
        move.tasks = tasks
        let userLoc = CLLocation(latitude: 39.7392, longitude: -104.9903)
        let destCoord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let resolvedNow = now ?? makeDate(hour: 12, minute: 0) // Default to 12:00 PM so timeOfDay gate passes
        return SuppressionEngine.Context(
            move: move,
            poiCategory: poiCategory,
            cooldownStore: cooldownStore,
            now: resolvedNow,
            userLocation: userLoc,
            destinationCoordinate: destCoord
        )
    }

    // MARK: - Main shouldFire Evaluator

    func test_shouldFire_withinDistance_passes() {
        let task = makePOITask(category: .bank, status: .toDo)
        let context = makeContext(tasks: [task])
        XCTAssertTrue(SuppressionEngine.shouldFire(context: context))
    }

    func test_shouldFire_beyondDistance_fails() {
        let task = makePOITask(category: .bank, status: .toDo)
        
        let userLoc = CLLocation(latitude: 40.7, longitude: -104.9903) // ~100km away
        let destCoord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        
        let store = CooldownStore(defaults: .init(suiteName: UUID().uuidString)!)
        move.locationConsentGrantedAt = Date()
        move.tasks = [task]
        
        let context = SuppressionEngine.Context(
            move: move,
            poiCategory: .bank,
            cooldownStore: store,
            now: makeDate(hour: 12, minute: 0),
            userLocation: userLoc,
            destinationCoordinate: destCoord
        )
        
        XCTAssertFalse(SuppressionEngine.shouldFire(context: context))
    }

    // MARK: - Gate 1: Consent Expiry

    func test_consentExpiry_nilGrantedAt_fails() {
        XCTAssertFalse(SuppressionEngine.consentExpiryGatePasses(grantedAt: nil, now: Date()))
    }

    func test_consentExpiry_within30Days_passes() {
        let grantedAt = Date()
        let now = Date().addingTimeInterval(29 * 86400)
        XCTAssertTrue(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now))
    }

    func test_consentExpiry_exactly30Days_passes() {
        let grantedAt = Date()
        let now = Calendar.current.date(byAdding: .day, value: 30, to: grantedAt)!
        XCTAssertTrue(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now))
    }

    func test_consentExpiry_after30Days_fails() {
        let grantedAt = Date()
        let now = Calendar.current.date(byAdding: .day, value: 31, to: grantedAt)!
        XCTAssertFalse(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now))
    }

    func test_consentExpiry_grantedInFuture_passes() {
        let grantedAt = Date().addingTimeInterval(86400) // 1 day from now
        let now = Date()
        XCTAssertTrue(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now))
    }

    // MARK: - Gate 2: Completion

    func test_completion_below80Percent_passes() {
        XCTAssertTrue(SuppressionEngine.completionGatePasses(fraction: 0.0))
        XCTAssertTrue(SuppressionEngine.completionGatePasses(fraction: 0.5))
        XCTAssertTrue(SuppressionEngine.completionGatePasses(fraction: 0.79))
    }

    func test_completion_exactly80Percent_fails() {
        XCTAssertFalse(SuppressionEngine.completionGatePasses(fraction: 0.80))
    }

    func test_completion_above80Percent_fails() {
        XCTAssertFalse(SuppressionEngine.completionGatePasses(fraction: 0.81))
        XCTAssertFalse(SuppressionEngine.completionGatePasses(fraction: 1.0))
    }

    // MARK: - Gate 3: Time of Day

    func test_timeOfDay_9am_passes() {
        let date = makeDate(hour: 9, minute: 0)
        XCTAssertTrue(SuppressionEngine.timeOfDayGatePasses(now: date))
    }

    func test_timeOfDay_midday_passes() {
        let date = makeDate(hour: 13, minute: 30)
        XCTAssertTrue(SuppressionEngine.timeOfDayGatePasses(now: date))
    }

    func test_timeOfDay_6_59pm_passes() {
        let date = makeDate(hour: 18, minute: 59)
        XCTAssertTrue(SuppressionEngine.timeOfDayGatePasses(now: date))
    }

    func test_timeOfDay_7pm_fails() {
        let date = makeDate(hour: 19, minute: 0)
        XCTAssertFalse(SuppressionEngine.timeOfDayGatePasses(now: date))
    }

    func test_timeOfDay_8_59am_fails() {
        let date = makeDate(hour: 8, minute: 59)
        XCTAssertFalse(SuppressionEngine.timeOfDayGatePasses(now: date))
    }

    func test_timeOfDay_midnight_fails() {
        let date = makeDate(hour: 0, minute: 0)
        XCTAssertFalse(SuppressionEngine.timeOfDayGatePasses(now: date))
    }

    // MARK: - Gate 4: Distance (static function, kept for completeness)

    func test_distance_within8km_passes() {
        let user = CLLocation(latitude: 39.7392, longitude: -104.9903)
        let dest = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        XCTAssertTrue(SuppressionEngine.distanceGatePasses(userLocation: user, destination: dest))
    }

    func test_distance_exactly8km_passes() {
        // ~8km north of Denver centroid
        let user = CLLocation(latitude: 39.8112, longitude: -104.9903)
        let dest = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let distance = user.distance(from: CLLocation(latitude: dest.latitude, longitude: dest.longitude))
        // Only assert if within tolerance
        if distance <= 8001 {
            XCTAssertTrue(SuppressionEngine.distanceGatePasses(userLocation: user, destination: dest))
        }
    }

    func test_distance_beyond8km_fails() {
        // ~100km away
        let user = CLLocation(latitude: 40.7, longitude: -104.9903)
        let dest = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        XCTAssertFalse(SuppressionEngine.distanceGatePasses(userLocation: user, destination: dest))
    }

    // MARK: - Gate 5: Task Relevance

    func test_taskRelevance_matchingPendingTask_passes() {
        let task = makePOITask(category: .bank, status: .toDo)
        XCTAssertTrue(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    func test_taskRelevance_noMatchingCategory_fails() {
        let task = makePOITask(category: .gym, status: .toDo)
        XCTAssertFalse(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    func test_taskRelevance_completedTask_fails() {
        let task = makePOITask(category: .bank, status: .completed)
        XCTAssertFalse(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    func test_taskRelevance_mutedTask_fails() {
        let task = makePOITask(category: .bank, status: .toDo)
        task.isMuted = true
        XCTAssertFalse(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    func test_taskRelevance_snoozedTask_fails() {
        let task = makePOITask(category: .bank, status: .toDo)
        task.snoozedUntil = Date().addingTimeInterval(86400) // snoozed until tomorrow
        XCTAssertFalse(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank, now: Date()))
    }

    func test_taskRelevance_snoozedExpired_passes() {
        let task = makePOITask(category: .bank, status: .toDo)
        task.snoozedUntil = Date().addingTimeInterval(-86400) // snooze expired yesterday
        XCTAssertTrue(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank, now: Date()))
    }

    func test_taskRelevance_emptyList_fails() {
        XCTAssertFalse(SuppressionEngine.taskRelevanceGatePasses(tasks: [], category: .bank))
    }

    // MARK: - Gate 6: Cooldown

    func test_cooldown_noPreviousFire_passes() {
        let store = CooldownStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertTrue(SuppressionEngine.cooldownGatePasses(store: store, category: .bank, now: Date()))
    }

    func test_cooldown_firedToday_fails() {
        var store = CooldownStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let now = Date()
        store.record(category: .bank, date: now)
        XCTAssertFalse(SuppressionEngine.cooldownGatePasses(store: store, category: .bank, now: now))
    }

    func test_cooldown_firedYesterday_passes() {
        var store = CooldownStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.record(category: .bank, date: yesterday)
        XCTAssertTrue(SuppressionEngine.cooldownGatePasses(store: store, category: .bank, now: Date()))
    }

    func test_cooldown_differentCategory_passes() {
        var store = CooldownStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.record(category: .bank, date: Date())
        XCTAssertTrue(SuppressionEngine.cooldownGatePasses(store: store, category: .gym, now: Date()))
    }

    // MARK: - Helper

    private func makeDate(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps)!
    }
}
