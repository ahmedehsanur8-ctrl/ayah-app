import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_shell.dart';
import 'screens/prayer_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/splash_screen.dart';
import 'services/location.dart';
import 'services/prayer.dart';
import 'services/reminders.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  await Prayers.loadAzanInfo();
  await Reminders.init(_openFromReminder, onAzan: _openPrayerTimes);
  final launch = await Reminders.launchPayload();
  final fromAzan = await Reminders.launchedFromAzan();
  runApp(AyahReminderApp(launch: launch));
  if (fromAzan) WidgetsBinding.instance.addPostFrameCallback((_) => _openPrayerTimes());
  if (state.settings.setupDone) {
    // Plan the next days of reminders every time the app starts.
    Reminders.reschedule(state.settings, state.data);
  }
  // Prayer times: update the location if the phone moved, then plan the azan
  // for the next days (so times are recalculated at least every app start).
  _refreshPrayerTimes(state);
}

Future<void> _refreshPrayerTimes(AppState state) async {
  await LocationService.refreshIfMoved(state.settings);
  await Prayers.schedule(state.settings);
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
              next: state.settings.setupDone
                  ? const HomeShell()
                  : const SetupScreen(firstTime: true),
            ),
    );
  }
}

final _light = buildTheme(Brightness.light);
final _dark = buildTheme(Brightness.dark);
