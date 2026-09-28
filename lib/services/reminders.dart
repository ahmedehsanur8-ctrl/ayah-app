import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/content.dart';
import 'rotation.dart';
import 'settings.dart';

/// What a reminder notification carries, so the app knows what to open.
class ReminderPayload {
  const ReminderPayload(this.slot, this.dateKey, this.itemId);

  /// "morning" or "night".
  final String slot;

  /// yyyy-mm-dd in Dhaka time.
  final String dateKey;
  final String itemId;

  String encode() => '$slot|$dateKey|$itemId';

  static ReminderPayload? decode(String? s) {
    if (s == null) return null;
    final p = s.split('|');
    if (p.length != 3) return null;
    return ReminderPayload(p[0], p[1], p[2]);
  }
}

/// Runs when a notification button (like the azan's "থামান") is pressed
/// while the app is closed. The plugin already removes the notification,
/// which stops its sound, so nothing else is needed.
@pragma('vm:entry-point')
void notificationActionInBackground(NotificationResponse response) {}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Reminders {
  Reminders._();

  static final plugin = FlutterLocalNotificationsPlugin();

  /// How many days ahead reminders are scheduled. They are re-planned every
  /// time the app opens, so this only matters if the app is never opened.
  static const daysAhead = 30;

  static const _channelId = 'ayah_reminder_daily';
  static const _channelName = 'দৈনিক আয়াত ও হাদিস';

  static late tz.Location dhaka;

  static AndroidFlutterLocalNotificationsPlugin? get android {
    try {
      return plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    } catch (_) {
      return null; // Plugin not available (e.g. in tests).
    }
  }

  static Future<void> init(void Function(ReminderPayload) onOpen, {void Function()? onAzan}) async {
    tzdata.initializeTimeZones();
    dhaka = tz.getLocation('Asia/Dhaka');
    tz.setLocalLocation(dhaka);
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (r) {
        if ((r.payload ?? '').startsWith('azan|')) {
          if (r.actionId != 'stop') onAzan?.call();
          return;
        }
        final p = ReminderPayload.decode(r.payload);
        if (p != null) onOpen(p);
      },
      onDidReceiveBackgroundNotificationResponse: notificationActionInBackground,
    );
  }

  /// The azan notification opened the app.
  static Future<bool> launchedFromAzan() async {
    final details = await plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
        (details?.notificationResponse?.payload ?? '').startsWith('azan|');
  }

  /// The reminder that launched the app, if any.
  static Future<ReminderPayload?> launchPayload() async {
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return ReminderPayload.decode(details.notificationResponse?.payload);
  }

  static tz.TZDateTime nowDhaka() => tz.TZDateTime.now(dhaka);

  /// Cancels the reminders and schedules the next [daysAhead] days again.
  /// (Azan notifications are planned separately, see Prayers.schedule.)
  static Future<void> reschedule(AppSettings settings, ContentData data) async {
    for (var i = 0; i <= daysAhead; i++) {
      try {
        await plugin.cancel(id: 1000 + i);
        await plugin.cancel(id: 2000 + i);
      } catch (_) {}
    }
    if (!settings.remindersOn) return;

    final exact = await android?.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final rotation = Rotation(data);
    final now = nowDhaka();

    for (var i = 0; i <= daysAhead; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final dayNo = Rotation.dayNumber(day);

      Future<void> add(int id, TimeOfDay t, String slot, ContentItem? item) async {
        if (item == null) return;
        final when = tz.TZDateTime(dhaka, day.year, day.month, day.day, t.hour, t.minute);
        if (!when.isAfter(now)) return;
        final heading = item.isAyah
            ? (slot == 'morning' ? 'সকালের আয়াত' : 'রাতের আয়াত')
            : 'রাতের হাদিস';
        await plugin.zonedSchedule(
          id: id,
          title: '$heading · ${item.category}',
          body: _short(item.bangla),
          scheduledDate: when,
          notificationDetails: NotificationDetails(android: _details(item)),
          androidScheduleMode: mode,
          payload: ReminderPayload(slot, dateKey(day), item.id).encode(),
        );
      }

      await add(1000 + i, settings.morningTime, 'morning', rotation.morning(dayNo));
      await add(
        2000 + i,
        settings.nightTime,
        'night',
        rotation.night(dayNo, hadith: settings.hadithAtNight),
      );
    }
  }

  static AndroidNotificationDetails _details(ContentItem item) => AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'সকাল ও রাতের কুরআন-হাদিস রিমাইন্ডার',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    fullScreenIntent: true,
    visibility: NotificationVisibility.public,
    color: const Color(0xFF1B6B47),
    styleInformation: BigTextStyleInformation(_short(item.bangla, 400)),
    ticker: 'Ayah Reminder',
  );

  static String _short(String s, [int max = 120]) =>
      s.length <= max ? s : '${s.substring(0, max).trimRight()}…';

  /// Shows one reminder right now, to test that notifications work.
  static Future<void> showTest(ContentItem item) async {
    final now = nowDhaka();
    await plugin.show(
      id: 999,
      title: 'পরীক্ষা · ${item.category}',
      body: _short(item.bangla),
      notificationDetails: NotificationDetails(android: _details(item)),
      payload: ReminderPayload(item.isAyah ? 'morning' : 'night', dateKey(now), item.id).encode(),
    );
  }

  /// Removes reminders that are currently showing (not the future ones).
  static Future<void> dismissShown() async {
    try {
      for (final n in await plugin.getActiveNotifications()) {
        if (n.id != null) await plugin.cancel(id: n.id!, tag: n.tag);
      }
    } catch (_) {
      // Not important if this fails.
    }
  }
}
