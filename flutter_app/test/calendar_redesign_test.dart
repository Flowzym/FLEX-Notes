import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/domain/calendar_layout.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/calendar_ics.dart';
import 'classroom_test.dart' show lesson, classroomMemory;
import 'material_workspace_test.dart' show material;

CalendarItem slot(
  String id,
  String start,
  String end, {
  String date = '2026-11-02',
  String category = 'lesson',
}) => CalendarItem(
  id: id,
  date: date,
  time: start,
  end: end,
  title: id,
  category: category,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('week headings distinguish month and year transitions', () {
    expect(
      calendarRangeLabel(DateTime(2026, 11, 9), DateTime(2026, 11, 15)),
      '9.–15. November 2026',
    );
    expect(
      calendarRangeLabel(DateTime(2026, 11, 30), DateTime(2026, 12, 6)),
      '30. November – 6. Dezember 2026',
    );
    expect(
      calendarRangeLabel(DateTime(2026, 12, 28), DateTime(2027, 1, 3)),
      '28. Dezember 2026 – 3. Januar 2027',
    );
  });
  test(
    'adjacent lessons use full width, overlaps receive deterministic lanes',
    () {
      final a = slot('a', '08:00', '08:50'),
          b = slot('b', '08:50', '09:40'),
          c = slot('c', '08:20', '08:45');
      final result = placeCalendarItems([b, c, a]);
      expect(result.map((p) => p.item.id), ['a', 'c', 'b']);
      expect(result.map((p) => p.columns), [2, 2, 1]);
      expect(result.map((p) => p.column), [0, 1, 0]);
      expect(result.first.start, 480);
      expect(result.first.finish, 530);
      expect(calendarClusters([a, b, c]).map((g) => g.length), [2, 1]);
    },
  );
  test('dense overlaps remain individually addressable in one cluster', () {
    final items = [for (var i = 0; i < 12; i++) slot('$i', '09:00', '09:50')];
    final cluster = calendarClusters(items).single;
    expect(cluster.map((p) => p.item.id).toSet().length, 12);
    expect(cluster.every((p) => p.columns == 12), isTrue);
  });
  test('point appointments keep their actual time without an invented end', () {
    final point = slot('call', '07:10', '', category: 'appointment');
    expect(placeCalendarItems([point]).single.finish, 460);
    expect(point.end, isEmpty);
    expect(calendarHours([point, slot('late', '17:30', '18:20')]), (
      start: 420,
      end: 1140,
    ));
    expect(calendarTimed(slot('task', '09:00', '', category: 'task')), isFalse);
    expect(calendarDue(slot('task', '', '', category: 'task')), isTrue);
  });
  test('now and next respect date, boundaries and explicit end times', () {
    final items = [
      slot('yesterday', '09:00', '10:00', date: '2026-11-01'),
      slot('one', '08:00', '08:50'),
      slot('two', '08:50', '09:40'),
      slot('call', '10:00', '', category: 'appointment'),
    ];
    expect(currentCalendarItem(items, DateTime(2026, 11, 2, 8, 50))?.id, 'two');
    expect(nextCalendarItem(items, DateTime(2026, 11, 2, 8, 50))?.id, 'call');
    expect(currentCalendarItem(items, DateTime(2026, 11, 2, 10, 1)), isNull);
    expect(nextCalendarItem(items, DateTime(2026, 11, 3)), isNull);
  });
  test(
    'one occurrence can override or clear files without changing next week',
    () {
      var doc = lesson(
        rule: const RepeatRule(frequency: 'weekly'),
        materials: ['template'],
      );
      doc = patchLessonOccurrence(doc, '2026-11-09', {
        'materialIds': ['specific'],
        'note': 'Plan',
      });
      final occurrences = lessonOccurrences([doc], '2026-11-02', '2026-11-16');
      expect(occurrences.map((l) => l.materialIds), [
        ['template'],
        ['specific'],
        ['template'],
      ]);
      doc = patchLessonOccurrence(doc, '2026-11-09', {
        'materialIds': <String>[],
      });
      expect(
        lessonOccurrences([doc], '2026-11-09', '2026-11-09').single.materialIds,
        isEmpty,
      );
      expect(doc.strings('materialIds'), ['template']);
    },
  );
  test('moving cancelling and restoring retain occurrence preparation', () {
    var doc = lesson(
      rule: const RepeatRule(frequency: 'weekly', until: '2026-11-09'),
    );
    doc = patchLessonOccurrence(doc, '2026-11-09', {
      'materialIds': ['file'],
      'planIds': ['plan'],
      'note': 'Behalten',
    });
    doc = patchLessonOccurrence(doc, '2026-11-09', {
      'movedTo': '2026-11-12',
      'start': '10:00',
      'end': '10:50',
    });
    doc = patchLessonOccurrence(doc, '2026-11-09', {'cancelled': true});
    expect(lessonOccurrences([doc], '2026-11-12', '2026-11-12'), isEmpty);
    doc = patchLessonOccurrence(doc, '2026-11-09', {'cancelled': false});
    final restored = lessonOccurrences(
      [doc],
      '2026-11-12',
      '2026-11-12',
    ).single;
    expect(restored.originalDate, '2026-11-09');
    expect(restored.materialIds, ['file']);
    expect(restored.planIds, ['plan']);
    expect(restored.note, 'Behalten');
    expect(restored.start, '10:00');
  });
  test('explicit planning overrides suppress inherited file suggestions', () {
    final file = material('Datei');
    var doc = lesson(rule: const RepeatRule(frequency: 'weekly'));
    final plan = ClassroomDocument.create(ClassroomKind.plan, 'Serienplan', {
      'lessonIds': [doc.id],
      'materialIds': [file.id],
      'date': '2026-11-02',
      'endDate': '2026-11-30',
    });
    doc = patchLessonOccurrence(doc, '2026-11-09', {'planIds': <String>[]});
    expect(suggestedMaterials([doc, plan, file], '2026-11-09'), isEmpty);
    expect(
      suggestedMaterials([doc, plan, file], '2026-11-16').map((m) => m.id),
      [file.id],
    );
  });
  test(
    'assigned planning follows the moved occurrence, independent of series',
    () {
      var doc = lesson(rule: const RepeatRule(frequency: 'weekly'));
      final file = material('Datei');
      final plan = ClassroomDocument.create(ClassroomKind.plan, 'Plan', {
        'materialIds': [file.id],
      });
      doc = patchLessonOccurrence(doc, '2026-11-09', {
        'planIds': [plan.id],
        'movedTo': '2026-11-11',
      });
      final docs = [doc, file, plan];
      expect(suggestedMaterials(docs, '2026-11-09'), isEmpty);
      expect(suggestedMaterials(docs, '2026-11-11').map((m) => m.id), [
        file.id,
      ]);
      expect(suggestedMaterials(docs, '2026-11-16'), isEmpty);
    },
  );
  test('invalid occurrence and malformed reference lists are rejected', () {
    final doc = lesson(rule: const RepeatRule(frequency: 'weekly'));
    expect(
      () => patchLessonOccurrence(doc, '2026-11-03', {'note': 'invalid'}),
      throwsA(isA<DomainError>()),
    );
    for (final ids in [
      <dynamic>['same', 'same'],
      <dynamic>[2],
      <dynamic>[''],
    ]) {
      expect(
        () => patchLessonOccurrence(doc, '2026-11-09', {'planIds': ids}),
        throwsA(isA<DomainError>()),
      );
    }
  });
  test(
    'nested references validate atomically and survive backup restore',
    () async {
      final repo = classroomMemory(), copy = classroomMemory();
      await repo.initialize();
      await copy.initialize();
      addTearDown(repo.close);
      addTearDown(copy.close);
      final file = material('Datei');
      final plan = ClassroomDocument.create(ClassroomKind.plan, 'Plan', {
        'materialIds': [file.id],
      });
      var doc = lesson(rule: const RepeatRule(frequency: 'weekly'));
      doc = patchLessonOccurrence(doc, '2026-11-09', {
        'materialIds': [file.id],
        'planIds': [plan.id],
      });
      await repo.saveClassroomDocuments([doc, plan, file]);
      await copy.restoreBackup(await repo.exportBackup());
      final saved = (await copy.classroomDocuments()).firstWhere(
        (d) => d.id == doc.id,
      );
      expect(saved.rows('exceptions'), doc.rows('exceptions'));
      final merged = classroomMemory();
      await merged.initialize();
      addTearDown(merged.close);
      await merged.applyBackupMerge(
        await merged.prepareBackupMerge(
          await repo.exportBackup(),
          catalogs: false,
        ),
        {},
      );
      expect(
        (await merged.classroomDocuments())
            .firstWhere((d) => d.id == doc.id)
            .rows('exceptions'),
        doc.rows('exceptions'),
      );

      await expectLater(
        copy.saveClassroomDocuments([
          plan.patch({'revision': 1, 'title': 'Rollback'}),
          patchLessonOccurrence(saved, '2026-11-09', {
            'materialIds': ['missing'],
          }),
        ]),
        throwsA(isA<DomainError>()),
      );
      expect(
        (await copy.classroomDocuments())
            .firstWhere((d) => d.id == plan.id)
            .title,
        'Plan',
      );
      await repo.saveClassroomDocument(
        file.patch({'revision': 1, 'deleted': true}),
      );
      await repo.validateClassroomReferences();
    },
  );
  test(
    'ICS refresh keeps local preparation and rejects an orphaned occurrence',
    () {
      final original = lesson(
        rule: const RepeatRule(frequency: 'weekly'),
        materials: ['file'],
      );
      final prepared = patchLessonOccurrence(original, '2026-11-09', {
        'planIds': ['plan'],
        'note': 'Vorbereitet',
      });
      final incoming = original.patch({
        'title': 'Neuer Stundenplan',
        'start': '09:00',
        'end': '09:50',
      });
      final merged = mergeImportedLesson(prepared, incoming);
      expect(merged.title, 'Neuer Stundenplan');
      expect(merged.strings('materialIds'), ['file']);
      expect(merged.rows('exceptions'), prepared.rows('exceptions'));
      expect(
        () => mergeImportedLesson(
          prepared,
          incoming.patch({'date': '2026-11-03'}),
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'stale atomic plan attachment rolls back plan and retains draft',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final source = await repo.saveClassroomDocument(lesson());
      final plan = ClassroomDocument.create(ClassroomKind.plan, 'Entwurf', {});
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: newId(),
          type: 'classroom',
          ownerId: plan.id,
          data: plan.toJson(),
          revision: 0,
          updatedAtUtc: utcNow(),
        ),
      );
      await repo.saveClassroomDocument(
        source.patch({'title': 'Inzwischen geändert'}),
      );
      await expectLater(
        repo.saveClassroomDocuments([
          plan,
          patchLessonOccurrence(source, '2026-11-02', {
            'planIds': [plan.id],
          }),
        ], draft: draft),
        throwsA(isA<StaleRevision>()),
      );
      expect(
        (await repo.classroomDocuments()).any((d) => d.id == plan.id),
        isFalse,
      );
      expect((await repo.dialogDrafts()).single.id, draft.id);
    },
  );
}
