# Privacy Policy — MovingSoon

**Last updated: May 2026**

MovingSoon ("the app") is a moving address checklist app for iOS. This privacy policy explains what data the app collects, how it is used, and your rights.

---

## Data We Collect

### Location Data
If you grant location permission, the app uses your device's location to send proximity-based reminders when you are near a bank, DMV, pharmacy, or other place relevant to your pending address-change tasks.

- Location access is **optional**. The app works fully without it.
- Location access is **time-limited**. The app requests a 30-day consent window. After 30 days, location monitoring stops automatically.
- Location data is **processed on-device only**. Your coordinates are never transmitted to any server.
- Location data is **never stored persistently**. It is used in real time to evaluate whether a notification should fire, then discarded.

### Move Data
The app stores the following on your device using Apple's SwiftData framework:
- Your move date
- Your origin and destination ZIP codes
- Your lifestyle profile (which services you use)
- Your selected financial institutions
- Your task completion status

This data **never leaves your device**. It is not synced to any cloud service, not shared with third parties, and not accessible to us.

### Ambient Background Photos
The app fetches background photos from the Unsplash API based on your destination city. The request includes your destination city bucket (e.g. "DENVER") — not your precise location or ZIP code. No personal information is sent to Unsplash.

---

## Data We Do Not Collect

- We do not collect your name, email, or any personally identifiable information
- We do not require account creation
- We do not use analytics or crash reporting SDKs
- We do not sell, share, or monetize any data
- We do not track you across apps or websites

---

## Third-Party Services

| Service | Purpose | Data sent |
|---|---|---|
| Unsplash API | Ambient background photos | Destination city name (e.g. "DENVER") |
| Apple CoreLocation | Proximity reminders | Processed on-device only |
| Apple UserNotifications | Push notifications | Processed on-device only |

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
