import 'dart:convert';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;
import 'document_attachments_test.dart' show taskRecord;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  setUp(() async {
    repo = classroomMemory();
    await repo.initialize();
    for (final p in ['p', 'q']) {
      await repo.savePupil(Pupil(id: p, name: p));
    }
  });
  tearDown(() => repo.close());
  Future<SchoolDraft> owner({SchoolRecord? record}) => repo.saveSchoolDraft(
    SchoolDraft(
      id: 'draft',
      record: record ?? taskRecord('p'),
      recipients: ['p', 'q'],
      updatedAtUtc: utcNow(),
    ),
  );
  Future<void> attachment(DocumentLink link) async {
    await repo.saveClassroomDocument(
      material(
        'Datei',
        fields: {
          'links': [link.toJson()],
        },
      ),
    );
    await repo.saveDialogDraft(
      DialogDraft(
        id: 'scan',
        type: 'scan',
        ownerId: 'scan',
        updatedAtUtc: utcNow(),
        data: ScanContext(links: [link]).initial(),
      ),
    );
  }

  Future<List<DocumentLink>> links() async => (await repo.classroomDocuments())
      .single
      .rows('links')
      .map(DocumentLink.fromJson)
      .toList();
  Future<List<DocumentLink>> scanLinks() async =>
      ((await repo.dialogDrafts())
                  .singleWhere((d) => d.type == 'scan')
                  .data['links']
              as List)
          .map((j) => DocumentLink.fromJson(Json.from(j as Map)))
          .toList();

  test(
    'blank drafts hold files; invalid publish is atomic; discard detaches without deleting',
    () async {
      final d = await owner(record: SchoolRecord.empty(SchoolKind.social, 'p'));
      await attachment(DocumentLink('schoolDraft', d.id));
      expect(await repo.schoolRecords(), isEmpty);
      await expectLater(
        repo.saveSchoolRecord(
          d.record,
          draftId: d.id,
          draftRevision: d.editRevision,
        ),
        throwsA(isA<DomainError>()),
      );
      expect((await links()).single.kind, 'schoolDraft');
      await repo.discardSchoolDraft(d.id, expectedRevision: d.editRevision);
      expect(await links(), isEmpty);
      expect(await scanLinks(), isEmpty);
      expect(await repo.classroomDocuments(), hasLength(1));
    },
  );
  test('group publishing maps subtask IDs and only final recipients', () async {
    final d = await owner();
    await attachment(DocumentLink('schoolDraft', d.id, taskId: 'child'));
    final records = await repo.saveSchoolGroup(
      d.record,
      ['q'],
      d.id,
      draftRevision: d.editRevision,
    );
    expect(records, hasLength(1));
    expect(records.single.pupilId, 'q');
    expect((await links()).single.taskId, records.single.tasks[1].id);
    expect((await links()).single.id, records.single.id);
    expect(
      (await scanLinks()).single.identity,
      (await links()).single.identity,
    );
    expect((await repo.classroomDocuments()).single.strings('pupilIds'), ['q']);
    expect(await repo.schoolDrafts(), isEmpty);
  });
  test('removed draft task retains attachments at entry level', () async {
    final d = await owner();
    await attachment(DocumentLink('schoolDraft', d.id, taskId: 'child'));
    await repo.saveSchoolDraft(
      SchoolDraft(
        id: d.id,
        record: d.record.patch({
          'tasks': [d.record.tasks.first.toJson()],
        }),
        editRevision: d.editRevision,
        updatedAtUtc: utcNow(),
      ),
    );
    expect((await links()).single.taskId, '');
    expect((await scanLinks()).single.taskId, '');
  });
  test('stale draft cannot publish or detach files', () async {
    final d = await owner();
    await attachment(DocumentLink('schoolDraft', d.id));
    await repo.saveSchoolDraft(
      SchoolDraft(
        id: d.id,
        record: d.record.patch({'subject': 'Neu'}),
        editRevision: d.editRevision,
        updatedAtUtc: utcNow(),
      ),
    );
    await expectLater(
      repo.discardSchoolDraft(d.id, expectedRevision: d.editRevision),
      throwsA(isA<StaleRevision>()),
    );
    await expectLater(
      repo.saveSchoolRecord(
        d.record,
        draftId: d.id,
        draftRevision: d.editRevision,
      ),
      throwsA(isA<StaleRevision>()),
    );
    expect((await links()).single.kind, 'schoolDraft');
    expect(await repo.schoolRecords(), isEmpty);
  });
  test(
    'undo group restores draft attachment access and supports republishing',
    () async {
      final d = await owner();
      await attachment(DocumentLink('schoolDraft', d.id, taskId: 'child'));
      await repo.saveSchoolGroup(
        d.record,
        ['p', 'q'],
        d.id,
        draftRevision: d.editRevision,
      );
      final group = (await repo.schoolGroups()).single;
      await repo.undoSchoolGroup(group['id'] as String);
      final recovered = (await repo.schoolDrafts()).single;
      expect(
        (await links()).where((l) => l.kind == 'schoolDraft').single.taskId,
        'child',
      );
      expect(
        (await links()).where((l) => l.kind == 'schoolDraft').single.id,
        recovered.id,
      );
      await repo.saveSchoolGroup(
        recovered.record,
        recovered.recipients,
        recovered.id,
        draftRevision: recovered.editRevision,
      );
      expect((await links()).any((l) => l.kind.endsWith('Draft')), false);
    },
  );

  test('orga draft publishes both saved file and unfinished scan', () async {
    final d = await repo.saveDraft(
      EditDraft(
        id: 'orga',
        entry: OrgaEntry.empty(pupilId: 'p'),
        updatedAtUtc: utcNow(),
      ),
    );
    await attachment(DocumentLink('orgaDraft', d.id));
    expect(await repo.entries(), isEmpty);
    final saved = await repo.saveEntry(
      d.entry.copyWith(title: 'Notiz'),
      draftId: d.id,
      draftRevision: d.editRevision,
    );
    expect(
      (await links()).single.identity,
      DocumentLink('orga', saved.id).identity,
    );
    expect(
      (await scanLinks()).single.identity,
      DocumentLink('orga', saved.id).identity,
    );
    expect((await repo.classroomDocuments()).single.strings('pupilIds'), ['p']);
  });
  test('bulk draft promotes both pupils and matching subtasks', () async {
    final d = await repo.saveDialogDraft(
      DialogDraft(
        id: 'bulk',
        type: 'bulk',
        ownerId: 'group',
        updatedAtUtc: utcNow(),
        data: {
          'kind': 'homework',
          'recipients': ['p', 'q'],
          'context': '',
          'subject': 'Mathe',
          'body': '',
          'individual': <String, dynamic>{},
          'observedOn': '2026-11-11',
          'tasks': taskRecord('p').tasks.map((t) => t.toJson()).toList(),
        },
      ),
    );
    await attachment(DocumentLink('bulkDraft', d.id, taskId: 'child'));
    await repo.saveBulkDialog(d);
    final records = await repo.schoolRecords();
    expect(records, hasLength(2));
    for (final r in records) {
      expect(
        (await links()).singleWhere((l) => l.id == r.id).taskId,
        r.tasks[1].id,
      );
    }
    expect(await scanLinks(), hasLength(2));
  });
  test(
    'backup round trip and divergent draft merge keep exact owners; repeat is idempotent',
    () async {
      final d = await owner();
      await attachment(DocumentLink('schoolDraft', d.id, taskId: 'child'));
      final source = classroomMemory();
      await source.initialize();
      addTearDown(source.close);
      await source.restoreBackup(await repo.exportBackup());
      await source.saveSchoolDraft(
        SchoolDraft(
          id: d.id,
          record: d.record.patch({'subject': 'Quelle'}),
          editRevision: d.editRevision,
          updatedAtUtc: utcNow(),
        ),
      );
      final backup = await source.exportBackup();
      await repo.applyBackupMerge(await repo.prepareBackupMerge(backup), {});
      final drafts = await repo.schoolDrafts();
      expect(drafts, hasLength(2));
      final incoming = drafts.singleWhere((d) => d.record.subject == 'Quelle');
      expect((await links()).map((l) => l.id).toSet(), {d.id, incoming.id});
      expect(
        (await repo.dialogDrafts())
            .where((d) => d.type == 'scan')
            .map((d) => (d.data['links'] as List).single['id'])
            .toSet(),
        {'draft', incoming.id},
      );
      final before = jsonDecode(await repo.exportBackup()) as Map;
      await repo.applyBackupMerge(await repo.prepareBackupMerge(backup), {});
      expect(await repo.schoolDrafts(), hasLength(2));
      expect(
        (await repo.dialogDrafts()).where((d) => d.type == 'scan'),
        hasLength(2),
      );
      expect((await links()).map((l) => l.id).toSet(), {d.id, incoming.id});
      final restored = classroomMemory();
      await restored.initialize();
      addTearDown(restored.close);
      await restored.restoreBackup(jsonEncode(before));
      expect(await restored.schoolDrafts(), hasLength(2));
    },
  );
}
