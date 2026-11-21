import 'dart:io';
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
