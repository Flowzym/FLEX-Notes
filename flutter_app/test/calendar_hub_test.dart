import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'package:flex_notizbuch/ui/return_lists.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/app_navigation.dart';
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
    'calendar has no page pills and retains mode and lesson visibility across organisation visits',
    (t) async {
      final c = await controller();
      await host(t, c);
      expect(find.text('Stundenplan'), findsNothing);
      expect(find.text('Übersicht'), findsNothing);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      expect(find.byKey(const ValueKey('calendar-view')), findsOneWidget);
      expect(find.byType(FlexPagePills), findsNothing);
      final state = t.state(find.byKey(const ValueKey('main-calendar')));
      await tap(t, find.byKey(const ValueKey('calendar-mode-week')));
      await tap(t, find.byKey(const ValueKey('calendar-show-lessons')));
      final before = c.classroom.map((d) => d.toJson()).toList();
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-3')));
      expect(find.byKey(const ValueKey('general-add-task')), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      expect(find.byType(FlexPagePills), findsNothing);
      expect(t.state(find.byKey(const ValueKey('main-calendar'))), same(state));
      expect(
        find.byKey(const ValueKey('calendar-time-grid-week')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-show-lessons')),
          matching: find.byIcon(Icons.check_box_outline_blank),
        ),
        findsOneWidget,
      );
      expect(c.classroom.map((d) => d.toJson()).toList(), before);
      expect(find.byKey(const ValueKey('main-timetable')), findsNothing);
      expect(find.byKey(const ValueKey('context-0-2')), findsNothing);
      await tap(t, find.byKey(const ValueKey('bottom-1')));
      expect(find.text('Stundenplan'), findsNothing);
      final pages = t.widget<IndexedStack>(
        find.byKey(const ValueKey('main-pages')),
      );
      expect(pages.children.length, 3);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'calendar tasks and organisation notes retain entries and editing',
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
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-3')));
      expect(find.text('Nur Alex').hitTestable(), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('general-add-task')));
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Kopien vorbereiten',
      );
      await tap(t, find.byKey(const ValueKey('person-assignment')));
      await tap(t, find.byKey(const ValueKey('person-assignment-p')));
      await tap(t, find.byKey(const ValueKey('person-assignment-apply')));
      await tap(t, find.text('Speichern').last);
      final task = c.entries.singleWhere((e) => e.body == 'Kopien vorbereiten');
      expect(task.isTask, true);
      expect(task.pupilId, 'p');
      expect(find.text('Kopien vorbereiten').hitTestable(), findsOneWidget);
      await tap(
        t,
        find.descendant(
          of: find.byKey(ValueKey('orga-entry-${task.id}')).hitTestable(),
          matching: find.byTooltip('Erledigen'),
        ),
      );
      expect(c.entries.singleWhere((e) => e.id == task.id).done, true);
      await t.drag(
        find.byKey(const PageStorageKey('general-task')),
        const Offset(0, 700),
      );
      await t.pumpAndSettle();
      await tap(t, find.text('Offen'));
      expect(find.text('Kopien vorbereiten').hitTestable(), findsNothing);
      expect(find.byKey(const ValueKey('context-0-3')), findsNothing);
      expect(find.text('Notizen').hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-pages')), findsNothing);
      final organisation = t.widget<IndexedStack>(
        find.byKey(const ValueKey('organisation-pages')),
      );
      expect(organisation.children.length, 3);
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-2')));
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
      await tap(t, find.byKey(const ValueKey('bottom-0')));
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-3')));
      expect(find.text('Kopien vorbereiten').hitTestable(), findsNothing);
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-0')));
      expect(find.text('Orga').hitTestable(), findsOneWidget);
      expect(find.text('Kopien vorbereiten'), findsWidgets);
      expect(find.byKey(const ValueKey('context-2-1')), findsNothing);
      expect(find.byTooltip('Rücklauf anlegen').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'tasks integrate return lists with status, kind and search filters in organisation',
    (t) async {
      final c = await controller();
      await c.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Bus buchen',
          body: 'Bus buchen',
          isTask: true,
        ),
      );
      for (final state in ['open', 'closed', 'trash']) {
        await c.saveClassroom(
          ClassroomDocument.fromJson({
            ...classroomInitial(ClassroomKind.returnList, c),
            'id': 'return-$state',
            'title': 'Formular $state',
            'closed': state == 'closed',
            'deleted': state == 'trash',
          }),
        );
      }
      await host(t, c, scale: 1.8);
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-3')));
      expect(find.byKey(const ValueKey('context-2-1')), findsNothing);
      Future<void> type(String page, String value) async {
        await tap(t, find.byKey(ValueKey('general-type-filter-$page')));
        await tap(t, find.widgetWithText(CheckedPopupMenuItem<String>, value));
      }

      await tap(t, find.text('Offen').hitTestable());
      await type('task', 'Rückläufe');
      expect(find.text('Formular open'), findsOneWidget);
      expect(find.text('Formular closed'), findsNothing);
      expect(find.text('Formular trash'), findsNothing);
      expect(find.text('Bus buchen'), findsNothing);
      await tap(t, find.text('Formular open'));
      expect(find.byType(ReturnDetail), findsOneWidget);
      await tap(t, find.text('Abschließen'));
      expect(
        c.classroom.singleWhere((d) => d.id == 'return-open').flag('closed'),
        isTrue,
      );
      Navigator.of(t.element(find.byType(ReturnDetail))).pop();
      await t.pumpAndSettle();
      expect(find.text('Formular open'), findsNothing);
      await type('task', 'Aufgaben');
      expect(find.text('Bus buchen'), findsWidgets);
      expect(find.byType(ReturnListCard), findsNothing);
      await tap(t, find.text('Erledigt').hitTestable());
      await type('task', 'Rückläufe');
      expect(find.text('Formular open'), findsOneWidget);
      expect(find.text('Formular closed'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('context-2-0')));
      await type('all', 'Rückläufe');
      await t.drag(
        find.byKey(const PageStorageKey('general-all')),
        const Offset(0, 700),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('general-search-button-all')));
      await t.enterText(
        find.byKey(const ValueKey('general-search-all')),
        'closed',
      );
      await t.pumpAndSettle();
      expect(find.text('Formular closed'), findsOneWidget);
      expect(find.text('Formular open'), findsNothing);
      expect(find.text('Formular trash'), findsNothing);
      expect(c.entries, hasLength(1));
      expect(c.classroom, hasLength(3));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'general drafts retain pupil assignments and are resumable at large text',
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
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      await tap(t, find.byKey(const ValueKey('context-2-3')));
      await tap(t, find.byTooltip('Entwürfe · 2'));
      expect(find.text('Allgemeiner Entwurf'), findsOneWidget);
      expect(find.text('Schülerentwurf'), findsOneWidget);
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
