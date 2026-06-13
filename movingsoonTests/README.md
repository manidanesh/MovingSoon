# movingsoonTests — Automated Test Suite

## Test Files

| File | Coverage | Tests |
|---|---|---|
| `SuppressionEngineTests.swift` | All 5+1 suppression gates | 21 tests |
| `CooldownStoreTests.swift` | UserDefaults round-trip, gate logic, persistence | 12 tests |
| `ChecklistGeneratorTests.swift` | Task generation, flag filtering, institution tasks | 16 tests |
| `ZipBucketServiceTests.swift` | ZIP → state/city/centroid mapping, Canada | 14 tests |
| `ChecklistTaskTests.swift` | State machine, category/priority round-trips | 17 tests |
| `MoveModelTests.swift` | completionFraction, daysUntilMove, counts | 10 tests |
| `RegionalIntelligenceTests.swift` | Regional brand availability by ZIP | 9 tests |
| `POICategoryTests.swift` | Display names, enum completeness | 5 tests |

**Total: ~104 tests**

## Setup

1. In Xcode: File → New → Target → Unit Testing Bundle
2. Name: `movingsoonTests`
3. Target to test: `movingsoon.app`
4. Add all `.swift` files from this folder to the new test target
5. Press ⌘U to run

## What's tested

- **SuppressionEngine**: Every gate in isolation — consent expiry boundary conditions,
  completion threshold at exactly 0.80, time-of-day window edges (8:59am, 9:00am, 6:59pm, 7:00pm),
  task relevance with muted/snoozed tasks, cooldown same-day vs next-day
- **CooldownStore**: Record → read round-trip, cross-category isolation, persistence across re-init,
  clearAll, midnight boundary edge cases
- **ChecklistGenerator**: USPS always present for US users, excluded for Canadians,
  Canada Post for Canadian users, flag-gated tasks, institution title format (no "Update address" prefix),
  hero task ordering, task count increases with flags
- **ZipBucketService**: State buckets for major states, city buckets for metros, rural fallback,
  Canadian postal codes, centroid accuracy for major metros
- **ChecklistTask**: Full toDo→pendingVerification→completed state machine, reset, category/priority
  round-trips, emoji/icon completeness
- **Move**: completionFraction math, daysUntilMove sign, completedCount/totalCount
- **RegionalIntelligence**: Publix in FL not CO, H-E-B in TX not NY, Wegmans in NY not CA, VASA in UT
- **POICategory**: All display names non-empty, specific known values

## What requires device/simulator (not auto-testable)

- GeofenceCoordinator (needs CLLocationManager + real/simulated GPS)
- SmartReminderService (needs UNUserNotificationCenter authorization)
- LocationManager (needs device)
- ZenDashboardView UI (requires UI test target with XCUIApplication)
