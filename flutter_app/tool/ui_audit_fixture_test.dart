// Generates synthetic data for a manual, populated UI audit. Never user data.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import '../test/classroom_test.dart' show classroomMemory;
import '../test/support/ui_audit_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export synthetic UI audit fixture', () async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    try {
      await seedUiAudit(c);
      final output = Platform.environment['FLEX_AUDIT_FIXTURE'];
      if (output == null) {
        throw StateError('Set FLEX_AUDIT_FIXTURE to the output JSON path.');
      }
      File(output).writeAsStringSync(await c.repository.exportBackup());
    } finally {
      c.dispose();
      await c.repository.close();
    }
  });
}
