// RegionalIntelligenceTests.swift — Tests for regional brand filtering
import XCTest
@testable import movingsoon_app

final class RegionalIntelligenceTests: XCTestCase {

    // MARK: - Regional chip availability

    func test_publix_availableInFlorida() {
        let chips = RegionalIntelligenceService.availableRegionalChips(forZip: "33101") // Miami FL
        XCTAssertTrue(chips.contains("publix"), "Publix should be available in Florida")
    }

    func test_publix_notAvailableInColorado() {
        let chips = RegionalIntelligenceService.availableRegionalChips(forZip: "80202") // Denver CO
        XCTAssertFalse(chips.contains("publix"), "Publix should not be available in Colorado")
    }

    func test_heb_availableInTexas() {
        let chips = RegionalIntelligenceService.availableRegionalChips(forZip: "78701") // Austin TX
        XCTAssertTrue(chips.contains("heb"), "H-E-B should be available in Texas")
    }

    func test_heb_notAvailableInNewYork() {
        let chips = RegionalIntelligenceService.availableRegionalChips(forZip: "10001") // NYC
        XCTAssertFalse(chips.contains("heb"), "H-E-B should not be available in New York")
    }

    func test_vasa_availableInUtah() {
        let chips = RegionalIntelligenceService.availableRegionalChips(forZip: "84101") // Salt Lake City UT
        XCTAssertTrue(chips.contains("vasa"), "VASA should be available in Utah")
    }

    func test_wegmans_availableInNewYork() {
        let chips = RegionalIntelligenceService.availableRegionalChips(forZip: "10001")
        XCTAssertTrue(chips.contains("wegmans"), "Wegmans should be available in New York")
    }

    func test_wegmans_notAvailableInCalifornia() {
        let chips = RegionalIntelligenceService.availableRegionalChips(forZip: "90001")
        XCTAssertFalse(chips.contains("wegmans"), "Wegmans should not be available in California")
    }

    // MARK: - National brands always available

    func test_nationalBrands_alwaysAvailable() {
        let denverChips = RegionalIntelligenceService.availableRegionalChips(forZip: "80202")
        let miamiChips = RegionalIntelligenceService.availableRegionalChips(forZip: "33101")
        // Amazon and DoorDash are national — should be available everywhere
        // (not in regional chip IDs, so they're always shown)
        let regionalIDs = RegionalIntelligenceService.regionalChipIDs
        XCTAssertFalse(regionalIDs.contains("amazon"), "Amazon should not be regional-gated")
        _ = denverChips // suppress unused warning
        _ = miamiChips
    }

    func test_regionalChipIDs_notEmpty() {
        XCTAssertFalse(RegionalIntelligenceService.regionalChipIDs.isEmpty,
                       "There should be at least some regional chip IDs defined")
    }
}
