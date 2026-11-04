import 'package:flutter/foundation.dart';
import 'data/open_notebook.dart';
import 'services/device_services.dart';
import 'package:flutter/material.dart';
import 'application/notebook_controller.dart';
import 'ui/app.dart';
import 'domain/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = await openNotebook();
    final services = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? await DeviceServices.create(repository)
        : null;
    final controller = NotebookController(repository, services: services);
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
