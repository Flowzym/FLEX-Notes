import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/domain/entry_template.dart';
import 'package:flex_notizbuch/domain/observation_catalog.dart';
import 'classroom_test.dart' show classroomMemory;

void main() {
  test(
    'homework templates remove identity, feedback and dates; applying creates fresh task trees',
    () async {
      final record = SchoolRecord.empty(SchoolKind.homework, 'pupil-secret')
          .patch({
            'title': 'Übung',
            'dueDate': '2026-11-20',
            'tasks': [
              const HomeworkTask(
                id: 'old',
                text: 'Seite 5',
                initialState: TaskState.complete,
              ).toJson(),
              const HomeworkTask(
                id: 'child',
                text: 'Nr. 2',
                parentId: 'old',
              ).toJson(),
            ],
            'otherParticipants': 'Private Person',
          });
      final template = EntryTemplate.school(record, 'Buchaufgabe');
      final serialized = jsonEncode(template.toJson());
      for (final private in [
        'pupil-secret',
        'Private Person',
        '2026-11-20',
        'complete',
        '"old"',
      ]) {
        expect(serialized, isNot(contains(private)));
      }
      final target = SchoolRecord.empty(
        SchoolKind.homework,
        'different',
      ).patch({'dueDate': '2026-12-01', 'body': 'Bestehend'});
      final applied = template.applySchool(target);
      expect(applied.pupilId, 'different');
      expect(applied.dueDate, '2026-12-01');
      expect(applied.body, 'Bestehend');
      expect(applied.tasks.last.parentId, applied.tasks.first.id);
      expect(applied.tasks.first.initialState, TaskState.open);
      expect(
        template.applySchool(target).tasks.first.id,
        isNot(applied.tasks.first.id),
      );
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.saveEntryTemplate(template);
      final restored = classroomMemory();
      await restored.initialize();
      addTearDown(restored.close);
      await restored.restoreBackup(await repo.exportBackup());
      expect((await restored.entryTemplates()).single.name, 'Buchaufgabe');
    },
  );
  test(
    'orga template appends unchecked items without changing appointment time or owner',
    () {
      final source = OrgaEntry.empty(pupilId: 'old').copyWith(
        body: 'Vorbereitung',
        items: [
          const CheckItem(id: 'old-item', text: 'Formular', checked: true),
        ],
        appointmentDate: '2026-11-20',
        appointmentTime: '10:00',
      );
      final target = OrgaEntry.empty(pupilId: 'new').copyWith(
        body: 'Vorhanden',
        appointmentDate: '2026-12-01',
        appointmentTime: '11:00',
        appointmentEndTime: '12:00',
      );
      final applied = EntryTemplate.orga(source, 'Gespräch').applyOrga(target);
      expect(applied.body, 'Vorhanden\nVorbereitung');
      expect(applied.pupilId, 'new');
      expect(applied.appointmentTime, '11:00');
      expect(applied.appointmentEndTime, '12:00');
      expect(applied.items.single.checked, false);
    },
  );
  test(
    'catalog export has only whitelisted lists; merge and replace are transactional',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'private', name: 'Vertraulich'));
      await repo.saveObservationOptions('work-neutral', ['Test A']);
      final bundle = await repo.exportCatalogs();
      expect(bundle.encode(), isNot(contains('Vertraulich')));
      final incoming = CatalogBundle({
        'work-neutral': ObservationCatalog(
          options: ['Test B'],
          favorites: ['Test B'],
        ),
      });
      await repo.importCatalogs(incoming, replace: false);
      expect((await repo.observationCatalog('work-neutral')).options, [
        'Test A',
        'Test B',
      ]);
      await repo.importCatalogs(incoming, replace: true);
      expect((await repo.observationCatalog('work-neutral')).options, [
        'Test B',
      ]);
      expect((await repo.observationCatalog('work-neutral')).favorites, [
        'Test B',
      ]);
      expect(
        () => CatalogBundle.decode(
          jsonEncode({
            'format': 'FLEX-Catalogs',
            'version': 1,
            'catalogs': {},
            'pupils': [],
          }),
        ),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => EntryTemplate.fromJson({
          'version': 1,
          'id': 'id',
          'name': 'Test',
          'kind': 'social',
          'fields': {'pupilId': 'secret'},
        }),
        throwsA(isA<DomainError>()),
      );
      final tooMany = CatalogBundle({
        'work-neutral': ObservationCatalog(
          options: List.generate(201, (i) => '$i'),
        ),
      });
      await expectLater(
        repo.importCatalogs(tooMany, replace: true),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.observationCatalog('work-neutral')).options, [
        'Test B',
      ]);
    },
  );
}
