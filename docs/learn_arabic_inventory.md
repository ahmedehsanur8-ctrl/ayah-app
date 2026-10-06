# কুরআন বুঝি: Phase 0 inventory

Answers to the Part B "Phase 0" checklist in `docs/learn_arabic_spec.md`. No feature
code was written for this. Inspected on branch `claude/learn-quran-arabic`, which starts
from `claude/ux-navigation-redesign` (PR #23, the new navigation, not merged yet).

## 1. Flutter / Dart versions, Android minSdk

| Item | Value | Where |
|---|---|---|
| Dart SDK constraint | `^3.13.4` | `pubspec.yaml` |
| App version | `1.0.71+71` | `pubspec.yaml` |
| Flutter used to build | latest `stable` channel (CI); checked locally with Flutter 3.47.6 / Dart 3.13.5 | `.github/workflows/build-apk.yml` (`subosito/flutter-action`, `channel: stable`) |
| Android minSdk / targetSdk | Flutter defaults (`flutter.minSdkVersion`, `flutter.targetSdkVersion`) | `android/app/build.gradle.kts` lines 27–28 |
| compileSdk | `max(flutter.compileSdkVersion, 36)` | `android/app/build.gradle.kts` line 14 |
| Package name | `com.ayahreminder.ayah_reminder` | `android/app/build.gradle.kts` line 24 |

## 2. Folder architecture and state management

- **Layer-first, not feature-first:** `lib/screens/` (one file per screen or screen
  family), `lib/widgets/`, `lib/services/` (logic + storage), `lib/models/`, `lib/utils/`.
  Entry: `lib/main.dart`; app-wide singletons: `lib/app_state.dart`.
- **State management: no package.** The app uses plain Flutter:
  - `ChangeNotifier` singletons for shared state: `AppSettings`, `QuranPrefs`
    (`lib/services/settings.dart`), `AudioController` (`lib/services/audio.dart`),
    `QuranPlayer` (`lib/services/quran_player.dart`), `ArabicProgress`
    (`lib/services/arabic.dart`).
  - Widgets listen with `ListenableBuilder` / `ValueListenableBuilder`; local state uses
    `StatefulWidget` + `setState`.
  - Global access through `AppState.instance` (`lib/app_state.dart`), loaded once in `main()`.
  - **The new feature will follow the same pattern:** `ChangeNotifier` services plus
    `ListenableBuilder`, no Provider, Riverpod, Bloc or GetX.

## 3. Router and bottom navigation

- **Router: Navigator 1.0, no named routes.** Pages are opened with the helper
  `push(context, page)` → `MaterialPageRoute` (`lib/widgets/ui.dart`, bottom of file).
  Notification taps use a global `navigatorKey` (`lib/main.dart`). No go_router or auto_route.
- **Bottom nav:** `NavigationBar` in `lib/screens/home_shell.dart`, **5 items**:
  - on this branch / PR #23: আজ · কুরআন · দোয়া · মন · জীবনী
  - on `main` today: আজ · কুরআন · মন · জীবনী · আরও
  - Tabs are switched with `HomeShell.tab` (a `ValueNotifier<int>`).
- The spec's routes (`/learn`, `/learn/path`, `/learn/lesson/:id` …) will be screen
  classes opened with `push(...)`, one class per route, because the app has no URL router.
  The route names will be kept as constants for reference and future deep links.

## 4. Theme, fonts, reusable widgets

| Item | Where |
|---|---|
| ThemeData | `buildTheme(Brightness)` in `lib/theme.dart`; light + dark, `themeMode` from settings (`lib/main.dart`) |
| Colours | `Brand` (fixed brand colours) and `Palette` (light/dark, used as `context.palette`) in `lib/theme.dart` |
| Arabic font | **Amiri Quran**, `arabicFont = 'AmiriQuran'` (`lib/theme.dart`), file `assets/fonts/AmiriQuran-Regular.ttf` |
| Bangla font | **Hind Siliguri** (`banglaFont`), titles **Noto Serif Bengali** (`titleFont`), fallback Noto Sans Bengali (`lib/theme.dart`) |
| Arabic / Bangla text widgets | `ArabicText`, `BanglaText` in `lib/widgets/item_view.dart` (RTL, user text scale) |
| Cards, rows, buttons | `AppCard`, `PageTitle`, `SectionLabel`, `IconBubble`, `GridTile3`, `NavRow`, `RowGroup`, `InfoPill`, `LabeledAction`, `ActionRow` in `lib/widgets/ui.dart` |
| Audio button | `AudioButton`, `ItemAudioButton` in `lib/widgets/audio_button.dart` |
| Decorative pattern | `PatternLayer` in `lib/widgets/pattern.dart` |
| Sizes | `radiusM`, `radiusL`, `titleStyle(...)` in `lib/theme.dart` |

## 5. Local storage

- **Only `shared_preferences`.** There is **no SQLite, drift, isar or hive** and no
  database, tables or migrations of any kind (`pubspec.yaml`).
- Keys live in `AppSettings` / `QuranPrefs` (`lib/services/settings.dart`) and
  `ArabicProgress` (`lib/services/arabic.dart`).
- Large read-only data is bundled as JSON / gzip assets: `assets/content.json`,
  `assets/duas.json`, `assets/stories.json`, `assets/quran/*`, `assets/arabic/*.json`.
- **Consequence:** the spec's "user DB (existing app DB, new tables via migration)" has no
  existing DB to extend. Plan: a new SQLite file `learn_user.db` in the app documents
  folder, created by the SQLite package's versioned `onCreate`/`onUpgrade` (version 1 =
  the four `learn_*` tables). The bundled `assets/learn/learn_content.db` is copied to
  the app folder on first run and whenever its `content_version` changes, then opened
  read-only.

## 6. How ayahs are stored, Quran text source and licence

- **Per ayah, not per word.** `assets/quran/arabic.txt.gz` has 6,236 lines, one ayah per
  line, **Tanzil Uthmani** (downloaded with `marks=true&sajdah=true&tatweel=true`) by
  `tools/fetch_quran.py`. Loaded by `Quran` in `lib/services/quran.dart`.
- Things the word alignment in Phase 1 must handle:
  - Tanzil puts the basmala in front of ayah 1 of most surahs. `Quran.basmala` and
    `Quran.displayArabic` deal with it for display.
  - Waqf (pause) marks such as `ۚ` are separate space-separated tokens with `marks=true`.
  - The text keeps tatweel (for example `ٱلرَّحْمَـٰنِ`).
- **Reminder ayahs** are separate: `assets/content.json` (built by `tools/fetch_content.py`)
  holds each item's Arabic as one string. An item can cover a range (`surah`,
  `ayahStart`, `ayahEnd` in `ContentItem`, `lib/models/content.dart`), and some are whole
  surahs (`fullSurah`).
- **Tanzil licence notice:** kept verbatim and shown in the credits screen
  `lib/screens/credits_screen.dart` (lines 37–46: "Tanzil Quran Text (Uthmani…) —
  Copyright © Tanzil Project. License: Creative Commons Attribution 3.0", plus the full
  header from `assets/quran/meta.json`).
- **Already in the repo:** `tools/quran_word_frequency.py` reads **Quranic Arabic Corpus
  morphology v0.4** from a verbatim GitHub mirror (CLTK), checks its SHA-256, and wrote
  `assets/arabic/level2_words.json` + `docs/LEVEL2_WORDS.md`: the top 300 lemmas (77,429
  words, 4,832 lemmas; the top 300 cover 70.97% of the text). Bangla meanings are empty.
  Phase 1 can reuse its download, checksum and Buckwalter → Arabic code.

## 7. Audio

- **Packages:** `just_audio` + `just_audio_background` (background playback with a
  notification), `flutter_tts` (phone's Bangla voice only).
- **Recitation source:** EveryAyah.com MP3s per ayah (reciters Alafasy, Abdul Basit
  Murattal, Husary), streamed and cached with `LockCachingAudioSource`
  (`lib/services/audio.dart` around line 90; full-surah player and downloads in
  `lib/services/quran_player.dart`). Credited in `lib/screens/credits_screen.dart`
  (line 98).
- The spec's "King Fahd Complex" grant is not what the app uses. Ayah audio will reuse
  EveryAyah as the spec says ("reuse whatever source the app already plays").
- **Word audio:** no word-level audio exists. The spec's option B, streaming from
  audio.qurancdn.com and caching it, is new.

## 8. Notifications and the full-screen reminder

- **Scheduling:** native Android alarms in
  `android/app/src/main/kotlin/.../Reminder.kt` (`ReminderAlarmReceiver`, foreground
  `ReminderService` with the full-screen intent), azan in `Azan.kt`, bridge in
  `MainActivity.kt`. Dart side: `lib/services/reminders.dart` (`Reminders`, plus
  `flutter_local_notifications` for older reminders and adhkar).
- **The screen that renders the reminder ayah:** `ReadingScreen` in
  `lib/screens/reading_screen.dart` (12-second countdown, "আমি পড়েছি"). It draws the ayah
  with `ItemBody(widget.item)` (`lib/widgets/item_view.dart`, class `ItemBody`), which
  shows the Arabic, then the Bangla meaning (`BanglaText(item.bangla)`), then the reference.
- `main.dart` opens `ReadingScreen` directly when the app is launched by a reminder.
- Phase 4's single "এই আয়াত বুঝুন" button goes right under the Bangla meaning on
  `ReadingScreen` only, with no other changes to that screen.

## 9. Bookmarks, favourites, progress, settings

All in `shared_preferences`:

| Item | Where |
|---|---|
| Ayah/hadith favourites | `favorites` |
| Dua favourites | `duaFavorites` |
| Quran bookmarks | `QuranPrefs.bookmarks` |
| Quran reading position | `lastSurah` / `lastAyah` |
| "Read" marks | `readMarks` |
| Settings | reminder times, audio, text size, theme, etc. in `AppSettings` |
| Tasbih count | `tasbihCount` |
| সহজ আরবি progress | `ArabicProgress` (stars, streak, review) in `lib/services/arabic.dart` |

## 10. Analytics, auth

- **No analytics SDK** (no Firebase, Sentry or similar). Following the spec, learning
  events will only be counted locally.
- **No accounts, login or user profile.** As the spec says, **no `userId` column**.

## 11. Localization

- **Hard-coded Bangla strings** in the widgets. No `intl`, no ARB files, no
  `flutter_localizations`. Digits are converted with `toBanglaDigits`
  (`lib/models/content.dart`) and dates with `lib/utils/bangla.dart`.
- The new feature will do the same: Bangla strings in code, Bangla digits in the UI.

## 12. Tests and checks

- `flutter analyze` and `flutter test` (81 tests on this branch) run in CI before every
  build (`.github/workflows/build-apk.yml`).
- Code is formatted with `dart format -l 100`.
- Widget tests load the real fonts (`test/screens_test.dart`) and run in light and dark.

## Decisions for the feature (to confirm)

1. **Navigation (spec rule):** the bottom bar already has 5 items, so there is **no new
   tab**. "কুরআন বুঝি" gets:
   - a large card on the আজ (Home) screen, next to the সহজ আরবি card;
   - an entry in the one সেটিংস page (a "শিখুন" heading with learning mode, daily goal
     and a link to the dashboard), because the app has no drawer;
   - the "এই আয়াত বুঝুন" button on the reminder screen (Phase 4).
2. **New packages (2):**
   - `fsrs` 2.0.1: FSRS scheduler, MIT licence, pure Dart, needs Dart ≥ 3.3.
   - `sqflite` 2.4.4: SQLite for the bundled content DB and the user DB, because the app
     has no database. Needs Flutter ≥ 3.44, which CI's stable channel meets.
   - **Question:** to test the database code in `flutter test` (which runs on the
     computer, not a phone), `sqflite_common_ffi` is needed as a **dev-only** package. It
     is never shipped in the APK. Without it, the database code can only be tested on a
     phone.
3. **Arabic only from Tanzil.**
   - Every Arabic word shown comes from the Tanzil text, by `quran_word` id.
   - The QAC lemma spelling (rebuilt from Buckwalter) is stored for matching and search
     only. The UI shows a lemma through a real Tanzil word form, such as the word in the
     lesson's anchor ayah.
4. **Overlap with সহজ আরবি.** The app already has সহজ আরবি (learn to read: letters,
   marks, tajweed; Level 1 has 22 lessons). Its Level 2 "কুরআনের শব্দ" is shown as
   "শীঘ্রই আসছে", and its word list was already generated from QAC. কুরআন বুঝি covers
   the same ground ("understand the words"). Without touching সহজ আরবি, the two would
   sit side by side. **Question:** should the সহজ আরবি "Level 2 শীঘ্রই আসছে" card later
   point to কুরআন বুঝি? That would change an existing feature, so only on your OK.
5. **Reminder ayahs that cover a range or a whole surah:** "এই আয়াত বুঝুন" opens the
   first ayah of the range, with আগের/পরের buttons for the rest of the range.
6. **Base branch:** this work builds on PR #23 (the new Home). If PR #23 changes, this
   branch will be updated from it.
