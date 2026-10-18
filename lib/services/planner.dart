import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/content.dart';
import 'duas.dart';
import 'prayer.dart';
import 'reminders.dart';
import 'settings.dart';

/// Plans every alarm in one place: the ayah/hadith reminders, the azan with its
/// reminders, sehri/iftar, and the adhkar notifications.
///
/// It runs when the app opens, and also without opening the app: Android runs
/// it in the background when an alarm rings, after a restart, and once a day
/// (Planner.kt), whenever [refreshAt] has passed. So the alarms never run out,
/// even if the app is not opened for months.
class Planner {
  Planner._();

  /// Days planned each time (reminders, azan, sehri/iftar).
  static const planDays = 35;

  /// At least this many days are always planned ahead.
  static const minDays = 30;

  /// Adhkar notifications always reach at least this far ahead.
  static const minAdhkarDays = 14;

  /// Days after planning when the plan is topped up. The other 2 of the 5
  /// spare days cover the last planned day ending early (its alarms are at set
  /// times of day) and Android's daily check coming up to a day late.
  static const refreshAfterDays = planDays - minDays - 2;

  /// When the plan must be topped up.
  static DateTime refreshAt(DateTime now) => now.add(const Duration(days: refreshAfterDays));

  static const _channel = MethodChannel('ayah_reminder/planner');

  /// Plans everything from [now] and tells Android when to plan again.
  static Future<void> planAll(AppSettings s, ContentData data) async {
    final now = DateTime.now();
    if (s.setupDone) await Reminders.reschedule(s, data);
    // Azan, sehri/iftar and (inside it) the adhkar notifications.
    await Prayers.schedule(s);
    try {
      await _channel.invokeMethod('planned', {
        'refreshAt': refreshAt(now).millisecondsSinceEpoch,
        'until': now.add(const Duration(days: planDays)).millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // Tests / non-Android.
    } on PlatformException catch (e) {
      debugPrint('planner: $e');
    }
  }

  /// The work of the background run (see backgroundTopUp in main.dart).
  static Future<void> topUp() async {
    await Reminders.initTimeZone();
    await Reminders.initPlugin();
    final s = await AppSettings.load();
    final data = await ContentData.load();
    await Duas.load();
    await Prayers.loadAzanInfo();
    await planAll(s, data);
  }

  /// Tells Android the background run is over.
  static Future<void> done() async {
    try {
      await _channel.invokeMethod('done');
    } on MissingPluginException {
      // Tests / non-Android.
    }
  }
}
