// ZipBucketService.swift — On-device zip-to-region mapping (no network call)
import Foundation

enum ZipBucketService {

    /// Returns (stateBucket, cityBucket?) from a 5-digit US zip code
    static func bucket(zip: String) -> (state: String, city: String?) {
        guard zip.count == 5, let prefix = Int(zip.prefix(2)) else {
            return ("US", nil)
        }
        let state = stateBucket(prefix: prefix)
        let city  = cityBucket(zip: zip)
        return (state, city)
    }

    // MARK: - State mapping (zip prefix → 2-letter state)

    private static func stateBucket(prefix: Int) -> String {
        switch prefix {
        case 10...14: return "NY"
        case 15...19: return "PA"
        case 20...20: return "DC"
        case 21...21: return "MD"
        case 22...24: return "VA"
        case 27...28: return "NC"
        case 29...29: return "SC"
        case 30...31: return "GA"
        case 32...34: return "FL"
        case 35...36: return "AL"
        case 37...38: return "TN"
        case 40...42: return "KY"
        case 43...45: return "OH"
        case 46...47: return "IN"
        case 48...49: return "MI"
        case 50...52: return "IA"
        case 53...54: return "WI"
        case 55...56: return "MN"
        case 57...57: return "SD"
        case 58...58: return "ND"
        case 59...59: return "MT"
        case 60...62: return "IL"
        case 63...65: return "MO"
        case 66...67: return "KS"
        case 68...69: return "NE"
        case 70...71: return "LA"
        case 72...72: return "AR"
        case 73...74: return "OK"
        case 75...79: return "TX"
        case 80...81: return "CO"
        case 82...82: return "WY"
        case 83...83: return "ID"
        case 84...84: return "UT"
        case 85...86: return "AZ"
        case 87...88: return "NM"
        case 89...89: return "NV"
        case 90...96: return "CA"
        case 97...97: return "OR"
        case 98...99: return "WA"
        default:      return "US"
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
