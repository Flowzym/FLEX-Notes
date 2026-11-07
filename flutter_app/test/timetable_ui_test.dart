import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/timetable.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/calendar_page.dart';
import 'package:flex_notizbuch/ui/timetable.dart';
import 'classroom_test.dart' show classroomMemory;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    for (final font in {
      'FlexSans': 'assets/fonts/Selawik-Regular.ttf',
      'FlexSerif': 'assets/fonts/Gelasio-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  setUp(() {
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'at.flowzym.flex_notizbuch/device',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });
  tearDown(() {
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'at.flowzym.flex_notizbuch/device',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });
  Future<NotebookController> controller() async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    await initializeFlexTimetable(c.repository);
    await c.reload();
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    return c;
  }

  Future<GlobalKey> host(
    WidgetTester t,
    NotebookController c, {
    double width = 390,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    final theme = Theme.of(t.element(find.byType(Scaffold).first)),
        key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: key, child: child!),
        ),
        home: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: CalendarPage(
            controller: c,
            clock: () => DateTime(2026, 11, 9, 8),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> enter(WidgetTester t, Finder f, String value) async {
    await t.ensureVisible(f);
    await t.enterText(f, value);
    await t.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester t, GlobalKey key, String name) async {
    final folder = Platform.environment['FLEX_TEST_ARTIFACT_DIR'];
    if (folder == null) return;
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(folder).create(recursive: true);
      await File('$folder/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final setting in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    testWidgets(
      'timetable direct access, readable blocks and editor at ${setting.$1}/${setting.$2}',
      (t) async {
        final c = await controller(),
            key = await host(t, c, width: setting.$1, scale: setting.$2);
        expect(find.text('Stundenplan').hitTestable(), findsOneWidget);
        await tap(t, find.text('Stundenplan'));
        expect(find.byKey(const ValueKey('timetable-view')), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(t.takeException(), isNull);
        await screenshot(
          t,
          key,
          'timetable-${setting.$1.toInt()}-${setting.$2.toInt()}',
        );
        await tap(t, find.byKey(const ValueKey('timetable-mode-day')));
        await screenshot(
          t,
          key,
          'timetable-day-${setting.$1.toInt()}-${setting.$2.toInt()}',
        );
        expect(find.text('07:45–11:30'), findsOneWidget);
        await tap(
          t,
          find.descendant(
            of: find.byKey(const ValueKey('timetable-view')),
            matching: find.text('Flexk'),
          ),
        );
        expect(find.text('Unterrichtsblock'), findsOneWidget);
        expect(find.byKey(const ValueKey('timetable-title')), findsOneWidget);
        expect(t.takeException(), isNull);
        await screenshot(
          t,
          key,
          'timetable-editor-${setting.$1.toInt()}-${setting.$2.toInt()}',
        );
        await tap(t, find.text('Abbrechen'));
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'edit retains keyboard focus through autosave and updates the actual calendar',
    (t) async {
      final c = await controller();
      await host(t, c);
      await tap(t, find.text('Stundenplan'));
      await tap(t, find.byKey(const ValueKey('timetable-mode-day')));
      await tap(
        t,
        find.descendant(
          of: find.byKey(const ValueKey('timetable-view')),
          matching: find.text('Flexk'),
        ),
      );
      final title = find.byKey(const ValueKey('timetable-title'));
      await enter(t, title, 'Lernatelier');
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      final editable = t.widget<EditableText>(
        find.descendant(of: title, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(t.testTextInput.isVisible, isTrue);
      await enter(
        t,
        find.byKey(const ValueKey('timetable-clock-start-p1-p2-p3-p4')),
        '08:00',
      );
      await tap(t, find.byKey(const ValueKey('timetable-weekday')));
      await tap(t, find.text('Dienstag').last);
      await tap(t, find.text('Speichern'));
      final saved = c.classroom.singleWhere((d) => d.title == 'Lernatelier');
      expect(saved.text('date'), '2026-11-10');
      expect(saved.strings('slotIds'), ['p1', 'p2', 'p3', 'p4']);
      expect(
        lessonOccurrences(
          c.classroom,
          '2026-11-10',
          '2026-11-10',
        ).singleWhere((l) => l.title == 'Lernatelier').start,
        '08:00',
      );
      expect(c.dialogDrafts, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'period span, deletion, restore and general time changes persist',
    (t) async {
      final c = await controller();
      await host(t, c);
      await tap(t, find.text('Stundenplan'));
      await tap(t, find.byKey(const ValueKey('timetable-mode-day')));
      await tap(
        t,
        find.descendant(
          of: find.byKey(const ValueKey('timetable-view')),
          matching: find.text('Flexk'),
        ),
      );
      await tap(t, find.byKey(const ValueKey('timetable-last-p4')));
      await tap(t, find.text('5. · 12:25').last);
      await tap(t, find.text('Speichern'));
      expect(find.text('07:45–12:25'), findsOneWidget);
      await tap(
        t,
        find.descendant(
          of: find.byKey(const ValueKey('timetable-view')),
          matching: find.text('Flexk'),
        ),
      );
      await tap(t, find.text('Block entfernen'));
      await tap(t, find.text('Speichern'));
      expect(
        lessonOccurrences(
          c.classroom,
          '2026-11-09',
          '2026-11-09',
        ).where((l) => l.title == 'Flexk'),
        isEmpty,
      );
      await tap(t, find.text('Verwalten'));
      await tap(t, find.byTooltip('Block wiederherstellen'));
      await tap(t, find.byTooltip('Schließen und Eingaben sichern'));
      expect(
        lessonOccurrences(
          c.classroom,
          '2026-11-09',
          '2026-11-09',
        ).where((l) => l.title == 'Flexk'),
        hasLength(1),
      );
      await tap(t, find.text('Stundenzeiten'));
      await enter(t, find.byKey(const ValueKey('period-p1-start')), '07:40');
      await tap(t, find.text('Speichern'));
      expect(
        lessonOccurrences(
          c.classroom,
          '2026-11-09',
          '2026-11-13',
        ).where((l) => l.title == 'Flexk').every((l) => l.start == '07:40'),
        isTrue,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancelled block draft reopens with span, teacher and removal action',
    (t) async {
      final c = await controller();
      await host(t, c);
      await tap(t, find.text('Stundenplan'));
      await tap(t, find.byKey(const ValueKey('timetable-mode-day')));
      await tap(
        t,
        find.descendant(
          of: find.byKey(const ValueKey('timetable-view')),
          matching: find.text('Flexk'),
        ),
      );
      await enter(t, find.byKey(const ValueKey('timetable-title')), 'Entwurf');
      await tap(t, find.text('Abbrechen'));
      expect(c.dialogDrafts, hasLength(1));
      final ctx = t.element(find.byKey(const ValueKey('timetable-view')));
      resumeTimetableDraft(ctx, c, c.dialogDrafts.single);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(
              find.byKey(const ValueKey('timetable-title')),
            )
            .initialValue,
        'Entwurf',
      );
      await t.ensureVisible(find.text('Block entfernen'));
      expect(find.text('Block entfernen'), findsOneWidget);
      await tap(t, find.text('Speichern'));
      expect(c.dialogDrafts, isEmpty);
      expect(c.classroom.any((d) => d.title == 'Entwurf'), isTrue);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'adding a block saves its custom name and time without altering the PDF blocks',
    (t) async {
      final c = await controller();
      await host(t, c);
      await tap(t, find.text('Stundenplan'));
      await tap(t, find.byKey(const ValueKey('timetable-mode-day')));
      await tap(t, find.text('Block hinzufügen'));
      await enter(t, find.byKey(const ValueKey('timetable-title')), 'Lernzeit');
      await enter(
        t,
        find.byKey(const ValueKey('timetable-clock-start-p1')),
        '16:10',
      );
      await enter(
        t,
        find.byKey(const ValueKey('timetable-clock-end-p1')),
        '17:00',
      );
      await tap(t, find.text('Speichern'));
      final blocks = c.classroom
          .where((d) => d.kind == ClassroomKind.lesson)
          .toList();
      expect(blocks, hasLength(13));
      expect(
        blocks.singleWhere((d) => d.title == 'Lernzeit').text('start'),
        '16:10',
      );
      expect(blocks.where((d) => d.title == 'Flexk'), hasLength(5));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('subpages retain independent dates, modes and scroll positions', (
    t,
  ) async {
    final c = await controller();
    await host(t, c);
    await tap(t, find.byKey(const ValueKey('calendar-mode-month')));
    await tap(t, find.byTooltip('Nächster Zeitraum'));
    expect(find.text('Dezember 2026'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('calendar-section-timetable')));
    expect(
      find.byKey(const ValueKey('calendar-time-grid-week')),
      findsOneWidget,
    );
    expect(find.text('Monat'), findsNothing);
    await tap(t, find.byKey(const ValueKey('timetable-mode-day')));
    await tap(t, find.byTooltip('Nächster Zeitraum'));
    expect(find.text('02.12.2026'), findsOneWidget);
    final scroll = find.byKey(const PageStorageKey('timetable-page'));
    await t.drag(scroll, const Offset(0, -250));
    await t.pumpAndSettle();
    final offset = t
        .state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
        )
        .position
        .pixels;
    expect(offset, greaterThan(0));
    await tap(t, find.byKey(const ValueKey('calendar-section-calendar')));
    expect(find.text('Dezember 2026'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-month-2026-12-01')),
      findsOneWidget,
    );
    await tap(t, find.byKey(const ValueKey('calendar-section-timetable')));
    expect(find.text('02.12.2026'), findsOneWidget);
    expect(
      t
          .state<ScrollableState>(
            find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
          )
          .position
          .pixels,
      offset,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'timetable day and week use dated occurrences and preserve calendar appointments',
    (t) async {
      final c = await controller();
      await c.repository.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Gespräch',
          appointmentDate: '2026-11-09',
          appointmentTime: '09:00',
        ),
      );
      final block = c.classroom.singleWhere(
        (d) => d.title == 'Flexk' && d.text('date') == '2026-11-09',
      );
      await c.saveClassroom(
        patchLessonOccurrence(block, '2026-11-09', {
          'movedTo': '2026-11-10',
          'start': '08:00',
          'end': '11:00',
        }),
      );
      await host(t, c);
      await tap(t, find.text('Stundenplan'));
      expect(find.text('Gespräch'), findsNothing);
      await tap(t, find.byKey(const ValueKey('timetable-mode-day')));
      expect(find.text('Flexk'), findsNothing);
      await tap(t, find.byTooltip('Nächster Zeitraum'));
      expect(find.text('10.11.2026'), findsOneWidget);
      expect(find.text('Flexk'), findsNWidgets(2));
      expect(find.text('08:00–11:00'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('calendar-section-calendar')));
      expect(find.text('Gespräch'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
