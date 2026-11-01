import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'application/notebook_controller.dart';
import 'data/database.dart';
import 'data/sqlite_notebook.dart';
import 'ui/app.dart';
import 'domain/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
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
    final controller = NotebookController(
      SqliteNotebook(NotebookDatabase(connection, schema)),
    );
    await controller.initialize();
    runApp(FlexApp(controller: controller));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                error is DomainError
                    ? error.message
                    : 'Der lokale Speicher konnte nicht geöffnet werden. Vorhandene Daten wurden nicht zurückgesetzt. Bitte Speicherberechtigung und freien Platz prüfen. Für die Webvorschau müssen sqlite3.wasm und drift_worker.js vorhanden sein.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
