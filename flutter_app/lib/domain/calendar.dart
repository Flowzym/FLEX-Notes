import 'classroom.dart';
import 'models.dart';
import 'repository.dart';
import 'school.dart';

class CalendarItem {
  const CalendarItem({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    this.time = '',
    this.end = '',
    this.detail = '',
    this.done = false,
    this.lesson,
    this.document,
    this.entry,
    this.record,
  });
  final String id, date, time, end, title, category, detail;
  final bool done;
  final LessonOccurrence? lesson;
  final ClassroomDocument? document;
  final OrgaEntry? entry;
  final SchoolRecord? record;
}

List<CalendarItem> calendarItems(
  NotebookSnapshot data,
  String from,
  String to,
) {
  final first = schoolDay(from), last = schoolDay(to);
  if (last.isBefore(first) || last.difference(first).inDays > 740) {
    throw const DomainError('Bitte einen Zeitraum bis zu zwei Jahren wählen.');
  }
  final active = data.pupils.where((p) => !p.archived).map((p) => p.id).toSet();
  bool within(String? d) =>
      d != null && d.compareTo(from) >= 0 && d.compareTo(to) <= 0;
  final result = <CalendarItem>[
    for (final l in lessonOccurrences(data.classroom, from, to))
      CalendarItem(
        id: l.target,
        date: l.date,
        time: l.start,
        end: l.end,
        title: l.title,
        category: 'lesson',
        detail: [
          l.document.text('subject'),
          l.document.text('teacher'),
          l.document.text('room'),
          for (final p in data.pupils)
            if (l.document.strings('pupilIds').contains(p.id)) p.name,
          l.document.text('otherParticipants'),
        ].where((s) => s.isNotEmpty).join(' · '),
        lesson: l,
        document: l.document,
      ),
    for (final e in data.entries.where(
      (e) => !e.deleted && (e.pupilId == null || active.contains(e.pupilId)),
    ))
      if (within(e.appointmentDate ?? e.dueDate))
        CalendarItem(
          id: 'orga:${e.id}',
          date: (e.appointmentDate ?? e.dueDate)!,
          time: e.appointmentTime,
          title: e.title,
          category: e.isAppointment ? 'appointment' : 'task',
          done: e.done,
          entry: e,
          detail: [
            if (e.pupilId != null)
              data.pupils.firstWhere((p) => p.id == e.pupilId).name,
            if (e.otherParticipants.trim().isNotEmpty)
              e.otherParticipants.trim(),
            if (e.pupilId == null && e.otherParticipants.trim().isEmpty)
              'FLEX-Klasse',
          ].join(' · '),
        ),
    for (final r in data.records.where(
      (r) => !r.deleted && active.contains(r.pupilId),
    ))
      if (r.kind == SchoolKind.homework && within(r.dueDate) ||
          r.kind == SchoolKind.goal &&
              r.goalStatus == 'active' &&
              within(r.nextReviewDate))
        CalendarItem(
          id: 'school:${r.id}',
          date: (r.kind == SchoolKind.goal ? r.nextReviewDate : r.dueDate)!,
          title: r.title.isEmpty ? r.kind.label : r.title,
          category: r.kind == SchoolKind.goal ? 'goal' : 'homework',
          done: !r.pending,
          record: r,
          detail: data.pupils.firstWhere((p) => p.id == r.pupilId).name,
        ),
    for (final d in data.classroom.where(
      (d) =>
          !d.deleted &&
          d.kind == ClassroomKind.returnList &&
          within(d.text('dueDate')),
    ))
      CalendarItem(
        id: 'return:${d.id}',
        date: d.text('dueDate'),
        title: d.title,
        category: 'return',
        document: d,
        done: d.flag('closed') || !d.rows('participants').any(returnPending),
        detail:
            '${d.rows('participants').where(returnPending).length} Rückmeldungen offen',
      ),
  ];
  for (final h in data.classroom.where(
    (d) => !d.deleted && d.kind == ClassroomKind.holiday,
  )) {
    var d = schoolDay(h.text('date'));
    if (d.isBefore(first)) d = first;
    final end = schoolDay(h.text('endDate'));
    for (
      ;
      !d.isAfter(last) && !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    ) {
      result.add(
        CalendarItem(
          id: 'holiday:${h.id}:${dateOnly(d)}',
          date: dateOnly(d),
          title: h.title,
          category: 'holiday',
          document: h,
        ),
      );
    }
  }
  result.sort(
    (a, b) =>
        '${a.date} ${a.time} ${a.id}'.compareTo('${b.date} ${b.time} ${b.id}'),
  );
  return result;
}

const calendarCategories = {
  'lesson': 'Unterricht',
  'appointment': 'Termine',
  'task': 'Aufgaben',
  'homework': 'HÜ',
  'goal': 'Ziele',
  'return': 'Rückläufe',
  'holiday': 'Ferien',
};
