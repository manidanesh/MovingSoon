// ZipBucketService.swift — On-device zip-to-region mapping (no network call)
import Foundation

enum ZipBucketService {

    /// Approximate postal region, not address verification or a jurisdiction decision.
    /// Unassigned prefixes stay unknown; military and Pacific postal regions are explicit.
    /// Reviewed 2026-10-20 against IRS IRM 3.41.267 ZIP ranges, USPS DMM 608.2,
    /// USPS Postal Facts and Canada Post's postal-code/delivery-region documentation.
    static func bucket(zip: String) -> (state: String, city: String?) {
        let value = PostalCodeService.normalize(zip)
        guard PostalCodeService.isValid(value) else { return ("US", nil) }
        if value.count == 6 { return (canadianProvince(postalCode: value), nil) }
        guard let code = Int(value) else { return ("US", nil) }
        let state = usRegion(code: code)
        return (state, cityBucket(zip: value))
    }

    /// Repairs stale persisted buckets from earlier prefix tables without changing progress.
    /// The caller saves the context and reconciles task/location rules after a change.
    @discardableResult
    static func repairRegionBuckets(for move: Move) -> Bool {
        let region = bucket(zip: move.destinationZip)
        guard move.destinationStateBucket != region.state || move.destinationCityBucket != region.city else { return false }
        move.destinationStateBucket = region.state
        move.destinationCityBucket = region.city
        return true
    }

    private static func usRegion(code: Int) -> String {
        // Five-digit exceptions precede prefix ranges. ZIPs may cross boundaries;
        // use the actual address and official agency when determining requirements.
        switch code {
        case 501, 544, 6390: return "NY"
        case 5501, 5544: return "MA"
        case 96799: return "AS"
        case 96910, 96912, 96913, 96915, 96916, 96917, 96919,
             96921, 96923, 96928, 96929, 96931, 96932: return "GU"
        case 96939, 96940: return "PW"
        case 96941...96944: return "FM"
        case 96950...96952: return "MP"
        case 96960, 96970: return "MH"
        default: break
        }
        switch code / 100 {
        case 6, 7, 9: return "PR"
        case 8: return "VI"
        case 10...27: return "MA"
        case 28...29: return "RI"
        case 30...38: return "NH"
        case 39...49: return "ME"
        case 50...54, 56...59: return "VT"
        case 60...69: return "CT"
        case 70...89: return "NJ"
        case 90...98: return "AE"
        case 100...149: return "NY"
        case 150...196: return "PA"
        case 197...199: return "DE"
        case 200, 202...205: return "DC"
        case 201, 220...246: return "VA"
        case 206...219: return "MD"
        case 247...268: return "WV"
        case 270...289: return "NC"
        case 290...299: return "SC"
        case 300...319, 398...399: return "GA"
        case 320...339, 341...342, 344, 346...347, 349: return "FL"
        case 340: return "AA"
        case 350...369: return "AL"
        case 370...385: return "TN"
        case 386...397: return "MS"
        case 400...427: return "KY"
        case 430...459: return "OH"
        case 460...479: return "IN"
        case 480...499: return "MI"
        case 500...528: return "IA"
        case 530...549: return "WI"
        case 550...567: return "MN"
        case 570...577: return "SD"
        case 580...588: return "ND"
        case 590...599: return "MT"
        case 600...629: return "IL"
        case 630...658: return "MO"
        case 660...679: return "KS"
        case 680...693: return "NE"
        case 700...714: return "LA"
        case 716...729: return "AR"
        case 730...732, 734...749: return "OK"
        case 733, 750...799, 885: return "TX"
        case 800...816: return "CO"
        case 820...831: return "WY"
        case 832...838: return "ID"
        case 840...847: return "UT"
        case 850...865: return "AZ"
        case 870...884: return "NM"
        case 889...898: return "NV"
        case 900...908, 910...961: return "CA"
        case 962...966: return "AP"
        case 967...968: return "HI"
        case 970...979: return "OR"
        case 980...986, 988...994: return "WA"
        case 995...999: return "AK"
        default: return "US"
        }
    }

    private static func canadianProvince(postalCode: String) -> String {
        switch postalCode.first {
        case "A": return "NL"
        case "B": return "NS"
        case "C": return "PE"
        case "E": return "NB"
        case "G", "H", "J": return "QC"
        case "K", "L", "M", "N", "P": return "ON"
        case "R": return "MB"
        case "S": return "SK"
        case "T": return "AB"
        case "V": return "BC"
        case "X":
            if ["X0A", "X0B", "X0C"].contains(String(postalCode.prefix(3))) { return "NU" }
            return "NT"
        case "Y": return "YT"
        default: return "CA"
        }
    }

    // MARK: - City bucket mapping (major metros only, rural → nil)

    private static func cityBucket(zip: String) -> String? {
        guard let code = Int(zip) else { return nil }
        switch code {
        case 10001...10499: return "NEW_YORK_METRO"
        case 11001...11699: return "NEW_YORK_METRO"   // Long Island
        case 20001...20599: return "DC_METRO"
        case 21201...21231: return "BALTIMORE"
        case 27601...27615: return "RALEIGH"
        case 28201...28220: return "CHARLOTTE"
        case 30301...30319: return "ATLANTA"
        case 33101...33199: return "MIAMI"
        case 33601...33620: return "TAMPA"
        case 35201...35215: return "BIRMINGHAM"
        case 37201...37215: return "NASHVILLE"
        case 43201...43230: return "COLUMBUS_OH"
        case 44101...44115: return "CLEVELAND"
        case 46201...46240: return "INDIANAPOLIS"
        case 48201...48226: return "DETROIT"
        case 53201...53215: return "MILWAUKEE"
        case 55401...55415: return "MINNEAPOLIS"
        case 60601...60661: return "CHICAGO"
        case 63101...63140: return "ST_LOUIS"
        case 64101...64130: return "KANSAS_CITY"
        case 68101...68110: return "OMAHA"
        case 70112...70119: return "NEW_ORLEANS"
        case 73101...73120: return "OKLAHOMA_CITY"
        case 75201...75215: return "DALLAS"
        case 77001...77099: return "HOUSTON"
        case 78201...78220: return "SAN_ANTONIO"
        case 78701...78720: return "AUSTIN"
        case 80201...80212: return "DENVER"
        case 85001...85020: return "PHOENIX"
        case 85701...85710: return "TUCSON"
        case 89101...89120: return "LAS_VEGAS"
        case 90001...90089: return "LOS_ANGELES"
        case 91601...91617: return "LOS_ANGELES"    // Valley
        case 92101...92108: return "SAN_DIEGO"
        case 94102...94112: return "SAN_FRANCISCO"
        case 95101...95115: return "SAN_JOSE"
        case 97201...97215: return "PORTLAND"
        case 98101...98119: return "SEATTLE"
        default:            return nil              // rural — state tier only
        }
    }
}

// MARK: - Centroid lookup (offline, no network)

import CoreLocation

extension ZipBucketService {

    /// Returns the approximate geographic centroid for a destination ZIP.
    /// Used as the reference point for the SuppressionEngine distance gate
    /// and as the search origin for MKLocalSearch in GeofenceCoordinator.
    /// Falls back to the continental US centroid (39.5, -98.35) for unknown ZIPs.
    static func centroid(zip: String) -> CLLocationCoordinate2D {
        let (_, cityBucketKey) = bucket(zip: zip)

        // Metro centroid table — keyed by city bucket string
        let centroids: [String: CLLocationCoordinate2D] = [
            "NEW_YORK_METRO": CLLocationCoordinate2D(latitude: 40.7128,  longitude: -74.0060),
            "DC_METRO":       CLLocationCoordinate2D(latitude: 38.9072,  longitude: -77.0369),
            "BALTIMORE":      CLLocationCoordinate2D(latitude: 39.2904,  longitude: -76.6122),
            "RALEIGH":        CLLocationCoordinate2D(latitude: 35.7796,  longitude: -78.6382),
            "CHARLOTTE":      CLLocationCoordinate2D(latitude: 35.2271,  longitude: -80.8431),
            "ATLANTA":        CLLocationCoordinate2D(latitude: 33.7490,  longitude: -84.3880),
            "MIAMI":          CLLocationCoordinate2D(latitude: 25.7617,  longitude: -80.1918),
            "TAMPA":          CLLocationCoordinate2D(latitude: 27.9506,  longitude: -82.4572),
            "BIRMINGHAM":     CLLocationCoordinate2D(latitude: 33.5186,  longitude: -86.8104),
            "NASHVILLE":      CLLocationCoordinate2D(latitude: 36.1627,  longitude: -86.7816),
            "COLUMBUS_OH":    CLLocationCoordinate2D(latitude: 39.9612,  longitude: -82.9988),
            "CLEVELAND":      CLLocationCoordinate2D(latitude: 41.4993,  longitude: -81.6944),
            "INDIANAPOLIS":   CLLocationCoordinate2D(latitude: 39.7684,  longitude: -86.1581),
            "DETROIT":        CLLocationCoordinate2D(latitude: 42.3314,  longitude: -83.0458),
            "MILWAUKEE":      CLLocationCoordinate2D(latitude: 43.0389,  longitude: -87.9065),
            "MINNEAPOLIS":    CLLocationCoordinate2D(latitude: 44.9778,  longitude: -93.2650),
            "CHICAGO":        CLLocationCoordinate2D(latitude: 41.8781,  longitude: -87.6298),
            "ST_LOUIS":       CLLocationCoordinate2D(latitude: 38.6270,  longitude: -90.1994),
            "KANSAS_CITY":    CLLocationCoordinate2D(latitude: 39.0997,  longitude: -94.5786),
            "OMAHA":          CLLocationCoordinate2D(latitude: 41.2565,  longitude: -95.9345),
            "NEW_ORLEANS":    CLLocationCoordinate2D(latitude: 29.9511,  longitude: -90.0715),
            "OKLAHOMA_CITY":  CLLocationCoordinate2D(latitude: 35.4676,  longitude: -97.5164),
            "DALLAS":         CLLocationCoordinate2D(latitude: 32.7767,  longitude: -96.7970),
            "HOUSTON":        CLLocationCoordinate2D(latitude: 29.7604,  longitude: -95.3698),
            "SAN_ANTONIO":    CLLocationCoordinate2D(latitude: 29.4241,  longitude: -98.4936),
            "AUSTIN":         CLLocationCoordinate2D(latitude: 30.2672,  longitude: -97.7431),
            "DENVER":         CLLocationCoordinate2D(latitude: 39.7392,  longitude: -104.9903),
            "PHOENIX":        CLLocationCoordinate2D(latitude: 33.4484,  longitude: -112.0740),
            "TUCSON":         CLLocationCoordinate2D(latitude: 32.2226,  longitude: -110.9747),
            "LAS_VEGAS":      CLLocationCoordinate2D(latitude: 36.1699,  longitude: -115.1398),
            "LOS_ANGELES":    CLLocationCoordinate2D(latitude: 34.0522,  longitude: -118.2437),
            "SAN_DIEGO":      CLLocationCoordinate2D(latitude: 32.7157,  longitude: -117.1611),
            "SAN_FRANCISCO":  CLLocationCoordinate2D(latitude: 37.7749,  longitude: -122.4194),
            "SAN_JOSE":       CLLocationCoordinate2D(latitude: 37.3382,  longitude: -121.8863),
            "PORTLAND":       CLLocationCoordinate2D(latitude: 45.5051,  longitude: -122.6750),
            "SEATTLE":        CLLocationCoordinate2D(latitude: 47.6062,  longitude: -122.3321),
        ]

        if let key = cityBucketKey, let coord = centroids[key] {
            return coord
        }

        // Rural or unknown ZIP — fall back to continental US centroid
        return CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35)
    }
}
