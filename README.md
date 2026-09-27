# Ayah Reminder

A calm Android app that shows one Quran ayah every morning (default 9:00 AM) and one hadith
every night (default 9:00 PM, Bangladesh time), in Arabic and Bangla, with a full-screen reminder.

Features: splash screen, home with today's ayah and hadith, colourful category grid,
full-screen reading with a 12-second countdown, share any ayah or hadith as an image,
favourites, dark mode that follows the phone, and Bangla labels throughout.

Audio: every ayah has a play button that streams the Arabic recitation (human reciters only)
from EveryAyah.com and caches it; the Bangla meaning and hadiths are read with the phone's
built-in Bangla text-to-speech. The "সাহাবিদের জীবনী" (Life of the Sahaba) section has the owner's
life stories of the Sahaba (drafts that need scholar review); recorded MP3s are bundled in
`assets/story_audio/`, and stories without one use the phone's Bangla voice.
The logo, Islamic geometric pattern and icon are drawn in code (no image assets);
icons are Material Icons (Apache 2.0) and fonts are under the SIL Open Font License.

## What's inside

| Path | What it is |
| --- | --- |
| `ayah-app-content-list.md` | The list of ayahs and hadiths, grouped by category |
| `assets/content.json` | All the downloaded text; the app works offline from this file |
| `tools/fetch_content.py` | Downloads the text from Tanzil.net, QuranEnc.com and HadeethEnc.com |
| `tools/hadith_map.json` | Which HadeethEnc hadith matches each reference (`null` = not on HadeethEnc, skipped) |
| `lib/` | The Flutter app |
| `.github/workflows/build-apk.yml` | Builds the APK on every push (Release on `main`) |
| `.github/workflows/fetch-content.yml` | Re-downloads the content when the list changes |
| `assets/stories.json` | The Sahaba life stories shown in the app (draft, need scholar review) |
| `tools/story_drafts_unused.json` | Earlier AI-written drafts, not shown in the app |
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

Edit `ayah-app-content-list.md` (or `tools/hadith_map.json`) on GitHub and commit.
The **Fetch content** workflow downloads the text again and commits a new `assets/content.json`.
You can also start it by hand from the Actions tab.
