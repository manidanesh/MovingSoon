**MovingSoon — functionality review, 3 October 2026**

**Product purpose**

Help someone moving home remember the address changes they would otherwise miss, take the right action with each organization, and keep track until the work is finished. Location and household context should help the app ask better questions and identify changes in service arrangements.

The customer promise should be: **“Remember what needs updating. Know what to do next.”** The most useful intelligent output is a relevant reminder or question that leads to an address-change action. Area statistics can support that output; the main screen should prioritize unfinished work.

This review covers the current local working tree, including uncommitted Census, housing-context, household-service, and provider-search additions. Findings are from source inspection and a static catalog inventory. No simulator session, build, or test suite was run for this review. A code finding is distinguished below from a proposed product behavior.

**What exists today**

| Customer need | Current implementation | Practical limit |
|---|---|---|
| Describe the move | Move date, destination postal code, optional origin postal code and selected neighborhood coordinates | Editing postal codes does not have the same country support as onboarding. Old and new housing arrangements are not modeled separately. |
| Describe the household | Three interview screens cover children/count, pets/species, owning the new home, financial accounts, and optional service chips | Untouched yes/no answers default to false; an unanswered housing question becomes renting. Total household size and child age bands are absent. |
| Remember organizations | 341 catalog literals across six catalog files, plus the separate financial-institution directory | This count includes generic actions, grouped providers, and Canadian entries; it is not a count of distinct brands or useful recommendations for a given person. Catalog coverage exceeds proactive discovery coverage. |
| Track work | Task list, category views, search of existing tasks, completion/undo, snooze, removal, provider links, timeline and progress | Current completion, category urgency, and persistent dismissal behaviors have defects described below. There is no general free-text service/task creation flow in the inspected views. |
| Receive reminders | Scheduled task digests, hero reminders, inactivity and post-move check-ins, optional proximity reminders | These features exist in code; delivery and permission behavior were not verified in this review. Reminders primarily follow tasks already on the list. |
| Discover forgotten items | Destination archetype suggestions, plus family/pet review prompts | The regional candidate table covers 11 unique service flags in five archetype groups. It mainly covers ski, boating, golf and rural recreation/membership examples. It does not search the whole catalog for likely omissions. |
| Understand location context | Census ACS ZIP/ZCTA income, household composition and housing estimates; separate bundled state economics and archetype similarity | Census data reaches dashboard comparisons and a housing-budget task. It is not an input to the service candidate generator. Child count and pet species do not currently drive a detailed omission ranker. |
| Check service continuity | User-triggered MapKit search for up to six eligible existing provider tasks, selected alphabetically | A listing is not coverage or transfer eligibility. Search results are held in view state. There is no general service action model for old-home closure, transfer, new-home setup and final confirmation. |
| Work locally | SwiftData profile and checklist, local rules and cached Census estimates | First retrieval of an uncached Census area and live provider lookup require a network connection. No trained model or offline LLM is integrated. |

Inventory method: count `CatalogItem(id: ...)` literals in `ItemCatalog*.swift`. Counts were 44 base, 151 lifestyle, 39 travel, 21 insurance, 45 digital and 41 Canada, with no duplicate literal catalog IDs. This is a source inventory, not a completeness or recommendation-quality score.

Relevant code: [ChecklistGenerator](movingsoon.app/Services/ChecklistGenerator.swift), [LifestyleInterviewView](movingsoon.app/Views/LifestyleInterview/LifestyleInterviewView.swift), [MoveImpactEngine](movingsoon.app/Services/MoveImpactEngine.swift), [AreaMarketDataService](movingsoon.app/Services/AreaMarketDataService.swift), [MoveFitEngine](movingsoon.app/Services/MoveFitEngine.swift), [AddMoreServicesView](movingsoon.app/Views/Settings/AddMoreServicesView.swift), [SmartReminderService](movingsoon.app/Services/SmartReminderService.swift).

**Priority findings from the code**

1. **Category urgency can be wrong.** `Move.categoryProgress` assigns the minimum `tMinusDays` directly to `nextDueInDays`, and `CategoryProgress.urgencyTier` treats a negative value as overdue. These values are offsets from the move date, not days remaining from today. For a move 45 days away, a task planned 14 days before moving is due in 31 days, yet its category can be labeled overdue. The primary dashboard renders these category tiers. Other task views use actual calculated dates, so screens can disagree. Fix all urgency displays to use a shared calendar-based due-date calculation. Sources: [Move](movingsoon.app/Models/Move.swift), `categoryProgress` / `urgencyTier`; [ZenDashboardView](movingsoon.app/Views/Dashboard/ZenDashboardView.swift), category grid.

2. **Snoozed work can trigger a completed-move message.** `pendingTasks` excludes tasks whose snooze date is in the future. The “All Caught Up” state and whole-move celebration observe that filtered list becoming empty. The celebration checks that tasks exist, but does not require them all to be completed. Snoozing the last visible task can therefore announce that the entire move is handled. Completion must use all applicable tasks; a separate state can say “Nothing to do right now; three items are snoozed.” Source: [ZenDashboardView](movingsoon.app/Views/Dashboard/ZenDashboardView.swift), `pendingTasks` and `.onChange(of: pendingTasks.isEmpty)`.

3. **A removed task can return.** “Not applicable” deletes the task without storing a catalog-level dismissal. `AddMoreServicesView.applyAndDismiss` then generates every matching catalog item whose title is missing from the current task list. An always-included item or an item whose profile flag remains active can reappear when services are added. Persist the user's decision against a stable catalog ID. `ChecklistTask` currently stores a UUID and title but does not retain `CatalogItem.id`; add that linkage and handle existing records carefully. Sources: [ZenDashboardView](movingsoon.app/Views/Dashboard/ZenDashboardView.swift), `removeTaskNotApplicable`; [AddMoreServicesView](movingsoon.app/Views/Settings/AddMoreServicesView.swift), `applyAndDismiss`; [ChecklistTask](movingsoon.app/Models/ChecklistTask.swift).

4. **Some provider enrollment is still assumed.** PayPal, Venmo and Cash App are `alwaysInclude`; car/motorcycle ownership triggers AAA; an EV flag triggers a Tesla/MyEV task. Family-provider confirmation has improved, but the same standard has not been applied across the catalog. These are good candidates to ask about, with a task created after confirmation. Generic obligations also need relevant gates, such as whether a tenant actually manages a utility. Source: [ItemCatalog](movingsoon.app/Services/ItemCatalog.swift), `financial`, `transport`, `housing`.

5. **The app asks users to remember too much themselves.** The final interview screen asks “Want to add more?” and offers five expandable categories. Many other service families live only in Add Services. There is no durable category-review state, so the app cannot distinguish “reviewed and none apply” from “never looked here.” A useful omission engine needs that distinction. Existing task search and financial-institution search help with known names; there is no general catalog search/custom-service fallback in the inspected Add Services flow. Sources: [LifestyleInterviewView](movingsoon.app/Views/LifestyleInterview/LifestyleInterviewView.swift), `optionalExtrasScreen`; [AddMoreServicesView](movingsoon.app/Views/Settings/AddMoreServicesView.swift); [DashboardView](movingsoon.app/Views/Dashboard/DashboardView.swift).

6. **The main next action appears late in the dashboard.** The view renders area statistics, housing context, household prompts, category grids, regional suggestions and location prompts before “Do This Now.” The code establishes this order; actual fold positions still need a simulator review. Put the most useful next address change first, then a short forgotten-items check. Keep detailed area comparisons behind an expandable surface. Source: [ZenDashboardView](movingsoon.app/Views/Dashboard/ZenDashboardView.swift), main content stack.

7. **Important household distinctions are collapsed.** “Owning your new home?” automatically sets `livesInHouseOrTownhouse`; no response sets `isRenting`. A condo owner, someone living with relatives, or someone changing tenure can get an inaccurate profile. Capture old and new tenure separately when it changes actions, and use an explicit unknown/skipped state. Household information should remain editable while preserving completed work. Source: [LifestyleInterviewView](movingsoon.app/Views/LifestyleInterview/LifestyleInterviewView.swift), `coreFlags`; [EditMoveView](movingsoon.app/Views/Settings/EditMoveView.swift).

8. **Country support is inconsistent.** Intake supports Canadian postal codes, but Edit Move saves origin only when its length is five and disables saving unless destination length is five. Changing geography also updates move fields without reconciling country/province profile flags. The interview combines origin and destination country flags, while many US tasks exclude `isCanadian`, so cross-border moves need an explicit origin/destination action audit. Treat supported move types as a release decision and make validation consistent. Sources: [CoreIntakeView](movingsoon.app/Views/Onboarding/CoreIntakeView.swift), [EditMoveView](movingsoon.app/Views/Settings/EditMoveView.swift), [LifestyleInterviewView](movingsoon.app/Views/LifestyleInterview/LifestyleInterviewView.swift), `applyRegionalFlags`.

9. **The disclosure and refresh experience need alignment.** Documentation calls the Census snapshot optional, but the dashboard automatically calls `loadAreaMarketComparison` for the entered ZIPs. There is no separate snapshot opt-in in that path. Cached estimates have a retrieval date and a versioned key, but no age-based refresh policy; the visible retry applies when the destination comparison is unavailable. Choose whether lookup is automatic with clear disclosure or explicitly enabled, and give cached context a clear refresh state. Sources: [ZenDashboardView](movingsoon.app/Views/Dashboard/ZenDashboardView.swift), `.task(id:)`; [AreaMarketDataService](movingsoon.app/Services/AreaMarketDataService.swift); [PRIVACY_POLICY](PRIVACY_POLICY.md).

**How location and demographics should help**

| Signal | Useful role in an address-change app | Example output |
|---|---|---|
| Confirmed household facts | Identify overlooked service families | “Any school meal account, childcare provider or children's activity account to update?” |
| Confirmed service | Produce that service's move actions and related checks | “You use this gym. Update your account and check whether your membership transfers.” |
| Origin location | Help recall services the person already uses | Surface relevant regional utilities, banks, toll systems or memberships as questions. A service must remain eligible for review even if absent at the destination. |
| Destination and boundary changes | Decide which actions need a local or jurisdiction-specific check | Review service transfer, old-home closure, new-home setup, and the relevant agency's address-change requirements. Specific legal deadlines need maintained official sources. |
| Area income and household composition | Optionally adjust review ordering where a documented service/category relationship exists | An area-context reason can support an optional question. It must not become a claimed personal income or enrollment fact. |
| Area housing costs | Support relevant household transition questions | If the user is moving into an owned home, offer to review housing-related accounts, policies and service arrangements. Any cost comparison retains its source and period. |
| Prior responses | Prevent repetition and respect corrections | “Not relevant” stays dismissed; “not sure” can be revisited once at a useful time. |

Origin and destination have different jobs: origin helps recall existing relationships; destination helps decide what must change. This is more directly useful to address changes than suggesting destination recreation memberships alone.

Demographic context should be a modest ranking input after household relevance and explicit selections. A ZIP median cannot supply a family's personal income, and Census does not provide membership data for the catalog's brands. A supported service-specific prior would need a separately sourced dataset or validated, consented outcomes. Missing demographic data must not remove essential tasks or block the checklist. Confirmed services stay relevant regardless of the income of either area.

**Proposed customer journey**

1. **Describe the move.** Keep date and destination. Explain origin's practical benefit: “Your previous ZIP helps us find accounts and services you may need to update.” Allow skipping. Ask about old/new housing arrangement only when it changes responsibilities.
2. **Identify major needs.** Keep household and account selection. Add concise memory prompts for vehicles, work/benefits, healthcare, deliveries and home services. Ask extra details, such as optional child age bands, only where a rule uses them. Avoid a long demographic questionnaire.
3. **Review a first list.** Show confirmed tasks and a short explanation of why they apply. Offer a small, varied “Anything you may have missed?” set with “I use this,” “Doesn't apply,” and “Not sure.” An unreviewed category remains unreviewed.
4. **Take the next action.** The dashboard leads with the next useful task, its purpose, planned date, provider instructions/link, and completion control. Put up to three omission prompts below it. Keep snoozed work visible in a separate count.
5. **Check coverage over time.** Show “18 of 25 tasks completed” separately from “7 of 10 categories reviewed.” Invite a brief final review before moving and a post-move check. Completing the generated list should not claim that every possible account has been discovered.
6. **Correct and add freely.** Offer search across the catalog, add a custom service/task, edit household answers without resetting progress, and retain dismissals. Optional notes or confirmation references can help with submitted-but-unfinished updates.

Example: for a household with two children and a pet moving from a rental into an owned home, useful checks include children's accounts, healthcare and pharmacy records, pet records/microchip account, closing old utilities, arranging new utilities, housing-related accounts, and payroll/benefits. Named providers require confirmation. No assumption about the household's income is required to offer those questions.

**Recommended on-device design**

Keep the existing catalog and flags as the shared source of service definitions. Add a stable catalog reference to tasks and a separate record of candidate/category responses; avoid introducing another competing flag registry. Extend catalog literals with metadata as needed: service family, applicability rules, action type, origin/destination role, provider search terms, evidence/source date, and any supported area-context rule.

Generate candidates in stages: apply explicit household relevance, retain origin-side service candidates, attach destination action checks, optionally adjust ordering with supported area context, remove already confirmed/dismissed items, and return a small diverse set with plain-language reasons. Use explainable rank bands until calibrated probabilities are actually supported by data. The first implementation can run entirely as Swift rules; an LLM is not required for these decisions.

Separate `update address`, `stop old service`, `transfer`, `start new service`, and `check eligibility/coverage`. Today some of these concepts exist in task titles, but there is no catalog-wide structured workflow for them. A provider's absence from a map search must remain an unknown availability result.

Store public area snapshots separately from household facts. Live Census/MapKit access can remain optional network enrichment while the checklist and ranking fallbacks work locally. Fully offline first-use area comparisons would require bundled public data and a refresh/distribution plan.

**Implementation sequence**

| Order | Deliverable | Completion criterion |
|---|---|---|
| 1 | Repair tracking reliability | Consistent actual due dates; snoozing never completes the move; dismissed catalog items stay dismissed when tasks are added; known brand accounts require confirmation. |
| 2 | Make forgotten-item discovery usable | Category review state, catalog search, custom service/task creation, and a brief review of overlooked categories; next task leads the dashboard. |
| 3 | Build broad rule coverage | Shared metadata and explainable candidate generation spanning financial/insurance, housing/utilities, family/health/pets, delivery/subscriptions, and vehicle/work accounts. Pilot examples in each family before expanding. |
| 4 | Add move transition intelligence | Distinct old/new service actions, geographic rule sources, consistent postal-code editing, preserved completed tasks and user corrections. |
| 5 | Add evidence-backed demographic ranking | Document each demographic rule's evidence and limitations, handle missing/stale data, and demonstrate that it improves useful confirmed additions. Complete the data/disclosure and offline decisions. |

Detailed housing analysis, crime/neighborhood grades, new-lifestyle shopping, automated account changes, and an on-device chatbot can be reconsidered after this address-change loop is reliable. They do not need to block the core release.

**Acceptance scenarios for subsequent implementation**

- A move 45 days away with a task at t-minus-14 is not marked overdue.
- Snoozing every unfinished task leaves the move incomplete and shows when work returns.
- Removing Cash App as not applicable and then adding a new service does not recreate Cash App.
- A renter whose landlord manages utilities sees appropriate review questions, without assumed individual provider accounts.
- A condo owner is not silently classified as living in a house; old and new home responsibilities can differ.
- A user skipping optional categories can later review them, and unselected services are not recorded as explicit rejections.
- A confirmed origin-side service remains visible when it has no destination footprint; its closure or transfer still needs attention.
- A confirmed premium membership remains on the list after a move to a lower-income area.
- An uncached ZIP without internet still produces a usable checklist and explains unavailable area context.
- A destination edit preserves completed work and dismissals while updating relevant open actions and suggestions.
- Canadian postal codes remain valid through both creation and editing; cross-border tasks are independently reviewed if those moves are supported.
- The last confirmed task can be completed while unreviewed categories remain; the UI distinguishes those states.

The product measures to watch are useful forgotten items discovered, explicit irrelevant-suggestion rates, repeated-dismissal failures, completed address updates, category-review coverage, and onboarding abandonment. A larger catalog or more demographic cards alone does not establish customer value.

## Implementation update — 4 October 2026

The core changes from findings 1–9 are now implemented in the local working tree. See [implementation status](IMPLEMENTATION_STATUS.md) for the feature mapping, build results, remaining runtime validation and data-dependent scope. The findings above describe the pre-change audit and are retained as the rationale for this work.
