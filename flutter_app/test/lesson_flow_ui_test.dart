import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/homework_control.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  late NotebookController c;
  setUp(() async {
    c = NotebookController(classroomMemory());
    await c.initialize();
    await c.savePupil(const Pupil(id: 'anna', name: 'Anna Beispiel'));
    await c.savePupil(const Pupil(id: 'ben', name: 'Ben Beispiel'));
    await c.saveRecord(
      SchoolRecord.empty(SchoolKind.homework, 'anna').patch({
        'title': 'Brüche üben',
        'tasks': [
          const HomeworkTask(id: 'a', text: 'Seite 12, Nummer 3').toJson(),
          const HomeworkTask(
            id: 'b',
            text: 'Zusatzaufgabe',
            parentId: 'a',
          ).toJson(),
        ],
      }),
    );
    await c.saveRecord(
      SchoolRecord.empty(SchoolKind.homework, 'ben').patch({
        'title': 'Später abgeben',
        'dueDate': dateOnly(DateTime.now().add(const Duration(days: 4))),
        'tasks': [const HomeworkTask(id: 'future', text: 'Vokabeln').toJson()],
      }),
    );
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  Future<void> app(
    WidgetTester t, {
    double width = 390,
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 844);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    await t.binding.setSurfaceSize(Size(width, 844));
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FlexApp(controller: c),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('page-2')));
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.view.resetViewInsets();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    await t.binding.setSurfaceSize(null);
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder.last);
    await t.pumpAndSettle();
    await t.tap(finder.last);
    await t.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Future<void> capture(WidgetTester t, GlobalKey boundary, String name) async {
    final path = Platform.environment['FLEX_RENDER_DIR'];
    if (path == null) return;
    await t.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(path).createSync(recursive: true);
      File('$path/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'phase editing, running, pausing and progress survive leaving and reopening the app',
    (t) async {
      await app(t);
      expect(c.classroom.where(hasLessonFlow), isEmpty);
      await tap(t, find.byTooltip('Phase hinzufügen'));
      await t.enterText(field('Titel'), 'Lesetraining');
      await t.enterText(
        field('Arbeitsauftrag · optional'),
        'Eine Seite gemeinsam lesen.',
      );
      await t.enterText(field('Dauer · optional'), '15');
      await tap(t, find.text('Speichern'));
      expect(
        lessonPhases(c.classroom.singleWhere(hasLessonFlow)).last.title,
        'Lesetraining',
      );
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('flow-start')),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('lesson-flow')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(t, find.byKey(const ValueKey('flow-start')));
      expect(
        lessonPhases(c.classroom.singleWhere(hasLessonFlow)).first.running,
        isTrue,
      );
      await tap(t, find.text('Pause'));
      expect(
        lessonPhases(c.classroom.singleWhere(hasLessonFlow)).first.running,
        isFalse,
      );
      await tap(t, find.text('Fortsetzen'));
      await tap(t, find.byKey(const ValueKey('flow-next')));
      expect(
        lessonPhases(c.classroom.singleWhere(hasLessonFlow)).first.status,
        'done',
      );
      expect(
        lessonPhases(c.classroom.singleWhere(hasLessonFlow))[1].status,
        'active',
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await c.reload();
      await app(t);
      expect(find.text('Hausübungen kontrollieren'), findsOneWidget);
      expect(
        lessonPhases(c.classroom.singleWhere(hasLessonFlow)).last.title,
        'Lesetraining',
      );
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );
  testWidgets(
    'invalid phase duration retains typed input; cancelling does not persist a phase',
    (t) async {
      await app(t);
      await tap(t, find.byTooltip('Phase hinzufügen'));
      await t.enterText(field('Titel'), 'Meine Phase');
      await t.enterText(field('Dauer · optional'), '-5');
      await tap(t, find.text('Speichern'));
      expect(find.text('Meine Phase'), findsOneWidget);
      expect(find.textContaining('Bitte Titel, Dauer'), findsOneWidget);
      expect(c.classroom.where(hasLessonFlow), isEmpty);
      await tap(t, find.text('Abbrechen'));
      expect(c.classroom.where(hasLessonFlow), isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'homework control filters by due date, keeps checked rows and shares normal task status',
    (t) async {
      await app(t);
      await tap(t, find.text('HÜ-Kontrolle').first);
      expect(find.byType(HomeworkControl), findsOneWidget);
      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.text('Ben Beispiel'), findsNothing);
      await tap(t, find.byKey(const ValueKey('status-a-complete')));
      await tap(t, find.byKey(const ValueKey('status-b-partial')));
      var r = c.records.singleWhere((r) => r.pupilId == 'anna');
      expect(r.taskState(r.tasks[0]), TaskState.complete);
      expect(r.taskState(r.tasks[1]), TaskState.partial);
      await tap(t, find.byKey(const ValueKey('status-b-complete')));
      expect(find.text('Seite 12, Nummer 3'), findsOneWidget);
      expect(find.text('Zusatzaufgabe'), findsOneWidget);
      await tap(t, find.text('Alle Hausübungen'));
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Ben Beispiel'),
        findsOneWidget,
      );
      await t.enterText(
        find.descendant(
          of: find.byType(HomeworkControl),
          matching: find.byType(TextField),
        ),
        'Ben Beispiel',
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(HomeworkControl),
          matching: find.text('Anna Beispiel'),
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Ben Beispiel'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );
  for (final (width, scale) in [(390.0, 1.0), (320.0, 1.8), (768.0, 1.0)]) {
    testWidgets('flow and homework control fit $width at text scale $scale', (
      t,
    ) async {
      final boundary = GlobalKey();
      await app(t, width: width, scale: scale, boundary: boundary);
      await capture(t, boundary, 'flow-$width-$scale');
      expect(t.takeException(), isNull);
      await tap(t, find.text('HÜ-Kontrolle').first);
      await capture(t, boundary, 'homework-control-$width-$scale');
      expect(t.takeException(), isNull);
      await tap(t, find.byTooltip('Schließen').last);
      await t.pump();
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byTooltip('Phase hinzufügen'),
        -180,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('lesson-flow')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(t, find.byTooltip('Phase hinzufügen'));
      await t.enterText(field('Titel'), 'Neue Phase');
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pumpAndSettle();
      await tap(t, find.text('Speichern'));
      expect(
        lessonPhases(c.classroom.singleWhere(hasLessonFlow)).last.title,
        'Neue Phase',
      );
      expect(t.takeException(), isNull);
      await finish(t);
    });
  }
}
