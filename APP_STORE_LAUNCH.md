# MovingSoon — first App Store launch

Updated October 26, 2026. The app is not uploaded, submitted or publicly released yet.

## 1. Create the app record — owner, required next

Open [App Store Connect](https://appstoreconnect.apple.com/) → Apps → + → New App.

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | MovingSoon |
| Primary language | English (U.S.) |
| Bundle ID | app.movingsoon |
| SKU | movingsoon-ios |
| User access | Full Access |

The SKU is an internal identifier. Keep the existing bundle ID. If it is absent from the menu, register the explicit identifier in the Apple developer account for the existing team, then retry. Do not create a differently identified app to work around the menu.

Status: owner confirmed this record has not been created. The previous upload failed before transferring a build because this record was missing. [Apple: create the record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

## 2. Activate paid sales — owner, required

In Business, accept any outstanding developer agreements and the Paid Apps Agreement as Account Holder. Complete the required banking and tax forms. Under the app's Pricing and Availability, set the United States price to **$4.99**, check regional equivalents and choose countries/regions. Check the tax category. This is a one-time paid download, so no subscription or in-app purchase product is needed for this pricing model.

Complete regional compliance fields shown by Apple, including trader status if distributing in the EU. Answer according to the owner's actual situation. [Agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements), [pricing](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/).

## 3. Upload version 1.0 (4) — archive prepared, distribution export pending

Build 4 adds the expired-location-window renewal invitation. Its signed archive is in `build/release-2026-10-26`, but the IPA export failed with Xcode distribution-signing/profile permission errors. Check the existing Apple account/team signing access in Xcode, retry the local App Store export with the saved ExportOptions.plist, and verify the resulting IPA before upload. Build 3 does not include this feature.

The new candidate uses support@movingsoon.app and the live domain's support/privacy pages. Archive/export verification is recorded in RELEASE_HANDOFF_2026-10-23.md, with separate entries for each candidate. Upload only after the app record exists, using Xcode's App Store Connect distribution workflow or its equivalent command-line export/upload. Wait for Apple's processing and resolve any reported issues. Uploading alone does not submit for review.

[Apple: upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

## 4. Finish the listing — owner and implementation support, required

Use APP_STORE_LISTING.md for the prepared description, subtitle, keywords and reviewer instructions.

| Field | Value |
|---|---|
| Version | 1.0 |
| Primary category | Productivity |
| Secondary category | Utilities |
| Marketing URL | https://movingsoon.app |
| Support URL | https://movingsoon.app/support/ |
| Privacy policy | https://movingsoon.app/privacy/ |
| Support email | support@movingsoon.app |
| Copyright | 2026 Mani Danesh |

Upload the four PNGs from AppStoreScreenshots/Upload-1.0-3 and verify the required media slots in App Store Connect. These have no alpha channel and preserve the original visible pixels. The older Moves & backups image is omitted because the help links changed in build 2, and the older Reminders image is omitted because build 3 changes its settings explanations. The 1320×2868 captures are an accepted large iPhone size; Apple documents scaling fallbacks for other slots. Validate the actual upload rather than assuming every slot is satisfied.

Complete App Privacy, the current age-rating questionnaire, content rights, export compliance and other required questionnaires shown by Apple. Do not infer a “Data Not Collected” label just because storage is local: review the optional Census ZIP requests and Apple service use against Apple's definitions. Do not presume an age rating. Optional accessibility claims should reflect completed device checks.

For App Review, provide the owner's contact name, reachable email and phone number. No app sign-in is required. Select the processed **1.0 (3)** build. Answer encryption questions against the actual binary.

[Privacy definitions](https://developer.apple.com/app-store/app-privacy-details/), [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

## 5. Test the release — TestFlight recommended; physical checks pending

Use TestFlight with the owner and a small group before charging customers. TestFlight itself is not mandatory for App Store submission. External testers require Apple's beta-review process.

Complete the physical acceptance checklist in RELEASE_HANDOFF_2026-10-23.md: upgrade/data preservation, onboarding, independent accounts, dates, offline use, permissions, real notification/location delivery, archive/reactivation, JSON backup/restore, large text, VoiceOver and help links. Automated tests and a successful install do not establish these physical results. Document failures and fix them before final submission. Confirm support email can receive and reply to a real test message.

[Apple: TestFlight](https://developer.apple.com/testflight/).

## 6. Submit for review — required after the candidate is accepted

Choose **Manually release this version** for control of launch timing. Confirm price, territories, privacy answers, reviewer contact, screenshots and selected build. Click **Add for Review**, then the separate **Submit for Review** action. Respond to App Review questions and resolve any issues.

[Apple: submit for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/).

## 7. Launch after approval — owner release decision

If manual release was selected, click **Release This Version** after approval. Verify the public listing, price and download in the intended storefront. Once the real App Store URL exists, replace the website's Coming soon call to action with the official link and badge, and deploy that website update. Monitor support requests and crash reports after launch.

[Apple: release options](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/).
