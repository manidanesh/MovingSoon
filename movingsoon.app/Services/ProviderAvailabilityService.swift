// ProviderAvailabilityService.swift — User-initiated, approximate provider discovery.
// A map result is a lead to verify, not proof of coverage or membership portability.
import Foundation
import CoreLocation
import MapKit

struct ProviderAvailabilityResult: Equatable {
    let nearbyCount: Int
    let nearestName: String?
    let checkedAt: Date
    let failed: Bool
}

enum ProviderAvailabilityService {
    private static let maximumResultDistance: CLLocationDistance = 50_000

    @MainActor
    static func check(provider: String, near center: CLLocationCoordinate2D) async -> ProviderAvailabilityResult {
        let checkedAt = Date()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = provider
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 30_000,
            longitudinalMeters: 30_000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let nearby = response.mapItems.compactMap { item -> (MKMapItem, CLLocationDistance)? in
                let coordinate = item.placemark.coordinate
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = location.distance(from: centerLocation)
                return distance <= maximumResultDistance ? (item, distance) : nil
            }
            let ordered = nearby.sorted { $0.1 < $1.1 }
            return ProviderAvailabilityResult(
                nearbyCount: ordered.count,
                nearestName: ordered.first?.0.name,
                checkedAt: checkedAt,
                failed: false
            )
        } catch {
            return ProviderAvailabilityResult(nearbyCount: 0, nearestName: nil, checkedAt: checkedAt, failed: true)
        }
    }
}
