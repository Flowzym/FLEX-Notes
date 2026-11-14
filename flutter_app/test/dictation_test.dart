import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/services/dictation.dart';
import 'package:flex_notizbuch/ui/dictation.dart';

class FakeDictation implements DictationPort {
  final controller = StreamController<DictationEvent>.broadcast(sync: true);
  bool denied = false;
  int cancelled = 0;
  @override
  Stream<DictationEvent> get events => controller.stream;
  @override
  Future<void> start(String language) async {
    if (denied) {
      throw PlatformException(
        code: 'permission',
        message: 'Mikrofon nicht erlaubt.',
      );
    }
  }

  @override
  Future<void> stop() async =>
      controller.add((state: 'final', text: 'Neuer Text'));
  @override
  Future<void> cancel() async {
    cancelled++;
  }
}

void main() {
  test(
    'insertion preserves adjacent text and selection; excess length never truncates existing note',
    () {
      final old = TextEditingValue(
        text: 'Vorher nachher',
        selection: const TextSelection.collapsed(offset: 6),
      );
      expect(insertDictation(old, 'Mitte', 100).text, 'Vorher Mitte nachher');
      expect(
        insertDictation(
          old.copyWith(
            selection: const TextSelection(baseOffset: 0, extentOffset: 6),
          ),
          'Anfang',
          100,
        ).text,
        'Anfang nachher',
      );
      expect(() => insertDictation(old, 'Zu viel', 5), throwsFormatException);
      expect(old.text, 'Vorher nachher');
    },
  );
  testWidgets(
    'dictation preview waits for explicit insertion and cancels late events',
    (t) async {
      final port = FakeDictation();
      addTearDown(port.controller.close);
      String? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => DictationDialog(port: port),
                  );
                },
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Öffnen'));
      await t.pumpAndSettle();
      await t.tap(find.text('Diktat starten'));
      await t.pump();
      port.controller.add((state: 'partial', text: 'Entwurf'));
      await t.pump();
      expect(result, isNull);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Einfügen'))
            .onPressed,
        isNull,
      );
      await t.tap(find.text('Anhalten'));
      await t.pump();
      await t.enterText(
        find.byKey(const ValueKey('dictation-preview')),
        'Geprüfter Text',
      );
      await t.tap(find.text('Einfügen'));
      await t.pumpAndSettle();
      port.controller.add((state: 'final', text: 'Zu spät'));
      await t.pump();
      expect(result, 'Geprüfter Text');
      expect(port.cancelled, greaterThan(0));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'permission denial leaves preview editable and restart possible',
    (t) async {
      final port = FakeDictation()..denied = true;
      addTearDown(port.controller.close);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DictationDialog(port: port)),
        ),
      );
      await t.tap(find.text('Diktat starten'));
      await t.pumpAndSettle();
      expect(find.text('Mikrofon nicht erlaubt.'), findsOneWidget);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('dictation-preview')))
            .readOnly,
        false,
      );
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
}
