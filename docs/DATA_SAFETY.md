# Google Play "Data safety" notes

Answers for the Data safety form in Play Console, based on what the app does.

## Data collection and sharing

- **Does your app collect or share any of the required user data types?** No.
  - Google counts data as "collected" only when it is sent off the device. The
    approximate location is processed **only on the device** (prayer times and
    Qibla) and is never transmitted, so it is not "collected".
- **Is all of the user data collected by your app encrypted in transit?** Not
  applicable (no user data is collected). Recitation audio is downloaded over HTTPS.
- **Do you provide a way for users to request that their data is deleted?** Not
  applicable. Everything stays on the phone and is removed when the app is
  uninstalled.

## Permissions and why they are used

| Permission | Why |
|---|---|
| `ACCESS_COARSE_LOCATION` | Prayer times and Qibla, calculated on the phone. Optional: a city can be picked by hand. |
| `POST_NOTIFICATIONS` | Morning/night reminders and azan. |
| `SCHEDULE_EXACT_ALARM` | Reminders and azan at the exact time. |
| `USE_FULL_SCREEN_INTENT` | The reminder can open the reading screen. |
| `RECEIVE_BOOT_COMPLETED` | Re-plans reminders and azan after the phone restarts. |
| `VIBRATE`, `WAKE_LOCK` | Notification vibration; gentle vibration when facing the Qibla. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Lets the user allow reminders on phones that stop background alarms. |
| `INTERNET` | Arabic recitation audio from EveryAyah.com. |

Location is read with Android's own `LocationManager` (no Google Play
Services), only when the user asks for it or when the app opens; the app never
uses location in the background.

## Other form answers

- Ads: **No ads.**
- Target audience: general (all ages); the app collects no data.
- Privacy policy: `docs/PRIVACY.md` (needs to be published at a public URL for Play).
