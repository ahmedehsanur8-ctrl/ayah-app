import 'dart:io';

import 'package:ayah_reminder/app_state.dart';
import 'package:ayah_reminder/services/duas.dart';
import 'package:ayah_reminder/services/quran.dart';
import 'package:ayah_reminder/services/reminders.dart';
import 'package:ayah_reminder/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'learn_test_helpers.dart';

/// The app's theme around [home], in light or dark mode.
Widget themedApp(Widget home, Brightness b) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildTheme(Brightness.light),
  darkTheme: buildTheme(Brightness.dark),
  themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

/// Loads the app's data (as on a fresh install) and the real fonts, so text is
/// measured and drawn like on a phone. With [icons], the Material icon font is
/// loaded too (for screenshots; otherwise icons draw as boxes).
Future<void> setUpTestApp({bool icons = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'Ayah Reminder',
    packageName: 'com.ayahreminder.ayah_reminder',
    version: '1.0.75',
    buildNumber: '75',
    buildSignature: '',
  );
  tzdata.initializeTimeZones();
  Reminders.dhaka = tz.getLocation('Asia/Dhaka');
  await AppState.load();
  await Quran.loadMeta();
  await Quran.load();
  await Duas.load();
  await attachLearnForTests();
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  String font(String f) => 'assets/fonts/$f';
  await load('AmiriQuran', [font('AmiriQuran-Regular.ttf')]);
  await load('NotoSansBengali', [
    font('NotoSansBengali-Regular.ttf'),
    font('NotoSansBengali-Bold.ttf'),
  ]);
  await load('HindSiliguri', [
    font('HindSiliguri-Regular.ttf'),
    font('HindSiliguri-Medium.ttf'),
    font('HindSiliguri-SemiBold.ttf'),
    font('HindSiliguri-Bold.ttf'),
  ]);
  await load('NotoSerifBengali', [
    font('NotoSerifBengali-SemiBold.ttf'),
    font('NotoSerifBengali-Bold.ttf'),
  ]);
  if (icons) {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) await load('MaterialIcons', [f.path]);
  }
}
