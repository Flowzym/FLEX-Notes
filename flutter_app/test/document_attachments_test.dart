import 'dart:async';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/drafts.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/dialog_workflows.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/scan_editor.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;

SchoolRecord taskRecord(String pupil) =>
    SchoolRecord.empty(SchoolKind.homework, pupil).patch({
      'tasks': [
        const HomeworkTask(id: 'main', text: 'Gleicher Text').toJson(),
        const HomeworkTask(
          id: 'child',
          text: 'Gleicher Text',
          parentId: 'main',
        ).toJson(),
        const HomeworkTask(id: 'other', text: 'Weitere Aufgabe').toJson(),
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  late NotebookController c;
  setUp(() async {
    repo = classroomMemory();
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(const Pupil(id: 'p', name: 'Alex'));
    await c.savePupil(const Pupil(id: 'q', name: 'Kim'));
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });

  test(
    'task links round trip, isolate siblings and keep legacy identity and signatures',
    () {
      const parent = DocumentLink('school', 'record');
      const child = DocumentLink('school', 'record', taskId: 'child');
      const sibling = DocumentLink('school', 'record', taskId: 'other');
      expect(parent.identity, 'school:record:');
      expect(DocumentLink.fromJson(child.toJson()).identity, child.identity);
      expect(parent.includes(child), isTrue);
      expect(parent.includes(child, includeTasks: false), isFalse);
      expect(child.includes(sibling), isFalse);
      expect(child.includes(parent), isFalse);
      expect(
        draftSignature(child.toJson()),
        isNot(draftSignature(sibling.toJson())),
      );
      expect(
        draftSignature(child.toJson()),
        isNot(
          draftSignature(
            const DocumentLink('school', 'other', taskId: 'child').toJson(),
          ),
        ),
      );
      expect(
        () => DocumentLink.fromJson(
          const DocumentLink('orga', 'r', taskId: 'child').toJson(),
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );

  test(
    'task references reject absent and foreign tasks without changing documents',
    () async {
      final r = await repo.saveSchoolRecord(taskRecord('p'));
      final other = await repo.saveSchoolRecord(
        taskRecord('q').patch({
          'tasks': [const HomeworkTask(id: 'foreign', text: 'Andere').toJson()],
        }),
      );
      for (final id in ['absent', other.tasks.single.id]) {
        await expectLater(
          repo.saveClassroomDocument(
            material(
              'Ungültig',
              fields: {
                'links': [DocumentLink('school', r.id, taskId: id).toJson()],
              },
            ),
          ),
          throwsA(isA<DomainError>()),
        );
      }
      expect(await repo.classroomDocuments(), isEmpty);
    },
  );

  test(
    'renaming and reordering keep a subtask file; backup preserves exact association',
    () async {
      var r = await repo.saveSchoolRecord(taskRecord('p'));
      final link = DocumentLink('school', r.id, taskId: 'child');
      final d = await repo.saveClassroomDocument(
        material(
          'Lösung',
          fields: {
            'pupilIds': ['p'],
            'links': [link.toJson()],
          },
        ),
      );
      r = await repo.saveSchoolRecord(
        r.patch({
          'tasks': [
            r.tasks.last.toJson(),
            r.tasks.first.toJson(),
            r.tasks[1].copyWith(text: 'Umbenannt').toJson(),
          ],
        }),
      );
      final restored = classroomMemory();
      addTearDown(restored.close);
      await restored.initialize();
      await restored.restoreBackup(await repo.exportBackup());
      final copy = (await restored.classroomDocuments()).single;
      expect(copy.id, d.id);
      expect(copy.rows('links').single, link.toJson());
      expect(
        ScanContext(pupilIds: ['p'], links: [link]).matchesMaterial(copy),
        isTrue,
      );
      expect(
        ScanContext(
          links: [DocumentLink('school', r.id)],
        ).matchesMaterial(copy),
        isTrue,
      );
      expect(
        ScanContext(
          links: [DocumentLink('school', r.id, taskId: 'main')],
        ).matchesMaterial(copy),
        isFalse,
      );
    },
  );

  test(
    'removing a task retains files and scan drafts on the entry and rejects stale writes',
    () async {
      var r = await repo.saveSchoolRecord(taskRecord('p'));
      final link = DocumentLink('school', r.id, taskId: 'child');
      final doc = await repo.saveClassroomDocument(
        material(
          'Behalten',
          fields: {
            'links': [link.toJson(), DocumentLink('school', r.id).toJson()],
          },
        ),
      );
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: newId(),
          type: 'scan',
          ownerId: newId(),
          updatedAtUtc: utcNow(),
          data: {
            ...ScanContext(links: [link]).initial(),
            'sourceId': doc.id,
            'sourceRevision': doc.revision,
          },
        ),
      );
      r = await repo.saveSchoolRecord(
        r.patch({
          'tasks': r.tasks
              .where((t) => t.id != 'child')
              .map((t) => t.toJson())
              .toList(),
        }),
      );
      final kept = (await repo.classroomDocuments()).single;
      final resumed = (await repo.dialogDrafts()).single;
      expect(kept.rows('links'), [DocumentLink('school', r.id).toJson()]);
      expect(resumed.data['links'], kept.rows('links'));
      expect(resumed.data['sourceRevision'], kept.revision);
      expect(resumed.revision, draft.revision + 1);
      await expectLater(
        repo.saveDialogDraft(draft),
        throwsA(isA<StaleRevision>()),
      );
      await repo.validateClassroomReferences();
    },
  );

  test('failed stale task removal cannot move attachments', () async {
    final old = await repo.saveSchoolRecord(taskRecord('p'));
    final link = DocumentLink('school', old.id, taskId: 'child');
    await repo.saveClassroomDocument(
      material(
        'Bleibt',
        fields: {
          'links': [link.toJson()],
        },
      ),
    );
    await repo.saveSchoolRecord(old.patch({'subject': 'Deutsch'}));
    await expectLater(
      repo.saveSchoolRecord(
        old.patch({
          'tasks': [old.tasks.first.toJson()],
        }),
      ),
      throwsA(isA<StaleRevision>()),
    );
    expect((await repo.classroomDocuments()).single.rows('links'), [
      link.toJson(),
    ]);
  });

  Future<void> host(
    WidgetTester t,
    Widget child, {
    double width = 390,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t, Widget child) async {
    await host(t, const SizedBox());
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold)),
        builder: (_) => child,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.pumpAndSettle();
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Finder action(String section, String action) => find.descendant(
    of: find.byKey(ValueKey(section)),
    matching: find.byKey(ValueKey(action)),
  );
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  testWidgets(
    'homework search retains query when collapsed and combines with open filter',
    (t) async {
      final openRecord = await repo.saveSchoolRecord(
        taskRecord('p').patch({'title': 'Deutsch Lesen'}),
      );
      await repo.saveSchoolRecord(
        taskRecord('p').patch({
          'title': 'Mathematik Rechnen',
          'tasks': [
            const HomeworkTask(
              id: 'done',
              text: 'Fertig',
              initialState: TaskState.complete,
            ).toJson(),
          ],
        }),
      );
      await c.reload();
      await host(
        t,
        SizedBox(
          height: 800,
          child: SchoolWorkspace(
            controller: c,
            pupil: c.pupils.firstWhere((p) => p.id == 'p'),
            kind: SchoolKind.homework,
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Hausübung hinzufügen'), findsOneWidget);
      expect(find.byKey(ValueKey(openRecord.id)), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('homework-search')));
      await t.enterText(
        find.byKey(const ValueKey('homework-search-field')),
        'Rechnen',
      );
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey(openRecord.id)), findsNothing);
      expect(find.text('Erledigt (1)'), findsOneWidget);
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byTooltip('Hausübungen durchsuchen: Rechnen'),
        findsOneWidget,
      );
      await tap(t, find.byType(FilterChip));
      expect(find.text('Keine passenden Hausübungen.'), findsOneWidget);
      await tap(t, find.byTooltip('Suchtext leeren'));
      expect(find.byKey(ValueKey(openRecord.id)), findsOneWidget);
      expect(find.text('Erledigt (1)'), findsNothing);
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  for (final layout in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'homework summary survives collapse and actions remain reachable at $layout',
      (t) async {
        final r = await repo.saveSchoolRecord(
          taskRecord(
            'p',
          ).patch({'subject': 'Deutsch', 'dueDate': '2026-11-09'}),
        );
        await c.reload();
        await host(
          t,
          SchoolRecordCard(controller: c, record: r),
          width: layout.$1,
          scale: layout.$2,
        );
        expect(find.text('Deutsch'), findsOneWidget);
        expect(find.text('Fällig: 09.11.2026'), findsOneWidget);
        expect(find.byTooltip('Notiz & Verlauf'), findsOneWidget);
        expect(find.byTooltip('Erinnerung verschieben'), findsOneWidget);
        expect(find.byTooltip('Papierkorb'), findsOneWidget);
        expect(
          find.byKey(ValueKey('homework-history-${r.id}')),
          findsOneWidget,
        );
        await tap(t, find.byTooltip('Hausübung einklappen'));
        expect(
          find.byKey(ValueKey('homework-progress-${r.id}')),
          findsOneWidget,
        );
        expect(find.text('Fällig: 09.11.2026'), findsOneWidget);
        expect(find.byKey(const ValueKey('task-previews-child')), findsNothing);
        await tap(t, find.byTooltip('Hausübung aufklappen'));
        expect(
          find.byKey(const ValueKey('task-previews-child')),
          findsOneWidget,
        );
        await tap(t, find.byTooltip('Erinnerung verschieben'));
        expect(find.text('Morgen um 09:00'), findsOneWidget);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  for (final layout in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'standalone homework separates task and record actions at $layout',
      (t) async {
        final r = await repo.saveSchoolRecord(taskRecord('p'));
        await c.reload();
        await host(
          t,
          SchoolRecordCard(controller: c, record: r, standalone: true),
          width: layout.$1,
          scale: layout.$2,
        );
        expect(find.byType(Card), findsNothing);
        expect(find.text('Hausübung'), findsNothing);
        expect(find.byTooltip('Hausübung einklappen'), findsNothing);
        expect(find.text('1.1'), findsOneWidget);
        expect(find.byKey(const ValueKey('attachment-scan')), findsNothing);
        expect(find.byKey(const ValueKey('comment-child')), findsNothing);
        for (final state in TaskState.values) {
          final control = find.byKey(ValueKey('status-child-${state.name}'));
          expect(t.getSize(control).width, greaterThanOrEqualTo(44));
          expect(t.getSize(control).height, greaterThanOrEqualTo(44));
        }
        // A record-level scan must not acquire the previous task's attachment scope.
        await tap(t, find.byKey(ValueKey('record-attachments-${r.id}')));
        await tap(t, find.text('Scannen / Foto'));
        expect(
          t
              .widget<ScanEditor>(find.byType(ScanEditor))
              .scope
              .links
              .single
              .taskId,
          isEmpty,
        );
        await finish(t);
        await host(
          t,
          SchoolRecordCard(controller: c, record: r, standalone: true),
          width: layout.$1,
          scale: layout.$2,
        );
        expect(find.byKey(ValueKey('homework-delivery-${r.id}')), findsNothing);
        expect(find.text('Abgabe: Nicht überprüft'), findsNothing);
        await tap(t, find.byKey(const ValueKey('status-child-missing')));
        expect(find.text('Erneut aufgeben?'), findsOneWidget);
        await tap(t, find.text('So belassen'));
        final saved = (await repo.schoolRecords()).single;
        expect(saved.taskState(saved.tasks[1]), TaskState.missing);
        expect(saved.taskState(saved.tasks.first), TaskState.open);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  testWidgets(
    'one short task stays compact while details retain comments and the full text',
    (t) async {
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'p').patch({
          'tasks': [
            const HomeworkTask(id: 'one', text: 'Seite 24 üben').toJson(),
          ],
        }),
      );
      await c.reload();
      await host(
        t,
        SchoolRecordCard(controller: c, record: r, standalone: true),
      );
      expect(
        t.getSize(find.byKey(ValueKey('homework-content-${r.id}'))).height,
        lessThan(340),
      );
      expect(find.byKey(const ValueKey('attachment-scan')), findsNothing);
      await tap(t, find.byKey(const ValueKey('homework-task-details-one')));
      expect(find.text('Seite 24 üben'), findsWidgets);
      await tap(t, find.byKey(const ValueKey('comment-one')));
      await t.enterText(
        find.byKey(const ValueKey('homework-comment')),
        'Nächstes Mal gemeinsam lesen',
      );
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      expect(find.text('Nächstes Mal gemeinsam lesen'), findsOneWidget);
      final saved = (await repo.schoolRecords()).single;
      expect(saved.liveFeedback.single.taskId, 'one');
      expect(saved.taskState(saved.tasks.single), TaskState.open);
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  testWidgets(
    'open task details track edits and stop capture after the task is removed',
    (t) async {
      var r = await repo.saveSchoolRecord(taskRecord('p'));
      await c.reload();
      await host(
        t,
        SchoolRecordCard(controller: c, record: r, standalone: true),
      );
      await tap(t, find.byKey(const ValueKey('homework-task-details-child')));
      r = await repo.saveSchoolRecord(
        r.patch({
          'tasks': r.tasks
              .map(
                (v) => (v.id == 'child' ? v.copyWith(text: 'Neuer Text') : v)
                    .toJson(),
              )
              .toList(),
        }),
      );
      await c.reload();
      await t.pumpAndSettle();
      expect(find.text('Neuer Text'), findsOneWidget);
      await repo.saveSchoolRecord(
        r.patch({
          'tasks': r.tasks
              .where((v) => v.id != 'child')
              .map((v) => v.toJson())
              .toList(),
        }),
      );
      await c.reload();
      await t.pumpAndSettle();
      expect(find.text('Diese Aufgabe wurde entfernt.'), findsOneWidget);
      expect(find.byKey(const ValueKey('attachment-scan')), findsNothing);
      expect(find.byKey(const ValueKey('comment-child')), findsNothing);
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  testWidgets(
    'separate history identifies submission and deleting feedback restores the prior task state',
    (t) async {
      final r = await repo.saveSchoolRecord(
        taskRecord('p').patch({
          'feedback': [
            SchoolFeedback(
              id: 'result',
              observedOn: '2026-11-07',
              createdAtUtc: utcNow(),
              taskId: 'child',
              taskText: 'Gleicher Text',
              state: TaskState.complete,
            ).toJson(),
            SchoolFeedback(
              id: 'delivery',
              observedOn: '2026-11-08',
              createdAtUtc: utcNow(),
              delivery: 'submitted',
            ).toJson(),
          ],
        }),
      );
      await c.reload();
      await host(
        t,
        SchoolRecordCard(controller: c, record: r, standalone: true),
      );
      await tap(t, find.byKey(ValueKey('homework-history-${r.id}')));
      expect(find.text('Änderungen'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('homework-feedback-delivery')),
          matching: find.text('Abgabe: Vorgelegt'),
        ),
        findsOneWidget,
      );
      await tap(
        t,
        find.descendant(
          of: find.byKey(const ValueKey('homework-feedback-result')),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tap(t, find.text('Löschen'));
      await tap(t, find.widgetWithText(FilledButton, 'Löschen'));
      final saved = (await repo.schoolRecords()).single;
      expect(saved.taskState(saved.tasks[1]), TaskState.open);
      expect(saved.delivery, 'submitted');
      expect(
        find.byKey(const ValueKey('homework-feedback-result')),
        findsNothing,
      );
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  for (final kind in [SchoolKind.goal, SchoolKind.social, SchoolKind.work]) {
    testWidgets(
      '${kind.name} bottom scanner assigns draft without publishing new entry',
      (t) async {
        final r = SchoolRecord.empty(kind, 'p').patch({
          'title': 'Lesen',
          'body': 'Übung',
          if (kind == SchoolKind.goal) 'criterion': 'Zehn Minuten',
        });
        await open(t, SchoolEditor(controller: c, record: r));
        await tap(t, action('editor-attachments-entry', 'attachment-scan'));
        final scope = t.widget<ScanEditor>(find.byType(ScanEditor)).scope;
        expect(scope.pupilIds, isEmpty);
        expect(await repo.schoolRecords(), isEmpty);
        expect(scope.links.single.kind, 'schoolDraft');
        expect(scope.links.single.id, (await repo.schoolDrafts()).single.id);
        expect(scope.links.single.taskId, isEmpty);
        await finish(t);
      },
    );
  }

  testWidgets(
    'new group homework scanner retains selected subtask on its draft',
    (t) async {
      await open(t, SchoolEditor(controller: c, record: taskRecord('p')));
      await tap(t, find.byKey(const ValueKey('pupil-tag-q')));
      await tap(t, action('editor-attachments-child', 'attachment-scan'));
      final scope = t.widget<ScanEditor>(find.byType(ScanEditor)).scope;
      expect(await repo.schoolRecords(), isEmpty);
      final draft = (await repo.schoolDrafts()).single;
      expect(draft.recipients.toSet(), {'p', 'q'});
      expect(scope.pupilIds, isEmpty);
      expect(scope.links.single.kind, 'schoolDraft');
      expect(scope.links.single.id, draft.id);
      expect(scope.links.single.taskId, 'child');
      await finish(t);
    },
  );

  testWidgets('bulk capture holds subtask link without publishing', (t) async {
    await host(t, const SizedBox());
    final d = await repo.saveDialogDraft(
      DialogDraft(
        id: newId(),
        type: 'bulk',
        ownerId: 'group',
        updatedAtUtc: utcNow(),
        data: {
          'kind': 'homework',
          'recipients': ['p', 'q'],
          'context': '',
          'subject': 'Mathe',
          'body': '',
          'individual': <String, dynamic>{},
          'observedOn': dateOnly(DateTime.now()),
          'observedTime': '',
          'needsCompletion': false,
          'tasks': taskRecord('p').tasks.map((t) => t.toJson()).toList(),
        },
      ),
    );
    unawaited(showBulk(t.element(find.byType(Scaffold)), c, draft: d));
    await t.pumpAndSettle();
    await tap(t, action('homework-row-child', 'attachment-scan'));
    final scope = t.widget<ScanEditor>(find.byType(ScanEditor)).scope;
    expect(await repo.schoolRecords(), isEmpty);
    expect(scope.links.single.kind, 'bulkDraft');
    expect(scope.links.single.id, d.id);
    expect(scope.links.single.taskId, 'child');
    await finish(t);
  });

  testWidgets(
    'task files are visible only on their own row at narrow width and large text',
    (t) async {
      final r = await repo.saveSchoolRecord(taskRecord('p'));
      final d = await repo.saveClassroomDocument(
        material(
          'Lösungsfoto',
          fields: {
            'pupilIds': ['p'],
            'links': [DocumentLink('school', r.id, taskId: 'child').toJson()],
          },
        ),
      );
      await c.reload();
      await host(
        t,
        SchoolRecordCard(controller: c, record: r),
        width: 320,
        scale: 1.8,
      );
      expect(find.byKey(ValueKey('attachment-file-${d.id}')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('task-previews-child')),
          matching: find.text('Lösungsfoto'),
        ),
        findsOneWidget,
      );
      expect(
        t
            .widget<InkWell>(find.byKey(ValueKey('attachment-file-${d.id}')))
            .onTap,
        isNotNull,
      );
      expect(t.takeException(), isNull);
      await tap(t, find.byKey(const ValueKey('homework-task-details-child')));
      expect(find.text('Teilaufgabe 1.1'), findsOneWidget);
      expect(
        action('task-attachments-child', 'attachment-file-${d.id}'),
        findsOneWidget,
      );
      await tap(t, action('task-attachments-child', 'attachment-scan'));
      expect(
        t.widget<ScanEditor>(find.byType(ScanEditor)).scope.links.single.taskId,
        'child',
      );
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  testWidgets(
    'saved observation draft survives opening scanner without committing edits',
    (t) async {
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.work, 'p').patch({'body': 'Original'}),
      );
      await c.reload();
      await open(t, SchoolEditor(controller: c, record: r));
      await t.enterText(
        find.byKey(const ValueKey('record-body')),
        'Geänderter Entwurf',
      );
      await tap(t, action('editor-attachments-entry', 'attachment-scan'));
      expect((await repo.schoolRecords()).single.revision, r.revision);
      expect((await repo.schoolRecords()).single.body, 'Original');
      expect(
        (await repo.schoolDrafts()).single.record.body,
        'Geänderter Entwurf',
      );
      expect(
        t.widget<ScanEditor>(find.byType(ScanEditor)).scope.links.single.id,
        (await repo.schoolDrafts()).single.id,
      );
      await finish(t);
    },
  );

  testWidgets('Orga bottom action opens scanner with draft owner', (t) async {
    final e = await repo.saveEntry(
      OrgaEntry.empty(
        pupilId: 'p',
      ).copyWith(title: 'Formular', body: 'Formular'),
    );
    await c.reload();
    await open(t, OrgaEditor(controller: c, entry: e));
    await tap(t, find.byKey(const ValueKey('attachment-scan')));
    expect(
      t.widget<ScanEditor>(find.byType(ScanEditor)).scope.links.single.id,
      (await repo.drafts()).single.id,
    );
    expect(
      t.widget<ScanEditor>(find.byType(ScanEditor)).scope.pupilIds,
      isEmpty,
    );
    expect((await repo.entries()).single.revision, e.revision);
    await finish(t);
  });
}
