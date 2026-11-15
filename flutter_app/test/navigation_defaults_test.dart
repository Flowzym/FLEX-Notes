import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/app_navigation.dart';
import 'package:flex_notizbuch/ui/calendar_timeline.dart';
import 'package:flex_notizbuch/ui/scanner_library.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadAppTestFonts();
  });
  test(
    'old preferences keep familiar defaults and invalid routes are rejected',
    () {
      final defaults = Appearance.fromJson({});
      expect(defaults.liveDefaultPage, 1);
      expect(defaults.organisationDefaultPage, 0);
      expect(defaults.materialDefaultPage, 0);
      expect(defaults.moreDefaultPage, 0);
      expect(defaults.navigationSwipeNext, 'right');
      for (final change in [
        {'liveDefaultPage': 3},
        {'organisationDefaultPage': 1},
        {'materialDefaultPage': -1},
        {'moreDefaultPage': 5},
        {'navigationSwipeNext': 'up'},
      ]) {
        expect(() => defaults.patch(change), throwsA(isA<DomainError>()));
      }
    },
  );

  testWidgets(
    'default choices survive saving and reopening; menu and scanner have separate access',
    (t) async {
      final repo = classroomMemory();
      final c = NotebookController(repo);
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await repo.close();
      });
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      Future<void> tap(Finder f) async {
        await t.ensureVisible(f.last);
        await t.pumpAndSettle();
        await t.tap(f.last);
        await t.pumpAndSettle();
      }

      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      expect(
        t.getCenter(find.byKey(const ValueKey('page-1'))).dx,
        closeTo(195, 1),
      );
      expect(
        t.getRect(find.byKey(const ValueKey('header-more'))).center.dy,
        closeTo(
          t.getRect(find.byKey(const ValueKey('app-wordmark'))).center.dy,
          1,
        ),
      );
      await tap(find.byKey(const ValueKey('header-more')));
      expect(find.text('Klassen-Orga'), findsNothing);
      await tap(find.byKey(const ValueKey('context-4-4')));
      await tap(find.text('Bedienung'));
      for (final choice in [
        'calendar-default-week',
        'default-liveDefaultPage-2',
        'default-organisationDefaultPage-4',
        'default-materialDefaultPage-3',
        'default-moreDefaultPage-4',
        'navigation-swipe-next-left',
      ]) {
        await tap(find.byKey(ValueKey(choice)));
      }
      await t.runAsync(c.flushAppearance);
      expect((await repo.appearance()).liveDefaultPage, 2);
      final restored = classroomMemory();
      await restored.initialize();
      await restored.restoreBackup(await repo.exportBackup());
      expect((await restored.appearance()).toJson(), c.appearance.toJson());
      await restored.close();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      expect(t.widget<FlexPagePills>(find.byType(FlexPagePills)).selected, 2);
      for (final next in [0, 1, 2]) {
        await t.drag(
          find.byKey(const ValueKey('page-pills')),
          const Offset(-180, 0),
        );
        await t.pumpAndSettle();
        expect(
          t.widget<FlexPagePills>(find.byType(FlexPagePills)).selected,
          next,
        );
        expect(
          t
              .widget<FlexTabTransition>(find.byType(FlexTabTransition).first)
              .direction,
          1,
        );
      }
      for (final destination in [(2, 4), (3, 3), (4, 4)]) {
        await tap(
          find.byKey(
            ValueKey(
              destination.$1 == 4 ? 'header-more' : 'bottom-${destination.$1}',
            ),
          ),
        );
        expect(
          t.widget<FlexPagePills>(find.byType(FlexPagePills)).selected,
          destination.$2,
        );
      }
      await tap(find.byKey(const ValueKey('bottom-0')));
      expect(
        t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).week,
        true,
      );
      for (final next in [2, 0, 1]) {
        await t.drag(
          find.byKey(const ValueKey('calendar-mode-navigation')),
          const Offset(-180, 0),
        );
        await t.pumpAndSettle();
        expect(
          t.widget<FlexPagePills>(find.byType(FlexPagePills)).selected,
          next,
        );
      }
      await tap(find.byKey(const ValueKey('bottom-5')));
      expect(find.byType(ScannerLibrary), findsOneWidget);
      expect(find.byType(FlexPagePills), findsNothing);
      await c.saveAppearance(
        c.appearance.patch({
          'liveDefaultPage': 0,
          'calendarDefaultView': 'day',
        }),
      );
      await t.pumpAndSettle();
      await tap(find.byKey(const ValueKey('bottom-1')));
      expect(t.widget<FlexPagePills>(find.byType(FlexPagePills)).selected, 0);
      await tap(find.byKey(const ValueKey('bottom-0')));
      expect(
        t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).week,
        false,
      );
      expect(find.widgetWithText(TextButton, 'Heute'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
