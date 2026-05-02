# MovingSoon

A hyper-personalized iOS moving checklist app built with SwiftUI and SwiftData.

When you move, you have to update your address with dozens of services — banks, utilities, subscriptions, government agencies, gyms, streaming services, and more. MovingSoon generates a personalized, prioritized checklist of everything you need to update, based on your actual lifestyle.

---

## Features

### Onboarding
- Enter your move date and destination ZIP code — that's it
- ZIP is used for regional intelligence (filters brands by state) and ambient background photos

### Lifestyle Interview (7 screens)
- **Transport** — vehicles, ride share, toll roads, TSA PreCheck, airline loyalty
- **Household** — family, pets, roommates, WFH, 529 plans, FSA
- **Shopping** — Amazon, Target, Costco, regional grocers (Publix, H-E-B, Wegmans, etc.)
- **Streaming** — Netflix, Hulu, Disney+, Spotify, cable/internet providers
- **Fitness** — Planet Fitness, Equinox, Peloton, CrossFit, regional gyms
- **More** — insurance, crypto, veteran status, retirement, business, legal
- **Financial Accounts** — pick your banks, credit cards, investments, student loans, and mortgages

### Checklist Engine
- 150+ catalog items across 11 categories
- Flag-based filtering: `requires` (ALL), `requiresAny` (OR), `excludes`, `alwaysInclude`
- Per-institution tasks generated for every selected bank/card/investment account
- USPS Mail Forwarding is always the hero task — pinned first, always critical
- Tasks sorted by urgency (`tMinusDays` relative to move date)

### Zen Dashboard
- One "Current Objective" hero card at a time
- "Next Up" drawer showing the next 2 tasks
- Completion ring with percentage
- T-minus countdown to move day
- Ambient background photo from Unsplash (moody, dark, location-aware)
- Local fallback backgrounds for Denver, Laguna Beach, and generic cityscape
- Skip task (pushes it 7 days out), Mark Complete, or Auto-Update (agentic email)

### Smart Reminders
- Anti-nag protocol: only fires daily at 10am for the current hero task if it's Critical priority
- Geofencing: triggers a local notification when you're near a relevant POI (bank, DMV, gym, etc.)

### Regional Intelligence
- On-device ZIP → state/city bucket mapping (no network call)
- Filters regional brands by destination state:
  - Grocers: Publix (Southeast), H-E-B (TX), Wegmans (Northeast), Kroger, Safeway/Albertsons
  - Fitness: Equinox (major metros), VASA (Mountain West), EoS (Southwest), 24 Hour Fitness
  - ISPs: Verizon Fios (Northeast), Cox (Southwest/Southeast), Optimum (NY/NJ/CT)

### Privacy
- `PendingSignal` model: on-device queue for anonymous telemetry
- Laplace noise applied to embeddings before emission
- Timestamps floored to the hour — no minute/second precision
- Persona and region buckets only — no PII

---

## Architecture

```
movingsoon.app/
├── Models/
│   ├── Move.swift                  # Central SwiftData model
│   ├── ChecklistTask.swift         # Task with 3-state machine (toDo → pending → completed)
│   ├── LifestyleProfile.swift      # JSON-encoded Set<LifestyleFlag>
│   ├── FinancialInstitution.swift  # User's selected banks/cards
│   ├── VerificationEvent.swift     # Audit log for task completions
│   ├── PendingSignal.swift         # Privacy-preserving telemetry queue
│   ├── UnsplashPhoto.swift         # Unsplash API response model
│   └── Enums.swift                 # All domain enumerations
│
├── Services/
│   ├── ChecklistGenerator.swift    # Filters catalog by lifestyle flags → tasks
│   ├── ItemCatalog.swift           # 150+ catalog items (government, transport, housing, financial)
│   ├── ItemCatalog+Lifestyle.swift # Catalog extension (shopping, streaming, fitness, healthcare, etc.)
│   ├── CatalogItem.swift           # CatalogItem struct with flag logic
│   ├── KnownInstitutions.swift     # Curated US financial institutions with brand colors
│   ├── TaskListProvider.swift      # Legacy persona-based task lists (Phase 1)
│   ├── PersonaEngine.swift         # Maps onboarding answers → PersonaKey
│   ├── ZipBucketService.swift      # On-device ZIP → state/city bucket mapping
│   ├── RegionalIntelligenceService.swift  # Filters regional brands by state
│   ├── CityBackgroundMapper.swift  # Maps ZIP/city to bundled background assets
│   ├── UnsplashService.swift       # Fetches ambient background photos
│   ├── SmartReminderService.swift  # Anti-nag push notification protocol
│   └── LocationManager.swift      # Geofencing for POI-based task reminders
│
├── Views/
│   ├── Onboarding/
│   │   └── CoreIntakeView.swift    # Move date + destination ZIP
│   ├── LifestyleInterview/
│   │   ├── LifestyleInterviewView.swift  # 7-screen interview container + ViewModel
│   │   ├── BubblePickerView.swift        # Emoji chip grid + InterviewScreenView template
│   │   └── FinancialScreenView.swift     # Bank/card/investment picker (screen 7)
│   ├── Dashboard/
│   │   ├── ZenDashboardView.swift        # Primary dashboard (hero card + next up drawer)
│   │   ├── DashboardView.swift           # Secondary dashboard (priority bucket list)
│   │   ├── HeroUSPSView.swift            # Pinned USPS hero card
│   │   └── TaskRowView.swift             # Individual task row with momentum ring
│   ├── AccountSetup/
│   │   └── AccountSetupView.swift        # Standalone financial account picker
│   ├── Components/
│   │   ├── MomentumRingView.swift        # 3-state animated progress ring
│   │   ├── InstitutionBadgeView.swift    # Colored circle with institution initials
│   │   ├── SelectionCard.swift           # Reusable pill/card selection component
│   │   └── OnboardingStepTemplate.swift  # Shared onboarding step layout
│   └── MailComposeView.swift             # MFMailComposeViewController wrapper
│
├── Theme.swift                     # Design system (colors, typography)
├── ContentView.swift               # Root router: onboarding → interview → dashboard
└── movingsoon_appApp.swift         # App entry point + SwiftData ModelContainer
```

---

## Tech Stack

- **SwiftUI** — UI framework
- **SwiftData** — Persistence (iOS 17+)
- **Combine / @Observable** — Reactive state
- **CoreLocation** — Geofencing for POI-based reminders
- **UserNotifications** — Push and local notifications
- **MessageUI** — In-app mail compose for agentic address updates
- **Unsplash API** — Ambient background photography

---

## Requirements

- iOS 17.0+
- Xcode 15+
- Unsplash API key (set in `UnsplashService.swift`)

---

## Known Issues / In Progress

- `Move.moveTypeRaw` is referenced in `LifestyleInterviewView` but not defined on the `Move` model — needs to be added or the reference removed
- `LifestyleViewModel` initializes with `move.originZip` for regional filtering, but `CoreIntakeView` never sets `originZip` — regional chips always fall back to the default
- `AccountSetupView` is not wired into the current app flow (superseded by `FinancialScreenView` inside the lifestyle interview)
- `DashboardView` (bucket list) exists but is not the active dashboard — `ZenDashboardView` is rendered instead
- `PendingSignal` model is fully defined but no service emits signals yet
- `LocationManager` geofencing uses a hardcoded Denver coordinate as a mock — real `MKLocalSearch` integration is pending

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

`Postal` · `Government` · `Financial` · `Utilities` · `Subscriptions` · `Healthcare` · `Education` · `Insurance` · `Legal` · `Employer` · `Other`

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
