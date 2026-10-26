# Location and reminder fixes

Updated October 22, 2026. Applies to the current local working tree. Build/test and device acceptance evidence must be recorded separately.

## Delivered behavior

| Finding | Implementation |
|---|---|
| First permission grant could strand setup | A move records the customer's explicit request before asking iOS. A later While Using or Always grant records that request's date as the start of the 30-day window. While Using keeps an Always/settings prompt available. Existing system permission alone does not opt a new move in. |
| Any gym or bank could match another account | Catalog entries have explicit provider names and aliases; financial tasks use the selected institution. Place names must match those names. Unknown personal providers, multi-provider passes and airline accounts stay on the ordinary checklist. Government office and mechanic tasks intentionally support category-level matching. |
| Destination edits retained old locations | Region IDs include the move, task, destination and provider. Reconciliation removes obsolete system regions, including legacy IDs, and retains unchanged ones. An invalidated search cannot register an old zone after an edit or consent withdrawal. |
| A category match could notify the wrong task | Region and visit matching return the exact task. Delivery rechecks that task's status, snooze, mute, geographic-review flag, move and plan after asynchronous work. |
| Notification Snooze did not update the checklist | Snooze saves 24 hours on the actual task, rebuilds scheduled alerts and removes its location zones. A later generic reminder avoids claiming the user is still near the provider. |
| Mute left scheduled alerts behind | Mute persists on the task and reconciles pending and delivered reminders. Completed, deleted and awaiting-confirmation tasks are excluded too. A single scheduling worker ensures the latest edit wins. |
| Background startup depended on the dashboard | The location manager attaches to the active move during app initialization. Dashboard loading and a network image no longer delay the delegate setup. |

## Rules and limits

- Decisions, checklist state, consent and reminder schedules are local. New place discovery uses Apple Maps and needs a connection; previously registered unchanged regions can be retained.
- At most 20 unique destination provider/target zones are monitored, ordered by earliest eligible account deadline. Accounts sharing a provider share a zone instead of consuming separate slots. Zones have a 200-metre radius around a matched provider within 8 km of the destination. A missing result never creates a guessed zone.
- An unknown destination has no arbitrary US fallback. Saved geocoded coordinates or a recognized city centroid are required for destination zones.
- The visit layer checks all eligible unique provider targets near a sufficiently accurate recent arrival; the 20 monitored-region cap does not truncate visit matching. Departures and arrivals delayed more than 15 minutes are ignored. It can recognize a provider away from the destination; the task still must pass destination-country eligibility. It does not establish membership or coverage. Explicitly entered provider names participate in name matching; a friendly account nickname alone does not identify a provider.
- Location delivery keeps the existing gates: active 30-day consent, less than 80% of the move complete, 9 am–7 pm, an eligible task, and once per category per local day. Destination events also use the 8 km gate. Nearby alerts have their own persistent two-per-local-day budget, separate from morning and scheduled date reminders. A morning hero/digest does not disable nearby alerts, and clearing Notification Center does not reset their count. This is not a combined cap on pre-scheduled notifications. Reminder settings disclose the remaining nearby allowance and the time/completion/category gates.
- Always location permission is needed for background operation; notification permission is needed for banners. Status and Settings links are visible on the dashboard. Continuous location updates run only while the dashboard is foregrounded and consent is active.
- Consent never silently renews. Reminder settings show expiry and support immediate Stop nearby reminders and an explicit Enable another 30 days after stopping/expiry. Existing system authorization does not create or extend app consent. Expired consent blocks events; monitoring is removed when the app next runs or receives a location event. iOS controls background execution and delivery timing. Notification settings remain accessible without location opt-in.
- Scheduled requests are one-shot and use a rolling 30-day window, with at most 60 app requests and available system capacity accounted for. Critical-task reminders cover the next seven days. Due-date digests, account-date batches and a post-move check-in are queued only within the supported horizon. Settings show the next recommended refresh, deferred alert count and capacity notice. Open the app regularly to extend coverage; a far-future task remains on the checklist even when its notification is not yet queued. Snoozes returning outside 9 am–7 pm move to the next 9 am. Task changes and notification actions regenerate the schedule after successful saves.

## Expired-window renewal invitation (October 26)

When a saved 30-day nearby-reminder window expires and at least one eligible critical task remains, the app offers another 30 days. A one-shot local notification is queued in advance for strictly after expiry, or the next 9 a.m. if expiry falls outside 9 a.m.–7 p.m. The trigger pins its timezone to preserve the planned deadline during travel; reopening the app refreshes the schedule for the current timezone. The renewal request has a dedicated category and one reserved scheduling slot, including when quiet hours move it just beyond the ordinary 30-day date-reminder horizon. It does not consume the two-per-day nearby allowance.

The notification opens Reminders; it never changes consent. The existing **Enable another 30 days** button is the explicit renewal action. An expired-window dashboard card also offers **Review & extend**, including for windows already expired before this version was installed. Past fixed notification dates are not requeued on every app visit. **Not now** hides the card for this window while the dashboard instance remains open. The card and reminder controls refresh expiry state once per minute while visible.

Completing/muting the last eligible critical task, stopping nearby reminders, archiving/cancelling the move, switching active moves or starting a new consent window removes obsolete renewal notices during schedule reconciliation after a successful save. Snooze and location-review rules are honored. Delivered notices and notification taps validate the current move and consent cycle; a stale notice cannot reactivate a move or renew access. At 80% checklist completion a renewal offer can still appear for a remaining critical task, but the existing nearby-alert completion pause remains disclosed and unchanged.

Actual local-notification delivery still requires notification permission and is controlled by iOS/Focus. This invitation needs no expired location access and does not restart monitoring. No data-model fields, server requests or movement history were added.

## Shared persistence and lifecycle

Task actions now use `ChecklistActions` as the save/schedule boundary. Failed saves roll back and show a persistence error; they do not schedule a completion that was not saved. Unmute and clear-snooze controls are reversible; reopening a task clears stale mute/snooze. Calendar move/account/custom dates use date-only storage so travel does not shift the selected date, while snooze and consent remain instants.

Archived or cancelled moves retain their progress and stop active reminders. Switching active moves clears previous consent; reactivation and backup restore do not silently restore nearby access. JSON restore creates archived copies and leaves optional Census requests off. Background images are bundled; startup has no live Unsplash dependency. Dashboard orchestration, extracted supporting views and task details use the same reminder/guidance services.

## Regression coverage

The sole Swift Testing file includes `ReminderPolicyRegressionTests`, `LocationRegionRegressionTests` and `ReminderScheduleRegressionTests`. They cover explicit consent, aliases, mismatched providers, destination changes, the 20-zone cap, cold-start reconciliation, obsolete asynchronous searches, exact-task visit matching, persisted actions, one-shot schedules, fractional-second snooze deadlines, stale alerts and competing notification writes. Place search, region monitoring and the notification center use injected test doubles. The existing suppression-gate tests remain in place.

The final October 22 build/test run is pending the root integration check and will be recorded in [implementation status](IMPLEMENTATION_STATUS.md). Historical results in that file predate this delivery. Automated tests do not establish real background delivery while walking or driving past a provider; the physical-phone checks below remain a separate release requirement.

## Phone acceptance checks

1. Allow 30 Days, select While Using, and confirm the app offers the Always/settings recovery path. Enable Always and notifications to check background behavior.
2. With an eligible named account, confirm the dashboard reports matched zones. A Life Time task must not trigger at Planet Fitness, or a Chase task at another bank.
3. Enter a matched destination zone during allowed hours with the phone locked. Verify the banner identifies the correct task. iOS may defer delivery, and category/daily limits can suppress it.
4. Use Snooze or Mute directly on the notification. Reopen the task and confirm its saved state, then verify no further eligible alert appears while snoozed/muted.
5. Edit the destination, complete/remove the task or disable location permission. Old zones and reminders should no longer act on the previous plan.
6. Upgrade an existing installation and check saved tasks, answers, date-only backfill and repaired postal buckets. A successful installation alone does not prove every migration path.
7. Explicitly stop and renew nearby reminders. Archive/cancel/switch moves and restore a backup; confirm the old move cannot generate reminders and restore does not opt into location/Census.
8. Give two accounts the same provider, then add more than 20 unique providers. Confirm shared providers use one destination slot and an eligible visit beyond the first 20 can still match.
9. Inspect 30-day/seven-day schedule coverage and capacity notices with many account dates. Verify deferred tasks stay on the checklist and refresh extends the queue.
10. Change device timezone across midnight: the chosen move/account/custom dates stay the same, while notification wall-clock times remain local. Unmute and reopen tasks and verify schedules resume only after a successful save.

This document updates the original `.kiro` location-reminder specification: the current setup prompt is not limited to the final 14 days; provider identity is explicit; visit matching returns a task; and scheduling is serialized with finite triggers.
