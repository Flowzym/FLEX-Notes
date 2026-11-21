import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'classroom_test.dart' show classroomMemory;

void main() {
  test(
    'real schema7 file migrates audit/outbox and timestamps without changing records',
    () async {
      final dir = Directory.systemTemp.createTempSync('flex-schema8-');
      final file = File('${dir.path}/notebook.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      old.execute(File('test/fixtures/schema_v7.sql').readAsStringSync());
      old.execute("INSERT INTO devices VALUES ('d')");
      old.execute("INSERT INTO pupils VALUES ('p','Altbestand',1,0,1)");
      old.execute(
        "INSERT INTO revisions VALUES ('r','pupil','p',0,1,NULL,'{}','2026-01-02T10:00:00Z','d')",
      );
      old.execute("INSERT INTO operations VALUES ('o','d',1,1,'r','{}')");
      old.execute("INSERT INTO outbox VALUES ('o')");
      old.execute('PRAGMA user_version=7');
      old.close();
      final repo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase(file),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      try {
        await repo.initialize();
        final pupil = (await repo.pupils()).single;
        expect(pupil.name, 'Altbestand');
        expect(pupil.createdAtUtc, '2026-01-02T10:00:00Z');
        expect(pupil.updatedAtUtc, pupil.createdAtUtc);
        expect(pupil.deleted, false);
        expect(
          (await repo.db
                  .customSelect('SELECT operation_id FROM outbox')
                  .getSingle())
              .read<String>('operation_id'),
          'o',
        );
        expect(
          await repo.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await repo.saveSchoolRecord(
          SchoolRecord.empty(
            SchoolKind.social,
            'p',
          ).patch({'body': 'Rücksichtsvoller Umgang'}),
        );
        expect(await repo.searchEntryKeys('rucksichts'), hasLength(1));
      } finally {
        await repo.close();
        dir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'full text changes atomically with records and checklist edits; deleted pupils disappear',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final p = await repo.savePupil(const Pupil(id: 'p', name: 'Testkind'));
      expect(p.createdAtUtc, isNotNull);
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.work,
          'p',
        ).patch({'body': 'Konzentriert und zuverlässig'}),
      );
      var e = await repo.saveEntry(
        OrgaEntry.empty(pupilId: 'p').copyWith(
          title: 'Unterlagen',
          items: [
            const CheckItem(id: 'i', text: 'Einverständniserklärung holen'),
          ],
        ),
      );
      expect(await repo.searchEntryKeys('zuverlassig', pupilId: 'p'), {
        'school:${r.id}',
      });
      expect(await repo.searchEntryKeys('Einverstandnis'), {'orga:${e.id}'});
      e = await repo.saveEntry(
        e.copyWith(
          items: [const CheckItem(id: 'i', text: 'Rückgabe bestätigen')],
        ),
      );
      expect(await repo.searchEntryKeys('Einverstandnis'), isEmpty);
      expect(await repo.searchEntryKeys('Ruckgabe'), {'orga:${e.id}'});
      final deleted = await repo.savePupil(
        p.copyWith(archived: true, deleted: true),
      );
      expect(deleted.deletedAtUtc, isNotNull);
      expect(await repo.searchEntryKeys('Ruckgabe', pupilId: 'p'), isEmpty);
      await repo.savePupil(deleted.copyWith(deleted: false, archived: false));
      expect(await repo.searchEntryKeys('Ruckgabe', pupilId: 'p'), {
        'orga:${e.id}',
      });
      expect((await repo.pupils()).single.createdAtUtc, p.createdAtUtc);
      expect((await repo.pupils()).single.deletedAtUtc, isNull);
    },
  );

  test(
    'schema7 backup is upgraded and unknown operation protocol rolls back',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute(File('test/fixtures/schema_v7.sql').readAsStringSync());
      raw.execute("INSERT INTO devices VALUES ('d')");
      raw.execute("INSERT INTO pupils VALUES ('p','Altbestand',1,0,1)");
      final tables = {
        for (final name in SqliteNotebook.backupTables)
          name: raw
              .select('SELECT * FROM $name')
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
      };
      raw.close();
      final backup = {
        'format': 'FLEX-Flutter-Rebuild-Backup',
        'version': 1,
        'schemaVersion': 7,
        'tables': tables,
      };
      await repo.restoreBackup(jsonEncode(backup));
      expect((await repo.pupils()).single.name, 'Altbestand');
      expect(
        (jsonDecode(await repo.exportBackup()) as Map)['schemaVersion'],
        8,
      );
      final target = classroomMemory();
      await target.initialize();
      addTearDown(target.close);
      tables['operations']!.add({'protocol_version': 2});
      await expectLater(
        target.restoreBackup(jsonEncode(backup)),
        throwsA(isA<DomainError>()),
      );
      expect(await target.pupils(), isEmpty);
    },
  );
}
