// GeocoderService.swift — ZIP → neighborhood list + single resolved name
// Uses CLGeocoder (on-device, no API key) + MKLocalSearch for rich neighborhood data.
import CoreLocation
import Foundation
import MapKit

// MARK: - NeighborhoodResult

/// A single candidate neighborhood for a given ZIP code.
struct NeighborhoodResult: Identifiable, Hashable {
    let id = UUID()
    /// Short display label shown in the picker, e.g. "Lowry" or "Cherry Creek"
    let neighborhood: String
    /// Full label with city + state context, e.g. "Lowry, Denver, CO"
    let fullLabel: String
    /// Source coordinate (used for geofencing / background mapping)
    let coordinate: CLLocationCoordinate2D?

    func hash(into hasher: inout Hasher) { hasher.combine(fullLabel) }
    static func == (lhs: NeighborhoodResult, rhs: NeighborhoodResult) -> Bool {
        lhs.fullLabel == rhs.fullLabel
    }
}

// MARK: - GeocoderService

enum GeocoderService {

    // MARK: Single resolved name (used by dashboard + legacy callers)

    /// Resolves a ZIP to the best single human-readable label.
    /// Priority: subLocality → locality → administrativeArea
    static func resolvedName(for zip: String) async -> String? {
        let results = await neighborhoods(for: zip)
        return results.first?.fullLabel
    }

    // MARK: Neighborhood list

    /// Returns an ordered, deduplicated list of neighborhoods within a ZIP code.
    ///
    /// Strategy:
    ///  1. CLGeocoder → all placemarks for the ZIP → extract subLocality values
    ///  2. MKLocalSearch → search "neighborhood" in the ZIP's bounding region
    ///     to surface names Apple Maps knows but CLGeocoder may miss
    ///  3. Merge, deduplicate, rank (CLGeocoder results first), return up to 12
    ///
    /// Falls back to a single city-level entry when no sub-localities exist.
    static func neighborhoods(for zip: String) async -> [NeighborhoodResult] {
        let clean = zip.trimmingCharacters(in: .whitespaces)
        guard clean.count >= 5 else { return [] }

        async let geocoderResults = geocoderNeighborhoods(zip: clean)
        async let searchResults   = localSearchNeighborhoods(zip: clean)

        let (geo, search) = await (geocoderResults, searchResults)

        // Merge: geo first (higher confidence), then MKLocalSearch extras
        var seen   = Set<String>()
        var merged = [NeighborhoodResult]()

        for item in geo + search {
            let key = item.fullLabel.lowercased()
            if seen.insert(key).inserted {
                merged.append(item)
            }
        }

        return Array(merged.prefix(12))
    }

    // MARK: - Private: CLGeocoder pass

    private static func geocoderNeighborhoods(zip: String) async -> [NeighborhoodResult] {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(zip) { placemarks, error in
                guard error == nil, let marks = placemarks, !marks.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                var results = [NeighborhoodResult]()
                var seen    = Set<String>()

                for pm in marks {
                    let subLocality = pm.subLocality       // e.g. "Lowry", "Chelsea"
                    let locality    = pm.locality          // e.g. "Denver", "New York"
                    let adminArea   = pm.administrativeArea // e.g. "CO", "NY"
                    let coord       = pm.location?.coordinate

                    // Build the full context label (city + state)
                    var contextParts: [String] = []
                    if let c = locality,   !c.isEmpty { contextParts.append(c) }
                    if let a = adminArea,  !a.isEmpty { contextParts.append(a) }
                    let context = contextParts.joined(separator: ", ")

                    if let n = subLocality, !n.isEmpty {
                        let full = context.isEmpty ? n : "\(n), \(context)"
                        if seen.insert(full.lowercased()).inserted {
                            results.append(NeighborhoodResult(neighborhood: n, fullLabel: full, coordinate: coord))
                        }
                    } else if !context.isEmpty {
                        // No sub-locality — fall back to city-level so we always have something
                        let cityName = locality ?? context
                        if seen.insert(context.lowercased()).inserted {
                            results.append(NeighborhoodResult(neighborhood: cityName, fullLabel: context, coordinate: coord))
                        }
                    }
                }

                continuation.resume(returning: results)
            }
        }
    }

    // MARK: - Private: MKLocalSearch pass

    /// Uses MKLocalSearch to find neighborhood-type named areas within the ZIP's region.
    /// This surfaces neighborhoods that CLGeocoder's single-placemark pass may miss.
    private static func localSearchNeighborhoods(zip: String) async -> [NeighborhoodResult] {
        // First: geocode the ZIP to get a center coordinate + region bounding box
        guard let region = await regionForZip(zip) else { return [] }

        let queries = ["neighborhood", "district", "quarter"]
        var results = [NeighborhoodResult]()

        for query in queries {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = query
            req.region = region
            req.resultTypes = .pointOfInterest

            do {
                let response = try await MKLocalSearch(request: req).start()
                for item in response.mapItems {
                    guard let name = item.name, !name.isEmpty else { continue }
                    let placemark = item.placemark
                    let subLoc  = placemark.subLocality ?? name
                    let city    = placemark.locality ?? ""
                    let state   = placemark.administrativeArea ?? ""
                    var parts   = [String]()
                    if !city.isEmpty  { parts.append(city) }
                    if !state.isEmpty { parts.append(state) }
                    let full = parts.isEmpty ? subLoc : "\(subLoc), \(parts.joined(separator: ", "))"
                    let coord = item.placemark.coordinate
                    results.append(NeighborhoodResult(neighborhood: subLoc, fullLabel: full, coordinate: coord))
                }
            } catch {
                // MKLocalSearch failures are non-fatal — skip this query
            }
        }

        return results
    }

    /// Returns an MKCoordinateRegion roughly bounding the given ZIP code.
    private static func regionForZip(_ zip: String) async -> MKCoordinateRegion? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(zip) { marks, _ in
                guard let pm = marks?.first, let loc = pm.location else {
                    continuation.resume(returning: nil)
                    return
                }
                // Use a ~10 km span — large enough to capture a full ZIP's neighborhoods
                let region = MKCoordinateRegion(
                    center: loc.coordinate,
                    latitudinalMeters: 10_000,
                    longitudinalMeters: 10_000
                )
                continuation.resume(returning: region)
            }
        }
    }
}
