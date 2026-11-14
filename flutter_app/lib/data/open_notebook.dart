import 'dart:async';
import 'package:flutter/services.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'native_storage.dart';
import '../domain/models.dart';
import 'database.dart';
import 'sqlite_notebook.dart';

Future<SqliteNotebook> openNotebook() async {
  final schema = await rootBundle.loadString('assets/schema.sql');
  final native = await notebookNativeOptions();
  final connection = driftDatabase(
    name: native?.databasePath == null
        ? 'flex_notizbuch_rebuild_v1'
        : 'flex_notizbuch_encrypted_v1',
    native: native,
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
