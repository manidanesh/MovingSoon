# CLAUDE.md

Guidance for work in the MovingSoon repository. Updated October 22, 2026 for the current local architecture; release/device verification is recorded separately.

## Project and build

MovingSoon is a SwiftUI/SwiftData address-change checklist for iOS 17+. It uses one plain `.xcodeproj`, filesystem-synchronized source groups and no CocoaPods/SPM dependency layer. Xcode 26 or later is required for the current release validation. `scripts/select_xcode.py` reads installed app version metadata and chooses the newest complete compatible installation; CI exports its developer directory through `GITHUB_ENV` without changing host-wide `xcode-select`.

```sh
xcodebuild build -project movingsoon.app.xcodeproj -scheme movingsoon.app -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project movingsoon.app.xcodeproj -scheme movingsoon.app -destination 'platform=iOS Simulator,name=iPhone 16'
```

`movingsoon.appTests/movingsoon_appTests.swift` is the sole wired test suite, using `Testing` (`@Suite`, `@Test`, `#expect`, `@testable import movingsoon_app`). Add meaningful regression coverage there, not a second unwired XCTest folder. Local simulator names may differ; inspect `xcodebuild -showdestinations` when needed. Device background delivery, permissions and old-store upgrade behavior require acceptance checks beyond unit tests.

## Data flow and views

1. `CoreIntakeView` creates a move from a calendar move date, destination postal code and optional origin. The household/service interview uses three screens, not the original seven-screen plan.
2. `LifestyleProfile` stores household answers and JSON-encoded lifestyle flags; `KnownInstitutions` supplies the selected financial organizations.
3. `ChecklistGenerator` uses the shared declarative `ItemCatalog*.swift` definitions, explicit confirmations and independent origin/destination geographic contexts. Exclusions, confirmation requirements and household applicability must remain consistent between generation and review.
4. `MoveChecklistService` preserves canonical catalog identity and explicit decisions; task UUIDs represent separate account instances. Do not use display titles as the primary identity. Existing titles/obsolete links have conservative migration aliases.
5. `ContentView` routes the newest active move through intake/interview/dashboard. Archived/cancelled moves stay in the library; only one move is active after an explicit activation.
6. `ZenDashboardView` owns dashboard orchestration. Supporting tiles/rows/timeline/milestones live in `DashboardSupportingViews.swift`; `TaskActionSheet.swift` owns task detail and guidance. `DashboardView` is the full task list. Avoid recreating duplicate view definitions in the main dashboard file.

The core model retains three stored task states (`toDo`, `pendingVerification`, `completed`), while normal manual completion advances directly through pending to completed. The app does not verify outside-provider completion. Use `ChecklistActions` for complete/reopen/remove: save first, then reschedule/reattach reminders only on success. Reopen clears mute and snooze. `ModelContext.saveOrLog()` returns a Bool indicating whether saving succeeded, rolls failures back and reports through `PersistenceIssueCenter`; affected entity types are refetched in the same context to refresh SwiftData's cached observed values. Views must not dismiss drafts or celebrate a failed save. The main context disables autosave so explicit-save rollback boundaries remain meaningful.

## Calendar dates

`Models/DateOnly.swift` stores Gregorian `YYYY-MM-DD` components for moving day, shipment/renewal dates and custom deadlines. These are calendar dates, not UTC instants. Use the model's `moveDate(calendar:)`, `effectiveAnchorDate`, shipment/renewal/custom date accessors and setters, and existing calendar-based due-date helpers. Reminder schedules interpret dates in the current local timezone. Legacy Date fields remain for compatibility; backfill preserves the day currently displayed because the historical originating timezone was never stored. Do not replace these helpers with raw time-interval arithmetic for day-only values. Consent, snooze and event timestamps remain instants.

## Action content and postal regions

`CatalogGuidance` returns eligibility, preparation, steps, suggested timing, source URL/title, review date and `sourceNote`. Distinguish primary-source instructions from provider-neutral checks. `actionURL(for:move:)` resolves US motor-vehicle actions to an official destination agency or the USAGov directory; do not reintroduce commercial dmv.org links. App dates are planning suggestions, not a jurisdiction deadline system. Source maintenance: `python3 scripts/check_catalog_links.py` is deterministic/offline; `--live-verify` explicitly enables public HTTP checks and leaves blocked/time-out destinations unverified.

`ZipBucketService` is an offline postal-region approximation covering the 50 states/DC, explicit territory/Pacific/military postal regions and Canadian provinces/territories (including NU). It is not address validation or proof of a legal jurisdiction. Unknown/unassigned prefixes return `US`; downstream code must treat that as unknown, not as a real state. `repairRegionBuckets(for:)` repairs stale persisted destination state/city values without touching progress. `PostalCodeService` provides consistent formatting and independent origin/destination eligibility. `GeocoderService` uses Apple's service for optional display neighborhoods/coordinates.

Catalog files and institution directories intentionally remain flat declarative data. Add consistent IDs, applicability and maintained links in that form. Equivalent entries share a canonical ID; a new explicitly added account receives another UUID. Never assume enrollment from children, retirement, income or a postal region. `ServiceDiscoveryEngine` ranks review questions, respects remembered answers and reviewed families, and retains the seven-day unsure pause.

## Reminders and location

`LOCATION_REMINDERS_IMPLEMENTATION.md` documents the current contract and supersedes older `.kiro/specs/smart-location-reminders/` names, timings and limits.

- `ReminderPolicy` centralizes eligibility, revision inputs and explicit consent. Location consent has an explicit 30-day request; customers may stop immediately or explicitly start another window after stopping/expiry. Authorization callbacks never silently extend it.
- `LocationConsentRenewal` prequeues one expiry invitation per consent cycle while eligible critical tasks remain. It reserves one notification slot, honors quiet hours and uses an explicitly zoned trigger. Already-past notice dates are not requeued; the dashboard offers review instead. Dedicated delegate/router handling opens Reminders and never opts in. Explicit Stop suppresses invitations. Successful grant/stop saves reconcile the schedule.
- `ReminderControlsView` keeps notification settings accessible without location consent and displays consent expiry, schedule coverage, deferred alerts and errors. `TaskReminderControls` exposes mute/unmute and snooze recovery.
- `LocationPlaceTarget` resolves named catalog providers, financial institutions and explicitly entered provider names. Unsupported/unknown generic personal providers remain regular checklist reminders. Certain government/mechanic checks intentionally match a place type.
- `LocationRegionPlan` produces all eligible account targets sorted by due date. The coordinator deduplicates destination zones by provider/target and monitors at most 20. Accounts sharing a provider share a zone; the earliest eligible account is selected. Visit matching searches all eligible unique targets instead of truncating to the destination-region limit.
- `GeofenceCoordinator` uses injected place-search/region-monitor adapters, reconciles the actual monitored system regions and invalidates stale asynchronous searches. No guessed destination zone is registered for unknown coordinates.
- `SuppressionEngine` remains stateless and independently testable: active consent, <80% completion, daytime, task eligibility, category cooldown and destination distance where applicable. Visit events have their own recency/accuracy checks. `NotificationBudget` independently caps nearby alert submissions at two per local day; scheduled morning/date alerts do not consume that allowance, and clearing Notification Center does not reset it. It cannot universally gate already-queued OS calendar alerts.
- `ReminderScheduleBuilder` builds finite one-shot requests within a rolling 30-day date window. Critical check-ins cover seven days. Its plan returns coverage/deferred-capacity metadata. Same-day account events batch together. The app reserves at most 60 requests, respects other pending requests, and tells customers to reopen/refresh; far-future dates stay on the checklist even when their alerts are not yet queued.
- `SmartReminderService` serializes schedule reconciliation so the latest saved edit wins. All surfaces/notification actions must reschedule through it after a successful save. Background region/visit delivery requires Always authorization and notifications; continuous updates run only during consented foreground use. iOS controls actual delivery.

## Lifecycle, sharing and privacy

`MoveLifecycleService` archives/cancels without deleting progress and removes active reminder consent. Reactivating a saved move archives any other active move and requires a fresh nearby-reminder choice. `MoveLibraryView` exposes saved moves, readable checklist sharing and versioned JSON export/restore.

`MoveBackupService` exports household answers, account/task fields, notes and progress to a user-selected file. Restore validates version/size/counts and creates new archived identities; existing moves are not overwritten and restored consent/Census lookups stay off. Backups are local user-managed files, not device synchronization. Shared content can contain personal notes; preserve the UI's disclosure before export/share.

No account/login, third-party analytics or cloud sync is integrated. Background images are bundled through `CityBackgroundMapper`; live Unsplash services/models were removed. Optional Census area snapshots require saved opt-in and send entered US ZIPs to Census; cached estimates remain public area context, not household facts. MapKit/geocoding use Apple services for postal/POI lookups. `PendingSignal` is a legacy on-device queue with no transmission path. No income-based membership ranking rule is enabled; the research feature contract is not a customer study consent or data upload.

The owner-confirmed product domain is `https://movingsoon.app` and preferred support email is `support@movingsoon.app`; GitHub Issues remains a support fallback. The website, `/support/` and `/privacy/` pages were verified live over HTTPS on October 24, 2026. Use these domain URLs in the app and store metadata, and recheck before submission. Keep `Services/SupportLinks.swift`, store metadata, README and privacy contact details aligned. Do not post externally as part of a local code/content review unless the user explicitly authorizes publication.

Use `Theme.swift` for shared colors and Dynamic Type-aware typography. Follow existing accessibility semantics and avoid capping accessibility text sizes or introducing fixed-point body text. Check public store/support/privacy links and truthful scope in `APP_STORE_LISTING.md`, `PRIVACY_POLICY.md` and `CATALOG_REVIEW.md` before a release.
