import Foundation
import CoreLocation
import MapKit
import OSLog

struct LocationPlaceMatch {
    let name: String
    let coordinate: CLLocationCoordinate2D
}

@MainActor protocol LocationPlaceSearching {
    func search(target: LocationPlaceTarget, near coordinate: CLLocationCoordinate2D,
                radius: CLLocationDistance) async -> [LocationPlaceMatch]
}

@MainActor struct MapLocationPlaceSearch: LocationPlaceSearching {
    func search(target: LocationPlaceTarget, near coordinate: CLLocationCoordinate2D,
                radius: CLLocationDistance) async -> [LocationPlaceMatch] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = target.query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: radius * 2, longitudinalMeters: radius * 2)
        do {
            let response = try await MKLocalSearch(request: request).start()
            let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return response.mapItems.compactMap { item -> (LocationPlaceMatch, Double)? in
                guard target.matches(name: item.name), let name = item.name else { return nil }
                let point = item.placemark.coordinate
                let distance = center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
                guard distance <= radius else { return nil }
                return (LocationPlaceMatch(name: name, coordinate: point), distance)
            }.sorted { $0.1 < $1.1 }.map(\.0)
        } catch {
            Logger(subsystem: "app.movingsoon", category: "LocationSearch").debug("Place search unavailable; no location reminder registered.")
            return []
        }
    }
}

@MainActor protocol LocationRegionMonitoring: AnyObject {
    var monitoredRegions: Set<CLRegion> { get }
    func startMonitoring(for region: CLRegion)
    func stopMonitoring(for region: CLRegion)
}
extension CLLocationManager: LocationRegionMonitoring {}

@MainActor @Observable
final class GeofenceCoordinator {
    private(set) var registeredRegionIDs: Set<String> = []
    private var generation = 0
    private let searcher: any LocationPlaceSearching
    static let maxGeofences = 20

    init(searcher: (any LocationPlaceSearching)? = nil) {
        self.searcher = searcher ?? MapLocationPlaceSearch()
    }

    /// Reconcile with the actual system regions, including after a cold launch.
    /// The identifier changes with destination/provider; stale async work cannot
    /// register a region after a new plan, consent revocation, or task removal.
    func syncGeofences(requests: [LocationRegionRequest], destination: CLLocationCoordinate2D,
                       manager: any LocationRegionMonitoring) async {
        generation += 1
        let revision = generation
        let desired = Array(requests.prefix(Self.maxGeofences))
        let identifiers = Set(desired.map(\.identifier))
        for region in manager.monitoredRegions where !identifiers.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }
        registeredRegionIDs = Set(manager.monitoredRegions.map(\.identifier)).intersection(identifiers)
        var cache: [String: [LocationPlaceMatch]] = [:]
        for request in desired {
            guard generation == revision, !Task.isCancelled else { return }
            if registeredRegionIDs.contains(request.identifier) { continue }
            let key = request.target.query + request.target.acceptedNames.joined(separator: "|")
            let matches: [LocationPlaceMatch]
            if let existing = cache[key] { matches = existing }
            else {
                matches = await searcher.search(target: request.target, near: destination, radius: 8_000)
                cache[key] = matches
            }
            guard generation == revision, !Task.isCancelled else { return }
            guard let match = matches.first else { continue }
            let region = CLCircularRegion(center: match.coordinate, radius: 200, identifier: request.identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
            registeredRegionIDs.insert(request.identifier)
        }
    }

    func invalidate() { generation += 1 }

    func removeAllGeofences(manager: any LocationRegionMonitoring) {
        invalidate()
        for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }
        registeredRegionIDs.removeAll()
    }

    func monitoringFailed(identifier: String) { registeredRegionIDs.remove(identifier) }

    /// Returns the matched task, not merely its category. No substitution of another
    /// gym/bank account is allowed after a provider was identified.
    func matchVisit(at coordinate: CLLocationCoordinate2D,
                    requests: [LocationRegionRequest]) async -> UUID? {
        for request in requests.prefix(Self.maxGeofences) {
            guard !Task.isCancelled else { return nil }
            let matches = await searcher.search(target: request.target, near: coordinate, radius: 75)
            if !matches.isEmpty { return request.taskID }
        }
        return nil
    }
}
