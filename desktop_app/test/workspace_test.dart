import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_desktop/data/demo_workspace.dart';
import 'package:flex_notizbuch/services/complete_backup.dart';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_desktop/application/editor_session.dart';
import 'package:flex_desktop/application/workspace_controller.dart';
import 'package:flex_desktop/domain/core.dart';

class MemoryFiles implements MaterialFiles {
  final values = <String, Uint8List>{};
  int? failWrite;
  int writes = 0;
  @override
  Future<bool> exists(String key) async => values.containsKey(key);
  @override
  Future<Uint8List> read(String key) async => values[key]!;
  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (++writes == failWrite) throw const DomainError('Test: Speicher voll');
    values[key] = bytes;
  }
}

void main() {
  // Independent in-memory executors intentionally simulate two devices.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  late WorkspaceController c;
  late MemoryFiles files;
  late Pupil pupil;
  setUp(() async {
    repo = SqliteNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    final notebook = NotebookController(repo);
    await notebook.initialize();
    files = MemoryFiles();
    c = WorkspaceController(notebook, files: files);
    pupil = await repo.savePupil(Pupil(id: newId(), name: 'Testkind Alpha'));
    await notebook.reload();
  });
  tearDown(() async {
    await c.editor?.flush();
    c.dispose();
    await repo.close();
  });
  test(
    'new desktop repository has no automatic timetable or demo data',
    () async {
      expect(c.notebook.entries, isEmpty);
      expect(c.notebook.records, isEmpty);
      expect(c.notebook.classroom, isEmpty);
    },
  );
  test(
    'switching editors preserves pupil and content across restart',
    () async {
      await c.start(EntryKind.social, pupil: pupil.id);
      c.editor!.patch({
        'body': 'Synthetische Beobachtung',
        'neutral': ['Fragt nach'],
      });
      await c.start(EntryKind.task);
      final draft = (await repo.schoolDrafts()).single;
      expect(draft.record.pupilId, pupil.id);
      expect(draft.record.body, 'Synthetische Beobachtung');
      await c.edit(draft);
      c.editor!.patch({'body': 'Ergänzte Beobachtung'});
      await c.commitEditor();
      expect(await repo.schoolDrafts(), isEmpty);
      expect((await repo.schoolRecords()).single.body, 'Ergänzte Beobachtung');
    },
  );
  test('rapid writes keep latest text and consume only one draft', () async {
    await c.start(EntryKind.note);
    final editor = c.editor!;
    editor.patch({'title': 'Anfang'});
    final first = editor.flush();
    editor.patch({'title': 'Letzter Stand', 'body': 'Bleibt erhalten'});
    final second = editor.flush();
    await Future.wait([first, second]);
    await c.commitEditor();
    expect(await repo.drafts(), isEmpty);
    expect((await repo.entries()).single.title, 'Letzter Stand');
    expect((await repo.entries()).single.body, 'Bleibt erhalten');
  });
  test(
    'invalid save retains draft and can be corrected without duplicating',
    () async {
      await c.start(EntryKind.task);
      c.editor!.patch({'body': 'Wichtige noch unvollständige Aufgabe'});
      await expectLater(c.commitEditor(), throwsA(isA<DomainError>()));
      expect(c.editor, isNotNull);
      expect((await repo.drafts()).single.entry.body, contains('Wichtige'));
      expect(await repo.entries(), isEmpty);
      c.editor!.patch({'title': 'Korrigiert'});
      await c.commitEditor();
      expect(await repo.drafts(), isEmpty);
      expect((await repo.entries()).length, 1);
    },
  );
  test('stale edits never overwrite a newer entry', () async {
    final entry = await repo.saveEntry(
      OrgaEntry.empty().copyWith(title: 'Original'),
    );
    await c.edit(entry);
    c.editor!.patch({'title': 'Desktopentwurf'});
    await repo.saveEntry(entry.copyWith(title: 'Andere Änderung'));
    await expectLater(c.commitEditor(), throwsA(isA<StaleRevision>()));
    expect((await repo.entries()).single.title, 'Andere Änderung');
    expect((await repo.drafts()).single.entry.title, 'Desktopentwurf');
  });
  test(
    'all non-school draft types support blank titles and atomic save',
    () async {
      for (final kind in [
        EntryKind.note,
        EntryKind.task,
        EntryKind.appointment,
        EntryKind.plan,
        EntryKind.lesson,
        EntryKind.returnList,
      ]) {
        await c.start(kind, pupil: pupil.id);
        c.editor!.patch({kind.orga ? 'body' : 'note': 'Noch unfertig'});
        await c.editor!.flush();
        c.editor!.patch({'title': 'Test ${kind.name}'});
        await c.commitEditor();
      }
      expect(await repo.drafts(), isEmpty);
      expect(await repo.dialogDrafts(), isEmpty);
      expect((await repo.entries()).length, 3);
      expect((await repo.classroomDocuments()).length, 3);
    },
  );
  test(
    'return list preserves participant statuses and appears in calendar',
    () async {
      await c.start(EntryKind.returnList, pupil: pupil.id);
      c.editor!.patch({
        'title': 'Testformular',
        'dueDate': '2026-11-16',
        'participants': [
          {
            'pupilId': pupil.id,
            'name': pupil.name,
            'status': 'received',
            'paid': 0,
            'note': 'Übergeben',
          },
        ],
      });
      await c.commitEditor();
      final doc = (await repo.classroomDocuments()).single;
      expect(doc.returnParticipant(pupil.id)!['status'], 'received');
      expect(
        calendarItems(
          c.notebook.currentSnapshot,
          '2026-11-16',
          '2026-11-16',
        ).single.done,
        isTrue,
      );
    },
  );
  test('material batch prevalidation leaves no partial imports', () async {
    await expectLater(
      c.importFiles([
        (name: 'valid.pdf', bytes: Uint8List.fromList('%PDF-1.7\n'.codeUnits)),
        (name: 'invalid.pdf', bytes: Uint8List.fromList([1, 2])),
      ]),
      throwsA(isA<DomainError>()),
    );
    expect(files.values, isEmpty);
    expect(await repo.classroomDocuments(), isEmpty);
  });
  test('file storage failure rolls back earlier batch files', () async {
    files.failWrite = 2;
    await expectLater(
      c.importFiles([
        for (final n in ['a', 'b'])
          (name: '$n.pdf', bytes: Uint8List.fromList('%PDF-1.7\n'.codeUnits)),
      ]),
      throwsA(isA<DomainError>()),
    );
    expect(files.values, isEmpty);
    expect(await repo.classroomDocuments(), isEmpty);
  });
  test(
    'pupil assignment adds dates without changing another pupil or file',
    () async {
      final other = await repo.savePupil(
        Pupil(id: newId(), name: 'Testkind Beta'),
      );
      await c.importFiles([
        (name: 'lesson.pdf', bytes: Uint8List.fromList('%PDF-1.7\n'.codeUnits)),
      ]);
      final original = c.materials.single;
      await c.assignMaterials([original.id], [pupil.id], '2026-11-16');
      await c.assignMaterials([original.id], [other.id], '2026-11-17');
      await c.assignMaterials([original.id], [pupil.id], '2026-11-18');
      final m = c.materials.single;
      expect(pupilMaterialDates(m, pupil.id), ['2026-11-16', '2026-11-18']);
      expect(pupilMaterialDates(m, other.id), ['2026-11-17']);
      expect(m.text('localKey'), original.text('localKey'));
      expect(files.values.length, 1);
    },
  );
  test(
    'moving appointments preserves duration, tags, pupil and participants',
    () async {
      final e = await repo.saveEntry(
        OrgaEntry.empty(pupilId: pupil.id).copyWith(
          title: 'Gespräch',
          appointmentDate: '2026-11-16',
          appointmentTime: '09:00',
          appointmentEndTime: '09:45',
          tags: ['Gespräch'],
          otherParticipants: 'Testperson',
        ),
      );
      await c.notebook.reload();
      final item = calendarItems(
        c.notebook.currentSnapshot,
        '2026-11-16',
        '2026-11-16',
      ).single;
      await c.moveAppointment(item, DateTime(2026, 11, 17), '10:30');
      final saved = (await repo.entries()).single;
      expect(saved.id, e.id);
      expect(saved.appointmentEndTime, '11:15');
      expect(saved.tags, ['Gespräch']);
      expect(saved.pupilId, pupil.id);
      expect(saved.otherParticipants, 'Testperson');
    },
  );
  test('discard removes draft without deleting original entry', () async {
    final original = await repo.saveEntry(
      OrgaEntry.empty().copyWith(title: 'Original'),
    );
    await c.edit(original);
    c.editor!.patch({'title': 'Verworfen'});
    await c.editor!.flush();
    await c.discardEditor();
    expect(await repo.drafts(), isEmpty);
    expect((await repo.entries()).single.title, 'Original');
  });
  test('desktop snapshot remains readable by the Android repository', () async {
    await c.start(EntryKind.work, pupil: pupil.id);
    c.editor!.patch({
      'body': 'Text aus Desktop',
      'positive': ['Arbeitet selbstständig'],
    });
    await c.commitEditor();
    await c.start(EntryKind.note);
    c.editor!.patch({'title': 'Entwurf bleibt dabei'});
    await c.editor!.flush();
    final backup = await repo.exportBackup();
    final android = SqliteNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('../flutter_app/assets/schema.sql').readAsStringSync(),
      ),
    );
    await android.initialize();
    try {
      await android.restoreBackup(backup);
      expect((await android.schoolRecords()).single.body, 'Text aus Desktop');
      expect(
        (await android.drafts()).single.entry.title,
        'Entwurf bleibt dabei',
      );
    } finally {
      await android.close();
    }
  });
  test(
    'demo opens with a valid complete workspace and never reseeds',
    () async {
      final demoRepo = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final demo = NotebookController(demoRepo);
      await demo.initialize();
      try {
        await seedDemo(demo, files, DateTime(2026, 11, 16));
        expect(demo.pupils.length, 8);
        expect(
          demo.classroom.where((d) => d.kind == ClassroomKind.lesson).length,
          10,
        );
        expect(demo.records.length, 7);
        final count = demo.classroom.length;
        await seedDemo(demo, files, DateTime(2026, 11, 16));
        expect(demo.classroom.length, count);
      } finally {
        demo.dispose();
        await demoRepo.close();
      }
    },
  );
  test(
    'complete exchange includes file bytes and their individual dates',
    () async {
      final bytes = Uint8List.fromList('%PDF-1.7\n'.codeUnits);
      await c.importFiles([(name: 'worksheet.pdf', bytes: bytes)]);
      final m = c.materials.single;
      await c.assignMaterials([m.id], [pupil.id], '2026-11-16');
      final complete = await CompleteBackup.decode(
        Json.from(jsonDecode(await CompleteBackup.capture(repo, files)) as Map),
      );
      expect(complete.files[m.text('localKey')], bytes);
      expect(complete.notebook, contains('2026-11-16'));
      expect(complete.notebook, contains(pupil.id));
    },
  );
}
