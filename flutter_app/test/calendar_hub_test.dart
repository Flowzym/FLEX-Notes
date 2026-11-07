import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/calendar_page.dart';
import 'package:flex_notizbuch/ui/material_thumbnail.dart';
import 'package:flex_notizbuch/ui/document_attachments.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;

void main() {
  Future<NotebookController> controller() async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    await c.savePupil(const Pupil(id: 'p', name: 'Alex'));
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    return c;
  }

  Future<void> host(
    WidgetTester t,
    NotebookController c, {
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'calendar owns timetable without duplicate shortcuts, section callbacks preserve date',
    (t) async {
      final c = await controller();
      await host(t, c);
      expect(find.text('Stundenplan'), findsNothing);
      expect(find.text('Übersicht'), findsNothing);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      expect(find.byKey(const ValueKey('calendar-view')), findsOneWidget);
      final date = DateTime(2026, 12, 14);
      t
          .widget<CalendarPage>(find.byKey(const ValueKey('main-calendar')))
          .onSwitchSection!(true, date);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('timetable-view')), findsOneWidget);
      expect(
        t
            .widget<CalendarPage>(find.byKey(const ValueKey('main-timetable')))
            .shortcutDate,
        date,
      );
      expect(find.byKey(const ValueKey('calendar-shortcut')), findsNothing);
      expect(find.text('Zum Kalender'), findsNothing);
      t
          .widget<CalendarPage>(find.byKey(const ValueKey('main-timetable')))
          .onSwitchSection!(false, date);
      await t.pumpAndSettle();
      expect(find.text('Zum Stundenplan'), findsNothing);
      expect(
        t
            .widget<CalendarPage>(find.byKey(const ValueKey('main-calendar')))
            .shortcutDate,
        date,
      );
      await tap(t, find.byKey(const ValueKey('bottom-1')));
      expect(find.text('Stundenplan'), findsNothing);
      final pages = t.widget<PageView>(
        find.byKey(const ValueKey('main-pages')),
      );
      expect(
        (pages.childrenDelegate as SliverChildListDelegate).children.length,
        3,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'general tasks and notes are separated, saved through the existing editor and completed',
    (t) async {
      final c = await controller();
      await c.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Gemeinsame Notiz',
          body: 'Notizinhalt',
        ),
      );
      await c.saveEntry(
        OrgaEntry.empty(
          pupilId: 'p',
        ).copyWith(title: 'Nur Alex', body: 'Schüleraufgabe', isTask: true),
      );
      await host(t, c);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      await tap(t, find.byKey(const ValueKey('context-0-2')));
      expect(find.text('Nur Alex').hitTestable(), findsNothing);
      await tap(t, find.byKey(const ValueKey('general-add-task')));
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Kopien vorbereiten',
      );
      await tap(t, find.text('Speichern').last);
      final task = c.entries.singleWhere((e) => e.body == 'Kopien vorbereiten');
      expect(task.isTask, true);
      expect(task.pupilId, isNull);
      await tap(t, find.byTooltip('Erledigen').hitTestable());
      expect(c.entries.singleWhere((e) => e.id == task.id).done, true);
      await tap(t, find.text('Offen').hitTestable());
      expect(find.text('Kopien vorbereiten').hitTestable(), findsNothing);
      await tap(t, find.byKey(const ValueKey('context-0-3')));
      expect(find.text('Notizinhalt').hitTestable(), findsOneWidget);
      expect(find.text('Schüleraufgabe').hitTestable(), findsNothing);
      await tap(t, find.byKey(const ValueKey('general-add-note')));
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Besprechungsidee',
      );
      await tap(t, find.text('Speichern').last);
      final note = c.entries.singleWhere((e) => e.body == 'Besprechungsidee');
      expect(note.isTask, false);
      expect(note.pupilId, isNull);
      await tap(t, find.byKey(const ValueKey('context-0-2')));
      expect(find.text('Kopien vorbereiten').hitTestable(), findsNothing);
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      expect(find.text('Orga').hitTestable(), findsOneWidget);
      expect(find.text('Kopien vorbereiten'), findsWidgets);
      await tap(t, find.byKey(const ValueKey('context-2-1')));
      expect(find.byTooltip('Rücklauf anlegen'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'general drafts exclude pupil entries and are resumable at large text',
    (t) async {
      final c = await controller();
      for (final pupil in [null, 'p']) {
        await c.repository.saveDraft(
          EditDraft(
            id: newId(),
            entry: OrgaEntry.empty(pupilId: pupil).copyWith(
              body: pupil == null ? 'Allgemeiner Entwurf' : 'Schülerentwurf',
              isTask: true,
            ),
            updatedAtUtc: utcNow(),
          ),
        );
      }
      await c.reload();
      await host(t, c, scale: 2);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      await tap(t, find.byKey(const ValueKey('context-0-2')));
      await tap(t, find.byTooltip('Entwürfe · 1'));
      expect(find.text('Allgemeiner Entwurf'), findsOneWidget);
      expect(find.text('Schülerentwurf'), findsNothing);
      await tap(t, find.text('Allgemeiner Entwurf'));
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('orga-note')))
            .controller!
            .text,
        'Allgemeiner Entwurf',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'inline attachments and document access show actual thumbnail widgets',
    (t) async {
      final c = await controller();
      await c.saveClassroom(
        material(
          'Anhang',
          fields: {
            'scan': true,
            'pupilIds': ['p'],
            'localKey': 'pdf-page',
          },
        ),
      );
      const scope = ScanContext(pupilIds: ['p']);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DocumentAttachmentSection(controller: c, scope: scope),
                DocumentAttachmentsButton(controller: c, scope: scope),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(MaterialThumbnail), findsNWidgets(2));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
