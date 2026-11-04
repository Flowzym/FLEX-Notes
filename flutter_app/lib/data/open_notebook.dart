import 'dart:async';
import 'package:flutter/services.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models.dart';
import 'database.dart';
import 'sqlite_notebook.dart';

Future<SqliteNotebook> openNotebook() async {
  final schema = await rootBundle.loadString('assets/schema.sql');
  final connection = driftDatabase(
    name: 'flex_notizbuch_rebuild_v1',
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
      shareAcrossIsolates: true,
    ),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      onResult: (result) {
        if ([
          WasmStorageImplementation.inMemory,
          WasmStorageImplementation.unsafeIndexedDb,
        ].contains(result.chosenImplementation)) {
          unawaited(result.resolvedExecutor.close());
          throw const DomainError(
            'Dieser Browser bietet keinen ausreichend zuverlässigen lokalen Speicher. Bitte die Vorschau mit einem aktuellen Browser auf einem lokalen Webserver öffnen.',
          );
        }
      },
    ),
  );
  return SqliteNotebook(NotebookDatabase(connection, schema));
}
