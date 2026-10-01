# Ayah Reminder: new navigation plan (Phase 2)

Date: 2026-10-01. Based on `docs/ux-audit.md`. Status: **waiting for approval**, no code changed yet.

## Goals
- Every feature is at most **2 taps from আজ (Home)**.
- Main features live in tabs or on Home. Settings live in **one** place.
- All saved items live in **one** প্রিয় place.
- Bangla labels with an icon on every menu item. "আপনি" everywhere.
- Bangla text at least 14px, buttons at least 48×48, colours only from the theme.

## Bottom tabs (5)

```
┌────────┬─────────┬─────────┬─────────┬────────┐
│  আজ    │  কুরআন  │  নামাজ  │  দোয়া   │  আরও   │
│ (sun)  │ (book)  │(mosque) │ (hands) │ (grid) │
└────────┴─────────┴─────────┴─────────┴────────┘
```

| Before | After | Why |
|---|---|---|
| আজ | **আজ** | Stays first: today's ayah is the heart of the app. |
| কুরআন | **কুরআন** | Stays. |
| মন | moved to Home (big card) | Mood is a "what should I read now" helper; it fits Home. বিষয় gets its own spot instead of hiding behind a switch. |
| জীবনী | moved to আরও and a Home card | Stories are still drafts; they should not take a main tab. |
| — | **নামাজ** (new) | Most-used daily feature. Qibla lives inside it. |
| — | **দোয়া** (new) | Duas, adhkar and the new tasbih together. |
| আরও | **আরও** | Now only extra features + settings + about, clearly split. |

Alternative if you prefer to keep মন as a tab: আজ · কুরআন · নামাজ · মন · আরও, with
duas as a big card on Home. Recommended choice is the table above, because duas and
tasbih are used every day, mood is occasional.

## Full map

```
আজ (Home)
├─ Top bar: greeting · Bangla date · [🔍 খুঁজুন] [♡ প্রিয়] [⚙ সেটিংস]
├─ Setup warning (only if reminders/permissions are broken)
├─ Next prayer strip ............................ → নামাজ tab
├─ আজকের আয়াত (big green card, Arabic 26+, শুনুন, আগের/পরের)
├─ আজকের হাদিস  ← moved up, right after the ayah
├─ Shortcut grid (2 rows × 3, big cards with icon + Bangla label)
│    নামাজের সময় · কিবলা · তাসবিহ
│    দোয়া · মন কেমন? · প্রিয়
├─ সকাল/সন্ধ্যার জিকির card (changes with time of day)
├─ কুরআন পড়া চালিয়ে যান (last read surah)
├─ মন কেমন? row: 6 common moods as chips + "সব" ......... 1 tap to a mood
├─ বিষয় অনুযায়ী row: common topics as chips + "সব বিষয়" .. 1 tap to a topic
├─ সহজ আরবি card
└─ সাহাবিদের জীবনী card (marked "খসড়া")

কুরআন
├─ Search box (সূরা, নম্বর, "২:২৫৫", যেকোনো শব্দ)
├─ Labelled buttons (icon + text): [বুকমার্ক] [পড়ার সেটিং] [ডাউনলোড]
├─ কুরআন পড়া চালিয়ে যান
└─ সূরা | পারা lists → reader

নামাজ
├─ Big next prayer + countdown, location (tap to change)
├─ Today's times: ফজর, সূর্যোদয়, যোহর, আসর, মাগরিব, এশা
├─ Big card: কিবলা দেখুন → compass screen
└─ Button: আজান সেটিংস → opens the one সেটিংস page at "আজান ও নামাজ"

দোয়া
├─ Search box (ভয়, ঋণ, সফর, অসুস্থ…)
├─ সকাল/সন্ধ্যার জিকির card
├─ Big card: তাসবিহ → new tasbih screen
├─ Labelled buttons: [প্রিয় দোয়া] [দোয়ার সেটিং]
└─ Dua sections by topic

আরও
├─ ফিচার
│    সাহাবিদের জীবনী · সহজ আরবি · মন কেমন? · বিষয়
│    কিবলা · তাসবিহ · প্রিয়
├─ সেটিংস
│    ⚙ সব সেটিংস (one page)
│    অনুমতি ও সেটআপ (রিমাইন্ডার না এলে)
└─ অ্যাপ সম্পর্কে
     ডেভেলপার সম্পর্কে · কৃতজ্ঞতা ও উৎস · গোপনীয়তা নীতি · অ্যাপ শেয়ার করুন
```

### New / merged screens

**প্রিয় (one place for everything saved)** — one screen with 3 tabs at the top:
`আয়াত ও হাদিস | দোয়া | কুরআন বুকমার্ক`. Opened from the Home top bar, the Home grid,
আরও, and the old "প্রিয় দোয়া" / Quran bookmark buttons (they open the right tab).
Nothing saved is lost; the data stays exactly where it is now.

**সেটিংস (one page)** — one scrolling page with headings and a row of jump chips at the top:
1. রিমাইন্ডার (সকাল ও রাতের সময়, শব্দ, পরীক্ষামূলক রিমাইন্ডার)
2. আজান ও নামাজ (আজান চালু/বন্ধ, হিসাবের পদ্ধতি, আসর, সাইলেন্ট মোডে আজান, পুরো স্ক্রিনে আজান, আজান শুনে দেখুন, এলাকা)
3. কুরআন পড়া (অনুবাদ, আরবির আকার, বাংলার আকার)
4. অডিও ও ক্বারী
5. দোয়া
6. লেখার আকার ও ডার্ক মোড
7. ডাউনলোড ও জায়গা
8. অনুমতি ও সেটআপ

The settings buttons on Quran, Prayer and Dua screens stay as shortcuts, but they all
open this same page at the right heading. The quick text-size slider in the reader stays
(it changes the same setting).

**তাসবিহ (new)** — big round tap area (the whole lower screen), large Bangla count,
choice of zikr (সুবহানাল্লাহ, আলহামদুলিল্লাহ, আল্লাহু আকবার, লা ইলাহা ইল্লাল্লাহ,
আস্তাগফিরুল্লাহ, or "শুধু গণনা"), target 33 / 99 / 100 / none, a short vibration at the
target, reset button, and the count is remembered if you leave the screen. Arabic text
shown with Bangla pronunciation and meaning. No new packages needed.

**খুঁজুন (app search, new)** — one search box on Home that looks through: surah names,
ayahs, duas, moods, topics and feature names (e.g. typing "কিবলা" shows the Qibla
screen). It reuses the Quran and Dua search that already exist.

## Taps from Home after the change

| Feature | Taps | Path |
|---|---|---|
| Today's ayah, hadith, next prayer | 0 | Home |
| Prayer times | 1 | নামাজ tab or Home grid |
| Qibla | 1 | Home grid (2 via নামাজ) |
| Tasbih | 1 | Home grid (2 via দোয়া) |
| Duas / adhkar | 1 | দোয়া tab |
| A mood | 1 | mood chip on Home |
| A topic (বিষয়) | 1 | topic chip on Home (2 via "সব বিষয়") |
| Full Quran | 1 | কুরআন tab |
| Quran bookmarks / downloads | 2 | কুরআন → labelled button |
| প্রিয় (all saved items) | 1 | Home top bar or grid |
| Search | 1 | Home top bar |
| Settings (all) | 1 | Home top bar ⚙ (2 via আরও) |
| Sahaba stories | 1 | Home card (2 via আরও) |
| সহজ আরবি | 1 | Home card (2 via আরও) |
| About / Credits / Privacy | 2 | আরও → row |

Everything is 2 taps or fewer.

## Design rules (applied to every screen)

| Thing | Rule |
|---|---|
| Colours | Only from the theme (`context.palette`). Remove the ~14 hard-coded colours. Check every screen in light and dark. |
| Bangla text | Body 16, small text minimum **14**, titles 22–26. Font: Hind Siliguri. Line height 1.5. |
| Arabic text | Cards 26+, reader 28+ by default, Amiri Quran, right-to-left, line height 1.8+. |
| Tap targets | Minimum **48×48**. Remove `VisualDensity.compact`. Shortcut grid max 3 per row. |
| Spacing | One scale: 4 · 8 · 12 · 16 · 24. Page side padding 16. |
| Corners | The existing small/large radius values only. |
| Labels | Every menu item: icon + Bangla text. No icon-only buttons except the standard back arrow and play/pause. |
| Language | "আপনি" form everywhere (e.g. "আপনার মন এখন কেমন?"). |

## Must keep working (checked in Phase 3)
- Scheduled ayah reminders (morning/night) and full-screen alarm reminders.
- Opening the reading screen from a reminder, the prayer screen from an azan, and the
  adhkar counter from the adhkar notification.
- Azan audio, silent-mode azan, full-screen azan.
- Notifications and all permission flows (setup screen and banner).
- Quran, ayah, hadith, dua and story audio playback, including background playback.
- Saved favourites, bookmarks, reading position, settings (no data reset).
- Package name stays `com.ayahreminder.ayah_reminder`.

## Phase 3 steps (after approval)
1. New branch from the current code, e.g. `claude/ux-navigation-redesign`.
2. Theme clean-up: text size floor, tap sizes, remove hard-coded colours, "আপনি".
3. New tabs (আজ · কুরআন · নামাজ · দোয়া · আরও) and the new Home layout.
4. New screens: তাসবিহ, merged প্রিয়, single সেটিংস page, app search.
5. Quran labelled buttons; Prayer tab with Qibla card; new আরও layout.
6. Update and add tests (tabs, Home, tasbih, প্রিয়, settings page, notification links).
7. Run `flutter analyze` and `flutter test`, fix everything, then open a PR for review.
