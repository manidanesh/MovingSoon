// GeofenceCoordinator.swift — Resolves destination POIs via MKLocalSearch and manages CLCircularRegion geofences
import Foundation
import CoreLocation
import MapKit
import OSLog

private let logger = Logger(subsystem: "com.movingsoon", category: "GeofenceCoordinator")

@Observable
final class GeofenceCoordinator {

    // MARK: - State

    private(set) var registeredRegionIDs: Set<String> = []

    // MARK: - iOS geofence limit

    private static let maxGeofences = 20

    // MARK: - MKLocalSearch query strings per POICategory

    private static func searchQuery(for category: POICategory) -> String {
        switch category {
        case .bank:          return "bank"
        case .gym:           return "gym fitness"
        case .dmv:           return "DMV department of motor vehicles"
        case .grocery:       return "grocery store supermarket"
        case .postOffice:    return "post office USPS"
        case .pharmacy:      return "pharmacy drugstore"
        case .bookstore:     return "bookstore Barnes & Noble"
        case .outdoorGear:   return "outdoor gear REI"
        case .hardwareStore: return "hardware store Home Depot Lowe's"
        case .doctor:        return "doctor physician clinic"
        case .airport:       return "airport terminal"
        case .hotel:         return "hotel resort"
        case .rentalCar:     return "car rental Hertz Enterprise Avis"
        case .autoRepair:    return "auto repair shop mechanic"
        case .movieTheater:  return "movie theater cinema"
        case .museum:        return "museum"
        case .other:         return "address update"
        }
    }

    // MARK: - Sync geofences

    /// Resolves POI coordinates via MKLocalSearch near the DESTINATION and registers geofences.
    /// Filters to pending tasks with a poiCategory, sorts by urgency (tMinusDays ascending),
    /// caps at 20 regions (iOS system limit).
    ///
    /// - Parameter destinationCoordinate: The approximate coordinate of the destination ZIP.
    ///   Geofences are placed near real POIs at the destination, not near the user's current location.
    func syncGeofences(
        for tasks: [ChecklistTask],
        destinationCoordinate: CLLocationCoordinate2D,
        manager: CLLocationManager
    ) async {
        // Filter to pending tasks that have a physical POI category
        let pendingPOITasks = tasks
            .filter { $0.status == .toDo && $0.poiCategory != nil }
            .sorted { $0.tMinusDays < $1.tMinusDays }  // most urgent first
            .prefix(Self.maxGeofences)

        logger.debug("GeofenceCoordinator: syncGeofences called with \(tasks.count) total tasks, \(pendingPOITasks.count) pending-POI candidates, destination=\(destinationCoordinate.latitude),\(destinationCoordinate.longitude)")

        for task in pendingPOITasks {
            guard let category = task.poiCategory else { continue }
            guard !registeredRegionIDs.contains(task.id.uuidString) else { continue }

            let query = Self.searchQuery(for: category)
            // Search near the DESTINATION — where the user is moving to
            let coordinate = await resolveCoordinate(query: query, near: destinationCoordinate)

            guard let coordinate else {
                logger.debug("GeofenceCoordinator: MKLocalSearch returned no results for '\(query)' near current location — skipping task \(task.id.uuidString)")
                continue
            }

            let region = CLCircularRegion(
                center: coordinate,
                radius: 200,
                identifier: task.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            manager.startMonitoring(for: region)
            registeredRegionIDs.insert(task.id.uuidString)
            logger.debug("GeofenceCoordinator: ✅ registered geofence for '\(task.title)' (\(category.rawValue)) at \(coordinate.latitude),\(coordinate.longitude)")
        }
    }

    // MARK: - Remove individual geofence

    /// Removes the geofence for a specific task (called when task is completed or verified).
    func removeGeofence(for task: ChecklistTask, manager: CLLocationManager) {
        let identifier = task.id.uuidString
        if let region = manager.monitoredRegions.first(where: { $0.identifier == identifier }) {
            manager.stopMonitoring(for: region)
        }
        registeredRegionIDs.remove(identifier)
    }

    // MARK: - Remove all geofences

    /// Removes all registered geofences (called on consent expiry).
    func removeAllGeofences(manager: CLLocationManager) {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        registeredRegionIDs.removeAll()
    }

    // MARK: - Visit-triggered category matching (citywide, not destination-bound)

    /// Matches a `CLVisit` coordinate against a set of candidate POI categories — used by
    /// `LocationManager.didVisit` to identify what kind of place the user just dwelled at,
    /// anywhere, not just near the destination. Reuses the same query strings as
    /// `syncGeofences` rather than reverse-classifying via `MKPointOfInterestCategory`,
    /// which doesn't cover categories like DMV, bookstore, or hardware store at all.
    ///
    /// - Parameter candidateCategories: Distinct `poiCategory` values drawn from the move's
    ///   pending tasks — checked in order, first confident match wins.
    /// - Returns: The matched category, or nil if nothing resolved within `matchRadius` of
    ///   the visit coordinate.
    func matchVisitCategory(
        at coordinate: CLLocationCoordinate2D,
        candidateCategories: [POICategory]
    ) async -> POICategory? {
        // A visit's coordinate is the system's own estimate of where the user dwelled, not a
        // GPS pin on the door — 75m keeps this from matching an unrelated place a block away.
        let matchRadius: CLLocationDistance = 75

        for category in candidateCategories {
            let query = Self.searchQuery(for: category)
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 150, longitudinalMeters: 150)

            do {
                let response = try await MKLocalSearch(request: request).start()
                guard let match = response.mapItems.first else { continue }
                let matchLocation = CLLocation(
                    latitude: match.placemark.coordinate.latitude,
                    longitude: match.placemark.coordinate.longitude
                )
                let visitLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                if matchLocation.distance(from: visitLocation) <= matchRadius {
                    return category
                }
            } catch {
                logger.debug("GeofenceCoordinator: visit-match search failed for '\(query)': \(error.localizedDescription)")
            }
        }
        return nil
    }

    // MARK: - MKLocalSearch resolution

    /// `MKLocalSearch.Request.region` is only a ranking *bias*, not a hard filter — for
    /// some natural-language queries (confirmed live for "doctor physician clinic") MapKit
    /// can rank a nationally/oddly-matched result above anything actually near the
    /// requested region, returning a coordinate hundreds or thousands of km away. A
    /// geofence built from that is dead weight at best (a Denver move will never cross it)
    /// and, if the user is ever coincidentally near that real place, an actively wrong
    /// notification at worst. 50km comfortably covers even large metro areas while
    /// rejecting cross-country mismatches.
    private static let maxResultDistanceFromBias: CLLocationDistance = 50_000

    private func resolveCoordinate(
        query: String,
        near coordinate: CLLocationCoordinate2D
    ) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // Bias search toward the destination with a ~10km span
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 10_000,
            longitudinalMeters: 10_000
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            guard let result = response.mapItems.first?.placemark.coordinate else { return nil }

            let biasLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let resultLocation = CLLocation(latitude: result.latitude, longitude: result.longitude)
            let distance = resultLocation.distance(from: biasLocation)
            guard distance <= Self.maxResultDistanceFromBias else {
                logger.debug("GeofenceCoordinator: MKLocalSearch result for '\(query)' was \(Int(distance / 1000))km from the bias point — discarding as a mismatch")
                return nil
            }
            return result
        } catch {
            logger.debug("GeofenceCoordinator: MKLocalSearch error for '\(query)': \(error.localizedDescription)")
            return nil
        }
    }
}
