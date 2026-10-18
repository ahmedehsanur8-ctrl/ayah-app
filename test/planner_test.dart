import 'dart:convert';
import 'dart:io';

import 'package:ayah_reminder/models/content.dart';
import 'package:ayah_reminder/services/duas.dart';
import 'package:ayah_reminder/services/planner.dart';
import 'package:ayah_reminder/services/prayer.dart';
import 'package:ayah_reminder/services/reminders.dart';
import 'package:ayah_reminder/services/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The alarms must never run out, even if the app is not opened for months:
/// Android tops up the plan (Planner.kt → backgroundTopUp) when an alarm rings,
/// after a restart and once a day, whenever Planner.refreshAt has passed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = ContentData.fromJson(
    jsonDecode(File('assets/content.json').readAsStringSync()) as Map<String, dynamic>,
  );
  const minDays = Duration(days: Planner.minDays);
  const minAdhkar = Duration(days: Planner.minAdhkarDays);

  setUpAll(Reminders.initTimeZone);

  Future<AppSettings> settings() async {
    SharedPreferences.setMockInitialValues({'setupDone': true});
    final s = await AppSettings.load();
    await s.setLocation(23.8103, 90.4125, 'ঢাকা', 'city');
    await s.setAdhkarMorning(true);
    await s.setAdhkarEvening(true);
    await s.setSehriAlarm(45);
    await s.setIftarNotify(true);
    Prayers.azanBundled = true;
    return s;
  }

  List<int> times(String json) => [
    for (final e in (jsonDecode(json) as List).cast<Map<String, dynamic>>()) e['t'] as int,
  ];

  test('planning sends 30+ days of reminders and azan, and when to top up', () async {
    final s = await settings();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final sent = <String, Map<Object?, Object?>>{};
    for (final name in ['reminder', 'azan', 'planner']) {
      messenger.setMockMethodCallHandler(MethodChannel('ayah_reminder/$name'), (call) async {
        sent['$name.${call.method}'] = (call.arguments as Map?) ?? const {};
        return true;
      });
    }
    addTearDown(() {
      for (final name in ['reminder', 'azan', 'planner']) {
        messenger.setMockMethodCallHandler(MethodChannel('ayah_reminder/$name'), null);
      }
    });

    final before = DateTime.now();
    await Planner.planAll(s, data);
    final after = DateTime.now();

    for (final channel in ['reminder', 'azan']) {
      final t = times(sent['$channel.schedule']!['events']! as String);
      expect(t, isNotEmpty, reason: channel);
      final last = DateTime.fromMillisecondsSinceEpoch(t.last);
      expect(last.difference(after) >= minDays, isTrue, reason: '$channel ends $last');
    }
    final planned = sent['planner.planned']!;
    final refreshAt = DateTime.fromMillisecondsSinceEpoch(planned['refreshAt']! as int);
    expect(refreshAt.isAfter(before), isTrue);
    expect(
      refreshAt.isBefore(after.add(const Duration(days: Planner.refreshAfterDays + 1))),
      isTrue,
    );
  });

  test('the plan never runs out during 200 days without opening the app', () async {
    final s = await settings();
    // Fajr just ahead, and a time late at night (the worst for "the last
    // planned day ends early").
    for (final start in [DateTime(2026, 2, 10, 0, 5), DateTime(2026, 2, 10, 23, 55)]) {
      late DateTime refreshAt;
      late DateTime reminderEnd, azanEnd, adhkarEnd;
      var plans = 0;
      void plan(DateTime now) {
        plans++;
        refreshAt = Planner.refreshAt(now);
        final r = Reminders.events(s, data, now: now);
        reminderEnd = DateTime.fromMillisecondsSinceEpoch(r.last['t']! as int);
        azanEnd = DateTime.fromMillisecondsSinceEpoch(times(Prayers.eventsJson(s, now)).last);
        adhkarEnd = AdhkarReminders.plan(s, now).last.at;
      }

      plan(start); // the last time the app was opened
      // Only the daily check tops up (the worst case: no alarm rings meanwhile),
      // and it may come up to a day late.
      var nextCheck = start.add(const Duration(days: 1, hours: 23));
      for (var t = start; t.isBefore(start.add(const Duration(days: 200)));) {
        t = t.add(const Duration(hours: 1));
        if (!t.isBefore(nextCheck)) {
          if (!t.isBefore(refreshAt)) plan(t);
          nextCheck = t.add(const Duration(days: 1, hours: 23));
        }
        final at = '$t (start $start)';
        expect(reminderEnd.difference(t) >= minDays, isTrue, reason: 'reminders, $at');
        expect(azanEnd.difference(t) >= minDays, isTrue, reason: 'azan, $at');
        expect(adhkarEnd.difference(t) >= minAdhkar, isTrue, reason: 'adhkar, $at');
      }
      expect(plans, greaterThan(200 ~/ (Planner.refreshAfterDays + 2)));
    }
  });

  test('sehri alarms are planned 30+ days ahead in Ramadan', () async {
    final s = await settings();
    // 2027 Ramadan starts around 8 February.
    final now = DateTime(2027, 1, 15, 22);
    final sehri = [
      for (final e in (jsonDecode(Prayers.eventsJson(s, now)) as List).cast<Map<String, dynamic>>())
        if (e['mode'] == 'sehri') DateTime.fromMillisecondsSinceEpoch(e['t'] as int),
    ];
    expect(sehri, isNotEmpty);
    expect(sehri.last.difference(now) >= minDays, isTrue, reason: '${sehri.last}');
  });

  test('top-up margins add up', () {
    expect(Planner.refreshAfterDays, greaterThan(0));
    expect(Planner.planDays - Planner.refreshAfterDays - 2, greaterThanOrEqualTo(Planner.minDays));
    expect(AdhkarReminders.days - Planner.refreshAfterDays - 3, greaterThan(Planner.minAdhkarDays));
  });
}
