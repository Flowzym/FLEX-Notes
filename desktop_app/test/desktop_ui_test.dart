import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_desktop/main.dart';
import 'package:flex_desktop/application/workspace_controller.dart';
import 'package:flex_desktop/application/editor_session.dart';
import 'package:flex_desktop/domain/core.dart';
import 'workspace_test.dart' show MemoryFiles;

void main() {
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
