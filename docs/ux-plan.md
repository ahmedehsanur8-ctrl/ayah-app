# Ayah Reminder: new navigation plan (Phase 2)

Date: 2026-10-01. Based on `docs/ux-audit.md`. Status: **approved (option A)** and built in Phase 3 (branch `claude/ux-navigation-redesign`).

## Goals
- Every feature is at most **2 taps from আজ (Home)**.
- Main features live in tabs or on Home. Settings live in **one** place.
- All saved items live in **one** প্রিয় place.
- Bangla labels with an icon on every menu item. "আপনি" everywhere.
- Bangla text at least 14px, buttons at least 48×48, colours only from the theme.

## Bottom tabs (5) — approved: option A

```
┌────────┬─────────┬─────────┬─────────┬─────────┐
│  আজ    │  কুরআন  │  দোয়া   │   মন    │  জীবনী  │
│ (sun)  │ (book)  │ (hands) │ (smile) │ (book)  │
└────────┴─────────┴─────────┴─────────┴─────────┘
```

| Before | After | Why |
|---|---|---|
| আজ | **আজ** | Today's ayah first. Prayer, Qibla, tasbih, প্রিয়, search and settings are reached from here. |
| কুরআন | **কুরআন** | Stays. |
| মন (with a hidden বিষয় switch) | **দোয়া** (new) | Duas, adhkar and the new tasbih together. |
| জীবনী | **মন** | Moods and বিষয় on one page: moods at the top, all topics below. No switch. |
| আরও | **জীবনী** | Kept as a tab (owner's choice); marked as draft. |

There is no "আরও" tab any more. Prayer times and Qibla are a big card near the top of
Home (1 tap). Settings, প্রিয় and search are labelled buttons at the top of Home (1 tap).
About, credits, privacy and share live at the bottom of the one সেটিংস page (2 taps).

## Full map

```
আজ (Home)
├─ Top: greeting · Bangla date · reminder time
├─ Labelled buttons: [🔍 খুঁজুন] [♡ প্রিয়] [⚙ সেটিংস]
├─ Setup warning (only if reminders/permissions are broken)
├─ Next prayer card (countdown) ................ → নামাজের সময়
├─ আজকের আয়াত (big green card, শুনুন, আগের/পরের)
├─ আজকের হাদিস  ← moved up, right after the ayah
├─ Shortcut cards (icon + Bangla label): নামাজের সময় · কিবলা · তাসবিহ
├─ সকাল/সন্ধ্যার জিকির card
├─ কুরআন পড়া চালিয়ে যান
└─ সহজ আরবি card

কুরআন
├─ Search box
├─ Labelled buttons: [বুকমার্ক] [পড়ার সেটিং] [ডাউনলোড]
├─ কুরআন পড়া চালিয়ে যান
└─ সূরা | পারা

দোয়া
├─ Search box
├─ সকাল/সন্ধ্যার জিকির card
├─ Big card: তাসবিহ
├─ Labelled buttons: [প্রিয় দোয়া] [দোয়ার সেটিং]
└─ Dua sections by topic

মন
├─ "আপনার মন এখন কেমন?" + 16 moods
└─ বিষয় অনুযায়ী: search + all topics (no switch)

জীবনী
└─ সাহাবিদের জীবনী (unchanged, marked as draft)

নামাজের সময় (from Home)
├─ next prayer, today's times, per-prayer azan choice
├─ Big card: কিবলা দেখুন
└─ Button: আজান সেটিংস → the one সেটিংস page

সেটিংস (one page, from Home)
রিমাইন্ডার · আজান ও নামাজ · কুরআন পড়া · অডিও ও ক্বারী · দোয়া ·
লেখার আকার ও ডার্ক মোড · ডাউনলোড · অনুমতি ও সেটআপ · অ্যাপ সম্পর্কে
```

### New / merged screens

**প্রিয় (one place for everything saved)** — one screen with 3 tabs at the top:
`আয়াত ও হাদিস | দোয়া | কুরআন বুকমার্ক`. Opened from the Home button and the old "প্রিয় দোয়া" / Quran bookmark buttons (they open the right tab).
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
| Prayer times | 1 | Home prayer card / shortcut |
| Qibla | 1 | Home shortcut (2 via prayer times) |
| Tasbih | 1 | Home shortcut (2 via দোয়া) |
| Duas / adhkar | 1 | দোয়া tab |
| Moods and topics | 1 | মন tab |
| Full Quran | 1 | কুরআন tab |
| Quran bookmarks / downloads | 2 | কুরআন → labelled button |
| প্রিয় (all saved items) | 1 | Home button |
| Search | 1 | Home button |
| Settings (all) | 1 | Home button |
| Sahaba stories | 1 | জীবনী tab |
| সহজ আরবি | 1 | Home card |
| About / Credits / Privacy | 2 | সেটিংস → row |

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
1. New branch `claude/ux-navigation-redesign`.
2. Theme clean-up: text size floor, tap sizes, remove hard-coded colours, "আপনি".
3. New tabs (আজ · কুরআন · দোয়া · মন · জীবনী) and the new Home layout.
4. New screens: তাসবিহ, merged প্রিয়, single সেটিংস page, app search.
5. Quran labelled buttons; prayer page with Qibla card.
6. Update and add tests (tabs, Home, tasbih, প্রিয়, settings page, notification links).
7. Run `flutter analyze` and `flutter test`, fix everything, then open a PR for review.

## Notes from building it (Phase 3)
- The Quran tab's "পড়ার সেটিং" button opens the quick sheet (the same controls as
  সেটিংস → কুরআন পড়া), so readers can change size without leaving the Quran. The quick
  text-size control in the reader also stays. All of them change the same saved settings.
- The morning/evening adhkar reminder switches are under সেটিংস → রিমাইন্ডার; the দোয়া
  heading has the উচ্চারণ switch.
- The per-prayer bell (azan / notification / off) stays on the prayer times page, next to each
  prayer. Everything else about azan is on the সেটিংস page.
- "আপনি" wording now also covers the সহজ আরবি lessons, including
  `tools/build_arabic_lessons.py`, so rebuilding the lessons keeps the new wording.
