import 'core.dart';

enum DeskEntryKind {
  task('Aufgaben', 'Aufgabe'),
  returns('Rückläufe', 'Rücklauf'),
  appointment('Termine', 'Termin'),
  note('Notizen', 'Notiz');

  const DeskEntryKind(this.plural, this.label);
  final String plural, label;
}

class DeskOrgaItem {
  DeskOrgaItem.fromEntry(OrgaEntry e, String owner)
    : target = e,
      kind = e.isAppointment
          ? DeskEntryKind.appointment
          : e.isTask
          ? DeskEntryKind.task
          : DeskEntryKind.note,
      date = e.appointmentDate ?? e.dueDate ?? (e.isTask ? '' : e.observedOn),
      complete = e.done,
      title = e.title,
      searchText = [
        e.title,
        e.body,
        owner,
        e.otherParticipants,
        ...e.tags,
        ...e.items.map((i) => i.text),
      ].join(' ').toLowerCase();
  DeskOrgaItem.fromReturn(ClassroomDocument r, String participants)
    : target = r,
      kind = DeskEntryKind.returns,
      date = r.text('dueDate'),
      complete = r.returnFinished,
      title = r.title,
      searchText = [
        r.title,
        r.text('note'),
        participants,
        r.text('otherParticipants'),
      ].join(' ').toLowerCase();
  final Object target;
  final DeskEntryKind kind;
  final bool complete;
  final String date, title, searchText;

  bool get actionable =>
      kind == DeskEntryKind.task || kind == DeskEntryKind.returns;
  bool overdue(String today) =>
      actionable && !complete && date.isNotEmpty && date.compareTo(today) < 0;

  bool matches(String type, String status, String query, String today) =>
      (type == 'Alle Arten' || type == kind.plural) &&
      (status == 'Alle' ||
          status == 'Überfällig' && overdue(today) ||
          status == 'Offen' && actionable && !complete ||
          status == 'Erledigt' && actionable && complete) &&
      query
          .toLowerCase()
          .trim()
          .split(RegExp(r'\s+'))
          .every(searchText.contains);
}

List<DeskOrgaItem> deskOrganization(
  NotebookController c, {
  required String type,
  required String status,
  required String query,
  required String today,
}) {
  final people = {for (final p in c.pupils) p.id: p.name};
  final rows = [
    for (final e in c.entries)
      if (!e.deleted) DeskOrgaItem.fromEntry(e, c.owner(e)),
    for (final r in c.classroom)
      if (!r.deleted && r.kind == ClassroomKind.returnList)
        DeskOrgaItem.fromReturn(
          r,
          r
              .rows('participants')
              .map(
                (row) => [
                  row['name'],
                  people[row['pupilId']],
                  row['note'],
                ].nonNulls.join(' '),
              )
              .join(' '),
        ),
  ].where((row) => row.matches(type, status, query, today)).toList();
  rows.sort((a, b) {
    if (a.overdue(today) != b.overdue(today)) return a.overdue(today) ? -1 : 1;
    if (a.complete != b.complete) return a.complete ? 1 : -1;
    final date = (a.date.isEmpty ? '9999' : a.date).compareTo(
      b.date.isEmpty ? '9999' : b.date,
    );
    return date == 0
        ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
        : date;
  });
  return rows;
}
