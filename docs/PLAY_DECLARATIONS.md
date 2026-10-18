# Google Play Console: what to write

Copy these texts into Play Console → **App content** (Policy → App content).
The app has **no ads**. Reminders can be turned off in সেটিংস → "রিমাইন্ডার চালু", and the azan
in নামাজের সময় → "আজান ও নামাজের নোটিফিকেশন" (or per prayer: আজান / শুধু নোটিফিকেশন / বন্ধ).

---

## 1. Full-screen intent (`USE_FULL_SCREEN_INTENT`)

App content → **Full-screen intent** → "Does your app use the full-screen intent permission?" → **Yes**.

- **Core functionality:** choose **"Alarm"** ("Setting alarms or timers").
- **Description:**

> Ayah Reminder is an alarm-style reminder app. At the morning and night times the user
> chooses, it rings a gentle alarm and opens a full-screen page showing that day's Quran ayah or
> hadith, also on the lock screen, like an alarm clock. The user dismisses it with "আমি পড়েছি"
> (I have read) or snoozes it for 10 minutes. The user can also choose to show the azan full screen at
> prayer times. Full-screen intents are used only for these user-scheduled alarms.

If Google does not grant this automatically on Android 14+, the app still works: the setup screen
asks the user to turn on "ফুল-স্ক্রিন রিমাইন্ডার" in the system settings.

## 2. Exact alarms (`SCHEDULE_EXACT_ALARM`)

The app uses `SCHEDULE_EXACT_ALARM` (not `USE_EXACT_ALARM`), which the user grants in system
settings, so **no Play Console declaration is required**. If Play Console asks anyway:

> The app sets alarms with AlarmManager.setAlarmClock for the reminder times the user chose and for
> the five daily prayer times (azan). These must ring at the exact minute; a delayed azan or reminder
> is wrong for the user. Only the next alarm is set at a time.

## 3. Foreground service (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`)

App content → **Foreground service permissions** → tick **Media playback**.

- **Description:**

> At each prayer time the user set to "Azan", an exact alarm starts a media-playback foreground
> service that plays the bundled azan recording (about 1–3 minutes) from start to end on the alarm
> audio stream, then stops itself. At the reminder times the user chose, the same kind of service
> plays a short gentle alarm sound (a few seconds, repeated for at most one minute) with the day's
> ayah. A notification with a stop button ("থামান") is shown the whole time; pressing a volume key
> also stops it. The playback must start at the exact time and continue while the screen is locked
> or the app is closed, so it cannot be deferred. When the user presses play on a surah in the
> Quran section, the recitation (per-ayah audio) keeps playing with the screen off through a
> media-playback foreground service with play/pause controls in the notification.

- **User impact if deferred / interrupted:** "The azan or reminder would not play at the prayer or
  reminder time, or would stop in the middle."
- **Video link:** a short screen recording (unlisted YouTube link) showing: set a prayer to
  "আজান" → press "আজান শুনে দেখুন" → the notification with "থামান" appears and the azan plays →
  press "থামান". Then "১ মিনিট পর পরীক্ষা করুন" on the setup page → lock the phone → the reminder
  rings and opens full screen.

## 4. Display over other apps (`SYSTEM_ALERT_WINDOW`)

There is no separate Play Console form for this permission. If a reviewer asks:

> Used only so that the alarm-style reminder page can open in front of other apps at the time the
> user chose (Android blocks activity starts from the background otherwise). The app draws no
> overlays of its own. It is optional and asked for on the setup screen with an explanation.

## 5. Location (`ACCESS_COARSE_LOCATION`, foreground only)

No background location, so **no location declaration form is needed**.

**Data safety** form → Data collection → **"No"** for all data types (including Location):

> Approximate location is used only on the device to calculate prayer times and the Qibla
> direction. It is saved only on the phone and never sent anywhere. The user can pick a city
> instead of allowing location.

(Google counts data as "collected" only when it leaves the device.)

## 6. Other App content answers

| Question | Answer |
|---|---|
| Ads | **No, my app does not contain ads** |
| App access | All functionality is available without special access (no login) |
| Content rating | Reference / education; no violence, no user-generated content |
| Target audience | 13+ (or "all ages"; the app collects no data) |
| News app | No |
| Health app | No |
| Government app | No |
| Financial features | None |
| Privacy policy URL | The public URL of `docs/PRIVACY.md` (e.g. the GitHub file link) |
