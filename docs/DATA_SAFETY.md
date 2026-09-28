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
| `USE_FULL_SCREEN_INTENT` | The reminder (and optionally the azan) opens full screen like an alarm, also on the lock screen. |
| `SYSTEM_ALERT_WINDOW` | While the phone is in use, the reminder page can open in front of other apps. |
| `RECEIVE_BOOT_COMPLETED` | Re-plans reminders and azan after the phone restarts. |
| `VIBRATE`, `WAKE_LOCK` | Notification vibration; gentle vibration when facing the Qibla. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Lets the user allow reminders on phones that stop background alarms. |
| `INTERNET` | Arabic recitation audio from EveryAyah.com. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Plays the full azan at the prayer times the user turned on, and the short reminder sound (see below). |

## Foreground service declaration (Play Console → App content → Foreground service permissions)

- **Type:** `mediaPlayback` (`AzanService` and `ReminderService`).
- **ReminderService:** at the reminder time the user chose, plays a short gentle sound
  (a few seconds, repeated for at most one minute) on the alarm stream with a notification
  with "পড়ুন" and "১০ মিনিট পরে" buttons, then stops. The sound can be changed or turned off
  in Settings.
- **What it does:** at each prayer time the user set to "আজান", an exact alarm starts the
  service, which plays the bundled azan recording (about 1–3 minutes) from start to end
  and then stops itself. A notification with a "থামান" (stop) button is shown the whole
  time; pressing a volume key also stops it.
- **Why it can't wait / be deferred:** the azan must start exactly at the prayer time and
  keep playing when the screen is locked or the app is closed.
- **User control:** per prayer "আজান / শুধু নোটিফিকেশন / বন্ধ", and "সাইলেন্ট মোডেও আজান বাজবে".
- A short screen recording of the azan playing with the stop button is needed for the form.

Location is read with Android's own `LocationManager` (no Google Play
Services), only when the user asks for it or when the app opens; the app never
uses location in the background.

## Other form answers

- Ads: **No ads.**
- Target audience: general (all ages); the app collects no data.
- Privacy policy: `docs/PRIVACY.md` (needs to be published at a public URL for Play).
- Exact texts for the permission declarations: `docs/PLAY_DECLARATIONS.md`.
