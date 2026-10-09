# Privacy Policy — MovingSoon

**Last updated: October 8, 2026**

MovingSoon ("the app") is a moving address checklist app for iOS. This privacy policy explains what data the app collects, how it is used, and your rights.

---

## Data We Collect

### Location Data
If you choose 30-day location reminders and grant location permission, the app uses your device's location to identify places relevant to pending address-change tasks. Named accounts match known provider names; government office and mechanic tasks can match the relevant place type. Tasks without a known personal provider keep their regular checklist reminders. Up to 20 places near your destination are monitored directly. Apple's low-power visit detection can also recognize matching providers away from the destination when a sufficiently recent and accurate arrival is reported.

- Location access is **optional**. The app works fully without it.
- Location access is **time-limited**. The app records your explicit 30-day request and the consent date. After that window, location events cannot trigger reminders; monitoring is removed when the app next runs or receives an event. Consent does not renew automatically.
- Background reminders require Always location permission and notifications enabled. Continuous location updates run only while the dashboard is foregrounded with active consent.
- Reminder eligibility is evaluated on-device. Apple Maps searches use a destination area or, for visit-based reminders, the detected visit area to find relevant places. These searches are handled by Apple’s services.
- The app does not store a continuous movement history. Coordinates for the origin and destination neighborhoods you select are stored with your move.

### Move Data
The app stores the following on your device using Apple's SwiftData framework:
- Your move date
- Your origin and destination ZIP codes
- Your lifestyle profile (which services you use)
- Your selected financial institutions
- Your task completion and snooze status
- Optional household answers, including household size, children, pets, housing arrangements and utility responsibility
- Service answers and category-review choices
- Optional current service-use answers (use / do not use / unsure), with the answer date and question version, stored separately from task applicability
- Custom tasks, their due dates and any notes you enter
- Optional provider/account names, nicknames, websites, next shipment and renewal dates, and reminder lead times for separate accounts
- Whether you enabled Census area estimates

Your move profile, selected services, financial institutions, and task status remain on your device and are not synced to a cloud service. After you enable **Use ZIP area estimates**, the app sends the entered US origin and destination ZIP codes to the US Census Bureau's public API to retrieve aggregate ZIP Code Tabulation Area (ZCTA) estimates. The app does not send your household profile, selected services, name, or precise device coordinates in that request. Retrieved public area estimates are cached locally on this device by ZIP code and data vintage so the snapshot can be shown offline; they are not synced to a cloud service. Snapshots older than 30 days are eligible for refresh while this feature is enabled. You can also refresh manually or disable lookups. Disabling hides the snapshot and stops subsequent Census requests; existing public-data cache entries remain on this device.

Account details and dates are entered by you and stored locally. The app does not sign in to providers, retrieve orders or renewals, or update your provider accounts automatically. Opening a saved provider website uses that provider's site and privacy practices.

### Ambient Background Photos
The app fetches background photos from the Unsplash API based on your destination city. The request includes your destination city bucket (e.g. "DENVER") — not your precise location or ZIP code. No personal information is sent to Unsplash.

### On-Device Personalization
Service choices and category reviews are saved with your move to avoid repeating dismissed questions. The new review engine uses these records locally. Older installations may also contain a local `PendingSignal` queue from earlier suggestion flows. There is no transmission path for that queue or your service responses in this version.

The recurring-account review uses your explicit answers to prioritize or pause questions. It does not automatically add or remove tasks. The optional Census snapshot includes aggregate household-income distributions for each area; these are not estimates of your personal income or service memberships. This version has no enabled income-based membership ranking rules. There is no research enrollment, research export or research upload through the app; answering these questions does not consent to a study.

---

## Data We Do Not Collect

- No name, email, or account is required. Text you choose to enter in custom tasks and notes is stored locally.
- We do not require account creation
- We do not use third-party analytics or crash reporting SDKs
- We do not sell, share, or monetize any data
- We do not track you across apps or websites

---

## Third-Party Services

| Service | Purpose | Data sent |
|---|---|---|
| Unsplash API | Ambient background photos | Destination city name (e.g. "DENVER") |
| US Census Bureau ACS API | Optional US area snapshot | Entered US ZIP codes after you enable area estimates; requests aggregate ZCTA estimates |
| Apple MapKit / Maps | Destination POI lookup for location reminders and optional provider searches | Search phrase/category and destination area; visit-based reminders can search near a detected visit coordinate |
| Apple geocoding | Resolve entered postal codes to neighborhoods; resolve a destination for provider lookup | Entered postal code |
| Apple CoreLocation | Proximity reminders | Location used on-device for reminder rules; visit coordinates may also be used in Apple Maps searches |
| Apple UserNotifications | Local notifications | Processed on-device only |

---

## Children's Privacy

This app is rated 4+ and does not knowingly collect data from children under 13.

---

## Changes to This Policy

If we update this policy, we will update the "Last updated" date above. Continued use of the app after changes constitutes acceptance of the updated policy.

---

## Contact

For questions about this privacy policy, open an issue at:
https://github.com/manidanesh/MovingSoon/issues
