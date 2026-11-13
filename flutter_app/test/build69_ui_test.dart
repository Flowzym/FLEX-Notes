import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/app_navigation.dart';
import 'package:flex_notizbuch/ui/calendar_page.dart';
import 'package:flex_notizbuch/ui/calendar_timeline.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/scan_editor.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  late NotebookController c;
  final boundary = GlobalKey();
  setUp(() async {
    c = NotebookController(classroomMemory());
    await c.initialize();
    await c.savePupil(const Pupil(id: 'anna', name: 'Anna Beispiel'));
    await c.savePupil(const Pupil(id: 'ben', name: 'Ben Beispiel'));
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  Future<void> app(
    WidgetTester t, {
    double width = 390,
    double scale = 1,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 844);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    await t.binding.setSurfaceSize(Size(width, 844));
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FlexApp(controller: c),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> end(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    await t.binding.setSurfaceSize(null);
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f.last);
    await t.pumpAndSettle();
    await t.tap(f.last);
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    final dir = Platform.environment['FLEX_RENDER_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'quick add chooses pupil once and opens matching existing editor',
    (t) async {
      await app(t);
      await tap(t, find.byKey(const ValueKey('quick-add')));
      await capture(t, 'quick-add');
      await tap(t, find.byKey(const ValueKey('quick-add-social')));
      await tap(t, find.text('Anna Beispiel').last);
      expect(
        t.widget<SchoolEditor>(find.byType(SchoolEditor)).record.pupilId,
        'anna',
      );
      expect(
        t.widget<SchoolEditor>(find.byType(SchoolEditor)).record.kind.name,
        'social',
      );
      await end(t);
    },
  );
  testWidgets(
    'individual phases keep independent time and materials can be assigned without editing mode',
    (t) async {
      final material = ClassroomDocument.create(
        ClassroomKind.material,
        'Leseblatt',
        {'url': 'https://example.org/leseblatt', 'extension': 'link'},
      );
      await c.saveClassroom(material);
      await app(t);
      await tap(t, find.byKey(const ValueKey('page-2')));
      await tap(t, find.byKey(const ValueKey('flow-scope-true')));
      await tap(t, find.byKey(const ValueKey('flow-pupil-start-anna')));
      expect(
        c.classroom
            .where(
              (d) => hasLessonFlow(d) && lessonPhases(d).any((p) => p.running),
            )
            .length,
        1,
      );
      expect(lessonFlowPupil(c.classroom.singleWhere(hasLessonFlow)), 'anna');
      await tap(t, find.byTooltip('Ablauf anpassen · Ben Beispiel'));
      await tap(t, find.byTooltip('Phase bearbeiten: Ankommen'));
      final duration = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Dauer · optional',
      );
      await t.enterText(duration, '25');
      await tap(t, find.text('Speichern'));
      final ben = c.classroom.singleWhere((d) => lessonFlowPupil(d) == 'ben');
      expect(lessonPhases(ben).first.minutes, 25);
      expect(
        lessonPhases(
          c.classroom.singleWhere((d) => lessonFlowPupil(d) == 'anna'),
        ).first.minutes,
        10,
      );
      await tap(t, find.byKey(const ValueKey('flow-materials')));
      await tap(t, find.text('Alle Materialien'));
      await tap(t, find.byTooltip('Zuordnen: Leseblatt'));
      await tap(t, find.text('Ankommen').last);
      final updated = c.classroom.singleWhere(
        (d) => lessonFlowPupil(d) == 'ben',
      );
      expect(lessonPhases(updated).first.materialIds, [material.id]);
      expect(
        c.classroom.where((d) => d.kind == ClassroomKind.material).length,
        1,
      );
      await tap(t, find.byTooltip('Schließen').last);
      await t.scrollUntilVisible(
        find.byTooltip('Alle Schülerabläufe'),
        -250,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('lesson-flow')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(t, find.byTooltip('Alle Schülerabläufe'));
      await capture(t, 'individual-flow');
      expect(t.takeException(), isNull);
      await end(t);
    },
  );
  testWidgets(
    'rapid cyclic header swipes retain order through repeated wraparound',
    (t) async {
      await app(t);
      for (final section in [
        (1, [1, 0, 2]),
        (2, [0, 3, 2]),
        (3, [0, 1, 2, 3]),
        (4, [0, 1, 2, 3, 4, 5]),
      ]) {
        await tap(t, find.byKey(ValueKey('bottom-${section.$1}')));
        for (final direction in [-1, 1]) {
          var index = section.$2.indexOf(
            t.widget<FlexPagePills>(find.byType(FlexPagePills).first).selected,
          );
          for (var n = 0; n < section.$2.length * 2; n++) {
            await t.drag(
              find.byKey(
                ValueKey(
                  section.$1 == 1
                      ? 'page-${section.$2.first}'
                      : 'context-${section.$1}-${section.$2.first}',
                ),
              ),
              Offset(direction * 180, 0),
            );
            await t.pump(const Duration(milliseconds: 30));
            index = (index - direction) % section.$2.length;
            expect(
              t
                  .widget<FlexPagePills>(find.byType(FlexPagePills).first)
                  .selected,
              section.$2[index],
            );
            if (section.$1 == 1 || section.$1 == 2) {
              expect(
                t
                    .widget<IndexedStack>(
                      find.byKey(
                        ValueKey(
                          section.$1 == 1 ? 'main-pages' : 'organisation-pages',
                        ),
                      ),
                    )
                    .index,
                index,
              );
            }
          }
        }
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
      await end(t);
    },
  );
  testWidgets(
    'calendar body swipes dates without page pills; creation inherits selected date',
    (t) async {
      await c.saveAppearance(const Appearance(calendarDefaultView: 'week'));
      await app(t);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      expect(
        t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).week,
        true,
      );
      for (final pair in [('day', 1), ('week', 7)]) {
        await tap(t, find.byKey(ValueKey('calendar-mode-${pair.$1}')));
        final before = t
            .widget<CalendarTimeline>(find.byType(CalendarTimeline))
            .selectedDate;
        await t.dragFrom(const Offset(300, 420), const Offset(-210, 0));
        await t.pumpAndSettle();
        final after = t
            .widget<CalendarTimeline>(find.byType(CalendarTimeline))
            .selectedDate;
        expect(schoolDay(after).difference(schoolDay(before)).inDays, pair.$2);
        expect(find.byType(FlexPagePills), findsNothing);
        await t.dragFrom(const Offset(80, 420), const Offset(210, 0));
        await t.pumpAndSettle();
        expect(
          t
              .widget<CalendarTimeline>(find.byType(CalendarTimeline))
              .selectedDate,
          before,
        );
      }
      await tap(t, find.byKey(const ValueKey('calendar-mode-month')));
      final date = DateTime.now();
      await t.dragFrom(const Offset(300, 430), const Offset(-210, 0));
      await t.pumpAndSettle();
      final next = DateTime.utc(date.year, date.month + 1, 1);
      expect(
        find.byKey(ValueKey('calendar-month-${dateOnly(next)}')),
        findsOneWidget,
      );
      final chosen = next.add(const Duration(days: 4));
      await tap(t, find.byKey(ValueKey('calendar-month-${dateOnly(chosen)}')));
      await tap(t, find.byKey(const ValueKey('quick-add')));
      await tap(t, find.byKey(const ValueKey('quick-add-appointment')));
      expect(
        t.widget<OrgaEditor>(find.byType(OrgaEditor)).entry.appointmentDate,
        dateOnly(chosen),
      );
      await end(t);
    },
  );
  for (final size in [(320.0, 1.0), (390.0, 1.0), (320.0, 1.8)]) {
    testWidgets(
      'weekend and quick add remain reachable at ${size.$1}/${size.$2}',
      (t) async {
        await app(t, width: size.$1, scale: size.$2);
        await tap(t, find.byKey(const ValueKey('bottom-0')));
        await tap(t, find.byKey(const ValueKey('calendar-mode-week')));
        final calendar = t.state(find.byType(CalendarPage));
        if (size.$2 == 1) {
          expect(
            t.getRect(find.text('Fr').first).right,
            lessThanOrEqualTo(size.$1),
          );
        }
        // Current real date may be a weekend; it is initially shown automatically.
        if (t
                .widget<CalendarTimeline>(find.byType(CalendarTimeline))
                .days
                .length ==
            5) {
          await tap(t, find.byKey(const ValueKey('calendar-weekends')));
        }
        expect(
          t.widget<CalendarTimeline>(find.byType(CalendarTimeline)).days.length,
          7,
        );
        await capture(t, 'calendar-${size.$1}-${size.$2}');
        if (size.$2 == 1) {
          expect(
            t.getRect(find.text('So').first).right,
            lessThanOrEqualTo(size.$1),
          );
          expect(t.getRect(find.text('Sa').first).left, greaterThan(0));
          expect(
            t
                .getTopLeft(
                  find.byKey(const ValueKey('calendar-time-grid-week')),
                )
                .dy,
            lessThan(330),
          );
        } else {
          await tap(t, find.byTooltip('Wochenende anzeigen'));
          expect(find.text('So').hitTestable(), findsOneWidget);
        }
        expect(t.state(find.byType(CalendarPage)), same(calendar));
        await tap(t, find.byKey(const ValueKey('quick-add')));
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('quick-add-holiday')),
          220,
          scrollable: find.byType(Scrollable).last,
        );
        await capture(t, 'add-menu-${size.$1}-${size.$2}');
        expect(t.takeException(), isNull);
        await end(t);
      },
    );
  }
  testWidgets(
    'overdue tasks disappear after completing subtasks; adding one reopens the parent',
    (t) async {
      final task = OrgaEntry.empty().copyWith(
        title: 'Ausflug organisieren',
        body: 'Ausflug organisieren',
        isTask: true,
        dueDate: dateOnly(DateTime.now().subtract(const Duration(days: 2))),
        items: [const CheckItem(id: 'transport', text: 'Bus bestellen')],
      );
      await c.saveEntry(task);
      await app(t);
      await tap(t, find.byKey(const ValueKey('page-0')));
      await tap(t, find.byKey(const ValueKey('overview-section-overdue')));
      expect(find.text('Ausflug organisieren'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-3')));
      await tap(t, find.byKey(const ValueKey('subtask-transport')));
      expect(c.entries.single.done, true);
      await tap(t, find.byTooltip('Unteraufgabe hinzufügen'));
      await t.enterText(
        find.byType(TextField).last,
        'Einverständnisse sammeln',
      );
      await tap(t, find.text('Hinzufügen').last);
      expect(c.entries.single.done, false);
      expect(c.entries.single.items.length, 2);
      expect(c.entries.single.items.first.checked, true);
      await tap(t, find.byTooltip('Erledigen'));
      await tap(t, find.byKey(const ValueKey('bottom-1')));
      await tap(t, find.byKey(const ValueKey('overview-section-overdue')));
      expect(find.text('Nichts überfällig.'), findsOneWidget);
      expect(t.takeException(), isNull);
      await end(t);
    },
  );
  testWidgets(
    'pupil quick capture inherits owner and calendar default can be selected in settings',
    (t) async {
      await app(t);
      await tap(t, find.text('Anna Beispiel'));
      await tap(t, find.byKey(const ValueKey('quick-add')).last);
      await tap(t, find.byKey(const ValueKey('quick-add-scan')));
      expect(t.widget<ScanEditor>(find.byType(ScanEditor)).scope.pupilIds, [
        'anna',
      ]);
      await end(t);
      await app(t);
      await tap(t, find.byKey(const ValueKey('bottom-4')));
      await tap(t, find.byKey(const ValueKey('context-4-4')));
      await tap(t, find.byKey(const ValueKey('settings-tab-1')));
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('calendar-default-month')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('settings')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(t, find.byKey(const ValueKey('calendar-default-month')));
      await t.runAsync(c.flushAppearance);
      expect((await c.repository.appearance()).calendarDefaultView, 'month');
      await end(t);
      await app(t);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      expect(
        find.byKey(ValueKey('calendar-month-${dateOnly(DateTime.now())}')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await end(t);
    },
  );
}
