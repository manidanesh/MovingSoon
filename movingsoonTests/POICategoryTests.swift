// POICategoryTests.swift — Tests for POICategory display names and enum completeness
import XCTest
@testable import movingsoon_app

final class POICategoryTests: XCTestCase {

    func test_allCategories_haveNonEmptyDisplayName() {
        for category in POICategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty,
                           "POICategory.\(category.rawValue) should have a non-empty displayName")
        }
    }

    func test_bank_displayName() {
        XCTAssertEqual(POICategory.bank.displayName, "bank")
    }

    func test_dmv_displayName_uppercased() {
        XCTAssertEqual(POICategory.dmv.displayName, "DMV")
    }

    func test_postOffice_displayName() {
        XCTAssertEqual(POICategory.postOffice.displayName, "post office")
    }

    func test_doctor_displayName() {
        XCTAssertEqual(POICategory.doctor.displayName, "doctor's office")
    }

    func test_allCases_hasExpectedCount() {
        // Ensure no cases were accidentally removed
        XCTAssertGreaterThanOrEqual(POICategory.allCases.count, 13,
                                    "POICategory should have at least 13 cases")
    }
}
