import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_shell.dart';
import 'screens/reading_screen.dart';
import 'screens/setup_screen.dart';
import 'services/reminders.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  await Reminders.init(_openFromReminder);
  final launch = await Reminders.launchPayload();
  runApp(AyahReminderApp(launch: launch));
  if (state.settings.setupDone) {
    // Plan the next days of reminders every time the app starts.
    Reminders.reschedule(state.settings, state.data);
  }
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
    return MaterialApp(
      title: 'Ayah Reminder',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: launchItem != null
          ? ReadingScreen(item: launchItem, payload: launch, fromReminder: true)
          : state.settings.setupDone
          ? const HomeShell()
          : const SetupScreen(firstTime: true),
    );
  }
}
