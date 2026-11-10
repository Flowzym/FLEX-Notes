import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';

SqliteNotebook fresh() => SqliteNotebook(
  NotebookDatabase(
    NativeDatabase.memory(),
    File('assets/schema.sql').readAsStringSync(),
  ),
);

class GatedNotebook extends SqliteNotebook {
  GatedNotebook(super.db);
  bool gate = false;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<List<Pupil>> pupils() async {
    final rows = await super.pupils();
    if (gate) {
      gate = false;
      started.complete();
      await release.future;
    }
    return rows;
  }
}

void main() {
  test('publishing cannot remove a draft changed by another editor', () async {
    final repo = fresh();
    await repo.initialize();
    try {
      await repo.savePupil(Pupil(id: 'synthetic', name: 'Testkind'));
      final r = SchoolRecord.empty(
        SchoolKind.goal,
        'synthetic',
      ).patch({'title': 'Testziel'});
      final first = await repo.saveSchoolDraft(
        SchoolDraft(id: 'draft', record: r, updatedAtUtc: utcNow()),
      );
      final second = await repo.saveSchoolDraft(
        SchoolDraft(
          id: first.id,
          record: r.patch({'title': 'Neuer Entwurf'}),
          updatedAtUtc: utcNow(),
          editRevision: first.editRevision,
        ),
      );
      await expectLater(
        repo.saveSchoolRecord(
          r,
          draftId: first.id,
          draftRevision: first.editRevision,
        ),
        throwsA(isA<StaleRevision>()),
      );
      expect(await repo.schoolRecords(), isEmpty);
      expect((await repo.schoolDrafts()).single.record.title, 'Neuer Entwurf');
      await repo.saveSchoolRecord(
        second.record,
        draftId: second.id,
        draftRevision: second.editRevision,
      );
      expect(await repo.schoolDrafts(), isEmpty);
    } finally {
      await repo.close();
    }
  });
  test(
    'controller snapshot holds one SQLite transaction across all reads',
    () async {
      final repo = GatedNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      await repo.initialize();
      try {
        final pupil = await repo.savePupil(
          Pupil(id: 'synthetic', name: 'Vor Änderung'),
        );
        repo.gate = true;
        final reading = repo.snapshot();
        await repo.started.future;
        final writing = repo.savePupil(pupil.copyWith(name: 'Nach Änderung'));
        repo.release.complete();
        final snapshot = await reading;
        await writing;
        expect(snapshot.pupils.single.name, 'Vor Änderung');
        expect((await repo.pupils()).single.name, 'Nach Änderung');
      } finally {
        await repo.close();
      }
    },
  );
  test(
    'old theme preferences migrate and new reading preferences validate',
    () {
      final old = Appearance.fromJson({
        'mode': 'dark',
        'accent': 0xffdae9a6,
        'textScale': 1.0,
      });
      expect(old.mode, 'light');
      final configured = old.patch({'mode': 'system', 'textScale': 1.3});
      expect(
        Appearance.fromJson(configured.toJson()).toJson(),
        configured.toJson(),
      );
      expect(() => old.patch({'textScale': 3}), throwsA(isA<DomainError>()));
    },
  );
  test(
    'surface colors and separate images survive database and backup round trip',
    () async {
      final repo = fresh(), restored = fresh();
      await repo.initialize();
      await restored.initialize();
      try {
        final appearance = const Appearance().patch({
          'dialogColor': 0xffabcdef,
          'headerOpacity': .25,
          'footerOpacity': .75,
          'desktopImage': base64Encode([1, 2, 3]),
          'mobileImage': base64Encode([4, 5, 6]),
          'desktopFit': 'fitWidth',
          'mobileFit': 'fill',
        });
        await repo.saveAppearance(appearance);
        await restored.restoreBackup(await repo.exportBackup());
        expect((await restored.appearance()).toJson(), appearance.toJson());
      } finally {
        await repo.close();
        await restored.close();
      }
    },
  );
  test(
    'Orga trash cancels reminders, preserves checklist and restore does not reactivate',
    () async {
      final repo = fresh();
      final c = NotebookController(repo);
      await c.initialize();
      try {
        final original = await repo.saveEntry(
          OrgaEntry.empty().copyWith(
            title: 'Synthetische Orga',
            isTask: true,
            observedOn: '2026-11-01',
            observedTime: '00:00',
            reminderAtUtc: '2026-12-01T10:00:00Z',
            reminderState: ReminderState.planned,
            items: [const CheckItem(id: 'item', text: 'Testpunkt')],
          ),
        );
        final deleted = await repo.saveEntry(
          original.copyWith(
            deleted: true,
            reminderState: ReminderState.cancelled,
          ),
        );
        await c.reload();
        expect(c.entries, isEmpty);
        expect(c.trashedEntries, hasLength(1));
        expect(deleted.pending, isFalse);
        final restored = await repo.saveEntry(deleted.copyWith(deleted: false));
        await c.reload();
        expect(restored.reminderState, ReminderState.cancelled);
        expect(restored.items.single.id, 'item');
        expect(restored.observedTime, '00:00');
        expect(c.entries, hasLength(1));
        expect(c.trashedEntries, isEmpty);
        expect(await repo.history(original.id), hasLength(3));
        await expectLater(
          repo.saveEntry(original),
          throwsA(isA<StaleRevision>()),
        );
      } finally {
        c.dispose();
        await repo.close();
      }
    },
  );
  test(
    'original version 1 backup gets default schema 7 fields without changing data',
    () async {
      final repo = fresh(), target = fresh();
      await repo.initialize();
      await target.initialize();
      try {
        final entry = await repo.saveEntry(
          OrgaEntry.empty().copyWith(title: 'Synthetischer Altbestand'),
        );
        final modern = jsonDecode(await repo.exportBackup()) as Json;
        final tables = Json.from(modern['tables'] as Map)
          ..removeWhere(
            (key, value) => !SqliteNotebook.legacyTables.contains(key),
          );
        for (final row in tables['orga'] as List) {
          for (final column in [
            'deleted',
            'observed_on',
            'observed_time',
            'reminder_text',
          ]) {
            (row as Map).remove(column);
          }
        }
        await target.restoreBackup(
          jsonEncode({
            'format': 'FLEX-Flutter-Backup',
            'version': 1,
            'tables': tables,
          }),
        );
        final restored = (await target.entries()).single;
        expect(restored.id, entry.id);
        expect(restored.title, entry.title);
        expect(restored.deleted, isFalse);
        expect(restored.observedOn, isEmpty);
      } finally {
        await repo.close();
        await target.close();
      }
    },
  );
  test('contrast helpers choose readable foregrounds', () {
    expect(legibleOn(Colors.white), Colors.black);
    expect(legibleOn(Colors.black), Colors.white);
  });
  testWidgets(
    'shared modal uses the fixed cream surface despite legacy customization',
    (tester) async {
      final repo = fresh();
      final c = NotebookController(repo);
      await c.initialize();
      await c.saveAppearance(
        const Appearance().patch({
          'dialogColor': 0xff426574,
          'headerOpacity': .5,
          'footerOpacity': .75,
          'buttonColor': 0xfff5f2e8,
        }),
      );
      await tester.pumpWidget(FlexApp(controller: c));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      showDialog<void>(
        context: context,
        builder: (context) => FlexModal(
          title: const Text('Synthetischer Dialog'),
          content: const Text('Inhalt'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final backdrop = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.descendant(
                of: find.byType(FlexModal),
                matching: find.byType(FlexBackground),
              ),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final colors = (backdrop.decoration as BoxDecoration).gradient!.colors;
      const palette = FlexPalette(Brightness.light);
      expect(colors, [palette.panel, palette.backdrop]);
      expect(colors.every((color) => color.a == 1), isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
    },
  );
}
