import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/homework_control.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'classroom_test.dart' show classroomMemory, lesson;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final now = DateTime.utc(2026, 11, 13, 8);
  test(
    'a removed calendar block keeps its saved flow; deleting a flow allows a fresh one',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      const target = 'lesson:old-block:2026-11-13';
      final saved = await repo.saveClassroomDocument(
        lessonFlowFor([], '2026-11-13', lessonTarget: target),
      );
      expect(
        lessonFlowFor([saved], '2026-11-13', lessonTarget: target).id,
        saved.id,
      );
      final deleted = await repo.saveClassroomDocument(
        saved.patch({'deleted': true}),
      );
      final fresh = lessonFlowFor(
        [deleted],
        '2026-11-13',
        lessonTarget: target,
      );
      expect(fresh.id, isNot(saved.id));
      await repo.saveClassroomDocument(fresh);
      expect(
        (await repo.classroomDocuments()).where((d) => !d.deleted).length,
        1,
      );
    },
  );
  test(
    'a changed carry destination rolls back the source write in the same transaction',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final source = await repo.saveClassroomDocument(
        lessonFlowFor([], '2026-11-13'),
      );
      final target = await repo.saveClassroomDocument(
        lessonFlowFor([], '2026-11-16'),
      );
      final transfer = carryLessonPhases(source, target, now);
      await repo.saveClassroomDocument(
        target.patch({'title': 'Inzwischen geändert'}),
      );
      final before = (jsonDecode(await repo.exportBackup()) as Map)['tables'];
      await expectLater(
        repo.saveClassroomDocuments(transfer),
        throwsA(isA<StaleRevision>()),
      );
      expect((jsonDecode(await repo.exportBackup()) as Map)['tables'], before);
    },
  );
  test(
    'days and lesson occurrences have independent progress; reading creates no stored data',
    () {
      final l = lesson(
        date: '2026-11-13',
        rule: const RepeatRule(frequency: 'daily'),
      );
      final days = lessonOccurrences([l], '2026-11-13', '2026-11-14');
      final first = lessonFlowFor([], '2026-11-13', lesson: days.first);
      final second = lessonFlowFor([], '2026-11-14', lesson: days.last);
      expect(first.id, isNot(second.id));
      expect(lessonFlowFor([], '2026-11-13', lesson: days.first).id, first.id);
      expect(lessonFlowFor([], '2026-11-13').id, isNot(first.id));
      final saved = activateLessonPhase(
        first,
        lessonPhases(first).first.id,
        now,
      );
      expect(
        lessonPhases(
          lessonFlowFor([saved], '2026-11-13', lesson: days.first),
        ).first.running,
        isTrue,
      );
      expect(lessonPhases(second).every((p) => p.status == 'open'), isTrue);
    },
  );
  test(
    'pause and resume count elapsed time once; templates strip all runtime progress',
    () {
      var d = lessonFlowFor([], '2026-11-13');
      final id = lessonPhases(d).first.id;
      d = activateLessonPhase(d, id, now);
      final paused = lessonPhases(
        d,
      ).first.pause(now.add(const Duration(seconds: 35)));
      d = withLessonPhases(d, [paused, ...lessonPhases(d).skip(1)]);
      expect(paused.elapsedAt(now.add(const Duration(minutes: 4))), 35);
      d = activateLessonPhase(d, id, now.add(const Duration(minutes: 5)));
      expect(
        lessonPhases(d).first.elapsedAt(now.add(const Duration(minutes: 6))),
        95,
      );
      final template = flowTemplate(d, 'Mein Ablauf');
      expect(isFlowTemplate(template), isTrue);
      expect(
        lessonPhases(
          template,
        ).every((p) => p.status == 'open' && !p.running && p.elapsed == 0),
        isTrue,
      );
      expect(lessonPhases(template).first.id, isNot(id));
      expect(lessonPhases(d).first.running, isTrue);
    },
  );
  test(
    'completing and skipping progress explicitly; activating another phase pauses the old one',
    () {
      var d = lessonFlowFor([], '2026-11-13');
      final phases = lessonPhases(d);
      d = activateLessonPhase(d, phases[0].id, now);
      d = activateLessonPhase(
        d,
        phases[2].id,
        now.add(const Duration(minutes: 3)),
      );
      expect(lessonPhases(d)[0].elapsed, 180);
      expect(lessonPhases(d).where((p) => p.running).length, 1);
      d = finishLessonPhase(
        d,
        phases[2].id,
        now.add(const Duration(minutes: 4)),
        skip: true,
      );
      expect(lessonPhases(d)[2].status, 'skipped');
      expect(lessonPhases(d)[0].status, 'active');
      d = finishLessonPhase(
        d,
        phases[0].id,
        now.add(const Duration(minutes: 5)),
      );
      expect(lessonPhases(d)[0].status, 'done');
      expect(lessonPhases(d)[1].kind, 'homework');
      expect(lessonPhases(d)[1].status, 'active');
    },
  );
  test('validation rejects malformed, ambiguous or running template data', () {
    final d = lessonFlowFor([], '2026-11-13');
    final phases = lessonPhases(d);
    for (final changes in <Json>[
      {'minutes': -1},
      {'minutes': 601},
      {'title': ''},
      {'status': 'unknown'},
      {'startedAt': now.toIso8601String()},
      {
        'materialIds': ['a', 'a'],
      },
      {'body': 1},
    ]) {
      expect(() => phases.first.patch(changes), throwsA(isA<DomainError>()));
    }
    expect(
      () => withLessonPhases(d, [phases.first, phases.first]),
      throwsA(isA<DomainError>()),
    );
    expect(
      () => withLessonPhases(
        d,
        phases.map((p) => p.patch({'status': 'active'})).toList(),
      ),
      throwsA(isA<DomainError>()),
    );
    expect(
      () => d.patch({
        'flow': {...d.map('flow'), 'unknown': true},
      }),
      throwsA(isA<DomainError>()),
    );
    expect(() => d.patch({'date': ''}), throwsA(isA<DomainError>()));
  });
  test(
    'carry forward is atomic, preserves target phases and cannot duplicate completed transfers',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final source = await repo.saveClassroomDocument(
        lessonFlowFor([], '2026-11-13'),
      );
      final target = await repo.saveClassroomDocument(
        withLessonPhases(lessonFlowFor([], '2026-11-16'), [
          LessonPhase(id: 'existing', title: 'Bereits geplant'),
        ]),
      );
      final changed = carryLessonPhases(source, target, now);
      await repo.saveClassroomDocuments(changed);
      final docs = await repo.classroomDocuments();
      final from = docs.singleWhere((d) => d.id == source.id),
          to = docs.singleWhere((d) => d.id == target.id);
      expect(lessonPhases(to).first.title, 'Bereits geplant');
      expect(lessonPhases(to).length, 6);
      expect(
        lessonPhases(
          from,
        ).every((p) => p.status == 'skipped' && p.carriedTo == '2026-11-16'),
        isTrue,
      );
      expect(
        () => carryLessonPhases(from, to, now),
        throwsA(isA<DomainError>()),
      );
      final stale = carryLessonPhases(source, target, now);
      final before = (jsonDecode(await repo.exportBackup()) as Map)['tables'];
      await expectLater(
        repo.saveClassroomDocuments(stale),
        throwsA(isA<StaleRevision>()),
      );
      expect((jsonDecode(await repo.exportBackup()) as Map)['tables'], before);
    },
  );
  test(
    'phase references and progress survive backup, restore and pupil mapping; invalid links rollback',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      await repo.savePupil(const Pupil(id: 'remote', name: 'Marek'));
      final material = await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Brüche', {
          'url': 'https://example.org/test.pdf',
          'extension': 'pdf',
        }),
      );
      var d = withLessonPhases(lessonFlowFor([], '2026-11-13'), [
        LessonPhase(
          id: 'phase',
          title: 'Arbeit',
          materialIds: [material.id],
          pupilIds: ['remote'],
        ),
      ]);
      d = activateLessonPhase(d, 'phase', now);
      d = await repo.saveClassroomDocument(d);
      final copy = classroomMemory();
      await copy.initialize();
      addTearDown(copy.close);
      await copy.restoreBackup(await repo.exportBackup());
      expect(
        lessonPhases(
          (await copy.classroomDocuments()).singleWhere(hasLessonFlow),
        ).first.toJson(),
        lessonPhases(d).first.toJson(),
      );
      final merged = classroomMemory();
      await merged.initialize();
      addTearDown(merged.close);
      await merged.savePupil(const Pupil(id: 'local', name: 'Marek'));
      final merge = await merged.prepareBackupMerge(
        await repo.exportBackup(),
        pupilLinks: {'remote': 'local'},
      );
      await merged.applyBackupMerge(merge, {});
      expect(
        lessonPhases(
          (await merged.classroomDocuments()).singleWhere(hasLessonFlow),
        ).first.pupilIds,
        ['local'],
      );
      await expectLater(
        repo.saveClassroomDocument(
          withLessonPhases(d, [
            lessonPhases(d).first.patch({
              'materialIds': ['missing'],
            }),
          ]),
        ),
        throwsA(isA<DomainError>()),
      );
      expect(
        lessonPhases(
          (await repo.classroomDocuments()).singleWhere(hasLessonFlow),
        ).first.materialIds,
        [material.id],
      );
    },
  );
  test(
    'homework control appends feedback, retains siblings and notes and rejects later-dated feedback',
    () {
      final r = SchoolRecord.empty(SchoolKind.homework, 'p').patch({
        'tasks': [
          const HomeworkTask(id: 'a', text: 'Brüche').toJson(),
          const HomeworkTask(
            id: 'b',
            text: 'Zusatz',
            parentId: 'a',
            initialState: TaskState.partial,
          ).toJson(),
        ],
        'feedback': [
          SchoolFeedback(
            id: 'note',
            observedOn: '2026-11-12',
            createdAtUtc: now.toIso8601String(),
            note: 'Bitte nachfragen',
          ).toJson(),
        ],
      });
      final checked = reviewHomeworkTask(r, 'a', TaskState.complete, now);
      expect(checked.feedback.length, 2);
      expect(checked.feedback.first.note, 'Bitte nachfragen');
      expect(checked.taskState(checked.tasks[1]), TaskState.partial);
      expect(checked.taskState(checked.tasks[0]), TaskState.complete);
      expect(
        identical(
          reviewHomeworkTask(checked, 'a', TaskState.complete, now),
          checked,
        ),
        isTrue,
      );
      expect(
        () => reviewHomeworkTask(
          checked,
          'a',
          TaskState.missing,
          now.subtract(const Duration(days: 1)),
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );
}
