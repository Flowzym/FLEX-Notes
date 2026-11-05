import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/domain/development.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/domain/backup_merge.dart';
import 'package:flex_notizbuch/services/calendar_ics.dart';
import 'package:flex_notizbuch/services/reminders.dart';

SqliteNotebook classroomMemory() => SqliteNotebook(
  NotebookDatabase(
    NativeDatabase.memory(),
    File('assets/schema.sql').readAsStringSync(),
  ),
);
ClassroomDocument lesson({
  String date = '2026-11-02',
  RepeatRule rule = const RepeatRule(),
  List<Json> exceptions = const [],
  List<String> materials = const [],
}) => ClassroomDocument.create(ClassroomKind.lesson, 'Mathematik', {
  'date': date,
  'start': '08:00',
  'end': '08:50',
  'repeat': rule.toJson(),
  'exceptions': exceptions,
  'materialIds': materials,
});
ClassroomDocument returns(
  String pupil, {
  String status = 'open',
  String type = 'consent',
  String due = '2026-11-10',
}) => ClassroomDocument.create(ClassroomKind.returnList, 'Wandertag', {
  'type': type,
  'dueDate': due,
  'participants': [
    {'pupilId': pupil, 'name': 'Kind', 'status': status, 'note': '', 'paid': 0},
  ],
  'materialIds': <String>[],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  setUp(() async {
    repo = classroomMemory();
    await repo.initialize();
  });
  tearDown(() async => repo.close());
  test(
    'maintenance retains series tombstones and completed sources can stop their series',
    () async {
      final entry = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Serie',
          body: 'Tun',
          isTask: true,
          dueDate: dateOnly(DateTime.now()),
        ),
      );
      await repo.configureRepeat(entry, const RepeatRule(frequency: 'weekly'));
      final generated = (await repo.entries()).firstWhere(
        (e) => e.id != entry.id,
      );
      expect(
        repeatForEntry(
          await repo.classroomDocuments(),
          generated.id,
        )?.text('entryId'),
        entry.id,
      );
      await repo.saveEntry(generated.copyWith(deleted: true));
      await repo.maintainStorage(await repo.exportBackup(), emptyTrash: true);
      await repo.materializeRepeats(DateTime.now());
      expect(
        (await repo.entries()).firstWhere((e) => e.id == generated.id).deleted,
        isTrue,
      );
      final done = await repo.saveEntry(entry.copyWith(done: true));
      await repo.configureRepeat(done, const RepeatRule());
      expect(
        (await repo.entries()).where((e) => !e.deleted && e.id != entry.id),
        isEmpty,
      );
      final copy = classroomMemory();
      await copy.initialize();
      addTearDown(copy.close);
      await copy.restoreBackup(await repo.exportBackup());
    },
  );
  test(
    'ICS rejects detached overrides and unsupported month-end semantics explicitly',
    () {
      final result = parseCalendarIcs(
        'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:series\r\nDTSTART:20261102T080000\r\nDTEND:20261102T090000\r\nRRULE:FREQ=WEEKLY\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:series\r\nRECURRENCE-ID:20261109T080000\r\nDTSTART:20261110T080000\r\nDTEND:20261110T090000\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:monthly\r\nDTSTART:20260131T080000\r\nDTEND:20260131T090000\r\nRRULE:FREQ=MONTHLY\r\nEND:VEVENT\r\nEND:VCALENDAR',
      );
      expect(result.documents, isEmpty);
      expect(result.warnings.length, 3);
    },
  );
  test(
    'weekly A/B dates, DST date arithmetic, monthly short months and exclusions',
    () {
      const fortnight = RepeatRule(
        frequency: 'weekly',
        interval: 2,
        weekdays: [1, 3],
      );
      expect(fortnight.includes('2026-10-19', '2026-10-21', []), isTrue);
      expect(fortnight.includes('2026-10-19', '2026-10-26', []), isFalse);
      expect(fortnight.includes('2026-10-19', '2026-11-02', []), isTrue);
      const monthly = RepeatRule(frequency: 'monthly');
      expect(monthly.includes('2026-01-31', '2026-02-28', []), isTrue);
      expect(monthly.includes('2026-01-31', '2026-03-30', []), isFalse);
      const ended = RepeatRule(
        frequency: 'daily',
        until: '2026-11-10',
        excluded: ['2026-11-05'],
      );
      expect(ended.includes('2026-11-01', '2026-11-05', []), isFalse);
      expect(ended.includes('2026-11-01', '2026-11-11', []), isFalse);
    },
  );
  test(
    'moved and cancelled lessons keep stable identity and respect holidays',
    () {
      final d = lesson(
        rule: const RepeatRule(
          frequency: 'weekly',
          weekdays: [1],
          skipHolidays: true,
        ),
        exceptions: [
          {
            'date': '2026-11-02',
            'cancelled': false,
            'movedTo': '2026-11-04',
            'start': '10:00',
            'end': '10:50',
          },
          {'date': '2026-11-09', 'cancelled': true},
        ],
      );
      final holiday = ClassroomDocument.create(ClassroomKind.holiday, 'Frei', {
        'date': '2026-11-16',
        'endDate': '2026-11-20',
      });
      final items = lessonOccurrences([d, holiday], '2026-11-04', '2026-11-23');
      expect(items.map((e) => e.date), ['2026-11-04', '2026-11-23']);
      expect(items.first.target, 'lesson:${d.id}:2026-11-02');
      expect(items.first.start, '10:00');
      expect(lessonOccurrences([d], '2026-11-02', '2026-11-02'), isEmpty);
    },
  );
  test(
    'validates return status, dates, amounts and safe material identifiers',
    () {
      expect(returnPending({'status': 'no'}), isFalse);
      expect(returnPending({'status': 'partial'}), isTrue);
      expect(
        () => returns('p', status: 'partial'),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => lesson().patch({'start': '12:00', 'end': '10:00'}),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => ClassroomDocument.create(ClassroomKind.material, 'Datei', {
          'localKey': '../outside',
          'extension': 'pdf',
        }),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => ClassroomDocument.create(ClassroomKind.material, 'Link', {
          'url': 'javascript:alert(1)',
          'extension': 'link',
        }),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'classroom revisions, draft publication and rollback are atomic',
    () async {
      await repo.savePupil(const Pupil(id: 'p', name: 'Kind'));
      final d = await repo.saveClassroomDocument(returns('p'));
      await repo.saveClassroomDocument(d.patch({'note': 'Neue Fassung'}));
      await expectLater(
        repo.saveClassroomDocument(d.patch({'note': 'Veraltet'})),
        throwsA(isA<StaleRevision>()),
      );
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: 'draft',
          type: 'classroom',
          ownerId: d.id,
          data: d.toJson(),
          updatedAtUtc: utcNow(),
        ),
      );
      await expectLater(
        repo.saveClassroomDocument(d, draft: draft),
        throwsA(isA<StaleRevision>()),
      );
      expect((await repo.dialogDrafts()).single.id, 'draft');
      final current = (await repo.classroomDocuments()).single;
      await repo.saveClassroomDocument(
        current.patch({'note': 'Fertig'}),
        draft: draft,
      );
      expect(await repo.dialogDrafts(), isEmpty);
      expect((await repo.history(d.id)).length, 3);
    },
  );
  test(
    'batch links resolve atomically and a broken reference leaves no writes',
    () async {
      final material = ClassroomDocument.create(
        ClassroomKind.material,
        'Plan',
        {'url': 'https://example.org/plan.docx', 'extension': 'docx'},
      );
      final l = lesson(materials: [material.id]);
      await repo.saveClassroomDocuments([l, material]);
      expect((await repo.classroomDocuments()).length, 2);
      await expectLater(
        repo.saveClassroomDocument(
          l.patch({
            'id': newId(),
            'materialIds': ['missing'],
          }),
        ),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.classroomDocuments()).length, 2);
    },
  );
  test(
    'older backup remains readable; new documents and histories round trip',
    () async {
      await repo.savePupil(const Pupil(id: 'p', name: 'Kind'));
      await repo.saveClassroomDocument(returns('p', status: 'no'));
      final copy = classroomMemory();
      await copy.initialize();
      addTearDown(copy.close);
      await copy.restoreBackup(await repo.exportBackup());
      expect(
        (await copy.classroomDocuments()).single
            .rows('participants')
            .single['status'],
        'no',
      );
      expect(
        (await copy.history(
          (await copy.classroomDocuments()).single.id,
        )).length,
        1,
      );
      final old = classroomMemory();
      await old.initialize();
      addTearDown(old.close);
      final blank = classroomMemory();
      await blank.initialize();
      addTearDown(blank.close);
      await blank.restoreBackup(await old.exportBackup());
      expect((await blank.snapshot()).classroom, isEmpty);
    },
  );
  test(
    'merge includes classroom links and maps pupil IDs even without catalog import',
    () async {
      await repo.savePupil(const Pupil(id: 'local', name: 'Kind'));
      final source = classroomMemory();
      await source.initialize();
      addTearDown(source.close);
      await source.savePupil(const Pupil(id: 'remote', name: 'Kind'));
      final material = await source.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Plan', {
          'url': 'https://example.org/plan.pdf',
          'extension': 'pdf',
        }),
      );
      await source.saveClassroomDocument(lesson(materials: [material.id]));
      await source.saveClassroomDocument(returns('remote'));
      final backup = await source.exportBackup();
      final before = canonical(
        (jsonDecode(await repo.exportBackup()) as Map)['tables'],
      );
      final plan = await repo.prepareBackupMerge(
        backup,
        pupilLinks: {'remote': 'local'},
        catalogs: false,
      );
      expect(
        canonical((jsonDecode(await repo.exportBackup()) as Map)['tables']),
        before,
      );
      await repo.applyBackupMerge(plan, {});
      final docs = await repo.classroomDocuments();
      expect(docs.length, 3);
      expect(
        docs
            .firstWhere((d) => d.kind == ClassroomKind.returnList)
            .rows('participants')
            .single['pupilId'],
        'local',
      );
      final again = await repo.prepareBackupMerge(
        backup,
        pupilLinks: {'remote': 'local'},
        catalogs: false,
      );
      expect(again.newCount, 0);
      expect(again.conflicts, 0);
    },
  );
  test(
    'invalid imported classroom reference rolls back instead of leaving partial data',
    () async {
      final source = classroomMemory();
      await source.initialize();
      addTearDown(source.close);
      await source.savePupil(const Pupil(id: 'p', name: 'Kind'));
      await source.saveClassroomDocument(returns('p'));
      final raw = Json.from(jsonDecode(await source.exportBackup()) as Map);
      final row = (raw['tables']['preferences'] as List).singleWhere(
        (r) => (r['key'] as String).startsWith('classroom:'),
      );
      final payload = Json.from(jsonDecode(row['payload'] as String) as Map);
      payload['participants'][0]['pupilId'] = 'missing';
      row['payload'] = jsonEncode(payload);
      await expectLater(
        repo.prepareBackupMerge(jsonEncode(raw)),
        throwsA(isA<DomainError>()),
      );
      expect(await repo.classroomDocuments(), isEmpty);
      expect(await repo.pupils(), isEmpty);
    },
  );
  test(
    'recurring tasks are independent and opening repeatedly creates no duplicates',
    () async {
      final now = DateTime.now(),
          start = dateOnly(now),
          until = dateOnly(now.add(const Duration(days: 21)));
      final source = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Kontrolle',
          isTask: true,
          dueDate: start,
          items: [const CheckItem(id: 'check', text: 'Material')],
        ),
      );
      await repo.configureRepeat(
        source,
        RepeatRule(frequency: 'weekly', until: until),
      );
      final first = await repo.entries();
      expect(first.length, 4);
      expect(first.expand((e) => e.items).map((i) => i.id).toSet().length, 4);
      final next = first.firstWhere((e) => e.id != source.id);
      await repo.saveEntry(next.complete());
      await repo.snapshot();
      await repo.snapshot();
      expect((await repo.entries()).length, 4);
      expect((await repo.entries()).where((e) => e.done).length, 1);
      await repo.configureRepeat(source, const RepeatRule());
      expect(
        (await repo.entries())
            .where((e) => !e.deleted && !e.done)
            .map((e) => e.id),
        [source.id],
      );
    },
  );
  test(
    'series changes never revive an individually deleted occurrence',
    () async {
      final now = DateTime.now();
      final until = dateOnly(now.add(const Duration(days: 21)));
      final entry = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Kontrolle',
          isTask: true,
          dueDate: dateOnly(now),
        ),
      );
      final rule = RepeatRule(frequency: 'weekly', until: until);
      await repo.configureRepeat(entry, rule);
      final occurrence = (await repo.entries()).firstWhere(
        (e) => e.id != entry.id,
      );
      await repo.saveEntry(occurrence.copyWith(deleted: true));
      await repo.configureRepeat(entry, rule);
      await repo.configureRepeat(entry, rule);
      expect(
        (await repo.entries()).firstWhere((e) => e.id == occurrence.id).deleted,
        isTrue,
      );
    },
  );
  test(
    'adding and removing holidays updates only untouched generated tasks',
    () async {
      final now = DateTime.now();
      final start = dateOnly(now);
      final next = dateOnly(now.add(const Duration(days: 7)));
      final entry = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Kontrolle',
          isTask: true,
          dueDate: start,
        ),
      );
      await repo.configureRepeat(
        entry,
        RepeatRule(frequency: 'weekly', until: next, skipHolidays: true),
      );
      final h = await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.holiday, 'Frei', {
          'date': next,
          'endDate': next,
        }),
      );
      await repo.snapshot();
      expect((await repo.entries()).where((e) => !e.deleted).length, 1);
      await repo.saveClassroomDocument(h.patch({'deleted': true}));
      await repo.snapshot();
      expect((await repo.entries()).where((e) => !e.deleted).length, 2);
    },
  );
  test(
    'calendar combines existing records, lessons and returns but excludes archived pupils',
    () async {
      await repo.savePupil(const Pupil(id: 'p', name: 'Kind'));
      await repo.savePupil(const Pupil(id: 'old', name: 'Archiv'));
      await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Termin',
          appointmentDate: '2026-11-10',
          appointmentTime: '10:00',
        ),
      );
      await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'p').patch({
          'dueDate': '2026-11-10',
          'tasks': [HomeworkTask(id: 'h', text: 'Lesen').toJson()],
        }),
      );
      await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.goal, 'old').patch({
          'title': 'Ziel',
          'criterion': 'Kriterium',
          'nextReviewDate': '2026-11-10',
        }),
      );
      final archived = (await repo.pupils()).firstWhere((p) => p.id == 'old');
      await repo.savePupil(archived.copyWith(archived: true));
      await repo.saveClassroomDocument(lesson(date: '2026-11-10'));
      await repo.saveClassroomDocument(returns('p'));
      final items = calendarItems(
        await repo.snapshot(),
        '2026-11-10',
        '2026-11-10',
      );
      expect(items.map((e) => e.category).toSet(), {
        'lesson',
        'appointment',
        'homework',
        'return',
      });
    },
  );
  test(
    'postponing a reminder leaves deadline unchanged and completion cancels it',
    () async {
      final now = DateTime(2026, 11, 10, 12);
      final e = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Aufgabe',
          isTask: true,
          dueDate: '2026-11-09',
        ),
      );
      await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.reminder, 'Aufgabe', {
          'target': 'orga:${e.id}',
          'at': DateTime(2026, 11, 11, 9).toUtc().toIso8601String(),
          'dismissed': false,
        }),
      );
      var data = await repo.snapshot();
      expect(
        planReminders(data, {}, now).single.when.toUtc(),
        DateTime(2026, 11, 11, 9).toUtc(),
      );
      expect(data.entries.single.dueDate, '2026-11-09');
      await repo.saveEntry(e.complete());
      data = await repo.snapshot();
      expect(planReminders(data, {}, now), isEmpty);
    },
  );
  test(
    'closed and answered returns do not schedule reminders, lessons respect cancellation',
    () async {
      await repo.savePupil(const Pupil(id: 'p', name: 'Kind'));
      await repo.saveClassroomDocument(returns('p', status: 'no'));
      await repo.saveClassroomDocument(
        lesson(
          date: '2026-11-10',
          exceptions: [
            {'date': '2026-11-10', 'cancelled': true},
          ],
        ),
      );
      expect(
        planReminders(await repo.snapshot(), {}, DateTime(2026, 11, 9)),
        isEmpty,
      );
    },
  );
  test(
    'development retains empty weeks and does not invent tone for untagged free text',
    () {
      final records = [
        SchoolRecord.empty(SchoolKind.social, 'p').patch({
          'observedOn': '2026-11-02',
          'positive': ['Hört zu'],
          'negative': ['Unterbricht'],
        }),
        SchoolRecord.empty(
          SchoolKind.work,
          'p',
        ).patch({'observedOn': '2026-11-03', 'body': 'Freitext'}),
        SchoolRecord.empty(SchoolKind.social, 'p').patch({
          'observedOn': '2026-11-03',
          'neutral': ['Beobachtung'],
          'deleted': true,
        }),
      ];
      final weeks = developmentWeeks(
        records,
        pupilId: 'p',
        from: '2026-11-02',
        to: '2026-11-15',
      );
      expect(weeks.length, 2);
      expect(weeks.last.records, isEmpty);
      expect(weeks.first.records.length, 2);
      expect(weeks.first.count('positive'), 1);
      expect(weeks.first.count('negative'), 1);
      expect(weeks.first.count('neutral'), 0);
      expect(weeks.first.count('free'), 1);
      expect(
        developmentWeeks(
          records,
          pupilId: 'p',
          from: '2026-11-02',
          to: '2026-11-15',
          query: 'Hört zu',
        ).first.records.length,
        1,
      );
    },
  );
  test(
    'ICS round trip escapes multiline unicode and import identity is stable',
    () {
      final source = [
        const CalendarItem(
          id: 'id',
          date: '2026-11-10',
          time: '10:00',
          end: '11:00',
          title: 'Äpfel, Bücher; Planung\nweiter',
          category: 'lesson',
          detail: 'FLEX-Klasse',
        ),
      ];
      final text = exportCalendarIcs(source, now: DateTime.utc(2026));
      final parsed = parseCalendarIcs(text);
      expect(parsed.warnings, isEmpty);
      expect(parsed.documents.single.title, source.single.title);
      expect(
        parseCalendarIcs(text).documents.single.id,
        parsed.documents.single.id,
      );
      for (final line in text.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
    },
  );
  test(
    'ICS reports unsupported rules instead of scheduling an incorrect one-off event',
    () {
      const text =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261110T100000\r\nDTEND:20261110T110000\r\nRRULE:FREQ=YEARLY\r\nSUMMARY:Termin\r\nEND:VEVENT\r\nEND:VCALENDAR';
      final parsed = parseCalendarIcs(text);
      expect(parsed.documents, isEmpty);
      expect(parsed.warnings.single, contains('Wiederholung'));
    },
  );
  test('ICS preserves supported weekly recurrence and excluded dates', () {
    const text =
        'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:x\nDTSTART:20261102T100000\nDTEND:20261102T110000\nRRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;UNTIL=20261201\nEXDATE:20261116T100000\nSUMMARY:Plan\nEND:VEVENT\nEND:VCALENDAR';
    final parsed = parseCalendarIcs(text);
    expect(parsed.warnings, isEmpty);
    expect(
      lessonOccurrences(
        parsed.documents,
        '2026-11-01',
        '2026-11-30',
      ).map((e) => e.date),
      ['2026-11-02', '2026-11-30'],
    );
  });
}
