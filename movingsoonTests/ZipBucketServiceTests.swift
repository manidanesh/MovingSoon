// ZipBucketServiceTests.swift — Tests for ZIP bucketing and centroid lookup
import XCTest
import CoreLocation
@testable import movingsoon_app

final class ZipBucketServiceTests: XCTestCase {

    // MARK: - State bucket (US)

    func test_denverZip_returnsCO() {
        let (state, _) = ZipBucketService.bucket(zip: "80202")
        XCTAssertEqual(state, "CO")
    }

    func test_nyZip_returnsNY() {
        let (state, _) = ZipBucketService.bucket(zip: "10001")
        XCTAssertEqual(state, "NY")
    }

    func test_laZip_returnsCA() {
        let (state, _) = ZipBucketService.bucket(zip: "90001")
        XCTAssertEqual(state, "CA")
    }

    func test_miamiZip_returnsFL() {
        let (state, _) = ZipBucketService.bucket(zip: "33101")
        XCTAssertEqual(state, "FL")
    }

    func test_seattleZip_returnsWA() {
        let (state, _) = ZipBucketService.bucket(zip: "98101")
        XCTAssertEqual(state, "WA")
    }

    func test_unknownZip_returnsUS() {
        let (state, _) = ZipBucketService.bucket(zip: "00001")
        XCTAssertEqual(state, "US")
    }

    // MARK: - City bucket (US)

    func test_denverZip_returnsDenverCity() {
        let (_, city) = ZipBucketService.bucket(zip: "80202")
        XCTAssertEqual(city, "DENVER")
    }

    func test_chicagoZip_returnsChicagoCity() {
        let (_, city) = ZipBucketService.bucket(zip: "60601")
        XCTAssertEqual(city, "CHICAGO")
    }

    func test_ruralZip_returnsNilCity() {
        let (_, city) = ZipBucketService.bucket(zip: "59001") // Montana rural
        XCTAssertNil(city, "Rural ZIP should return nil city bucket")
    }

    // MARK: - Canadian postal codes

    func test_ontarioPostalCode_returnsON() {
        let (state, _) = ZipBucketService.bucket(zip: "M5V 3A8")
        XCTAssertEqual(state, "ON")
    }

    func test_bcPostalCode_returnsBC() {
        let (state, _) = ZipBucketService.bucket(zip: "V6B1A1")
        XCTAssertEqual(state, "BC")
    }

    func test_quebecPostalCode_returnsQC() {
        let (state, _) = ZipBucketService.bucket(zip: "H3A0G4")
        XCTAssertEqual(state, "QC")
    }

    func test_albertaPostalCode_returnsAB() {
        let (state, _) = ZipBucketService.bucket(zip: "T2P0A8")
        XCTAssertEqual(state, "AB")
    }

    // MARK: - Centroid lookup

    func test_centroid_denverZip_isApproximatelyCorrect() {
        let coord = ZipBucketService.centroid(zip: "80202")
        XCTAssertEqual(coord.latitude, 39.7392, accuracy: 0.5)
        XCTAssertEqual(coord.longitude, -104.9903, accuracy: 0.5)
    }

    func test_centroid_nyZip_isApproximatelyCorrect() {
        let coord = ZipBucketService.centroid(zip: "10001")
        XCTAssertEqual(coord.latitude, 40.7128, accuracy: 0.5)
        XCTAssertEqual(coord.longitude, -74.0060, accuracy: 0.5)
    }

    func test_centroid_unknownZip_returnsContinentalUSFallback() {
        let coord = ZipBucketService.centroid(zip: "00001")
        XCTAssertEqual(coord.latitude, 39.5, accuracy: 0.1)
        XCTAssertEqual(coord.longitude, -98.35, accuracy: 0.1)
    }

    func test_centroid_ruralZip_returnsContinentalUSFallback() {
        let coord = ZipBucketService.centroid(zip: "59601") // Helena MT — rural
        XCTAssertEqual(coord.latitude, 39.5, accuracy: 0.1)
        XCTAssertEqual(coord.longitude, -98.35, accuracy: 0.1)
    }

    func test_centroid_allMajorMetros_areValid() {
        let metroZips = ["80202", "10001", "90001", "60601", "77001",
                         "85001", "98101", "94102", "30301", "33101"]
        for zip in metroZips {
            let coord = ZipBucketService.centroid(zip: zip)
            XCTAssertFalse(coord.latitude == 39.5 && coord.longitude == -98.35,
                           "ZIP \(zip) should not fall back to US centroid")
        }
    }
}
