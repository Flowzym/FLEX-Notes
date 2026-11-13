import 'support/app_test_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:flex_notizbuch/ui/compact_switch.dart';
import 'dart:async';
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
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/domain/observation_catalog.dart';
import 'package:flex_notizbuch/ui/option_bar.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteNotebook repo;
  late NotebookController c;
  setUpAll(loadAppTestFonts);
  setUp(() async {
    repo = SqliteNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(
      const Pupil(id: 'a', name: 'Anna Beispiel', color: 0xff53747e),
    );
    await c.savePupil(
      const Pupil(id: 'b', name: 'Ben Beispiel', color: 0xff756582),
    );
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });
  Future<void> app(
    WidgetTester t, {
    Size size = const Size(390, 1000),
    double font = 1,
    GlobalKey? boundary,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    t.platformDispatcher.textScaleFactorTestValue = font;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FlexApp(controller: c),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isEmpty &&
        find.byKey(const PageStorageKey('settings')).evaluate().isNotEmpty) {
      await t.scrollUntilVisible(
        finder,
        -400,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('settings')),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 80,
      );
    }
    if (finder.evaluate().isEmpty) {
      final list = find
          .descendant(
            of: find.byKey(const PageStorageKey('overview')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        finder,
        finder.describeMatch(Plurality.one).contains('overview-section')
            ? -250
            : 250,
        scrollable: list,
      );
    }
    await t.ensureVisible(finder.last);
    await t.pumpAndSettle();
    await t.tap(finder.last);
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t, Widget dialog) async {
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold)),
        barrierDismissible: false,
        builder: (_) => dialog,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    final dir = Platform.environment['FLEX_RENDER_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final editing in [false, true]) {
    testWidgets(
      'Orga ${editing ? 'saved pupil entry' : 'new class entry'}: swipes retain text, checklist and focus across kinds',
      (t) async {
        var entry = OrgaEntry.empty(pupilId: editing ? 'a' : null).copyWith(
          title: 'Planung',
          body: 'Planung',
          items: const [CheckItem(id: 'check', text: 'Unterlagen')],
        );
        if (editing) {
          await c.saveEntry(entry);
          entry = (await repo.entries()).single;
        }
        await app(t);
        await open(t, OrgaEditor(controller: c, entry: entry));
        await tap(t, find.byKey(const ValueKey('orga-kind-note')));
        final bar = find.byKey(const ValueKey('orga-kind-bar'));
        await t.drag(bar, const Offset(-110, 0));
        await t.pumpAndSettle();
        expect(t.widget<OptionBar>(bar).value, 'task');
        final body = find.byKey(const ValueKey('orga-note'));
        await t.ensureVisible(body);
        await t.enterText(body, 'Planung bleibt erhalten');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        final editable = find.descendant(
          of: body,
          matching: find.byType(EditableText),
        );
        final state = t.state<EditableTextState>(editable);
        t.testTextInput.log.clear();
        for (final step in [
          ('appointment', -110.0),
          if (editing) ('appointment', -110.0),
          ('task', 110.0),
          ('note', 110.0),
          ('note', 110.0),
        ]) {
          await t.ensureVisible(body);
          await t.pumpAndSettle();
          await t.drag(editable, Offset(step.$2, 0));
          await t.pumpAndSettle();
          expect(t.widget<OptionBar>(bar).value, step.$1);
          expect(t.state<EditableTextState>(editable), same(state));
          expect(state.widget.focusNode.hasFocus, isTrue);
          expect(state.widget.controller.text, 'Planung bleibt erhalten');
          expect(
            find.byKey(const ValueKey('orga-appointment-date')),
            step.$1 == 'appointment' ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Aufgabe erledigt'),
            step.$1 == 'task' ? findsOneWidget : findsNothing,
          );
        }
        expect(
          t.testTextInput.log.where((e) => e.method == 'TextInput.hide'),
          isEmpty,
        );
        final item = find.byKey(const ValueKey('orga-item-check'));
        await t.ensureVisible(item);
        await t.enterText(item, 'Unterlagen bleiben erhalten');
        await t.pumpAndSettle();
        for (final kind in ['task', 'appointment']) {
          await t.ensureVisible(item);
          await t.pumpAndSettle();
          await t.drag(
            find.descendant(of: item, matching: find.byType(EditableText)),
            const Offset(-90, 0),
          );
          await t.pumpAndSettle();
          expect(t.widget<OptionBar>(bar).value, kind);
        }
        await tap(t, find.text('Speichern'));
        final saved = (await repo.entries()).single;
        expect(saved.isAppointment, isTrue);
        expect(saved.isTask, isFalse);
        expect(saved.body, 'Planung bleibt erhalten');
        expect(saved.items.single.text, 'Unterlagen bleiben erhalten');
        expect(saved.pupilId, editing ? 'a' : null);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  for (final kind in [SchoolKind.social, SchoolKind.work]) {
    testWidgets(
      '${kind.name}: text swipes move once and keep input, tags and keyboard focus',
      (t) async {
        await app(t);
        await open(
          t,
          SchoolEditor(controller: c, record: SchoolRecord.empty(kind, 'a')),
        );
        final neutral = observationDefaults['${kind.name}-neutral']!.first;
        await tap(t, find.byKey(ValueKey('observation-$neutral')));
        final body = find.byKey(const ValueKey('record-body'));
        await t.ensureVisible(body);
        await t.enterText(body, 'Unveränderter Beobachtungstext');
        final editable = find.descendant(
          of: body,
          matching: find.byType(EditableText),
        );
        final state = t.state<EditableTextState>(editable);
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        t.testTextInput.log.clear();
        for (final step in [
          ('negative', -110.0),
          ('negative', -110.0),
          ('neutral', 110.0),
          ('positive', 110.0),
          ('positive', 110.0),
          ('neutral', -110.0),
        ]) {
          await t.ensureVisible(body);
          await t.pumpAndSettle();
          await t.drag(editable, Offset(step.$2, 0));
          await t.pumpAndSettle();
          expect(
            t.widget<OptionBar>(find.byKey(const ValueKey('tone-pill'))).value,
            step.$1,
          );
          expect(t.state<EditableTextState>(editable), same(state));
          expect(state.widget.focusNode.hasFocus, isTrue);
          expect(
            state.widget.controller.text,
            'Unveränderter Beobachtungstext',
          );
        }
        expect(
          t.testTextInput.log.where((e) => e.method == 'TextInput.hide'),
          isEmpty,
        );
        if (kind == SchoolKind.work) {
          final subject = find.byKey(const ValueKey('record-subject'));
          await t.ensureVisible(subject);
          await t.enterText(subject, 'Eigener Auftrag');
          await t.pumpAndSettle();
          await t.ensureVisible(subject);
          await t.pumpAndSettle();
          await t.drag(
            find.descendant(of: subject, matching: find.byType(EditableText)),
            const Offset(100, 0),
          );
          await t.pumpAndSettle();
          expect(
            t.widget<OptionBar>(find.byKey(const ValueKey('tone-pill'))).value,
            'positive',
          );
        }
        await tap(t, find.byKey(const ValueKey('save-school-record')));
        final saved = (await repo.schoolRecords()).single;
        expect(saved.body, 'Unveränderter Beobachtungstext');
        expect(saved.neutral, [neutral]);
        if (kind == SchoolKind.work) {
          expect(saved.assignmentFree, 'Eigener Auftrag');
        }
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  testWidgets(
    'text selection, mouse, vertical or short drags and multitouch do not switch tone',
    (t) async {
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'a'),
        ),
      );
      final body = find.byKey(const ValueKey('record-body'));
      await t.ensureVisible(body);
      await t.enterText(body, 'Text für Auswahl und Bearbeitung');
      final editable = find.descendant(
        of: body,
        matching: find.byType(EditableText),
      );
      String tone() =>
          t.widget<OptionBar>(find.byKey(const ValueKey('tone-pill'))).value;
      await t.drag(editable, const Offset(-20, 0));
      await t.pumpAndSettle();
      expect(tone(), 'neutral');
      await t.ensureVisible(body);
      await t.drag(editable, const Offset(-25, -70));
      await t.pumpAndSettle();
      expect(tone(), 'neutral');
      await t.ensureVisible(body);
      await t.pumpAndSettle();
      final hold = await t.startGesture(
        t.getTopLeft(editable) + const Offset(20, 16),
      );
      await t.pump(const Duration(milliseconds: 600));
      await hold.moveBy(
        const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 650),
      );
      await hold.up(timeStamp: const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      expect(tone(), 'neutral');
      final state = t.state<EditableTextState>(editable);
      expect(state.widget.controller.selection.isCollapsed, isFalse);
      state.hideToolbar();
      await t.pumpAndSettle();
      final mouse = await t.startGesture(
        t.getCenter(editable) - const Offset(50, 0),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(100, 0));
      await mouse.up();
      await t.pumpAndSettle();
      expect(tone(), 'neutral');
      await t.ensureVisible(body);
      await t.pumpAndSettle();
      final first = await t.startGesture(t.getCenter(editable), pointer: 51);
      final second = await t.startGesture(
        t.getCenter(editable) + const Offset(0, 10),
        pointer: 52,
      );
      await first.moveBy(const Offset(-100, 0));
      await second.up();
      await first.up();
      await t.pumpAndSettle();
      expect(tone(), 'neutral');
      expect(state.widget.controller.text, 'Text für Auswahl und Bearbeitung');
      await tap(t, find.byKey(const ValueKey('cancel-editor')));
      await finish(t);
    },
  );

  testWidgets(
    'compact switches support track, label, drag and keyboard; disabled remains disabled',
    (t) async {
      var value = false, changes = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  CompactSwitch(
                    key: const ValueKey('standalone'),
                    value: value,
                    onChanged: (v) => setState(() {
                      value = v;
                      changes++;
                    }),
                  ),
                  CompactSwitchListTile(
                    title: const Text('Beschriftung'),
                    value: value,
                    onChanged: (v) => setState(() {
                      value = v;
                      changes++;
                    }),
                  ),
                  const CompactSwitchListTile(
                    title: Text('Deaktiviert'),
                    value: false,
                    onChanged: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final standalone = find.byKey(const ValueKey('standalone'));
      expect(t.getSize(standalone), const Size(52, 48));
      await t.tap(standalone);
      await t.pumpAndSettle();
      expect(value, isTrue);
      expect(changes, 1);
      await t.tap(find.text('Beschriftung'));
      await t.pumpAndSettle();
      expect(value, isFalse);
      expect(changes, 2);
      await t.drag(standalone, const Offset(35, 0));
      await t.pumpAndSettle();
      expect(value, isTrue);
      expect(changes, 3);
      await t.tap(find.text('Deaktiviert'));
      await t.pumpAndSettle();
      expect(changes, 3);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(changes, 4);
      expect(value, isFalse);
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  testWidgets(
    'dragging a switch in an observation does not navigate the tone',
    (t) async {
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'a'),
        ),
      );
      final control = find.descendant(
        of: find.byKey(const ValueKey('section-Zielbezug')),
        matching: find.byType(CompactSwitch),
      );
      await t.ensureVisible(control);
      await t.pumpAndSettle();
      await t.drag(control, const Offset(45, 0));
      await t.pumpAndSettle();
      expect(t.widget<CompactSwitch>(control).value, isTrue);
      expect(
        t.widget<OptionBar>(find.byKey(const ValueKey('tone-pill'))).value,
        'neutral',
      );
      await tap(t, find.byKey(const ValueKey('cancel-editor')));
      await finish(t);
    },
  );

  for (final view in [(390.0, 1.0, 'dark'), (320.0, 2.0, 'light')]) {
    testWidgets(
      'colors, larger pill and compact switches ${view.$1}/${view.$2}/${view.$3}',
      (t) async {
        await c.saveAppearance(c.appearance.patch({'mode': view.$3}));
        final boundary = GlobalKey(),
            suffix = '${view.$1.toInt()}-${view.$2.toInt()}-${view.$3}';
        await app(
          t,
          size: Size(view.$1, 1000),
          font: view.$2,
          boundary: boundary,
        );
        await open(
          t,
          SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.social, 'a'),
          ),
        );
        for (final tone in ['positive', 'neutral', 'negative']) {
          final finder = find.byKey(ValueKey('tone-$tone'));
          await tap(t, finder);
          final button = t.widget<TextButton>(finder),
              color = t
                  .widget<TextButton>(finder)
                  .style!
                  .backgroundColor!
                  .resolve({})!;
          expect(color.computeLuminance(), lessThan(.18));
          expect(1.05 / (color.computeLuminance() + .05), greaterThan(4.5));
          expect(button.style!.foregroundColor!.resolve({}), Colors.white);
          if (tone == 'positive') {
            expect(color.g, greaterThan(color.r));
            expect(color.g, greaterThan(color.b));
          }
          if (tone == 'negative') {
            expect(color.r, greaterThan(color.g));
            expect(color.r, greaterThan(color.b));
          }
          if (tone == 'neutral') {
            expect(color.b, greaterThan(color.r));
            expect(color.b, greaterThan(color.g));
          }
          if (view.$2 == 1) {
            expect(
              t.getSize(find.byKey(const ValueKey('tone-pill'))).height,
              inInclusiveRange(42, 46),
            );
          }
          await capture(t, boundary, 'tone-$tone-$suffix');
        }
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: 'a'),
          ),
        );
        await tap(t, find.byKey(const ValueKey('orga-kind-task')));
        await capture(t, boundary, 'switches-orga-$suffix');
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
        await tap(t, find.byTooltip('Weitere Bereiche'));
        await tap(t, find.text('Einstellungen'));
        await capture(t, boundary, 'switches-settings-$suffix');
        await tap(t, find.byKey(const ValueKey('settings-tab-1')));
        for (final tone in ['positive', 'neutral', 'negative']) {
          await tap(t, find.byKey(ValueKey('default-tone-$tone')));
          final color = t
              .widget<TextButton>(find.byKey(ValueKey('default-tone-$tone')))
              .style!
              .backgroundColor!
              .resolve({})!;
          expect(color.computeLuminance(), lessThan(.18));
        }
        await capture(t, boundary, 'default-tone-$suffix');
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }
}
