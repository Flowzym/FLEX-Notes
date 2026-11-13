import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/ui/scan_editor.dart';
import 'package:flex_notizbuch/ui/material_thumbnail.dart';
import 'material_workspace_test.dart' show material;
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'support/app_test_fonts.dart';

class ReturnDraftNotebook extends SqliteNotebook {
  ReturnDraftNotebook(super.db);
  bool failDialogWrites = false;
  @override
  Future<DialogDraft> saveDialogDraft(DialogDraft draft) {
    if (failDialogWrites) {
      throw const DomainError('Test: Sicherung fehlgeschlagen');
    }
    return super.saveDialogDraft(draft);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);
  late NotebookController c;
  late ReturnDraftNotebook repo;
  setUp(() async {
    repo = ReturnDraftNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(const Pupil(id: 'a', name: 'Anna'));
    await c.savePupil(const Pupil(id: 'b', name: 'Ben'));
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });

  Future<void> host(
    WidgetTester t, {
    OrgaEntry? entry,
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(320, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold).first),
        builder: (_) =>
            OrgaEditor(controller: c, entry: entry ?? OrgaEntry.empty()),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.pumpAndSettle();
    await t.ensureVisible(f.last);
    await t.pumpAndSettle();
    await t.tap(f.last);
    await t.pumpAndSettle();
  }

  Future<void> tab(WidgetTester t, String kind) =>
      tap(t, find.byKey(ValueKey('orga-kind-$kind')));
  Future<void> finish(WidgetTester t) async {
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  testWidgets(
    'return capture keeps blank owner and previews through switch and publication',
    (t) async {
      await host(t, scale: 1.8);
      await tab(t, 'return');
      await tap(t, find.byKey(const ValueKey('return-scan')));
      final scanner = t.widget<ScanEditor>(find.byType(ScanEditor));
      expect(scanner.scope.category, 'form');
      final draft = (await repo.dialogDrafts()).singleWhere(
        (d) => d.type == 'classroom',
      );
      expect(
        scanner.scope.links.single.identity,
        DocumentLink('classroomDraft', draft.id).identity,
      );
      final attached = await repo.saveClassroomDocument(
        material(
          'Einverständnis.pdf',
          fields: {
            'links': scanner.scope.links.map((l) => l.toJson()).toList(),
          },
        ),
      );
      await c.reload();
      await tap(t, find.text('Später fortsetzen'));
      expect(
        find.byKey(ValueKey('return-file-${attached.id}')),
        findsOneWidget,
      );
      expect(find.byType(MaterialThumbnail), findsOneWidget);
      await tab(t, 'note');
      expect(
        (await repo.dialogDrafts()).where((d) => d.type == 'classroom'),
        hasLength(1),
      );
      await tab(t, 'return');
      expect(
        find.byKey(ValueKey('return-file-${attached.id}')),
        findsOneWidget,
      );
      await t.ensureVisible(find.byKey(const ValueKey('classroom-title')));
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Ausflug',
      );
      await tap(t, find.text('Speichern'));
      final saved = c.classroom.singleWhere(
        (d) => d.kind == ClassroomKind.returnList,
      );
      expect(
        c.classroom.singleWhere((d) => d.id == attached.id).rows('links'),
        [DocumentLink('classroom', saved.id).toJson()],
      );
      await finish(t);
    },
  );

  testWidgets('failed owner save prevents scanner launch and retries safely', (
    t,
  ) async {
    await host(t);
    await tab(t, 'return');
    repo.failDialogWrites = true;
    await tap(t, find.byKey(const ValueKey('return-scan')));
    expect(find.byType(ScanEditor), findsNothing);
    repo.failDialogWrites = false;
    await tap(t, find.byKey(const ValueKey('return-scan')));
    expect(find.byType(ScanEditor), findsOneWidget);
    await tap(t, find.text('Später fortsetzen'));
    await tap(t, find.text('Abbrechen'));
    expect(await repo.dialogDrafts(), isEmpty);
    await finish(t);
  });

  testWidgets(
    'four creation options fit a phone and return pupils save without an extra task',
    (t) async {
      await host(t);
      final buttons = ['note', 'task', 'appointment', 'return']
          .map((kind) => t.getRect(find.byKey(ValueKey('orga-kind-$kind'))))
          .toList();
      for (final rect in buttons) {
        expect(rect.top, closeTo(buttons.first.top, .1));
        expect(rect.width, closeTo(buttons.first.width, .1));
      }
      await tab(t, 'return');
      expect(find.text('Schüler auswählen'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Ausflugserlaubnis',
      );
      await tap(t, find.byKey(const ValueKey('person-assignment')));
      await tap(t, find.byKey(const ValueKey('person-assignment-clear')));
      await tap(t, find.byKey(const ValueKey('person-assignment-b')));
      await tap(t, find.byKey(const ValueKey('person-assignment-apply')));
      await tap(t, find.text('Speichern'));
      final saved = c.classroom.single;
      expect(saved.kind, ClassroomKind.returnList);
      expect(saved.rows('participants').map((p) => p['pupilId']), ['b']);
      expect(c.entries, isEmpty);
      expect(await repo.drafts(), isEmpty);
      expect(await repo.dialogDrafts(), isEmpty);
      await finish(t);
    },
  );

  testWidgets(
    'return switching preserves both drafts, pupil context and names at large text',
    (t) async {
      await host(
        t,
        entry: OrgaEntry.empty(
          pupilId: 'a',
        ).copyWith(isTask: true, otherParticipants: 'Frau Muster'),
        scale: 1.8,
      );
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Originalaufgabe',
      );
      await tab(t, 'return');
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Rückgabe',
      );
      await tap(t, find.byKey(const ValueKey('person-assignment')));
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('person-assignment-a')),
            )
            .value,
        true,
      );
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('person-assignment-b')),
            )
            .value,
        false,
      );
      await tap(t, find.byKey(const ValueKey('person-assignment-select-all')));
      await tap(t, find.byKey(const ValueKey('person-assignment-apply')));
      final bar = find.byKey(const ValueKey('orga-kind-bar'));
      await t.ensureVisible(bar);
      await t.drag(bar, const Offset(180, 0));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('orga-appointment-date')),
        findsOneWidget,
      );
      await t.drag(bar, const Offset(-180, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('classroom-title')), findsOneWidget);
      await tab(t, 'task');
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('orga-note')))
            .controller!
            .text,
        'Originalaufgabe',
      );
      await tab(t, 'return');
      expect(
        t
            .widget<TextFormField>(
              find.byKey(const ValueKey('classroom-title')),
            )
            .initialValue,
        'Rückgabe',
      );
      await tap(t, find.text('Abbrechen'));
      expect((await repo.drafts()).single.entry.body, 'Originalaufgabe');
      final saved = (await repo.dialogDrafts()).single;
      expect(saved.data['title'], 'Rückgabe');
      expect((saved.data['participants'] as List), hasLength(2));
      expect(saved.data['otherParticipants'], 'Frau Muster');
      expect(c.classroom, isEmpty);
      await finish(t);
    },
  );

  testWidgets(
    'return draft failure blocks tab navigation and preserves input for retry',
    (t) async {
      await host(t);
      await tab(t, 'return');
      repo.failDialogWrites = true;
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Nicht verlieren',
      );
      await tab(t, 'note');
      expect(find.byKey(const ValueKey('classroom-title')), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(
              find.byKey(const ValueKey('classroom-title')),
            )
            .initialValue,
        'Nicht verlieren',
      );
      repo.failDialogWrites = false;
      await tab(t, 'note');
      expect(find.byKey(const ValueKey('orga-note')), findsOneWidget);
      expect(
        (await repo.dialogDrafts()).single.data['title'],
        'Nicht verlieren',
      );
      await finish(t);
    },
  );

  testWidgets(
    'changing return participants retains selected pupil statuses and notes',
    (t) async {
      final initial = classroomInitial(ClassroomKind.returnList, c);
      final doc = ClassroomDocument.fromJson({
        ...initial,
        'title': 'Rücklauf',
        'participants': [
          {
            'pupilId': 'a',
            'name': 'Anna',
            'status': 'open',
            'note': '',
            'paid': 0,
          },
          {
            'pupilId': 'b',
            'name': 'Ben',
            'status': 'received',
            'note': 'Bereits da',
            'paid': 0,
          },
        ],
      });
      await c.saveClassroom(doc);
      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      unawaited(
        showClassroomEditor(
          t.element(find.byType(Scaffold).first),
          c,
          ClassroomKind.returnList,
          document: c.classroom.single,
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('person-assignment')));
      await tap(t, find.byKey(const ValueKey('person-assignment-clear')));
      await tap(t, find.byKey(const ValueKey('person-assignment-b')));
      await tap(t, find.byKey(const ValueKey('person-assignment-apply')));
      await tap(t, find.text('Speichern'));
      final row = c.classroom.single.rows('participants').single;
      expect(row['pupilId'], 'b');
      expect(row['status'], 'received');
      expect(row['note'], 'Bereits da');
      await finish(t);
    },
  );
}
