import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/services/diagnostics.dart';
import 'material_workspace_test.dart' show MemoryMaterialFiles;

void main() {
  test(
    'exception text, paths, names and access tokens never enter persistent report',
    () async {
      final files = MemoryMaterialFiles();
      final log = DiagnosticLog(clock: () => DateTime.utc(2026, 11, 14));
      await log.initialize(files);
      await log.capture(
        StateError('Marek /storage/secret.pdf token=abc123'),
        StackTrace.fromString('''
#0 privateUserName /storage/emulated/secret.pdf:10
#1 x (package:flex_notizbuch/ui/orga_editor.dart:23:4)
https://private.example/?token=abc123
'''),
        area: DiagnosticArea.scanner,
      );
      final persisted = utf8.decode(await files.read(DiagnosticLog.key));
      expect(persisted, contains('orga_editor.dart:23:4'));
      for (final secret in [
        'Marek',
        'secret.pdf',
        'abc123',
        'privateUserName',
        'private.example',
      ]) {
        expect(persisted, isNot(contains(secret)));
        expect(log.report(), isNot(contains(secret)));
      }
    },
  );

  test(
    'bounded rotation persists across restart and expired events disappear',
    () async {
      final files = MemoryMaterialFiles();
      var now = DateTime.utc(2026, 11, 1);
      final log = DiagnosticLog(clock: () => now);
      await log.initialize(files);
      for (var i = 0; i < 112; i++) {
        await log.capture(const FormatException('secret'), StackTrace.empty);
      }
      expect(log.events, hasLength(100));
      final reopened = DiagnosticLog(clock: () => now);
      await reopened.initialize(files);
      expect(reopened.events, hasLength(100));
      now = DateTime.utc(2026, 11, 16);
      expect((jsonDecode(reopened.report()) as Map)['events'], isEmpty);
      await reopened.clear();
      expect(
        jsonDecode(utf8.decode(await files.read(DiagnosticLog.key))),
        isEmpty,
      );
    },
  );

  test('tampered stored log is revalidated before sharing', () async {
    final files = MemoryMaterialFiles();
    await files.write(
      DiagnosticLog.key,
      Uint8List.fromList(
        utf8.encode(
          jsonEncode([
            {
              'time': '2026-11-14T00:00:00Z',
              'area': 'scanner',
              'type': 'unexpected',
              'secret': 'name',
              'frames': [
                'package:flex_notizbuch/ui/scan.dart:1:1 secretname',
                '/private/names.txt',
              ],
            },
            {
              'time': '2026-11-14',
              'area': 'student-name',
              'type': 'unexpected',
            },
          ]),
        ),
      ),
    );
    final log = DiagnosticLog(clock: () => DateTime.utc(2026, 11, 14));
    await log.initialize(files);
    expect(log.events, hasLength(1));
    expect(log.report(), isNot(contains('secret')));
    expect(log.report(), isNot(contains('student-name')));
    expect(log.events.single['frames'], isEmpty);
  });
}
