import 'dart:async';
import 'package:flutter/services.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/data/native_storage.dart';
import '../domain/core.dart';

/// Separate application identity + separate database, including on the web.
/// Nothing reads or migrates the Android database implicitly.
Future<SqliteNotebook> openDesktopWorkspace({bool demo = false}) async {
  final schema = await rootBundle.loadString('assets/schema.sql');
  final connection = driftDatabase(
    name: demo ? 'flex_desktop_demo_v2' : 'flex_desktop_v1',
    native: await notebookNativeOptions(),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      onResult: (result) {
        if (const [
          WasmStorageImplementation.inMemory,
          WasmStorageImplementation.unsafeIndexedDb,
        ].contains(result.chosenImplementation)) {
          unawaited(result.resolvedExecutor.close());
          throw const DomainError(
            'Dieser Browser unterstützt keinen zuverlässigen lokalen Speicher. Bitte einen aktuellen Browser verwenden.',
          );
        }
      },
    ),
  );
  return SqliteNotebook(NotebookDatabase(connection, schema));
}
