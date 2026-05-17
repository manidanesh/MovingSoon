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
        case .bank:       return "bank"
        case .gym:        return "gym"
        case .dmv:        return "DMV department of motor vehicles"
        case .grocery:    return "grocery store supermarket"
        case .postOffice: return "post office USPS"
        case .pharmacy:   return "pharmacy drugstore"
        case .bookstore:  return "bookstore Barnes & Noble"
        case .outdoorGear: return "outdoor gear REI"
        case .hardwareStore: return "hardware store Home Depot Lowe's"
        case .doctor:     return "doctor physician clinic"
        case .other:      return "address update"
        }
    }

    // MARK: - Sync geofences

    /// Resolves POI coordinates via MKLocalSearch and registers geofences.
    /// Filters to pending tasks with a poiCategory, sorts by urgency (tMinusDays ascending),
    /// caps at 20 regions (iOS system limit).
    func syncGeofences(
        for tasks: [ChecklistTask],
        currentLocation: CLLocationCoordinate2D?,
        manager: CLLocationManager
    ) async {
        // Filter to pending tasks that have a physical POI category
        let pendingPOITasks = tasks
            .filter { $0.status == .toDo && $0.poiCategory != nil }
            .sorted { $0.tMinusDays < $1.tMinusDays }  // most urgent first
            .prefix(Self.maxGeofences)

        for task in pendingPOITasks {
            guard let category = task.poiCategory else { continue }
            guard !registeredRegionIDs.contains(task.id.uuidString) else { continue }

            let query = Self.searchQuery(for: category)
            let coordinate = await resolveCoordinate(query: query, near: currentLocation)

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

    // MARK: - MKLocalSearch resolution

    private func resolveCoordinate(
        query: String,
        near coordinate: CLLocationCoordinate2D?
    ) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // Bias search toward the current location with a ~10km span
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 10_000,
                longitudinalMeters: 10_000
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            logger.debug("GeofenceCoordinator: MKLocalSearch error for '\(query)': \(error.localizedDescription)")
            return nil
        }
    }
}
