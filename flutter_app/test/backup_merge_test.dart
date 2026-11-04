import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/domain/backup_merge.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook local, source;
  SqliteNotebook memory() => SqliteNotebook(
    NotebookDatabase(
      NativeDatabase.memory(),
      File('assets/schema.sql').readAsStringSync(),
    ),
  );
  Future<String> stamp(SqliteNotebook repo) async =>
      canonical((jsonDecode(await repo.exportBackup()) as Map)['tables']);
  setUp(() async {
    local = memory();
    source = memory();
    await local.initialize();
    await source.initialize();
  });
  tearDown(() async {
    await local.close();
    await source.close();
  });
  test(
    'preview is read-only; adds records, preserves original history, deduplicates repeat import',
    () async {
      await local.savePupil(const Pupil(id: 'local', name: 'Lokal'));
      final pupil = await source.savePupil(
        const Pupil(id: 'source', name: 'Quelle'),
      );
      final goal = await source.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.goal, pupil.id).patch({
          'title': 'Ziel',
          'criterion': 'Sachlich',
          'nextReviewDate': '2026-12-01',
        }),
      );
      final observation = await source.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.social, pupil.id).patch({
          'body': 'Beobachtung',
          'goalId': goal.id,
          'neutral': ['Hört zu'],
          'context': 'Gemeinsam',
          'participantIds': [pupil.id],
        }),
      );
      final entry = await source.saveEntry(
        OrgaEntry.empty(pupilId: pupil.id).copyWith(
          title: 'Termin',
          appointmentDate: '2026-11-12',
          appointmentTime: '10:30',
          items: [const CheckItem(id: 'item', text: 'A')],
        ),
      );
      await source.saveDraft(
        EditDraft(
          id: 'draft',
          entry: entry.copyWith(body: 'Entwurf'),
          updatedAtUtc: utcNow(),
        ),
      );
      final text = await source.exportBackup(), before = await stamp(local);
      final plan = await local.prepareBackupMerge(text);
      expect(await stamp(local), before);
      expect(plan.newCount, 4);
      await local.applyBackupMerge(plan, {});
      expect((await local.pupils()).length, 2);
      expect((await local.schoolRecords()).length, 2);
      expect((await local.entries()).single.appointmentTime, '10:30');
      expect(
        (await local.schoolRecords())
            .singleWhere((r) => r.id == observation.id)
            .goalId,
        goal.id,
      );
      expect((await local.history(entry.id)).length, 1);
      expect((await local.drafts()).length, 1);
      expect(
        await local.importArchive(
          (await local.importArchives()).single['id'] as String,
        ),
        text,
      );
      final repeat = await local.prepareBackupMerge(text);
      expect(repeat.newCount, 0);
      expect(repeat.conflicts, 0);
      await local.applyBackupMerge(repeat, {});
      expect((await local.drafts()).length, 1);
      expect((await local.importArchives()).length, 1);
      final fresh = memory();
      await fresh.initialize();
      await fresh.restoreBackup(await local.exportBackup());
      expect((await fresh.schoolRecords()).length, 2);
      await fresh.close();
    },
  );
  test(
    'field selections merge appointment date while preserving local body and audit',
    () async {
      final entry = await local.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Termin',
          body: 'Original',
          appointmentDate: '2026-11-10',
          appointmentTime: '09:00',
        ),
      );
      await source.restoreBackup(await local.exportBackup());
      await local.saveEntry(entry.copyWith(body: 'Lokale Notiz'));
      await source.saveEntry(
        entry.copyWith(
          body: 'Andere Notiz',
          appointmentDate: '2026-11-11',
          appointmentTime: '15:30',
        ),
      );
      final plan = await local.prepareBackupMerge(await source.exportBackup());
      final item = plan.items.singleWhere((i) => i.kind == 'orga');
      expect(
        item.differences,
        containsAll(['body', 'appointmentDate', 'appointmentTime']),
      );
      await local.applyBackupMerge(plan, {
        item.key: {'appointmentDate', 'appointmentTime'},
      });
      final result = (await local.entries()).single;
      expect(result.body, 'Lokale Notiz');
      expect(result.appointmentTime, '15:30');
      expect(result.revision, 3);
      expect((await local.history(entry.id)).length, 3);
    },
  );
  test('incompatible task fields roll back every change atomically', () async {
    final entry = await local.saveEntry(
      OrgaEntry.empty().copyWith(title: 'Notiz'),
    );
    await source.restoreBackup(await local.exportBackup());
    await source.saveEntry(entry.copyWith(isTask: true, dueDate: '2026-11-10'));
    await source.savePupil(const Pupil(id: 'new', name: 'Neu'));
    final plan = await local.prepareBackupMerge(await source.exportBackup()),
        before = await stamp(local);
    await expectLater(
      local.applyBackupMerge(plan, {
        'orga:${entry.id}': {'dueDate'},
      }),
      throwsA(isA<DomainError>()),
    );
    expect(await stamp(local), before);
  });
  test(
    'stale preview and malformed source cannot change local records',
    () async {
      await local.savePupil(const Pupil(id: 'p', name: 'Kind'));
      await source.savePupil(const Pupil(id: 's', name: 'Anderes'));
      final plan = await local.prepareBackupMerge(await source.exportBackup());
      await local.saveEntry(OrgaEntry.empty().copyWith(title: 'Inzwischen'));
      final before = await stamp(local);
      await expectLater(
        local.applyBackupMerge(plan, {}),
        throwsA(isA<DomainError>()),
      );
      expect(await stamp(local), before);
      final invalid = jsonDecode(await source.exportBackup()) as Map;
      invalid['tables']['pupils'][0]['color'] = -1;
      await expectLater(
        local.prepareBackupMerge(jsonEncode(invalid)),
        throwsA(isA<DomainError>()),
      );
      expect(await stamp(local), before);
    },
  );
  test(
    'same names require explicit mapping; owner links are rewritten',
    () async {
      await local.savePupil(const Pupil(id: 'local', name: 'Gleich'));
      await source.savePupil(const Pupil(id: 'source', name: 'Gleich'));
      await source.saveEntry(
        OrgaEntry.empty(pupilId: 'source').copyWith(title: 'Importiert'),
      );
      final text = await source.exportBackup(),
          first = await local.prepareBackupMerge(text);
      expect(first.sameNames.keys, ['source']);
      await expectLater(
        local.applyBackupMerge(first, {}),
        throwsA(isA<DomainError>()),
      );
      final plan = await local.prepareBackupMerge(
        text,
        pupilLinks: {'source': 'local'},
      );
      await local.applyBackupMerge(plan, {});
      expect((await local.pupils()).length, 1);
      expect((await local.entries()).single.pupilId, 'local');
    },
  );
  test(
    'divergent drafts survive twice without multiplying on repeat imports',
    () async {
      final entry = await local.saveEntry(
        OrgaEntry.empty().copyWith(title: 'Notiz'),
      );
      await local.saveDraft(
        EditDraft(
          id: 'draft',
          entry: entry.copyWith(body: 'Lokal'),
          updatedAtUtc: utcNow(),
        ),
      );
      await source.restoreBackup(await local.exportBackup());
      final draft = (await source.drafts()).single;
      await source.saveDraft(
        EditDraft(
          id: draft.id,
          entry: entry.copyWith(body: 'Quelle'),
          editRevision: draft.editRevision,
          updatedAtUtc: utcNow(),
        ),
      );
      final text = await source.exportBackup();
      await local.applyBackupMerge(await local.prepareBackupMerge(text), {});
      expect((await local.drafts()).length, 2);
      await local.applyBackupMerge(await local.prepareBackupMerge(text), {});
      expect((await local.drafts()).length, 2);
    },
  );
  test(
    'mapped pupil and shared context drafts retain valid ownership on repeat import',
    () async {
      await local.savePupil(const Pupil(id: 'local', name: 'Gleich'));
      final pupil = await source.savePupil(
        const Pupil(id: 'source', name: 'Gleich'),
      );
      final record = await source.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.social, pupil.id).patch({
          'body': 'Quelle',
          'context': 'Gemeinsam',
          'participantIds': [pupil.id],
        }),
      );
      await source.saveDialogDraft(
        DialogDraft(
          id: 'pupil-draft',
          type: 'pupil',
          ownerId: pupil.id,
          data: pupil.copyWith(name: 'Bearbeitet').toJson(),
          updatedAtUtc: utcNow(),
        ),
      );
      await source.saveSchoolDraft(
        SchoolDraft(
          id: 'school-draft',
          record: record.patch({'body': 'Entwurf'}),
          updatedAtUtc: utcNow(),
          recipients: [pupil.id],
        ),
      );
      final original = await source.exportBackup();
      for (var n = 0; n < 2; n++) {
        final plan = await local.prepareBackupMerge(
          original,
          pupilLinks: {'source': 'local'},
        );
        await local.applyBackupMerge(plan, {});
      }
      final pupilDraft = (await local.dialogDrafts()).single;
      expect(pupilDraft.ownerId, 'local');
      expect(pupilDraft.data['id'], 'local');
      final schoolDraft = (await local.schoolDrafts()).single;
      expect(schoolDraft.record.pupilId, 'local');
      expect(schoolDraft.recipients, ['local']);
      expect((await local.schoolRecords()).single.participantIds, ['local']);
    },
  );
  test(
    'excluding catalogs preserves full original archive and local choices',
    () async {
      await local.savePupil(const Pupil(id: 'local', name: 'Lokal'));
      await source.saveObservationOptions('social-neutral', ['Neue Auswahl']);
      final original = await source.exportBackup();
      final plan = await local.prepareBackupMerge(original, catalogs: false);
      expect(plan.items.where((i) => i.id.startsWith('observation-')), isEmpty);
      await local.applyBackupMerge(plan, {});
      expect(
        (await local.observationCatalog('social-neutral')).options,
        isNot(contains('Neue Auswahl')),
      );
      expect(
        await local.importArchive(
          (await local.importArchives()).single['id'] as String,
        ),
        original,
      );
    },
  );
}
