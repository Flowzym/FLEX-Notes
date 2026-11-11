import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;
import 'document_attachments_test.dart' show taskRecord;

void main() {
  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'work assignment links day material and a planning task at scale $scale',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final c = NotebookController(classroomMemory());
        await c.initialize();
        await c.savePupil(const Pupil(id: 'p', name: 'Alex'));
        addTearDown(() async {
          c.dispose();
          await c.repository.close();
        });
        final file = await c.repository.saveClassroomDocument(
          material('Tagesblatt'),
        );
        final plan = await c.repository.saveClassroomDocument(
          ClassroomDocument.create(ClassroomKind.plan, 'Tagesplan', {
            'date': '2026-11-11',
            'note': 'Seite 12 bearbeiten\nWörter üben',
            'materialIds': [file.id],
          }),
        );
        await c.saveClassroom(
          prepareMaterials(
            await c.repository.classroomDocuments(),
            '2026-11-11',
            [file.id],
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => SchoolEditor(
                      controller: c,
                      record: SchoolRecord.empty(SchoolKind.work, 'p').patch({
                        'observedOn': '2026-11-11',
                        'body': 'Arbeitet am Tagesplan',
                      }),
                    ),
                  ),
                  child: const Text('Öffnen'),
                ),
              ),
            ),
          ),
        );
        await tap(t, find.text('Öffnen'));
        await tap(t, find.byKey(const ValueKey('assignment-sources')));
        await tap(t, find.widgetWithText(CheckboxListTile, 'Tagesblatt'));
        final card = find.ancestor(
          of: find.text('Tagesplan'),
          matching: find.byType(Card),
        );
        await tap(
          t,
          find.descendant(of: card, matching: find.text('Aufgaben auswählen')),
        );
        await tap(t, find.widgetWithText(CheckboxListTile, 'Wörter üben'));
        await tap(t, find.text('Übernehmen'));
        await tap(t, find.byKey(const ValueKey('apply-assignment-sources')));
        expect(find.text('Wörter üben'), findsOneWidget);
        await tap(t, find.byKey(const ValueKey('save-school-record')));
        final saved = (await c.repository.schoolRecords()).single;
        expect(saved.assignmentSources.map((s) => s.documentId).toSet(), {
          file.id,
          plan.id,
        });
        expect(
          saved.assignmentSources
              .singleWhere((s) => s.documentId == plan.id)
              .text,
          'Wörter üben',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'X proposes reassignment and confirmation creates one new open subtask entry',
    (t) async {
      final c = NotebookController(classroomMemory());
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await c.repository.close();
      });
      await c.savePupil(const Pupil(id: 'p', name: 'Alex'));
      final r = await c.repository.saveSchoolRecord(taskRecord('p'));
      await c.reload();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: c,
                builder: (_, _) => SchoolRecordCard(
                  controller: c,
                  record: c.records.firstWhere((v) => v.id == r.id),
                  standalone: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tap(t, find.byKey(const ValueKey('status-child-missing')));
      expect((await c.repository.schoolRecords()).length, 1);
      await tap(t, find.byKey(const ValueKey('reassign-homework')));
      final records = await c.repository.schoolRecords();
      expect(records.length, 2);
      final next = records.singleWhere((v) => v.id != r.id);
      expect(next.tasks.length, 1);
      expect(next.tasks.single.parentId, isNull);
      expect(next.taskState(next.tasks.single), TaskState.open);
      expect(find.text('Erneut aufgeben?'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
