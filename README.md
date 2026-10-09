# MovingSoon

An iOS address-change checklist built with SwiftUI and SwiftData.

When you move, you have to update your address with dozens of services — banks, utilities, subscriptions, government agencies, gyms, streaming services, and more. MovingSoon generates a personalized, prioritized checklist of address updates to review, based on your actual lifestyle.

---

## Features

### Move and household setup

- Move date, destination postal code, and optional origin; supports US ZIP and Canadian postal-code formats.
- Three interview screens: household, financial accounts, and optional services.
- Explicit yes / no / skip answers; previous and new housing arrangements are separate.
- Optional household size, child count, pet types, home type, and utility responsibility.
- Household details remain editable without resetting completed tasks.

### Address-change checklist

- 402 catalog definitions spanning identity, money, home, insurance, children, health/pets, shopping, memberships, travel, and work. This includes aliases and grouped services, not 402 distinct providers.
- Tasks retain stable catalog IDs. Equivalent catalog entries share a canonical identity to avoid accidental duplicate additions; customers can explicitly add separate accounts within a service.
- Named accounts such as payment apps, AAA, Tesla and Canadian providers require confirmation where a broad household or regional flag previously assumed enrollment.
- Search the catalog, add banks/cards, or create a custom task with a due date and optional note.
- Actual calendar due dates determine urgency. Snoozed and awaiting-confirmation tasks remain unfinished.
- Persistent service answers: confirmed, not applicable, or not sure. Not sure pauses suggestions for seven days; it does not add the service.
- Separate category-review progress and task-completion progress. Reopen a reviewed category to see its suggestions again.
- Optional **Review recurring accounts** browses recurring catalog topics and retains the original 25 pilot questions. It is grouped and searchable; service-use answers stay separate from task decisions, and adding a reminder is a separate action.
- Nineteen focused topics make groceries, wine, clothing rentals, refills, personal care, storage and other recurring services easier to find. Search understands topic vocabulary and compact brand names such as “stitchfix.”
- Move guidance covers upcoming shipments, returns, local transfers, delivery instructions and membership credits. See the [catalog review and expansion](CATALOG_REVIEW.md).
- **Accounts & dates** tracks separate providers or household accounts, each with a name, optional nickname/website, progress, snooze and mute. Removing one leaves the others intact.
- Optional next shipment and renewal dates bring address review forward, with a selectable 0–30-day lead time and local reminders. Dates stay fixed when moving day changes. Dates are entered manually; there is no live account access or automatic renewal tracking.

### Dashboard and discovery

- Next action first, followed by up to three varied forgotten-item questions and the upcoming task list.
- `ServiceDiscoveryEngine` ranks review questions locally using confirmed household answers, previous/destination regional context, housing transitions, and prior answers.
- Previous-home closure, service transfer, new-home setup and requirement checks have distinct action labels.
- Canadian and US geographic rules are evaluated independently for each end of a move; existing completed tasks and explicit choices are retained when locations change.
- Reminder scheduling is refreshed after checklist and move edits. Reminders still require the appropriate iOS permissions.

### Optional connected features

- **Census area estimates:** explicit opt-in under **Explore your new area**. ZIP/ZCTA income, household composition, rent, owner costs and home values describe the area, not the user's personal finances.
- Cached Census results work offline; snapshots older than 30 days are refreshed when connected. A failed refresh retains the previous snapshot and its retrieval date.
- Housing comparisons use margins of error before indicating a clear difference. This context can modestly prioritize housing review questions.
- The area snapshot includes seven Census household-income bands when complete data is available. Income-based service ranking remains disabled until independently validated, appropriately licensed service-use evidence passes the release gates.
- **Provider lookup:** the customer taps Check to search Apple Maps near the destination. Results do not establish service coverage or membership-transfer eligibility.
- **Background images and neighborhood lookup:** use Unsplash and Apple's services, with bundled background and postal-bucket fallbacks.
- Core checklist, review responses and suggestion rules work without an app backend or LLM. Uncached Census and live provider data require internet access.

### Nearby reminders

- Optional 30-day access with a recovery prompt when location permission is only While Using. The dashboard shows permission and matching status.
- Named providers and selected banks are matched to their own places. Unknown personal providers retain regular checklist reminders.
- Destination or task changes replace stale monitored locations. Notification Snooze and Mute save to the task and refresh all its reminders.
- Rules run on-device; Apple Maps discovery needs internet. Background reminders need Always location permission and notifications enabled. iOS controls delivery timing.
- See [location reminder behavior and phone checks](LOCATION_REMINDERS_IMPLEMENTATION.md).

## Architecture

| Component | Responsibility |
|---|---|
| `Models/Move.swift` | Move, checklist relationships, service decisions, reviewed categories and Census opt-in |
| `Models/ChecklistTask.swift` | Status, due date, stable catalog identity, action type and note |
| `Models/LifestyleProfile.swift` | Household answers and explicitly selected service flags |
| `Services/ItemCatalog*.swift` | Catalog definitions, canonical identities, review family and contextual metadata |
| `Services/ChecklistGenerator.swift` | Generate relevant tasks and evaluate each end of the move |
| `Services/MoveChecklistService.swift` | Confirm/add services, preserve dismissals, link legacy tasks and add custom items |
| `Services/ServiceDiscoveryEngine.swift` | Explainable local ordering of forgotten-item questions |
| `Services/PostalCodeService.swift` | Shared normalization, validation and country/province context |
| `Services/AreaMarketDataService.swift` | Optional Census fetch, parsing, local cache and offline fallback |
| `Services/MoveFitEngine.swift` | Uncertainty-aware area housing comparisons |
| `Services/ServiceEvidenceCatalog.swift` / `Resources/IncomePilot.json` | 25-service pilot, source mappings and validation requirements |
| `Services/IncomeSuggestionEngine.swift` | Bounded local income adjustment; no income rules enabled in the current bundle |
| `scripts/evaluate_income_pilot.py` | Offline paired holdout evaluation, with explicit research consent and subgroup checks |
| `Views/Settings/AddMoreServicesView.swift` | Catalog search, category reviews, custom items and provider checks |
| `Views/Settings/HouseholdDetailsView.swift` | Shared household questions and edits that retain progress |
| `Views/Dashboard/ZenDashboardView.swift` | Next action, discovery, progress and optional area details |
| `Services/SmartReminderService.swift` / `LocationManager.swift` | Scheduled and permission-based proximity reminders |

SwiftData stores household facts and tasks locally. New persistent fields are optional for additive schema compatibility. If the database cannot open, the app keeps its files and presents a recovery message; it does not silently replace the customer's checklist.

See [implementation status](IMPLEMENTATION_STATUS.md) for the current delivery and remaining validation, and [functional review](PRODUCT_FUNCTIONAL_REVIEW.md) for the original findings.

---

## Tech Stack

- **SwiftUI** — UI framework
- **SwiftData** — Persistence (iOS 17+)
- **Combine / @Observable** — Reactive state
- **CoreLocation** — Geofencing for POI-based reminders
- **UserNotifications** — Local notifications
- **MessageUI** — User-reviewed address-change email drafts
- **Unsplash API** — Ambient background photography

---

## Requirements

- iOS 17.0+
- Xcode 16+ for the filesystem-synchronized project groups
- Optional Unsplash configuration for live background photos
- Optional Census key in the ignored `movingsoon.app/CensusAPIKey.plist` resource (`CensusAPIKey` string) or `CENSUS_API_KEY` environment variable. Do not commit keys. A key bundled in an app is extractable; it is not a server-side secret.

---

## Known Issues / In Progress

- The current review engine saves explicit service responses locally; it does not transmit telemetry. Older `PendingSignal` records remain local.
- Personal income, exact property prices, crime grades and service-enrollment probabilities are not inferred. They require additional appropriate data and validation.
- Simulator interaction and existing-install migration still need validation. The earlier automated suite and Census request passed; the October 7 catalog expansion has a successful simulator build and has not had a new test run. See `IMPLEMENTATION_STATUS.md`.
- See the [income pilot and study contract](research/income-pilot/README.md) for data-source limits, evaluation commands and what is needed before enabling income-based ranking.

---

## Personas

| Persona | Tagline |
|---|---|
| College Grad | Starting fresh 🎓 |
| Young Couple | Moving together 💛 |
| Family with Kids | You've got this 🏡 |
| Divorce / Separation | One step at a time. |
| Active Professional | Let's get it done ⚡ |
| Retiree / Senior | We'll guide you through it 🌿 |

---

## Task Categories

`Postal` · `Government` · `Financial` · `Utilities` · `Subscriptions` · `Healthcare` · `Education` · `Insurance` · `Legal` · `Employer` · `Travel` · `Estate` · `Digital` · `Other`

## Task Priorities

| Priority | Label | Timing |
|---|---|---|
| Critical | Do Now | 14–30 days before move |
| High | High Priority | 7–14 days before move |
| Medium | First Two Weeks | Around move day |
| Low | When You're Settled | 7–21 days after move |

---

## License

Private — all rights reserved.
