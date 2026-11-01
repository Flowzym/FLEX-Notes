import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';

SqliteNotebook memoryRepo() => SqliteNotebook(
  NotebookDatabase(
    NativeDatabase.memory(),
    File('assets/schema.sql').readAsStringSync(),
  ),
);
SchoolRecord homework(String pupil) =>
    SchoolRecord.empty(SchoolKind.homework, pupil).patch({
      'tasks': [
        const HomeworkTask(id: 'task-a', text: 'Synthetische Aufgabe').toJson(),
      ],
    });
SchoolFeedback feedback(
  String id, {
  TaskState? state,
  String note = '',
  String day = '2026-11-01',
  String? delivery,
}) => SchoolFeedback(
  id: id,
  observedOn: day,
  createdAtUtc: '2026-11-01T12:00:00Z',
  taskId: state != null ? 'task-a' : null,
  state: state,
  note: note,
  delivery: delivery,
);

void main() {
  late SqliteNotebook repo;
  late Pupil pupil;
  setUp(() async {
    repo = memoryRepo();
    await repo.initialize();
    pupil = await repo.savePupil(
      Pupil(id: 'synthetic-pupil', name: 'Testkind Alpha'),
    );
  });
  tearDown(() async {
    await repo.close();
  });
  test('fresh schema is version 7 with 19 domain tables', () async {
    expect(
      (await repo.db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      7,
    );
    final tables = await repo.db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(tables.length, 19);
    expect(await repo.schoolRecords(), isEmpty);
  });
  test(
    'homework status changes are independent from comments and delivery',
    () {
      final base = homework(pupil.id);
      final full = feedback('a', state: TaskState.complete);
      final note = feedback('b', note: 'Nur Kommentar', delivery: 'absent');
      final record = base.patch({
        'feedback': [full.toJson(), note.toJson()],
      });
      expect(record.taskState(record.tasks.single), TaskState.complete);
      expect(record.delivery, 'absent');
      expect(base.taskState(base.tasks.single), TaskState.open);
    },
  );
  test(
    'chronological feedback ignores insertion order and reverts on deletion',
    () {
      final late = feedback(
        'later',
        state: TaskState.complete,
        day: '2026-11-03',
      );
      final early = feedback(
        'early',
        state: TaskState.partial,
        day: '2026-11-02',
      );
      var record = homework(pupil.id).patch({
        'feedback': [late.toJson(), early.toJson()],
      });
      expect(record.taskState(record.tasks.single), TaskState.complete);
      record = record.patch({
        'feedback': [late.copyWith(deleted: true).toJson(), early.toJson()],
      });
      expect(record.taskState(record.tasks.single), TaskState.partial);
    },
  );
  test('invalid tasks, times, feedback and goal reviews are rejected', () {
    final record = homework(pupil.id);
    for (final changes in <Json>[
      {'observedOn': '2026-02-30'},
      {'observedTime': '25:00'},
      {
        'tasks': [
          ...record.tasks.map((t) => t.toJson()),
          ...record.tasks.map((t) => t.toJson()),
        ],
      },
      {
        'tasks': [
          const HomeworkTask(id: 'x', text: 'X', parentId: 'missing').toJson(),
        ],
      },
      {
        'reviews': [
          const GoalReview(
            id: 'review',
            decision: 'continue',
            observedOn: '2026-11-01',
          ).toJson(),
        ],
      },
    ]) {
      expect(
        () => record.patch(changes).validate(),
        throwsA(isA<DomainError>()),
      );
    }
    expect(
      () => record.patch({'observedTime': '00:00'}).validate(),
      returnsNormally,
    );
  });
  test('all four domains persist and journal atomically', () async {
    for (final kind in SchoolKind.values) {
      var record = SchoolRecord.empty(
        kind,
        pupil.id,
      ).patch({'title': 'Testziel', 'body': 'Synthetische Beobachtung'});
      if (kind == SchoolKind.homework) record = homework(pupil.id);
      final saved = await repo.saveSchoolRecord(record);
      expect(saved.revision, 1);
      expect(await repo.history(saved.id), hasLength(1));
    }
    expect(await repo.schoolRecords(), hasLength(4));
    final backup = jsonDecode(await repo.exportBackup());
    expect(backup['tables']['outbox'], hasLength(5));
  });
  test('optimistic revision prevents lost update and keeps draft', () async {
    final saved = await repo.saveSchoolRecord(homework(pupil.id));
    await repo.saveSchoolDraft(
      SchoolDraft(id: 'draft', record: saved, updatedAtUtc: utcNow()),
    );
    await repo.saveSchoolRecord(saved.patch({'subject': 'Mathematik'}));
    await expectLater(
      repo.saveSchoolRecord(
        saved.patch({'subject': 'Sprache'}),
        draftId: 'draft',
      ),
      throwsA(isA<StaleRevision>()),
    );
    expect(await repo.schoolDrafts(), hasLength(1));
    expect((await repo.schoolRecords()).single.subject, 'Mathematik');
  });
  test('draft editors cannot overwrite each other', () async {
    final initial = SchoolDraft(
      id: 'draft',
      record: homework(pupil.id),
      updatedAtUtc: utcNow(),
    );
    final saved = await repo.saveSchoolDraft(initial);
    expect(saved.editRevision, 1);
    await expectLater(
      repo.saveSchoolDraft(initial),
      throwsA(isA<StaleRevision>()),
    );
    final next = await repo.saveSchoolDraft(saved);
    expect(next.editRevision, 2);
  });
  test(
    'group saves have separate task ids and idempotent request ids',
    () async {
      final other = await repo.savePupil(
        Pupil(id: 'synthetic-beta', name: 'Testkind Beta'),
      );
      final records = await repo.saveSchoolGroup(homework(pupil.id), [
        pupil.id,
        other.id,
      ], 'request');
      expect(records, hasLength(2));
      expect(records[0].tasks.single.id, isNot(records[1].tasks.single.id));
      await repo.saveSchoolGroup(homework(pupil.id), [
        pupil.id,
        other.id,
      ], 'request');
      expect(await repo.schoolRecords(), hasLength(2));
    },
  );
  test('group transaction rolls back when any recipient is invalid', () async {
    await expectLater(
      repo.saveSchoolGroup(homework(pupil.id), [
        pupil.id,
        'missing',
      ], 'request'),
      throwsA(isA<DomainError>()),
    );
    expect(await repo.schoolRecords(), isEmpty);
    expect(await repo.schoolGroups(), isEmpty);
    final backup = jsonDecode(await repo.exportBackup());
    expect(backup['tables']['revisions'], hasLength(1));
  });
  test('group undo restores draft and is idempotent', () async {
    await repo.saveSchoolGroup(homework(pupil.id), [pupil.id], 'request');
    await repo.undoSchoolGroup('request');
    await repo.undoSchoolGroup('request');
    expect((await repo.schoolRecords()).single.deleted, isTrue);
    expect(await repo.schoolDrafts(), hasLength(1));
    await expectLater(
      repo.saveSchoolGroup(homework(pupil.id), [pupil.id], 'request'),
      throwsA(isA<DomainError>()),
    );
  });
  test('group undo refuses to erase changed homework', () async {
    final saved = (await repo.saveSchoolGroup(homework(pupil.id), [
      pupil.id,
    ], 'request')).single;
    await repo.saveSchoolRecord(saved.patch({'subject': 'Änderung'}));
    await expectLater(
      repo.undoSchoolGroup('request'),
      throwsA(isA<DomainError>()),
    );
    expect((await repo.schoolRecords()).single.deleted, isFalse);
  });
  test('participants receive no personal assessment', () async {
    final other = await repo.savePupil(
      Pupil(id: 'synthetic-beta', name: 'Testkind Beta'),
    );
    final saved = await repo.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.social, pupil.id).patch({
        'body': 'Beobachtung nur für Alpha',
        'participantIds': [other.id],
        'context': 'Gemeinsamer Kontext',
      }),
    );
    expect(saved.situationId, isNotNull);
    expect(await repo.schoolRecords(), hasLength(1));
    final participants = await repo.db
        .customSelect('SELECT * FROM situation_pupils')
        .get();
    expect(participants, hasLength(2));
  });
  test('goal references cannot cross pupil ownership', () async {
    final other = await repo.savePupil(
      Pupil(id: 'synthetic-beta', name: 'Testkind Beta'),
    );
    final goal = await repo.saveSchoolRecord(
      SchoolRecord.empty(
        SchoolKind.goal,
        pupil.id,
      ).patch({'title': 'Testziel'}),
    );
    final observation = SchoolRecord.empty(
      SchoolKind.social,
      other.id,
    ).patch({'body': 'Beobachtung', 'goalId': goal.id});
    await expectLater(
      repo.saveSchoolRecord(observation),
      throwsA(isA<DomainError>()),
    );
  });
  test(
    'complete rebuild backup round trip includes records, drafts and history',
    () async {
      final saved = await repo.saveSchoolRecord(homework(pupil.id));
      await repo.saveSchoolDraft(
        SchoolDraft(id: 'draft', record: saved, updatedAtUtc: utcNow()),
      );
      final text = await repo.exportBackup();
      final target = memoryRepo();
      await target.initialize();
      try {
        await target.restoreBackup(text);
        expect((await target.schoolRecords()).single.toJson(), saved.toJson());
        expect(await target.schoolDrafts(), hasLength(1));
        expect(await target.history(saved.id), await repo.history(saved.id));
      } finally {
        await target.close();
      }
    },
  );
  test('foreign payload format is rejected without partial restore', () async {
    await repo.saveSchoolRecord(homework(pupil.id));
    final backup = jsonDecode(await repo.exportBackup()) as Json;
    final row = backup['tables']['school_records'][0] as Map;
    final payload = jsonDecode(row['payload'] as String) as Json;
    payload.remove('rebuildFormat');
    row['payload'] = jsonEncode(payload);
    final target = memoryRepo();
    await target.initialize();
    try {
      await expectLater(
        target.restoreBackup(jsonEncode(backup)),
        throwsA(isA<DomainError>()),
      );
      expect(await target.pupils(), isEmpty);
      expect(await target.schoolRecords(), isEmpty);
    } finally {
      await target.close();
    }
  });
  test('real version 1 file migrates to schema 7 without losing pupil', () async {
    final dir = Directory.systemTemp.createTempSync('flex-migration-');
    final file = File('${dir.path}/test.sqlite');
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(File('test/fixtures/schema_v1.sql').readAsStringSync());
    raw.execute(
      "INSERT INTO pupils VALUES ('old','Synthetischer Altbestand',4289248128,0,1)",
    );
    raw.execute('PRAGMA user_version = 1');
    raw.close();
    final migrated = SqliteNotebook(
      NotebookDatabase(
        NativeDatabase(file),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    try {
      await migrated.initialize();
      expect((await migrated.pupils()).single.name, 'Synthetischer Altbestand');
      expect(
        (await migrated.db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        7,
      );
      await migrated.saveSchoolRecord(homework('old'));
    } finally {
      await migrated.close();
      dir.deleteSync(recursive: true);
    }
  });
}
