# MovingSoon release handoff — October 23–26, 2026

Build/archive and screenshot evidence links below refer to local project artifacts. They are excluded from Git and are not GitHub downloads. The source, tests and validation scripts are versioned separately.

## Current candidate — October 26, 2026

**Version 1.0 (4) includes the expired-window renewal invitation and has a verified signed archive. App Store IPA export and phone installation are pending.** No upload or submission happened.

- [Signed archive](build/release-2026-10-26/MovingSoon-1.0-4.xcarchive) and [artifact notes](build/release-2026-10-26/README.md). Archive strict signature, version 1.0/build 4, minimum iOS 17 and required resource/configuration checks passed.
- **306 test definitions / 338 executions passed, 53 suites, 0 failures/skips.** Added expiry, quiet-hours/DST/timezone, stale-cycle, cancellation and capacity coverage. The dashboard's large SwiftUI expression is separated into content, sheet, overlay and lifecycle boundaries so both Debug and Release compile.
- One local invitation per expired consent cycle is prequeued when critical eligible tasks remain. It opens reminder controls; only **Enable another 30 days** renews consent. An in-app card covers already-expired windows. Explicit Stop opts out; completed/muted tasks and archive/cancel/new-grant actions cancel obsolete invitations. The existing 80% nearby-alert pause remains disclosed.
- [Actual renewal-screen QA](build/release-2026-10-26/QA/README.md) used fictional data on an isolated iPhone 16e / iOS 26.0 simulator. Review & extend opened Reminders while consent remained expired; Not now dismissed the card. No physical background-delivery acceptance is claimed.
- Xcode App Store export failed: the team could not create iOS App Store provisioning profiles and no distribution certificate was available. The valid cached store profile and prior cloud-managed build 3 export do not resolve current signing access. Restore distribution-signing access in Xcode and retry with the saved export options; do not upload build 3 expecting the new feature.
- The known paired iPhone is disconnected. No installation or phone-data change occurred. The owner confirmed **Always** Location access on October 26; Precise Location, notification permission and the app's current consent expiry remain unverified on that phone.

## Previous candidate — October 25, 2026

**Version 1.0 (3) includes the nearby-reminder fixes and is archived/exported locally. It has not been installed on the phone, uploaded or submitted.** Supersedes build 2 for release preparation. See [nearby-reminder diagnosis](NEARBY_REMINDERS_REVIEW_2026-10-25.md).

- [Signed archive](build/release-2026-10-25/MovingSoon-1.0-3.xcarchive) and [App Store IPA](build/release-2026-10-25/MovingSoon-1.0-3.ipa). Bundle app.movingsoon; team 3CXZWALQ26; Xcode 26.0 / iOS 26 SDK; minimum iOS 17. Source includes local uncommitted release work in addition to base commit 6a37a74.
- **290 test definitions / 302 executions passed, 0 failures/skips**, including the new nearby-budget and sparse-region regressions. Simulator results do not establish physical location or background delivery.
- Archive/export succeeded. Archive and exported IPA strict signatures, resource/key configuration, version metadata, distribution `get-task-allow=false` and ZIP integrity passed. IPA 7,211,096 bytes; SHA-256 `739ada9daccf4bf37a8ffe761ff260ecd70ffc054faf86d2024dfb991612b2b0`.
- The nearby allowance is two per local day, independent of morning/date reminders. Empty provider search results no longer exhaust monitoring selection. Settings disclose the allowance, suppression rules, Precise Location requirement and monitoring errors.
- Use the four [build 3 screenshot candidates](AppStoreScreenshots/Upload-1.0-3/README.md). The older reminder/settings capture needs recapture before reuse; it no longer matches the new explanations.
- Phone installation/acceptance is pending. The known paired-device lookup returned Device not found; no phone installation or data changes were performed. The owner's current location/consent settings have not been confirmed.
- App Store Connect account record and submission settings remain pending the owner's last confirmation. Recheck public website URLs before submission: the last October 25 checks found www pages serving correctly and the root domain returning 404. This content/routing task is separate from the app's signed candidate.

## Previous candidate — October 24, 2026

**Version 1.0 (2) is archived and exported locally, with signatures and bundle checks passed. Upload, App Review and public release have not happened.** The owner confirmed on October 24 that the App Store Connect app record has not been created. The account record is the next upload dependency. Use [APP_STORE_LAUNCH.md](APP_STORE_LAUNCH.md) for the ordered launch steps.

- [Signed archive](build/release-2026-10-24/MovingSoon-1.0-2.xcarchive) and [App Store IPA](build/release-2026-10-24/MovingSoon-1.0-2.ipa) are saved in the project. Version 1.0, build 2, bundle app.movingsoon, team 3CXZWALQ26; Xcode 26.0 / iOS 26 SDK; minimum iOS 17.
- The executable contains the live support and privacy URLs, https://movingsoon.app/support/ and https://movingsoon.app/privacy/, plus support@movingsoon.app. GitHub Issues remains a fallback. All three website pages returned HTTPS 200 with the expected email using a browser-style request. A default Python user-agent request returned 403; the browser-style requests succeeded.
- Archive and exported IPA signatures passed `codesign --verify --deep --strict` against system trust. The exported App Store entitlement has `get-task-allow = false`. Archive/export succeeded; ZIP integrity, version/bundle metadata and required Census configuration checks passed. No key was logged. The archive has only the informational App Intents metadata-extraction warning because the app does not use AppIntents.framework.
- IPA: 7,204,559 bytes; SHA-256 `591b60fdbd69fbb277e21eb86d7cfd5415fee808d1810b5663dcab1105c130ad`. Archive/export logs, export options and SourceManifest.json are saved beside it. The manifest records base commit 6a37a74 plus local uncommitted release changes; that commit alone does not reproduce this candidate.
- This candidate has not been installed on the physical iPhone or uploaded. The earlier build 1 install/launch below does not validate build 2's interactive behavior. Physical acceptance boxes remain pending. The large automated suite was not rerun for these URL, help-link and build-number changes; the signed Release archive/export and focused checks above cover this preparation.
- Five upload-ready screenshots are in [Upload-1.0-2](AppStoreScreenshots/Upload-1.0-2/README.md). The fully opaque alpha channel was removed losslessly, with dimensions and visible pixels verified unchanged. The older Moves & backups capture is omitted because build 2 adds a Support website link. App Store Connect media upload/validation is pending.

## Previous candidate — October 23, 2026

**Status: signed archive and App Store IPA verified; installed and launched on the paired iPhone. Full physical acceptance and submission are pending.** The initial launch attempt was blocked by the phone's lock screen; the later installation and launch succeeded. The App Store Connect upload was attempted and failed because the app record for `app.movingsoon` does not exist. No build was uploaded or submitted for review.

## Prepared candidate and completed work

**October 24 contact update:** GitHub commit `6a37a74` changes the preferred email to `support@movingsoon.app` and records `https://movingsoon.app` as the coming-soon product website. The archive/IPA below predates that update and still uses the earlier email. Re-archive before submission to include the new contact; the contact-only Release simulator build and full local Debug simulator build passed. GitHub privacy/support pages remain the working destinations while website hosting is prepared.

- Version **1.0 (1)**, bundle **app.movingsoon**, team **3CXZWALQ26**, iPhone/iOS 17 minimum; archived with Xcode 26.0 / iOS 26 SDK.
- [Signed archive](build/release-2026-10-23/MovingSoon-1.0-1.xcarchive) and [App Store IPA](build/release-2026-10-23/movingsoon.app.ipa) are saved locally. Archive signature, exported distribution signature, ZIP integrity and required bundle-resource checks passed. Distribution export uses a Cloud Managed Apple Distribution certificate and has `get-task-allow = false`.
- IPA SHA-256: `bdd01e125c2516ad0167c34da81cfef415e79d45efb1b44070ded996c282eac7` (7,203,858 bytes).
- Installed the signed Release archive's development-signed app on the paired iPhone 12 Pro / iOS 26.6.2, preserving its app container. The first launch returned iOS `Locked`; installation and launch were retried successfully at 12:19 PM America/Denver. The OS accepted the launch. Interactive migration/data inspection and the full acceptance walkthrough remain pending.
- Before installation, copied the existing app database and preferences to the private, ignored directory `build/private-phone-backups/2026-10-23`. The database copy passes SQLite integrity checking. iOS-owned container metadata/snapshots were unreadable and are not included; no Documents folder existed. This is an app-data safeguard, not a complete iPhone backup.
- Published the explicitly approved current [privacy policy](https://github.com/manidanesh/MovingSoon/blob/main/PRIVACY_POLICY.md) at commit [`eb64e2b`](https://github.com/manidanesh/MovingSoon/commit/eb64e2b). Verified its current date, backup disclosures and email contact through GitHub. The listing's Support URL points directly to its [Contact section](https://github.com/manidanesh/MovingSoon/blob/main/PRIVACY_POLICY.md#contact).
- Upload evidence: `build/release-2026-10-23/movingsoon-release-2026-10-23-upload.log`; Xcode distribution diagnostics report `DistributionAppRecordProviderError.missingApp(bundleId: "app.movingsoon")`.

## Immediate account step

Create the app in **App Store Connect → Apps → + → New App**: iOS, **MovingSoon**, **English (US)**, bundle **app.movingsoon**, SKU **movingsoon-ios**. The SKU is an internal identifier. Then upload the current **1.0 (2)** candidate. The owner confirmed on October 24 that this account step is pending. [Apple: add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

The existing Xcode account can archive and export distribution-signed builds. Do not change the bundle ID to work around the missing app record.

See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for automated/build evidence. Simulator migration, date, backup, consent and rollback tests do not establish physical background delivery. The declared iOS 17 minimum has not been exercised on an installed iOS 17 runtime.

## Record the candidate

Record tester/date, version/build, source commit, installation source, iPhone/iOS, original timezone, permissions, Focus and notification-summary settings. Use fictional account data. Back up existing phone work before upgrading; tie evidence to this candidate.

All boxes below start **pending**. Record Pass / Fail / Not exercised, evidence and any issue beside each item; an unobserved or suppressed notification is not a delivery pass.

## Physical iPhone acceptance

- [ ] **Install, upgrade and reopen.** Open the signed candidate on the phone. For an upgrade, retain a previous installation with completed work, custom notes, household answers and account dates. Confirm that those values survive the upgrade and a cold relaunch; no unexpected onboarding or reset appears. Test a fresh install separately.
- [ ] **Create and edit a move.** Generate a checklist with destination `80202`, optional origin `10001` and a chosen date. Skip optional questions. Also check Canadian input such as `K1A 0B1`, a cross-border edit and an already-past moving day. Completed work remains intact; previous-area items can request review rather than disappearing silently.
- [ ] **Independent accounts and custom items.** Add two accounts under one service, with different nicknames and shipment/renewal dates. Complete or remove one; the other remains. Rename a provider: an unchanged old catalog website must not open as the new provider. An explicitly entered different website remains usable. Edit a custom title, category, date and note, then relaunch and verify all fields.
- [ ] **Progress and reversible actions.** Complete and reopen a task; remove and immediately undo another. Use task Mute / Unmute and Snooze / Clear snooze. Confirm saved status and dates after relaunch. Snoozed unfinished work must not produce a false whole-checklist completion. Reopening clears stale mute/snooze choices.
- [ ] **Calendar dates across timezones.** Enter distinct move, shipment, renewal and custom dates in New York time; switch the device to Los Angeles time and reopen. Every chosen calendar date stays the same. Check displayed reminder times in the current local timezone, then restore the phone's original timezone settings.
- [ ] **Offline and optional requests.** With location and Census features off, use the checklist, edits and bundled background images offline. Enable **Use ZIP area estimates** after reading the ZIP-sharing explanation; check a successful US lookup, a cached offline view and an unavailable refresh. Turn it off again. A failed geocode/provider search must not be presented as confirmed coverage.
- [ ] **Notification permission and date delivery.** Decline notifications and continue using the checklist. Open **Move settings → Reminders**, then enable notifications through the offered prompt/settings path. Queue a near-term dated task and observe an actual scheduled alert with the phone locked. Record its planned/actual time and Focus/summary state. Verify the settings disclose the 30-day date window, seven-day critical check-ins, refresh recommendation and any deferred alerts.
- [ ] **Nearby setup and correct-provider delivery.** With an unfinished named-provider task and a suitable destination, explicitly enable 30 days. Check While Using → Always/settings recovery and the visible expiry. On an eligible day, test a different provider first, then a supported matching place with the phone locked. Require an actual correct-task positive result; a cooldown, mute or other suppression is not proof of provider discrimination. See the conditions below.
- [ ] **Notification actions and stopping access.** From a delivered task notification, use Snooze or Mute; reopen and verify the saved task state. Clear/unmute and check eligibility returns. Use **Stop nearby reminders** and confirm its stopped status while ordinary checklist notifications remain available. Re-enable only through an explicit choice. Revoke system location permission and confirm the status/recovery path.
- [ ] **Move lifecycle, sharing and backup.** Use **Archive & start another move**, cancel a test move, and reactivate a saved move from **Moves, sharing & backups**. History stays available and the prior move stops active reminders. Export a readable checklist and JSON backup to a private Files destination. Restore the backup: existing moves remain, restored copies are archived, and nearby consent/Census stay off. Verify notes/assignments in the shared snapshot; it is not live household synchronization. Reject an invalid JSON backup without changing existing moves.
- [ ] **Accessibility and help.** At the largest accessibility text size, finish intake and reach task actions, reminder controls, Save/Cancel and backup dialogs without clipped controls. Walk the main flow with VoiceOver and check focus, selection state and completion controls. Open support/privacy links in a logged-out browser and verify the email support path. Record the smallest phone checked; simulator screenshots alone do not complete this item.

For nearby delivery, use active app consent, Always location permission, notifications enabled, an eligible unmuted/unsnoozed task, less than 80% completion and local time 9 am–7 pm. Destination zones use supported matches within 8 km of the destination and a 200 m provider zone; iOS chooses event timing. Per-category cooldown and the immediate-alert budget can suppress delivery, including when a hero/digest already arrived that day. Record the route, time and suppression state. An exit/re-entry or a later eligible day may be needed; do not count a settings status as delivered-notification evidence.

Thirty-day real-time expiry and physical fault injection are **not completed by this checklist's short walkthrough**. Their automated coverage is recorded separately. If no controlled device exercise is performed, leave the physical result Not exercised. Recovery-copy export, if encountered on a test installation, must preserve the original store and be treated separately from normal JSON restore.

## App Store Connect reviewer notes — draft to paste

No login or reviewer credentials are required. Enter US ZIP 80202 or Canadian postal code K1A 0B1, choose a moving date, and continue through optional household/service choices. Past moving dates are supported. Use Review services to add an account, or add a custom dated item. Task details provide instructions, outside links and manual completion. Eligibility-dependent government items require customer review; the app does not submit provider changes.

Location is optional. Move settings → Reminders offers notification settings and explicit 30-day nearby consent. Background reminders use Apple region/visit events and require Always authorization plus notifications. Continuous updates run only with the dashboard foregrounded and consent active. Expiry rejects events; monitoring is removed when the app next runs or receives an event. Stop and explicit renewal controls are available. iOS controls delivery timing; enabling the feature does not produce an immediate alert. Checklist/date reminders work without location.

US Census estimates are off until the customer accepts the ZIP-sharing explanation. Requests send entered US ZIPs for aggregate area context, not personal income or membership predictions. Photos are bundled; no Unsplash requests occur. There is no MovingSoon account/backend, automatic provider login or live shipment import.

Move settings → Moves, sharing & backups provides manual sharing and readable JSON backups. Restore adds archived copies, preserves existing moves and leaves nearby/Census features off. Sharing does not synchronize devices.

Support: support@movingsoon.app. Website: https://movingsoon.app. Privacy policy: https://movingsoon.app/privacy/. Support site: https://movingsoon.app/support/. These website pages were verified live on October 24. GitHub Issues remains a fallback.

## Submission handoff — still pending confirmation

- [x] Record signed archive/distribution validation and installation result above. The upload attempt failed before upload because the app record is missing; TestFlight availability remains pending.
- [ ] Set and verify the intended **US $4.99 one-time paid-download price**, regional prices/availability, paid-app agreements and tax/banking status in App Store Connect.
- [ ] Complete the current age-rating and privacy questionnaires against the actual binary and optional Apple/Census behavior. Verify the public support/privacy URLs without authentication.
- [ ] Confirm version/build, final candidate screenshots and description match the submitted binary. Screenshot candidates are in [ReleaseCandidate-2026-10-22](AppStoreScreenshots/ReleaseCandidate-2026-10-22/README.md); candidates are not an upload or approval record.
- [ ] Replace draft reviewer notes only after checking their paths and behavior against the signed candidate. Resolve failed phone checks, document any unexercised cases and obtain the release owner's final submission decision.

Result record: **Pending**. Tested candidate: ______. Phone/iOS: ______. Tester/date: ______. Blocking issues: ______. Evidence location: ______.
