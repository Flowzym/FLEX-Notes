import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/material_tags.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/material_sharing.dart';
import 'package:flex_notizbuch/ui/material_tags.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material, MemoryMaterialFiles;

void main() {
  test(
    'tags normalize, combine case variants, AND filter, remove and replace',
    () {
      expect(
        normalizeMaterialTags([' #  Mathe  ', 'mathe', '  Wort   Arten ', '']),
        ['Mathe', 'Wort Arten'],
      );
      expect(
        matchesMaterialTags(['Mathe', 'Klasse'], ['mathe', 'klasse']),
        true,
      );
      expect(matchesMaterialTags(['Mathe'], ['Mathe', 'Klasse']), false);
      expect(
        changeMaterialTags(['Mathe', 'Alt'], ['mathe'], TagChange.remove),
        ['Alt'],
      );
      expect(changeMaterialTags(['Alt'], ['Neu'], TagChange.replace), ['Neu']);
      expect(() => checkedMaterialTag('a,b'), throwsA(isA<DomainError>()));
      expect(
        () => changeMaterialTags(List.generate(30, (i) => '$i'), [
          'Neu',
        ], TagChange.add),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'rename merges duplicates across files, trash and pending scans; removal keeps files',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      for (final deleted in [false, true]) {
        await repo.saveClassroomDocument(
          material(
            'Datei',
            fields: {
              'tags': ['Mathe', 'Neu'],
              'deleted': deleted,
            },
          ),
        );
      }
      await repo.saveDialogDraft(
        DialogDraft(
          id: 'scan',
          type: 'scan',
          ownerId: 'scan',
          updatedAtUtc: utcNow(),
          data: {
            ...const ScanContext().initial(),
            'tags': ['mathe'],
          },
        ),
      );
      await repo.renameMaterialTag('MATHE', 'Neu');
      expect(
        (await repo.classroomDocuments()).every(
          (d) => d.strings('tags').single == 'Neu',
        ),
        true,
      );
      expect((await repo.dialogDrafts()).single.data['tags'], ['Neu']);
      await repo.renameMaterialTag('neu', null);
      expect(
        (await repo.classroomDocuments()).every(
          (d) => d.strings('tags').isEmpty,
        ),
        true,
      );
      expect(await repo.classroomDocuments(), hasLength(2));
      expect((await repo.dialogDrafts()).single.data['tags'], isEmpty);
    },
  );
  testWidgets(
    'typed tag persists before Enter; suggestion, chip and removal stay in sync',
    (t) async {
      var values = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, update) => MaterialTagEditor(
                values: values,
                suggestions: const ['Deutsch', 'Mathe'],
                onChanged: (v) => update(() => values = v),
              ),
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'Projekt');
      await t.pump();
      expect(values, ['Projekt']);
      await t.tap(find.byTooltip('Tag übernehmen'));
      await t.pump();
      expect(find.widgetWithText(InputChip, 'Projekt'), findsOneWidget);
      await t.tap(find.widgetWithText(ActionChip, 'Mathe'));
      await t.pump();
      expect(values, ['Projekt', 'Mathe']);
      t
          .widget<InputChip>(find.widgetWithText(InputChip, 'Projekt'))
          .onDeleted!();
      await t.pump();
      expect(values, ['Mathe']);
      expect(find.byType(TextField), findsOneWidget);
    },
  );
  testWidgets('24-hour input rejects invalid time and saves typed minutes', (
    t,
  ) async {
    (String, String)? result;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await pickFlexDate(
                  ctx,
                  date: '2026-11-11',
                  time: '09:00',
                  requireTime: true,
                );
              },
              child: const Text('Datum'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Datum'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('calendar-time')), '24:90');
    await t.tap(find.text('Übernehmen'));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(find.textContaining('Bitte eine Uhrzeit'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('calendar-time')), '0735');
    await t.tap(find.text('Übernehmen'));
    await t.pumpAndSettle();
    expect(result, ('2026-11-11', '07:35'));
  });

  test(
    'share preserves bytes, file order and MIME, sanitizes and deduplicates filenames',
    () async {
      final files = MemoryMaterialFiles();
      await files.write('one', Uint8List.fromList([1, 2]));
      await files.write('two', Uint8List.fromList([3, 4]));
      final docs = await prepareMaterialShare([
        material('A', fields: {'localKey': 'one', 'name': 'A/B.pdf'}),
        material(
          'B',
          fields: {'localKey': 'two', 'name': 'A/B.pdf', 'extension': 'jpg'},
        ),
      ], files);
      final params = documentShareParams(docs);
      expect(params.fileNameOverrides, ['A_B.pdf', 'A_B (2).pdf']);
      expect(await params.files!.first.readAsBytes(), [1, 2]);
      expect(await params.files!.last.readAsBytes(), [3, 4]);
      expect(params.files!.first.mimeType, 'application/pdf');
      expect(params.files!.last.mimeType, 'image/jpeg');
      await expectLater(
        prepareMaterialShare([
          material('A', fields: {'localKey': 'one'}),
          material('Fehlt'),
        ], files),
        throwsA(isA<DomainError>()),
      );
      expect(() => documentShareParams([]), throwsA(isA<DomainError>()));
    },
  );
}
