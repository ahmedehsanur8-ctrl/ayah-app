# Ayah Reminder: UX audit (Phase 1)

Date: 2026-10-01. App version audited: 1.0.71+71. No code was changed during this audit.

The problem we are solving: users find it hard to find features. The app has grown
(daily ayah, hadith, mood, categories, full Quran, prayer times and azan, Qibla, duas,
adhkar, Sahaba stories, Arabic lessons, audio, settings, About) but the screens were
not reorganised as it grew.

## Current navigation

Bottom tabs today: **আজ · কুরআন · মন · জীবনী · আরও**

## 1. Where every feature lives today

"Taps" is counted from the first screen (আজ). 0 = visible straight away.

| Feature | Where it is now | Taps |
|---|---|---|
| Today's ayah | আজ tab, top card | 0 |
| Next prayer countdown | আজ tab, thin strip | 0 |
| Today's hadith | আজ tab, at the very bottom of a long scroll | 0 (lots of scrolling) |
| Morning/evening adhkar (zikr counter) | আজ tab, a card in the middle | 1 |
| Full Quran (114 surahs, para) | কুরআন tab | 1 |
| Quran search | কুরআন tab, search box | 1 |
| Quran bookmarks / downloads / reading settings | কুরআন tab, 3 small icons with no text | 2 |
| Mood (মন কেমন?) | মন tab | 1 |
| Categories (বিষয়) | মন tab, then a switch at the top | 2 (easy to miss) |
| Sahaba stories + audio | জীবনী tab | 1 (2 to play) |
| Prayer times + azan settings | আরও → নামাজের সময় (or the strip on আজ) | 1–2 |
| Qibla compass | আরও → কিবলা (also a button on আজ) | 1–2 |
| Saved ayahs/hadith (প্রিয়) | আরও → প্রিয় (also a button on আজ) | 1–2 |
| Duas | আরও → দোয়া | 2 |
| Saved duas | আরও → দোয়া → small heart icon | 3 |
| Tasbih | No standalone tasbih. The counter only exists inside adhkar and duas | 3+ |
| Learn Arabic (সহজ আরবি) | আরও → card | 2 |
| Reminder times | আরও → রিমাইন্ডার | 2 |
| Audio and reciter (ক্বারী) | আরও → অডিও ও ক্বারী | 2 |
| Text size and dark mode | আরও → লেখার আকার | 2 |
| Permissions and test reminder | আরও → অনুমতি ও সেটআপ | 2 |
| About / Credits | আরও → … | 2 |
| Privacy policy | আরও → ডেভেলপার সম্পর্কে → … | 3 |

Note: সহজ আরবি (Arabic lessons) exists in the app but is tucked away under আরও.

## 2. Biggest problems

### Hard to find
1. **Prayer times has no tab.** It is probably the most-used daily feature for
   Bangladeshi users, but it sits under "আরও", where people rarely look for main features.
2. **Duas are hidden** under আরও, while **জীবনী** (stories still marked as drafts)
   has a whole tab.
3. **বিষয় (categories) is hidden** behind a small switch inside the মন tab.
4. **"আরও" mixes main features** (prayer, Qibla, duas, Arabic) with settings and About.
5. **No standalone tasbih** for simple counting.
6. **Today's hadith is at the bottom** of আজ, below about 5 other cards.

### Confusing
7. **Settings are spread over 5 places:** আরও (3 sections), Prayer screen (azan),
   Quran tab (reading settings sheet), Dua screen (dua settings sheet), and the reader.
   Text size can be changed in 3 places.
8. **Saved items live in 3 places:** প্রিয় (ayahs/hadith), প্রিয় দোয়া, Quran bookmarks.
9. **Icon-only buttons** on the Quran page (bookmark, "Aa", download). The meaning only
   shows on a long press.
10. **Search only works inside Quran and Duas.** There is no app-wide search.
11. **The app switches between "তোমার" and "আপনি".** The মন page uses the casual form;
    the rest uses the polite form.

### Readability and touch
12. **About 57 places use Bangla text at 12px or smaller.** Bangla conjunct letters need
    about 14px to read comfortably, especially for older users.
    Most in: dua_screens (11), stories_screen (7), reader_screen (6), arabic_screens (6),
    today_screen (5).
13. **Small tap targets:** 3 places use `VisualDensity.compact` (setup_screen,
    quran_screen, quran_reader_screen). The 4 tiles in a row on আরও are cramped on small
    phones and "নামাজের সময়" wraps.
14. **About 14 hard-coded colours** (`Color(0x…)`) outside the theme, 4 of them in
    qibla_screen. Dark mode may look wrong there.

## What is already good
- One central theme (`lib/theme.dart`): green and gold palette, Hind Siliguri for Bangla,
  Amiri Quran for Arabic.
- Light and dark mode both exist.
- Almost all labels are already in Bangla.
- Arabic on the Today card is a good size (26).

So the fix is mostly a **reorganisation**, not a full redesign.
