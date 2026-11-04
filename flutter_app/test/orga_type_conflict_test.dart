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
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/conflict_dialog.dart';

// Regression tests for the Orga defects reproduced in the Build 35 review.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteNotebook repo;
  late NotebookController c;
  Directory? databaseDirectory;
  setUp(() async {
    repo = SqliteNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    c = NotebookController(repo);
    await c.initialize();
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
    await databaseDirectory?.delete(recursive: true);
    databaseDirectory = null;
  });
  Future<void> open(
    WidgetTester t,
    Widget dialog, {
    Size size = const Size(800, 1000),
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(t.view.reset);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold)),
        builder: (_) => dialog,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  for (final appointment in [true, false]) {
    testWidgets(
      '${appointment ? 'appointment' : 'task'} explicit changes and cleared values survive type changes',
      (t) async {
        final original = await repo.saveEntry(
          OrgaEntry.empty().copyWith(
            title: 'Änderung',
            body: 'Änderung',
            isTask: !appointment,
            done: !appointment,
            dueDate: appointment ? null : '2030-04-04',
            appointmentDate: appointment ? '2030-04-04' : null,
            appointmentTime: appointment ? '14:30' : '',
          ),
        );
        await c.reload();
        await open(t, OrgaEditor(controller: c, entry: original));
        if (appointment) {
          await tap(t, find.byKey(const ValueKey('orga-appointment-date')));
          await tap(t, find.byKey(const ValueKey('calendar-day-2030-04-05')));
          await tap(t, find.byTooltip('Uhrzeit entfernen'));
          await tap(t, find.text('Übernehmen'));
        } else {
          await tap(t, find.textContaining('Fällig am'));
          await tap(t, find.text('Datum entfernen'));
          await tap(t, find.text('Aufgabe erledigt'));
        }
        await tap(t, find.byKey(const ValueKey('orga-kind-note')));
        await tap(
          t,
          find.byKey(
            ValueKey('orga-kind-${appointment ? 'appointment' : 'task'}'),
          ),
        );
        await tap(t, find.text('Speichern'));
        final saved = (await repo.entries()).single;
        expect(saved.appointmentDate, appointment ? '2030-04-05' : null);
        expect(saved.appointmentTime, isEmpty);
        expect(saved.dueDate, isNull);
        expect(saved.done, isFalse);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );

    testWidgets(
      '${appointment ? 'appointment date/time' : 'task due date/completion'} survives swipe away and back',
      (t) async {
        final original = await repo.saveEntry(
          OrgaEntry.empty().copyWith(
            title: 'Prüfeintrag',
            body: 'Prüfeintrag',
            isTask: !appointment,
            done: !appointment,
            dueDate: appointment ? null : '2030-04-04',
            appointmentDate: appointment ? '2030-04-04' : null,
            appointmentTime: appointment ? '14:30' : '',
          ),
        );
        await c.reload();
        await open(t, OrgaEditor(controller: c, entry: original));
        final bar = find.byKey(const ValueKey('orga-kind-bar'));
        for (final delta in [110.0, -110.0]) {
          await t.ensureVisible(bar);
          await t.pumpAndSettle();
          await t.drag(bar, Offset(delta, 0));
          await t.pumpAndSettle();
        }
        await t.ensureVisible(find.text('Speichern'));
        await t.tap(find.text('Speichern'));
        await t.pumpAndSettle();
        final actual = (await repo.entries()).single;
        final expectedValues = appointment
            ? [original.appointmentDate, original.appointmentTime]
            : [original.dueDate, original.done];
        final actualValues = appointment
            ? [actual.appointmentDate, actual.appointmentTime]
            : [actual.dueDate, actual.done];
        await finish(t);
        expect(actualValues, expectedValues);
      },
    );

    testWidgets(
      '${appointment ? 'appointment' : 'task'} values survive closing, backup restore and database restart',
      (t) async {
        final original = await repo.saveEntry(
          OrgaEntry.empty().copyWith(
            title: 'Fortsetzen',
            body: 'Fortsetzen',
            isTask: !appointment,
            done: !appointment,
            dueDate: appointment ? null : '2030-04-04',
            appointmentDate: appointment ? '2030-04-04' : null,
            appointmentTime: appointment ? '14:30' : '',
            items: const [
              CheckItem(id: 'item', text: 'Unterlagen', checked: true),
            ],
          ),
        );
        await c.reload();
        await open(t, OrgaEditor(controller: c, entry: original));
        await tap(t, find.byKey(const ValueKey('orga-kind-note')));
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
        final draft = (await repo.drafts()).single;
        expect(draft.entry.isTask, isFalse);
        expect(draft.entry.appointmentDate, isNull);
        expect((await repo.entries()).single.toJson(), original.toJson());
        final backup = await repo.exportBackup();
        await finish(t);
        c.dispose();
        await repo.close();
        databaseDirectory = Directory.systemTemp.createTempSync(
          'flex-orga-types-',
        );
        final file = File('${databaseDirectory!.path}/notebook.sqlite');
        SqliteNotebook reopen() => SqliteNotebook(
          NotebookDatabase(
            NativeDatabase(file),
            File('assets/schema.sql').readAsStringSync(),
          ),
        );
        repo = reopen();
        await repo.initialize();
        await repo.restoreBackup(backup);
        await repo.close();
        repo = reopen();
        c = NotebookController(repo);
        await c.initialize();
        final restored = c.drafts.single;
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: restored.entry,
            draftId: restored.id,
          ),
        );
        await tap(
          t,
          find.byKey(
            ValueKey('orga-kind-${appointment ? 'appointment' : 'task'}'),
          ),
        );
        await tap(t, find.text('Speichern'));
        final saved = (await repo.entries()).single;
        expect(saved.appointmentDate, original.appointmentDate);
        expect(saved.appointmentTime, original.appointmentTime);
        expect(saved.dueDate, original.dueDate);
        expect(saved.done, original.done);
        expect(saved.items.single.toJson(), original.items.single.toJson());
        expect(await repo.drafts(), isEmpty);
        await finish(t);
      },
    );

    testWidgets(
      '${appointment ? 'appointment' : 'task'} round trip without edits removes its draft',
      (t) async {
        final original = await repo.saveEntry(
          OrgaEntry.empty().copyWith(
            title: 'Unverändert',
            body: 'Unverändert',
            isTask: !appointment,
            done: !appointment,
            dueDate: appointment ? null : '2030-04-04',
            appointmentDate: appointment ? '2030-04-04' : null,
            appointmentTime: appointment ? '14:30' : '',
          ),
        );
        await c.reload();
        await open(t, OrgaEditor(controller: c, entry: original));
        await tap(t, find.byKey(const ValueKey('orga-kind-note')));
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
        final draft = c.drafts.single;
        await open(
          t,
          OrgaEditor(controller: c, entry: draft.entry, draftId: draft.id),
        );
        await tap(
          t,
          find.byKey(
            ValueKey('orga-kind-${appointment ? 'appointment' : 'task'}'),
          ),
        );
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
        expect(await repo.drafts(), isEmpty);
        expect((await repo.entries()).single.toJson(), original.toJson());
        await finish(t);
      },
    );
  }
  for (final useOther in [true, false]) {
    testWidgets(
      'conflict comparison shows dates/times and resolves ${useOther ? 'other' : 'current'}',
      (t) async {
        final original = await repo.saveEntry(
          OrgaEntry.empty().copyWith(
            title: 'Terminvergleich',
            body: 'Terminvergleich',
            appointmentDate: '2030-04-04',
            appointmentTime: '14:30',
          ),
        );
        await repo.saveDraft(
          EditDraft(
            id: 'review-conflict',
            entry: original.copyWith(
              appointmentDate: '2030-05-05',
              appointmentTime: '15:45',
            ),
            updatedAtUtc: utcNow(),
          ),
        );
        await repo.saveEntry(
          original.copyWith(
            appointmentDate: '2030-06-06',
            appointmentTime: '16:00',
          ),
        );
        await c.reload();
        await open(
          t,
          ConflictDialog(controller: c),
          size: useOther ? const Size(320, 740) : const Size(1100, 1000),
        );
        expect(find.text('Andere übernehmen'), findsOneWidget);
        final comparisons = t
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data ?? '')
            .join('\n');
        expect(comparisons, contains('15:45'));
        expect(comparisons, contains('16:00'));
        expect(comparisons, contains('05.05.2030'));
        expect(comparisons, contains('06.06.2030'));
        await tap(
          t,
          find.text(useOther ? 'Andere übernehmen' : 'Aktuelle behalten'),
        );
        final saved = (await repo.entries()).single;
        expect(saved.appointmentDate, useOther ? '2030-05-05' : '2030-06-06');
        expect(saved.appointmentTime, useOther ? '15:45' : '16:00');
        expect(await repo.drafts(), isEmpty);
        expect(find.text('Keine offenen Konflikte.'), findsOneWidget);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  test(
    'all user-facing Orga fields can be compared, including all-day appointments',
    () {
      final fields = OrgaEntry.empty().toJson().keys.toSet()
        ..removeAll({'id', 'revision', 'createdAtUtc', 'updatedAtUtc'});
      expect(fields.difference(conflictFieldLabels.keys.toSet()), isEmpty);
      expect(conflictText('appointmentTime', '', c), 'Ganztägig');
    },
  );

  test(
    'legacy drafts remain readable and invalid cached dates roll back restoration',
    () async {
      final entry = OrgaEntry.empty().copyWith(title: 'Alt', body: 'Alt');
      await repo.saveDraft(
        EditDraft(id: 'legacy', entry: entry, updatedAtUtc: utcNow()),
      );
      final backup =
          jsonDecode(await repo.exportBackup()) as Map<String, dynamic>;
      final row = (backup['tables']['drafts'] as List).single as Map;
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      payload.remove('orgaTypeDraft');
      row['payload'] = jsonEncode(payload);
      await repo.discardDraft('legacy');
      await repo.restoreBackup(jsonEncode(backup));
      final restored = (await repo.drafts()).single;
      expect(restored.entry.toJson(), entry.toJson());
      expect(restored.typeDraft.appointmentDate, isNull);
      await repo.discardDraft(restored.id);
      payload['orgaTypeDraft'] = {
        'appointmentDate': '2030-02-30',
        'appointmentTime': '14:30',
      };
      row['payload'] = jsonEncode(payload);
      await expectLater(
        repo.restoreBackup(jsonEncode(backup)),
        throwsA(isA<DomainError>()),
      );
      expect(await repo.drafts(), isEmpty);
    },
  );

  test(
    'returning to a completed task does not leave a newly planned reminder active',
    () {
      final note = OrgaEntry.empty().copyWith(
        title: 'Aufgabe',
        body: 'Aufgabe',
        reminderAtUtc: '2030-04-04T10:00:00Z',
        reminderState: ReminderState.planned,
      );
      final saved = const OrgaTypeDraft(
        done: true,
        dueDate: '2030-04-04',
      ).select(note, 'task');
      expect(saved.done, isTrue);
      expect(saved.reminderState, ReminderState.cancelled);
      expect(saved.validate, returnsNormally);
    },
  );
}
