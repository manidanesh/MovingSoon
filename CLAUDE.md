# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MovingSoon — a SwiftUI/SwiftData iOS app that generates a personalized, prioritized moving checklist (address updates across banks, government, subscriptions, etc.) based on a lifestyle interview. iOS 17+, Xcode 15+. See `README.md` for the full feature list and `APP_STORE_LISTING.md` / `PRIVACY_POLICY.md` for store-facing copy.

## Build & Test

This is a plain `.xcodeproj` (no SPM package, no CocoaPods/Carthage). Xcode uses the newer file-system-synchronized groups, so adding a `.swift` file to the right folder on disk is enough — no manual "add to target" step needed for files already under a synced group.

```bash
# Build
xcodebuild build -project movingsoon.app.xcodeproj -scheme movingsoon.app \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run the full test suite
xcodebuild test -project movingsoon.app.xcodeproj -scheme movingsoon.app \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test (Swift Testing syntax — see note below)
xcodebuild test -project movingsoon.app.xcodeproj -scheme movingsoon.app \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:movingsoon.appTests/ConsentExpiryGateTests
```

Or open `movingsoon.app.xcodeproj` in Xcode and press ⌘U.

**Important — two test folders exist, only one is live:**
- `movingsoon.appTests/movingsoon_appTests.swift` is the **active** suite, wired into the `movingsoon.appTests` target and written with the Swift **Testing** framework (`@Suite` / `@Test` / `#expect`, `@testable import movingsoon_app`). This is what `xcodebuild test` actually runs.
- `movingsoonTests/` is a **legacy, unwired** XCTest-based suite (`XCTestCase`, `@testable import movingsoon_app`) covering the same ground in more detail (ChecklistGenerator, Move, ZipBucketService, RegionalIntelligence, etc. — see `movingsoonTests/README.md`). It is not attached to any build target and `xcodebuild test` silently ignores it. If you add coverage, prefer extending `movingsoon.appTests/movingsoon_appTests.swift` (Swift Testing) unless the user asks you to wire `movingsoonTests` into the project first.
- `GeofenceCoordinator`, `SmartReminderService`, `LocationManager`, and dashboard UI are not unit-testable (need CoreLocation / UNUserNotificationCenter / XCUIApplication) — see `movingsoonTests/README.md` for the full breakdown of what's covered vs. device-only.

## Architecture

### Data flow: lifestyle flags → checklist

The entire app pivots on one idea: a `Set<LifestyleFlag>` (100+ cases in `Models/LifestyleProfile.swift`) drives which of the 150+ `CatalogItem`s in `Services/ItemCatalog*.swift` become `ChecklistTask`s.

1. **Onboarding** (`Views/Onboarding/CoreIntakeView.swift`) collects move date + destination ZIP and creates the `Move` (SwiftData model).
2. **Lifestyle Interview** (`Views/LifestyleInterview/LifestyleInterviewView.swift`, 7 screens) toggles `LifestyleFlag`s on the `Move`'s `LifestyleProfile` (stored as JSON-encoded `[String]`, not a native SwiftData relationship to enum cases) and financial institutions (`FinancialScreenView.swift`, backed by `Services/KnownInstitutions.swift`).
3. **`ChecklistGenerator.generate(for:profile:institutions:)`** (`Services/ChecklistGenerator.swift`) is the single point where flags become tasks:
   - Iterates `ItemCatalog.all` (merged from `ItemCatalog.swift` + `ItemCatalog+{Canada,Digital,Insurance,Lifestyle,Travel}.swift` extensions), applying `shouldInclude` filter logic on each `CatalogItem`: `excludes` (any match → drop, trumps everything) → `alwaysInclude` (short-circuits to include) → `requires` (must be a subset of flags, AND) → `requiresAny` (must intersect flags, OR).
   - Generates one task per selected `FinancialInstitution`, with priority/timing derived from `InstitutionType` (banks/credit unions/mortgages are `.critical` at t-14; cards/loans `.high` at t-7; investments `.high` at t+7).
   - USPS Mail Forwarding is `alwaysInclude` + `isHeroItem`, excluded only for `.isCanadian`; hero items are always sorted first.
4. **`ContentView`** is a phase router (`loading → onboarding → lifestyleInterview → dashboard`) keyed off whether an "active" `Move` exists and whether it has a `LifestyleProfile` yet — there's no separate navigation stack/coordinator.
5. **`ZenDashboardView`** is the primary UI: one "Current Objective" hero task, a "Next Up" drawer, and a completion ring computed from `Move.completionFraction`.

`ChecklistTask` is a 3-state machine (`toDo → pendingVerification → completed`) via `advanceStatus()`; each transition to `completed` appends a `VerificationEvent`. `resetStatus()` undoes it and clears events.

### Regional intelligence (on-device, no network)

`Services/ZipBucketService.swift` maps a US ZIP prefix (3-digit, not 2 — New England/NJ, WV, and MS/TN each need that precision to avoid collapsing distinct states into one bucket) or Canadian postal-code letter to a state/province bucket (and city bucket for major metros) purely with static lookup tables — no geocoding call. Unmapped/invalid prefixes return the literal string `"US"`, not `nil` — any code branching on the bucket (e.g. `KnownInstitutions.filtered(_:forStateBucket:)`) must treat `"US"` the same as "unknown," not as a real state. `Services/KnownInstitutions.swift`'s `filtered(_:forStateBucket:)` filters *only strictly regional* banks (sourced from the FDIC BankFind API) by that state bucket; national and branchless/digital-first banks aren't touched. (There is no longer a separate RegionalIntelligenceService — it gated regional grocery/gym/ISP chips the interview never actually offered, so it was dead code and was removed.) `Services/CityBackgroundMapper.swift` uses the same bucket to pick a bundled ambient background image (with `Services/UnsplashService.swift` as the network-backed alternative). `Services/GeocoderService.swift` resolves human-readable neighborhood strings for display only, and is separate from `ZipBucketService`'s bucket logic.

### Smart Location Reminders (geofencing + anti-nag notifications)

This subsystem was built from a formal spec — see `.kiro/specs/smart-location-reminders/{requirements,design,tasks}.md` for the authoritative behavior contract before changing any of these files:

- `Services/SuppressionEngine.swift` is a **stateless**, fully unit-tested gate evaluator (`shouldFire`) — six gates must *all* pass, fail-fast in order: consent-not-expired (30 days from `Move.locationConsentGrantedAt`) → move <80% complete → 9am–7pm local time → within 8000m of destination → a matching non-muted/non-snoozed `.toDo` task exists for the POI category → per-category cooldown (max 1/day, `CooldownStore`, UserDefaults-backed). Each gate is exposed as its own static function specifically so it can be tested in isolation — keep that shape when modifying.
- `Services/GeofenceCoordinator.swift` resolves real POI coordinates near the **destination** (not the user's current location) via `MKLocalSearch`, capped at iOS's 20-geofence system limit, sorted by task urgency (`tMinusDays`).
- `Services/LocationManager.swift` owns `CLLocationManager` authorization/delegate callbacks and is the glue that calls `SuppressionEngine` then `SmartReminderService.fireLocationNotification`.
- `Services/SmartReminderService.swift` also runs two independent notification protocols: a daily 10am reminder for the hero task *only if* it's `.critical` priority ("anti-nag"), and a T-minus-3-days **digest** notification (one push per day summarizing all tasks due soon, not one per task).
- Consent, once granted, is never re-requested — `locationConsentGrantedAt` on `Move` is the only source of truth; there's no separate "denied" flag to re-check.

### Privacy telemetry (dormant)

`Models/PendingSignal.swift` is a fully-defined on-device queue model (Laplace noise on embeddings, timestamps floored to the hour, persona/region buckets only — no PII) but **no service currently emits into it**. `PersonaEngine.swift` similarly exists (maps onboarding answers → `PersonaKey`) but isn't called during onboarding; `Move.personaKey` derives the persona lazily from `LifestyleProfile` flags instead. Don't assume either is wired up without checking call sites first.

### Catalog/institution data files

`Services/ItemCatalog*.swift` and `Services/KnownInstitutions.swift` are large, flat, declarative data files (arrays of `CatalogItem`/`KnownInstitution` struct literals with brand colors, deep-link URLs, flag requirements). When adding a new addressable service or institution, follow the existing literal style in the relevant file rather than introducing new abstractions — these files are intentionally just data.

### Design system

`Theme.swift` is the single source for colors/typography ("Calm Confidence" navy + electric-blue palette, dark-mode only — `ContentView` forces `.preferredColorScheme(.dark)`). Priority/status colors (`priorityCritical`, `accentSuccess`, etc.) are defined once there and should be reused rather than hardcoded in views.
