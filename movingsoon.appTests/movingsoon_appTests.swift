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
