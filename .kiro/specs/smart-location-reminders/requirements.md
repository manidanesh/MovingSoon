# Requirements Document

## Introduction

The Smart Location Reminders feature adds a consent-based, proximity-aware notification system to the movingsoon.app iOS app. When a user's move is imminent (≤14 days away), the app prompts for location access and — once granted — monitors the user's proximity to destination-area POIs relevant to their pending address-change tasks. A multi-gate suppression algorithm prevents over-notification. Consent is time-bounded to 30 days and is never re-requested after it has been granted.

## Glossary

- **Move**: The SwiftData `Move` model representing the user's active relocation, containing `anchorDate`, `destinationZip`, `tasks`, and `completionFraction`.
- **ChecklistTask**: The SwiftData `ChecklistTask` model representing a single address-change task, with optional `poiCategory` and `status`.
- **POICategory**: The `POICategory` enum (Bank, Gym, DMV, Grocery, Post Office, Pharmacy, Other) that classifies a task's physical location type.
- **LocationManager**: The existing `LocationManager.swift` service responsible for CoreLocation authorization and geofence registration.
- **SmartReminderService**: The existing `SmartReminderService.swift` service responsible for scheduling local push notifications.
- **ZenDashboardView**: The main dashboard SwiftUI view where the consent prompt card is displayed.
- **ConsentCard**: The dismissible SwiftUI card component shown on `ZenDashboardView` to request location access.
- **SuppressionEngine**: The logic component that evaluates all suppression gates before allowing a notification to fire.
- **GeofenceCoordinator**: The component responsible for resolving destination POI coordinates via `MKLocalSearch` and registering `CLCircularRegion` geofences.
- **CooldownStore**: The persistent store (SwiftData or `UserDefaults`) that records the last-fired timestamp per `POICategory`.
- **ConsentWindow**: The 30-day period starting from `locationConsentGrantedAt` during which location monitoring is active.
- **daysUntilMove**: The computed property on `Move` returning the integer number of calendar days between today and `anchorDate`.
- **completionFraction**: The computed property on `Move` returning the ratio of completed tasks to total tasks (0.0–1.0).

---

## Requirements

### Requirement 1: Consent Prompt Card Display

**User Story:** As a user approaching my move date, I want to see a clear, non-intrusive prompt asking for location access, so that I can make an informed decision about enabling proximity reminders.

#### Acceptance Criteria

1. WHEN `move.daysUntilMove` is less than or equal to 14 AND the device location authorization status is `.notDetermined` or `.denied`, THE `ZenDashboardView` SHALL display the `ConsentCard`.
2. WHEN `move.locationConsentGrantedAt` is not nil (consent was previously granted), THE `ZenDashboardView` SHALL NOT display the `ConsentCard`, regardless of current authorization status or days until move.
3. THE `ConsentCard` SHALL display the copy: "Give us access for 30 days — we'll notify you when you're near a place that needs your new address."
4. THE `ConsentCard` SHALL present two actions: a primary "Allow 30 Days" button and a secondary "Not Now" button.
5. WHEN the user taps "Allow 30 Days", THE `LocationManager` SHALL call `requestAlwaysAuthorization()` on the system location manager.
6. WHEN the user taps "Not Now", THE `ZenDashboardView` SHALL dismiss the `ConsentCard` for the current app session without persisting the dismissal.
7. WHEN the system grants location authorization following the "Allow 30 Days" tap, THE `Move` model SHALL record the current date in `locationConsentGrantedAt` and persist it via SwiftData.

### Requirement 2: Consent Window Management

**User Story:** As a user who granted location access, I want the app to automatically stop monitoring after 30 days, so that I don't have to manually revoke permissions.

#### Acceptance Criteria

1. THE `Move` model SHALL store a `locationConsentGrantedAt` property of type `Date?`, persisted in SwiftData.
2. WHEN `Date()` is greater than `locationConsentGrantedAt` plus 30 days, THE `SuppressionEngine` SHALL treat the consent as expired and suppress all location-triggered notifications.
3. WHEN consent expires, THE `GeofenceCoordinator` SHALL remove all registered `CLCircularRegion` geofences by calling `stopMonitoring` for each monitored region.
4. WHEN consent expires, THE `ZenDashboardView` SHALL NOT display the `ConsentCard` again (the card is permanently suppressed once consent has ever been granted).
5. WHILE the `ConsentWindow` is active, THE `GeofenceCoordinator` SHALL maintain geofences for all pending tasks that have a non-nil `poiCategory`.

### Requirement 3: Geofence Registration

**User Story:** As a user who granted location access, I want geofences placed near real POIs at my destination, so that notifications are triggered by actual nearby locations rather than arbitrary coordinates.

#### Acceptance Criteria

1. WHEN the `ConsentWindow` is active, THE `GeofenceCoordinator` SHALL use `MKLocalSearch` to resolve the nearest POI coordinate for each pending `ChecklistTask` that has a non-nil `poiCategory`, searching near the destination ZIP's approximate coordinate.
2. THE `GeofenceCoordinator` SHALL register a `CLCircularRegion` with a radius of 200 metres for each resolved POI coordinate.
3. WHEN a `ChecklistTask`'s `status` changes to `.completed` or `.pendingVerification`, THE `GeofenceCoordinator` SHALL remove the corresponding `CLCircularRegion` from monitoring.
4. IF `MKLocalSearch` returns no results for a given `poiCategory`, THEN THE `GeofenceCoordinator` SHALL skip geofence registration for that task and log a diagnostic message.
5. THE `GeofenceCoordinator` SHALL NOT register more than 20 geofences simultaneously, respecting the iOS CoreLocation system limit.

### Requirement 4: Suppression Engine — Multi-Gate Algorithm

**User Story:** As a user, I want to receive location reminders only when they are genuinely relevant and timely, so that I am not over-notified during my move.

#### Acceptance Criteria

1. WHEN the device enters a monitored `CLCircularRegion`, THE `SuppressionEngine` SHALL evaluate all six suppression gates before firing a notification; all gates must pass.
2. **Distance gate**: WHEN the user's current location is NOT within 8 kilometres of the destination ZIP's approximate coordinate, THE `SuppressionEngine` SHALL suppress the notification.
3. **Task relevance gate**: WHEN there is no pending (`status == .toDo`) `ChecklistTask` with a `poiCategory` matching the entered region's category, THE `SuppressionEngine` SHALL suppress the notification.
4. **Cooldown gate**: WHEN a notification for the same `POICategory` has already been fired on the current calendar day, THE `SuppressionEngine` SHALL suppress the notification.
5. **Completion gate**: WHEN `move.completionFraction` is greater than or equal to 0.80, THE `SuppressionEngine` SHALL suppress all location-triggered notifications.
6. **Time-of-day gate**: WHEN the current local time is before 09:00 or after 19:00, THE `SuppressionEngine` SHALL suppress the notification.
7. **Consent expiry gate**: WHEN `Date()` is greater than `locationConsentGrantedAt` plus 30 days, THE `SuppressionEngine` SHALL suppress the notification.
8. WHEN all six gates pass, THE `SuppressionEngine` SHALL instruct `SmartReminderService` to fire the notification and update the `CooldownStore` with the current timestamp for the relevant `POICategory`.

### Requirement 5: Cooldown Persistence

**User Story:** As a user, I want the app to remember that it already notified me today for a given location type, so that I don't receive duplicate reminders within the same day.

#### Acceptance Criteria

1. THE `CooldownStore` SHALL persist the last-fired `Date` for each `POICategory` across app launches.
2. WHEN the `SuppressionEngine` fires a notification for a `POICategory`, THE `CooldownStore` SHALL record the current `Date` for that category.
3. WHEN the `SuppressionEngine` evaluates the cooldown gate, THE `CooldownStore` SHALL return `true` (gate passes) if no entry exists for the `POICategory` or if the stored date is not on the current calendar day.
4. WHEN the `SuppressionEngine` evaluates the cooldown gate, THE `CooldownStore` SHALL return `false` (gate fails) if the stored date for the `POICategory` falls on the current calendar day.

### Requirement 6: Notification Content

**User Story:** As a user near a relevant POI, I want to receive a clear, actionable notification that tells me what to do and where I am, so that I can act on it immediately.

#### Acceptance Criteria

1. THE `SmartReminderService` SHALL set the notification title to "Address update nearby".
2. THE `SmartReminderService` SHALL set the notification body to "You're near a [POI type] — update your address while you're here.", where `[POI type]` is the lowercase display name of the `POICategory` (e.g. "bank", "post office").
3. THE `SmartReminderService` SHALL include the triggering `ChecklistTask`'s `id` (as a `UUID` string) in the notification's `userInfo` dictionary under the key `"taskID"`.
4. THE `SmartReminderService` SHALL use the default notification sound.
