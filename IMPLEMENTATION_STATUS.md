# Address-change experience: implementation status

Updated October 8, 2026. This describes the local working tree; it has not been published to the App Store.

## Implemented

| Review finding | Delivered behavior |
|---|---|
| Incorrect category urgency | Calendar-based days until the actual task due date; move countdown also uses calendar days. |
| False completion after snoozing | Completion requires every existing task to be completed. Snoozed and awaiting-confirmation work remains unfinished. The empty next-action state shows remaining work and the next snooze return. |
| Dismissed services returning | Stable catalog IDs, canonical aliases and persistent confirmed / not applicable / not sure answers. Adding services or editing the profile respects those answers. Legacy tasks receive IDs only through conservative matches. |
| Assumed provider enrollment | Payment apps, AAA, Tesla, rideshare brands, Canadian providers and other identified broad matches require confirmation. Previously confirmed family/pet-service flags remain supported. |
| Missing review and search tools | Ten review families, persistent category-review state, catalog search, bank/card selection, and custom tasks with dates and optional notes. Category review and task completion are shown separately. |
| Next action buried in dashboard | Next action first, up to three varied forgotten-item questions, upcoming tasks, then supporting sections. Detailed Census comparisons are expandable. |
| Collapsed household distinctions | Yes / no / skip answers; previous/new housing; independent home type; optional household size, children, pet types and utility responsibility. Editing retains completed tasks and service choices. |
| Inconsistent postal support | Shared US/Canadian normalization and format validation in creation and editing. Origin/destination geographic flags are evaluated independently. Unconfirmed tasks from a superseded area are flagged for review, not silently removed. |
| Census disclosure and refresh | Explicit saved opt-in, ZIP-sharing explanation, manual refresh, 30-day refresh eligibility, offline cached fallback, retrieval dates and stale-data copy. Parser handles nulls/sentinels and avoids partial family-count percentages. |

Additional safeguards:

- The full catalog has 402 definitions after the October 7 expansion, including 52 new service checks/providers. Definitions include aliases and grouped services; this is not a count of unique brands.
- `ServiceDiscoveryEngine` orders questions across all ten families using household answers, origin/destination context, changed housing arrangements and prior responses. Household size and pet types support specific recall prompts.
- A significant area housing-cost difference can modestly prioritize housing questions. The comparison uses available Census margins of error.
- `Not sure` defers a suggestion for seven days and does not create a task. Reviewed categories stop automatic prompts until reopened; their individual service answers remain intact.
- Service actions distinguish address updates, transfer/cancellation checks, old-home closeout, new-home setup and requirement review.
- Provider search remains customer-triggered, covers all eligible selected catalog services, and distinguishes failed searches from zero listings. Results still require provider confirmation.
- Task removals in the dashboard, upcoming list and full list save the service dismissal. Dashboard removal undo restores the previous answer.
- Reminder schedules are refreshed after relevant task and move edits. Explicit dates on user-created tasks are retained when move day changes.
- Catalog services support multiple explicitly added accounts with independent names, nicknames, websites, task progress, snooze and mute. Removing one account preserves the remaining accounts and their service confirmation.
- Optional next shipment and renewal dates bring address-review deadlines forward. Lead times, date summaries, daily notification batches, dashboard urgency, calendar grouping and location-monitoring priority use the account dates. These dates remain fixed when moving day changes; they are entered manually and do not roll forward automatically.
- New model fields are optional. An unreadable database now produces a recovery screen while retaining existing files; the previous destructive reset fallback was removed.

## Offline and data scope

Checklist generation, task tracking, household edits, service/category answers and the rule engine run locally. There is no app backend or LLM dependency. Uncached Census estimates, neighborhood geocoding, live background photos and provider searches need internet access.

Area income, household composition and housing medians remain area context. There is no validated service-enrollment dataset in this project, so the app does not predict a person's income or brand memberships from a ZIP. Income-based enrollment probabilities, crime/neighborhood grades, exact home valuations and automated provider account updates remain outside this delivery. The catalog's existing timing suggestions are not a maintained jurisdiction-specific legal deadline system.

When locations change, completed and confirmed services are retained. Earlier automatic tasks outside the new geographic context require customer review. Cross-border task handling is improved, but a jurisdiction-by-jurisdiction content audit is still needed before promising comprehensive cross-border coverage.

## Income and service-use pilot

- Added 25 optional recurring-account questions spanning children, home services, pets, shopping/deliveries, memberships and travel. Service-use answers are stored separately from task applicability; existing task actions never become implicit membership labels.
- Explicit positive answers prioritize an unhandled account; negative answers hide it; unsure defers it seven days. Adding a task remains a separate customer action, and completed/confirmed tasks are preserved.
- Added seven Census B19001 income bands and count margins of error to optional origin/destination snapshots. The request stays within 50 variables. New cache entries use v2, with legacy offline fallback and backward-compatible decoding.
- Added source metadata, a versioned feature contract and a bounded ±4-point income-ranking hook. Rules require approved service-use evidence, adequate independent holdout results, subgroup checks, source rights and release review. **The shipped rule list is empty; income does not affect service ranking.**
- Added an offline paired evaluation CLI, separate-consent and label checks, household overlap detection, bootstrap intervals, subgroup metrics and report hashes. It never reads app storage or enables rules. Synthetic data always fails readiness.
- BLS expenditure mapping remains provisional: the workbook download returned HTTP 403. No numeric BLS weights were extracted. Licensed service-use data and an independent real-world validation study are still outstanding.

See the [pilot source assessment and study contract](research/income-pilot/README.md).

## Location and reminder gap fixes

Implemented explicit permission-request persistence and Always/settings recovery, named-provider matching, replacement of stale destination zones, exact-task eligibility checks, task-backed notification Snooze/Mute, serialized scheduling, finite calendar triggers, and location initialization before the dashboard loads. Catalog metadata identifies 39 supported provider entries; unknown personal providers retain ordinary checklist reminders.

See [the implementation and phone acceptance checks](LOCATION_REMINDERS_IMPLEMENTATION.md) for behavior, limits and regression coverage. This does not enable income-based membership predictions or automatic account updates.

## Build and validation

### October 8 account and date delivery

- Added **Accounts & dates** to service review and recurring-account review, plus an editor in task details. Normal catalog Add remains idempotent; **Add another account** creates an independent task UUID.
- Preserved catalog identity before account renaming, retained customer-entered links during catalog backfill, and included the original service name in task search. Save failures restore the form's previous values without rolling back unrelated edits.
- Added optional SwiftData account/date fields and an absolute custom due date. Existing-store migration has not been exercised for these changes.
- The final Debug simulator compilation passed with exit code 0. The build log reports no compiler errors or warnings: `/tmp/movingsoon-accounts-build-final.log`. `git diff --check` passes.
- No tests were added or run for this delivery. Interactive account/reminder behavior, saved-data migration and actual notification delivery remain unverified. This update has not been installed on the phone. Earlier test results below predate this implementation.

### October 7 catalog expansion

- Added 52 definitions, 19 browsing topics, search vocabulary, move-specific guidance and a broader grouped recurring-account review. Restored the hidden subscription choices to the existing optional onboarding screen.
- Retained old titles as lookup aliases; removed known misleading links from grouped services; preserved existing tasks and the latest saved answers when aligning children's-box aliases.
- Static inventory found 402 distinct literal IDs and no duplicate literal IDs; `git diff --check` passes.
- The final Debug simulator build passed with exit code 0 after the onboarding and alias-preservation changes. No compiler errors or warnings were reported; log: `/tmp/movingsoon-catalog-build-final.log`.
- Automated tests and an interactive walkthrough were not run for this catalog update. It has not been installed on the phone. The test and device results below are from the earlier reminder delivery.
- See [CATALOG_REVIEW.md](CATALOG_REVIEW.md) for scope, sources and remaining work.

### Earlier validation

- October 5: Debug simulator build/test, Release simulator build, and the signed Debug iPhone build completed with exit code 0 using scheme `movingsoon.app`. Final build logs contain no compiler errors or warnings.
- The update was installed on the paired iPhone 12 Pro (`app.movingsoon`). Launch verification is pending because iOS reported the device was locked. Installation does not establish background-notification delivery or that saved data has opened successfully.
- The October 5 location/reminder run reports **240 tests passed, zero failures/skips** (250 executions including parameterized cases) on iPhone 17 / iOS 26. This adds 34 tests covering permission recovery, named providers, stale zones, saved actions, finite schedules and asynchronous races. Earlier Census, evidence, explicit-answer and persistence tests also passed. Result: `/tmp/movingsoon-location-regression-3.xcresult`.
- **10 Python evaluator tests passed**. A full CLI run against 210 synthetic records correctly returned `passesNumericalGate: false` and `releaseApproved: false`. These are software checks, not evidence that income predicts memberships.
- A live Census request for public example ZIP 80202 returned HTTP 200, all 50 requested variables plus the geography column, and complete income bins whose counts matched the total. The key was not logged. This was a direct API check, not an app UI walkthrough.
- `git diff --check` passes.
- Before the October 7 expansion, static inventory found 350 distinct literal IDs across 350 definitions.
- The Census key resource remains ignored and untracked; the key was not copied into source or documentation.
- A simulator interaction walkthrough and saved-data migration inspection were not run. The in-memory persistence test does not establish existing-store migration compatibility. Screen layout, the full permission flow and real background notification delivery still need manual validation.

## Next validation pass

Start with the new account flow: rename the first wine-club task, add a second provider, give them different shipment/renewal dates, and reopen the app. Complete, snooze, mute and remove accounts independently; confirm the other account remains active. Change moving day and confirm account dates stay fixed. Clear or edit a date and inspect replacement notifications. Reopen a completed account to resume reminders. Use an existing installation to inspect migration rather than relying on a fresh install.

1. Walk through the household interview, review/search flow, custom item creation and task completion on the simulator.
2. Upgrade an existing installation and confirm that completed tasks, custom notes and service choices survive migration and relaunch.
3. Exercise snooze-all, removal/undo, seven-day unsure handling, category reopening and duplicate-service cases.
4. Check Canadian and cross-border edits, including the earlier-location review prompt.
5. Check Census opt-in/off, uncached offline use, cached refresh failure, and provider-search failure independently.
6. Review the new recurring-account screen on small displays and large text settings, and conduct the separately consented study before enabling any income rule. Regression fixtures now reflect intentional country handling and EV ownership no longer automatically creating a Tesla account task.

See [the original functional review](PRODUCT_FUNCTIONAL_REVIEW.md), [README](README.md), and [privacy policy](PRIVACY_POLICY.md) for context.
