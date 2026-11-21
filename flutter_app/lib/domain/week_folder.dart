import 'calendar.dart';
import 'classroom.dart';
import 'material_workspace.dart';
import 'models.dart';
import 'repository.dart';
import 'teaching_sheet.dart';

DateTime offsetDay(DateTime d, int delta) =>
    DateTime(d.year, d.month, d.day + delta);

class WeekDayFolder {
  const WeekDayFolder(this.day, this.agenda, this.materials, this.focus);
  final DateTime day;
  final List<CalendarItem> agenda;
  final List<ClassroomDocument> materials;
  final List<({ClassroomDocument source, List<String> lines})> focus;
}

List<WeekDayFolder> buildWeekFolder(
  NotebookSnapshot snapshot,
  DateTime anchor, {
  bool weekends = false,
}) {
  final active = snapshot.active();
  final monday = offsetDay(anchor, 1 - anchor.weekday);
  final days = List.generate(weekends ? 7 : 5, (i) => offsetDay(monday, i));
  final events = calendarItems(active, dateOnly(monday), dateOnly(days.last));
  final files = preparedMaterialsByDay(active.classroom);
  final sources = teachingSources(
    active.classroom,
    dateOnly(monday),
    week: true,
  );
  return [
    for (final day in days)
      WeekDayFolder(
        day,
        events.where((e) => e.date == dateOnly(day)).toList(),
        files[dateOnly(day)] ?? [],
        [
          for (final m in sources)
            if (weeklyContext(m, dateOnly(day)) case final rows
                when rows.isNotEmpty)
              (
                source: m,
                lines: [
                  for (final row in rows)
                    [
                      sheetText(
                        row,
                        row['type'] == 'week' ? 'task' : 'subject',
                      ),
                      sheetText(row, row['type'] == 'week' ? 'prep' : 'goal'),
                    ].where((s) => s.isNotEmpty).join(' · '),
                ],
              ),
        ],
      ),
  ];
}

String materialDayOwners(
  ClassroomDocument file,
  String date,
  String Function(String?) name,
) {
  return materialOwnerIds(
    file,
    day: date,
  ).map(name).where((s) => s.isNotEmpty).join(', ');
}
