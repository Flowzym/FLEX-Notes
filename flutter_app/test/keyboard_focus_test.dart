import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/app_scale.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/pupil_editor.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';

void main() {
  for (final scale in [0.8, 1.0, 1.2]) {
    testWidgets('keyboard resize keeps input connection at scale $scale', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              FlexAppScale(scale: scale, textScale: 1, child: child!),
          home: const Scaffold(body: SizedBox()),
        ),
      );
      unawaited(
        showDialog<void>(
          context: t.element(find.byType(Scaffold)),
          builder: (_) => const FlexModal(
            title: Text('Eingabe'),
            content: TextField(key: ValueKey('input'), maxLines: 3),
          ),
        ),
      );
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('input'));
      await t.showKeyboard(field);
      const value = TextEditingValue(
        text: 'Grüße aus der Testapp',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      );
      t.testTextInput.updateEditingValue(value);
      await t.pump();
      final editable = find.byType(EditableText);
      final state = t.state<EditableTextState>(editable);
      expect(state.widget.focusNode.hasFocus, isTrue);
      t.testTextInput.log.clear();
      // Cross the modal's 520 px layout threshold during the IME animation,
      // including closing, reopening and changing the keyboard's height.
      for (final inset in [80.0, 200.0, 320.0, 460.0, 280.0, 0.0, 460.0]) {
        t.view.viewInsets = FakeViewPadding(bottom: inset);
        await t.pumpAndSettle();
        expect(
          t.state<EditableTextState>(editable),
          same(state),
          reason: 'keyboard inset $inset',
        );
        expect(state.widget.focusNode.hasFocus, isTrue);
        expect(t.testTextInput.isVisible, isTrue);
        expect(state.widget.controller.value, value);
        expect(
          t.testTextInput.log.where((c) => c.method == 'TextInput.hide'),
          isEmpty,
        );
        expect(t.takeException(), isNull);
      }
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Grüße – weitergeschrieben',
          selection: TextSelection.collapsed(offset: 24),
        ),
      );
      await t.pump();
      expect(state.widget.controller.text, 'Grüße – weitergeschrieben');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }

  for (final section in ['header', 'footer']) {
    testWidgets('keyboard preserves a focused $section field', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      const field = TextField(key: ValueKey('section-input'));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlexModal(
              title: const Text('Eingabe'),
              headerContent: section == 'header' ? field : null,
              content: const Text('Dialoginhalt'),
              footerContent: section == 'footer' ? field : null,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.showKeyboard(find.byKey(const ValueKey('section-input')));
      final state = t.state<EditableTextState>(find.byType(EditableText));
      for (final inset in [350.0, 0.0, 350.0]) {
        t.view.viewInsets = FakeViewPadding(bottom: inset);
        await t.pumpAndSettle();
        expect(
          t.state<EditableTextState>(find.byType(EditableText)),
          same(state),
        );
        expect(state.widget.focusNode.hasFocus, isTrue);
        expect(t.testTextInput.isVisible, isTrue);
      }
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }

  for (final area in ['pupil', 'orga', 'social', 'work', 'goal', 'homework']) {
    testWidgets('$area: type through keyboard resize and autosave, then save', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final c = NotebookController(repo);
      await c.initialize();
      await c.savePupil(
        const Pupil(id: 'p', name: 'Anna Beispiel', color: 0xff53747e),
      );
      addTearDown(() async {
        c.dispose();
        await repo.close();
      });
      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      final kind = SchoolKind.values.where((k) => k.name == area).firstOrNull;
      final record = kind == null ? null : SchoolRecord.empty(kind, 'p');
      final editor = switch (area) {
        'pupil' => PupilEditor(controller: c),
        'orga' => OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(pupilId: 'p'),
        ),
        _ => SchoolEditor(controller: c, record: record!),
      };
      unawaited(
        showDialog<void>(
          context: t.element(find.byType(Scaffold)),
          builder: (_) => editor,
        ),
      );
      await t.pumpAndSettle();
      final field = switch (area) {
        'pupil' =>
          find
              .descendant(
                of: find.byType(PupilEditor),
                matching: find.byType(TextField),
              )
              .first,
        'orga' => find.byKey(const ValueKey('orga-note')),
        'goal' => find.byKey(const ValueKey('record-title')),
        'homework' =>
          find
              .descendant(
                of: find.byType(SchoolEditor),
                matching: find.byType(TextFormField),
              )
              .first,
        _ => find.byKey(const ValueKey('record-body')),
      };
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.showKeyboard(field);
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      final state = t.state<EditableTextState>(editable);
      t.testTextInput.log.clear();
      for (final inset in [180.0, 320.0, 0.0, 350.0]) {
        t.view.viewInsets = FakeViewPadding(bottom: inset);
        await t.pumpAndSettle();
        expect(t.state<EditableTextState>(editable), same(state));
        expect(state.widget.focusNode.hasFocus, isTrue);
        expect(t.testTextInput.isVisible, isTrue);
        final text = 'Eingabe $area bei $inset';
        // Do not use enterText here: it would request focus again and hide
        // the regression. Deliver input over the existing IME connection.
        t.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );
        await t.pump(const Duration(milliseconds: 650));
        await t.pumpAndSettle();
        expect(state.widget.controller.text, text);
        expect(state.widget.focusNode.hasFocus, isTrue);
        expect(
          t.testTextInput.log.where((c) => c.method == 'TextInput.hide'),
          isEmpty,
        );
      }
      final save = switch (area) {
        'pupil' => find.widgetWithText(FilledButton, 'Hinzufügen'),
        'orga' => find.widgetWithText(FilledButton, 'Speichern'),
        _ => find.byKey(const ValueKey('save-school-record')),
      };
      await t.ensureVisible(save);
      await t.pumpAndSettle();
      await t.tap(save);
      await t.pumpAndSettle();
      expect(find.byType(editor.runtimeType), findsNothing);
      final expected = 'Eingabe $area bei 350.0';
      if (area == 'pupil') {
        expect(c.pupils.any((p) => p.name == expected), isTrue);
      } else if (area == 'orga') {
        expect(c.entries.single.title, expected);
      } else {
        final saved = c.records.single;
        expect(switch (kind!) {
          SchoolKind.goal => saved.title,
          SchoolKind.homework => saved.tasks.single.text,
          _ => saved.body,
        }, expected);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }
}
