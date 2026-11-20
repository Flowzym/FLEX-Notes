import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'package:flex_notizbuch/ui/flex_icons.dart';
import 'package:flex_notizbuch/ui/pupil_card.dart';
import 'package:flex_notizbuch/ui/return_lists.dart';
import 'support/app_test_fonts.dart';

class ReturnWriteStore extends SqliteNotebook {
  ReturnWriteStore(super.db);
  bool rejectWrite = false;
  @override
  Future<ClassroomDocument> saveClassroomDocument(
    ClassroomDocument value, {
    DialogDraft? draft,
  }) {
    if (rejectWrite && value.kind == ClassroomKind.returnList) {
      throw const DomainError('Test: Speichern fehlgeschlagen.');
    }
    return super.saveClassroomDocument(value, draft: draft);
  }
}

void main() {
  setUpAll(loadAppTestFonts);
  late Directory dir;
  late NotebookController c;
  Future<NotebookController> load() async {
    final controller = NotebookController(
      ReturnWriteStore(
        NotebookDatabase(
          NativeDatabase(File('${dir.path}/notebook.sqlite')),
          File('assets/schema.sql').readAsStringSync(),
        ),
      ),
    );
    await controller.initialize();
    return controller;
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('flex-return-workflow-');
    c = await load();
    await c.savePupil(const Pupil(id: 'a', name: 'Anna'));
    await c.savePupil(const Pupil(id: 'b', name: 'Ben'));
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> host(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.pumpAndSettle();
    await t.ensureVisible(finder.last);
    await t.pumpAndSettle();
    await t.tap(finder.last);
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  Future<void> pupilReturn(WidgetTester t, String title) async {
    await tap(t, find.byKey(const ValueKey('shortcut-a-orga')));
    await tap(t, find.byKey(const ValueKey('orga-kind-return')));
    await t.enterText(find.byKey(const ValueKey('classroom-title')), title);
  }

  Future<void> tasks(WidgetTester t) async {
    await tap(t, find.byKey(const ValueKey('bottom-2')));
    await tap(t, find.byKey(const ValueKey('context-2-3')));
  }

  testWidgets(
    'pupil return persists across restart and appears in both workspaces',
    (t) async {
      await host(t);
      await pupilReturn(t, 'Einverständnis zum Ausflug');
      await tap(t, find.text('Speichern'));
      final saved = (await c.repository.classroomDocuments()).single;
      expect(saved.rows('participants').map((r) => r['pupilId']), ['a']);
      await finish(t);
      c.dispose();
      await c.repository.close();
      c = await load();
      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      await tasks(t);
      expect(find.byKey(ValueKey('return-entry-${saved.id}')), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('bottom-1')));
      await tap(t, find.byKey(const ValueKey('pupil-open-a')));
      expect(find.text(saved.title), findsOneWidget);
      await tap(t, find.text(saved.title));
      expect(find.byType(ReturnDetail), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('return-status-a-received')));
      Navigator.of(t.element(find.byType(ReturnDetail))).pop();
      await t.pumpAndSettle();
      await tap(t, find.text('Noch offen'));
      expect(find.text(saved.title), findsNothing);
      await tap(t, find.text('Abgeschlossen'));
      expect(find.text(saved.title), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets(
    'long press on a return participant allows marking multiple replies together',
    (t) async {
      final form = ClassroomDocument.fromJson({
        ...classroomInitial(ClassroomKind.returnList, c),
        'title': 'Ausflugszettel',
      });
      await c.saveClassroom(form);
      await host(t);
      await tasks(t);
      await tap(t, find.text('Ausflugszettel'));
      final anna = find.text('Anna');
      await t.ensureVisible(anna);
      await t.longPress(anna);
      await t.pumpAndSettle();
      expect(find.text('Für den ausgewählten Schüler'), findsOneWidget);
      await tap(t, find.text('Ben'));
      expect(find.text('Für 2 ausgewählte Schüler'), findsOneWidget);
      await tap(
        t,
        find.widgetWithText(TextButton, returnStatuses['form']!['received']!),
      );
      await c.reload();
      expect(
        c.classroom.single
            .rows('participants')
            .every((r) => r['status'] == 'received'),
        isTrue,
      );
      await finish(t);
    },
  );

  testWidgets(
    'new return is visible even after task, done and search filters',
    (t) async {
      await host(t);
      await tasks(t);
      await tap(t, find.byKey(const ValueKey('general-type-task-tasks')));
      await tap(t, find.text('Erledigt').hitTestable());
      await tap(t, find.byKey(const ValueKey('general-search-button-task')));
      await t.enterText(
        find.byKey(const ValueKey('general-search-task')),
        'anderes',
      );
      await tap(t, find.byKey(const ValueKey('general-add-task')));
      await tap(t, find.byKey(const ValueKey('orga-kind-return')));
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Neue Rückgabe',
      );
      await tap(t, find.text('Speichern'));
      expect(c.classroom.single.title, 'Neue Rückgabe');
      expect(find.text('Neue Rückgabe'), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets('quick add in a pupil workspace preselects only that pupil', (
    t,
  ) async {
    await host(t);
    await tap(t, find.byKey(const ValueKey('pupil-open-a')));
    await tap(t, find.byKey(const ValueKey('quick-add')).last);
    await tap(t, find.byKey(const ValueKey('quick-add-returnList')));
    await t.enterText(
      find.byKey(const ValueKey('classroom-title')),
      'Annas Formular',
    );
    await tap(t, find.text('Speichern'));
    expect(c.classroom.single.rows('participants').map((p) => p['pupilId']), [
      'a',
    ]);
    expect(find.text('Annas Formular'), findsOneWidget);
    await finish(t);
  });

  for (final origin in ['pupil', 'tasks', 'editor']) {
    testWidgets('return draft is accessible and resumable from $origin', (
      t,
    ) async {
      await host(t);
      await pupilReturn(t, 'Beitrag zum Theater');
      await tap(t, find.text('Abbrechen'));
      expect(c.classroom, isEmpty);
      expect(c.dialogDrafts.single.data['title'], 'Beitrag zum Theater');
      if (origin == 'pupil') {
        final card = t.widget<PupilCard>(
          find.byKey(const ValueKey('pupil-card-a')),
        );
        expect(card.draftCounts[FlexSymbol.orga], 1);
        await tap(t, find.byKey(const ValueKey('pupil-open-a')));
        await tap(t, find.byTooltip('Entwürfe (1)'));
        await tap(t, find.text('Fortsetzen'));
      } else if (origin == 'tasks') {
        await tasks(t);
        await tap(t, find.byTooltip('Entwürfe · 1'));
        await tap(t, find.text('Beitrag zum Theater'));
      } else {
        await tap(t, find.byKey(const ValueKey('shortcut-a-orga')));
        await tap(t, find.byTooltip('Entwürfe (1)'));
        await tap(t, find.text('Fortsetzen'));
      }
      expect(find.byKey(const ValueKey('classroom-title')), findsOneWidget);
      await tap(t, find.text('Speichern').last);
      expect(c.dialogDrafts, isEmpty);
      expect(c.classroom.single.title, 'Beitrag zum Theater');
      await finish(t);
    });
  }

  for (final failure in ['participants', 'storage']) {
    testWidgets(
      '$failure error is visible and a return can be saved after correction',
      (t) async {
        await host(t);
        t.view.physicalSize = const Size(320, 740);
        t.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpAndSettle();
        await pupilReturn(t, 'Eingaben erhalten');
        if (failure == 'participants') {
          await tap(t, find.byKey(const ValueKey('person-assignment')));
          await tap(t, find.byKey(const ValueKey('person-assignment-clear')));
          await tap(t, find.byKey(const ValueKey('person-assignment-apply')));
        } else {
          (c.repository as ReturnWriteStore).rejectWrite = true;
        }
        await tap(t, find.text('Speichern'));
        expect(c.classroom, isEmpty);
        expect(c.dialogDrafts.single.data['title'], 'Eingaben erhalten');
        expect(
          find
              .text(
                failure == 'participants'
                    ? 'Bitte mindestens einen Schüler für den Rücklauf auswählen.'
                    : 'Test: Speichern fehlgeschlagen.',
              )
              .hitTestable(),
          findsOneWidget,
        );
        if (failure == 'participants') {
          await tap(t, find.byKey(const ValueKey('person-assignment')));
          await tap(t, find.byKey(const ValueKey('person-assignment-a')));
          await tap(t, find.byKey(const ValueKey('person-assignment-apply')));
        } else {
          (c.repository as ReturnWriteStore).rejectWrite = false;
        }
        await tap(t, find.text('Speichern'));
        expect(c.classroom.single.title, 'Eingaben erhalten');
        expect(c.dialogDrafts, isEmpty);
        await finish(t);
      },
    );
  }

  testWidgets(
    'pupil return previews show shared and own files, never another pupil files',
    (t) async {
      final document = ClassroomDocument.fromJson({
        ...classroomInitial(ClassroomKind.returnList, c),
        'title': 'Ausflug mit Unterlagen',
      });
      await c.saveClassroom(document);
      for (final id in ['shared', 'a', 'b']) {
        await c.saveClassroom(
          ClassroomDocument.create(ClassroomKind.material, id, {
            'extension': 'pdf',
            'url': 'https://example.org/$id.pdf',
            'pupilIds': id == 'shared' ? <String>[] : [id],
            'links': [DocumentLink('classroom', document.id).toJson()],
          }, id: id),
        );
      }
      await host(t);
      await tap(t, find.byKey(const ValueKey('pupil-open-a')));
      expect(
        find.byKey(const ValueKey('pupil-preview-file-shared')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pupil-preview-file-a')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pupil-preview-file-b')), findsNothing);
      await finish(t);
    },
  );

  testWidgets(
    'pupil return search and counters respect individual status and deletion',
    (t) async {
      for (final state in ['open', 'done', 'closed', 'deleted', 'other']) {
        await c.saveClassroom(
          ClassroomDocument.fromJson({
            ...classroomInitial(ClassroomKind.returnList, c),
            'id': state,
            'title': 'Theater $state',
            'dueDate': '2020-01-01',
            'closed': state == 'closed',
            'deleted': state == 'deleted',
            'participants': [
              if (state != 'other')
                {
                  'pupilId': 'a',
                  'name': 'Anna',
                  'status': state == 'done' ? 'received' : 'open',
                  'note': 'Reisebus',
                  'paid': 0,
                },
              {
                'pupilId': 'b',
                'name': 'Ben',
                'status': 'open',
                'note': '',
                'paid': 0,
              },
            ],
          }),
        );
      }
      await host(t);
      final card = t.widget<PupilCard>(
        find.byKey(const ValueKey('pupil-card-a')),
      );
      expect(card.counts[FlexSymbol.orga], 1);
      expect(card.due, contains(FlexSymbol.orga));
      await tap(t, find.byKey(const ValueKey('pupil-open-a')));
      await tap(t, find.byKey(const ValueKey('pupil-search-button')));
      await t.enterText(
        find.byKey(const ValueKey('pupil-entry-search')),
        'Reisebus',
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.text('Theater open'), findsOneWidget);
      expect(find.text('Theater done'), findsOneWidget);
      expect(find.text('Theater closed'), findsOneWidget);
      expect(find.text('Theater deleted'), findsNothing);
      expect(find.text('Theater other'), findsNothing);
      await tap(t, find.text('Noch offen'));
      expect(find.text('Theater done'), findsNothing);
      expect(find.text('Theater closed'), findsNothing);
      expect(find.text('Theater open'), findsOneWidget);
      await finish(t);
    },
  );
}
