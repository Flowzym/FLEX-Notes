import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/school_year.dart';
import 'package:flex_notizbuch/services/pseudonymize.dart';
import 'classroom_test.dart' show classroomMemory, returns;
import 'material_workspace_test.dart' show material;

void main() {
  test(
    'school-year closeout retains pupils and open tasks, archive can be reopened',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'p', name: 'Marek'));
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.social,
          'p',
        ).patch({'observedOn': '2025-10-01', 'body': 'Hilft mit.'}),
      );
      final e = await repo.saveEntry(
        OrgaEntry.empty(
          pupilId: 'p',
        ).copyWith(title: 'Offen', isTask: true, dueDate: '2026-06-01'),
      );
      final year = SchoolYearArchive.preview(
        await repo.snapshot(),
        title: '2025/26',
        from: '2025-09-01',
        to: '2026-08-31',
        reviewOn: '2026-11-01',
      );
      expect(year.recordIds, {r.id});
      expect(year.orgaIds, isEmpty);
      await repo.archiveSchoolYear(year, await repo.exportBackup());
      expect((await repo.snapshot()).active().records, isEmpty);
      expect((await repo.schoolRecords()).single.id, r.id);
      expect((await repo.snapshot()).active().entries.single.id, e.id);
      expect((await repo.pupils()).single.archived, false);
      final restore = classroomMemory();
      await restore.initialize();
      addTearDown(restore.close);
      await restore.restoreBackup(await repo.exportBackup());
      expect((await restore.snapshot()).active().records, isEmpty);
      await restore.reopenSchoolYear(year.id);
      expect((await restore.snapshot()).active().records.single.id, r.id);
    },
  );
  test(
    'changed backup rejects closeout and scoped retention only deletes selected copies',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'p', name: 'Marek'));
      await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.work,
          'p',
        ).patch({'observedOn': '2025-10-01', 'body': 'Text'}),
      );
      final year = SchoolYearArchive.preview(
        await repo.snapshot(),
        title: '2025/26',
        from: '2025-09-01',
        to: '2026-08-31',
      );
      final old = await repo.exportBackup();
      await repo.saveEntry(OrgaEntry.empty().copyWith(title: 'Neue Notiz'));
      await expectLater(
        repo.archiveSchoolYear(year, old),
        throwsA(isA<DomainError>()),
      );
      await repo.db.customStatement(
        "INSERT INTO legacy_backups VALUES ('old','{}','2026-01-01T00:00:00Z')",
      );
      await repo.db.customStatement(
        "INSERT INTO legacy_backups VALUES ('keep','{}','2026-01-01T00:00:00Z')",
      );
      final stamp = await repo.exportBackup();
      await repo.purgeRetained(
        {'legacy:old'},
        stamp,
        now: DateTime.utc(2026, 11, 14),
      );
      expect(await repo.legacyCount(), 1);
      expect(await repo.entries(), hasLength(1));
      expect(await repo.schoolRecords(), hasLength(1));
    },
  );
  test(
    'year purge removes exclusive files, retains shared files and only queues unused bytes',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'p', name: 'Marek'));
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.social,
          'p',
        ).patch({'observedOn': '2025-10-01', 'body': 'Text'}),
      );
      final exclusive = await repo.saveClassroomDocument(
        material(
          'Exklusiv',
          fields: {
            'localKey': 'only_old',
            'links': [
              {'kind': 'school', 'id': r.id},
            ],
          },
        ),
      );
      final shared = await repo.saveClassroomDocument(
        material(
          'Gemeinsam',
          fields: {
            'localKey': 'shared',
            'links': [
              {'kind': 'school', 'id': r.id},
            ],
          },
        ),
      );
      await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.materialSet, 'Paket', {
          'materialIds': [shared.id],
        }),
      );
      final year = SchoolYearArchive.preview(
        await repo.snapshot(),
        title: '2025/26',
        from: '2025-09-01',
        to: '2026-08-31',
        reviewOn: '2026-11-01',
      );
      await repo.archiveSchoolYear(year, await repo.exportBackup());
      await repo.purgeRetained(
        {'year:${year.id}'},
        await repo.exportBackup(),
        now: DateTime.utc(2026, 11, 14),
      );
      expect(await repo.schoolRecords(), isEmpty);
      expect(
        (await repo.classroomDocuments()).any((d) => d.id == exclusive.id),
        false,
      );
      expect(
        (await repo.classroomDocuments()).any((d) => d.id == shared.id),
        true,
      );
      final removed = <String>[];
      await repo.removeUnreferencedFiles((key) async {
        removed.add(key);
      });
      expect(removed, ['only_old']);
      expect(
        await repo.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
  test(
    'emptying pupil trash preserves other pupils and removes dependent rows',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final p = await repo.savePupil(const Pupil(id: 'p', name: 'Marek'));
      await repo.savePupil(const Pupil(id: 'other', name: 'Andere Person'));
      await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.social, 'p').patch({'body': 'Text'}),
      );
      await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.social,
          'other',
        ).patch({'body': 'Bleibt'}),
      );
      await repo.saveEntry(
        OrgaEntry.empty(pupilId: 'p').copyWith(title: 'Aufgabe', isTask: true),
      );
      await repo.savePupil(p.copyWith(deleted: true, archived: true));
      await repo.maintainStorage(await repo.exportBackup(), emptyTrash: true);
      expect((await repo.pupils()).map((p) => p.id), ['other']);
      expect((await repo.schoolRecords()).single.body, 'Bleibt');
      expect(await repo.entries(), isEmpty);
      final backup = jsonDecode(await repo.exportBackup()) as Map;
      expect(
        jsonEncode(backup['tables']['revisions']),
        isNot(contains('Marek')),
      );
      expect(
        await repo.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
  test(
    'pseudonyms cover Unicode names without rewriting ordinary word substrings',
    () {
      final text = pseudonymizeReport(
        'Émil Müller hilft Émil. Müller spricht mit Hanna. Hanna Reiter und Hanna Weiss arbeiten zusammen. Sommer bleibt Sommer.',
        ['Émil Müller', 'Hanna Reiter', 'Hanna Weiss', 'Som'],
      );
      expect(text, isNot(contains('Émil')));
      expect(text, isNot(contains('Müller')));
      expect(text, isNot(contains('Hanna')));
      expect(text, contains('Person 1'));
      expect(text, contains('Sommer bleibt Sommer'));
      expect(
        pseudonymizeReport('Person 1 trifft Person', ['Person 1', 'Person']),
        isNot(contains('Person 2 1')),
      );
    },
  );
  test(
    'pupil purge rolls back when a draft still refers to the pupil; last return participant is removed cleanly',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final pupil = await repo.savePupil(const Pupil(id: 'p', name: 'Marek'));
      await repo.saveClassroomDocument(returns('p'));
      final draft = await repo.saveSchoolDraft(
        SchoolDraft(
          id: 'draft',
          record: SchoolRecord.empty(
            SchoolKind.work,
            'p',
          ).patch({'body': 'Noch offen'}),
          updatedAtUtc: utcNow(),
        ),
      );
      await repo.savePupil(pupil.copyWith(deleted: true, archived: true));
      final backup = await repo.exportBackup();
      await expectLater(
        repo.maintainStorage(backup, emptyTrash: true),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.pupils()).single.id, 'p');
      expect(
        (await repo.classroomDocuments()).single.kind,
        ClassroomKind.returnList,
      );
      await repo.discardSchoolDraft(draft.id);
      await repo.maintainStorage(await repo.exportBackup(), emptyTrash: true);
      expect(await repo.pupils(), isEmpty);
      expect(await repo.classroomDocuments(), isEmpty);
      expect(
        await repo.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
  test(
    'broken archive references reject restore without changing local entries',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'p', name: 'Marek'));
      await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.social,
          'p',
        ).patch({'body': 'Bleibt', 'observedOn': '2025-11-01'}),
      );
      final year = SchoolYearArchive.preview(
        await repo.snapshot(),
        title: '2025/26',
        from: '2025-09-01',
        to: '2026-08-31',
      );
      await repo.archiveSchoolYear(year, await repo.exportBackup());
      final broken = jsonDecode(await repo.exportBackup()) as Map;
      final prefs = broken['tables']['preferences'] as List;
      final row = prefs.cast<Map>().singleWhere(
        (r) => r['key'] == 'school-year:${year.id}',
      );
      row['payload'] = jsonEncode({
        ...year.toJson(),
        'recordIds': ['missing'],
      });
      await expectLater(
        repo.restoreBackup(jsonEncode(broken)),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.schoolRecords()).single.body, 'Bleibt');
      expect((await repo.schoolYears()).single.recordIds, year.recordIds);
    },
  );
}
