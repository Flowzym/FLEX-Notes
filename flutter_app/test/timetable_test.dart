import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/timetable.dart';
import 'classroom_test.dart' show classroomMemory, lesson;
import 'material_workspace_test.dart' show material;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  setUp(() async {
    repo = classroomMemory();
    await repo.initialize();
  });
  tearDown(() => repo.close());

  test(
    'PDF transcription preserves merged blocks, exact periods, rooms and teachers',
    () {
      final docs = flexTimetableTemplate(), table = docs.first;
      expect(table.text('date'), '2026-11-09');
      expect(table.rows('slots').map((s) => '${s['start']}-${s['end']}'), [
        '07:45-08:35',
        '08:40-09:30',
        '09:30-10:20',
        '10:40-11:30',
        '11:35-12:25',
        '12:30-13:20',
        '13:25-14:15',
        '14:20-15:10',
        '15:10-16:00',
        '16:10-17:00',
      ]);
      final week = lessonOccurrences(docs, '2026-11-09', '2026-11-15');
      expect(
        week.map(
          (l) =>
              '${schoolDay(l.date).weekday} ${l.title} ${l.start}-${l.end} ${l.document.text('teacher')} ${l.document.text('room')}'
                  .trim(),
        ),
        [
          '1 Flexk 07:45-11:30 ZiFl',
          '1 PH 13:25-14:15 GöCh',
          '1 BSPK 14:20-15:10 GöCh',
          '2 Flexk 07:45-12:25 ZiFl',
          '2 BUB 15:10-16:00 GöCh',
          '3 Flexk 07:45-11:30 ZiFl',
          '3 DG 11:35-12:25 GöCh',
          '3 TDTE 13:25-15:10 GöCh',
          '4 Flexk 07:45-11:30 ZiFl',
          '4 BSPK 13:25-14:15 GöCh TS 2',
          '5 Flexk 07:45-12:25 ZiFl',
          '5 BSPK 12:30-13:20 GöCh TS 1',
        ],
      );
      expect(lessonOccurrences(docs, '2026-11-02', '2026-11-08'), isEmpty);
      expect(
        lessonOccurrences(docs, '2026-11-16', '2026-11-22'),
        hasLength(12),
      );
      final holiday = ClassroomDocument.create(
        ClassroomKind.holiday,
        'Ferien',
        {'date': '2026-11-16', 'endDate': '2026-11-20'},
      );
      expect(
        lessonOccurrences([...docs, holiday], '2026-11-16', '2026-11-22'),
        isEmpty,
      );
      expect(docs.map((d) => d.id), flexTimetableTemplate().map((d) => d.id));
    },
  );

  test(
    'initialization is additive and never restores edited or removed blocks',
    () async {
      await repo.savePupil(const Pupil(id: 'p', name: 'Testkind'));
      await initializeFlexTimetable(repo);
      final docs = await repo.classroomDocuments();
      expect(docs, hasLength(13));
      final block = docs.firstWhere((d) => d.kind == ClassroomKind.lesson);
      await repo.saveClassroomDocument(
        block.patch({'title': 'Angepasst', 'deleted': true}),
      );
      await initializeFlexTimetable(repo);
      final after = await repo.classroomDocuments();
      expect(after, hasLength(13));
      expect(after.firstWhere((d) => d.id == block.id).deleted, isTrue);
      expect(after.firstWhere((d) => d.id == block.id).title, 'Angepasst');
      expect((await repo.pupils()).single.name, 'Testkind');
    },
  );

  test(
    'existing calendar lessons prevent automatic duplicates, including trash',
    () async {
      await repo.saveClassroomDocument(lesson().patch({'deleted': true}));
      await initializeFlexTimetable(repo);
      expect(await repo.classroomDocuments(), hasLength(1));
      // Explicit adoption remains possible and retains the existing entry.
      await repo.saveClassroomDocuments(flexTimetableTemplate());
      expect(await repo.classroomDocuments(), hasLength(14));
    },
  );

  test(
    'weekday change preserves preparation, moved occurrences and reminder references',
    () async {
      final docs = flexTimetableTemplate(),
          table = docs.first,
          file = material('Arbeitsblatt');
      final plan = ClassroomDocument.create(ClassroomKind.plan, 'Planung', {
        'lessonIds': [docs[1].id],
        'materialIds': [file.id],
      });
      final old = patchLessonOccurrence(docs[1], '2026-11-16', {
        'materialIds': [file.id],
        'planIds': [plan.id],
        'note': 'Vorbereitet',
        'movedTo': '2026-11-20',
      });
      final reminder =
          ClassroomDocument.create(ClassroomKind.reminder, 'Erinnerung', {
            'target': 'lesson:${old.id}:2026-11-16',
            'at': '2026-11-16T06:00:00.000Z',
            'dismissed': false,
          });
      await repo.saveClassroomDocuments([table, old, file, plan, reminder]);
      final current = await repo.classroomDocuments(),
          saved = current.firstWhere((d) => d.id == old.id);
      await repo.saveClassroomDocuments(
        changeTimetableBlock(
          current,
          saved,
          saved.patch({
            'date': '2026-11-10',
            'repeat': {
              ...saved.rule.toJson(),
              'weekdays': [2],
            },
            'start': '08:00',
          }),
        ),
      );
      final after = await repo.classroomDocuments(),
          moved = lessonOccurrences(after, '2026-11-20', '2026-11-20').single;
      expect(moved.originalDate, '2026-11-17');
      expect(moved.materialIds, [file.id]);
      expect(moved.planIds, [plan.id]);
      expect(moved.note, 'Vorbereitet');
      expect(
        after.firstWhere((d) => d.id == reminder.id).text('target'),
        'lesson:${old.id}:2026-11-17',
      );
      expect(after.firstWhere((d) => d.id == plan.id).strings('lessonIds'), [
        old.id,
      ]);
    },
  );

  test(
    'period updates follow standard edges and retain custom times and exceptions',
    () async {
      final docs = flexTimetableTemplate();
      final custom = patchLessonOccurrence(
        docs[1].patch({'start': '08:00'}),
        '2026-11-16',
        {'start': '08:10', 'end': '11:30', 'note': 'Einmalig'},
      );
      await repo.saveClassroomDocuments([docs.first, custom, docs[4]]);
      final current = await repo.classroomDocuments(),
          table = current.firstWhere((d) => d.kind == ClassroomKind.timetable);
      final after = table.patch({
        'slots': [
          for (final s in table.rows('slots'))
            {
              ...s,
              if (s['id'] == 'p1') 'start': '07:40',
              if (s['id'] == 'p4') 'end': '11:25',
            },
        ],
      });
      await repo.saveClassroomDocuments(
        changeTimetableHours(current, table, after),
      );
      final saved = await repo.classroomDocuments();
      expect(saved.firstWhere((d) => d.id == custom.id).text('start'), '08:00');
      expect(saved.firstWhere((d) => d.id == custom.id).text('end'), '11:25');
      expect(
        saved.firstWhere((d) => d.id == docs[4].id).text('start'),
        '07:40',
      );
      expect(
        lessonOccurrences(saved, '2026-11-16', '2026-11-16').single.start,
        '08:10',
      );
    },
  );

  test(
    'period updates do not reunite split series or resurrect historical dates',
    () {
      final docs = flexTimetableTemplate(), table = docs.first;
      final old = docs[1].patch({
        'repeat': {...docs[1].rule.toJson(), 'until': '2026-11-15'},
      });
      final next = ClassroomDocument.fromJson({
        ...docs[1].toJson(),
        'id': newId(),
        'date': '2026-11-16',
      });
      final after = table.patch({
        'slots': [
          for (final s in table.rows('slots'))
            {...s, if (s['id'] == 'p1') 'start': '07:40'},
        ],
      });
      final changed = changeTimetableHours([table, old, next], table, after);
      expect(
        lessonOccurrences(changed, '2026-11-09', '2026-11-22'),
        hasLength(2),
      );
      expect(
        changed.firstWhere((d) => d.id == old.id).rule.until,
        '2026-11-15',
      );
      expect(
        changed.firstWhere((d) => d.id == next.id).text('date'),
        '2026-11-16',
      );
    },
  );

  test('shortened validity cannot silently discard prepared occurrences', () {
    final docs = flexTimetableTemplate(), table = docs.first;
    final block = patchLessonOccurrence(docs[1], '2026-11-23', {
      'note': 'Behalten',
    });
    expect(
      () => changeTimetableHours(
        [table, block],
        table,
        table.patch({'endDate': '2026-11-20'}),
      ),
      throwsA(isA<DomainError>()),
    );
  });

  test(
    'invalid periods and broken references roll back the complete save',
    () async {
      final docs = flexTimetableTemplate(), table = docs.first;
      expect(
        () => table.patch({
          'slots': [...table.rows('slots'), table.rows('slots').first],
        }),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => table.patch({
          'slots': [
            {'id': 'x', 'label': '1', 'start': '09:00', 'end': '08:00'},
          ],
        }),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        repo.saveClassroomDocuments([
          table,
          docs[1].patch({
            'slotIds': ['missing'],
          }),
        ]),
        throwsA(isA<DomainError>()),
      );
      expect(await repo.classroomDocuments(), isEmpty);
    },
  );

  test(
    'stale block aborts time-grid transaction without partial period changes',
    () async {
      await initializeFlexTimetable(repo);
      final before = await repo.classroomDocuments(),
          table = before.firstWhere((d) => d.kind == ClassroomKind.timetable);
      final block = before.firstWhere((d) => d.kind == ClassroomKind.lesson);
      await repo.saveClassroomDocument(
        block.patch({'note': 'Parallel geändert'}),
      );
      final after = table.patch({
        'slots': [
          for (final s in table.rows('slots'))
            {...s, if (s['id'] == 'p1') 'start': '07:40'},
        ],
      });
      await expectLater(
        repo.saveClassroomDocuments(changeTimetableHours(before, table, after)),
        throwsA(isA<StaleRevision>()),
      );
      final saved = await repo.classroomDocuments();
      expect(
        saved.firstWhere((d) => d.id == table.id).rows('slots'),
        table.rows('slots'),
      );
      expect(
        saved.firstWhere((d) => d.id == block.id).text('note'),
        'Parallel geändert',
      );
    },
  );

  test(
    'timetable, custom block and lesson preparation survive restore and merge',
    () async {
      await initializeFlexTimetable(repo);
      final docs = await repo.classroomDocuments(),
          block = docs.firstWhere((d) => d.kind == ClassroomKind.lesson);
      await repo.saveClassroomDocument(
        patchLessonOccurrence(
          block,
          '2026-11-${schoolDay(block.text('date')).day + 7}',
          {'note': 'Unterlagen bereitlegen'},
        ).patch({'title': 'Eigener Block'}),
      );
      final backup = await repo.exportBackup();
      for (final merge in [false, true]) {
        final copy = classroomMemory();
        await copy.initialize();
        addTearDown(copy.close);
        if (merge) {
          await copy.applyBackupMerge(
            await copy.prepareBackupMerge(backup, catalogs: false),
            {},
          );
        } else {
          await copy.restoreBackup(backup);
        }
        final saved = await copy.classroomDocuments();
        expect(saved, hasLength(13));
        expect(
          saved.firstWhere((d) => d.id == block.id).title,
          'Eigener Block',
        );
        expect(
          saved
              .firstWhere((d) => d.id == block.id)
              .rows('exceptions')
              .single['note'],
          'Unterlagen bereitlegen',
        );
        expect(
          lessonOccurrences(saved, '2026-11-16', '2026-11-22'),
          hasLength(12),
        );
      }
    },
  );
  test(
    'regular timetable chooses the current split series and skips historical copies',
    () {
      final docs = flexTimetableTemplate(), table = docs.first;
      final old = docs[1].patch({
        'repeat': {...docs[1].rule.toJson(), 'until': '2026-11-15'},
      });
      final next = ClassroomDocument.fromJson({
        ...docs[1].toJson(),
        'id': newId(),
        'date': '2026-11-16',
        'title': 'Neuer Block',
      });
      expect(
        timetableBlocks(
          [table, old, next],
          table,
          at: DateTime(2026, 11, 9),
        ).single.id,
        old.id,
      );
      expect(
        timetableBlocks(
          [table, old, next],
          table,
          at: DateTime(2026, 11, 16),
        ).single.id,
        next.id,
      );
    },
  );
}
