# Address-change experience: implementation status

Updated October 26, 2026. This describes the local working tree; it has not been published to the App Store. Current integrated validation is recorded below; earlier results are retained as history.

## October 26 expired-location-window invitation

- Added a one-shot local invitation after the 30-day nearby-reminder window expires when at least one eligible critical address-change task remains. The notification opens Reminders; extending access still needs the explicit **Enable another 30 days** action.
- Added a dashboard **Review & extend** card for expired windows, including older windows whose fixed notification time already passed. Reopening does not create repeated catch-up alerts. Explicitly stopped reminders do not invite renewal.
- Renewal requests reserve one scheduling slot, honor quiet hours, pin the planned deadline to its timezone and reject stale move/consent-cycle payloads. Successful grant/stop saves reconcile the queue; task and lifecycle changes remove obsolete notices. No model migration, background tracking or new network service was added.
- **iOS 26 suite passed: 306 test definitions / 338 executions, 53 suites, 0 failures/skips.** Results: `/tmp/movingsoon-renewal-2026-10-26-verified.xcresult`; log: `/tmp/movingsoon-renewal-2026-10-26-verified-tests.log`. The new 16-definition renewal suite covers expiry/DST/timezones, quiet hours, eligibility, cycle identity, cancellation and reserved capacity. The dashboard view expression was split into content/presentation/overlay boundaries to keep SwiftUI compilation tractable.
- On an isolated iPhone 16e / iOS 26 simulator with fictional expired consent, confirmed the critical-task explanation and explicit renewal button. Verified dashboard **Review & extend** opens Reminders and the window remains expired without an explicit renewal. Physical notification delivery and phone installation remain pending.
- Signed version 1.0 build 4 archived successfully; strict archive signature and release-resource checks passed. Artifacts and actual renewal-screen QA are in `build/release-2026-10-26`. App Store IPA export failed because Xcode reported no permission to create iOS App Store profiles and no distribution certificate; the earlier build 3 cloud-managed export does not validate current signing access. No upload/submission or phone installation occurred. The paired iPhone is disconnected.

## October 25 nearby-reminder correction

- Investigated the owner's report of 10 a.m. alerts without nearby alerts. The budget rejected every immediate location alert while any same-day Hero/Digest remained delivered. Nearby reminders now have their own persistent two-per-local-day allowance, independent of scheduled reminders and clearing Notification Center.
- Fixed sparse destination matching: provider searches that find no location no longer consume the twenty-region selection limit. Successful matches retain due-date priority, unchanged regions remain monitored, and replacements remove displaced zones before starting new ones.
- Reminder settings show the remaining nearby allowance and disclose quiet hours, completion/category suppression and destination/visit coverage. Precise Location authorization is observed and explained; monitoring errors are surfaced. No new continuous background tracking, coordinate history or provider sign-in was added.
- **iOS 26 suite passed: 290 test definitions / 302 executions, 52 suites, 0 failures/skips.** Result `/tmp/movingsoon-nearby-fix-2026-10-25.xcresult`; log `/tmp/movingsoon-nearby-fix-2026-10-25-tests.log`. Added regression coverage for nearby alerts after scheduled reminders, failed submissions, persisted budgets/local-midnight reset and sparse priority-ordered provider matches.
- Signed version 1.0 build 3 archived/exported successfully. The archive/IPA signatures, distribution entitlements, version/resource checks and IPA ZIP integrity passed. Artifacts: `build/release-2026-10-25`.
- Actual nearby event/delivery acceptance remains pending. The app still selects one matching provider branch near the destination (8 km search,200 m zone) and uses precise/recent iOS visits elsewhere. It does not promise an alert when passing any branch anywhere. Always+Precise Location, notification permission and active 30-day consent must be checked on the physical phone.

## October 24 domain and support contact

- Published the focused contact update at GitHub commit `6a37a74`: product domain `https://movingsoon.app` (website being prepared) and preferred email `support@movingsoon.app`. README, published privacy policy, store metadata, contributor guidance and the shared app support links are aligned. Working GitHub support/privacy URLs remain active until the replacement website pages are published and verified.
- Both the exact contact-only publication checkout's Release simulator build and the complete local working copy's Debug simulator build passed. Logs: `/tmp/movingsoon-contact-publish-build.log` and `/tmp/movingsoon-contact-local-build.log`. No Swift compiler diagnostics; the existing AppIntents metadata warning remains benign.
- Local `main` is aligned to the published contact commit. All 151 existing working paths were verified unchanged during Git alignment; earlier app-hardening edits remain local and uncommitted. The October 23 signed IPA and installed phone binary predate this contact update and require a new archive/install to show the new email.

## October 23 distribution preparation

- Signed Release archive and App Store IPA export succeeded with the existing Apple team. Both signatures, IPA ZIP integrity and required resources passed verification. Version 1.0 (1), bundle `app.movingsoon`; the exported IPA uses Cloud Managed Apple Distribution signing. Artifacts and logs are in the ignored `build/release-2026-10-23` directory.
- Saved a private pre-upgrade copy of the paired iPhone's MovingSoon database/preferences, then installed the signed Release candidate on iPhone 12 Pro / iOS 26.6.2. The initial launch was blocked by the lock screen; the later installation and launch retry succeeded. Interactive startup/data inspection, migration and background acceptance remain pending.
- The attempted App Store Connect upload failed at app-record lookup: `missingApp(bundleId: "app.movingsoon")`. An app record must be created before retrying; nothing has been uploaded or submitted.
- Published the owner-approved updated privacy policy and email support contact to GitHub at commit `eb64e2b`. Confirmed current content. Store metadata now points its Support URL directly to the published Contact section and avoids an unconfigured age-rating claim. App Store Connect price, account, age/privacy and release settings remain pending.
- See the [release handoff, artifact links and physical-phone checklist](RELEASE_HANDOFF_2026-10-23.md). Native Computer Use continued to report disabled after the readiness reply; the in-app browser was unavailable, so account UI settings could not be completed here.

## October 22 paid-release hardening

The current working tree adds:

- A shared successful-save boundary for task completion/reopen/removal, visible save-error recovery and retained form drafts. Reminder scheduling follows successful persistence. The main context uses explicit saves rather than autosave.
- Date-only calendar storage for moving day, shipment/renewal dates and custom deadlines, with legacy Date backfill. Travel between timezones does not change the selected calendar dates. Consent, snooze and event timestamps remain instants.
- Reversible task mute/snooze controls, notification settings without location opt-in, explicit location stop/renew choices and visible consent expiry. Scheduled alerts use a rolling 30-day window, seven-day critical check-ins and a finite capacity; settings disclose refresh/deferred alerts.
- Shared destination provider zones (at most 20) instead of one zone per account. Visit matching considers eligible unique providers beyond the destination cap. Explicit customer-entered provider names participate in matching; a nickname alone is not provider identity.
- Archive/cancel/reactivate workflows, readable checklist sharing, assignment labels and versioned JSON backup/restore. Restore adds archived copies without overwriting existing moves and leaves nearby consent/Census requests off; assignment labels do not synchronize a shared household.
- Editing of custom task title/category/date/note, retained completed tasks and household/service choices, and intake support for customers who already moved.
- An unreadable-store recovery screen with retry and user-chosen recovery export, preserving original files rather than deleting them. Restoring a backup is an explicit action.
- Action guidance for 44 important service identities, with eligibility, preparation, steps, planning timing and source review metadata. Official instructions and provider-neutral checklists are distinguished; DMV actions use official destination agencies. Issued US passports have no generic address-change requirement; benefit/voter-sensitive tasks require explicit review.
- Corrected postal-region ranges for all 50 states/DC and explicit territory/Pacific/military buckets, including Canadian Nunavut. Stale persisted destination buckets can be repaired without resetting progress. Postal context remains approximate and is not address verification or legal-jurisdiction determination.
- Extracted dashboard supporting views and task details, scalable typography and improved selection semantics. Background images are bundled; live Unsplash code was removed. Store copy now matches this scope and keeps the US $4.99 target separate from actual App Store Connect pricing.
- Current owner-confirmed support is [support@movingsoon.app](mailto:support@movingsoon.app), with [GitHub Issues](https://github.com/manidanesh/MovingSoon/issues) as fallback. The product domain is [movingsoon.app](https://movingsoon.app), whose website is being prepared. Public storefront/support/privacy links must still be checked in the submitted configuration.

### Current validation boundary

- CI selects the newest complete installed Xcode 26+ through job-local `DEVELOPER_DIR`, with a clear failure if the runner has none. Five Python selection regressions pass; local selection resolves `/Applications/Xcode.app/Contents/Developer`, verified as Xcode 26.0 (17A324). Host-wide Xcode selection is unchanged.
- The catalog/geography regression block occurs exactly once in the sole wired test file. It covers representative 50-state/DC cases, exceptional/military/Pacific/Canadian mappings, conservative persisted repair, eligibility, action guidance and official DMV routing.
- `python3 scripts/check_catalog_links.py` passes deterministic inventory validation for 70 maintained URLs, including all 50 state DMV destinations and DC. `python3 -m py_compile scripts/check_catalog_links.py` passes. Static checks do not establish live reachability.
- The October 22 full HTTP review checked all 70 maintained URLs: **59 reachable, 11 unverified, zero permanent HTTP failures**. The earlier Hawaii 404 was repaired and the replacement is reachable. SSA/passport and AK/MA/ME/NH DMV sites returned HTTP 403; Canadian government and Illinois pages timed out; Tennessee reset the connection. These remain inaccessible checks, not certified broken pages or passed links. The live command exits 1 while anything is unverified. Full evidence: [public-link report](research/catalog-link-review-2026-10-22.json).
- **Final iOS 26.0 run passed: 285 test definitions, 295 executions including parameters, zero failures/skips**, on iPhone 17. Result: `/tmp/movingsoon-fixes-final-285.xcresult`; log: `/tmp/movingsoon-fixes-final-285.log`. This includes previous-schema migration, timezone/date editing, provider identities, backup/restore, capacity and consent, and scalar/relationship/verification-event save failure recovery.
- **iOS 18.6 passed: 283 definitions, 293 executions, zero failures/skips**, on iPhone 16. Result: `/tmp/movingsoon-fixes-ios18-tests.xcresult`. This predates only the two additional relationship failure tests and final decorative accessibility layout corrections. No iOS 17 runtime is installed, so the declared minimum itself was not exercised.
- **Final unsigned Release iPhone build and bundle checks passed.** Log: `/tmp/movingsoon-release-final-285.log`. MovingSoon display name, iOS 17 minimum, privacy manifest, app assets, pilot resource and required Census key configuration were verified; key values were not logged. There are no Swift compiler diagnostics; the AppIntents metadata tool reports its benign missing-framework warning. This is not a signed archive/upload validation.
- **15 Python tests passed**; deterministic catalog inventory checks for 70 URLs and `git diff --check` passed. CI chooses an installed Xcode 26+ explicitly and validates the release bundle rather than depending on the runner's default Xcode.
- Refreshed six real simulator screen captures with fictional Debug-only data: [release screenshot candidates](AppStoreScreenshots/ReleaseCandidate-2026-10-22/README.md). The dashboard was also inspected at the largest accessibility text size; clipped decorative progress and settings glyphs were corrected. [QA screenshot](AppStoreScreenshots/QA-2026-10-22/dashboard-max-text.png). Native interactive computer access was unavailable, so this does not establish a complete VoiceOver, small-phone or permission walkthrough.
- A physical-phone permission/background-delivery walkthrough and App Store Connect account/pricing/privacy/age/support checks remain **manual release checks**. No code or simulator test establishes Apple approval, a correct account configuration, or actual background notification delivery.

## Earlier implemented behavior

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

Checklist generation, task tracking, household edits, service/category answers and the rule engine run locally. There is no app backend or LLM dependency. Uncached Census estimates, neighborhood geocoding and provider searches need internet access. Current background images are bundled and do not make network requests.

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

This paragraph records the earlier reminder delivery. The current unique-provider/visit, consent-renewal and capacity behavior is described in [the implementation and phone acceptance checks](LOCATION_REMINDERS_IMPLEMENTATION.md). This does not enable income-based membership predictions or automatic account updates.

## Historical build and validation

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

## Manual acceptance scenarios

Start with the new account flow: rename the first wine-club task, add a second provider, give them different shipment/renewal dates, and reopen the app. Complete, snooze, mute and remove accounts independently; confirm the other account remains active. Change moving day and confirm account dates stay fixed. Clear or edit a date and inspect replacement notifications. Reopen a completed account to resume reminders. Use an existing installation to inspect migration rather than relying on a fresh install.

1. Walk through the household interview, review/search flow, custom item creation and task completion on the simulator.
2. Upgrade an existing installation and confirm that completed tasks, custom notes and service choices survive migration and relaunch.
3. Exercise snooze-all, removal/undo, seven-day unsure handling, category reopening and duplicate-service cases.
4. Check Canadian and cross-border edits, including the earlier-location review prompt.
5. Check Census opt-in/off, uncached offline use, cached refresh failure, and provider-search failure independently.
6. Review the new recurring-account screen on small displays and large text settings, and conduct the separately consented study before enabling any income rule. Regression fixtures now reflect intentional country handling and EV ownership no longer automatically creating a Tesla account task.

See [the original functional review](PRODUCT_FUNCTIONAL_REVIEW.md), [README](README.md), and [privacy policy](PRIVACY_POLICY.md) for context.
