import 'package:flutter/material.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/ui/lesson_flow_page.dart';
import 'classroom_test.dart' show classroomMemory;
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'material_workspace_test.dart' show material;

void main() {
  testWidgets(
    'daily flow toggles pupil headings, keeps shared files available and remembers the choice',
    (t) async {
      final c = NotebookController(classroomMemory());
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await c.repository.close();
      });
      for (final p in [
        const Pupil(id: 'a', name: 'Anna'),
        const Pupil(id: 'b', name: 'Bert'),
      ]) {
        await c.savePupil(p);
      }
      final doc = await c.repository.saveClassroomDocument(
        material(
          'Leseblatt',
          fields: {
            'pupilIds': ['b', 'a'],
          },
        ),
      );
      final free = await c.repository.saveClassroomDocument(
        material('Klassenblatt'),
      );
      await c.saveClassroom(
        prepareMaterials(c.classroom, '2026-11-19', [doc.id, free.id]),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonFlowPage(
              controller: c,
              initialDate: '2026-11-19',
              initialTarget: '',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final group = find.widgetWithText(FilterChip, 'Nach Schüler');
      await t.scrollUntilVisible(
        group,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(group);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Anna · 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Bert · 1'), findsOneWidget);
      expect(find.text('Ohne Schülerzuordnung · 1'), findsOneWidget);
      expect(find.text('Leseblatt'), findsNWidgets(2));
      expect(
        (await c.repository.snapshot()).appearance.groupMaterialsByPupil,
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
  );
  test(
    'Shared, daily, archived and unassigned materials group by stable pupil IDs',
    () {
      const pupils = [
        Pupil(id: 'b', name: 'Ben'),
        Pupil(id: 'a', name: 'Alex'),
        Pupil(id: 'old', name: 'Alex', archived: true),
      ];
      final both = material(
        'Gemeinsam',
        fields: {
          'pupilIds': ['b', 'a'],
          'pupilDates': [
            {'pupilId': 'a', 'date': '2026-11-19'},
          ],
        },
      );
      final other = material('Klasse'),
          archive = material(
            'Alt',
            fields: {
              'pupilIds': ['old'],
            },
          );
      final docs = [both, other, archive];
      final groups = pupilFileGroups(docs, pupils, (m) => materialOwnerIds(m));
      expect(groups.map((g) => g.id), ['a', 'old', 'b', '']);
      expect(groups.last.name, 'Ohne Schülerzuordnung');
      expect(groups[0].files.single.id, groups[2].files.single.id);
      expect(materialOwnerIds(both, day: '2026-11-19'), {'a'});
      expect(materialOwnerIds(both, day: '2026-11-20'), {'a', 'b'});
      expect(Appearance.fromJson({}).groupMaterialsByPupil, isFalse);
      final appearance = const Appearance().patch({
        'groupMaterialsByPupil': true,
        'materialLayout': 'grid',
      });
      expect(
        Appearance.fromJson(appearance.toJson()).groupMaterialsByPupil,
        isTrue,
      );
      expect(appearance.materialLayout, MaterialLayout.grid);
    },
  );
}
