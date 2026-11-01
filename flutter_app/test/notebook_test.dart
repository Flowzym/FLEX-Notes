import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';

void main() {
  late SqliteNotebook repo;
  final schema = File('assets/schema.sql').readAsStringSync();
  setUp(() async { repo = SqliteNotebook(NotebookDatabase(NativeDatabase.memory(), schema)); await repo.initialize(); });
  tearDown(() => repo.close());
  OrgaEntry task({String? pupilId}) => OrgaEntry.empty(pupilId: pupilId).copyWith(title: 'Synthetisch: Material vorbereiten', isTask: true, dueDate: '2026-11-10', reminderAtUtc: '2026-11-08T15:00:00.000Z', reminderZone: 'Europe/Vienna', reminderState: ReminderState.planned, items: [CheckItem(id: newId(), text: 'Synthetische Testmappe')]);

  test('new workspace contains no seeded pupils or entries', () async {
    expect(await repo.pupils(), isEmpty); expect(await repo.entries(), isEmpty);
  });
  test('create, edit, reload, complete; one revision and outbox per commit', () async {
    final pupil = await repo.savePupil(Pupil(id: newId(), name: 'Testkind Alpha'));
    final first = await repo.saveEntry(task(pupilId: pupil.id));
    final second = await repo.saveEntry(first.copyWith(body: 'Nur synthetische Daten', items: [first.items.single.copyWith(checked: true)]));
    final loaded = (await repo.entries()).single;
    expect(loaded.toJson(), second.toJson());
    expect(loaded.items.single.id, first.items.single.id);
    final completed = await repo.saveEntry(loaded.complete());
    expect(completed.done, isTrue); expect(completed.reminderState, ReminderState.cancelled);
    expect(completed.dueDate, '2026-11-10');
    expect((await repo.history(first.id)).length, 3);
    final backup = jsonDecode(await repo.exportBackup()) as Json;
    expect((backup['tables']['outbox'] as List).length, 4);
    expect((backup['tables']['operations'] as List).map((e) => e['sequence']), [1,2,3,4]);
  });
  test('notes and class Orga have independent reminders and completion', () async {
    final note = await repo.saveEntry(task().copyWith(isTask: false, dueDate: null));
    expect(note.pupilId, isNull); expect(note.isTask, isFalse);
    final acknowledged = await repo.saveEntry(note.acknowledge());
    expect(acknowledged.done, isFalse); expect(acknowledged.pending, isFalse);
    final openTask = await repo.saveEntry(task());
    final dismissed = await repo.saveEntry(openTask.acknowledge());
    expect(dismissed.done, isFalse); expect(dismissed.pending, isTrue);
  });
  test('reopening never rearms a reminder or changes checklist points', () async {
    final initial = await repo.saveEntry(task());
    final done = await repo.saveEntry(initial.complete());
    final reopened = await repo.saveEntry(done.reopen());
    expect(reopened.reminderState, ReminderState.cancelled);
    expect(reopened.items.single.checked, isFalse);
  });
  test('stale editor is rejected and its draft remains available', () async {
    final initial = await repo.saveEntry(task());
    final draft = EditDraft(id: newId(), entry: initial.copyWith(body: 'Lokale Eingabe'), updatedAtUtc: utcNow());
    await repo.saveDraft(draft);
    await repo.saveEntry(initial.copyWith(body: 'Andere Fassung'));
    await expectLater(repo.saveEntry(draft.entry, draftId: draft.id), throwsA(isA<StaleRevision>()));
    expect((await repo.drafts()).single.entry.body, 'Lokale Eingabe');
    expect((await repo.entries()).single.body, 'Andere Fassung');
  });
  test('publishing removes only its own draft', () async {
    final value = task();
    final first = EditDraft(id: newId(), entry: value, updatedAtUtc: utcNow());
    final second = EditDraft(id: newId(), entry: value.copyWith(body: 'Alternative'), updatedAtUtc: utcNow());
    await repo.saveDraft(first); await repo.saveDraft(second);
    await repo.saveEntry(first.entry, draftId: first.id);
    expect((await repo.drafts()).single.id, second.id);
  });
  test('audit/outbox write failure rolls back entry and keeps draft', () async {
    final draft = EditDraft(id: newId(), entry: task(), updatedAtUtc: utcNow()); await repo.saveDraft(draft);
    await repo.db.customStatement("CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'synthetic failure'); END");
    await expectLater(repo.saveEntry(draft.entry, draftId: draft.id), throwsA(anything));
    expect(await repo.entries(), isEmpty); expect((await repo.drafts()).length, 1);
    expect(await repo.history(draft.entry.id), isEmpty);
  });
  test('archive preserves open obligations and original pupil assignment', () async {
    final pupil = await repo.savePupil(Pupil(id: newId(), name: 'Testkind Beta'));
    await repo.saveEntry(task(pupilId: pupil.id)); await repo.savePupil(pupil.copyWith(archived: true));
    expect((await repo.entries()).single.pending, isTrue); expect((await repo.pupils()).single.archived, isTrue);
  });
  test('backup round trip preserves revisions, drafts, IDs, settings and staged legacy', () async {
    final pupil = await repo.savePupil(Pupil(id: newId(), name: 'Testkind Gamma'));
    final value = await repo.saveEntry(task(pupilId: pupil.id));
    await repo.saveDraft(EditDraft(id: newId(), entry: value.copyWith(title: ''), updatedAtUtc: utcNow()));
    await repo.saveAppearance(const Appearance(mode: 'light', textScale: 1.15));
    const legacy = '{"version":3,"schemaVersion":5,"students":[],"entries":[],"homework":[],"reminders":[],"unknownFutureField":{"retain":true}}';
    await repo.stageLegacy(legacy); await repo.stageLegacy(legacy);
    expect(await repo.legacyCount(), 1);
    final text = await repo.exportBackup();
    final restored = SqliteNotebook(NotebookDatabase(NativeDatabase.memory(), schema)); await restored.initialize();
    try {
      await restored.restoreBackup(text);
      expect((await restored.entries()).single.toJson(), value.toJson());
      expect((await restored.drafts()).single.entry.title, '');
      expect((await restored.appearance()).textScale, 1.15);
      final restoredBackup = jsonDecode(await restored.exportBackup()) as Json;
      expect(restoredBackup['tables']['legacy_backups'].single['original_json'], legacy);
      expect(await restored.history(value.id), await repo.history(value.id));
      await expectLater(restored.restoreBackup(text), throwsA(isA<DomainError>()));
    } finally { await restored.close(); }
  });
  test('invalid backup foreign keys roll back all inserted rows', () async {
    final valid = await repo.saveEntry(task());
    final payload = jsonDecode(await repo.exportBackup()) as Json;
    payload['tables']['orga'][0]['pupil_id'] = 'nonexistent-synthetic-pupil';
    final target = SqliteNotebook(NotebookDatabase(NativeDatabase.memory(), schema)); await target.initialize();
    try {
      await expectLater(target.restoreBackup(jsonEncode(payload)), throwsA(anything));
      expect(await target.entries(), isEmpty); expect(await target.history(valid.id), isEmpty);
    } finally { await target.close(); }
  });
  test('disk database survives close and reopening with original IDs', () async {
    final temp = await Directory.systemTemp.createTemp('flex-synthetic-');
    final file = File('${temp.path}/test.sqlite');
    final disk = SqliteNotebook(NotebookDatabase(NativeDatabase(file), schema)); await disk.initialize();
    final saved = await disk.saveEntry(task()); await disk.close();
    final reopened = SqliteNotebook(NotebookDatabase(NativeDatabase(file), schema)); await reopened.initialize();
    try { expect((await reopened.entries()).single.toJson(), saved.toJson()); }
    finally { await reopened.close(); await temp.delete(recursive: true); }
  });
  test('invalid dates, duplicate point IDs and note deadlines are rejected', () {
    expect(validDate('2026-02-29'), isFalse); expect(validDate('2028-02-29'), isTrue);
    expect(() => task().copyWith(dueDate: '2026-02-30').validate(), throwsA(isA<DomainError>()));
    expect(() => task().copyWith(isTask: false).validate(), throwsA(isA<DomainError>()));
    final item = CheckItem(id: newId(), text: 'Test');
    expect(() => task().copyWith(items: [item,item]).validate(), throwsA(isA<DomainError>()));
  });
}
