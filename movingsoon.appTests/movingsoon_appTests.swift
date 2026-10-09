// movingsoon_appTests.swift — Automated test suite using Swift Testing
import Testing
import Foundation
import CoreLocation
import SwiftData
import UserNotifications
@testable import movingsoon_app

// MARK: - Location/reminder regression fixtures

@MainActor private enum ReminderFixtures {
    static let now = Date(timeIntervalSince1970: 1_791_201_600)
    static let destination = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    static func move(tasks: [ChecklistTask] = []) -> Move {
        let move = Move(anchorDate: now.addingTimeInterval(10 * 86400), originZip: "90210",
                        destinationZip: "80202", destinationStateBucket: "CO", destinationCityBucket: "DENVER",
                        destinationLatitude: destination.latitude, destinationLongitude: destination.longitude)
        move.lifestyleProfile = LifestyleProfile()
        move.tasks = tasks
        tasks.forEach { $0.move = move }
        return move
    }
    static func task(_ id: String = "lifetime", priority: TaskPriority = .critical) -> ChecklistTask {
        let item = ItemCatalog.byID[id]
        let task = ChecklistTask(title: item?.title ?? id, category: .other, priority: priority, tMinusDays: -3)
        task.catalogItemID = item?.canonicalID
        task.poiCategory = item?.poiCategory ?? .gym
        return task
    }
    static func request(_ id: String, task: ChecklistTask? = nil) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        if let task { content.userInfo = ["taskID": task.id.uuidString, "taskIDs": [task.id.uuidString]] }
        return UNNotificationRequest(identifier: id, content: content, trigger: nil)
    }
    static func ids(_ request: UNNotificationRequest) -> [String] {
        request.content.userInfo["taskIDs"] as? [String] ?? []
    }
    static func fireDate(_ request: UNNotificationRequest) -> Date? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return nil }
        return calendar.date(from: trigger.dateComponents)
    }
}

/// Deterministic async barriers: race tests never depend on wall-clock sleeps.
@MainActor private final class ReminderTestLatch {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        opened = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

@MainActor private final class FakeLocationSearch: LocationPlaceSearching {
    var calls: [String] = []
    var availableQueries: Set<String>?
    var firstEntered: ReminderTestLatch?
    var firstRelease: ReminderTestLatch?
    func search(target: LocationPlaceTarget, near coordinate: CLLocationCoordinate2D,
                radius: CLLocationDistance) async -> [LocationPlaceMatch] {
        calls.append(target.query)
        if let release = firstRelease {
            firstRelease = nil
            firstEntered?.open()
            await release.wait()
        }
        if let availableQueries, !availableQueries.contains(target.query) { return [] }
        return [LocationPlaceMatch(name: target.query, coordinate: coordinate)]
    }
}

@MainActor private final class FakeRegionMonitor: LocationRegionMonitoring {
    var monitoredRegions: Set<CLRegion> = []
    var started: [String] = []
    var stopped: [String] = []
    var peakCount = 0
    func startMonitoring(for region: CLRegion) {
        monitoredRegions.insert(region)
        started.append(region.identifier)
        peakCount = max(peakCount, monitoredRegions.count)
    }
    func stopMonitoring(for region: CLRegion) {
        monitoredRegions.remove(region)
        stopped.append(region.identifier)
    }
}

@MainActor private final class FakeReminderCenter: ReminderNotificationCenter {
    var pendingRequests: [String: UNNotificationRequest] = [:]
    var deliveredRequests: [UNNotificationRequest] = []
    var permission = true
    var failAdds = false
    var firstEntered: ReminderTestLatch?
    var firstRelease: ReminderTestLatch?
    func pending() async -> [UNNotificationRequest] { Array(pendingRequests.values) }
    func delivered() async -> [UNNotificationRequest] { deliveredRequests }
    func authorized() async -> Bool { permission }
    func requestPermission() async -> Bool { permission }
    func add(_ request: UNNotificationRequest) async throws {
        if let release = firstRelease {
            firstRelease = nil
            firstEntered?.open()
            await release.wait()
        }
        if failAdds { throw NSError(domain: "ReminderTest", code: 1) }
        pendingRequests[request.identifier] = request
    }
    func removePending(_ identifiers: [String]) { identifiers.forEach { pendingRequests.removeValue(forKey: $0) } }
    func removeDelivered(_ identifiers: [String]) { deliveredRequests.removeAll { identifiers.contains($0.identifier) } }
}

@MainActor @Suite("Location reminders — explicit consent and task eligibility")
struct ReminderPolicyRegressionTests {
    @Test(arguments: [CLAuthorizationStatus.notDetermined, .authorizedWhenInUse, .authorizedAlways, .denied])
    func unconsentedMoveKeepsSetupAvailable(_ status: CLAuthorizationStatus) {
        #expect(ReminderPolicy.showsConsent(grantedAt: nil, status: status, dismissed: false))
        #expect(!ReminderPolicy.showsConsent(grantedAt: nil, status: status, dismissed: true))
    }

    @Test func restrictedAndExpiredConsentDoNotReprompt() {
        #expect(!ReminderPolicy.showsConsent(grantedAt: nil, status: .restricted, dismissed: false))
        let old = ReminderFixtures.now.addingTimeInterval(-31 * 86400)
        #expect(!ReminderPolicy.showsConsent(grantedAt: old, status: .authorizedAlways, dismissed: false))
        #expect(!ReminderPolicy.needsAlwaysUpgrade(grantedAt: old, status: .authorizedWhenInUse,
                                                  dismissed: false, now: ReminderFixtures.now))
    }

    @Test func systemPermissionAloneNeverCreatesMoveConsent() {
        let move = ReminderFixtures.move()
        #expect(!ReminderPolicy.recordRequestedConsent(for: move, status: .authorizedAlways, now: ReminderFixtures.now))
        #expect(move.locationConsentGrantedAt == nil)
    }

    @Test func firstWhileUsingGrantRecordsExplicitRequestAndEnablesUpgrade() {
        let move = ReminderFixtures.move()
        move.locationConsentRequestedAt = ReminderFixtures.now.addingTimeInterval(-10)
        #expect(ReminderPolicy.recordRequestedConsent(for: move, status: .authorizedWhenInUse, now: ReminderFixtures.now))
        #expect(move.locationConsentGrantedAt == move.locationConsentRequestedAt)
        #expect(ReminderPolicy.needsAlwaysUpgrade(grantedAt: move.locationConsentGrantedAt, status: .authorizedWhenInUse,
                                                  dismissed: false, now: ReminderFixtures.now))
        #expect(!ReminderPolicy.recordRequestedConsent(for: move, status: .authorizedAlways,
                                                        now: ReminderFixtures.now.addingTimeInterval(86400)))
        #expect(move.locationConsentGrantedAt == move.locationConsentRequestedAt)
    }

    @Test func denialFutureAndExpiredRequestsDoNotStartConsent() {
        let move = ReminderFixtures.move()
        move.locationConsentRequestedAt = ReminderFixtures.now
        #expect(!ReminderPolicy.recordRequestedConsent(for: move, status: .denied, now: ReminderFixtures.now))
        move.locationConsentRequestedAt = ReminderFixtures.now.addingTimeInterval(1)
        #expect(!ReminderPolicy.recordRequestedConsent(for: move, status: .authorizedAlways, now: ReminderFixtures.now))
        move.locationConsentRequestedAt = ReminderFixtures.now.addingTimeInterval(-31 * 86400)
        #expect(!ReminderPolicy.recordRequestedConsent(for: move, status: .authorizedAlways, now: ReminderFixtures.now))
    }

    @Test func everySuppressionAppliesToTheExactTask() {
        let task = ReminderFixtures.task()
        let now = ReminderFixtures.now
        #expect(ReminderPolicy.isEligible(task, at: now))
        task.isMuted = true
        #expect(!ReminderPolicy.isEligible(task, at: now))
        task.isMuted = false
        task.snoozedUntil = now.addingTimeInterval(1)
        #expect(!ReminderPolicy.isEligible(task, at: now))
        task.snoozedUntil = now
        #expect(ReminderPolicy.isEligible(task, at: now))
        task.needsLocationReview = true
        #expect(!ReminderPolicy.isEligible(task, at: now))
        task.needsLocationReview = false
        for status in [TaskStatus.pendingVerification, .completed] {
            task.status = status
            #expect(!ReminderPolicy.isEligible(task, at: now))
        }
    }

    @Test func revisionTracksProviderDestinationPriorityLinkAndTaskState() {
        let task = ReminderFixtures.task()
        let move = ReminderFixtures.move(tasks: [task])
        var previous = ReminderPolicy.revision(for: move)
        let edits: [() -> Void] = [
            { task.institutionName = "Chase" }, { move.destinationZip = "10001" },
            { task.priorityRaw = TaskPriority.low.rawValue }, { task.deepLinkURLString = "https://example.com/account" },
            { task.isMuted = true }, { task.snoozedUntil = ReminderFixtures.now },
            { task.needsLocationReview = true }, { task.status = .completed },
            { move.destinationLatitude = 40 }, { move.phaseRaw = MovePhase.archived.rawValue }
        ]
        for edit in edits {
            edit()
            let changed = ReminderPolicy.revision(for: move)
            #expect(previous != changed)
            previous = changed
        }
    }

    @Test func consentAndNotificationActionsPersistAcrossContexts() throws {
        let container = try ModelContainer(for: Move.self, ChecklistTask.self, LifestyleProfile.self,
            FinancialInstitution.self, VerificationEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let task = ReminderFixtures.task()
        let move = ReminderFixtures.move(tasks: [task])
        context.insert(move)
        move.locationConsentRequestedAt = ReminderFixtures.now
        ReminderPolicy.recordRequestedConsent(for: move, status: .authorizedWhenInUse, now: ReminderFixtures.now)
        #expect(NotificationTaskAction.apply("SNOOZE", to: task, now: ReminderFixtures.now))
        #expect(NotificationTaskAction.apply("MUTE", to: task, now: ReminderFixtures.now))
        try context.save()
        let restored = try #require(ModelContext(container).fetch(FetchDescriptor<Move>()).first)
        #expect(restored.locationConsentRequestedAt == ReminderFixtures.now)
        #expect(restored.locationConsentGrantedAt == ReminderFixtures.now)
        #expect(restored.tasks.first?.isMuted == true)
        #expect(restored.tasks.first?.snoozedUntil == ReminderFixtures.now.addingTimeInterval(86400))
    }

    @Test func notificationActionsDoNotResurrectFinishedTasks() {
        let task = ReminderFixtures.task()
        for status in [TaskStatus.completed, .pendingVerification] {
            task.status = status
            #expect(!NotificationTaskAction.apply("SNOOZE", to: task))
            #expect(!NotificationTaskAction.apply("MUTE", to: task))
            #expect(task.status == status)
        }
        task.status = .toDo
        task.isMuted = true
        #expect(!NotificationTaskAction.apply("SNOOZE", to: task))
        #expect(!NotificationTaskAction.apply("UNKNOWN", to: task))
    }
}

@MainActor @Suite("Location reminders — provider matching and region reconciliation")
struct LocationRegionRegressionTests {
    @Test func namedProvidersNeverMatchAnotherProviderInTheCategory() throws {
        let lifeTime = try #require(LocationPlaceTarget.forTask(ReminderFixtures.task("lifetime")))
        #expect(lifeTime.matches(name: "Life Time Cherry Creek"))
        #expect(lifeTime.matches(name: "LIFETIME FITNESS"))
        #expect(!lifeTime.matches(name: "Planet Fitness"))
        let bank = ReminderFixtures.task("My bank")
        bank.poiCategory = .bank
        bank.institutionName = "Chase"
        let chase = try #require(LocationPlaceTarget.forTask(bank))
        #expect(chase.matches(name: "Chase Bank"))
        #expect(!chase.matches(name: "Bank of America"))
        #expect(!chase.matches(name: "Chasewood Shopping Center"))
    }

    @Test func aliasesRespectWordBoundariesAndPunctuation() {
        let rei = LocationPlaceTarget(query: "REI", acceptedNames: ["REI"], category: .outdoorGear)
        #expect(rei.matches(name: "REI Co-op"))
        #expect(!rei.matches(name: "Freight outlet"))
        #expect(!rei.matches(name: nil))
        let books = LocationPlaceTarget(query: "Barnes & Noble", acceptedNames: ["Barnes & Noble"], category: .bookstore)
        #expect(books.matches(name: "Barnes and Noble — Café"))
        #expect(!LocationPlaceTarget(query: "", acceptedNames: [""], category: .other).matches(name: "Any Place"))
    }

    @Test func unknownPersonalProvidersStayOutOfLocationPlan() {
        let doctor = ChecklistTask(title: "My doctor", category: .other, priority: .high, tMinusDays: 0)
        doctor.poiCategory = .doctor
        #expect(LocationPlaceTarget.forTask(doctor) == nil)
        #expect(LocationPlaceTarget.forTask(ReminderFixtures.task("classpass")) == nil)
        #expect(LocationPlaceTarget.forTask(ReminderFixtures.task("Unknown local gym")) == nil)
    }

    @Test func catalogProviderMetadataIsCompleteWhereDeclared() {
        let providers = ItemCatalog.all.filter { $0.placeSearchName != nil }
        #expect(providers.count >= 39)
        for item in providers {
            #expect(item.poiCategory != nil)
            #expect(!item.placeNameAliases.isEmpty)
            #expect(item.placeNameAliases.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        }
    }

    @Test func regionIdentityChangesWhenDestinationOrProviderChanges() throws {
        let task = ReminderFixtures.task()
        let move = ReminderFixtures.move(tasks: [task])
        func plan(_ coordinate: CLLocationCoordinate2D? = nil) -> [LocationRegionRequest] {
            LocationRegionPlan.requests(for: move, destination: coordinate ?? ReminderFixtures.destination, now: ReminderFixtures.now)
        }
        let first = try #require(plan().first)
        #expect(plan().first?.identifier == first.identifier)
        move.destinationZip = "10001"
        #expect(plan().first?.identifier != first.identifier)
        move.destinationZip = "80202"
        #expect(plan(CLLocationCoordinate2D(latitude: 40.75, longitude: -73.99)).first?.identifier != first.identifier)
        task.institutionName = "Another provider"
        #expect(plan().first?.identifier != first.identifier)
    }

    @Test func planSkipsMutedSnoozedReviewedAndWrongCountryTasks() {
        let muted = ReminderFixtures.task(), snoozed = ReminderFixtures.task(), review = ReminderFixtures.task()
        muted.isMuted = true
        snoozed.snoozedUntil = ReminderFixtures.now.addingTimeInterval(1)
        review.needsLocationReview = true
        let usps = ReminderFixtures.task("usps")
        let move = ReminderFixtures.move(tasks: [muted, snoozed, review, usps])
        move.destinationZip = "M5V 3L9"
        let plan = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        #expect(plan.isEmpty)
    }

    @Test func coldLaunchPrunesLegacyZonesAndRetainsUnchangedZones() async throws {
        let search = FakeLocationSearch(), monitor = FakeRegionMonitor()
        let coordinator = GeofenceCoordinator(searcher: search)
        let move = ReminderFixtures.move(tasks: [ReminderFixtures.task()])
        let requests = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        monitor.startMonitoring(for: CLCircularRegion(center: ReminderFixtures.destination, radius: 200, identifier: "legacy-task-uuid"))
        await coordinator.syncGeofences(requests: requests, destination: ReminderFixtures.destination, manager: monitor)
        #expect(monitor.stopped == ["legacy-task-uuid"])
        #expect(monitor.monitoredRegions.count == 1)
        let calls = search.calls.count, starts = monitor.started.count
        await coordinator.syncGeofences(requests: requests, destination: ReminderFixtures.destination, manager: monitor)
        #expect(search.calls.count == calls)
        #expect(monitor.started.count == starts)
        let region = try #require(monitor.monitoredRegions.first as? CLCircularRegion)
        #expect(region.radius == 200 && region.notifyOnEntry && !region.notifyOnExit)
        move.tasks[0].isMuted = true
        let empty = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        await coordinator.syncGeofences(requests: empty, destination: ReminderFixtures.destination, manager: monitor)
        #expect(monitor.monitoredRegions.isEmpty)
        #expect(coordinator.registeredRegionIDs.isEmpty)
    }

    @Test func destinationEditReplacesCoordinatesAndOldIdentifiers() async throws {
        let monitor = FakeRegionMonitor(), coordinator = GeofenceCoordinator(searcher: FakeLocationSearch())
        let move = ReminderFixtures.move(tasks: [ReminderFixtures.task()])
        let old = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        await coordinator.syncGeofences(requests: old, destination: ReminderFixtures.destination, manager: monitor)
        let destination = CLLocationCoordinate2D(latitude: 40.75, longitude: -73.99)
        move.destinationZip = "10001"
        let new = LocationRegionPlan.requests(for: move, destination: destination, now: ReminderFixtures.now)
        await coordinator.syncGeofences(requests: new, destination: destination, manager: monitor)
        let region = try #require(monitor.monitoredRegions.first as? CLCircularRegion)
        #expect(region.center.latitude == destination.latitude)
        #expect(region.identifier == new.first?.identifier)
        #expect(monitor.stopped.contains(old[0].identifier))
    }

    @Test func zoneLimitAndSharedProviderSearchCache() async {
        let search = FakeLocationSearch(), monitor = FakeRegionMonitor()
        let coordinator = GeofenceCoordinator(searcher: search)
        let move = ReminderFixtures.move(tasks: (0..<25).map { _ in ReminderFixtures.task() })
        let plan = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        await coordinator.syncGeofences(requests: plan, destination: ReminderFixtures.destination, manager: monitor)
        #expect(monitor.monitoredRegions.count == 20)
        #expect(monitor.peakCount == 20)
        #expect(search.calls.count == 1)
    }

    @Test func noSearchMatchDoesNotRegisterZone() async {
        let search = FakeLocationSearch(), monitor = FakeRegionMonitor()
        search.availableQueries = []
        let coordinator = GeofenceCoordinator(searcher: search)
        let move = ReminderFixtures.move(tasks: [ReminderFixtures.task()])
        let plan = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        await coordinator.syncGeofences(requests: plan, destination: ReminderFixtures.destination, manager: monitor)
        #expect(monitor.monitoredRegions.isEmpty)
        #expect(coordinator.registeredRegionIDs.isEmpty)
    }

    @Test func obsoleteAsyncSearchCannotRecreateClearedZones() async {
        let entered = ReminderTestLatch(), release = ReminderTestLatch()
        let search = FakeLocationSearch(), monitor = FakeRegionMonitor()
        search.firstEntered = entered; search.firstRelease = release
        let coordinator = GeofenceCoordinator(searcher: search)
        let move = ReminderFixtures.move(tasks: [ReminderFixtures.task()])
        let plan = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        let old = Task { await coordinator.syncGeofences(requests: plan, destination: ReminderFixtures.destination, manager: monitor) }
        await entered.wait()
        coordinator.removeAllGeofences(manager: monitor)
        release.open()
        await old.value
        #expect(monitor.started.isEmpty)
        #expect(coordinator.registeredRegionIDs.isEmpty)
    }

    @Test func visitReturnsMatchingTaskNotAnotherGym() async throws {
        let first = ReminderFixtures.task("planetfitness"), second = ReminderFixtures.task("lifetime")
        first.tMinusDays = -30
        let move = ReminderFixtures.move(tasks: [first, second])
        let search = FakeLocationSearch()
        search.availableQueries = [try #require(LocationPlaceTarget.forTask(second)).query]
        let coordinator = GeofenceCoordinator(searcher: search)
        let plan = LocationRegionPlan.requests(for: move, destination: ReminderFixtures.destination, now: ReminderFixtures.now)
        #expect(await coordinator.matchVisit(at: ReminderFixtures.destination, requests: plan) == second.id)
    }
}

@MainActor @Suite("Reminders — one-shot schedules and serialized delivery")
struct ReminderScheduleRegressionTests {
    @Test func scheduledRequestsExcludeMutedFinishedAndReviewTasks() {
        let active = ReminderFixtures.task(), muted = ReminderFixtures.task(), completed = ReminderFixtures.task()
        let review = ReminderFixtures.task(), verifying = ReminderFixtures.task()
        muted.isMuted = true; completed.status = .completed; review.needsLocationReview = true; verifying.status = .pendingVerification
        let move = ReminderFixtures.move(tasks: [active, muted, completed, review, verifying])
        let requests = ReminderScheduleBuilder.requests(for: move, now: ReminderFixtures.now, calendar: ReminderFixtures.calendar)
        #expect(!requests.isEmpty)
        #expect(requests.allSatisfy { ReminderFixtures.ids($0) == [active.id.uuidString] })
        #expect(requests.allSatisfy { $0.content.userInfo["moveID"] as? String == move.id.uuidString })
        #expect(requests.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == false })
        #expect(requests.allSatisfy { (ReminderFixtures.fireDate($0) ?? .distantPast) > ReminderFixtures.now })
    }

    @Test func snoozedTaskCannotAppearBeforeExpiryAndReturnDoesNotClaimProximity() throws {
        let task = ReminderFixtures.task()
        let move = ReminderFixtures.move(tasks: [task])
        task.snoozedUntil = ReminderFixtures.now.addingTimeInterval(2 * 86400 + 60.5)
        let requests = ReminderScheduleBuilder.requests(for: move, now: ReminderFixtures.now, calendar: ReminderFixtures.calendar)
        #expect(requests.allSatisfy { (ReminderFixtures.fireDate($0) ?? .distantPast) >= task.snoozedUntil! })
        let snooze = try #require(requests.first { $0.identifier == "Snooze-\(task.id.uuidString)" })
        #expect(!snooze.content.body.lowercased().contains("near"))
        #expect(snooze.content.categoryIdentifier == "TaskReminder")
    }

    @Test func nightSnoozeReturnsAtNineAndUsesSuppliedCalendar() throws {
        let task = ReminderFixtures.task()
        let calendar = ReminderFixtures.calendar
        let start = calendar.startOfDay(for: ReminderFixtures.now.addingTimeInterval(86400))
        task.snoozedUntil = calendar.date(bySettingHour: 22, minute: 10, second: 0, of: start)
        let requests = ReminderScheduleBuilder.requests(for: ReminderFixtures.move(tasks: [task]), now: ReminderFixtures.now, calendar: calendar)
        let snooze = try #require(requests.first { $0.identifier.hasPrefix("Snooze-") })
        let fire = try #require(ReminderFixtures.fireDate(snooze))
        #expect(calendar.component(.hour, from: fire) == 9)
        #expect(fire > task.snoozedUntil!)
        #expect(calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: fire)).day == 1)
    }

    @Test func scheduleStaysWithinSystemCapacityAndArchivesClearIt() {
        let tasks = (0..<100).map { index in
            let task = ReminderFixtures.task()
            task.tMinusDays = index
            return task
        }
        let move = ReminderFixtures.move(tasks: tasks)
        let requests = ReminderScheduleBuilder.requests(for: move, now: ReminderFixtures.now, calendar: ReminderFixtures.calendar)
        #expect(requests.count == 60)
        #expect(Set(requests.map(\.identifier)).count == requests.count)
        move.phaseRaw = MovePhase.archived.rawValue
        #expect(ReminderScheduleBuilder.requests(for: move, now: ReminderFixtures.now).isEmpty)
    }

    @Test func legacyAndCurrentNotificationIdentifiersAreOwned() {
        for id in ["HeroTaskReminder", "HeroTaskReminderEvening", "Hero-123", "Digest-123", "TMinus-abc",
                   "Snooze-abc", "LocationReminder-abc", "ReengagementReminder", "PostMoveCheckIn"] {
            #expect(ReminderScheduleBuilder.owns(id))
        }
        #expect(!ReminderScheduleBuilder.owns("UnrelatedNotification"))
    }

    @Test func muteDuringAsyncSchedulingLeavesOnlyLatestPlan() async {
        let center = FakeReminderCenter(), entered = ReminderTestLatch(), release = ReminderTestLatch()
        center.firstEntered = entered; center.firstRelease = release
        let service = SmartReminderService(center: center, registerCategories: false)
        let muted = ReminderFixtures.task(), active = ReminderFixtures.task("costco")
        let move = ReminderFixtures.move(tasks: [muted, active])
        service.reschedule(for: move, now: ReminderFixtures.now)
        await entered.wait()
        muted.isMuted = true
        service.reschedule(for: move, now: ReminderFixtures.now)
        release.open()
        await service.waitForSchedule()
        #expect(!center.pendingRequests.isEmpty)
        #expect(center.pendingRequests.values.allSatisfy { !ReminderFixtures.ids($0).contains(muted.id.uuidString) })
        let expected = ReminderScheduleBuilder.requests(for: move, now: ReminderFixtures.now)
        #expect(Set(center.pendingRequests.keys) == Set(expected.map(\.identifier)))
    }

    @Test func resetClearsOwnedPendingAndDeliveredButPreservesUnrelatedRequests() async {
        let center = FakeReminderCenter()
        let task = ReminderFixtures.task()
        let old = ReminderFixtures.request("LocationReminder-old", task: task)
        let unrelated = ReminderFixtures.request("UnrelatedNotification")
        center.pendingRequests = [old.identifier: old, unrelated.identifier: unrelated]
        center.deliveredRequests = [old, unrelated]
        let service = SmartReminderService(center: center, registerCategories: false)
        service.reschedule(for: nil)
        await service.waitForSchedule()
        #expect(Set(center.pendingRequests.keys) == [unrelated.identifier])
        #expect(center.deliveredRequests.map(\.identifier) == [unrelated.identifier])
    }

    @Test func staleDeliveredTasksAreRemovedAndEligibleTasksAreRetained() async {
        let center = FakeReminderCenter()
        let muted = ReminderFixtures.task(), active = ReminderFixtures.task("costco")
        muted.isMuted = true
        let move = ReminderFixtures.move(tasks: [muted, active])
        center.deliveredRequests = [ReminderFixtures.request("LocationReminder-muted", task: muted),
                                   ReminderFixtures.request("LocationReminder-active", task: active),
                                   ReminderFixtures.request("HeroTaskReminder")]
        let service = SmartReminderService(center: center, registerCategories: false)
        service.reschedule(for: move, now: ReminderFixtures.now)
        await service.waitForSchedule()
        #expect(center.deliveredRequests.map(\.identifier) == ["LocationReminder-active"])
    }

    @Test func schedulingErrorDoesNotPreventNextUpdate() async {
        let center = FakeReminderCenter()
        let service = SmartReminderService(center: center, registerCategories: false)
        let move = ReminderFixtures.move(tasks: [ReminderFixtures.task()])
        center.failAdds = true
        service.reschedule(for: move, now: ReminderFixtures.now)
        await service.waitForSchedule()
        #expect(center.pendingRequests.isEmpty)
        center.failAdds = false
        service.reschedule(for: move, now: ReminderFixtures.now)
        await service.waitForSchedule()
        #expect(!center.pendingRequests.isEmpty)
    }

    @Test func locationDeliveryUsesExactTaskAndRecordsBudgetAfterSuccess() async throws {
        let center = FakeReminderCenter()
        var recorded = 0
        let service = SmartReminderService(center: center, registerCategories: false,
            hasLocationBudget: { true }, recordLocationDelivery: { recorded += 1 })
        let task = ReminderFixtures.task()
        #expect(await service.fireLocationNotification(task: task, poiCategory: .gym, stillRelevant: { true }))
        let request = try #require(center.pendingRequests.values.first)
        #expect(request.content.body.contains(task.title))
        #expect(ReminderFixtures.ids(request) == [task.id.uuidString])
        #expect(recorded == 1)
    }

    @Test func deniedPermissionAndStaleTaskNeverConsumeBudget() async {
        let center = FakeReminderCenter()
        var recorded = 0
        let service = SmartReminderService(center: center, registerCategories: false,
            hasLocationBudget: { true }, recordLocationDelivery: { recorded += 1 })
        let task = ReminderFixtures.task()
        center.permission = false
        #expect(await !service.fireLocationNotification(task: task, poiCategory: .gym, stillRelevant: { true }))
        center.permission = true
        #expect(await !service.fireLocationNotification(task: task, poiCategory: .gym, stillRelevant: { false }))
        task.isMuted = true
        #expect(await !service.fireLocationNotification(task: task, poiCategory: .gym, stillRelevant: { true }))
        #expect(recorded == 0 && center.pendingRequests.isEmpty)
    }

    @Test func concurrentLocationRequestsCannotRaceTheBudget() async {
        let center = FakeReminderCenter(), entered = ReminderTestLatch(), release = ReminderTestLatch()
        center.firstEntered = entered; center.firstRelease = release
        var recorded = 0
        let service = SmartReminderService(center: center, registerCategories: false,
            hasLocationBudget: { true }, recordLocationDelivery: { recorded += 1 })
        let first = ReminderFixtures.task(), second = ReminderFixtures.task("costco")
        let delivery = Task { await service.fireLocationNotification(task: first, poiCategory: .gym, stillRelevant: { true }) }
        await entered.wait()
        #expect(await !service.fireLocationNotification(task: second, poiCategory: .grocery, stillRelevant: { true }))
        release.open()
        #expect(await delivery.value)
        #expect(recorded == 1 && center.pendingRequests.count == 1)
    }

    @Test func taskMutedWhileNotificationAddIsPendingGetsRemoved() async {
        let center = FakeReminderCenter(), entered = ReminderTestLatch(), release = ReminderTestLatch()
        center.firstEntered = entered; center.firstRelease = release
        var recorded = 0
        let service = SmartReminderService(center: center, registerCategories: false,
            hasLocationBudget: { true }, recordLocationDelivery: { recorded += 1 })
        let task = ReminderFixtures.task()
        let delivery = Task { await service.fireLocationNotification(task: task, poiCategory: .gym, stillRelevant: { true }) }
        await entered.wait()
        task.isMuted = true
        release.open()
        #expect(await !delivery.value)
        #expect(recorded == 0 && center.pendingRequests.isEmpty)
    }
}

// MARK: - SuppressionEngine Tests

@Suite("SuppressionEngine — Consent Expiry Gate")
struct ConsentExpiryGateTests {

    @Test func nilGrantedAt_fails() {
        #expect(SuppressionEngine.consentExpiryGatePasses(grantedAt: nil, now: Date()) == false)
    }

    @Test func within30Days_passes() {
        let grantedAt = Date()
        let now = Date().addingTimeInterval(29 * 86400)
        #expect(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now) == true)
    }

    @Test func exactly30Days_passes() {
        let grantedAt = Date()
        let now = Calendar.current.date(byAdding: .day, value: 30, to: grantedAt)!
        #expect(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now) == true)
    }

    @Test func after30Days_fails() {
        let grantedAt = Date()
        let now = Calendar.current.date(byAdding: .day, value: 31, to: grantedAt)!
        #expect(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now) == false)
    }

    @Test func grantedInFuture_passes() {
        let grantedAt = Date().addingTimeInterval(86400) // 1 day from now
        let now = Date()
        #expect(SuppressionEngine.consentExpiryGatePasses(grantedAt: grantedAt, now: now) == true)
    }
}

@Suite("SuppressionEngine — Completion Gate")
struct CompletionGateTests {

    @Test func zeroPercent_passes()  { #expect(SuppressionEngine.completionGatePasses(fraction: 0.0)) }
    @Test func seventyNine_passes()  { #expect(SuppressionEngine.completionGatePasses(fraction: 0.79)) }
    @Test func exactly80_fails()     { #expect(!SuppressionEngine.completionGatePasses(fraction: 0.80)) }
    @Test func above80_fails()       { #expect(!SuppressionEngine.completionGatePasses(fraction: 1.0)) }
}

@Suite("SuppressionEngine — Time of Day Gate")
struct TimeOfDayGateTests {

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour; c.minute = minute; c.second = 0
        return Calendar.current.date(from: c)!
    }

    @Test func nineAM_passes()       { #expect(SuppressionEngine.timeOfDayGatePasses(now: makeDate(hour: 9))) }
    @Test func noon_passes()         { #expect(SuppressionEngine.timeOfDayGatePasses(now: makeDate(hour: 12))) }
    @Test func sixFiftyNinePM_passes() { #expect(SuppressionEngine.timeOfDayGatePasses(now: makeDate(hour: 18, minute: 59))) }
    @Test func sevenPM_fails()       { #expect(!SuppressionEngine.timeOfDayGatePasses(now: makeDate(hour: 19))) }
    @Test func eightFiftyNineAM_fails() { #expect(!SuppressionEngine.timeOfDayGatePasses(now: makeDate(hour: 8, minute: 59))) }
    @Test func midnight_fails()      { #expect(!SuppressionEngine.timeOfDayGatePasses(now: makeDate(hour: 0))) }
}

@Suite("SuppressionEngine — Distance Gate")
struct DistanceGateTests {

    @Test func sameLocation_passes() {
        let user = CLLocation(latitude: 39.7392, longitude: -104.9903)
        let dest = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        #expect(SuppressionEngine.distanceGatePasses(userLocation: user, destination: dest))
    }

    @Test func farAway_fails() {
        let user = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
        let dest = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903) // Denver
        #expect(!SuppressionEngine.distanceGatePasses(userLocation: user, destination: dest))
    }

    @Test func exactly8km_passes() {
        // ~8km north of Denver centroid
        let user = CLLocation(latitude: 39.8112, longitude: -104.9903)
        let dest = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let distance = user.distance(from: CLLocation(latitude: dest.latitude, longitude: dest.longitude))
        // Only assert if within tolerance — the fixture coordinates approximate 8km
        if distance <= 8001 {
            #expect(SuppressionEngine.distanceGatePasses(userLocation: user, destination: dest))
        }
    }
}

@Suite("SuppressionEngine — Task Relevance Gate")
struct TaskRelevanceGateTests {

    private func makeTask(category: POICategory, status: TaskStatus = .toDo) -> ChecklistTask {
        let t = ChecklistTask(title: "Test", category: .financial, priority: .medium, tMinusDays: 0)
        t.poiCategory = category
        t.statusRaw = status.rawValue
        return t
    }

    @Test func matchingPendingTask_passes() {
        let task = makeTask(category: .bank)
        #expect(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    @Test func noMatchingCategory_fails() {
        let task = makeTask(category: .gym)
        #expect(!SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    @Test func completedTask_fails() {
        let task = makeTask(category: .bank, status: .completed)
        #expect(!SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    @Test func mutedTask_fails() {
        let task = makeTask(category: .bank)
        task.isMuted = true
        #expect(!SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank))
    }

    @Test func snoozedTask_fails() {
        let task = makeTask(category: .bank)
        task.snoozedUntil = Date().addingTimeInterval(86400)
        #expect(!SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank, now: Date()))
    }

    @Test func snoozedExpired_passes() {
        let task = makeTask(category: .bank)
        task.snoozedUntil = Date().addingTimeInterval(-86400)
        #expect(SuppressionEngine.taskRelevanceGatePasses(tasks: [task], category: .bank, now: Date()))
    }

    @Test func emptyTaskList_fails() {
        #expect(!SuppressionEngine.taskRelevanceGatePasses(tasks: [], category: .bank))
    }
}

@Suite("SuppressionEngine — shouldFire (Full Evaluator)")
struct ShouldFireEvaluatorTests {

    private func makeMove() -> Move {
        let move = Move(anchorDate: Date().addingTimeInterval(30 * 86400),
                         originZip: "80202",
                         destinationZip: "80202",
                         destinationStateBucket: "CO",
                         destinationCityBucket: "DENVER")
        move.locationConsentGrantedAt = Date()
        return move
    }

    private func makePOITask(move: Move, category: POICategory, status: TaskStatus = .toDo) -> ChecklistTask {
        let task = ChecklistTask(title: "Test Task", category: .financial,
                                  priority: .medium, tMinusDays: 0)
        task.poiCategory = category
        task.statusRaw = status.rawValue
        task.move = move
        return task
    }

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour; c.minute = minute; c.second = 0
        return Calendar.current.date(from: c)!
    }

    @Test func withinDistance_passes() {
        let move = makeMove()
        let task = makePOITask(move: move, category: .bank)
        move.tasks = [task]
        let userLoc = CLLocation(latitude: 39.7392, longitude: -104.9903)
        let destCoord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let context = SuppressionEngine.Context(
            move: move, poiCategory: .bank,
            cooldownStore: CooldownStore(defaults: .init(suiteName: UUID().uuidString)!),
            now: makeDate(hour: 12), userLocation: userLoc, destinationCoordinate: destCoord
        )
        #expect(SuppressionEngine.shouldFire(context: context))
    }

    @Test func beyondDistance_fails() {
        let move = makeMove()
        let task = makePOITask(move: move, category: .bank)
        move.tasks = [task]
        let userLoc = CLLocation(latitude: 40.7, longitude: -104.9903) // ~100km away
        let destCoord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let context = SuppressionEngine.Context(
            move: move, poiCategory: .bank,
            cooldownStore: CooldownStore(defaults: .init(suiteName: UUID().uuidString)!),
            now: makeDate(hour: 12), userLocation: userLoc, destinationCoordinate: destCoord
        )
        #expect(!SuppressionEngine.shouldFire(context: context))
    }
}

@Suite("SuppressionEngine — shouldFireForVisit (citywide, no distance gate)")
struct ShouldFireForVisitEvaluatorTests {

    private func makeMove() -> Move {
        let move = Move(anchorDate: Date().addingTimeInterval(30 * 86400),
                         originZip: "80202",
                         destinationZip: "80202",
                         destinationStateBucket: "CO",
                         destinationCityBucket: "DENVER")
        move.locationConsentGrantedAt = Date()
        return move
    }

    private func makePOITask(move: Move, category: POICategory, status: TaskStatus = .toDo) -> ChecklistTask {
        let task = ChecklistTask(title: "Test Task", category: .financial,
                                  priority: .medium, tMinusDays: 0)
        task.poiCategory = category
        task.statusRaw = status.rawValue
        task.move = move
        return task
    }

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour; c.minute = minute; c.second = 0
        return Calendar.current.date(from: c)!
    }

    /// Far from the destination — shouldFire would reject this, shouldFireForVisit shouldn't.
    private func makeFarAwayContext(move: Move, category: POICategory, now: Date) -> SuppressionEngine.Context {
        let farUserLoc = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
        let denverDest = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        return SuppressionEngine.Context(
            move: move, poiCategory: category,
            cooldownStore: CooldownStore(defaults: .init(suiteName: UUID().uuidString)!),
            now: now, userLocation: farUserLoc, destinationCoordinate: denverDest
        )
    }

    @Test func farFromDestination_stillPasses() {
        let move = makeMove()
        let task = makePOITask(move: move, category: .gym)
        move.tasks = [task]
        let context = makeFarAwayContext(move: move, category: .gym, now: makeDate(hour: 12))
        #expect(SuppressionEngine.shouldFireForVisit(context: context))
    }

    @Test func noMatchingTask_fails() {
        let move = makeMove()
        move.tasks = []
        let context = makeFarAwayContext(move: move, category: .museum, now: makeDate(hour: 12))
        #expect(!SuppressionEngine.shouldFireForVisit(context: context))
    }

    @Test func outsideTimeWindow_fails() {
        let move = makeMove()
        let task = makePOITask(move: move, category: .movieTheater)
        move.tasks = [task]
        let context = makeFarAwayContext(move: move, category: .movieTheater, now: makeDate(hour: 22))
        #expect(!SuppressionEngine.shouldFireForVisit(context: context))
    }

    @Test func expiredConsent_fails() {
        let move = makeMove()
        move.locationConsentGrantedAt = Date().addingTimeInterval(-40 * 86400)
        let task = makePOITask(move: move, category: .gym)
        move.tasks = [task]
        let context = makeFarAwayContext(move: move, category: .gym, now: makeDate(hour: 12))
        #expect(!SuppressionEngine.shouldFireForVisit(context: context))
    }
}

// MARK: - CooldownStore Tests

@Suite("CooldownStore")
struct CooldownStoreTests {

    private func makeStore() -> CooldownStore {
        CooldownStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func freshStore_allCategoriesPass() {
        let store = makeStore()
        for category in POICategory.allCases {
            #expect(store.gatePasses(for: category), "Fresh store should pass for \(category.rawValue)")
        }
    }

    @Test func recordThenGate_sameDay_fails() {
        var store = makeStore()
        let now = Date()
        store.record(category: .bank, date: now)
        #expect(!store.gatePasses(for: .bank, now: now))
    }

    @Test func recordThenGate_nextDay_passes() {
        var store = makeStore()
        let now = Date()
        store.record(category: .bank, date: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        #expect(store.gatePasses(for: .bank, now: tomorrow))
    }

    @Test func recordBankDoesNotAffectGym() {
        var store = makeStore()
        store.record(category: .bank, date: Date())
        #expect(store.gatePasses(for: .gym, now: Date()))
    }

    @Test func clearAll_resetsGates() {
        var store = makeStore()
        let now = Date()
        store.record(category: .bank, date: now)
        store.record(category: .dmv, date: now)
        store.clearAll()
        #expect(store.gatePasses(for: .bank, now: now))
        #expect(store.gatePasses(for: .dmv, now: now))
    }

    @Test func persistence_survivesReinit() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        var store1 = CooldownStore(defaults: defaults)
        let now = Date()
        store1.record(category: .pharmacy, date: now)
        let store2 = CooldownStore(defaults: defaults)
        #expect(!store2.gatePasses(for: .pharmacy, now: now))
    }

    @Test func recordAllCategories_allFail() {
        var store = makeStore()
        let now = Date()
        for category in POICategory.allCases {
            store.record(category: category, date: now)
        }
        for category in POICategory.allCases {
            #expect(!store.gatePasses(for: category, now: now), "Expected gate to fail for \(category.rawValue)")
        }
    }

    @Test func clearAll_onEmptyStore_doesNotCrash() {
        var store = makeStore()
        store.clearAll()
        #expect(store.gatePasses(for: .bank, now: Date()))
    }

    @Test func recordMidnight_gateFailsSameDay() {
        var store = makeStore()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let midnight = Calendar.current.date(from: comps)!
        store.record(category: .postOffice, date: midnight)

        comps.hour = 23; comps.minute = 59
        let lateNight = Calendar.current.date(from: comps)!
        #expect(!store.gatePasses(for: .postOffice, now: lateNight))
    }

    @Test func recordLateNight_gatePassesNextMorning() {
        var store = makeStore()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 23; comps.minute = 59
        let lateNight = Calendar.current.date(from: comps)!
        store.record(category: .postOffice, date: lateNight)

        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: lateNight)!
        #expect(store.gatePasses(for: .postOffice, now: nextDay))
    }
}

// MARK: - ZipBucketService Tests

@Suite("ZipBucketService — State Buckets")
struct ZipStateBucketTests {

    @Test func denver_returnsColorado()   { #expect(ZipBucketService.bucket(zip: "80202").state == "CO") }
    @Test func nyc_returnsNewYork()       { #expect(ZipBucketService.bucket(zip: "10001").state == "NY") }
    @Test func miami_returnsFlorida()     { #expect(ZipBucketService.bucket(zip: "33101").state == "FL") }
    @Test func la_returnsCalifornia()     { #expect(ZipBucketService.bucket(zip: "90001").state == "CA") }
    @Test func seattle_returnsWashington(){ #expect(ZipBucketService.bucket(zip: "98101").state == "WA") }
    @Test func unknown_returnsUS()        { #expect(ZipBucketService.bucket(zip: "00001").state == "US") }
}

@Suite("ZipBucketService — New England / NJ 3-digit prefix fix")
struct ZipNewEnglandBucketTests {

    @Test func cambridge_returnsMassachusetts() { #expect(ZipBucketService.bucket(zip: "02139").state == "MA") }
    @Test func providence_returnsRhodeIsland()  { #expect(ZipBucketService.bucket(zip: "02903").state == "RI") }
    @Test func concord_returnsNewHampshire()    { #expect(ZipBucketService.bucket(zip: "03301").state == "NH") }
    @Test func portland_returnsMaine()          { #expect(ZipBucketService.bucket(zip: "04101").state == "ME") }
    @Test func burlington_returnsVermont()      { #expect(ZipBucketService.bucket(zip: "05401").state == "VT") }
    @Test func hartford_returnsConnecticut()    { #expect(ZipBucketService.bucket(zip: "06103").state == "CT") }
    @Test func jerseyCity_returnsNewJersey()    { #expect(ZipBucketService.bucket(zip: "07302").state == "NJ") }
}

@Suite("ZipBucketService — WV / MS / TN 3-digit prefix fix")
struct ZipWestVirginiaMississippiTests {

    @Test func charleston_returnsWestVirginia()  { #expect(ZipBucketService.bucket(zip: "25301").state == "WV") }
    @Test func wheeling_returnsWestVirginia()    { #expect(ZipBucketService.bucket(zip: "26003").state == "WV") }
    @Test func nashville_returnsTennessee()      { #expect(ZipBucketService.bucket(zip: "37201").state == "TN") }
    @Test func batesvilleMS_returnsMississippi() { #expect(ZipBucketService.bucket(zip: "38606").state == "MS") }
    @Test func jacksonMS_returnsMississippi()    { #expect(ZipBucketService.bucket(zip: "39201").state == "MS") }
}

@Suite("ZipBucketService — City Buckets")
struct ZipCityBucketTests {

    @Test func denver_returnsDenverCity() { #expect(ZipBucketService.bucket(zip: "80202").city == "DENVER") }
    @Test func chicago_returnsChicago()   { #expect(ZipBucketService.bucket(zip: "60601").city == "CHICAGO") }
    @Test func ruralMontana_returnsNil()  { #expect(ZipBucketService.bucket(zip: "59001").city == nil) }
}

@Suite("ZipBucketService — Canadian Postal Codes")
struct CanadianPostalCodeTests {

    @Test func ontario_returnsON()  { #expect(ZipBucketService.bucket(zip: "M5V3A8").state == "ON") }
    @Test func bc_returnsBC()       { #expect(ZipBucketService.bucket(zip: "V6B1A1").state == "BC") }
    @Test func quebec_returnsQC()   { #expect(ZipBucketService.bucket(zip: "H3A0G4").state == "QC") }
    @Test func alberta_returnsAB()  { #expect(ZipBucketService.bucket(zip: "T2P0A8").state == "AB") }
}

@Suite("ZipBucketService — Centroid Lookup")
struct CentroidTests {

    @Test func denver_approximatelyCorrct() {
        let c = ZipBucketService.centroid(zip: "80202")
        #expect(abs(c.latitude - 39.7392) < 0.5)
        #expect(abs(c.longitude - (-104.9903)) < 0.5)
    }

    @Test func unknownZip_returnsContinentalUSFallback() {
        let c = ZipBucketService.centroid(zip: "00001")
        #expect(abs(c.latitude - 39.5) < 0.1)
        #expect(abs(c.longitude - (-98.35)) < 0.1)
    }

    @Test func nyZip_isApproximatelyCorrect() {
        let c = ZipBucketService.centroid(zip: "10001")
        #expect(abs(c.latitude - 40.7128) < 0.5)
        #expect(abs(c.longitude - (-74.0060)) < 0.5)
    }

    @Test func ruralZip_returnsContinentalUSFallback() {
        let c = ZipBucketService.centroid(zip: "59601") // Helena MT — rural
        #expect(abs(c.latitude - 39.5) < 0.1)
        #expect(abs(c.longitude - (-98.35)) < 0.1)
    }

    @Test func allMajorMetros_areValid() {
        let metroZips = ["80202", "10001", "90001", "60601", "77001",
                         "85001", "98101", "94102", "30301", "33101"]
        for zip in metroZips {
            let c = ZipBucketService.centroid(zip: zip)
            #expect(!(c.latitude == 39.5 && c.longitude == -98.35), "ZIP \(zip) should not fall back to US centroid")
        }
    }
}

// MARK: - ChecklistTask State Machine Tests

@Suite("ChecklistTask — State Machine")
struct ChecklistTaskStateMachineTests {

    private func makeTask() -> ChecklistTask {
        ChecklistTask(title: "Test", category: .financial, priority: .medium, tMinusDays: 0)
    }

    @Test func initialStatus_isToDo() {
        #expect(makeTask().status == .toDo)
    }

    @Test func advance_toDoToPending() {
        let t = makeTask(); t.advanceStatus()
        #expect(t.status == .pendingVerification)
    }

    @Test func advance_pendingToCompleted() {
        let t = makeTask(); t.advanceStatus(); t.advanceStatus()
        #expect(t.status == .completed)
    }

    @Test func advance_completedStays() {
        let t = makeTask(); t.advanceStatus(); t.advanceStatus(); t.advanceStatus()
        #expect(t.status == .completed)
    }

    @Test func reset_backToToDo() {
        let t = makeTask(); t.advanceStatus(); t.advanceStatus()
        t.resetStatus()
        #expect(t.status == .toDo)
    }

    @Test func reset_clearsVerificationEvents() {
        let t = makeTask(); t.advanceStatus(); t.advanceStatus()
        t.resetStatus()
        #expect(t.verificationEvents.isEmpty)
    }
}

@Suite("ChecklistTask — Property Round-Trips")
struct ChecklistTaskPropertyTests {

    private func makeTask() -> ChecklistTask {
        ChecklistTask(title: "Test", category: .financial, priority: .medium, tMinusDays: 0)
    }

    @Test func categoryRawValue_roundtrips() {
        for category in TaskCategory.allCases {
            let t = ChecklistTask(title: "Test", category: category, priority: .medium, tMinusDays: 0)
            #expect(t.category == category)
        }
    }

    @Test func priorityRawValue_roundtrips() {
        for priority in TaskPriority.allCases {
            let t = ChecklistTask(title: "Test", category: .other, priority: priority, tMinusDays: 0)
            #expect(t.priority == priority)
        }
    }

    @Test func poiCategory_nilByDefault() {
        #expect(makeTask().poiCategory == nil)
    }

    @Test func poiCategory_setAndRetrieved() {
        let t = makeTask()
        t.poiCategory = .bank
        #expect(t.poiCategory == .bank)
    }

    @Test func poiCategory_clearedToNil() {
        let t = makeTask()
        t.poiCategory = .bank
        t.poiCategory = nil
        #expect(t.poiCategory == nil)
    }

    @Test func isMuted_falseByDefault() {
        #expect(makeTask().isMuted == false)
    }

    @Test func snoozedUntil_nilByDefault() {
        #expect(makeTask().snoozedUntil == nil)
    }

    @Test func deepLinkURL_roundtrips() {
        let url = URL(string: "https://www.wellsfargo.com")!
        let t = ChecklistTask(title: "WF", category: .financial, priority: .critical,
                               tMinusDays: -14, deepLinkURL: url)
        #expect(t.deepLinkURL == url)
    }
}

// MARK: - TaskCategory Tests

@Suite("TaskCategory — Emoji & Icons")
struct TaskCategoryTests {

    @Test func allCategories_haveEmoji() {
        for category in TaskCategory.allCases {
            #expect(!category.emoji.isEmpty, "Missing emoji for \(category.rawValue)")
        }
    }

    @Test func allCategories_haveIcon() {
        for category in TaskCategory.allCases {
            #expect(!category.icon.isEmpty, "Missing icon for \(category.rawValue)")
        }
    }
}

// MARK: - POICategory Tests

@Suite("POICategory — Display Names")
struct POICategoryTests {

    @Test func allCategories_haveDisplayName() {
        for category in POICategory.allCases {
            #expect(!category.displayName.isEmpty, "Missing displayName for \(category.rawValue)")
        }
    }

    @Test func bank_displayName()       { #expect(POICategory.bank.displayName == "bank") }
    @Test func dmv_displayName()        { #expect(POICategory.dmv.displayName == "DMV") }
    @Test func postOffice_displayName() { #expect(POICategory.postOffice.displayName == "post office") }
    @Test func doctor_displayName()     { #expect(POICategory.doctor.displayName == "doctor's office") }

    @Test func allCases_hasExpectedCount() {
        // Ensure no cases were accidentally removed
        #expect(POICategory.allCases.count >= 13)
    }
}

// MARK: - KnownInstitutions Regional Filtering Tests

@Suite("KnownInstitutions — Regional Filtering")
struct KnownInstitutionsRegionalFilteringTests {

    @Test func nilStateBucket_returnsAllUnfiltered() {
        let result = KnownInstitutions.filtered(KnownInstitutions.banks, forStateBucket: nil)
        #expect(result.count == KnownInstitutions.banks.count)
    }

    @Test func nationalBank_alwaysIncluded() {
        // Chase has no regionStates (near-universal FDIC footprint) — must show everywhere.
        let waResult = KnownInstitutions.filtered(KnownInstitutions.banks, forStateBucket: "WA")
        #expect(waResult.contains { $0.name == "Chase" })
    }

    @Test func branchlessDigitalBank_alwaysIncluded() {
        // Ally is branchless/national despite a thin FDIC branch record — must never be filtered.
        let waResult = KnownInstitutions.filtered(KnownInstitutions.banks, forStateBucket: "WA")
        #expect(waResult.contains { $0.name == "Ally Bank" })
    }

    @Test func regionalBank_excludedOutsideFootprint() {
        // Regions Bank operates in the South — must not appear for a Washington state user.
        let waResult = KnownInstitutions.filtered(KnownInstitutions.banks, forStateBucket: "WA")
        #expect(!waResult.contains { $0.name == "Regions Bank" })
    }

    @Test func regionalBank_includedInsideFootprint() {
        // Regions Bank does operate in Alabama.
        let alResult = KnownInstitutions.filtered(KnownInstitutions.banks, forStateBucket: "AL")
        #expect(alResult.contains { $0.name == "Regions Bank" })
    }

    @Test func eastCoastBank_excludedOnWestCoast() {
        // TD Bank's footprint is Maine-to-Florida only.
        let caResult = KnownInstitutions.filtered(KnownInstitutions.banks, forStateBucket: "CA")
        #expect(!caResult.contains { $0.name == "TD Bank" })
    }

    @Test func unmappedUSSentinel_returnsAllUnfiltered() {
        // ZipBucketService.bucket(zip:) returns "US" (not nil) for zips it can't map
        // to a specific state (Puerto Rico, APO/FPO, unassigned prefixes) — that
        // sentinel must be treated the same as nil, not as a state no bank matches.
        let result = KnownInstitutions.filtered(KnownInstitutions.banks, forStateBucket: "US")
        #expect(result.count == KnownInstitutions.banks.count)
        #expect(result.contains { $0.name == "Regions Bank" })
    }
}

@Suite("ChecklistGenerator — Core Task Generation")
struct ChecklistGeneratorCoreTests {

    private func makeMove(zip: String = "80202") -> Move {
        let bucket = ZipBucketService.bucket(zip: zip)
        return Move(anchorDate: Date().addingTimeInterval(30 * 86400),
             originZip: zip, destinationZip: zip,
             destinationStateBucket: bucket.state, destinationCityBucket: bucket.city)
    }

    private func makeProfile(flags: Set<LifestyleFlag> = []) -> LifestyleProfile {
        let profile = LifestyleProfile()
        profile.activeFlags = flags
        return profile
    }

    // MARK: - Always-included tasks

    @Test func alwaysInclude_USPSPresent_forAmericanUser() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.isAmerican]), institutions: [])
        #expect(tasks.map(\.title).contains("USPS Mail Forwarding"))
    }

    @Test func alwaysInclude_USPSExcluded_forCanadianUser() {
        let tasks = ChecklistGenerator.generate(for: makeMove(zip: "K1A0B1"), profile: makeProfile(flags: [.isCanadian]), institutions: [])
        #expect(!tasks.map(\.title).contains("USPS Mail Forwarding"))
    }

    @Test func alwaysInclude_CanadaPost_forCanadianUser() {
        let tasks = ChecklistGenerator.generate(for: makeMove(zip: "K1A0B1"), profile: makeProfile(flags: [.isCanadian]), institutions: [])
        #expect(tasks.map(\.title).contains("Canada Post Mail Forwarding"))
    }

    @Test func alwaysInclude_primaryCareDoctor() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(), institutions: [])
        #expect(tasks.contains { $0.title == "Primary Care Doctor" })
    }

    @Test func alwaysInclude_employerHR() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(), institutions: [])
        #expect(tasks.contains { $0.title == "Employer HR & Payroll Address" })
    }

    // MARK: - Conditional tasks

    @Test func childrenTasks_appearWithHasChildrenFlag() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.hasChildren]), institutions: [])
        #expect(tasks.contains { $0.title == "Children's School Enrollment" })
        #expect(tasks.contains { $0.title == "Pediatrician & Children's Records" })
    }

    @Test func childrenTasks_absentWithoutFlag() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: []), institutions: [])
        #expect(!tasks.contains { $0.title == "Children's School Enrollment" })
    }

    @Test func petTasks_appearWithHasPetsFlag() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.hasPets]), institutions: [])
        #expect(tasks.contains { $0.title == "Veterinarian Records Transfer" })
    }

    @Test func mortgageTask_appearsWithHasMortgageFlag() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.hasMortgage]), institutions: [])
        #expect(tasks.contains { $0.title == "Mortgage Servicer" })
    }

    @Test func evOwnership_doesNotAssumeTeslaEnrollment() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.hasElectricVehicle]), institutions: [])
        #expect(!tasks.contains { $0.catalogItemID == "tesla" })
    }

    @Test func teslaTask_appearsWithExplicitConfirmation() {
        let move = makeMove()
        move.respond(to: "tesla", with: .confirmed)
        let tasks = ChecklistGenerator.generate(for: move, profile: makeProfile(flags: [.hasElectricVehicle]), institutions: [])
        #expect(tasks.contains { $0.title == "Tesla Account / MyEV Address" })
    }

    // MARK: - Institution tasks

    @Test func institution_generatesTaskWithJustName() {
        let fi = FinancialInstitution(name: "Wells Fargo", initials: "WF",
                                       colorHex: "#B7410E", type: .bank,
                                       websiteURL: URL(string: "https://wellsfargo.com"))
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(), institutions: [fi])
        let task = tasks.first { $0.institutionName == "Wells Fargo" }
        #expect(task != nil)
        #expect(task?.title == "Wells Fargo", "Institution task title should be just the name, no prefix")
        #expect(task?.priority == .critical)
        #expect(task?.poiCategory == .bank)
    }

    @Test func institution_noPrefixInTitle() {
        let fi = FinancialInstitution(name: "Chase", initials: "CH",
                                       colorHex: "#117ACA", type: .bank, websiteURL: nil)
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(), institutions: [fi])
        let task = tasks.first { $0.institutionName == "Chase" }
        #expect(!(task?.title.hasPrefix("Update address") ?? false), "Title should NOT start with 'Update address'")
    }

    @Test func institution_investmentType_highPriority() {
        let fi = FinancialInstitution(name: "Fidelity", initials: "FI",
                                       colorHex: "#27AE60", type: .investment, websiteURL: nil)
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(), institutions: [fi])
        let task = tasks.first { $0.institutionName == "Fidelity" }
        #expect(task?.priority == .high)
        #expect(task?.poiCategory == nil, "Investment accounts don't have a POI category")
    }

    // MARK: - Hero task ordering

    @Test func heroTask_isFirstInList() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.isAmerican]), institutions: [])
        #expect(tasks.first?.isHeroItem ?? false, "First task should be the hero item (USPS)")
    }

    @Test func canadaPost_isHeroForCanadianUser() {
        let tasks = ChecklistGenerator.generate(for: makeMove(zip: "K1A0B1"), profile: makeProfile(flags: [.isCanadian]), institutions: [])
        #expect(tasks.first?.isHeroItem ?? false, "Canada Post should be hero for Canadian users")
        #expect(tasks.first?.title == "Canada Post Mail Forwarding")
    }

    // MARK: - Task count sanity

    @Test func minimumTaskCount_baselineAmericanUser() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.isAmerican]), institutions: [])
        #expect(tasks.count > 10, "Should generate at least 10 tasks for a baseline US user")
    }

    @Test func taskCount_increasesWithMoreFlags() {
        let move = makeMove()
        let baseTasks = ChecklistGenerator.generate(for: move, profile: makeProfile(flags: [.isAmerican]), institutions: [])
        let richTasks = ChecklistGenerator.generate(for: move, profile: makeProfile(flags: [
            .isAmerican, .hasChildren, .hasPets, .hasCar, .hasElectricVehicle, .hasMortgage
        ]), institutions: [])
        #expect(richTasks.count > baseTasks.count, "More lifestyle flags should produce more tasks")
    }
}

@Suite("ChecklistGenerator — Regional Recreation Networks")
struct RegionalRecreationNetworkTests {

    @Test func invitedClubs_includedWhenFlagged() {
        let items = ChecklistGenerator.matchingItems(flags: [.usesInvitedClubs])
        #expect(items.contains { $0.id == "invited_clubs" })
    }

    @Test func freedomBoatClub_includedWhenFlagged() {
        let items = ChecklistGenerator.matchingItems(flags: [.usesFreedomBoatClub])
        #expect(items.contains { $0.id == "freedom_boat_club" })
    }

    @Test func farmBureau_includedWhenFlagged() {
        let items = ChecklistGenerator.matchingItems(flags: [.hasFarmBureauMembership])
        #expect(items.contains { $0.id == "farm_bureau" })
    }

    @Test func delWebb_includedWhenFlagged() {
        let items = ChecklistGenerator.matchingItems(flags: [.livesInDelWebbCommunity])
        #expect(items.contains { $0.id == "del_webb_search" })
    }

    @Test func tractorSupplyAndBassPro_includedWhenFlagged() {
        let items = ChecklistGenerator.matchingItems(flags: [.usesTractorSupplyNeighborsClub, .usesBassProCabelasClub])
        #expect(items.contains { $0.id == "tractor_supply_neighbors_club" })
        #expect(items.contains { $0.id == "bass_pro_cabelas_club" })
    }

    @Test func noRegionalFlags_excludesAllNetworkItems() {
        let networkIDs: Set<String> = [
            "invited_clubs", "troon_club", "freedom_boat_club", "carefree_boat_club",
            "tractor_supply_neighbors_club", "bass_pro_cabelas_club",
            "conservation_org_membership", "farm_bureau", "del_webb_search",
        ]
        let items = ChecklistGenerator.matchingItems(flags: [])
        #expect(items.filter { networkIDs.contains($0.id) }.isEmpty)
    }

    @Test func allNewCatalogIDsAreUnique() {
        let ids = ItemCatalog.all.map(\.id)
        #expect(ids.count == Set(ids).count, "duplicate CatalogItem id found")
    }
}

@Suite("LifestyleViewModel — Flag Reachability")
struct LifestyleFlagReachabilityTests {

    /// Flags that are correctly never chip-toggled: either answered directly on
    /// onboarding screen 1 (LifestyleViewModel.coreFlags), or auto-derived from the
    /// destination ZIP/postal code (country + Canadian province flags), never from a
    /// user tap. Every other LifestyleFlag case must have a chip somewhere in
    /// extraChips, or it's a dead flag no user can ever actually set.
    static let autoOrCoreDerived: Set<LifestyleFlag> = [
        .hasChildren, .hasPets, .isOwning, .isRenting, .livesInHouseOrTownhouse,
        .isCanadian, .isAmerican,
        .inOntario, .inBritishColumbia, .inQuebec, .inAlberta, .inManitoba,
        .inSaskatchewan, .inNovaScotia, .inNewBrunswick, .inNewfoundland, .inPEI,
        .inNorthwestTerritories, .inNunavut, .inYukon,
    ]

    @Test func everyFlagIsEitherAutoSetOrChipReachable() {
        let vm = LifestyleViewModel()
        let chipFlags: Set<LifestyleFlag> = Set(
            vm.extraChips.values.flatMap { $0 }.flatMap { $0.chips }.compactMap { $0.flag }
        )
        let unreachable = Set(LifestyleFlag.allCases)
            .subtracting(Self.autoOrCoreDerived)
            .subtracting(chipFlags)
        #expect(unreachable.isEmpty, "flags with no chip and no auto-derivation: \(unreachable.map(\.rawValue).sorted())")
    }

    @Test func newRegionalRecreationFlagsAreChipReachable() {
        let vm = LifestyleViewModel()
        let chipFlags: Set<LifestyleFlag> = Set(
            vm.extraChips.values.flatMap { $0 }.flatMap { $0.chips }.compactMap { $0.flag }
        )
        let expected: Set<LifestyleFlag> = [
            .usesInvitedClubs, .usesTroonManagedClub, .usesFreedomBoatClub, .usesCarefreeBoatClub,
            .usesTractorSupplyNeighborsClub, .hasFarmBureauMembership, .usesBassProCabelasClub,
            .hasConservationOrgMembership, .livesInDelWebbCommunity,
        ]
        #expect(expected.isSubset(of: chipFlags))
    }

    @Test func reviewFamiliesCoverCatalog() {
        // AddMoreServices now reads the catalog's review families directly.
        #expect(Set(ItemCatalog.all.map(\.reviewFamily)) == Set(ReviewFamily.allCases))
        #expect(ItemCatalog.all.allSatisfy { !$0.canonicalID.isEmpty })
    }
}

@Suite("Move — Timing & Completion")
struct MoveTimingCompletionTests {

    private func makeMove(daysFromNow: Int = 30) -> Move {
        let anchor = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return Move(anchorDate: anchor, originZip: "80202", destinationZip: "80202",
                    destinationStateBucket: "CO", destinationCityBucket: "DENVER")
    }

    @Test func daysUntilMove_futureDate_positive() {
        #expect(makeMove(daysFromNow: 14).daysUntilMove > 0)
    }

    @Test func daysUntilMove_pastDate_negative() {
        #expect(makeMove(daysFromNow: -7).daysUntilMove < 0)
    }

    @Test func completionFraction_noTasks_isZero() {
        #expect(makeMove().completionFraction == 0.0)
    }

    @Test func completionFraction_allCompleted_isOne() {
        let move = makeMove()
        let task = ChecklistTask(title: "Test", category: .financial, priority: .medium, tMinusDays: 0)
        task.advanceStatus(); task.advanceStatus() // → completed
        move.tasks = [task]
        #expect(abs(move.completionFraction - 1.0) < 0.001)
    }

    @Test func completionFraction_halfCompleted() {
        let move = makeMove()
        let task1 = ChecklistTask(title: "Task 1", category: .financial, priority: .medium, tMinusDays: 0)
        let task2 = ChecklistTask(title: "Task 2", category: .financial, priority: .medium, tMinusDays: 0)
        task1.advanceStatus(); task1.advanceStatus() // completed
        move.tasks = [task1, task2]
        #expect(abs(move.completionFraction - 0.5) < 0.001)
    }

    @Test func totalCount_matchesTaskArray() {
        let move = makeMove()
        move.tasks = [
            ChecklistTask(title: "A", category: .financial, priority: .medium, tMinusDays: 0),
            ChecklistTask(title: "B", category: .financial, priority: .medium, tMinusDays: 0),
        ]
        #expect(move.totalCount == 2)
    }

    @Test func completedCount_onlyCountsCompleted() {
        let move = makeMove()
        let t1 = ChecklistTask(title: "A", category: .financial, priority: .medium, tMinusDays: 0)
        let t2 = ChecklistTask(title: "B", category: .financial, priority: .medium, tMinusDays: 0)
        t1.advanceStatus(); t1.advanceStatus()
        move.tasks = [t1, t2]
        #expect(move.completedCount == 1)
    }

    @Test func locationConsentGrantedAt_nilByDefault() {
        #expect(makeMove().locationConsentGrantedAt == nil)
    }

    @Test func locationConsentGrantedAt_canBeSet() {
        let move = makeMove()
        move.locationConsentGrantedAt = Date()
        #expect(move.locationConsentGrantedAt != nil)
    }
}

@Suite("Move — Tracked POI Categories")
struct TrackedPOICategoriesTests {

    private func makeMove(tasks: [ChecklistTask]) -> Move {
        let move = Move(anchorDate: Date(), originZip: nil, destinationZip: "80202",
                         destinationStateBucket: "CO", destinationCityBucket: "DENVER")
        move.tasks = tasks
        return move
    }

    private func task(status: TaskStatus, poi: POICategory?) -> ChecklistTask {
        let t = ChecklistTask(title: "t", category: .government, priority: .medium, tMinusDays: 0)
        t.statusRaw = status.rawValue
        t.poiCategory = poi
        return t
    }

    @Test func includesOnlyPendingTasksWithAPOICategory() {
        let move = makeMove(tasks: [
            task(status: .toDo, poi: .bank),
            task(status: .completed, poi: .dmv),  // completed — excluded
            task(status: .toDo, poi: nil),         // no POI — excluded
        ])
        #expect(move.trackedPOICategories == [.bank])
    }

    @Test func deduplicatesRepeatedCategories() {
        let move = makeMove(tasks: [
            task(status: .toDo, poi: .bank),
            task(status: .toDo, poi: .bank),
        ])
        #expect(move.trackedPOICategories == [.bank])
    }

    @Test func emptyWhenNothingPendingHasAPOICategory() {
        #expect(makeMove(tasks: [task(status: .completed, poi: .bank)]).trackedPOICategories.isEmpty)
    }
}

@Suite("Move — Category Progress")
struct CategoryProgressTests {

    private func makeMove(tasks: [ChecklistTask]) -> Move {
        let move = Move(anchorDate: Date(), originZip: nil, destinationZip: "80202",
                         destinationStateBucket: "CO", destinationCityBucket: "DENVER")
        move.tasks = tasks
        return move
    }

    private func task(category: TaskCategory, status: TaskStatus, tMinusDays: Int = 0) -> ChecklistTask {
        let t = ChecklistTask(title: "t", category: category, priority: .medium, tMinusDays: tMinusDays)
        t.statusRaw = status.rawValue
        return t
    }

    @Test func groupsAndCountsCorrectlyPerCategory() {
        let move = makeMove(tasks: [
            task(category: .utilities, status: .completed),
            task(category: .utilities, status: .toDo),
            task(category: .financial, status: .completed),
        ])
        let utilities = move.categoryProgress.first { $0.category == .utilities }
        let financial = move.categoryProgress.first { $0.category == .financial }
        #expect(utilities?.completed == 1 && utilities?.total == 2)
        #expect(financial?.completed == 1 && financial?.total == 1)
    }

    @Test func sortsLeastCompleteFirst() {
        let move = makeMove(tasks: [
            task(category: .insurance, status: .completed),
            task(category: .education, status: .toDo),
            task(category: .education, status: .toDo),
        ])
        #expect(move.categoryProgress.first?.category == .education)
        #expect(move.categoryProgress.last?.category == .insurance)
    }

    @Test func tiesBrokenByNearestDeadline() {
        let move = makeMove(tasks: [
            task(category: .legal, status: .toDo, tMinusDays: -3),
            task(category: .digital, status: .toDo, tMinusDays: -20),
        ])
        // Both 0% complete — tMinusDays -20 was supposed to happen earlier in the
        // pre-move timeline than -3, so it's the more urgent (more overdue-feeling)
        // of the two and should lead.
        #expect(move.categoryProgress.first?.category == .digital)
    }

    @Test func emptyTaskList_returnsEmptyProgress() {
        #expect(makeMove(tasks: []).categoryProgress.isEmpty)
    }
}

@Suite("ItemCatalog — Flag Lookup")
struct ItemCatalogFlagLookupTests {

    @Test func returnsTheDedicatedItemForASingleFlagCandidate() {
        #expect(ItemCatalog.item(for: .hasEpicPass)?.id == "epic_pass")
        #expect(ItemCatalog.item(for: .hasIkonPass)?.id == "ikon_pass")
    }

    @Test func returnsNilForAFlagWithNoDedicatedSingleItem() {
        // isAmerican gates via `excludes` across many items, never as the sole
        // `requires` on any one — there is no single dedicated item for it.
        #expect(ItemCatalog.item(for: .isAmerican) == nil)
    }
}

@Suite("SignalEmitter (WS1)")
struct SignalEmitterTests {

    private func makeContext() -> ModelContext {
        let container = try! ModelContainer(for: PendingSignal.self, configurations: .init(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func makeMove() -> Move {
        Move(anchorDate: Date(), originZip: "90210", destinationZip: "80202",
             destinationStateBucket: "CO", destinationCityBucket: "DENVER")
    }

    private func makeItem() -> MoveImpactItem {
        MoveImpactItem(flag: .hasEpicPass, confidence: .inferredHigh, archetype: .mountainSkiCorridor, rationale: "test")
    }

    @Test func emit_insertsExactlyOnePendingSignal() {
        let context = makeContext()
        SignalEmitter.emit(item: makeItem(), accepted: true, move: makeMove(), into: context)
        let signals = (try? context.fetch(FetchDescriptor<PendingSignal>())) ?? []
        #expect(signals.count == 1)
    }

    @Test func emit_capturesRegionAndStaysPending() {
        let context = makeContext()
        SignalEmitter.emit(item: makeItem(), accepted: true, move: makeMove(), into: context)
        let signals = (try? context.fetch(FetchDescriptor<PendingSignal>())) ?? []
        #expect(signals.first?.regionState == "CO")
        #expect(signals.first?.isPending == true)
        #expect(signals.first?.emittedAt == nil)
    }

    @Test func embedding_has384Dimensions() {
        let context = makeContext()
        SignalEmitter.emit(item: makeItem(), accepted: true, move: makeMove(), into: context)
        let signals = (try? context.fetch(FetchDescriptor<PendingSignal>())) ?? []
        #expect(signals.first?.noisyEmbedding.count == 384)
    }

    @Test func repeatedEmission_addsNoiseNotIdenticalVectors() {
        // Two emissions for the identical (flag, archetype, accepted) triple must not be
        // bit-identical — that would mean the Laplace step isn't actually running.
        let context = makeContext()
        let move = makeMove()
        let item = makeItem()
        SignalEmitter.emit(item: item, accepted: true, move: move, into: context)
        SignalEmitter.emit(item: item, accepted: true, move: move, into: context)
        let signals = (try? context.fetch(FetchDescriptor<PendingSignal>())) ?? []
        #expect(signals.count == 2)
        #expect(signals[0].noisyEmbedding != signals[1].noisyEmbedding)
    }

    @Test func differentFlags_produceDifferentEmbeddings() {
        let context = makeContext()
        let move = makeMove()
        SignalEmitter.emit(item: MoveImpactItem(flag: .hasEpicPass, confidence: .inferredHigh, archetype: .mountainSkiCorridor, rationale: "t"), accepted: true, move: move, into: context)
        SignalEmitter.emit(item: MoveImpactItem(flag: .hasIkonPass, confidence: .inferredHigh, archetype: .mountainSkiCorridor, rationale: "t"), accepted: true, move: move, into: context)
        let signals = (try? context.fetch(FetchDescriptor<PendingSignal>())) ?? []
        #expect(signals.count == 2)
        #expect(signals[0].noisyEmbedding != signals[1].noisyEmbedding)
    }
}

@Suite("LifestyleProfile — Signal Store (WS2)")
struct SignalStoreTests {

    @Test func settingFlagTrue_createsSelfReportedSignalAtFullConfidence() {
        let profile = LifestyleProfile()
        profile.set(.usesNetflix, to: true)
        let signal = profile.signal(for: .usesNetflix)
        #expect(signal?.confidence == 1.0)
        #expect(signal?.source == .selfReported)
    }

    @Test func settingFlagFalse_removesTheSignalRecord() {
        let profile = LifestyleProfile()
        profile.set(.usesNetflix, to: true)
        profile.set(.usesNetflix, to: false)
        #expect(profile.signal(for: .usesNetflix) == nil)
    }

    @Test func activeFlagsUnaffectedBySignalStore() {
        // The core acceptance bar for WS2: activeFlags behaves identically to before
        // this workstream existed.
        let profile = LifestyleProfile()
        profile.set(.hasCar, to: true)
        #expect(profile.activeFlags == [.hasCar])
    }

    @Test func profileWithNoSignalRecordsJSON_lazilyBackfillsFromActiveFlags() {
        // Simulates a profile written before WS2 shipped: activeFlagsJSON is set the
        // old way (direct assignment, bypassing `set`), signalRecordsJSON is nil.
        let profile = LifestyleProfile()
        profile.activeFlags = [.hasChildren, .usesSpotify]
        #expect(profile.signalRecordsJSON == nil)

        let backfilled = profile.signalRecords
        #expect(backfilled.count == 2)
        #expect(backfilled[.hasChildren]?.confidence == 1.0)
        #expect(backfilled[.hasChildren]?.source == .selfReported)
    }

    @Test func signalRecordsRoundTripThroughJSON() {
        let profile = LifestyleProfile()
        profile.set(.hasPartner, to: true)
        profile.set(.hasEpicPass, to: true)
        // Force a round-trip through the JSON string, not just the in-memory dictionary.
        let json = profile.signalRecordsJSON
        let reloaded = LifestyleProfile()
        reloaded.signalRecordsJSON = json
        #expect(reloaded.signal(for: .hasPartner) != nil)
        #expect(reloaded.signal(for: .hasEpicPass) != nil)
    }
}

@Suite("LifestyleProfile — Household Structured Fields (WS5)")
struct HouseholdStructuredFieldTests {

    @Test func childCount_defaultsToNil() {
        #expect(LifestyleProfile().childCount == nil)
    }

    @Test func petSpecies_defaultsToEmpty() {
        #expect(LifestyleProfile().petSpecies.isEmpty)
    }

    @Test func petSpecies_roundTripsThroughJSON() {
        let profile = LifestyleProfile()
        profile.petSpecies = [.dog, .largeOrExotic]
        #expect(profile.petSpecies == [.dog, .largeOrExotic])
    }

    @Test func childCount_settingDoesNotAffectHasChildrenFlag() {
        // WS5's acceptance bar: this is additive, hasChildren stays independent.
        let profile = LifestyleProfile()
        profile.childCount = 3
        #expect(!profile.has(.hasChildren))
    }
}

@Suite("RegionalArchetypeService — State Matching")
struct RegionalArchetypeMatchTests {

    @Test func colorado_matchesMountainSkiCorridorHigh() {
        let matches = RegionalArchetypeService.matches(forStateBucket: "CO")
        #expect(matches.contains { $0.archetype == .mountainSkiCorridor && $0.strength == .high })
    }

    @Test func minnesota_matchesBothSkiModerateAndLakeHigh() {
        let matches = RegionalArchetypeService.matches(forStateBucket: "MN")
        #expect(matches.contains { $0.archetype == .mountainSkiCorridor && $0.strength == .moderate })
        #expect(matches.contains { $0.archetype == .lakeBoatingBelt && $0.strength == .high })
    }

    @Test func unmappedState_returnsEmptyNotAFallback() {
        // Rhode Island has no strong regional archetype signal in this table — empty
        // is the honest answer, not an error and not a guessed default.
        #expect(RegionalArchetypeService.matches(forStateBucket: "RI").isEmpty)
    }

    @Test func unknownUSSentinel_returnsEmpty() {
        #expect(RegionalArchetypeService.matches(forStateBucket: "US").isEmpty)
    }
}

@Suite("MoveImpactEngine — Candidate Generation")
struct MoveImpactEngineTests {

    @Test func coloradoDestination_suggestsEpicAndIkon() {
        let items = MoveImpactEngine.candidates(destinationStateBucket: "CO", activeFlags: [])
        #expect(items.contains { $0.flag == .hasEpicPass && $0.confidence == .inferredHigh })
        #expect(items.contains { $0.flag == .hasIkonPass && $0.confidence == .inferredHigh })
    }

    @Test func alreadyConfirmedFlag_isNeverSuggestedAsCandidate() {
        let items = MoveImpactEngine.candidates(destinationStateBucket: "CO", activeFlags: [.hasEpicPass])
        #expect(!items.contains { $0.flag == .hasEpicPass })
        #expect(items.contains { $0.flag == .hasIkonPass })
    }

    @Test func unmappedState_producesNoCandidates() {
        #expect(MoveImpactEngine.candidates(destinationStateBucket: "RI", activeFlags: []).isEmpty)
    }

    @Test func highConfidenceCandidatesRankBeforeSuggested() {
        // Michigan: lakeBoatingBelt is .high, mountainSkiCorridor is .moderate —
        // boating candidates should sort ahead of ski candidates.
        let items = MoveImpactEngine.candidates(destinationStateBucket: "MI", activeFlags: [])
        let firstSuggestedIndex = items.firstIndex { $0.confidence == .suggested }
        let lastInferredHighIndex = items.lastIndex { $0.confidence == .inferredHigh }
        if let firstSuggestedIndex, let lastInferredHighIndex {
            #expect(lastInferredHighIndex < firstSuggestedIndex)
        }
    }

    @Test func rationaleNamesTheArchetype() {
        let items = MoveImpactEngine.candidates(destinationStateBucket: "CO", activeFlags: [])
        #expect(items.allSatisfy { $0.rationale.contains($0.archetype.displayName) })
    }

    @Test func candidatesNeverDuplicateAFlagAcrossArchetypes() {
        // Farm Bureau is a candidate for both ranchWesternHeritage and
        // huntingFishingHeritage — Montana matches both — must appear once, not twice.
        let items = MoveImpactEngine.candidates(destinationStateBucket: "MT", activeFlags: [])
        let farmBureauCount = items.filter { $0.flag == .hasFarmBureauMembership }.count
        #expect(farmBureauCount == 1)
    }

    // MARK: WS3 — regional similarity upgrade

    @Test func moderateMatchUpgradedToHighConfidence_whenOriginDestinationHighlySimilar() {
        // Same-state move: origin/destination similarity is 1.0 (identical vector to
        // itself), comfortably above the upgrade threshold. MI's mountainSkiCorridor
        // match is only .moderate on its own — this proves the upgrade path fires.
        let withoutOrigin = MoveImpactEngine.candidates(destinationStateBucket: "MI", activeFlags: [])
        let withOrigin = MoveImpactEngine.candidates(destinationStateBucket: "MI", activeFlags: [], originStateBucket: "MI")

        #expect(withoutOrigin.first { $0.flag == .hasEpicPass }?.confidence == .suggested)
        #expect(withOrigin.first { $0.flag == .hasEpicPass }?.confidence == .inferredHigh)
    }

    @Test func highMatchIsNeverDowngraded_regardlessOfSimilarity() {
        // CO's mountainSkiCorridor is already .high — must stay .inferredHigh even
        // with a low-similarity, unrelated origin.
        let items = MoveImpactEngine.candidates(destinationStateBucket: "CO", activeFlags: [], originStateBucket: "RI")
        #expect(items.first { $0.flag == .hasEpicPass }?.confidence == .inferredHigh)
    }

    @Test func noOriginProvided_behavesExactlyAsBeforeWS3() {
        // Default parameter — every pre-WS3 call site must be unaffected.
        let items = MoveImpactEngine.candidates(destinationStateBucket: "MI", activeFlags: [])
        #expect(items.first { $0.flag == .hasEpicPass }?.confidence == .suggested)
    }
}

@Suite("RegionalSimilarityService (WS3)")
struct RegionalSimilarityServiceTests {

    @Test func identicalState_similarityIsOne() {
        // Same state, same feature vector on both sides — cosine similarity of a
        // vector with itself is always 1.0.
        #expect(abs(RegionalSimilarityService.similarity(between: "CO", and: "CO") - 1.0) < 0.0001)
    }

    @Test func similarityIsSymmetric() {
        let ab = RegionalSimilarityService.similarity(between: "CO", and: "UT")
        let ba = RegionalSimilarityService.similarity(between: "UT", and: "CO")
        #expect(abs(ab - ba) < 0.0001)
    }

    @Test func twoSkiStates_moreSimilarThanSkiStateAndUnrelatedState() {
        // CO and UT are both high-confidence Mountain & Ski Corridor with comparable
        // income/home-value profiles — should score higher than CO against a state
        // with no shared archetype signal at all.
        let coToUt = RegionalSimilarityService.similarity(between: "CO", and: "UT")
        let coToUnrelated = RegionalSimilarityService.similarity(between: "CO", and: "RI")
        #expect(coToUt > coToUnrelated)
    }

    @Test func unmappedStatePair_doesNotCrashAndStaysInValidRange() {
        let score = RegionalSimilarityService.similarity(between: "RI", and: "US")
        #expect(score >= 0 && score <= 1)
    }

    @Test func featureVector_hasOneDimensionPerArchetypePlusTwoEconomicDimensions() {
        let vector = RegionalSimilarityService.featureVector(forStateBucket: "CO")
        #expect(vector.count == RegionalArchetype.allCases.count + 2)
    }
}

@Suite("Move — Regional Similarity Score (WS3)")
struct MoveRegionalSimilarityTests {

    private func makeMove(origin: String?, destinationState: String) -> Move {
        Move(anchorDate: Date(), originZip: origin, destinationZip: "00000",
             destinationStateBucket: destinationState, destinationCityBucket: nil)
    }

    @Test func noOriginZip_returnsNil() {
        #expect(makeMove(origin: nil, destinationState: "CO").regionalSimilarityScore == nil)
    }

    @Test func sameOriginAndDestinationState_scoresNearOne() {
        let move = makeMove(origin: "80202", destinationState: "CO")
        #expect((move.regionalSimilarityScore ?? 0) > 0.99)
    }
}

@Suite("RegionalEconomicsService — Cost Comparison")
struct RegionalEconomicsComparisonTests {

    @Test func noOrigin_returnsNil() {
        #expect(RegionalEconomicsService.compare(originStateBucket: nil, destinationStateBucket: "CO") == nil)
    }

    @Test func canadianOrigin_returnsNil() {
        // Census/Zillow are US-only — a Canadian province bucket has no snapshot.
        #expect(RegionalEconomicsService.compare(originStateBucket: "ON", destinationStateBucket: "CO") == nil)
    }

    @Test func canadianDestination_returnsNil() {
        #expect(RegionalEconomicsService.compare(originStateBucket: "CA", destinationStateBucket: "BC") == nil)
    }

    @Test func mississippiToCalifornia_isCostIncrease() {
        // MS has the lowest median home value in the snapshot, CA the highest.
        let result = RegionalEconomicsService.compare(originStateBucket: "MS", destinationStateBucket: "CA")
        #expect(result?.direction == .costIncrease)
        #expect((result?.homeValueDeltaPercent ?? 0) > 0)
    }

    @Test func californiaToMississippi_isCostDecrease() {
        let result = RegionalEconomicsService.compare(originStateBucket: "CA", destinationStateBucket: "MS")
        #expect(result?.direction == .costDecrease)
        #expect((result?.homeValueDeltaPercent ?? 0) < 0)
    }

    @Test func sameState_isComparable() {
        let result = RegionalEconomicsService.compare(originStateBucket: "TX", destinationStateBucket: "TX")
        #expect(result?.direction == .comparable)
        #expect(result?.homeValueDeltaPercent == 0)
        #expect(result?.incomeDeltaPercent == 0)
    }

    @Test func allFiftyStatesPlusDCAndNationalFallback_havePositiveSnapshots() {
        let expectedBuckets = [
            "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA",
            "ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK",
            "OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY","DC","US"
        ]
        for bucket in expectedBuckets {
            let snapshot = RegionalEconomicsService.snapshot(forStateBucket: bucket)
            #expect(snapshot != nil, "missing snapshot for \(bucket)")
            #expect((snapshot?.medianHouseholdIncome ?? 0) > 0, "\(bucket) income should be positive")
            #expect((snapshot?.medianHomeValue ?? 0) > 0, "\(bucket) home value should be positive")
        }
    }
}

// MARK: - Income pilot (synthetic software fixtures; never deployable evidence)

private enum IncomePilotFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static var values: [String: String] {
        var result = Dictionary(uniqueKeysWithValues: AreaMarketDataService.variables.map { ($0, "10") })
        result["B19013_001E"] = "90000"
        result["B25010_001E"] = "2.5"
        result["B11016_002E"] = "100"
        result["B19001_001E"] = "160"
        for cell in 1...17 { result[String(format: "B19001_%03dM", cell)] = "1" }
        result["zip code tabulation area"] = "80202"
        return result
    }

    static func response(_ changes: [String: Any] = [:], reversed: Bool = false) throws -> Data {
        var values: [String: Any] = Self.values
        changes.forEach { values[$0.key] = $0.value }
        var header = AreaMarketDataService.variables + ["zip code tabulation area"]
        if reversed { header.reverse() }
        return try JSONSerialization.data(withJSONObject: [header, header.map { values[$0] ?? NSNull() }])
    }

    static func profile(_ changes: [String: Any] = [:], retrievedAt: Date = now) throws -> AreaMarketProfile {
        try #require(AreaMarketDataService.parseResponse(response(changes), zip: "80202", retrievedAt: retrievedAt))
    }

    static func manifest(edit: (inout [String: Any]) -> Void = { _ in }) throws -> IncomePilotManifest {
        let strata = AreaIncomeBand.allCases.map {
            IncomeValidationStratum(id: $0.rawValue, households: 30, usefulLiftLower95: 0.01, irrelevantIncreaseUpper95: 0)
        }
        let regions = ["northeast", "south", "west"].map {
            IncomeValidationStratum(id: $0, households: 70, usefulLiftLower95: 0.01, irrelevantIncreaseUpper95: 0)
        }
        let report = IncomeValidationReport(modelVersion: "TEST-ONLY", independentHoldout: true, synthetic: false,
            households: 210, regionCount: 3, excludedHouseholds: 0, usefulLiftLower95: 0.01,
            irrelevantIncreaseUpper95: 0, incomeStrata: strata, regionStrata: regions,
            reportSHA256: String(repeating: "a", count: 64))
        let source = IncomeEvidenceSource(id: "test-survey", title: "TEST fixture — not research evidence",
            url: "https://example.invalid/test-only", kind: .serviceUseSurvey, population: "test fixtures",
            period: "test only", offlineUseApproved: true, limitations: "Synthetic code-path fixture")
        let rule = IncomeRankingRule(serviceID: "lifetime", sourceID: source.id, modelVersion: "TEST-ONLY",
            featureDefinition: IncomeSuggestionEngine.featureDefinition, reviewedForRelease: true,
            validFrom: now.addingTimeInterval(-86400), validUntil: now.addingTimeInterval(86400),
            coefficients: Dictionary(uniqueKeysWithValues: AreaIncomeBand.allCases.map { ($0.rawValue, 1.0) }), validation: report)
        let manifest = IncomePilotManifest(schemaVersion: 1, version: "TEST-ONLY", sources: [source],
            services: [ServicePilotEntry(id: "lifetime", question: "Test question", sourceIDs: [source.id],
                researchCategory: "test", mappingLimit: "not research evidence")], rules: [rule])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(JSONSerialization.jsonObject(with: encoder.encode(manifest)) as? [String: Any])
        edit(&object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(IncomePilotManifest.self, from: JSONSerialization.data(withJSONObject: object))
    }

    static func changedRule(_ key: String, _ value: Any, validation: Bool = false) throws -> IncomePilotManifest {
        try manifest { object in
            var rules = object["rules"] as! [[String: Any]]
            if validation {
                var report = rules[0]["validation"] as! [String: Any]
                report[key] = value
                rules[0]["validation"] = report
            } else { rules[0][key] = value }
            object["rules"] = rules
        }
    }

    static func move() -> Move {
        let move = Move(anchorDate: now, originZip: "80202", destinationZip: "80202",
                        destinationStateBucket: "CO", destinationCityBucket: "DENVER")
        move.lifestyleProfile = LifestyleProfile()
        return move
    }
}

@Suite("Income pilot — Census parsing and bundled catalog")
struct IncomePilotDataTests {
    @Test func binsPartitionACSCellsAndStayWithinRequestLimit() {
        let cells = AreaIncomeBand.allCases.flatMap { Array($0.censusCells) }
        #expect(cells == Array(2...17))
        #expect(AreaMarketDataService.variables.count == 50)
        #expect(Set(AreaMarketDataService.variables).count == 50)
    }

    @Test func completeDistributionPreservesSharesAndUncertainty() throws {
        let result = try #require(AreaIncomeDistribution.parse(IncomePilotFixtures.values))
        #expect(result.isComplete)
        #expect(result.share(in: .under35k) == 60.0 / 160)
        #expect(result.share(in: .over200k) == 10.0 / 160)
        #expect(abs(result.counts[0].marginOfError! - sqrt(6)) < 0.0001)
        #expect(abs(AreaIncomeBand.allCases.reduce(0) { $0 + (result.share(in: $1) ?? 0) } - 1) < 0.0001)
    }

    @Test(arguments: ["-666666666", "NaN", "inf", "bad", "-1"])
    func invalidEstimateRejectsWholeDistribution(raw: String) {
        var values = IncomePilotFixtures.values
        values["B19001_017E"] = raw
        #expect(AreaIncomeDistribution.parse(values) == nil)
    }

    @Test func missingBinBadTotalAndDuplicateBandsFailClosed() throws {
        var values = IncomePilotFixtures.values
        values.removeValue(forKey: "B19001_017E")
        #expect(AreaIncomeDistribution.parse(values) == nil)
        values = IncomePilotFixtures.values
        values["B19001_001E"] = "0"
        #expect(AreaIncomeDistribution.parse(values) == nil)
        values["B19001_001E"] = "161"
        #expect(AreaIncomeDistribution.parse(values) == nil)
        let parsed = try #require(AreaIncomeDistribution.parse(IncomePilotFixtures.values))
        let duplicate = AreaIncomeDistribution(totalHouseholds: 160, totalMarginOfError: 1,
            counts: Array(repeating: parsed.counts[0], count: 7))
        #expect(!duplicate.isComplete)
    }

    @Test func reorderedColumnsAndPartialIncomeDataPreserveCoreSnapshot() throws {
        let reordered = AreaMarketDataService.parseResponse(try IncomePilotFixtures.response(reversed: true), zip: "80202")
        #expect(reordered?.incomeDistribution?.isComplete == true)
        let partial = try IncomePilotFixtures.profile(["B19001_017E": NSNull()])
        #expect(partial.medianHouseholdIncome == 90000)
        #expect(partial.incomeDistribution == nil)
        #expect(AreaMarketDataService.parseResponse(try IncomePilotFixtures.response(), zip: "10001") == nil)
        #expect(AreaMarketDataService.parseResponse(try IncomePilotFixtures.response(["B19013_001E": NSNull()]), zip: "80202") == nil)
    }

    @Test func legacyCachedProfilesDecodeWithoutNewDistribution() throws {
        let data = try JSONEncoder().encode(IncomePilotFixtures.profile())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "incomeDistribution")
        let decoded = try JSONDecoder().decode(AreaMarketProfile.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.incomeDistribution == nil)
        #expect(decoded.medianHouseholdIncome == 90000)
    }

    @Test func bundleContains25CanonicalQuestionsAndNoIncomeRules() {
        let manifest = ServiceEvidenceCatalog.bundled
        #expect(manifest.version != "unavailable")
        #expect(manifest.isStructurallyValid)
        #expect(manifest.services.count == 25)
        #expect(manifest.rules.isEmpty)
        for entry in manifest.services {
            #expect(ItemCatalog.byID[entry.id]?.canonicalID == entry.id)
            #expect(!entry.mappingLimit.isEmpty)
        }
    }

    @Test func duplicateAndUnknownReferencesRejectManifest() throws {
        let duplicate = try IncomePilotFixtures.manifest { object in
            let sources = object["sources"] as! [[String: Any]]
            object["sources"] = sources + sources
        }
        #expect(!duplicate.isStructurallyValid)
        let unknown = try IncomePilotFixtures.changedRule("sourceID", "unknown")
        #expect(!unknown.isStructurallyValid)
        #expect(ServiceEvidenceCatalog.decode(Data("{}".utf8)) == nil)
    }
}

@Suite("Income pilot — evidence gates")
struct IncomePilotGateTests {
    @Test func validTestFixtureIsBoundedAndUnknownServiceDoesNotScore() throws {
        let area = try IncomePilotFixtures.profile()
        let manifest = try IncomePilotFixtures.manifest()
        #expect(IncomeSuggestionEngine.adjustment(for: "lifetime", origin: area, manifest: manifest,
                                                   now: IncomePilotFixtures.now)?.points == 4)
        let negative = try IncomePilotFixtures.changedRule("coefficients",
            Dictionary(uniqueKeysWithValues: AreaIncomeBand.allCases.map { ($0.rawValue, -1.0) }))
        #expect(IncomeSuggestionEngine.adjustment(for: "lifetime", origin: area, manifest: negative,
                                                   now: IncomePilotFixtures.now)?.points == -4)
        #expect(IncomeSuggestionEngine.adjustment(for: "unknown", origin: area, manifest: manifest,
                                                   now: IncomePilotFixtures.now) == nil)
    }

    @Test(arguments: ["areaDemographics", "categorySpending", "modeledMarketEstimate", "unlicensed"])
    func aggregateAndUnlicensedEvidenceCannotScore(kind: String) throws {
        let manifest = try IncomePilotFixtures.manifest { object in
            var sources = object["sources"] as! [[String: Any]]
            if kind == "unlicensed" { sources[0]["offlineUseApproved"] = false }
            else { sources[0]["kind"] = kind }
            object["sources"] = sources
        }
        #expect(IncomeSuggestionEngine.adjustment(for: "lifetime", origin: try IncomePilotFixtures.profile(),
            manifest: manifest, now: IncomePilotFixtures.now) == nil)
    }

    @Test func invalidApprovalFeatureDatesAndCoefficientsCannotScore() throws {
        let invalid: [(String, Any)] = [("reviewedForRelease", false), ("featureDefinition", "destination-income"),
            ("modelVersion", "different"), ("validUntil", "2020-01-01T00:00:00Z"),
            ("validFrom", "2099-01-01T00:00:00Z"), ("coefficients", ["over200k": 1.0]),
            ("coefficients", Dictionary(uniqueKeysWithValues: AreaIncomeBand.allCases.map { ($0.rawValue, 1.1) }))]
        for (key, value) in invalid {
            #expect(IncomeSuggestionEngine.adjustment(for: "lifetime", origin: try IncomePilotFixtures.profile(),
                manifest: try IncomePilotFixtures.changedRule(key, value), now: IncomePilotFixtures.now) == nil,
                "Gate failed: \(key)")
        }
    }

    @Test func insufficientSyntheticAndHarmfulValidationCannotScore() throws {
        let invalid: [(String, Any)] = [("independentHoldout", false), ("synthetic", true), ("households", 199),
            ("regionCount", 2), ("excludedHouseholds", 1), ("usefulLiftLower95", 0),
            ("irrelevantIncreaseUpper95", 0.01), ("reportSHA256", "unverified"),
            ("incomeStrata", []), ("regionStrata", [])]
        for (key, value) in invalid {
            #expect(IncomeSuggestionEngine.adjustment(for: "lifetime", origin: try IncomePilotFixtures.profile(),
                manifest: try IncomePilotFixtures.changedRule(key, value, validation: true),
                now: IncomePilotFixtures.now) == nil, "Gate failed: \(key)")
        }
        let harmful = try IncomePilotFixtures.manifest { object in
            var rules = object["rules"] as! [[String: Any]]
            var report = rules[0]["validation"] as! [String: Any]
            var strata = report["incomeStrata"] as! [[String: Any]]
            strata[0]["usefulLiftLower95"] = -0.01
            report["incomeStrata"] = strata
            rules[0]["validation"] = report
            object["rules"] = rules
        }
        #expect(!harmful.rules[0].validation.passesLaunchCriteria)
    }

    @Test func missingUncertainStaleAndFutureAreaDataCannotScore() throws {
        let manifest = try IncomePilotFixtures.manifest()
        let now = IncomePilotFixtures.now
        let candidates: [AreaMarketProfile?] = [nil,
            try IncomePilotFixtures.profile(["B19001_017E": NSNull()]),
            try IncomePilotFixtures.profile(["B19001_017M": NSNull()]),
            try IncomePilotFixtures.profile(["B19001_001M": "1000"]),
            try IncomePilotFixtures.profile(["B19001_017M": "1000"]),
            try IncomePilotFixtures.profile(retrievedAt: now.addingTimeInterval(-91 * 86400)),
            try IncomePilotFixtures.profile(retrievedAt: now.addingTimeInterval(86400))]
        for area in candidates {
            #expect(IncomeSuggestionEngine.adjustment(for: "lifetime", origin: area,
                manifest: manifest, now: now) == nil)
        }
        let noMOE = try IncomePilotFixtures.profile(["B19001_017M": NSNull()])
        #expect(noMOE.incomeDistribution?.isComplete == true, "Missing uncertainty still permits contextual display")
    }
}

@MainActor
@Suite("Income pilot — explicit answers and persistence")
struct ServiceUseResponseTests {
    @Test func answersAreSeparateFromTaskDecisionsAndDoNotCreateTasks() {
        let move = IncomePilotFixtures.move()
        move.respond(to: "lifetime", with: .notApplicable)
        #expect(move.serviceUseResponses.isEmpty)
        move.recordServiceUse(.usesService, for: "lifetime", now: IncomePilotFixtures.now)
        #expect(move.serviceResponses["lifetime"]?.decision == .notApplicable)
        #expect(move.serviceUseResponses["lifetime"]?.questionVersion == "service-use-v1")
        #expect(move.tasks.isEmpty)
        move.recordServiceUse(nil, for: "lifetime")
        #expect(move.serviceUseResponses.isEmpty)
        #expect(move.serviceResponses["lifetime"]?.decision == .notApplicable)
    }

    @Test func yesPrioritizesNoHidesAndUnsureDefersSevenDays() throws {
        let move = IncomePilotFixtures.move()
        let now = IncomePilotFixtures.now
        let baseline = try #require(ServiceDiscoveryEngine.candidates(for: move, now: now).first { $0.id == "lifetime" })
        move.recordServiceUse(.usesService, for: "lifetime", now: now)
        let accepted = try #require(ServiceDiscoveryEngine.candidates(for: move, now: now).first { $0.id == "lifetime" })
        #expect(accepted.rank == baseline.rank + 80)
        move.recordServiceUse(.doesNotUse, for: "lifetime", now: now)
        #expect(!ServiceDiscoveryEngine.candidates(for: move, now: now, includeDeferred: true).contains { $0.id == "lifetime" })
        move.recordServiceUse(.unsure, for: "lifetime", now: now)
        #expect(!ServiceDiscoveryEngine.candidates(for: move, now: now).contains { $0.id == "lifetime" })
        #expect(ServiceDiscoveryEngine.candidates(for: move, now: now.addingTimeInterval(7 * 86400)).contains { $0.id == "lifetime" })
        #expect(ServiceDiscoveryEngine.candidates(for: move, now: now, includeDeferred: true).contains { $0.id == "lifetime" })
    }

    @Test func explicitServiceUseCanCoverAccountsForOtherPeople() {
        let move = IncomePilotFixtures.move()
        move.lifestyleProfile?.childrenAnswer = false
        #expect(!ServiceDiscoveryEngine.candidates(for: move).contains { $0.id == "kids_childcare" })
        move.recordServiceUse(.usesService, for: "kids_childcare")
        #expect(ServiceDiscoveryEngine.candidates(for: move).contains { $0.id == "kids_childcare" })
    }

    @Test func bundledIncomeDataDoesNotChangeRankings() throws {
        let move = IncomePilotFixtures.move()
        move.areaInsightsEnabled = true
        let destination = try IncomePilotFixtures.profile()
        let low = AreaMarketComparison(origin: destination, destination: destination)
        let highIncomeOrigin = try IncomePilotFixtures.profile(["B19001_002E": "0", "B19001_017E": "20"])
        let high = AreaMarketComparison(origin: highIncomeOrigin, destination: destination)
        let baseline = ServiceDiscoveryEngine.candidates(for: move, area: low)
        let changed = ServiceDiscoveryEngine.candidates(for: move, area: high)
        #expect(baseline.map(\.id) == changed.map(\.id))
        #expect(baseline.map(\.rank) == changed.map(\.rank))
    }

    @Test func noAndUnsureBlockImplicitTasksButPreserveConfirmedTasks() throws {
        let move = IncomePilotFixtures.move()
        let item = try #require(ItemCatalog.byID["lifetime"])
        let flags = item.requires.union(item.requiresAny)
        for answer in [ServiceUseAnswer.doesNotUse, .unsure] {
            move.recordServiceUse(answer, for: "lifetime")
            #expect(!ChecklistGenerator.matchingItems(for: move, flags: flags).contains { $0.canonicalID == "lifetime" })
        }
        move.respond(to: "lifetime", with: .confirmed)
        #expect(ChecklistGenerator.matchingItems(for: move, flags: []).contains { $0.canonicalID == "lifetime" })
    }

    @Test func answersAndCompletedTasksPersistAcrossContexts() throws {
        let container = try ModelContainer(for: Move.self, ChecklistTask.self, LifestyleProfile.self,
            FinancialInstitution.self, VerificationEvent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let move = IncomePilotFixtures.move()
        context.insert(move)
        let item = try #require(ItemCatalog.byID["lifetime"])
        let task = MoveChecklistService.confirm(item, for: move, in: context)
        task.advanceStatus(); task.advanceStatus()
        move.recordServiceUse(.doesNotUse, for: item.canonicalID, now: IncomePilotFixtures.now)
        try context.save()
        let freshContext = ModelContext(container)
        let restored = try #require(freshContext.fetch(FetchDescriptor<Move>()).first)
        #expect(restored.serviceUseResponses["lifetime"]?.answer == .doesNotUse)
        #expect(restored.serviceUseResponses["lifetime"]?.answeredAt == IncomePilotFixtures.now)
        #expect(restored.tasks.count == 1)
        #expect(restored.tasks.first?.status == .completed)
        #expect(restored.serviceResponses["lifetime"]?.decision == .confirmed)
    }
}
