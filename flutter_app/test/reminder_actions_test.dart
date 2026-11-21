import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/reminder_action.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/services/reminders.dart';
import 'classroom_test.dart' show classroomMemory;

void main() {
  test(
    'notification task completion is revision checked and duplicate safe',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final entry = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Abgeben',
          isTask: true,
          body: 'Abgeben',
          dueDate: '2026-11-20',
        ),
      );
      final now = DateTime(2026, 11, 19, 9);
      final request = planReminders(await repo.snapshot(), {}, now).single;
      expect(request.completable, true);
      final action = ReminderAction.parse(
        ReminderAction.response(request.payload, 'done'),
      )!;
      expect(action.target, 'orga:${entry.id}');
      expect(await repo.applyReminderAction(action, now), true);
      expect((await repo.entries()).single.done, true);
      expect(await repo.applyReminderAction(action, now), false);
    },
  );
  test(
    'stale notification cannot change task and snooze retains due date',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      var entry = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Abgeben',
          isTask: true,
          body: 'Abgeben',
          dueDate: '2026-11-20',
        ),
      );
      final now = DateTime(2026, 11, 19, 9);
      final old = planReminders(await repo.snapshot(), {}, now).single;
      entry = await repo.saveEntry(entry.copyWith(body: 'Geändert'));
      await expectLater(
        repo.applyReminderAction(
          ReminderAction.parse(ReminderAction.response(old.payload, 'done'))!,
          now,
        ),
        throwsA(isA<DomainError>()),
      );
      final request = planReminders(await repo.snapshot(), {}, now).single;
      final action = ReminderAction.parse(
        ReminderAction.response(request.payload, 'snooze'),
      )!;
      await repo.applyReminderAction(action, now);
      expect((await repo.entries()).single.dueDate, '2026-11-20');
      final snooze = (await repo.classroomDocuments()).singleWhere(
        (d) => d.kind == ClassroomKind.reminder,
      );
      expect(
        DateTime.parse(snooze.text('at')),
        now.add(const Duration(hours: 1)).toUtc(),
      );
      expect(
        await repo.applyReminderAction(
          action,
          now.add(const Duration(minutes: 10)),
        ),
        false,
      );
      expect(
        planReminders(await repo.snapshot(), {}, now).single.when,
        now.add(const Duration(hours: 1)).toUtc(),
      );
    },
  );
  test('invalid payloads and missing targets are rejected', () async {
    expect(ReminderAction.parse('{"v":1,"action":"erase"}'), isNull);
    expect(ReminderAction.response('orga:legacy', 'done'), 'orga:legacy');
    final repo = classroomMemory();
    await repo.initialize();
    addTearDown(repo.close);
    await expectLater(
      repo.applyReminderAction(
        const ReminderAction(
          target: 'orga:missing',
          revision: 1,
          scheduledAt: '2026-11-19T10:00:00Z',
          action: 'done',
        ),
        DateTime(2026),
      ),
      throwsA(isA<DomainError>()),
    );
  });

  test(
    'notification cannot override a reminder manually postponed or dismissed',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final entry = await repo.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Aufgabe',
          body: 'Aufgabe',
          isTask: true,
          dueDate: '2026-11-20',
        ),
      );
      final now = DateTime(2026, 11, 19, 9);
      final original = planReminders(await repo.snapshot(), {}, now).single;
      var override = await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.reminder, 'Erinnerung', {
          'target': 'orga:${entry.id}',
          'at': now.add(const Duration(days: 2)).toUtc().toIso8601String(),
          'dismissed': false,
        }),
      );
      await expectLater(
        repo.applyReminderAction(
          ReminderAction.parse(
            ReminderAction.response(original.payload, 'done'),
          )!,
          now,
        ),
        throwsA(isA<DomainError>()),
      );
      final updated = planReminders(await repo.snapshot(), {}, now).single;
      override = await repo.saveClassroomDocument(
        override.patch({'dismissed': true}),
      );
      await expectLater(
        repo.applyReminderAction(
          ReminderAction.parse(
            ReminderAction.response(updated.payload, 'snooze'),
          )!,
          now,
        ),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.entries()).single.done, false);
      expect(
        (await repo.classroomDocuments()).single.revision,
        override.revision,
      );
    },
  );
}
