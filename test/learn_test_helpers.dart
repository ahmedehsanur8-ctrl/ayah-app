import 'dart:io';

import 'package:ayah_reminder/features/learn/data/content_repository.dart';
import 'package:ayah_reminder/features/learn/data/progress_repository.dart';
import 'package:ayah_reminder/features/learn/state/learn_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// কুরআন বুঝি in tests: SQLite through FFI, the real bundled content DB opened
/// read-only, and an empty in-memory progress DB.
Future<void> attachLearnForTests() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final content = ContentRepository(
    await databaseFactory.openDatabase(
      File(ContentRepository.asset).absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    ),
  );
  final progress = await ProgressRepository.open(inMemoryDatabasePath);
  await Learn.instance.attachForTests(content, progress);
}

/// Lets the database answer (outside the test clock), then pumps.
Future<void> settleLearn(WidgetTester t, [int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await t.pump(const Duration(milliseconds: 50));
  }
}
