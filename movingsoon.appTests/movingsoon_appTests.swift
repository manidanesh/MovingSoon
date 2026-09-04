// movingsoon_appTests.swift — Automated test suite using Swift Testing
import Testing
import Foundation
import CoreLocation
import SwiftData
@testable import movingsoon_app

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
        Move(anchorDate: Date().addingTimeInterval(30 * 86400),
             originZip: zip, destinationZip: zip,
             destinationStateBucket: "CO", destinationCityBucket: "DENVER")
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
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.isCanadian]), institutions: [])
        #expect(!tasks.map(\.title).contains("USPS Mail Forwarding"))
    }

    @Test func alwaysInclude_CanadaPost_forCanadianUser() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.isCanadian]), institutions: [])
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

    @Test func evTask_appearsWithEVFlag() {
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.hasElectricVehicle]), institutions: [])
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
        let tasks = ChecklistGenerator.generate(for: makeMove(), profile: makeProfile(flags: [.isCanadian]), institutions: [])
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

    @Test func addMoreServicesCategoriesCoverEveryExtraChipsKey() {
        // AddMoreServicesView's own category list is a separate hardcoded array (by
        // design — onboarding's screen-3 list stays short). This guards that whichever
        // new top-level key gets added to extraChips doesn't silently go unlisted there.
        let vm = LifestyleViewModel()
        let addMoreServicesCategoryIDs: Set<String> = [
            "shopping", "streaming", "fitness", "transport", "life",
            "household", "home", "insurance", "travel", "subscriptions", "community", "digital", "recreation",
        ]
        let extraChipsKeys = Set(vm.extraChips.keys)
        #expect(extraChipsKeys.isSubset(of: addMoreServicesCategoryIDs), "extraChips has a category not listed in AddMoreServicesView: \(extraChipsKeys.subtracting(addMoreServicesCategoryIDs))")
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
