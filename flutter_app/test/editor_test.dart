import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/ui/app.dart';

void main() {
  testWidgets(
    'class Orga can be entered, saved, reopened and completed without browser',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final controller = NotebookController(repo);
      await controller.initialize();
      await tester.pumpWidget(FlexApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Klassen-Orga anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Synthetische Klassenaufgabe',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(
        (await repo.entries()).single.title,
        'Synthetische Klassenaufgabe',
      );
      await tester.tap(find.byTooltip('Bearbeiten'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Bearbeitete Testaufgabe',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erledigen'));
      await tester.pumpAndSettle();
      expect((await repo.entries()).single.done, isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await repo.close();
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'closing secures an unpublished draft, including a pending checklist input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1400));
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final controller = NotebookController(repo);
      await controller.initialize();
      await tester.pumpWidget(FlexApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Klassen-Orga anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Entwurf Test',
      );
      await tester.tap(find.text('☐ Checkliste'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Neuer Listenpunkt'),
        'Noch nicht hinzugefügter Testpunkt',
      );
      await tester.tap(find.byTooltip('Schließen und Eingaben sichern').last);
      await tester.pumpAndSettle();
      expect(await repo.entries(), isEmpty);
      final draft = (await repo.drafts()).single;
      expect(draft.entry.title, 'Entwurf Test');
      expect(
        draft.entry.items.single.text,
        'Noch nicht hinzugefügter Testpunkt',
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await repo.close();
      await tester.binding.setSurfaceSize(null);
    },
  );
}
