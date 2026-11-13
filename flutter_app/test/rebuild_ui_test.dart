import 'support/app_test_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/flex_icons.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);

  late SqliteNotebook repo;
  late NotebookController c;
  setUp(() async {
    repo = SqliteNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(Pupil(id: 'alpha', name: 'Testkind Alpha'));
    await c.savePupil(
      Pupil(id: 'beta', name: 'Testkind Beta', color: 0xff9dc9d3),
    );
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });
  Future<void> app(
    WidgetTester tester, {
    Size size = const Size(1100, 950),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(FlexApp(controller: c));
    await tester.pumpAndSettle();
  }

  Future<void> editor(
    WidgetTester tester,
    SchoolRecord record, {
    String mode = 'entry',
    String? taskId,
    SchoolDraft? draft,
  }) async {
    final context = tester.element(find.byType(Scaffold).first);
    // Deliberately leave the route future pending until the interaction closes it.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SchoolEditor(
        controller: c,
        record: record,
        mode: mode,
        taskId: taskId,
        draft: draft,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(null);
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('filled symbols cover all five reference categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final symbol in FlexSymbol.values)
                FlexIcon(symbol, size: 80),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(FlexIcon), findsNWidgets(5));
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
  testWidgets(
    'homework uses direct status buttons and comment gets focus without changing status',
    (tester) async {
      final initial = SchoolRecord.empty(SchoolKind.homework, 'alpha').patch({
        'subject': 'Mathematik',
        'tasks': [
          const HomeworkTask(id: 'task', text: 'Testaufgabe 1').toJson(),
        ],
      });
      await c.saveRecord(initial);
      await app(tester);
      await tester.tap(find.byKey(const ValueKey('page-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('overview-open-${initial.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('status-task-partial')), findsOneWidget);
      final card = find.byType(SchoolRecordCard);
      expect(
        find.descendant(of: card, matching: find.byType(Checkbox)),
        findsNothing,
      );
      for (final state in [
        TaskState.complete,
        TaskState.missing,
        TaskState.open,
        TaskState.partial,
      ]) {
        final button = find.byKey(ValueKey('status-task-${state.name}'));
        await reveal(tester, button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          (await repo.schoolRecords()).single.taskState(initial.tasks.single),
          state,
        );
        if (state == TaskState.missing) {
          expect(find.text('Erneut aufgeben?'), findsOneWidget);
          await tester.tap(find.text('So belassen'));
          await tester.pumpAndSettle();
        }
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('homework-task-details-task')),
      );
      await tester.tap(
        find.byKey(const ValueKey('homework-task-details-task')),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('comment-task')));
      await tester.tap(find.byKey(const ValueKey('comment-task')));
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('homework-comment')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.focusNode.hasFocus, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('homework-comment')),
        'Synthetischer Kommentar',
      );
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      final saved = (await repo.schoolRecords()).single;
      expect(saved.taskState(saved.tasks.single), TaskState.partial);
      expect(
        saved.liveFeedback.where((f) => f.note.isNotEmpty).single.note,
        'Synthetischer Kommentar',
      );
      expect(await repo.schoolDrafts(), isEmpty);
      await finish(tester);
    },
  );
  testWidgets(
    'homework recipients are tags and save separate records atomically',
    (tester) async {
      await app(tester);
      await editor(tester, SchoolRecord.empty(SchoolKind.homework, 'alpha'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Aufgabe …'),
        'Synthetische Gruppenaufgabe',
      );
      final beta = find.byKey(const ValueKey('pupil-tag-beta'));
      await reveal(tester, beta);
      await tester.tap(beta);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(beta).selected, isTrue);
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      final records = await repo.schoolRecords();
      expect(records, hasLength(2));
      expect(records.map((r) => r.pupilId).toSet(), {'alpha', 'beta'});
      expect(records[0].tasks.single.id, isNot(records[1].tasks.single.id));
      await finish(tester);
    },
  );
  testWidgets(
    'closing a comment preserves its own draft and resumes text focus',
    (tester) async {
      final initial = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'alpha').patch({
          'tasks': [
            const HomeworkTask(id: 'task', text: 'Testaufgabe').toJson(),
          ],
        }),
      );
      await c.reload();
      await app(tester);
      await editor(tester, initial, mode: 'comment', taskId: 'task');
      await tester.enterText(
        find.byKey(const ValueKey('homework-comment')),
        'Nicht veröffentlichte Notiz',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect((await repo.schoolRecords()).single.feedback, isEmpty);
      final draft = (await repo.schoolDrafts()).single;
      expect(draft.mode, 'comment');
      await editor(tester, initial, draft: draft);
      expect(find.text('Nicht veröffentlichte Notiz'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('homework-comment')),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      expect(await repo.schoolDrafts(), isEmpty);
      await finish(tester);
    },
  );
  testWidgets(
    'goals and observations use shared modal and preserve field text',
    (tester) async {
      await app(tester);
      await editor(tester, SchoolRecord.empty(SchoolKind.goal, 'alpha'));
      expect(find.byType(FlexModal), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('record-title')),
        'Synthetisches Lernziel',
      );
      await tester.enterText(
        find.byKey(const ValueKey('record-criterion')),
        'Ein überprüfbares Kriterium',
      );
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      expect((await repo.schoolRecords()).single.kind, SchoolKind.goal);
      await editor(tester, SchoolRecord.empty(SchoolKind.social, 'alpha'));
      final body = find.byKey(const ValueKey('record-body'));
      await reveal(tester, body);
      await tester.enterText(body, 'Freier Beobachtungstext');
      await reveal(tester, find.byKey(const ValueKey('tone-positive')));
      await tester.tap(find.byKey(const ValueKey('tone-positive')));
      await tester.pumpAndSettle();
      final selection = find.text('Hilft anderen');
      await reveal(tester, selection);
      await tester.tap(selection);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      final observation = (await repo.schoolRecords()).firstWhere(
        (r) => r.kind == SchoolKind.social,
      );
      expect(observation.body, 'Freier Beobachtungstext');
      expect(observation.positive, ['Hilft anderen']);
      await finish(tester);
    },
  );
  testWidgets(
    'goal review retains target date and requires next review for continue',
    (tester) async {
      final goal = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.goal,
          'alpha',
        ).patch({'title': 'Testziel', 'dueDate': '2026-12-01'}),
      );
      await c.reload();
      await app(tester);
      await editor(tester, goal, mode: 'review');
      await tester.tap(find.textContaining('Nächste Überprüfung:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datum entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      expect(
        find.text('Fortführen benötigt einen nächsten Prüftermin.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ziel erreicht'));
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      final saved = (await repo.schoolRecords()).single;
      expect(saved.goalStatus, 'achieved');
      expect(saved.dueDate, '2026-12-01');
      expect(saved.reviews, hasLength(1));
      await finish(tester);
    },
  );
  testWidgets(
    'mobile homework modal and keyboard remain usable at 320 pixels',
    (tester) async {
      await app(tester, size: const Size(320, 700));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await editor(tester, SchoolRecord.empty(SchoolKind.homework, 'alpha'));
      expect(tester.takeException(), isNull);
      final task = find.widgetWithText(TextFormField, 'Aufgabe …');
      await reveal(tester, task);
      await tester.enterText(task, 'Kleine Ansicht');
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-school-record')),
      );
      await tester.tap(find.byKey(const ValueKey('save-school-record')));
      await tester.pumpAndSettle();
      expect(await repo.schoolRecords(), hasLength(1));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await finish(tester);
    },
  );
  testWidgets('calendar preserves midnight separately from no time', (
    tester,
  ) async {
    await app(tester);
    final context = tester.element(find.byType(Scaffold).first);
    final result = pickFlexDate(context, date: '2026-11-01', time: '00:00');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(await result, ('2026-11-01', '00:00'));
    final noTime = pickFlexDate(context, date: '2026-11-01');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(await noTime, ('2026-11-01', ''));
    await finish(tester);
  });
  testWidgets('synthetic direct Flutter render of the homework modal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    final boundary = GlobalKey();
    final saved = await repo.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.homework, 'alpha').patch({
        'subject': 'Mathematik',
        'tasks': [
          const HomeworkTask(id: 'task', text: 'Übungsaufgabe A').toJson(),
        ],
      }),
    );
    await c.reload();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FlexApp(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    final directory = Platform.environment['FLEX_RENDER_DIR'];
    if (directory != null) {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(directory).createSync(recursive: true);
        File(
          '$directory/homework-desktop.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await editor(tester, saved, mode: 'comment', taskId: 'task');
    expect(find.byType(FlexModal), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await finish(tester);
  });
}
