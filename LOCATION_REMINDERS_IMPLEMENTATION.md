# Location and reminder fixes

Updated October 5, 2026. Applies to the local working tree.

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
- At most 20 destination zones are considered, ordered by earliest task deadline. Zones have a 200-metre radius around a matched provider within 8 km of the destination. Multiple tasks may share a provider search. A missing result never creates a guessed zone.
- An unknown destination has no arbitrary US fallback. Saved geocoded coordinates or a recognized city centroid are required for destination zones.
- The visit layer checks up to 20 eligible task targets near a sufficiently accurate recent arrival. Departures and arrivals delayed more than 15 minutes are ignored. It can recognize a provider away from the destination; the task still must pass destination-country eligibility. It does not establish membership or coverage.
- Location delivery keeps the existing gates: active 30-day consent, less than 80% of the move complete, 9 am–7 pm, an eligible task, and once per category per local day. Destination events also use the 8 km gate. Immediate location alerts have a two-per-day budget and defer when a hero/digest was already delivered today. This is not a universal cap on pre-scheduled notifications.
- Always location permission is needed for background operation; notification permission is needed for banners. Status and Settings links are visible on the dashboard. Continuous location updates run only while the dashboard is foregrounded and consent is active.
- Consent never silently renews. Expired consent blocks events; monitoring is removed when the app next runs or receives a location event. iOS controls background execution and delivery timing.
- Scheduled requests are one-shot and capped at 60. Critical-task reminders cover the next seven days and refresh with app activity; due-date digests and a post-move check-in are queued ahead. Snoozes returning outside 9 am–7 pm move to the next 9 am. Task changes and notification actions regenerate the schedule.

## Regression coverage

The sole Swift Testing file includes `ReminderPolicyRegressionTests`, `LocationRegionRegressionTests` and `ReminderScheduleRegressionTests`. They cover explicit consent, aliases, mismatched providers, destination changes, the 20-zone cap, cold-start reconciliation, obsolete asynchronous searches, exact-task visit matching, persisted actions, one-shot schedules, fractional-second snooze deadlines, stale alerts and competing notification writes. Place search, region monitoring and the notification center use injected test doubles. The existing suppression-gate tests remain in place.

Build/test results are recorded in [implementation status](IMPLEMENTATION_STATUS.md). Automated tests do not establish real background delivery while walking or driving past a provider.

## Phone acceptance checks

1. Allow 30 Days, select While Using, and confirm the app offers the Always/settings recovery path. Enable Always and notifications to check background behavior.
2. With an eligible named account, confirm the dashboard reports matched zones. A Life Time task must not trigger at Planet Fitness, or a Chase task at another bank.
3. Enter a matched destination zone during allowed hours with the phone locked. Verify the banner identifies the correct task. iOS may defer delivery, and category/daily limits can suppress it.
4. Use Snooze or Mute directly on the notification. Reopen the task and confirm its saved state, then verify no further eligible alert appears while snoozed/muted.
5. Edit the destination, complete/remove the task or disable location permission. Old zones and reminders should no longer act on the previous plan.
6. Upgrade an existing installation and check saved tasks and answers. A successful installation alone does not prove every migration path.

This document updates the original `.kiro` location-reminder specification: the current setup prompt is not limited to the final 14 days; provider identity is explicit; visit matching returns a task; and scheduling is serialized with finite triggers.
