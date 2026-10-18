# Azan

## Settings (per prayer: Fajr, Dhuhr, Asr, Maghrib, Isha)

Tap a prayer on the prayer times page to open its azan page:

| Setting | Choices |
|---|---|
| Sound | মসজিদে নববী · মসজিদুল হারাম · শুধু নোটিফিকেশন · বন্ধ (each azan has "শুনে দেখুন") |
| Time | "সময় আগে-পিছে করুন" −30 … +30 minutes, or "নিজে সময় দিন" (a fixed time every day) |
| Reminder before | off · 5 · 10 · 15 · 30 minutes before the azan |
| Iqamah reminder | off · 10 · 15 · 20 minutes after the azan |

For all prayers (bottom of the prayer times page): azan volume (10–100% of the alarm
volume), "সাইলেন্ট মোডেও বাজবে" (on by default), vibration, full screen, "আজান শুনে দেখুন".
The calculation method and Hanafi Asr are unchanged. A moved azan shows on the prayer
list as "আসর ৩:৪৫ → আজান ৩:৫৫".

## How it is scheduled

- `Prayers.eventsJson` (Dart) lists the next 30 days: each azan (or notification), each
  reminder before it and each iqamah reminder, sorted, every time unique.
- Every settings change, and every app start, calls `Prayers.schedule`, which hands the
  list to Android (`AzanStore`, saved with `commit()`).
- Android sets only the next event, as an **alarm clock** (`setAlarmClock`). This is the
  alarm type Oppo/ColorOS, Xiaomi etc. do not delay or drop; it is used for every event so
  the "ring, then set the next one" chain never breaks. Without the exact-alarm permission
  it falls back to `setAndAllowWhileIdle`.
- `AzanBootReceiver` sets the next event again after a restart, an app update, or a
  clock/time-zone change.
- Oppo/Realme/OnePlus: the setup page ("অনুমতি ও সেটআপ") also asks for Auto launch,
  background activity and lock-screen notifications.

## Audio

Now (interim): Wikimedia Commons, bundled at original quality (no mono, trimming or
loudness change), by `tools/azan_audio.py`:

| File | Recording | Author | Licence |
|---|---|---|---|
| `azan.mp3` (stereo MP3, ~134 kbit/s, 87 s) | The Adhan – Muslim Call to Prayer – Aaqib Azeez | Atcovi | CC BY-SA 4.0 |
| `azan_fajr.webm` (audio stream only, stereo Opus, ~136 kbit/s, 248 s) | Eid al-Fitr Fajr azan at Malmö Mosque, 19 Aug 2012 | Islamic Center Malmö | CC BY 3.0 |

Both are used for both sound choices until the masjid recordings are added.

Planned: The Wahy Project live recordings (Masjid an-Nabawi and Masjid al-Haram, 2010),
CC BY-NC-ND 3.0, bundled byte for byte by `tools/azan_wahy.py` as
`azan_nabawi[_fajr|_dhuhr|…].mp3` / `azan_haram…mp3`. Their download links (old Dropbox
public folder) are dead and the Internet Archive has no copies (`tools/data/wahy_probe.json`,
`tools/data/wahy_wayback.json`); the files are being requested from the author.
