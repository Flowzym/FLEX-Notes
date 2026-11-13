import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'classroom_test.dart' show classroomMemory;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test(
    'individual progress, duration and carry never mutate another pupil or shared flow',
    () {
      final shared = withLessonPhases(lessonFlowFor([], '2026-11-13'), [
        const LessonPhase(id: 'shared', title: 'Lesen', minutes: 20),
        const LessonPhase(
          id: 'ben',
          title: 'Zusatz',
          minutes: 10,
          pupilIds: ['ben'],
        ),
      ]);
      final anna = lessonFlowFor([shared], '2026-11-13', pupilId: 'anna');
      final ben = lessonFlowFor([shared], '2026-11-13', pupilId: 'ben');
      expect(lessonPhases(anna).length, 1);
      expect(lessonPhases(ben).length, 2);
      expect({anna.id, ben.id, shared.id}.length, 3);
      final modified = withLessonPhases(anna, [
        lessonPhases(anna).first.patch({'minutes': 35}),
      ]);
      final running = activateLessonPhase(
        modified,
        lessonPhases(modified).first.id,
        DateTime.utc(2026, 11, 13, 8),
      );
      expect(lessonPhases(running).first.minutes, 35);
      expect(lessonPhases(shared).first.minutes, 20);
      expect(lessonPhases(ben).every((p) => !p.running), true);
      final lookup = lessonFlowFor(
        [shared, running, ben],
        '2026-11-13',
        pupilId: 'anna',
      );
      expect(lookup.toJson(), running.toJson());
      expect(lessonFlowPupil(flowTemplate(running, 'Vorlage')), '');
      expect(
        () => carryLessonPhases(
          running,
          lessonFlowFor([], '2026-11-14', pupilId: 'ben'),
          DateTime.now(),
        ),
        throwsA(isA<DomainError>()),
      );
      final carry = carryLessonPhases(
        running,
        withLessonPhases(lessonFlowFor([], '2026-11-14', pupilId: 'anna'), []),
        DateTime.now(),
      );
      expect(lessonFlowPupil(carry.last), 'anna');
      expect(lessonPhases(carry.last).single.minutes, 35);
      expect(lessonPhases(carry.last).single.running, false);
    },
  );
  test(
    'individual ownership and calendar preference round-trip through backup and pupil merge',
    () async {
      final source = classroomMemory(),
          target = classroomMemory(),
          restored = classroomMemory();
      await source.initialize();
      await target.initialize();
      await restored.initialize();
      addTearDown(source.close);
      addTearDown(target.close);
      addTearDown(restored.close);
      await source.savePupil(const Pupil(id: 'remote', name: 'Anna'));
      await source.saveClassroomDocument(
        lessonFlowFor([], '2026-11-13', pupilId: 'remote'),
      );
      await source.saveAppearance(
        const Appearance(calendarDefaultView: 'week'),
      );
      final backup = await source.exportBackup();
      await restored.restoreBackup(backup);
      expect((await restored.appearance()).calendarDefaultView, 'week');
      expect(
        lessonFlowPupil((await restored.classroomDocuments()).single),
        'remote',
      );
      await target.savePupil(const Pupil(id: 'local', name: 'Anna'));
      final merge = await target.prepareBackupMerge(
        backup,
        pupilLinks: {'remote': 'local'},
      );
      await target.applyBackupMerge(merge, {});
      expect(
        lessonFlowPupil((await target.classroomDocuments()).single),
        'local',
      );
      await expectLater(
        source.saveClassroomDocument(
          lessonFlowFor([], '2026-11-14', pupilId: 'missing'),
        ),
        throwsA(isA<DomainError>()),
      );
      expect((await source.classroomDocuments()).length, 1);
      expect(Appearance.fromJson({}).calendarDefaultView, 'day');
      expect(
        () => const Appearance().patch({'calendarDefaultView': 'invalid'}),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'subtasks retain IDs, complete their parent and reopen it on a new open item',
    () {
      final task = OrgaEntry.empty().copyWith(
        isTask: true,
        items: [
          const CheckItem(id: 'a', text: 'Kopieren'),
          const CheckItem(id: 'b', text: 'Verteilen'),
        ],
      );
      final partial = task.withTaskItems([
        task.items.first.copyWith(checked: true),
        task.items.last,
      ]);
      expect(partial.done, false);
      final complete = partial.withTaskItems(
        partial.items.map((i) => i.copyWith(checked: true)).toList(),
      );
      expect(complete.done, true);
      final reopened = complete.withTaskItems([
        ...complete.items,
        const CheckItem(id: 'c', text: 'Einsammeln'),
      ]);
      expect(reopened.done, false);
      expect(reopened.items.take(2).every((i) => i.checked), true);
      expect(OrgaEntry.fromJson(reopened.toJson()).items.map((i) => i.id), [
        'a',
        'b',
        'c',
      ]);
      expect(task.complete().items.every((i) => i.checked), true);
    },
  );
}
