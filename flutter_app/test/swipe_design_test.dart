import 'support/app_test_fonts.dart';
import 'package:flex_notizbuch/ui/app_navigation.dart';
import 'package:flex_notizbuch/ui/settings.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';

class DesignNotebook extends SqliteNotebook {
  DesignNotebook(super.db);
  bool failWrites = false;
  @override
  Future<void> saveAppearance(Appearance value) async {
    if (failWrites) throw const DomainError('Synthetischer Einstellungsfehler');
    return super.saveAppearance(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DesignNotebook repo;
  late NotebookController c;
  setUpAll(loadAppTestFonts);
  setUp(() async {
    repo = DesignNotebook(
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
    Size size = const Size(1100, 1000),
    GlobalKey? boundary,
    double scale = 1,
    double keyboard = 0,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    t.view.viewInsets = FakeViewPadding(bottom: keyboard);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    await t.binding.setSurfaceSize(size);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FlexApp(controller: c),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    t.view.resetViewInsets();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    await t.binding.setSurfaceSize(null);
  }

  Future<void> open(WidgetTester t, Widget widget) async {
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold).first),
        barrierDismissible: false,
        builder: (_) => widget,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await t.ensureVisible(target.last);
    await t.pumpAndSettle();
    await t.tap(target.last);
    await t.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester t,
    GlobalKey key,
    String name,
    Size size,
    double scale,
    double keyboard,
  ) async {
    final directory = Platform.environment['FLEX_RENDER_DIR'];
    if (directory == null) return;
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      Directory(directory).createSync(recursive: true);
      File(
        '$directory/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      picture.dispose();
      File('$directory/manifest.jsonl').writeAsStringSync(
        '${jsonEncode({'file': '$name.png', 'width': size.width, 'height': size.height, 'textScale': scale, 'keyboardInset': keyboard, 'textSetting': c.appearance.textScale, 'engine': 'flutter_test RenderRepaintBoundary', 'source': '0.17.1+58 UI audit', 'data': 'synthetic'})}\n',
        mode: FileMode.append,
      );
    });
  }

  Future<void> close(WidgetTester t) =>
      tap(t, find.byTooltip(RegExp(r'^(Schließen.*|Zurück)$')));
  EditableText input(WidgetTester t, Key key) => t.widget<EditableText>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(EditableText))
        .last,
  );

  Future<void> settings(WidgetTester t) async {
    await tap(t, find.byTooltip('Weitere Bereiche'));
    await tap(t, find.text('Einstellungen').last);
  }

  int page(WidgetTester t) =>
      t.widget<FlexPagePills>(find.byType(FlexPagePills)).selected;
  Future<void> slider(WidgetTester t, String name, double fraction) async {
    final finder = find.byKey(
      ValueKey(name == 'textScale' ? 'appearance-text-scale' : 'setting-$name'),
    );
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    final rect = t.getRect(finder);
    await t.tapAt(
      Offset(rect.left + 24 + (rect.width - 48) * fraction, rect.center.dy),
    );
    await t.pumpAndSettle();
    await t.runAsync(c.flushAppearance);
    await t.pumpAndSettle();
  }

  double paintedWidth(WidgetTester t, Finder finder) {
    final box = t.renderObject<RenderBox>(finder);
    return (box.localToGlobal(Offset(box.size.width, 0)) -
            box.localToGlobal(Offset.zero))
        .dx;
  }

  test('reading scale validates independently of retired design options', () {
    final old = Appearance.fromJson({
      'textScale': 1.15,
      'uiScale': .8,
      'fieldRadius': 0,
    });
    expect(old.textScale, 1.15);
    expect(old.toJson(), isNot(contains('uiScale')));
    for (final change in <Json>[
      {'textScale': .79},
      {'textScale': 1.61},
      {'textScale': double.nan},
    ]) {
      expect(() => old.patch(change), throwsA(isA<DomainError>()));
    }
  });
  testWidgets(
    'horizontal swipes change primary page, vertical drags and settings sliders do not; search survives',
    (t) async {
      for (var i = 0; i < 8; i++) {
        await c.savePupil(Pupil(id: 'extra-$i', name: 'Zusatzschüler $i'));
      }
      await app(t, size: const Size(390, 844));
      expect(page(t), 0);
      await t.drag(
        find.byKey(const ValueKey('main-pages')),
        const Offset(-300, 0),
      );
      await t.pumpAndSettle();
      expect(page(t), 1);
      await t.drag(
        find.byKey(const ValueKey('main-pages')),
        const Offset(0, -200),
      );
      await t.pumpAndSettle();
      expect(page(t), 1);
      final pupilScroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('pupils-false')),
            matching: find.byType(Scrollable),
          )
          .first;
      final offset = t.state<ScrollableState>(pupilScroll).position.pixels;
      expect(offset, greaterThan(0));
      await t.drag(
        find.byKey(const ValueKey('main-pages')),
        const Offset(300, 0),
      );
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(const ValueKey('main-pages')),
        const Offset(-300, 0),
      );
      await t.pumpAndSettle();
      expect(
        t.state<ScrollableState>(pupilScroll).position.pixels,
        closeTo(offset, .01),
      );
      await t.scrollUntilVisible(
        find.byTooltip('Schüler suchen'),
        -150,
        scrollable: pupilScroll,
      );
      await tap(t, find.byTooltip('Schüler suchen'));
      await t.enterText(find.byType(TextField).first, 'Anna');
      await t.drag(
        find.byKey(const ValueKey('main-pages')),
        const Offset(300, 0),
      );
      await t.pumpAndSettle();
      expect(page(t), 0);
      await t.tap(find.byKey(const ValueKey('bottom-1')));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('page-1')));
      expect(find.byTooltip('Schüler suchen: Anna'), findsOneWidget);
      expect(find.text('Suche: Anna'), findsNothing);
      await settings(t);
      expect(page(t), 4);
      await slider(t, 'textScale', .65);
      expect(page(t), 4);
      await t.tap(find.byKey(const ValueKey('bottom-1')));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('page-0')));
      expect(page(t), 0);
      await t.drag(
        find.byKey(const ValueKey('main-pages')),
        const Offset(-300, 0),
      );
      await t.pumpAndSettle();
      expect(page(t), 1);
      await finish(t);
    },
  );
  testWidgets('text size persists and resetting it keeps shortcut order', (
    t,
  ) async {
    final order = ['orga', 'work', 'social', 'goal', 'homework'];
    await c.saveAppearance(c.appearance.patch({'shortcutOrder': order}));
    await app(t, size: const Size(1100, 1000));
    await settings(t);
    await slider(t, 'textScale', .7);
    expect(c.appearance.textScale, greaterThan(1.2));
    expect((await repo.appearance()).toJson(), c.appearance.toJson());
    await tap(t, find.text('Standardgröße'));
    expect(c.appearance.textScale, 1);
    expect(c.appearance.shortcutOrder, order);
    await finish(t);
  });
  testWidgets(
    'failed scale persistence rolls back without losing the settings route',
    (t) async {
      await app(t);
      await settings(t);
      repo.failWrites = true;
      await slider(t, 'textScale', 0);
      expect(c.appearance.textScale, 1);
      expect(c.appearanceError, isNotNull);
      expect(find.byType(SettingsPage), findsOneWidget);
      repo.failWrites = false;
      await slider(t, 'textScale', .65);
      expect(c.appearanceError, isNull);
      expect((await repo.appearance()).textScale, c.appearance.textScale);
      await finish(t);
    },
  );
  testWidgets(
    'homework symbols persist all four states and retain sibling status and comments',
    (t) async {
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'a').patch({
          'tasks': [
            const HomeworkTask(id: 'first', text: 'Erste Aufgabe').toJson(),
            const HomeworkTask(
              id: 'second',
              text: 'Zweite Aufgabe',
              initialState: TaskState.partial,
            ).toJson(),
          ],
          'feedback': [
            SchoolFeedback(
              id: 'comment',
              observedOn: dateOnly(DateTime.now()),
              createdAtUtc: utcNow(),
              taskId: 'first',
              taskText: 'Erste Aufgabe',
              note: 'Kommentar bleibt',
            ).toJson(),
          ],
        }),
      );
      await c.reload();
      await app(t, size: const Size(390, 844));
      await tap(t, find.byKey(ValueKey('overview-open-${r.id}')));
      for (final state in [
        TaskState.complete,
        TaskState.partial,
        TaskState.missing,
        TaskState.open,
      ]) {
        final target = find.byKey(ValueKey('status-first-${state.name}'));
        expect(
          find.descendant(of: target, matching: find.byType(Icon)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: target, matching: find.byType(ChoiceChip)),
          findsNothing,
        );
        await tap(t, target);
        final saved = (await repo.schoolRecords()).single;
        expect(saved.taskState(saved.tasks.first), state);
        expect(saved.taskState(saved.tasks.last), TaskState.partial);
        expect(
          saved.feedback.firstWhere((f) => f.id == 'comment').note,
          'Kommentar bleibt',
        );
        expect(
          t
              .widgetList<Semantics>(
                find.ancestor(of: target, matching: find.byType(Semantics)),
              )
              .any((node) => node.properties.selected == true),
          isTrue,
        );
        expect(
          find.descendant(of: target, matching: find.byTooltip(state.label)),
          findsOneWidget,
        );
      }
      await finish(t);
    },
  );
  testWidgets(
    'legacy layout scaling is ignored; font changes preserve editor state and keyboard geometry',
    (t) async {
      await app(t, size: const Size(390, 844));
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(pupilId: 'a'),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Bleibt erhalten',
      );
      final state = t.state(find.byType(OrgaEditor));
      var expectedText = 'Bleibt erhalten';
      for (final zoom in [.8, 1.0, 1.2]) {
        await c.saveAppearance(
          c.appearance.patch({'uiScale': zoom, 'textScale': 1.0}),
        );
        t.view.viewInsets = const FakeViewPadding(bottom: 240);
        await t.pumpAndSettle();
        final toolbarIcon = find.byIcon(Icons.format_list_numbered);
        await t.ensureVisible(toolbarIcon);
        await t.pumpAndSettle();
        expect(paintedWidth(t, toolbarIcon), closeTo(24, .1));
        final media = MediaQuery.of(t.element(find.byType(OrgaEditor)));
        expect(media.size.width, closeTo(390, .01));
        expect(media.viewInsets.bottom, closeTo(240, .01));
        expect(t.state(find.byType(OrgaEditor)), same(state));
        expect(
          input(t, const ValueKey('orga-note')).controller.text,
          expectedText,
        );
        await tap(t, find.byTooltip('Nummerierung'));
        expect(
          input(t, const ValueKey('orga-note')).controller.text,
          contains('Bleibt erhalten'),
        );
        expectedText = input(t, const ValueKey('orga-note')).controller.text;
      }
      await c.saveAppearance(c.appearance.patch({'textScale': 1.5}));
      await t.pumpAndSettle();
      expect(
        paintedWidth(t, find.byIcon(Icons.format_list_numbered)),
        closeTo(24, .1),
      );
      expect(
        MediaQuery.textScalerOf(t.element(find.byType(OrgaEditor))).scale(20),
        closeTo(20 * 1.5, .01),
      );
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );
  for (final view in [
    (320.0, 700.0, 1.0, .8),
    (390.0, 844.0, 1.0, 1.0),
    (1200.0, 1000.0, 1.0, 1.2),
    (320.0, 800.0, 2.0, 1.0),
    (320.0, 800.0, 1.0, 1.2),
    (320.0, 800.0, 2.0, 1.6),
  ]) {
    testWidgets(
      'design and symbol renderings ${view.$1} system font ${view.$3} app font ${view.$4}',
      (t) async {
        await c.saveAppearance(c.appearance.patch({'textScale': view.$4}));
        final boundary = GlobalKey();
        final size = Size(view.$1, view.$2);
        final suffix =
            '${view.$1.toInt()}-${view.$3.toInt()}-${(view.$4 * 100).round()}';
        await app(t, size: size, scale: view.$3, boundary: boundary);
        await settings(t);
        expect(t.takeException(), isNull);
        await capture(t, boundary, 'design-$suffix', size, view.$3, 0);
        await t.tap(find.byKey(const ValueKey('bottom-1')));
        await t.pumpAndSettle();
        await tap(t, find.byKey(const ValueKey('page-0')));
        final r = await repo.saveSchoolRecord(
          SchoolRecord.empty(SchoolKind.homework, 'a').patch({
            'subject': 'Mathematik',
            'tasks': [
              const HomeworkTask(
                id: 'given',
                text: 'Seite 24: Aufgaben 1 bis 3',
              ).toJson(),
            ],
          }),
        );
        await c.reload();
        await t.pumpAndSettle();
        final summary = find.byKey(ValueKey('overview-open-${r.id}'));
        if (summary.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            summary,
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const PageStorageKey('overview')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await t.ensureVisible(summary);
        await t.pumpAndSettle();
        // At 200% text plus UI zoom the card can exceed the viewport. Tap
        // its visible portion, just as a user would, rather than its center.
        final visibleCard = t
            .getRect(summary)
            .intersect(
              Offset.zero & (t.view.physicalSize / t.view.devicePixelRatio),
            );
        expect(visibleCard.isEmpty, isFalse);
        await t.tapAt(visibleCard.center);
        await t.pumpAndSettle();
        await tap(t, find.byKey(const ValueKey('status-given-partial')));
        expect(
          t.getRect(find.byKey(const ValueKey('status-given-open'))).top,
          closeTo(
            t.getRect(find.byKey(const ValueKey('status-given-missing'))).top,
            .01,
          ),
        );
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          'homework-symbols-$suffix',
          size,
          view.$3,
          0,
        );
        await close(t);
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: 'a'),
          ),
        );
        expect(find.text('☐ Checkliste'), findsNothing);
        await t.enterText(
          find.byKey(const ValueKey('orga-note')),
          'Material vorbereiten',
        );
        await tap(t, find.byTooltip('Nummerierung'));
        await tap(t, find.byTooltip('Checkliste'));
        await t.enterText(
          find.byKey(const ValueKey('orga-new-item')),
          'Arbeitsblätter kopieren',
        );
        await t.testTextInput.receiveAction(TextInputAction.next);
        await t.pumpAndSettle();
        t.view.viewInsets = const FakeViewPadding(bottom: 240);
        await t.pumpAndSettle();
        await t.ensureVisible(find.byTooltip('Nummerierung'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          'orga-symbols-keyboard-$suffix',
          size,
          view.$3,
          240,
        );
        await tap(t, find.text('Speichern'));
        expect(
          (await repo.entries()).single.items.single.text,
          'Arbeitsblätter kopieren',
        );
        await finish(t);
      },
    );
  }
}
