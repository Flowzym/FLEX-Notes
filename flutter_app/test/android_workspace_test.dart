import 'package:flex_notizbuch/ui/lesson_flow_page.dart';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/week_folder.dart';
import 'package:flex_notizbuch/services/week_pdf.dart';
import 'package:flex_notizbuch/services/material_import.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/notebook_search.dart';
import 'package:flex_notizbuch/ui/week_folder_page.dart';
import 'classroom_test.dart' show classroomMemory, lesson, returns;
import 'material_workspace_test.dart' show MemoryMaterialFiles, material;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NotebookController c;
  setUp(() async {
    c = NotebookController(classroomMemory());
    await c.initialize();
    await c.savePupil(const Pupil(id: 'p', name: 'Ada'));
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  test(
    'the week crosses the year, optional weekends and the PDF include daily files and assignments',
    () async {
      final shared = await c.repository.saveClassroomDocument(
        material(
          'Brüche üben',
          fields: {
            'pupilIds': ['p'],
          },
        ),
      );
      await c.saveClassroom(
        prepareMaterials(c.classroom, '2027-01-01', [shared.id]),
      );
      await c.saveClassroom(lesson(date: '2027-01-01'));
      await c.saveClassroom(returns('p', due: '2027-01-02'));
      final day = DateTime(2027, 1, 2),
          week = buildWeekFolder(c.currentSnapshot, day);
      expect(week.map((d) => dateOnly(d.day)), [
        '2026-12-28',
        '2026-12-29',
        '2026-12-30',
        '2026-12-31',
        '2027-01-01',
      ]);
      expect(week.last.agenda.single.title, 'Mathematik');
      expect(week.last.materials.single.id, shared.id);
      final full = buildWeekFolder(c.currentSnapshot, day, weekends: true);
      expect(full[5].agenda.single.category, 'return');
      expect(
        materialDayOwners(shared, '2027-01-01', (id) => id == 'p' ? 'Ada' : ''),
        'Ada',
      );
      final pdf = await weekFolderPdf(
        full,
        (id) => 'Ada',
        pupils: c.pupils,
        grouped: true,
      );
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
    },
  );
  test(
    'copy preserves plan contents, resets classroom progress and protects an existing target',
    () {
      final doc = lessonFlowFor(
        [],
        '2026-11-17',
      ).patch({'subject': 'Lesen', 'note': 'Für morgen'});
      final running = activateLessonPhase(
        doc,
        lessonPhases(doc).first.id,
        DateTime.utc(2026, 11, 17, 9),
      );
      final copy = copyTeachingPlan(running, [running], date: '2026-11-18');
      expect(copy.text('status'), 'planned');
      expect(copy.text('note'), 'Für morgen');
      expect(
        lessonPhases(copy).map((p) => p.title),
        lessonPhases(doc).map((p) => p.title),
      );
      expect(
        lessonPhases(copy).every((p) => p.status == 'open' && p.elapsed == 0),
        isTrue,
      );
      expect(copy.id, isNot(doc.id));
      expect(
        () => copyTeachingPlan(doc, [doc, copy], date: '2026-11-18'),
        throwsA(isA<DomainError>()),
      );
      final regular = ClassroomDocument.create(ClassroomKind.plan, 'Rechnen', {
        'pupilIds': ['p'],
        'materialIds': ['m'],
        'status': 'done',
      });
      final next = copyTeachingPlan(regular, [regular]);
      expect(next.strings('materialIds'), ['m']);
      expect(next.strings('pupilIds'), ['p']);
      expect(next.text('status'), 'planned');
    },
  );
  test(
    'local multi-import commits together, assigns the selected pupil and rolls back incomplete batches',
    () async {
      final files = MemoryMaterialFiles();
      XFile pdf(String name) => XFile.fromData(
        Uint8List.fromList(ascii.encode('%PDF-example')),
        path: name,
        name: name,
      );
      final list = await importLocalMaterials(
        [pdf('A.pdf'), pdf('B.pdf')],
        c.repository,
        files,
        pupilId: 'p',
      );
      expect(list.length, 2);
      expect(list.every((d) => d.strings('pupilIds').single == 'p'), isTrue);
      final ids = files.values.keys.toSet();
      await expectLater(
        importLocalMaterials(
          [
            pdf('C.pdf'),
            XFile.fromData(
              Uint8List(5),
              path: 'broken.pdf',
              name: 'broken.pdf',
            ),
          ],
          c.repository,
          files,
        ),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        importLocalMaterials(
          List.generate(26, (i) => pdf('$i.pdf')),
          c.repository,
          files,
        ),
        throwsA(isA<DomainError>()),
      );
      expect(files.values.keys.toSet(), ids);
      expect(
        (await c.repository.classroomDocuments())
            .where((d) => d.kind == ClassroomKind.material)
            .length,
        2,
      );
    },
  );
  testWidgets(
    'work and individual instructions are visible in teaching order without starting the live flow',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(360, 760);
      addTearDown(t.view.reset);
      final seed = lessonFlowFor([], '2026-11-18');
      final stored = withLessonPhases(seed, [
        const LessonPhase(
          id: 'lesen',
          title: 'Lesezeit',
          body: 'Die erste Seite lesen und zwei Wörter markieren.',
          guidance: [
            {
              'pupilIds': ['p'],
              'body': 'Die Bildkarten ordnen.',
              'minutes': 0,
              'materialIds': <String>[],
            },
          ],
        ),
        const LessonPhase(
          id: 'runde',
          title: 'Rückblick',
          body: 'Das markierte Wort vorstellen.',
        ),
      ]);
      await c.saveClassroom(
        activateLessonPhase(stored, 'runde', DateTime.utc(2026, 11, 18)),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonFlowPage(
              controller: c,
              initialDate: '2026-11-18',
              initialTarget: '',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Die erste Seite lesen und zwei Wörter markieren.'),
        findsOneWidget,
      );
      expect(find.text('Die Bildkarten ordnen.'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Lesezeit')).dy,
        lessThan(t.getTopLeft(find.text('Rückblick')).dy),
      );
      expect(find.byKey(const ValueKey('flow-next')), findsNothing);
      expect(find.byKey(const ValueKey('flow-start')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'global search opens a destination on a phone and resolves a pupil material from its metadata',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(360, 780);
      addTearDown(t.view.reset);
      await c.saveClassroom(
        material(
          'Arbeitsblatt',
          fields: {
            'pupilIds': ['p'],
            'subject': 'Mathematik',
          },
        ),
      );
      expect(
        notebookSearchIndex(c).any(
          (h) =>
              h.title == 'Arbeitsblatt' &&
              ['ada', 'mathematik'].every(h.terms.contains),
        ),
        isTrue,
      );
      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyK);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Wochenmappe');
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Wochenmappe'));
      await t.pumpAndSettle();
      expect(find.byType(WeekFolderPage), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('overdue status combines with returns, tasks and text search', (
    t,
  ) async {
    for (final date in ['2001-01-01', '2099-12-31']) {
      await c.saveClassroom(
        returns('p', due: date).patch({
          'title': date.startsWith('200') ? 'Alt Ausflug' : 'Neu Ausflug',
        }),
      );
    }
    await c.saveEntry(
      OrgaEntry.empty().copyWith(
        title: 'Bus reservieren',
        body: 'Bus reservieren',
        isTask: true,
        dueDate: '2001-01-01',
      ),
    );
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    Future<void> tap(Finder f) async {
      await t.ensureVisible(f);
      await t.tap(f);
      await t.pumpAndSettle();
    }

    await tap(find.byKey(const ValueKey('bottom-2')));
    await tap(find.byKey(const ValueKey('context-2-0')));
    await tap(find.text('Überfällig').last);
    await tap(find.byKey(const ValueKey('general-type-all-returns')));
    await tap(find.byKey(const ValueKey('general-search-button-all')));
    await t.enterText(
      find.byKey(const ValueKey('general-search-all')),
      'Ausflug',
    );
    await t.pumpAndSettle();
    expect(find.text('Alt Ausflug'), findsOneWidget);
    expect(find.text('Neu Ausflug'), findsNothing);
    expect(find.text('Bus reservieren'), findsNothing);
  });
}
