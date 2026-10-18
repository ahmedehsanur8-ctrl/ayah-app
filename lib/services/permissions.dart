import 'package:flutter/material.dart';

import 'prayer.dart';
import 'reminders.dart';
import 'settings.dart';
import 'system_settings.dart';

/// The permissions and phone settings the reminders and azan need, in the
/// order the first-open setup asks for them.
enum PermKey { notifications, fullScreen, exactAlarm, overlay, location, battery, brand }

/// One permission, with the words shown for it.
class PermissionInfo {
  const PermissionInfo(this.key, this.icon, this.title, this.why, {this.optional = false});

  final PermKey key;
  final IconData icon;
  final String title;
  final String why;

  /// Nice to have; reminders work without it, so it is not counted as missing.
  final bool optional;
}

/// A setting inside the phone maker's own pages (autostart etc.).
class BrandStep {
  const BrandStep(this.id, this.title, this.how, this.open);

  final String id;
  final String title;

  /// Where to find the switch, in simple words.
  final String how;
  final Future<void> Function() open;
}

/// Phone makers that stop background alarms unless the user changes settings.
class PhoneBrand {
  const PhoneBrand(this.name, this.steps);

  final String name;
  final List<BrandStep> steps;

  static Future<void> _autostart() async {
    if (!await SystemSettings.openAutostartSettings()) await SystemSettings.openAppDetails();
  }

  static final colorOs = PhoneBrand('Oppo / Realme / OnePlus', [
    BrandStep(
      'autostart',
      'অটোস্টার্ট (Auto launch)',
      'খোলা পাতায় Ayah Reminder-এর পাশের সুইচটি চালু করুন।',
      _autostart,
    ),
    const BrandStep(
      'popup',
      'পপ-আপ উইন্ডো (Pop-up windows)',
      'অ্যাপের তথ্য → Permissions বা Other permissions → "Display pop-up windows" চালু করুন।',
      SystemSettings.openAppDetails,
    ),
    const BrandStep(
      'lockscreen',
      'লক স্ক্রিনে দেখানো (Show on lock screen)',
      'Notifications → "Lock screen" বা "Show on lock screen" চালু করুন।',
      SystemSettings.openNotificationSettings,
    ),
    const BrandStep(
      'background',
      'ব্যাকগ্রাউন্ডে চলা (Allow background activity)',
      'অ্যাপের তথ্য → Battery usage → "Allow background activity" চালু করুন।',
      SystemSettings.openAppDetails,
    ),
  ]);

  static final miui = PhoneBrand('Xiaomi / Redmi / Poco', [
    BrandStep(
      'autostart',
      'অটোস্টার্ট (Autostart)',
      'খোলা পাতায় Ayah Reminder-এর পাশের সুইচটি চালু করুন।',
      _autostart,
    ),
    const BrandStep(
      'lockscreen',
      'লক স্ক্রিনে দেখানো (Show on Lock screen)',
      'Other permissions → "Show on Lock screen" → Allow দিন।',
      SystemSettings.openMiuiPermissions,
    ),
    const BrandStep(
      'popup',
      'পপ-আপ উইন্ডো (Pop-up windows)',
      'Other permissions → "Display pop-up windows while running in the background" → Allow দিন।',
      SystemSettings.openMiuiPermissions,
    ),
    const BrandStep(
      'battery',
      'ব্যাটারি: No restrictions',
      'অ্যাপের তথ্য → Battery saver → "No restrictions" বেছে নিন।',
      SystemSettings.openAppDetails,
    ),
  ]);

  static final vivo = PhoneBrand('Vivo / iQOO', [
    BrandStep(
      'autostart',
      'অটোস্টার্ট (Autostart)',
      'খোলা পাতায় Ayah Reminder-এর পাশের সুইচটি চালু করুন।',
      _autostart,
    ),
    const BrandStep(
      'background',
      'ব্যাকগ্রাউন্ডে ব্যাটারি ব্যবহার',
      'অ্যাপের তথ্য → Battery → "Background power consumption" → "Allow" দিন।',
      SystemSettings.openAppDetails,
    ),
  ]);

  static const samsung = PhoneBrand('Samsung', [
    BrandStep(
      'sleeping',
      '"Sleeping apps" থেকে সরিয়ে দিন',
      'Battery → Background usage limits → "Sleeping apps" ও "Deep sleeping apps" থেকে '
          'Ayah Reminder সরিয়ে দিন।',
      SystemSettings.openSamsungBattery,
    ),
    BrandStep(
      'unrestricted',
      'ব্যাটারি: Unrestricted',
      'অ্যাপের তথ্য → Battery → "Unrestricted" বেছে নিন।',
      SystemSettings.openAppDetails,
    ),
  ]);

  /// The brand page for [manufacturer], or null for phones that don't need it.
  static PhoneBrand? of(String manufacturer) {
    final m = manufacturer.toLowerCase();
    bool any(List<String> names) => names.any(m.contains);
    if (any(['oppo', 'realme', 'oneplus'])) return colorOs;
    if (any(['xiaomi', 'redmi', 'poco'])) return miui;
    if (any(['vivo', 'iqoo'])) return vivo;
    if (m.contains('samsung')) return samsung;
    return null;
  }
}

/// What is on and what is still missing.
class PermissionStatus {
  const PermissionStatus(this.granted, this.brand);

  final Map<PermKey, bool> granted;

  /// null when the phone needs no brand-specific steps.
  final PhoneBrand? brand;

  bool isGranted(PermKey k) => granted[k] ?? true;

  /// The permissions shown for this phone.
  List<PermissionInfo> get items =>
      Permissions.all.where((i) => i.key != PermKey.brand || brand != null).toList();

  /// Missing items that stop reminders from working (location only affects
  /// prayer times, and optional items are extras, so they are not counted).
  int get missingForReminders =>
      items.where((i) => i.key != PermKey.location && !i.optional && !isGranted(i.key)).length;
}

class Permissions {
  Permissions._();

  static const all = [
    PermissionInfo(
      PermKey.notifications,
      Icons.notifications_active_rounded,
      'নোটিফিকেশন',
      'অনুমতি না দিলে অ্যাপ কোনো রিমাইন্ডার বা আজানের খবর দেখাতে পারবে না।',
    ),
    PermissionInfo(
      PermKey.fullScreen,
      Icons.fullscreen_rounded,
      'ফুল-স্ক্রিন রিমাইন্ডার',
      'ফোন লক থাকলেও আয়াতটি অ্যালার্মের মতো পুরো স্ক্রিনে খুলবে। '
          'খোলা পাতায় Ayah Reminder-এর সুইচটি চালু করুন।',
    ),
    PermissionInfo(
      PermKey.exactAlarm,
      Icons.alarm_rounded,
      'সময়মতো রিমাইন্ডার',
      'রিমাইন্ডার ও আজান ঠিক নির্ধারিত সময়েই বাজবে, দেরিতে নয়। খোলা পাতায় সুইচটি চালু করুন।',
    ),
    PermissionInfo(
      PermKey.overlay,
      Icons.layers_rounded,
      'অন্য অ্যাপের উপরে দেখানো (ঐচ্ছিক)',
      'এটি ছাড়াও রিমাইন্ডার আসবে: অন্য অ্যাপ ব্যবহারের সময় উপরে নোটিফিকেশন, ফোন লক থাকলে পুরো '
          'স্ক্রিনে। চালু থাকলে রিমাইন্ডারের পাতাটি সরাসরি সামনে খুলবে।',
      optional: true,
    ),
    PermissionInfo(
      PermKey.location,
      Icons.location_on_rounded,
      'লোকেশন',
      'নামাজের সময় ও কিবলার দিক হিসাবের জন্য। লোকেশন ফোনেই থাকে, কোথাও পাঠানো হয় না। '
          'না দিতে চাইলে শহর বেছে নিন।',
    ),
    PermissionInfo(
      PermKey.battery,
      Icons.battery_charging_full_rounded,
      'ব্যাটারি',
      'ব্যাটারি বাঁচাতে ফোন অনেক সময় অ্যাপ বন্ধ করে দেয়, তখন রিমাইন্ডার আসে না। '
          '"Allow" বা "অনুমতি দিন" চাপুন।',
    ),
    PermissionInfo(
      PermKey.brand,
      Icons.phone_android_rounded,
      'ফোনের বিশেষ সেটিং',
      'আপনার ফোনে কিছু আলাদা সেটিং আছে যা বন্ধ থাকলে রিমাইন্ডার আসে না। '
          'প্রতিটি খুলে চালু করুন, তারপর "করেছি" চাপুন।',
    ),
  ];

  static PermissionInfo info(PermKey k) => all.firstWhere((i) => i.key == k);

  /// The latest check, for the banner on the home screen.
  static final status = ValueNotifier<PermissionStatus?>(null);

  static String? _manufacturer;

  static Future<PermissionStatus> check(AppSettings s) async {
    _manufacturer ??= await SystemSettings.manufacturer();
    final brand = PhoneBrand.of(_manufacturer!);
    final done = s.brandStepsDone;
    final result = PermissionStatus({
      PermKey.notifications: await SystemSettings.notificationsEnabled(),
      PermKey.fullScreen: await SystemSettings.canUseFullScreenIntent(),
      PermKey.exactAlarm: await SystemSettings.canScheduleExactAlarms(),
      PermKey.overlay: await SystemSettings.canDrawOverlays(),
      PermKey.location: s.hasLocation,
      PermKey.battery: await SystemSettings.isIgnoringBatteryOptimizations(),
      PermKey.brand: brand == null || brand.steps.every((st) => done.contains(st.id)),
    }, brand);
    final before = status.value;
    status.value = result;
    // "Alarms & reminders" was just turned on: plan the azan, sehri/iftar and
    // adhkar again so they are exact. (Android re-sets the native alarms too.)
    if (before != null &&
        !before.isGranted(PermKey.exactAlarm) &&
        result.isGranted(PermKey.exactAlarm)) {
      await Prayers.schedule(s);
    }
    return result;
  }

  static bool _askedNotifications = false;

  /// Opens the system dialog or settings page for [k]. Location and the
  /// brand steps have their own buttons and are not handled here.
  static Future<void> request(PermKey k) async {
    switch (k) {
      case PermKey.notifications:
        // The system dialog first; after that, the settings page.
        if (!_askedNotifications) {
          _askedNotifications = true;
          if (Reminders.android != null) {
            await Reminders.android!.requestNotificationsPermission();
            return;
          }
        }
        await SystemSettings.openNotificationSettings();
      case PermKey.fullScreen:
        await SystemSettings.openFullScreenSettings();
      case PermKey.exactAlarm:
        await SystemSettings.openExactAlarmSettings();
      case PermKey.overlay:
        await SystemSettings.openOverlaySettings();
      case PermKey.battery:
        await SystemSettings.requestIgnoreBatteryOptimizations();
      case PermKey.location || PermKey.brand:
        break;
    }
  }
}
