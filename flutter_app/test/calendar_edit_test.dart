import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/calendar.dart';
import 'package:flex_notizbuch/domain/calendar_edit.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'classroom_test.dart' show classroomMemory;

void main() {
  test('snap and bounds preserve duration, including the end of the day', () {
    final original = CalendarEdit.fromItem(
      const CalendarItem(
        id: 'a',
        date: '2026-11-09',
        title: 'Termin',
        category: 'appointment',
        time: '09:00',
        end: '10:00',
      ),
    );
    final moved = original.move(minutes: 22, day: '2026-11-10');
    expect(moved.startTime, '09:15');
    expect(moved.endTime, '10:15');
    expect(original.move(minutes: 2000, day: original.date).endTime, '24:00');
    expect(original.resize(-900, beginning: false).endTime, '09:15');
    expect(original.resize(900, beginning: true).startTime, '09:45');
  });

  test('end time survives drafts, persistence and backup roundtrip', () async {
    final repo = classroomMemory();
    await repo.initialize();
    addTearDown(repo.close);
    final entry = await repo.saveEntry(
      OrgaEntry.empty().copyWith(
        title: 'Besprechung',
        appointmentDate: '2026-11-09',
        appointmentTime: '23:00',
        appointmentEndTime: '24:00',
      ),
    );
    final scratch = const OrgaTypeDraft().remember(entry);
    final note = scratch.select(entry, 'note');
    expect(note.appointmentEndTime, '');
    expect(
      OrgaTypeDraft.fromJson(
        scratch.toJson(),
      ).select(note, 'appointment').appointmentEndTime,
      '24:00',
    );
    expect(OrgaEntry.fromJson(entry.toJson()).appointmentEndTime, '24:00');
    final backup = await repo.exportBackup();
    final restored = classroomMemory();
    await restored.initialize();
    addTearDown(restored.close);
    await restored.restoreBackup(backup);
    expect((await restored.entries()).single.appointmentEndTime, '24:00');
  });

  test(
    'moving a lesson changes only the occurrence and retains its material links',
    () {
      final lesson = ClassroomDocument.create(
        ClassroomKind.lesson,
        'Englisch',
        {
          'date': '2026-11-09',
          'start': '09:00',
          'end': '10:00',
          'repeat': const RepeatRule(frequency: 'weekly').toJson(),
          'materialIds': ['worksheet'],
        },
      );
      final occurrence = lessonOccurrences(
        [lesson],
        '2026-11-09',
        '2026-11-16',
      ).first;
      final moved = const CalendarEdit(
        '2026-11-10',
        630,
        690,
      ).applyToLesson(occurrence);
      final times = lessonOccurrences([moved], '2026-11-09', '2026-11-16');
      expect(times.map((l) => l.date), ['2026-11-10', '2026-11-16']);
      expect(times.first.start, '10:30');
      expect(times.last.start, '09:00');
      expect(times.first.materialIds, ['worksheet']);
    },
  );
}
