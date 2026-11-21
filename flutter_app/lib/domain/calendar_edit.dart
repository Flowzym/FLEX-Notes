import 'calendar.dart';
import 'calendar_layout.dart';
import 'classroom.dart';
import 'models.dart';

/// A preview is independent of persisted objects until the finger is released.
/// Slots snap to 15 minutes, stay within one day and retain a real duration.
class CalendarEdit {
  const CalendarEdit(this.date, this.start, this.end);
  final String date;
  final int start, end;
  String get startTime => minuteClock(start);
  String get endTime => minuteClock(end);

  factory CalendarEdit.fromItem(CalendarItem item) {
    final start = clockMinutes(item.time);
    final end = validEndClock(item.end) ? clockMinutes(item.end) : start + 30;
    return CalendarEdit(item.date, start, end.clamp(start + 1, 1440));
  }

  CalendarEdit move({required int minutes, required String day}) {
    final duration = end - start;
    final next = ((start + minutes) / 15).round() * 15;
    final bounded = next.clamp(0, 1440 - duration);
    return CalendarEdit(day, bounded, bounded + duration);
  }

  CalendarEdit resize(int minutes, {required bool beginning}) {
    final next = (((beginning ? start : end) + minutes) / 15).round() * 15;
    return beginning
        ? CalendarEdit(
            date,
            next.clamp(0, end - (end - start).clamp(1, 15)),
            end,
          )
        : CalendarEdit(
            date,
            start,
            next.clamp(start + (end - start).clamp(1, 15), 1440),
          );
  }

  bool sameAs(CalendarEdit other) =>
      date == other.date && start == other.start && end == other.end;

  OrgaEntry applyToEntry(OrgaEntry entry) {
    if (!entry.isAppointment || entry.deleted) {
      throw const DomainError('Dieser Termin kann nicht verschoben werden.');
    }
    // A reminder tied to the appointment retains its distance from the start.
    final oldStart = DateTime.parse(
      '${entry.appointmentDate}T${entry.appointmentTime}:00',
    );
    final newStart = DateTime.parse('${date}T$startTime:00');
    return entry.copyWith(
      appointmentDate: date,
      appointmentTime: startTime,
      appointmentEndTime: endTime,
      reminderAtUtc:
          entry.reminderAtUtc == null ||
              entry.reminderState != ReminderState.planned
          ? entry.reminderAtUtc
          : DateTime.parse(
              entry.reminderAtUtc!,
            ).add(newStart.difference(oldStart)).toUtc().toIso8601String(),
    );
  }

  ClassroomDocument applyToLesson(LessonOccurrence lesson) =>
      patchLessonOccurrence(lesson.document, lesson.originalDate, {
        'movedTo': date,
        'start': startTime,
        'end': endTime,
      });
}
