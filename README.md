# MovingSoon

An iOS address-change checklist built with SwiftUI and SwiftData. The intended US price is a one-time $4.99 paid download, configured separately in App Store Connect.

MovingSoon helps customers remember organizations, prepare an address update and track their own progress. It does not submit provider changes, discover every account or establish legal eligibility or service coverage.

## Customer workflow

- Enter a move date, destination US ZIP or Canadian postal code, and optional origin.
- Answer optional household questions, select financial institutions and choose services.
- Work through the next task or full checklist; review overlooked categories separately from task completion.
- Search the service catalog, add your own dated item with notes, or maintain separate provider accounts and shipment/renewal dates.
- Edit move/household choices while preserving completed work and remembered dismissals.
- Archive or cancel a move, start another, and reactivate saved work. Share a readable checklist or export/restore a versioned JSON backup; restore adds archived copies rather than overwriting existing moves. Local assignment labels help divide work; they do not synchronize household devices.
- Optionally enable local notifications, explicit 30-day nearby reminders, US Census ZIP-area estimates or user-triggered provider listings.

The catalog includes grouped services, aliases and generic checks as well as brands. A large definition count is not a count of distinct providers or a completeness guarantee. Nearby map results are leads to confirm directly, not proof that a utility, delivery service or membership works at an address.

## Action guidance and geography

`Services/CatalogGuidance.swift` supplies eligibility, preparation, steps, planning timing, source link and review date. The October 20 audit covers 44 important identities, using official instructions where verified and clearly labelled provider-neutral checklists elsewhere. Government eligibility is not inferred from country or age. US passports already delivered do not need a general address update; the pending-application case is explicitly reviewed. SSA updates are relevant to applicable benefits/Medicare, and Medicare is distinguished from Medicaid.

DMV actions resolve to an official destination agency or USAGov's directory, replacing commercial dmv.org links. Planning dates never replace actual agency/provider deadlines.

The offline postal-region table covers all 50 states and DC, distinct US territories and Pacific postal destinations, military postal regions and Canadian provinces/territories, including Nunavut. It fixes the former Delaware, Maryland/Virginia, Georgia, Arkansas, Texas, Wyoming, Alaska and Hawaii misclassifications. ZIPs can span boundaries and prefix ranges do not verify an address; the actual address's jurisdiction must be checked. Persisted region buckets can be repaired without resetting progress using `ZipBucketService.repairRegionBuckets(for:)`.

## Architecture

SwiftUI presents intake, the household/service interview and the dashboard. SwiftData stores moves, profiles, accounts, task status and local responses. Catalog definitions and explicit selections feed a rule-based checklist generator. Stable canonical service IDs preserve user decisions while separate task UUIDs represent separate accounts.

`CatalogGuidance` is the shared action-content source. `ReminderPolicy`, `ReminderScheduleBuilder`, `SmartReminderService` and `GeofenceCoordinator` separate eligibility, finite schedules, notification reconciliation and monitored locations. Background behavior still depends on iOS permissions, OS scheduling and device acceptance tests.

Optional Census requests send only entered US ZIPs for public ZCTA estimates and cache the results. These estimates are not personal income or evidence that someone holds a membership. No income-based membership ranking rule is enabled. Optional MapKit/geocoding requests use the relevant postal area/search; checklist and profile data stay local. Background images are bundled; there is no Unsplash network dependency in the current flow. See [privacy policy](PRIVACY_POLICY.md).

## Support

Website: [movingsoon.app](https://movingsoon.app). [Support](https://movingsoon.app/support/) and [privacy policy](https://movingsoon.app/privacy/) are live on the product domain.

Email [support@movingsoon.app](mailto:support@movingsoon.app) or use [GitHub Issues](https://github.com/manidanesh/MovingSoon/issues). The [privacy policy](PRIVACY_POLICY.md) describes local storage, optional outside requests and user-chosen sharing/backups.

## Build and test

Requires iOS 17+ and Xcode 26 or later. CI chooses the newest complete installed Xcode 26+ with `scripts/select_xcode.py` and sets `DEVELOPER_DIR` for that job; it does not change the host-wide Xcode selection. Open `movingsoon.app.xcodeproj` or run:

```sh
xcodebuild build -project movingsoon.app.xcodeproj -scheme movingsoon.app -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project movingsoon.app.xcodeproj -scheme movingsoon.app -destination 'platform=iOS Simulator,name=iPhone 16'
```

Run `python3 scripts/check_catalog_links.py` for deterministic catalog URL maintenance; `--live-verify` explicitly enables network requests and reports inaccessible links as unverified. The October 22 public-link report is in [research](research/catalog-link-review-2026-10-22.json).

The single wired Swift Testing target is `movingsoon.appTests`. Build/device details and prior validation limits are recorded in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md). See [catalog review](CATALOG_REVIEW.md) for source provenance and limits and [App Store copy](APP_STORE_LISTING.md) for the honest customer-facing scope.
