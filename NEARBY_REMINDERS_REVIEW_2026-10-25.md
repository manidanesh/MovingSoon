# Nearby reminder diagnosis — October 25, 2026

The owner reports scheduled reminders around 10 a.m. but no nearby-provider reminders. Code inspection found a direct app-side blocker consistent with that symptom. The phone's actual permissions, consent and location callbacks have not been inspected, so this is not proof of the sole device cause.

## Corrected in version 1.0 (3)

1. **Morning alert blocks nearby.** NotificationBudget previously rejected all nearby alerts if any same-day Hero/Digest remained in Notification Center. Nearby submissions now have their own persistent two-per-local-day budget. Scheduled date alerts do not consume it, dismissing notifications does not replenish it, and failed submissions do not consume it.
2. **Unmatched providers waste capacity.** The coordinator selected the first 20 targets before searching, leaving later valid providers unexamined when early searches had no match. It now selects up to 20 actual matches in priority order, retains unchanged regions and removes displaced regions before registering replacements.
3. **Settings hide suppression and accuracy.** Settings now disclose remaining nearby allowance, 9 a.m.–7 p.m. quiet-hour policy, 80% completion pause, category cooldown and destination/visit coverage. Precise Location authorization is observed and reported. Monitoring failures are shown to the customer.

## Coverage still differs from the intended pass-by behavior

The current implementation monitors one nearest matching branch per selected provider within 8 km of the destination, using a 200 m zone. Those zones do not follow the customer's current area. Elsewhere it relies on iOS visit arrivals with accuracy ≤75 m, no departure and arrival age ≤15 minutes. Passing another branch or driving past a business may produce no usable event. These are app design limits, not guarantees Apple provides.

A broader design should maintain relevant provider zones around the user's current area, refresh them on appropriate movement events, and keep matches tied to unfinished exact-provider tasks within iOS's region limit. The priority would be real nearby relevance plus a visible explanation when monitoring cannot run. That broader redesign is not included in this bug fix.

## Verification and next physical check

The full iOS 26 simulator suite passed: 290 definitions, 302 executions, 52 suites, 0 failures/skips. Test result: `/tmp/movingsoon-nearby-fix-2026-10-25.xcresult`. Signed archive/export and strict signatures passed; build 3 artifacts are in `build/release-2026-10-25`.

The paired phone was unavailable to the known device lookup. No new installation or phone-data access was performed. Connect/unlock the intended iPhone, install build 3 while preserving its data, then confirm Always Location, Precise Location, notifications and the app's active 30-day consent. With a qualifying unfinished provider task, test the correct selected branch during 9 a.m.–7 p.m. after a morning notification. Record the actual region/visit callback and accepted notification, then confirm visible delivery with Focus/Scheduled Summary accounted for. A simulator or settings status is not a delivery pass.

[Apple: location accuracy and region monitoring](https://developer.apple.com/documentation/corelocation/cllocationmanager/accuracyauthorization), [visit events](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringvisits%28%29).
