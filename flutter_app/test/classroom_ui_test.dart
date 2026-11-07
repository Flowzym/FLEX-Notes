import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';
import 'package:flex_notizbuch/ui/conflict_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'package:flex_notizbuch/ui/calendar_page.dart';
import 'package:flex_notizbuch/ui/return_lists.dart';
import 'package:flex_notizbuch/ui/development_dialog.dart';
import 'package:flex_notizbuch/ui/prototype_navigation.dart';
import 'classroom_test.dart' show classroomMemory, lesson, returns;

void main() {
  setUpAll(() async {
    final loader = FontLoader('FlexSans')
      ..addFont(rootBundle.load('assets/fonts/Selawik-Regular.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    final folder = Platform.environment['FLEX_TEST_ARTIFACT_DIR'];
    if (folder == null) return;
    await t.runAsync(() async {
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(folder).create(recursive: true);
      await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<NotebookController> controller() async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    return c;
  }

  Future<void> host(
    WidgetTester t,
    Widget Function(BuildContext) builder, {
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: Builder(builder: builder)),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  test(
    'classroom conflict previews describe all changed series and payment fields',
    () async {
      final c = await controller();
      final text = conflictText('participants', [
        {
          'name': 'Kind',
          'status': 'partial',
          'paid': 450,
          'note': 'Rest folgt',
        },
      ], c);
      expect(text, contains('Teilbezahlt'));
      expect(text, contains('4.50 €'));
      expect(text, contains('Rest folgt'));
      expect(
        conflictText(
          'repeat',
          const RepeatRule(frequency: 'weekly', interval: 2).toJson(),
          c,
        ),
        contains('Wöchentlich'),
      );
      expect(
        conflictText('exceptions', [
          {'date': '2026-11-09', 'cancelled': true},
        ], c),
        contains('Entfällt: Ja'),
      );
    },
  );
  testWidgets(
    'app navigation swipes between pupils calendar and materials with live data',
    (t) async {
      final c = await controller();
      await c.repository.saveClassroomDocument(
        lesson(date: dateOnly(DateTime.now())),
      );
      await c.repository.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Wochenplan · Lesen', {
          'url': 'https://example.org/wochenplan.docx',
          'extension': 'docx',
          'subject': 'Deutsch',
        }),
      );
      await c.reload();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(
                'plugins.it_nomads.com/flutter_secure_storage',
              ),
              null,
            ),
      );
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: FlexApp(controller: c),
        ),
      );
      await t.runAsync(
        () => precacheImage(
          const AssetImage(FlexBackground.defaultDarkImage),
          t.element(find.byType(FlexBackground).first),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('page-1')));
      await t.drag(find.byType(PageView), const Offset(-320, 0));
      await t.pumpAndSettle();
      expect(find.text('Dieser Bereich wird noch gestaltet.'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      await tap(t, find.byKey(const ValueKey('context-0-1')));
      expect(find.byKey(const ValueKey('timetable-view')), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('calendar-shortcut')));
      expect(find.byKey(const ValueKey('calendar-view')), findsOneWidget);
      await capture(t, key, 'calendar-phone');
      await tap(t, find.byKey(const ValueKey('bottom-3')));
      expect(find.text('Wochenplan · Lesen'), findsOneWidget);
      await capture(t, key, 'materials-phone');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'four calendar page buttons remain visible and usable at large text on phone',
    (t) async {
      var selected = -1;
      await host(
        t,
        (_) => FlexPagePills(
          selected: 0,
          pages: calendarPages,
          onSelected: (v) => selected = v,
        ),
        scale: 2,
      );
      final shell = t.getRect(find.byKey(const ValueKey('page-pills')));
      final active = t.getRect(find.byKey(const ValueKey('page-0')));
      final track = t.getRect(find.byKey(const ValueKey('page-track-0')));
      expect(active.top, lessThan(track.top));
      expect(active.bottom, greaterThan(track.bottom));
      expect(active.left, lessThan(track.left));
      for (final i in [0, 1, 2, 3]) {
        final button = t.getRect(find.byKey(ValueKey('page-$i')));
        expect(shell.contains(button.topLeft), isTrue);
        expect(shell.contains(button.bottomRight), isTrue);
        await tap(t, find.byKey(ValueKey('page-$i')));
        expect(selected, i);
      }
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'lesson editor retains focus through autosave and restores a draft',
    (t) async {
      final c = await controller();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showClassroomEditor(ctx, c, ClassroomKind.lesson),
          child: const Text('Start'),
        ),
      );
      await tap(t, find.text('Start'));
      final title = find.byKey(const ValueKey('classroom-title'));
      await t.enterText(title, 'Lesestunde');
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      final editable = t.widget<EditableText>(
        find.descendant(of: title, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      await tap(t, find.text('Abbrechen'));
      final saved = (await c.repository.dialogDrafts()).single;
      expect(saved.data['title'], 'Lesestunde');
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () =>
              showClassroomEditor(ctx, c, ClassroomKind.lesson, draft: saved),
          child: const Text('Fortsetzen'),
        ),
      );
      await tap(t, find.text('Fortsetzen'));
      expect(find.text('Lesestunde'), findsOneWidget);
      await tap(t, find.text('Speichern'));
      expect(
        (await c.repository.classroomDocuments()).single.title,
        'Lesestunde',
      );
      expect(await c.repository.dialogDrafts(), isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'single lesson edit changes one occurrence and leaves series fields intact',
    (t) async {
      final c = await controller();
      final doc = await c.repository.saveClassroomDocument(
        lesson(
          rule: const RepeatRule(frequency: 'weekly'),
        ).patch({'subject': 'Mathematik', 'room': 'A'}),
      );
      await c.reload();
      await host(
        t,
        (ctx) => TextButton(
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
      expect(find.byKey(const ValueKey('classroom-subject')), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('classroom-title')),
        'Vertretung',
      );
      await tap(t, find.text('Speichern'));
      final saved = (await c.repository.classroomDocuments()).single;
      expect(saved.title, 'Mathematik');
      expect(saved.text('room'), 'A');
      expect(saved.rows('exceptions').single['title'], 'Vertretung');
      expect(
        lessonOccurrences(
          [saved],
          '2026-11-09',
          '2026-11-16',
        ).map((l) => l.title),
        ['Vertretung', 'Mathematik'],
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'future lesson series split preserves past lessons and removes its draft',
    (t) async {
      final c = await controller();
      final doc = await c.repository.saveClassroomDocument(
        lesson(rule: const RepeatRule(frequency: 'weekly')),
      );
      await c.reload();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showClassroomEditor(
            ctx,
            c,
            ClassroomKind.lesson,
            document: doc,
            occurrenceDate: '2026-11-09',
            following: true,
          ),
          child: const Text('Edit'),
        ),
      );
      await tap(t, find.text('Edit'));
      await t.enterText(find.byKey(const ValueKey('classroom-title')), 'Neu');
      await tap(t, find.text('Speichern'));
      final docs = await c.repository.classroomDocuments();
      expect(docs.length, 2);
      expect(
        lessonOccurrences(docs, '2026-11-02', '2026-11-16').map((l) => l.title),
        ['Mathematik', 'Neu', 'Neu'],
      );
      expect(await c.repository.dialogDrafts(), isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'return consent rejection counts as answered and bulk status persists',
    (t) async {
      final c = await controller();
      await c.repository.savePupil(const Pupil(id: 'p', name: 'Kind'));
      final doc = await c.repository.saveClassroomDocument(returns('p'));
      await c.reload();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showReturnDetail(ctx, c, doc.id),
          child: const Text('Start'),
        ),
        scale: 1.5,
      );
      await tap(t, find.text('Start'));
      await tap(t, find.text('Abgelehnt'));
      expect(
        (await c.repository.classroomDocuments()).single
            .rows('participants')
            .single['status'],
        'no',
      );
      expect(find.textContaining('0 offen'), findsOneWidget);
      await tap(t, find.text('Sichtbare auswählen'));
      await tap(t, find.text('Zugestimmt · 1'));
      expect(
        (await c.repository.classroomDocuments()).single
            .rows('participants')
            .single['status'],
        'yes',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'payment status resets old amount and partial payment requests an amount',
    (t) async {
      final c = await controller();
      await c.repository.savePupil(const Pupil(id: 'p', name: 'Kind'));
      final doc = await c.repository.saveClassroomDocument(
        returns('p', type: 'payment').patch({'amountDue': 1000}),
      );
      await c.reload();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showReturnDetail(ctx, c, doc.id),
          child: const Text('Start'),
        ),
      );
      await tap(t, find.text('Start'));
      await tap(t, find.text('Bezahlt'));
      expect(
        (await c.repository.classroomDocuments()).single
            .rows('participants')
            .single['paid'],
        1000,
      );
      await tap(t, find.text('Offen'));
      expect(
        (await c.repository.classroomDocuments()).single
            .rows('participants')
            .single['paid'],
        0,
      );
      await tap(t, find.text('Teilbezahlt'));
      await t.enterText(find.byType(TextFormField).last, '4,50');
      await tap(t, find.text('Übernehmen'));
      final row = (await c.repository.classroomDocuments()).single
          .rows('participants')
          .single;
      expect(row['status'], 'partial');
      expect(row['paid'], 450);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('calendar day week and month work with large text on phone', (
    t,
  ) async {
    final c = await controller();
    await host(t, (_) => CalendarPage(controller: c), scale: 2);
    for (final mode in ['day', 'week', 'month']) {
      await tap(t, find.byKey(ValueKey('calendar-mode-$mode')));
      expect(t.takeException(), isNull);
    }
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'development filters reach original observations without overflow',
    (t) async {
      final c = await controller();
      const pupil = Pupil(id: 'p', name: 'Kind');
      await c.repository.savePupil(pupil);
      await c.repository.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.social, 'p').patch({
          'body': 'Gemeinsam gelesen',
          'observedOn': dateOnly(DateTime.now()),
          'positive': ['Hilft'],
        }),
      );
      await c.reload();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showDevelopment(ctx, c, pupil),
          child: const Text('Start'),
        ),
        scale: 1.5,
      );
      await tap(t, find.text('Start'));
      await tap(t, find.text('Arbeit'));
      expect(find.text('Gemeinsam gelesen'), findsNothing);
      await tap(t, find.text('Sozial'));
      await tap(
        t,
        find.byKey(
          ValueKey(
            'development-week-${dateOnly(DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)))}',
          ),
        ),
      );
      await t.ensureVisible(find.text('Gemeinsam gelesen'));
      expect(find.text('Gemeinsam gelesen'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
