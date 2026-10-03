import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app_state.dart';
import 'screens/dua_screens.dart';
import 'screens/home_shell.dart';
import 'screens/prayer_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/duas.dart';
import 'services/location.dart';
import 'services/planner.dart';
import 'services/prayer.dart';
import 'services/quran.dart';
import 'services/reminders.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Recitation keeps playing with the screen off, with controls in the notification.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ayahreminder.audio',
      androidNotificationChannelName: 'তিলাওয়াত',
      androidNotificationChannelDescription: 'কুরআন তিলাওয়াত ও অডিও চলার সময়',
      androidNotificationIcon: 'drawable/ic_notification',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('background audio: $e');
  }
  final state = await AppState.load();
  await Quran.loadMeta();
  await Duas.load();
  await Prayers.loadAzanInfo();
  await Reminders.init(_openFromReminder, onAzan: _openPrayerTimes, onAdhkar: _openAdhkar);
  // Opened by a reminder alarm (native) or an older reminder notification.
  final launch = await Reminders.nativeLaunchPayload() ?? await Reminders.launchPayload();
  Reminders.listen(_openFromReminder);
  final fromAzan = await Reminders.launchedFromAzan();
  final fromAdhkar = await Reminders.launchedFromAdhkar();
  runApp(AyahReminderApp(launch: launch));
  if (fromAzan) WidgetsBinding.instance.addPostFrameCallback((_) => _openPrayerTimes());
  if (fromAdhkar != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAdhkar(fromAdhkar == 'evening'));
  }
  // Update the location if the phone moved, then plan every alarm (reminders,
  // azan, sehri/iftar, adhkar) for the next weeks.
  _planAll(state);
}

Future<void> _planAll(AppState state) async {
  await LocationService.refreshIfMoved(state.settings);
  await Planner.planAll(state.settings, state.data);
}

/// Run by Android without opening the app (an alarm rang, the phone restarted,
/// or the daily check) to top up the alarms: see Planner.kt.
@pragma('vm:entry-point')
Future<void> backgroundTopUp() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await Planner.topUp();
  } catch (e) {
    debugPrint('background planning failed: $e');
  } finally {
    await Planner.done();
  }
}

/// The morning / evening adhkar notification was tapped.
void _openAdhkar(bool evening) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => DuaCounterScreen.adhkar(evening: evening)),
  );
}

void _openPrayerTimes() {
  navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const PrayerScreen()));
}

/// A reminder was tapped (or shown full screen) while the app was running.
void _openFromReminder(ReminderPayload p) {
  final item = AppState.instance.data.byId(p.itemId);
  if (item == null) return;
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ReadingScreen(item: item, payload: p, fromReminder: true),
    ),
  );
}

class AyahReminderApp extends StatelessWidget {
  const AyahReminderApp({super.key, this.launch});

  final ReminderPayload? launch;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final launchItem = launch == null ? null : state.data.byId(launch!.itemId);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, home) => MaterialApp(
        title: 'Ayah Reminder',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: _light,
        darkTheme: _dark,
        themeMode: state.settings.themeMode,
        home: home,
      ),
      child: launchItem != null
          // Opened from a reminder: go straight to the reading screen.
          ? ReadingScreen(item: launchItem, payload: launch, fromReminder: true)
          : SplashScreen(
              next: state.settings.setupDone ? const HomeShell() : const OnboardingScreen(),
            ),
    );
  }
}

final _light = buildTheme(Brightness.light);
final _dark = buildTheme(Brightness.dark);
