import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);
  late NotebookController c;
  setUp(() async {
    c = NotebookController(classroomMemory());
    await c.initialize();
    await c.savePupil(const Pupil(id: 'a', name: 'Anna Beispiel'));
    await c.savePupil(const Pupil(id: 'b', name: 'Ben Beispiel'));
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });

  Future<void> host(WidgetTester t, {double scale = 1}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 844);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t, Widget editor) async {
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold).first),
        builder: (_) => editor,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await t.ensureVisible(target.last);
    await t.pumpAndSettle();
    await t.tap(target.last);
    await t.pumpAndSettle();
  }

  Future<void> assign(
    WidgetTester t, {
    String? pupil,
    String names = 'Frau Muster',
  }) async {
    await tap(t, find.byKey(const ValueKey('person-assignment')));
    if (pupil != null) {
      await tap(t, find.byKey(ValueKey('person-assignment-$pupil')));
    }
    await t.enterText(
      find.byKey(const ValueKey('person-assignment-names')),
      names,
    );
    await tap(t, find.byKey(const ValueKey('person-assignment-apply')));
  }

  Future<void> finish(WidgetTester t) async {
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  test(
    'people survive JSON, drafts, storage, restore and merge; old entries still load',
    () async {
      final old = OrgaEntry.empty().copyWith(title: 'Früher').toJson()
        ..remove('otherParticipants');
      expect(OrgaEntry.fromJson(old).otherParticipants, isEmpty);
      final entry = OrgaEntry.empty().copyWith(
        title: 'Gespräch',
        pupilId: 'a',
        otherParticipants: 'Frau Muster',
        appointmentDate: '2026-11-14',
      );
      expect(entry.copyWith(pupilId: null).pupilId, isNull);
      await c.repository.saveDraft(
        EditDraft(id: 'people-draft', entry: entry, updatedAtUtc: utcNow()),
      );
      expect(
        (await c.repository.drafts()).single.entry.otherParticipants,
        'Frau Muster',
      );
      await c.saveEntry(entry);
      final saved = c.entries.single;
      expect(saved.pupilId, 'a');
      expect(saved.otherParticipants, 'Frau Muster');
      expect(c.owner(saved), 'Anna Beispiel · Frau Muster');
      expect(
        calendarItems(
          c.currentSnapshot,
          '2026-11-14',
          '2026-11-14',
        ).singleWhere((i) => i.entry?.id == saved.id).detail,
        contains('Frau Muster'),
      );

      for (final kind in [
        ClassroomKind.lesson,
        ClassroomKind.plan,
        ClassroomKind.holiday,
      ]) {
        final data = classroomInitial(kind, c, date: '2026-11-14');
        await c.saveClassroom(
          ClassroomDocument.fromJson({
            ...data,
            'title': 'Vorbereitung',
            'pupilIds': ['a'],
            'otherParticipants': 'Herr Muster',
          }),
        );
      }
      final backup = await c.repository.exportBackup();
      for (final merge in [false, true]) {
        final restored = classroomMemory();
        await restored.initialize();
        try {
          if (merge) {
            final plan = await restored.prepareBackupMerge(backup);
            await restored.applyBackupMerge(plan, {});
          } else {
            await restored.restoreBackup(backup);
          }
          expect(
            (await restored.entries()).single.otherParticipants,
            'Frau Muster',
          );
          expect((await restored.drafts()).single.entry.pupilId, 'a');
          for (final doc in await restored.classroomDocuments()) {
            expect(doc.text('otherParticipants'), 'Herr Muster');
            expect(doc.strings('pupilIds'), ['a']);
          }
        } finally {
          await restored.close();
        }
      }
      expect(
        () => saved.copyWith(otherParticipants: 'x' * 2001).validate(),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        c.repository.saveEntry(saved.copyWith(pupilId: 'b')),
        throwsA(isA<DomainError>()),
      );
    },
  );

  testWidgets(
    'existing long participant text remains editable without truncation',
    (t) async {
      final names = 'Beispielname; ' * 180;
      await c.saveRecord(
        SchoolRecord.empty(
          SchoolKind.goal,
          'a',
        ).patch({'title': 'Gemeinsames Ziel', 'otherParticipants': names}),
      );
      await host(t);
      await open(t, SchoolEditor(controller: c, record: c.records.single));
      await assign(t, names: '${names}Zusätzliche Person');
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      expect(c.records.single.otherParticipants, '${names}Zusätzliche Person');
      await finish(t);
    },
  );

  for (final kind in ['orga', 'social', 'work', 'homework']) {
    test('group $kind retains free names for every recipient', () async {
      final draft = await c.repository.saveDialogDraft(
        DialogDraft(
          id: 'group-$kind',
          type: 'bulk',
          ownerId: 'group',
          updatedAtUtc: utcNow(),
          data: {
            'kind': kind,
            'recipients': ['a', 'b'],
            'observedOn': '2026-11-14',
            'body': 'Gemeinsame Notiz',
            'subject': 'Lesen',
            'otherParticipants': 'Frau Muster',
            'individual': {
              for (final id in ['a', 'b']) id: {'body': 'Beobachtung'},
            },
            'tasks': [
              {'id': 'task', 'text': 'Lesen', 'status': 'open', 'comment': ''},
            ],
          },
        ),
      );
      await c.repository.saveBulkDialog(draft);
      await c.reload();
      if (kind == 'orga') {
        expect(c.entries.length, 2);
        expect(
          c.entries.every((e) => e.otherParticipants == 'Frau Muster'),
          isTrue,
        );
      } else {
        expect(c.records.length, 2);
        expect(
          c.records.every((e) => e.otherParticipants == 'Frau Muster'),
          isTrue,
        );
      }
    });
  }

  for (final kind in ['note', 'task', 'appointment']) {
    testWidgets(
      '$kind assigns pupil and free person, retains them across type changes and reopening',
      (t) async {
        await host(t);
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(),
            defaultToClassTask: false,
          ),
        );
        await tap(t, find.byKey(ValueKey('orga-kind-$kind')));
        await t.enterText(
          find.byKey(const ValueKey('orga-note')),
          'Besprechung vorbereiten',
        );
        await assign(t, pupil: 'b');
        final alternate = kind == 'note' ? 'task' : 'note';
        await tap(t, find.byKey(ValueKey('orga-kind-$alternate')));
        await tap(t, find.byKey(ValueKey('orga-kind-$kind')));
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(c.drafts.single.entry.pupilId, 'b');
        expect(c.drafts.single.entry.otherParticipants, 'Frau Muster');
        await tap(t, find.text('Speichern'));
        final saved = c.entries.single;
        expect(saved.pupilId, 'b');
        expect(saved.otherParticipants, 'Frau Muster');
        await open(t, OrgaEditor(controller: c, entry: saved));
        await tap(t, find.byKey(const ValueKey('person-assignment')));
        expect(
          t
              .widget<TextFormField>(
                find.byKey(const ValueKey('person-assignment-names')),
              )
              .initialValue,
          'Frau Muster',
        );
        expect(
          t
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('person-assignment-b')),
              )
              .value,
          true,
        );
        await tap(t, find.text('Abbrechen'));
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
        await finish(t);
      },
    );
  }

  for (final kind in SchoolKind.values) {
    testWidgets('$kind keeps its pupil and stores further people', (t) async {
      await host(t);
      final record = SchoolRecord.empty(kind, 'a').patch({
        'title': 'Übung',
        'body': 'Sachliche Beobachtung',
        'criterion': 'Gelingt',
        if (kind == SchoolKind.homework)
          'tasks': [
            {'id': 'task', 'text': 'Lesen', 'status': 'open', 'comment': ''},
          ],
      });
      await open(t, SchoolEditor(controller: c, record: record));
      await assign(t, pupil: 'b');
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      final saved = c.records.singleWhere(
        (r) => r.kind == kind && r.pupilId == 'a',
      );
      expect(saved.pupilId, 'a');
      expect(saved.participantIds, ['b']);
      expect(saved.otherParticipants, 'Frau Muster');
      await finish(t);
    });
  }

  testWidgets(
    'plan editor assigns pupils and free names and preserves them on reopen',
    (t) async {
      await host(t);
      unawaited(
        showClassroomEditor(
          t.element(find.byType(Scaffold).first),
          c,
          ClassroomKind.plan,
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Lesestunde',
      );
      await assign(t, pupil: 'a', names: 'Herr Muster');
      await tap(t, find.text('Speichern'));
      final plan = c.classroom.singleWhere((d) => d.title == 'Lesestunde');
      expect(plan.strings('pupilIds'), ['a']);
      expect(plan.text('otherParticipants'), 'Herr Muster');
      await finish(t);
    },
  );

  testWidgets(
    'free person alone works at large text; cancelling assignment changes nothing',
    (t) async {
      await host(t, scale: 1.8);
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(),
          defaultToClassTask: false,
        ),
      );
      await t.enterText(find.byKey(const ValueKey('orga-note')), 'Telefonat');
      await assign(t);
      await tap(t, find.byKey(const ValueKey('person-assignment')));
      await t.enterText(
        find.byKey(const ValueKey('person-assignment-names')),
        'Nicht übernehmen',
      );
      await tap(t, find.text('Abbrechen'));
      await tap(t, find.text('Speichern'));
      expect(c.entries.single.pupilId, isNull);
      expect(c.entries.single.otherParticipants, 'Frau Muster');
      expect(c.owner(c.entries.single), 'Frau Muster');
      await finish(t);
    },
  );
}
