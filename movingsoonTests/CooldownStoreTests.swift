// CooldownStoreTests.swift — Unit tests for CooldownStore round-trip and gate logic
import XCTest
@testable import movingsoon_app

final class CooldownStoreTests: XCTestCase {

    private func makeStore() -> CooldownStore {
        // Each test gets a fresh isolated UserDefaults suite
        CooldownStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    // MARK: - Initial state

    func test_freshStore_allCategoriesPass() {
        let store = makeStore()
        for category in POICategory.allCases {
            XCTAssertTrue(store.gatePasses(for: category),
                          "Expected gate to pass for \(category.rawValue) on fresh store")
        }
    }

    // MARK: - Record & gate

    func test_recordThenGate_sameDay_fails() {
        var store = makeStore()
        let now = Date()
        store.record(category: .bank, date: now)
        XCTAssertFalse(store.gatePasses(for: .bank, now: now))
    }

    func test_recordThenGate_nextDay_passes() {
        var store = makeStore()
        let now = Date()
        store.record(category: .bank, date: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        XCTAssertTrue(store.gatePasses(for: .bank, now: tomorrow))
    }

    func test_recordBankDoesNotAffectGym() {
        var store = makeStore()
        store.record(category: .bank, date: Date())
        XCTAssertTrue(store.gatePasses(for: .gym, now: Date()))
    }

    func test_recordAllCategories_allFail() {
        var store = makeStore()
        let now = Date()
        for category in POICategory.allCases {
            store.record(category: category, date: now)
        }
        for category in POICategory.allCases {
            XCTAssertFalse(store.gatePasses(for: category, now: now),
                           "Expected gate to fail for \(category.rawValue)")
        }
    }

    // MARK: - Persistence (re-init from same UserDefaults)

    func test_persistence_survivesReinit() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        var store1 = CooldownStore(defaults: defaults)
        let now = Date()
        store1.record(category: .pharmacy, date: now)

        // Re-init from same suite
        let store2 = CooldownStore(defaults: defaults)
        XCTAssertFalse(store2.gatePasses(for: .pharmacy, now: now),
                       "Recorded date should persist across re-initialisation")
    }

    // MARK: - clearAll

    func test_clearAll_resetsAllGates() {
        var store = makeStore()
        let now = Date()
        store.record(category: .bank, date: now)
        store.record(category: .dmv, date: now)
        store.clearAll()
        XCTAssertTrue(store.gatePasses(for: .bank, now: now))
        XCTAssertTrue(store.gatePasses(for: .dmv, now: now))
    }

    func test_clearAll_onEmptyStore_doesNotCrash() {
        var store = makeStore()
        store.clearAll() // should not crash
        XCTAssertTrue(store.gatePasses(for: .bank, now: Date()))
    }

    // MARK: - Edge cases

    func test_recordMidnight_gateFailsSameDay() {
        var store = makeStore()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let midnight = Calendar.current.date(from: comps)!
        store.record(category: .postOffice, date: midnight)

        comps.hour = 23; comps.minute = 59
        let lateNight = Calendar.current.date(from: comps)!
        XCTAssertFalse(store.gatePasses(for: .postOffice, now: lateNight))
    }

    func test_recordLateNight_gatePassesNextMorning() {
        var store = makeStore()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 23; comps.minute = 59
        let lateNight = Calendar.current.date(from: comps)!
        store.record(category: .postOffice, date: lateNight)

        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: lateNight)!
        XCTAssertTrue(store.gatePasses(for: .postOffice, now: nextDay))
    }
}
