import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/ui/draft_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('at.flowzym.flex_notizbuch/files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android export passes filename, MIME and UTF-8 to document picker',
    () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return true;
      });
      const content = '{"name":"Schüler – Grüße 👋"}';
      expect(
        await saveTextFile('FLEX.json', content, mime: 'application/json'),
        isTrue,
      );
      expect(received!.method, 'saveFile');
      expect(received!.arguments['name'], 'FLEX.json');
      expect(received!.arguments['mime'], 'application/json');
      expect(utf8.decode(received!.arguments['bytes'] as Uint8List), content);
    },
  );

  test(
    'Cancelling Android document picker is not a successful export',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      expect(await saveTextFile('FLEX.txt', 'Notiz'), isFalse);
    },
  );

  test(
    'Android write errors reach caller and a later export can retry',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'save_failed',
          message: 'Kein Speicherplatz',
        );
      });
      await expectLater(
        saveTextFile('FLEX.txt', 'Notiz'),
        throwsA(isA<PlatformException>()),
      );
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      expect(await saveTextFile('FLEX.txt', 'Notiz'), isTrue);
    },
  );
}
