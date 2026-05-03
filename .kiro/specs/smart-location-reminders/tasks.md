# Implementation Plan: Smart Location Reminders

## Overview

Implement a consent-based, proximity-aware notification system for movingsoon.app. The work proceeds in dependency order: data model additions first, then pure logic components (SuppressionEngine, CooldownStore), then the geofence coordinator, then LocationManager upgrades, then SmartReminderService additions, and finally the UI consent card wired into ZenDashboardView. Property-based tests are placed immediately after the component they validate.

## Tasks

- [x] 1. Extend data models
  - [x] 1.1 Add `locationConsentGrantedAt: Date?` to `Move`
    - Add the optional `Date?` property to `Move.swift` (SwiftData handles optional additions without migration)
    - _Requirements: 2.1_

  - [x] 1.2 Add `displayName` computed property to `POICategory`
    - Add an extension on `POICategory` in `Enums.swift` with the `displayName: String` switch returning lowercase display strings as specified in the design
    - _Requirements: 6.2_

- [ ] 2. Implement `CooldownStore`
  - [x] 2.1 Create `CooldownStore.swift` in `Services/`
    - Implement the `struct CooldownStore` with `UserDefaults` backing, JSON-encoded `[String: Date]` under key `"com.movingsoon.cooldownStore"`
    - Implement `gatePasses(for:now:)` — returns `true` if no entry exists for the category or the stored date is on a different calendar day than `now`
    - Implement `record(category:date:)` — encodes and writes the updated dictionary
    - Implement `clearAll()` — removes the key from `UserDefaults`
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ]* 2.2 Write property test for `CooldownStore` round-trip (Property 11)
    - **Property 11: CooldownStore round-trip preserves recorded dates**
    - For any `POICategory` and `Date`, recording then reading back returns a date on the same calendar day; value persists across re-initialisation from the same `UserDefaults` instance
    - **Validates: Requirements 5.1, 5.2**

- [x] 3. Implement `SuppressionEngine`
  - [x] 3.1 Create `SuppressionEngine.swift` in `Services/`
    - Implement as a caseless `enum` (stateless namespace) with the `Context` struct holding `move`, `poiCategory`, `cooldownStore`, `now`, `userLocation`, `destinationCoordinate`
    - Implement all six individual gate evaluators as `internal static func` methods
    - Implement `shouldFire(context:) -> Bool` evaluating gates in fail-fast order: consent expiry → completion → time-of-day → distance → task relevance → cooldown
    - Distance gate: haversine via `CLLocation.distance(from:)` ≤ 8,000 m
    - Completion gate: `completionFraction < 0.80`
    - Time-of-day gate: `9 ≤ Calendar.current.component(.hour, from: now) < 19`
    - Consent expiry gate: `now ≤ grantedAt + 30 days`; nil `grantedAt` → gate fails
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [ ]* 3.2 Write property test for consent expiry gate (Property 2)
    - **Property 2: Consent expiry gate is a pure function of two dates**
    - For any `(grantedAt, now)` pair, `consentExpiryGatePasses` returns `true` iff `now ≤ grantedAt + 30 days`
    - **Validates: Requirements 2.2, 4.7**

  - [ ]* 3.3 Write property test for distance gate (Property 6)
    - **Property 6: Distance gate is a pure function of two coordinates**
    - For any `(userLocation, destination)` pair, `distanceGatePasses` returns `true` iff distance ≤ 8,000 m
    - **Validates: Requirements 4.2**

  - [ ]* 3.4 Write property test for task relevance gate (Property 7)
    - **Property 7: Task relevance gate reflects pending task existence**
    - For any task list and `POICategory`, `taskRelevanceGatePasses` returns `true` iff at least one task has `status == .toDo` and matching `poiCategory`
    - **Validates: Requirements 4.3**

  - [ ]* 3.5 Write property test for cooldown gate (Property 8)
    - **Property 8: Cooldown gate is a pure function of stored date and current date**
    - For any `(POICategory, lastFiredDate?, now)` triple, `cooldownGatePasses` returns `true` iff `lastFiredDate` is nil or falls on a different calendar day than `now`
    - **Validates: Requirements 4.4, 5.3, 5.4**

  - [ ]* 3.6 Write property test for completion gate (Property 9)
    - **Property 9: Completion gate threshold is exactly 0.80**
    - For any `completionFraction` in `[0.0, 1.0]`, `completionGatePasses` returns `true` iff `completionFraction < 0.80`
    - **Validates: Requirements 4.5**

  - [ ]* 3.7 Write property test for time-of-day gate (Property 10)
    - **Property 10: Time-of-day gate passes only within the 09:00–19:00 window**
    - For any `Date`, `timeOfDayGatePasses` returns `true` iff the local hour satisfies `9 ≤ hour < 19`
    - **Validates: Requirements 4.6**

- [ ] 4. Checkpoint — Ensure all SuppressionEngine and CooldownStore tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Add centroid lookup to `ZipBucketService`
  - [x] 5.1 Add `centroid(zip:)` static method to `ZipBucketService`
    - Add an extension on `ZipBucketService` in `ZipBucketService.swift`
    - Build a `[String: CLLocationCoordinate2D]` lookup table covering the same ~40 metro city buckets already present in `cityBucket(zip:)` (e.g. `"DENVER"` → `(39.7392, -104.9903)`)
    - Call `cityBucket(zip:)` to get the bucket key, then look up the centroid; fall back to continental US centroid `(39.5, -98.35)` for unknown ZIPs
    - _Requirements: 3.1, 4.2_

- [x] 6. Implement `GeofenceCoordinator`
  - [x] 6.1 Create `GeofenceCoordinator.swift` in `Services/`
    - Implement `@Observable final class GeofenceCoordinator` with `private(set) var registeredRegionIDs: Set<String>`
    - Implement `syncGeofences(for:destinationCoordinate:manager:) async` — filters tasks to `status == .toDo` with non-nil `poiCategory`, sorts by `tMinusDays` ascending (most urgent first), caps at 20, runs `MKLocalSearch` per task using the query strings from the design table, registers a `CLCircularRegion` with `radius: 200` and identifier `task.id.uuidString`, logs via `os_log` when `MKLocalSearch` returns no results
    - Implement `removeGeofence(for:manager:)` — calls `stopMonitoring` for the region matching `task.id.uuidString`
    - Implement `removeAllGeofences(manager:)` — calls `stopMonitoring` for every region in `manager.monitoredRegions`
    - _Requirements: 2.3, 2.5, 3.1, 3.2, 3.4, 3.5_

  - [ ]* 6.2 Write property test for geofence count cap (Property 3)
    - **Property 3: Geofence count never exceeds 20 and matches pending POI tasks**
    - For any task list, after `syncGeofences` completes, registered region count equals `min(pendingPOITaskCount, 20)`
    - **Validates: Requirements 2.5, 3.5**

  - [ ]* 6.3 Write property test for geofence radius (Property 4)
    - **Property 4: All registered geofences have radius exactly 200 metres**
    - For any set of resolved POI coordinates, every registered `CLCircularRegion` has `radius == 200.0`
    - **Validates: Requirements 3.2**

  - [ ]* 6.4 Write property test for task completion removes geofence (Property 5)
    - **Property 5: Completing or verifying a task removes its geofence**
    - For any `ChecklistTask` with a registered geofence, advancing status to `.completed` or `.pendingVerification` causes `stopMonitoring` to be called for the region with identifier `task.id.uuidString`
    - **Validates: Requirements 3.3**

  - [ ]* 6.5 Write integration test for `syncGeofences` MKLocalSearch calls
    - Inject a mock `MKLocalSearch` provider via protocol
    - Verify `MKLocalSearch` is called exactly once per pending POI task
    - Verify that empty search results skip registration and emit an `os_log` diagnostic
    - _Requirements: 3.1, 3.4_

- [-] 7. Upgrade `LocationManager`
  - [x] 7.1 Remove mock Denver coordinate and inject `GeofenceCoordinator`
    - Delete the hardcoded Denver `dummyCoordinate` and the existing `setupGeofences(for:)` implementation
    - Add `var geofenceCoordinator = GeofenceCoordinator()` as an `@Observable`-tracked property
    - Add `var currentLocation: CLLocation?` updated in `locationManager(_:didUpdateLocations:)`
    - Add `var move: Move?` and `var cooldownStore = CooldownStore()` as injectable properties
    - _Requirements: 3.1, 3.2, 4.2_

  - [x] 7.2 Implement `didEnterRegion` suppression and notification dispatch
    - In `locationManager(_:didEnterRegion:)`, extract `taskID` from `region.identifier`, look up the matching `ChecklistTask` in `move.tasks`, resolve `destinationCoordinate` via `ZipBucketService.centroid(zip:)`
    - Build a `SuppressionEngine.Context` and call `SuppressionEngine.shouldFire(context:)`
    - On `true`: call `SmartReminderService.fireLocationNotification(task:poiCategory:)` and `cooldownStore.record(category:date:)`
    - Guard against nil `currentLocation` — treat as distance gate failure (suppress)
    - _Requirements: 4.1, 4.8, 5.2_

  - [x] 7.3 Implement consent expiry geofence teardown
    - Add a method `checkConsentExpiry()` that evaluates whether `move.locationConsentGrantedAt` is expired (> 30 days ago)
    - If expired, call `geofenceCoordinator.removeAllGeofences(manager:)` and `cooldownStore.clearAll()`
    - Call `checkConsentExpiry()` from `locationManagerDidChangeAuthorization` and on app foreground
    - _Requirements: 2.2, 2.3_

  - [x] 7.4 Wire `GeofenceCoordinator.syncGeofences` into authorization grant flow
    - After `authorizationStatus` changes to `.authorizedAlways` or `.authorizedWhenInUse`, call `geofenceCoordinator.syncGeofences(for:destinationCoordinate:manager:)` if the consent window is active
    - Also call `syncGeofences` when a task's status changes to `.completed` or `.pendingVerification` (to remove its geofence)
    - _Requirements: 2.5, 3.3_

- [x] 8. Upgrade `SmartReminderService`
  - [x] 8.1 Add `fireLocationNotification(task:poiCategory:)` method
    - Implement the method in `SmartReminderService.swift`
    - Set `content.title = "Address update nearby"`
    - Set `content.body = "You're near a \(poiCategory.displayName) — update your address while you're here."`
    - Set `content.userInfo = ["taskID": task.id.uuidString]`
    - Set `content.sound = .default`
    - Fire with a nil trigger (immediate delivery)
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]* 8.2 Write property test for notification body contains display name (Property 12)
    - **Property 12: Notification body contains the POI category display name**
    - For any `POICategory`, the notification body produced by `fireLocationNotification` contains `poiCategory.displayName` as a substring
    - **Validates: Requirements 6.2**

  - [ ]* 8.3 Write property test for notification userInfo contains task ID (Property 13)
    - **Property 13: Notification userInfo contains the task ID**
    - For any `ChecklistTask`, `userInfo["taskID"]` equals `task.id.uuidString`
    - **Validates: Requirements 6.3**

  - [ ]* 8.4 Write unit tests for `SmartReminderService` notification content
    - Test that `content.title` is exactly `"Address update nearby"` (Req 6.1)
    - Test that `content.sound` is `.default` (Req 6.4)
    - _Requirements: 6.1, 6.4_

- [ ] 9. Checkpoint — Ensure all service-layer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement `LocationConsentCard` view
  - [x] 10.1 Create `LocationConsentCard.swift` in `Views/Components/`
    - Implement `struct LocationConsentCard: View` with `let onAllow: () -> Void` and `let onDismiss: () -> Void` callbacks
    - Display the exact copy: "Give us access for 30 days — we'll notify you when you're near a place that needs your new address."
    - Render a primary "Allow 30 Days" button that calls `onAllow`
    - Render a secondary "Not Now" button that calls `onDismiss`
    - Match the existing card visual style from `ZenDashboardView` (use `Theme` colours, `RoundedRectangle` with `cornerRadius: 16`, `backgroundCard` fill)
    - _Requirements: 1.3, 1.4_

  - [ ]* 10.2 Write unit tests for `LocationConsentCard` display
    - Test that the card renders the correct copy text (Req 1.3)
    - Test that both action buttons are present (Req 1.4)
    - Test that tapping "Allow 30 Days" invokes `onAllow` (Req 1.5)
    - Test that tapping "Not Now" invokes `onDismiss` (Req 1.6)
    - _Requirements: 1.3, 1.4, 1.5, 1.6_

- [x] 11. Wire `LocationConsentCard` into `ZenDashboardView`
  - [x] 11.1 Add consent card state and display logic to `ZenDashboardView`
    - Add `@State private var consentCardDismissed: Bool = false` to `ZenDashboardView`
    - Add `@Environment` or injected `LocationManager` reference
    - Implement `shouldShowConsentCard: Bool` computed property: returns `false` if `move.locationConsentGrantedAt != nil`; returns `false` if `move.daysUntilMove > 14`; returns `false` if `consentCardDismissed`; returns `true` if `authorizationStatus == .notDetermined || .denied`
    - Insert `LocationConsentCard` into the `VStack` in `ZenDashboardView.body` when `shouldShowConsentCard` is `true`
    - _Requirements: 1.1, 1.2, 1.6_

  - [x] 11.2 Implement "Allow 30 Days" tap handler
    - In the `onAllow` closure passed to `LocationConsentCard`, call `locationManager.requestPermissions()` (which calls `requestAlwaysAuthorization()`)
    - In `LocationManager.locationManagerDidChangeAuthorization`, when status becomes `.authorizedAlways` or `.authorizedWhenInUse`, set `move.locationConsentGrantedAt = Date()` and call `try? modelContext.save()`
    - _Requirements: 1.5, 1.7_

  - [x] 11.3 Implement "Not Now" tap handler
    - In the `onDismiss` closure, set `consentCardDismissed = true` (session-only; resets on next launch)
    - _Requirements: 1.6_

  - [ ]* 11.4 Write property test for consent card visibility predicate (Property 1)
    - **Property 1: Consent card visibility is determined by consent history and proximity to move date**
    - For any `Move` with non-nil `locationConsentGrantedAt`, `shouldShowConsentCard` returns `false` regardless of other state
    - For any `Move` with nil `locationConsentGrantedAt` and `daysUntilMove ≤ 14`, returns `true` when `authorizationStatus` is `.notDetermined` or `.denied`
    - **Validates: Requirements 1.1, 1.2**

  - [ ]* 11.5 Write unit tests for authorization grant persisting consent date
    - Test that granting authorization sets `move.locationConsentGrantedAt` to approximately `Date()` (Req 1.7)
    - Test that `move.locationConsentGrantedAt` persists across SwiftData save/reload (Req 2.1)
    - _Requirements: 1.7, 2.1_

  - [ ]* 11.6 Write unit test for consent expiry calling `stopMonitoring`
    - Test that when `Date()` exceeds `locationConsentGrantedAt + 30 days`, `GeofenceCoordinator.removeAllGeofences` is called (Req 2.3)
    - _Requirements: 2.3_

- [ ] 12. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests use [SwiftCheck](https://github.com/typelift/SwiftCheck) with a minimum of 100 iterations per property
- Tag each property test with `// Feature: smart-location-reminders, Property N: <property text>`
- The `CLCircularRegion` identifier convention is `task.id.uuidString` throughout — this is the key that connects geofence events back to tasks
- `SuppressionEngine` is a caseless enum (not a class) — it holds no state and is trivially testable
- `CooldownStore` uses `UserDefaults` (not SwiftData) — intentionally lightweight for six keys
