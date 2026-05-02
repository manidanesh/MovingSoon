// LocationManager.swift — Geofencing and Location Awareness
import Foundation
import CoreLocation
import UserNotifications
import SwiftData

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    /// Scans pending tasks and sets up geofences for those with a physical POI category.
    func setupGeofences(for tasks: [ChecklistTask]) {
        // Clear existing geofences
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }

        // We only care about pending tasks that have a POI category
        let pendingPOITasks = tasks.filter { $0.status == .toDo && $0.poiCategory != nil }

        for task in pendingPOITasks {
            // MOCK: In a real app, we would query MKLocalSearch for the nearest POI.
            // For this phase, we mock a coordinate near a generic user location.
            // Let's use a dummy coordinate for demonstration.
            let dummyCoordinate = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903) // Denver
            
            let region = CLCircularRegion(center: dummyCoordinate, radius: 200, identifier: task.id.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            manager.startMonitoring(for: region)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        // Trigger a local notification
        let content = UNMutableNotificationContent()
        content.title = "Address Update Opportunity"
        content.body = "You are near a location for one of your pending tasks. Update your address while you're here!"
        content.sound = .default
        
        // We embed the task ID in userInfo
        content.userInfo = ["taskID": circularRegion.identifier]

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Fire immediately
        UNUserNotificationCenter.current().add(request)
    }
}
