import 'dart:io';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/teaching_sheet.dart';
import 'package:flex_notizbuch/ui/observation_tone_colors.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/return_lists.dart' show ReturnDetail;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_desktop/main.dart';
import 'package:flex_desktop/application/workspace_controller.dart';
import 'package:flex_desktop/application/editor_session.dart';
import 'package:flex_desktop/domain/core.dart';
import 'workspace_test.dart' show MemoryFiles;

void main() {
  testWidgets(
    'Unterricht zeigt die verwendete Quelle, kennzeichnet Vergleiche und öffnet die Quellzeile',
    (t) async {
      t.view.physicalSize = const Size(1480, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      const day = '2026-11-23';
      ClassroomDocument doc(String id) {
        final m = ClassroomDocument.create(
          ClassroomKind.material,
          '$id Tagesplanung.docx',
          {
            'extension': 'docx',
            'driveId': 'drive',
            'itemId': id,
            'url': 'https://example.org/$id.docx',
            'planning': {
              'use': 'dayPlan',
              'day': day,
              'week': day,
              'year': '2026-27',
            },
          },
          id: id,
        );
        return m.patch({
          'planSheet': {
            'drive': 'drive',
            'item': id,
            'stamp': sourceStamp(m),
            'parser': 2,
            'rows': [
              for (final i in [1, 2])
                {
                  'id': '$id-$i',
                  'line': 'Quelle $id Zeile $i',
                  'raw': 'Original $id $i',
                  'type': 'phase',
                  'phase': 'Phase $i',
                  'time': i == 1 ? '08:00–08:15' : '08:15–08:30',
                  'task': 'Auftrag $id $i',
                },
            ],
          },
        });
      }

      final a = doc('A'), b = doc('B');
      final f = lessonFlowFor([a, b], day, chosenSource: b);
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final n = NotebookController(repo);
      await t.runAsync(() async {
        await n.initialize();
        await n.saveClassroomBatch([
          a,
          b,
          activateLessonPhase(
            f,
            lessonPhases(f).last.id,
            DateTime.utc(2026, 11, 23, 8, 15),
          ),
        ]);
      });
      final c = WorkspaceController(n, files: MemoryFiles())
        ..setDate(DateTime.parse(day))
        ..navigate(WorkspaceSection.week);
      await t.pumpWidget(DesktopApp(controller: c));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Unterrichtsablauf öffnen'));
      await t.pumpAndSettle();
      final dropdown = find.byType(DropdownButton<String>);
      expect(t.widget<DropdownButton<String>>(dropdown).value, 'B');
      await t.tap(dropdown);
      await t.pumpAndSettle();
      await t.tap(find.text('A Tagesplanung.docx').last);
      await t.pumpAndSettle();
      expect(find.text('Vergleichsdokument'), findsOneWidget);
      await t.tap(find.byTooltip('Zur verwendeten Quelle'));
      await t.pumpAndSettle();
      expect(t.widget<DropdownButton<String>>(dropdown).value, 'B');
      final line = find.text('Planzeile öffnen');
      await t.ensureVisible(line.first);
      await t.tap(line.first);
      await t.pumpAndSettle();
      expect(find.text('Quelle B Zeile 2'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      n.dispose();
      await t.runAsync(repo.close);
    },
  );
  testWidgets(
    'Wochenmappe wechselt nach dem Scrollen zu einer älteren Woche und einem leeren Tag',
    (t) async {
      t.view.physicalSize = const Size(1480, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final n = NotebookController(repo), files = MemoryFiles();
      final nov = DateTime(2026, 11, 18), sept = DateTime(2026, 9, 30);
      final entries = [
        for (var i = 0; i < 20; i++)
          ClassroomDocument.create(ClassroomKind.material, 'Datei $i', {
            'extension': 'pdf',
            'url': 'https://example.org/$i.pdf',
          }),
      ];
      await t.runAsync(() async {
        await n.initialize();
        await repo.saveClassroomDocuments([
          ...entries,
          prepareMaterials(
            [],
            dateOnly(nov),
            entries.map((m) => m.id).toList(),
          ),
          ClassroomDocument.create(
            ClassroomKind.material,
            'Septemberwoche.docx',
            {
              'extension': 'docx',
              'url': 'https://example.org/september.docx',
              'planning': {
                'use': 'weekPlan',
                'day': '',
                'week': '2026-09-28',
                'year': '2026-27',
              },
            },
          ),
        ]);
        await n.reload();
      });
      final c = WorkspaceController(n, files: files)
        ..setDate(nov)
        ..navigate(WorkspaceSection.week);
      await t.pumpWidget(DesktopApp(controller: c));
      await t.pumpAndSettle();
      final list = find.byKey(const PageStorageKey('week-folder'));
      final position = t
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      position.jumpTo(140);
      await t.pumpAndSettle();
      position.jumpTo(0);
      await t.pumpAndSettle();
      await t.runAsync(() => c.edit(entries.first));
      await t.pumpAndSettle();
      expect(find.text('Dokumentvorschau'), findsOneWidget);
      c.setDate(sept);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Wochenschwerpunkt'), findsOneWidget);
      expect(find.text('Dokumentvorschau'), findsNothing);
      await t.tap(find.text('Wochenschwerpunkt'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Vorherige Woche'));
      await t.pumpAndSettle();
      expect(
        find.text('Für diesen Tag sind keine Unterlagen bereitgelegt.'),
        findsOneWidget,
      );
      expect(find.text('Sa'), findsNothing);
      await t.tap(find.byKey(const ValueKey('week-folder-weekends')));
      await t.pumpAndSettle();
      expect(find.text('Sa'), findsOneWidget);
      await t.tap(find.text('So'));
      await t.pumpAndSettle();
      expect(c.date.weekday, DateTime.sunday);
      await t.tap(find.byKey(const ValueKey('week-folder-weekends')));
      await t.pumpAndSettle();
      expect(c.date.weekday, DateTime.friday);
      expect(find.text('So'), findsNothing);
      await t.runAsync(n.reload);
      expect(n.appearance.weekFolderWeekends, isFalse);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      n.dispose();
      await t.runAsync(repo.close);
    },
  );

  testWidgets(
    'Journal findet zugewiesene Dateien aus Unterordnern und wechselt den Vorschaukontext',
    (t) async {
      t.view.physicalSize = const Size(1480, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final n = NotebookController(repo);
      final a = ClassroomDocument.create(ClassroomKind.material, 'Schachzüge', {
        'url': 'https://example.org/a',
        'extension': 'pdf',
        'sourcePath': 'FLEX/Unterricht/Schach/Blatt.pdf',
        'pupilIds': ['a'],
        'pupilDates': [
          {'pupilId': 'a', 'date': '2026-11-18'},
        ],
      });
      await t.runAsync(() async {
        await n.initialize();
        await n.savePupil(const Pupil(id: 'a', name: 'Kind A'));
        await n.savePupil(const Pupil(id: 'b', name: 'Kind B'));
        await n.saveClassroom(a);
      });
      final c = WorkspaceController(n, files: MemoryFiles())
        ..navigate(WorkspaceSection.journal)
        ..selectPupil('a');
      await t.pumpWidget(DesktopApp(controller: c));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, 'Materialien'));
      await t.pumpAndSettle();
      await t.tap(find.text('FLEX / Unterricht / Schach'));
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey('assigned-file-${a.id}')), findsOneWidget);
      await t.tap(find.text('Schachzüge'));
      await t.pumpAndSettle();
      expect(find.text('Dokumentvorschau'), findsOneWidget);
      await t.tap(find.text('Kind B'));
      await t.pumpAndSettle();
      expect(find.text('Schachzüge'), findsNothing);
      expect(find.text('Dokumentvorschau'), findsNothing);
      expect(
        find.text('Keine zugewiesenen Materialien in dieser Ansicht.'),
        findsOneWidget,
      );
      c.navigate(WorkspaceSection.materials);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('material-layout')));
      await t.pumpAndSettle();
      await t.tap(
        find.widgetWithText(CheckedPopupMenuItem<MaterialLayout>, 'Kacheln'),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const PageStorageKey('desk-material-grid')),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('Alle sichtbaren Materialien auswählen'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('material-layout')));
      await t.pumpAndSettle();
      await t.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<MaterialLayout>,
          'Kompaktliste',
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('1 ausgewählt'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      n.dispose();
      await t.runAsync(repo.close);
    },
  );

  testWidgets(
    'organisation filters are independent and a return can be reopened from the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final n = NotebookController(repo);
      await tester.runAsync(() async {
        await n.initialize();
        await n.savePupil(Pupil(id: 'alpha', name: 'Testkind Alpha'));
        await n.saveClassroom(
          ClassroomDocument.create(ClassroomKind.returnList, 'Museumsliste', {
            'type': 'consent',
            'dueDate': '2020-01-01',
            'participants': [
              {
                'pupilId': 'alpha',
                'name': 'Testkind Alpha',
                'status': 'open',
                'note': '',
                'paid': 0,
              },
            ],
          }),
        );
      });
      final c = WorkspaceController(n, files: MemoryFiles())
        ..navigate(WorkspaceSection.organization);
      await tester.pumpWidget(DesktopApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rückläufe'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Überfällig'));
      await tester.pumpAndSettle();
      expect(find.text('Museumsliste'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Erledigt'));
      await tester.pumpAndSettle();
      expect(find.text('Keine passenden Einträge'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Suchen und öffnen'),
        'Alpha Museum',
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Museumsliste'), findsWidgets);
      expect(find.byType(ReturnDetail), findsOneWidget);
      expect(find.text('Testkind Alpha'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      n.dispose();
      await tester.runAsync(repo.close);
    },
  );

  testWidgets(
    'Zentraler Plusbutton öffnet vollständige Beobachtung mit Farbe, Zuordnung und Speicherung',
    (t) async {
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final n = NotebookController(repo);
      await t.runAsync(() async {
        await n.initialize();
        await n.savePupil(const Pupil(id: 'p1', name: 'Person Eins'));
        await n.savePupil(const Pupil(id: 'p2', name: 'Person Zwei'));
      });
      final c = WorkspaceController(n, files: MemoryFiles());
      await t.pumpWidget(DesktopApp(controller: c));
      await t.pumpAndSettle();
      final fab = find.byKey(const ValueKey('desktop-add'));
      final rect = t.getRect(fab);
      expect(rect.right, closeTo(1440 - 390 - 20, 2));
      expect(rect.bottom, closeTo(880, 2));
      await t.tap(fab);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(MenuItemButton, 'Sozialverhalten'));
      await t.pumpAndSettle();
      await t.tap(find.text('Person Zwei').last);
      await t.pumpAndSettle();
      expect(find.byType(SchoolEditor), findsOneWidget);
      expect(find.text('Person Zwei'), findsWidgets);
      await t.tap(find.byKey(const ValueKey('tone-negative')));
      await t.pumpAndSettle();
      final negative = t.widget<TextButton>(
        find.byKey(const ValueKey('tone-negative')),
      );
      expect(
        negative.style!.backgroundColor!.resolve({}),
        observationToneColors['negative'],
      );
      await t.tap(find.byTooltip('Beobachtungen bearbeiten'));
      await t.pumpAndSettle();
      await t.tap(find.text('Nur für Person Zwei'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('new-personal-negative-0')),
        'Eigenes Beispiel',
      );
      await t.tap(find.text('Änderungen speichern'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('observation-Eigenes Beispiel')),
        findsOneWidget,
      );
      expect(
        (await t.runAsync(
          () => repo.observationCatalog('social-negative@p1'),
        ))!.options,
        isEmpty,
      );
      expect(
        (await t.runAsync(
          () => repo.observationCatalog('social-negative'),
        ))!.options,
        isNot(contains('Eigenes Beispiel')),
      );
      await t.tap(
        find.byKey(const ValueKey('observation-Unterbricht andere wiederholt')),
      );
      await t.pump();
      expect(find.text('Scannen / Foto'), findsWidgets);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyS);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      await t.runAsync(repo.snapshot);
      await t.pumpAndSettle();
      expect(find.byType(SchoolEditor), findsNothing);
      final saved = (await t.runAsync(repo.schoolRecords))!.single;
      expect(saved.pupilId, 'p2');
      expect(saved.negative, ['Unterbricht andere wiederholt']);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      c.dispose();
      n.dispose();
      await t.runAsync(repo.close);
    },
  );
  for (final size in [const Size(1440, 960), const Size(1024, 768)]) {
    testWidgets('all desktop workspaces and entry forms fit ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final notebook = NotebookController(repo);
      final c = WorkspaceController(notebook, files: MemoryFiles());
      await tester.runAsync(() async {
        await notebook.initialize();
        await notebook.savePupil(Pupil(id: 'alpha', name: 'Testkind Alpha'));
        await notebook.savePupil(Pupil(id: 'beta', name: 'Testkind Beta'));
      });
      await tester.pumpWidget(DesktopApp(controller: c));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final section in WorkspaceSection.values) {
        c.navigate(section);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: section.name);
      }
      for (final kind in EntryKind.values) {
        await tester.runAsync(() => c.start(kind, pupil: 'alpha'));
        await tester.pumpAndSettle();
        expect(find.text(kind.label).last, findsOneWidget);
        expect(tester.takeException(), isNull, reason: kind.name);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      c.dispose();
      notebook.dispose();
      await tester.runAsync(repo.close);
    });
  }
  testWidgets('an editor stays open while changing the main workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = SqliteNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    final n = NotebookController(repo);
    await tester.runAsync(n.initialize);
    final c = WorkspaceController(n, files: MemoryFiles());
    await tester.runAsync(() => c.start(EntryKind.note));
    await tester.pumpWidget(DesktopApp(controller: c));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Titel'),
      'Bleibt beim Bereichswechsel',
    );
    await tester.runAsync(() => c.editor!.flush());
    c.navigate(WorkspaceSection.calendar);
    await tester.pumpAndSettle();
    expect(find.text('Bleibt beim Bereichswechsel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => c.editor!.flush());
    expect(
      (await tester.runAsync(repo.drafts))!.single.entry.title,
      'Bleibt beim Bereichswechsel',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    c.dispose();
    n.dispose();
    await tester.runAsync(repo.close);
  });
}
