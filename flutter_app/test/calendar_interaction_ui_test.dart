import 'package:flex_notizbuch/ui/calendar_drag.dart';
import 'package:flex_notizbuch/ui/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/calendar_page.dart';
import 'package:flex_notizbuch/ui/calendar_timeline.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  late NotebookController c;
  setUp(() async {
    c = NotebookController(classroomMemory());
    await c.initialize();
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  Future<void> host(WidgetTester t) async {
    t.view.physicalSize = const Size(320, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CalendarPage(
            controller: c,
            clock: () => DateTime(2026, 11, 9, 8),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  testWidgets('outside swipes change views; grid swipes change only dates', (
    t,
  ) async {
    await host(t);
    final toolbar = find.byKey(const ValueKey('calendar-toolbar'));
    Future<void> swipeHeader(double dx) async {
      final rect = t.getRect(toolbar);
      await t.dragFrom(
        Offset(dx < 0 ? rect.right - 20 : rect.left + 20, rect.center.dy),
        Offset(dx, 0),
      );
      await t.pumpAndSettle();
    }

    await swipeHeader(-180);
    expect(
      t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).week,
      true,
    );
    expect(
      t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).selectedDate,
      '2026-11-09',
    );
    final grid = t.getRect(
      find.byKey(const ValueKey('calendar-time-grid-week')),
    );
    await t.dragFrom(Offset(280, grid.top + 100), const Offset(-180, 0));
    await t.pumpAndSettle();
    expect(
      t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).selectedDate,
      '2026-11-16',
    );
    expect(
      t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).week,
      true,
    );
    expect(find.byType(OrgaEditor), findsNothing);
    await swipeHeader(-180);
    expect(
      find.byKey(const ValueKey('calendar-month-2026-11-16')),
      findsOneWidget,
    );
    await swipeHeader(-180);
    expect(
      t.widget<FlexTabTransition>(find.byType(FlexTabTransition)).direction,
      1,
    );
    expect(
      t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).week,
      false,
    );
    await swipeHeader(180);
    expect(
      t.widget<FlexTabTransition>(find.byType(FlexTabTransition)).direction,
      -1,
    );
    expect(
      find.byKey(const ValueKey('calendar-month-2026-11-16')),
      findsOneWidget,
    );
    await finish(t);
  });
  testWidgets(
    'touch a free time field then save an appointment at that exact time',
    (t) async {
      await host(t);
      final y = t
          .getTopLeft(find.byKey(const ValueKey('calendar-hour-600')))
          .dy;
      await t.tapAt(Offset(220, y + 4));
      await t.pumpAndSettle();
      final editor = t.widget<OrgaEditor>(find.byType(OrgaEditor));
      expect(editor.entry.appointmentDate, '2026-11-09');
      expect(editor.entry.appointmentTime, '10:00');
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Elterngespräch',
      );
      await t.pumpAndSettle();
      await tap(t, find.text('Speichern'));
      expect(c.entries.single.appointmentDate, '2026-11-09');
      expect(c.entries.single.appointmentTime, '10:00');
      expect(c.entries.single.body, 'Elterngespräch');
      expect(find.byType(OrgaEditor), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'week touch respects its column; month touch creates an all-day draft',
    (t) async {
      await host(t);
      await tap(t, find.byKey(const ValueKey('calendar-mode-week')));
      final col = t.getRect(
        find.byKey(const ValueKey('calendar-create-2026-11-11')),
      );
      final y = t
          .getTopLeft(find.byKey(const ValueKey('calendar-hour-540')))
          .dy;
      await t.tapAt(Offset(col.center.dx, y + 3));
      await t.pumpAndSettle();
      expect(
        t.widget<OrgaEditor>(find.byType(OrgaEditor)).entry.appointmentDate,
        '2026-11-11',
      );
      expect(
        t.widget<OrgaEditor>(find.byType(OrgaEditor)).entry.appointmentTime,
        '09:00',
      );
      await tap(t, find.byKey(const ValueKey('cancel-editor')));
      await tap(t, find.byKey(const ValueKey('calendar-mode-month')));
      await tap(t, find.byKey(const ValueKey('calendar-month-2026-11-20')));
      expect(
        t.widget<OrgaEditor>(find.byType(OrgaEditor)).entry.appointmentDate,
        '2026-11-20',
      );
      expect(
        t.widget<OrgaEditor>(find.byType(OrgaEditor)).entry.appointmentTime,
        isEmpty,
      );
      await tap(t, find.byKey(const ValueKey('cancel-editor')));
      expect(c.entries, isEmpty);
      expect(c.drafts, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'long press selects resize handles without creating a duplicate; ordinary tap edits',
    (t) async {
      await c.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Bestehend',
          appointmentDate: '2026-11-09',
          appointmentTime: '09:00',
        ),
      );
      await host(t);
      await tap(t, find.text('Bestehend'));
      expect(
        t.widget<OrgaEditor>(find.byType(OrgaEditor)).entry.revision,
        greaterThan(0),
      );
      await tap(t, find.byKey(const ValueKey('cancel-editor')));
      await t.longPress(find.text('Bestehend'));
      await t.pumpAndSettle();
      expect(find.byType(OrgaEditor), findsNothing);
      expect(
        find.byKey(ValueKey('calendar-resize-end-orga:${c.entries.single.id}')),
        findsOneWidget,
      );
      expect(c.entries, hasLength(1));
      await finish(t);
    },
  );
  testWidgets(
    'touch move and resize persist a real duration and can be undone',
    (t) async {
      await c.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Verschieben',
          appointmentDate: '2026-11-09',
          appointmentTime: '09:00',
          appointmentEndTime: '10:00',
        ),
      );
      await host(t);
      final id = c.entries.single.id;
      final hour =
          t.getTopLeft(find.byKey(const ValueKey('calendar-hour-600'))).dy -
          t.getTopLeft(find.byKey(const ValueKey('calendar-hour-540'))).dy;
      final gesture = await t.startGesture(
        t.getCenter(find.byKey(ValueKey('calendar-drag-orga:$id'))),
      );
      await t.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(Offset(0, hour));
      await t.pump();
      expect(c.entries.single.appointmentTime, '09:00');
      await gesture.up();
      await t.pumpAndSettle();
      expect(c.entries.single.appointmentTime, '10:00');
      expect(c.entries.single.appointmentEndTime, '11:00');
      final handle = find.byKey(ValueKey('calendar-resize-end-orga:$id'));
      await t.drag(handle, Offset(0, hour / 2), touchSlopY: 0);
      await t.pumpAndSettle();
      expect(c.entries.single.appointmentEndTime, '11:30');
      await c.reload();
      expect(c.entries.single.appointmentEndTime, '11:30');
      await tap(t, find.text('Rückgängig'));
      expect(c.entries.single.appointmentTime, '10:00');
      expect(c.entries.single.appointmentEndTime, '11:00');
      await finish(t);
    },
  );
  testWidgets('week drag crosses a day; cancelling never saves the preview', (
    t,
  ) async {
    final entry = await c.repository.saveEntry(
      OrgaEntry.empty().copyWith(
        title: 'Verschieben',
        appointmentDate: '2026-11-09',
        appointmentTime: '09:00',
        appointmentEndTime: '10:00',
      ),
    );
    await c.reload();
    await host(t);
    await tap(t, find.byKey(const ValueKey('calendar-mode-week')));
    final block = find.byKey(ValueKey('calendar-drag-orga:${entry.id}'));
    final spec = t.widget<CalendarDragBlock>(find.byType(CalendarDragBlock));
    final original = await t.startGesture(t.getCenter(block));
    await t.pump(const Duration(milliseconds: 600));
    await original.moveBy(Offset(spec.dayWidth, spec.pixelsPerMinute * 30));
    await t.pump();
    await original.cancel();
    await t.pumpAndSettle();
    expect(c.entries.single.appointmentDate, '2026-11-09');
    expect(c.entries.single.appointmentTime, '09:00');
    final gesture = await t.startGesture(t.getCenter(block));
    await t.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(Offset(spec.dayWidth, spec.pixelsPerMinute * 30));
    await t.pump();
    await gesture.up();
    await t.pumpAndSettle();
    expect(c.entries.single.appointmentDate, '2026-11-10');
    expect(c.entries.single.appointmentTime, '09:30');
    expect(c.entries.single.appointmentEndTime, '10:30');
    await finish(t);
  });
}
