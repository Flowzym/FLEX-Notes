import 'dart:async';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/services/calendar_ics.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  test('legacy appointments have no tags; invalid tags cannot be saved', () {
    final legacy = OrgaEntry.empty().copyWith(
      title: 'Englisch',
      appointmentDate: '2030-04-04',
    );
    expect(OrgaEntry.fromJson(legacy.toJson()..remove('tags')).tags, isEmpty);
    for (final tags in [
      [''],
      ['Test', 'test'],
      ['A,B'],
      ['x' * 65],
      List.generate(31, (i) => 'Tag $i'),
    ]) {
      expect(
        () => legacy.copyWith(tags: tags).validate(),
        throwsA(isA<DomainError>()),
      );
    }
  });

  testWidgets(
    'appointment tags survive type changes, saving and reopening and can be removed',
    (t) async {
      final repo = classroomMemory();
      final c = NotebookController(repo);
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await repo.close();
      });
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      Future<void> tap(Finder f) async {
        await t.ensureVisible(f.last);
        await t.pumpAndSettle();
        await t.tap(f.last);
        await t.pumpAndSettle();
      }

      Future<void> open(OrgaEntry entry) async {
        unawaited(
          showDialog<void>(
            context: t.element(find.byType(Scaffold).first),
            builder: (_) => OrgaEditor(controller: c, entry: entry),
          ),
        );
        await t.pumpAndSettle();
      }

      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      await open(
        OrgaEntry.empty().copyWith(
          title: 'Prüfung',
          body: 'Prüfung',
          appointmentDate: '2030-04-04',
        ),
      );
      await tap(find.widgetWithText(ActionChip, 'Schularbeit'));
      final field = find.descendant(
        of: find.byKey(const ValueKey('appointment-tags')),
        matching: find.byType(TextField),
      );
      await t.ensureVisible(field);
      await t.enterText(field, 'Englisch');
      await t.pumpAndSettle();
      await tap(find.byKey(const ValueKey('orga-kind-note')));
      await tap(find.byKey(const ValueKey('orga-kind-appointment')));
      expect(find.widgetWithText(InputChip, 'Englisch'), findsOneWidget);
      await tap(find.text('Speichern'));
      final saved = (await repo.entries()).single;
      expect(saved.tags, ['Schularbeit', 'Englisch']);
      expect(await repo.searchEntryKeys('schularb'), {'orga:${saved.id}'});
      final item = calendarItems(
        await repo.snapshot(),
        '2030-04-04',
        '2030-04-04',
      ).singleWhere((item) => item.entry?.id == saved.id);
      expect(item.detail, contains('#Schularbeit'));
      expect(
        exportCalendarIcs([item]),
        contains('CATEGORIES:Termine,Schularbeit,Englisch'),
      );
      await open(saved);
      await tap(find.byTooltip('Schularbeit entfernen'));
      await tap(find.byTooltip('Englisch entfernen'));
      await tap(find.text('Speichern'));
      expect((await repo.entries()).single.tags, isEmpty);
      expect(await repo.searchEntryKeys('schularb'), isEmpty);
      await repo.saveEntry(
        (await repo.entries()).single.copyWith(tags: ['Überprüfung']),
      );
      expect(await repo.searchEntryKeys('überprüfung'), {'orga:${saved.id}'});
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
