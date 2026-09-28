import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const _native = MethodChannel('ayah_reminder/reminder');

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _native.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // tests / non-Android
    } on PlatformException catch (e) {
      debugPrint('reminder $method failed: $e');
      return null;
    }
  }

  static String _heading(ContentItem item, String slot) =>
      item.isAyah ? (slot == 'morning' ? 'সকালের আয়াত' : 'রাতের আয়াত') : 'রাতের হাদিস';

  static Map<String, Object> _event(DateTime when, String slot, DateTime day, ContentItem item) => {
    't': when.millisecondsSinceEpoch,
    'payload': ReminderPayload(slot, dateKey(day), item.id).encode(),
    'title': '${_heading(item, slot)} · ${item.category}',
    'body': _short(item.banglaPlain, 200),
  };

  /// The reminders of the next [daysAhead] days, as the Android alarm needs them.
  static List<Map<String, Object>> events(AppSettings settings, ContentData data) {
    if (!settings.remindersOn) return const [];
    final rotation = Rotation(data);
    final now = nowDhaka();
    final out = <Map<String, Object>>[];
    for (var i = 0; i <= daysAhead; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final dayNo = Rotation.dayNumber(day);
      void add(TimeOfDay t, String slot, ContentItem? item) {
        if (item == null) return;
        final when = tz.TZDateTime(dhaka, day.year, day.month, day.day, t.hour, t.minute);
        if (!when.isAfter(now)) return;
        out.add(_event(when, slot, day, item));
      }

      add(settings.morningTime, 'morning', rotation.morning(dayNo));
      add(settings.nightTime, 'night', rotation.night(dayNo, hadith: settings.hadithAtNight));
    }
    return out;
  }

  /// Plans the next [daysAhead] days of alarm-style reminders (Android alarm
  /// clock; only the next one is set at a time, and it comes back after restart).
  static Future<void> reschedule(AppSettings settings, ContentData data) async {
    // Remove notifications planned by older versions of the app.
    for (var i = 0; i <= daysAhead; i++) {
      try {
        await plugin.cancel(id: 1000 + i);
        await plugin.cancel(id: 2000 + i);
      } catch (_) {}
    }
    await _call('schedule', {
      'events': jsonEncode(events(settings, data)),
      'sound': settings.reminderSound,
      'vibrate': settings.reminderVibrate,
    });
  }

  /// Rings a test reminder after [seconds] (lock the phone and wait).
  static Future<void> testIn(ContentItem item, {int seconds = 60}) async {
    final now = nowDhaka();
    final slot = item.isAyah ? 'morning' : 'night';
    await _call('test', {
      'event': jsonEncode(_event(now.add(Duration(seconds: seconds)), slot, now, item)),
      'seconds': seconds,
    });
  }

  /// The reminder alarm that opened the app, if any.
  static Future<ReminderPayload?> nativeLaunchPayload() async =>
      ReminderPayload.decode(await _call<String>('launchPayload'));

  /// Opens reminders that arrive while the app is running.
  static void listen(void Function(ReminderPayload) onOpen) {
    _native.setMethodCallHandler((call) async {
      if (call.method == 'open') {
        final p = ReminderPayload.decode(call.arguments as String?);
        if (p != null) onOpen(p);
      }
    });
  }

  /// Stops the reminder sound (reading page opened with "আমি পড়েছি" / snooze).
  static Future<void> stopSound() => _call('stopSound');

  /// "১০ মিনিট পরে": rings the same reminder again in 10 minutes.
  static Future<void> snooze() => _call('snooze');

  static String _short(String s, [int max = 120]) =>
      s.length <= max ? s : '${s.substring(0, max).trimRight()}…';

  /// Removes reminders that are currently showing (not the future ones).
  static Future<void> dismissShown() async {
    await _call('done');
    try {
      for (final n in await plugin.getActiveNotifications()) {
        final id = n.id;
        // Only reminder notifications (not a playing azan).
        if (id != null && (id == 999 || (id >= 1000 && id < 3000))) {
          await plugin.cancel(id: id, tag: n.tag);
        }
      }
    } catch (_) {
      // Not important if this fails.
    }
  }
}
