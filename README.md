# Ayah Reminder

A calm Android app that shows one Quran ayah every morning (default 9:00 AM) and one hadith
every night (default 9:00 PM, Bangladesh time), in Arabic and Bangla, with a full-screen reminder.

Tabs: **আজ** (search, প্রিয়, সেটিংস; next prayer; today's ayah and hadith; shortcuts to prayer
times, Qibla and tasbih; adhkar; continue Quran; **সহজ আরবি**), **কুরআন** (full Quran),
**দোয়া** (duas, morning/evening adhkar and a tasbih counter), **মন** (16 moods, each with ayahs,
full surahs and hadiths, from `mood-content.md`, then all topics with search) and **জীবনী**
(Sahaba life stories). Everything saved (ayahs, hadiths, duas, Quran bookmarks) is on one
প্রিয় page, and every setting is on one সেটিংস page. See `docs/ux-plan.md`. One reader with a player (speed, repeat, play all), share as an
image, favourites, light/dark mode, and Bangla labels throughout. Reminders open a full-screen
reading page with a 12-second countdown.

Prayer times are calculated on the phone with the [adhan](https://pub.dev/packages/adhan)
library (default: University of Islamic Sciences, Karachi; Asr Hanafi), from the phone's
approximate location or a city picked by hand. Each prayer has its own azan settings (sound,
time adjustment or a fixed time, reminder before, iqamah reminder); see `docs/AZAN.md`. The
azan uses Wikimedia Commons recordings at their original quality (`res/raw/azan.mp3`,
`res/raw/azan_fajr.webm`, details in `assets/azan_license.json`).
The Qibla compass uses the phone's rotation sensor. The location never leaves the phone
(see `docs/PRIVACY.md` and `docs/DATA_SAFETY.md`).

Audio: every ayah has a play button that streams the Arabic recitation (human reciters only)
from EveryAyah.com and caches it; the Bangla meaning and hadiths are read with the phone's
built-in Bangla text-to-speech. The "সাহাবিদের জীবনী" (Life of the Sahaba) section has the owner's
life stories of the Sahaba (drafts that need scholar review); recorded MP3s are bundled in
`assets/story_audio/`, and stories without one use the phone's Bangla voice.
The logo, Islamic geometric pattern and icon are drawn in code (no image assets);
icons are Material Icons (Apache 2.0) and fonts are under the SIL Open Font License.

## সহজ আরবি (Learn Arabic from Bangla)

On the আজ (Home) screen → সহজ আরবি card. Level 1 (পড়তে শিখি) has 22 short lessons: letters in groups, similar
sounds, letter shapes, joining, the marks (যবর, যের, পেশ, তানবীন, সুকুন, শাদ্দাহ, মাদ্দ), আল,
Quran words, qalqalah/ghunnah, stop signs, Surah Al-Fatiha and the last three surahs. Each lesson
has a Bangla explanation, big tap-to-hear letters and 3–4 games (শুনে বেছে নিন, মেলান, সাজান,
লিখে দেখুন). Stars, a daily streak, one-by-one unlocking and a spaced-repetition review are saved
on the phone. Levels 2–4 show as "শীঘ্রই আসছে".

* All lesson text is original and lives in `tools/build_arabic_lessons.py`, which writes
  `assets/arabic/level1.json` and checks every Quran word against the app's Tanzil text.
* Qari recordings go in `assets/arabic_audio/` with the names in `docs/ARABIC_AUDIO_LIST.md`;
  until a file exists the app shows "অডিও শীঘ্রই" (no synthetic voice for Arabic). Surah ayat
  play from the chosen EveryAyah reciter.
* Level 2 preparation: `tools/quran_word_frequency.py` counts Quran words by lemma from the
  Quranic Arabic Corpus (morphology v0.4, © Kais Dukes, GNU GPL, corpus.quran.com) and writes
  `assets/arabic/level2_words.json` and `docs/LEVEL2_WORDS.md` (the 300 most frequent lemmas).

## What's inside

| Path | What it is |
| --- | --- |
| `ayah-app-content-list.md` | The list of ayahs and hadiths, grouped by category |
| `mood-content.md` | The 16 moods: ayahs, full surahs and hadiths (hadiths marked (H) need a scholar to check the grade) |
| `assets/content.json` | All the downloaded text; the app works offline from this file |
| `tools/fetch_content.py` | Downloads the text from Tanzil.net, QuranEnc.com and HadeethEnc.com |
| `tools/hadith_map.json` | Which HadeethEnc hadith matches each reference (`null` = not on HadeethEnc, skipped) |
| `lib/` | The Flutter app |
| `.github/workflows/build-apk.yml` | Builds the APK on every push (Release on `main`) |
| `.github/workflows/fetch-content.yml` | Re-downloads the content when the list changes |
| `assets/stories.json` | The Sahaba life stories shown in the app (draft, need scholar review) |
| `tools/story_drafts_unused.json` | Earlier AI-written drafts, not shown in the app |
| `tools/azan_audio.py`, `.github/workflows/azan-audio.yml` | Finds a freely licensed azan on Wikimedia Commons and bundles the one named in `tools/azan_choice.txt` |
| `.github/workflows/story-audio.yml` | Run by hand: creates story MP3s with ElevenLabs within the free credits and commits them to `assets/story_audio/` |

## Content sources

* Arabic Quran text: [Tanzil.net](https://tanzil.net), Uthmani script (CC BY 3.0, text unchanged)
* Bangla translation and footnotes: [QuranEnc.com](https://quranenc.com), Dr. Abu Bakr Muhammad Zakaria
* Hadith Arabic, Bangla and explanation: [HadeethEnc.com](https://hadeethenc.com)

## Getting the APK

* **From `main`:** open the repo's **Releases** page and download the newest `AyahReminder-N.apk`.
* **From another branch:** open **Actions → Build APK → the latest run → Artifacts → AyahReminder-apk**
  (a zip file with the APK inside).

## Changing the content

Edit `ayah-app-content-list.md`, `mood-content.md` (or `tools/hadith_map.json`) on GitHub and commit.
The **Fetch content** workflow downloads the text again and commits a new `assets/content.json`.
You can also start it by hand from the Actions tab.
