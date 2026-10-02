import 'dart:io';

import 'package:ayah_reminder/features/learn/data/content_repository.dart';
import 'package:ayah_reminder/features/learn/data/progress_repository.dart';
import 'package:ayah_reminder/features/learn/state/learn_controller.dart';
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
