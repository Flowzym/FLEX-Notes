import 'support/app_test_fonts.dart';
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
  setUpAll(loadAppTestFonts);
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

  Future<void> manage(WidgetTester t) =>
      tap(t, find.byKey(const ValueKey('calendar-edit-timetable')));
  Future<void> editFirst(WidgetTester t) =>
      tap(t, find.byTooltip('Block bearbeiten').first);

  for (final setting in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    testWidgets(
      'unified calendar and editable base plan at ${setting.$1}/${setting.$2}',
      (t) async {
        final c = await controller(),
            key = await host(t, c, width: setting.$1, scale: setting.$2);
        expect(find.text('07:45–11:30'), findsOneWidget);
        await screenshot(
          t,
          key,
          'unified-day-${setting.$1.toInt()}-${setting.$2.toInt()}',
        );
        await tap(t, find.byKey(const ValueKey('calendar-mode-week')));
        await screenshot(
          t,
          key,
          'unified-week-${setting.$1.toInt()}-${setting.$2.toInt()}',
        );
        await manage(t);
        expect(find.text('Stundenzeiten'), findsOneWidget);
        await editFirst(t);
        expect(find.byKey(const ValueKey('timetable-title')), findsOneWidget);
        await screenshot(
          t,
          key,
          'timetable-editor-${setting.$1.toInt()}-${setting.$2.toInt()}',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('base plan editing retains keyboard focus and custom times', (
    t,
  ) async {
    final c = await controller();
    await host(t, c);
    await manage(t);
    await editFirst(t);
    final title = find.byKey(const ValueKey('timetable-title'));
    await enter(t, title, 'Lernatelier');
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(
      t
          .widget<EditableText>(
            find.descendant(of: title, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
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
  });
  testWidgets(
    'span deletion restoration and shared period hours stay editable',
    (t) async {
      final c = await controller();
      await host(t, c);
      await manage(t);
      await editFirst(t);
      await tap(t, find.byKey(const ValueKey('timetable-last-p4')));
      await tap(t, find.text('5. · 12:25').last);
      await tap(t, find.text('Speichern'));
      expect(
        lessonOccurrences(c.classroom, '2026-11-09', '2026-11-09').first.end,
        '12:25',
      );
      await editFirst(t);
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
      await tap(t, find.byTooltip('Block wiederherstellen'));
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
  testWidgets('cancelled block draft resumes without losing its controls', (
    t,
  ) async {
    final c = await controller();
    await host(t, c);
    await manage(t);
    await editFirst(t);
    await enter(t, find.byKey(const ValueKey('timetable-title')), 'Entwurf');
    await tap(t, find.text('Abbrechen'));
    expect(c.dialogDrafts, hasLength(1));
    resumeTimetableDraft(
      t.element(find.text('Stundenplan verwalten')),
      c,
      c.dialogDrafts.single,
    );
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextFormField>(find.byKey(const ValueKey('timetable-title')))
          .initialValue,
      'Entwurf',
    );
    await t.ensureVisible(find.text('Block entfernen'));
    await tap(t, find.text('Speichern'));
    expect(c.dialogDrafts, isEmpty);
    expect(c.classroom.any((d) => d.title == 'Entwurf'), isTrue);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('adding a block leaves existing PDF blocks intact', (t) async {
    final c = await controller();
    await host(t, c);
    await manage(t);
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
    expect(
      c.classroom.where((d) => d.kind == ClassroomKind.lesson),
      hasLength(13),
    );
    expect(c.classroom.where((d) => d.title == 'Flexk'), hasLength(5));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'lesson switch preserves selected day, appointments and stored data',
    (t) async {
      final c = await controller();
      await c.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Gespräch',
          appointmentDate: '2026-11-10',
          appointmentTime: '12:45',
        ),
      );
      final block = c.classroom.singleWhere(
        (d) => d.title == 'Flexk' && d.text('date') == '2026-11-09',
      );
      await c.saveClassroom(
        patchLessonOccurrence(block, '2026-11-09', {'cancelled': true}),
      );
      await host(t, c);
      expect(find.text('Flexk'), findsNothing);
      await tap(t, find.byTooltip('Nächster Zeitraum'));
      expect(find.text('Gespräch'), findsOneWidget);
      expect(find.text('Flexk'), findsOneWidget);
      final before = c.classroom.map((d) => d.toJson()).toList();
      await tap(t, find.byKey(const ValueKey('calendar-show-lessons')));
      expect(find.text('Flexk'), findsNothing);
      expect(find.text('Gespräch'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('calendar-mode-month')));
      expect(find.text('Gespräch'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('calendar-show-lessons')));
      expect(find.text('Flexk'), findsOneWidget);
      expect(c.classroom.map((d) => d.toJson()).toList(), before);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('lesson tap offers explicit single and future changes', (
    t,
  ) async {
    final c = await controller();
    await host(t, c);
    await tap(t, find.text('Flexk'));
    expect(find.text('Nur diesen Termin bearbeiten'), findsOneWidget);
    expect(find.text('Stundenplan ab 09.11.2026 ändern'), findsOneWidget);
    await tap(t, find.text('Nur diesen Termin bearbeiten'));
    await enter(t, find.byKey(const ValueKey('classroom-title')), 'Nur heute');
    await tap(t, find.text('Speichern'));
    expect(
      lessonOccurrences(c.classroom, '2026-11-09', '2026-11-09').first.title,
      'Nur heute',
    );
    expect(
      lessonOccurrences(c.classroom, '2026-11-16', '2026-11-16').first.title,
      'Flexk',
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
