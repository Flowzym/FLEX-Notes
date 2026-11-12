import 'support/app_test_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/calendar_page.dart';
import 'package:flex_notizbuch/ui/calendar_timeline.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'classroom_test.dart' show classroomMemory, lesson;
import 'material_workspace_test.dart' show material;

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
  Future<NotebookController> controller({bool seed = false}) async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    if (seed) {
      for (final p in [
        const Pupil(id: 'p', name: 'Alex'),
        const Pupil(id: 'q', name: 'Sam'),
      ]) {
        await c.repository.savePupil(p);
        await c.repository.saveSchoolRecord(
          SchoolRecord.empty(SchoolKind.homework, p.id).patch({
            'title': 'Lesen · S. 12',
            'tasks': [
              {'id': 'h', 'text': 'Lesen', 'status': 'open', 'comment': ''},
            ],
            'dueDate': '2026-11-02',
            'subject': 'Deutsch',
          }),
        );
      }
      final file = material('Brüche · Arbeitsblatt');
      await c.repository.saveClassroomDocument(file);
      for (var d = 0; d < 5; d++) {
        for (var i = 0; i < 5; i++) {
          await c.repository.saveClassroomDocument(
            lesson(
              date: '2026-11-0${2 + d}',
              rule: const RepeatRule(frequency: 'weekly'),
              materials: i == 0 ? [file.id] : [],
            ).patch({
              'title': [
                'Mathematik',
                'Deutsch',
                'Englisch',
                'Lernzeit',
                'Kreativwerkstatt',
              ][i],
              'start': ['08:00', '08:55', '10:00', '10:55', '12:00'][i],
              'end': ['08:50', '09:45', '10:50', '11:45', '12:50'][i],
              'room': 'FLEX-Raum',
            }),
          );
        }
      }
      await c.repository.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Material richten',
          body: 'Kopien',
          isTask: true,
          dueDate: '2026-11-02',
        ),
      );
      await c.repository.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Elterngespräch',
          appointmentDate: '2026-11-03',
          appointmentTime: '10:15',
        ),
      );
      await c.reload();
    }
    return c;
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<GlobalKey> host(
    WidgetTester t,
    NotebookController c, {
    Size size = const Size(390, 844),
    double scale = 1,
    Widget Function(BuildContext)? builder,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    // Reuse the production theme rather than an approximate test palette.
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: SafeArea(
              child: Builder(
                builder:
                    builder ??
                    (_) => CalendarPage(
                      controller: c,
                      clock: () => DateTime(2026, 11, 2, 8, 20),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    final folder = Platform.environment['FLEX_TEST_ARTIFACT_DIR'];
    if (folder == null) return;
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(folder).create(recursive: true);
      await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final week in [false, true]) {
    testWidgets(
      'compact ${week ? 'week' : 'day'} keeps short events tappable and adjacent lessons separate',
      (t) async {
        final c = await controller();
        String? opened;
        for (final scale in [1.0, 2.0]) {
          await host(
            t,
            c,
            scale: scale,
            builder: (_) => SingleChildScrollView(
              child: CalendarTimeline(
                week: week,
                days: [
                  for (var day = 2; day <= (week ? 6 : 2); day++)
                    DateTime(2026, 11, day),
                ],
                selectedDate: '2026-11-02',
                now: DateTime(2026, 11, 2, 8),
                items: const [
                  CalendarItem(
                    id: 'first',
                    date: '2026-11-02',
                    title: 'Deutsch',
                    category: 'lesson',
                    time: '08:00',
                    end: '08:45',
                  ),
                  CalendarItem(
                    id: 'next',
                    date: '2026-11-02',
                    title: 'Mathematik',
                    category: 'lesson',
                    time: '08:45',
                    end: '09:30',
                  ),
                  CalendarItem(
                    id: 'short',
                    date: '2026-11-02',
                    title: 'Rückfrage',
                    category: 'appointment',
                    time: '10:00',
                    end: '10:05',
                  ),
                ],
                onOpen: (item) => opened = item.id,
                onDay: (_) {},
              ),
            ),
          );
          final first = find.byKey(const ValueKey('calendar-slot-first'));
          final next = find.byKey(const ValueKey('calendar-slot-next'));
          final short = find.byKey(const ValueKey('calendar-slot-short'));
          expect(first, findsOneWidget);
          expect(next, findsOneWidget);
          expect(t.getRect(first).bottom, lessThan(t.getRect(next).top));
          expect(t.getSize(short).height, greaterThanOrEqualTo(week ? 32 : 44));
          final hour = (t.getTopLeft(short).dy - t.getTopLeft(first).dy) / 2;
          expect(hour / scale, lessThanOrEqualTo(72.01));
          await tap(t, short);
          expect(opened, 'short');
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('time marker stays above ongoing blocks and passes taps through', (
    t,
  ) async {
    final c = await controller();
    var opened = false;
    final boundary = await host(
      t,
      c,
      builder: (_) => SingleChildScrollView(
        child: CalendarTimeline(
          days: [DateTime(2026, 11, 2)],
          items: const [
            CalendarItem(
              id: 'long',
              date: '2026-11-02',
              title: 'Flexk',
              category: 'lesson',
              time: '07:45',
              end: '11:30',
            ),
          ],
          now: DateTime(2026, 11, 2, 8, 20),
          selectedDate: '2026-11-02',
          onOpen: (_) => opened = true,
          onDay: (_) {},
        ),
      ),
    );
    final line = find.byKey(const ValueKey('calendar-now-line'));
    final rect = t.getRect(line);
    expect(rect.width, greaterThan(300));
    expect(rect.height, 2);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-now-label')),
        matching: find.text('08:20'),
      ),
      findsOneWidget,
    );
    // Check actual paint output at the block center: the lesson used to cover it.
    await t.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final rgba = (await image.toByteData())!;
      final pixel =
          ((rect.top + 1).floor() * image.width + rect.center.dx.floor()) * 4;
      final color = Color.fromARGB(
        rgba.getUint8(pixel + 3),
        rgba.getUint8(pixel),
        rgba.getUint8(pixel + 1),
        rgba.getUint8(pixel + 2),
      );
      expect(
        color,
        (t
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: line,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color,
      );
      image.dispose();
    });
    await t.tapAt(rect.center);
    await t.pumpAndSettle();
    expect(opened, isTrue);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'shared day updates current time with and without lessons and omits it on other dates',
    (t) async {
      final c = await controller(seed: true);
      var now = DateTime(2026, 11, 9, 8, 20);
      await host(
        t,
        c,
        builder: (_) => CalendarPage(controller: c, clock: () => now),
      );
      final line = find.byKey(const ValueKey('calendar-now-line'));
      final label = find.byKey(const ValueKey('calendar-now-label'));
      for (final showLessons in [true, false]) {
        if (!showLessons) {
          await tap(t, find.byKey(const ValueKey('calendar-show-lessons')));
        }
        await tap(t, find.byKey(const ValueKey('calendar-mode-day')));
        final oldY = t.getTopLeft(line).dy;
        final minuteHeight =
            (t.getTopLeft(find.byKey(const ValueKey('calendar-hour-540'))).dy -
                t
                    .getTopLeft(find.byKey(const ValueKey('calendar-hour-480')))
                    .dy) /
            60;
        now = now.add(const Duration(minutes: 1));
        await t.pump(const Duration(minutes: 1));
        expect(t.getTopLeft(line).dy - oldY, closeTo(minuteHeight, .01));
        expect(
          find.descendant(of: label, matching: find.text('08:${now.minute}')),
          findsOneWidget,
        );
        await tap(t, find.byTooltip('Nächster Zeitraum'));
        expect(line, findsNothing);
        await tap(t, find.byTooltip('Vorheriger Zeitraum'));
        expect(line, findsOneWidget);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('today includes current time before and after teaching hours', (
    t,
  ) async {
    final c = await controller();
    for (final hour in [0, 6, 23]) {
      await host(
        t,
        c,
        builder: (_) => SingleChildScrollView(
          child: CalendarTimeline(
            days: [DateTime(2026, 11, 2)],
            items: const [],
            now: DateTime(2026, 11, 2, hour, 59),
            selectedDate: '2026-11-02',
            onOpen: (_) {},
            onDay: (_) {},
          ),
        ),
      );
      final line = find.byKey(const ValueKey('calendar-now-line'));
      expect(line, findsOneWidget);
      await t.ensureVisible(line);
      await t.pumpAndSettle();
      expect(t.getRect(line).top, inInclusiveRange(0, 844));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }
  });

  for (final setting in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    testWidgets(
      'populated day week month remain usable at width ${setting.$1} scale ${setting.$2}',
      (t) async {
        final c = await controller(seed: true);
        final key = await host(
          t,
          c,
          size: Size(setting.$1, 844),
          scale: setting.$2,
        );
        for (final mode in ['day', 'week', 'month']) {
          await tap(t, find.byKey(ValueKey('calendar-mode-$mode')));
          expect(t.takeException(), isNull);
          expect(find.text('Anlegen').hitTestable(), findsOneWidget);
          expect(find.text('Verwalten').hitTestable(), findsOneWidget);
          await capture(
            t,
            key,
            'calendar-$mode-${setting.$1.toInt()}-${setting.$2.toInt()}',
          );
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'calendar groups due pupils without losing the original entries',
    (t) async {
      final c = await controller(seed: true);
      await host(t, c);
      final grid = find.byKey(const ValueKey('calendar-time-grid-day'));
      expect(t.getTopLeft(grid).dy, lessThan(350));
      await tap(t, find.text('2 HÜ'));
      expect(find.text('Lesen · S. 12'), findsNWidgets(2));
      expect(find.textContaining('Alex'), findsOneWidget);
      expect(find.textContaining('Sam'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'month selection keeps month then opens selected day and dated creation',
    (t) async {
      final c = await controller(seed: true);
      await host(t, c);
      await tap(t, find.byKey(const ValueKey('calendar-mode-month')));
      await tap(t, find.byKey(const ValueKey('calendar-month-2026-11-05')));
      expect(find.text('November 2026'), findsOneWidget);
      await tap(t, find.byTooltip('Tagesansicht öffnen'));
      expect(find.textContaining('Do, 5. November'), findsOneWidget);
      await tap(t, find.text('Anlegen'));
      expect(find.text('Anlegen · 05.11.2026'), findsOneWidget);
      expect(find.text('Termin'), findsOneWidget);
      expect(find.text('Aufgabe'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'week overlaps open every source and weekends with entries stay visible',
    (t) async {
      final c = await controller(seed: true);
      await c.repository.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Samstagstermin',
          appointmentDate: '2026-11-07',
          appointmentTime: '09:00',
        ),
      );
      await c.reload();
      await host(t, c);
      await tap(t, find.byKey(const ValueKey('calendar-mode-week')));
      expect(find.text('Sa'), findsOneWidget);
      expect(find.text('So'), findsOneWidget);
      await tap(
        t,
        find
            .ancestor(
              of: find.text('Elterngespräch').first,
              matching: find.byType(InkWell),
            )
            .last,
      );
      expect(find.text('2 Einträge'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Elterngespräch'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'single lesson edit past series end retains preparation and inheritance',
    (t) async {
      final c = await controller();
      final file = material('Testdatei');
      await c.saveClassroom(file);
      final doc = await c.repository.saveClassroomDocument(
        lesson(
          rule: const RepeatRule(frequency: 'weekly', until: '2026-11-09'),
          materials: [file.id],
        ),
      );
      await c.reload();
      await host(
        t,
        c,
        builder: (ctx) => TextButton(
          onPressed: () => showClassroomEditor(
            ctx,
            c,
            ClassroomKind.lesson,
            document: doc,
            occurrenceDate: '2026-11-09',
          ),
          child: const Text('Edit'),
        ),
      );
      await tap(t, find.text('Edit'));
      await tap(t, find.text('Beginn / Datum: 09.11.2026'));
      await tap(t, find.text('12'));
      await tap(t, find.text('Übernehmen'));
      await t.enterText(
        find.byKey(const ValueKey('classroom-note')),
        'Spezielle Notiz',
      );
      await tap(t, find.text('Speichern'));
      final saved = c.classroom.firstWhere((d) => d.id == doc.id);
      final current = lessonOccurrences(
        [saved],
        '2026-11-12',
        '2026-11-12',
      ).single;
      expect(current.note, 'Spezielle Notiz');
      expect(current.materialIds, [file.id]);
      expect(
        saved.rows('exceptions').single.containsKey('materialIds'),
        isFalse,
      );
      expect(saved.rows('exceptions').single.containsKey('start'), isFalse);
      expect(await c.repository.dialogDrafts(), isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'lesson planning is created and linked atomically to this occurrence',
    (t) async {
      final c = await controller();
      await c.saveClassroom(
        lesson(rule: const RepeatRule(frequency: 'weekly')),
      );
      final item = calendarItems(
        c.currentSnapshot,
        '2026-11-02',
        '2026-11-02',
      ).single;
      await host(
        t,
        c,
        builder: (ctx) => TextButton(
          onPressed: () => showCalendarItem(ctx, c, item),
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.text('Planung zuordnen'));
      await tap(t, find.text('Neue Planung für diese Stunde'));
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Brüche üben',
      );
      await tap(t, find.text('Speichern'));
      final doc = c.classroom.singleWhere(
        (d) => d.kind == ClassroomKind.lesson,
      );
      final plan = c.classroom.singleWhere((d) => d.kind == ClassroomKind.plan);
      final occurrences = lessonOccurrences([doc], '2026-11-02', '2026-11-09');
      expect(lessonPlans(c.classroom, occurrences.first).single.id, plan.id);
      expect(lessonPlans(c.classroom, occurrences.last), isEmpty);
      expect(plan.text('date'), isEmpty);
      expect(await c.repository.dialogDrafts(), isEmpty);
      expect(find.text('Brüche üben'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'file assignment in lesson details changes only the selected occurrence',
    (t) async {
      final c = await controller();
      final file = material('Nur am Montag');
      await c.saveClassroom(file);
      await c.saveClassroom(
        lesson(rule: const RepeatRule(frequency: 'weekly')),
      );
      final item = calendarItems(
        c.currentSnapshot,
        '2026-11-02',
        '2026-11-02',
      ).single;
      await host(
        t,
        c,
        builder: (ctx) => TextButton(
          onPressed: () => showCalendarItem(ctx, c, item),
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.text('Dateien dieser Stunde'));
      await tap(t, find.text('Nur am Montag'));
      await tap(t, find.text('Übernehmen'));
      final doc = c.classroom.singleWhere(
        (d) => d.kind == ClassroomKind.lesson,
      );
      final occurrences = lessonOccurrences([doc], '2026-11-02', '2026-11-09');
      expect(occurrences.first.materialIds, [file.id]);
      expect(occurrences.last.materialIds, isEmpty);
      expect(find.widgetWithText(ListTile, 'Nur am Montag'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'splitting a series preserves occurrence files and linked planning',
    (t) async {
      final c = await controller();
      final file = material('Vorbereitet');
      await c.saveClassroom(file);
      var doc = patchLessonOccurrence(
        lesson(rule: const RepeatRule(frequency: 'weekly')),
        '2026-11-16',
        {
          'materialIds': [file.id],
        },
      );
      doc = await c.repository.saveClassroomDocument(doc);
      await c.saveClassroom(
        ClassroomDocument.create(ClassroomKind.plan, 'Serienplanung', {
          'lessonIds': [doc.id],
        }),
      );
      await host(
        t,
        c,
        builder: (ctx) => TextButton(
          onPressed: () => showClassroomEditor(
            ctx,
            c,
            ClassroomKind.lesson,
            document: doc,
            occurrenceDate: '2026-11-09',
            following: true,
          ),
          child: const Text('Split'),
        ),
      );
      await tap(t, find.text('Split'));
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Neue Serie',
      );
      await tap(t, find.text('Speichern'));
      final occurrences = lessonOccurrences(
        c.classroom,
        '2026-11-02',
        '2026-11-16',
      );
      expect(occurrences.map((l) => l.title), [
        'Mathematik',
        'Neue Serie',
        'Neue Serie',
      ]);
      expect(occurrences.last.materialIds, [file.id]);
      expect(
        occurrences.every(
          (l) => lessonPlans(c.classroom, l).single.title == 'Serienplanung',
        ),
        isTrue,
      );
      expect(await c.repository.dialogDrafts(), isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'week keeps a conversation visible inside Flexk and both entries reachable',
    (t) async {
      final c = await controller();
      await c.saveClassroom(
        lesson(
          date: '2026-11-02',
        ).patch({'title': 'Flexk', 'start': '07:45', 'end': '11:30'}),
      );
      await c.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Gespräch',
          appointmentDate: '2026-11-02',
          appointmentTime: '09:00',
        ),
      );
      final key = await host(t, c);
      await tap(t, find.byKey(const ValueKey('calendar-mode-week')));
      expect(find.text('Flexk'), findsOneWidget);
      expect(find.text('Gespräch'), findsOneWidget);
      await capture(t, key, 'calendar-week-overlap');
      await tap(
        t,
        find
            .ancestor(of: find.text('Gespräch'), matching: find.byType(InkWell))
            .last,
      );
      expect(find.text('2 Einträge'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Flexk'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Gespräch'), findsOneWidget);
      await tap(t, find.widgetWithText(ListTile, 'Flexk'));
      expect(find.text('Nur diesen Termin bearbeiten'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
