import 'dart:async';
import 'services/diagnostics.dart';
import 'services/material_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'data/open_notebook.dart';
import 'services/device_services.dart';
import 'package:flutter/material.dart';
import 'application/notebook_controller.dart';
import 'ui/app.dart';
import 'domain/models.dart';
import 'domain/timetable.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final present = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      diagnostics.capture(
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
    if (!kReleaseMode) present?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(diagnostics.capture(error, stack));
    return true;
  };
  await diagnostics.initialize(const LocalMaterialFiles());
  LicenseRegistry.addLicense(() async* {
    for (final name in ['SQLCipher', 'OpenSSL', 'AndroidX']) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/licenses/$name.txt'));
    }
  });
  runApp(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFFFAF7F2),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FLEX.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF65734A),
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Color(0xFF65734A)),
              SizedBox(height: 16),
              Text('FLEX wird geöffnet …'),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final repository = await openNotebook();
    final services = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? await DeviceServices.create(repository)
        : null;
    final controller = NotebookController(repository, services: services);
    await controller.initialize();
    try {
      await repository.removeUnreferencedFiles(
        const LocalMaterialFiles().remove,
      );
    } catch (error, stack) {
      await diagnostics.capture(error, stack, area: DiagnosticArea.storage);
    }
    await initializeFlexTimetable(repository);
    await controller.reload();
    runApp(FlexApp(controller: controller));
  } catch (error, stack) {
    await diagnostics.capture(error, stack, area: DiagnosticArea.startup);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                error is DomainError
                    ? error.message
                    : (kIsWeb
                          ? 'Die lokalen Daten konnten nicht geöffnet werden. Bitte die Seite neu laden und freien Speicher sowie die Browsereinstellungen prüfen. Vorhandene Daten wurden nicht zurückgesetzt.'
                          : 'Die lokalen Daten konnten nicht geöffnet werden. Bitte FLEX neu starten und freien Speicher prüfen. Vorhandene Daten wurden nicht zurückgesetzt.'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
