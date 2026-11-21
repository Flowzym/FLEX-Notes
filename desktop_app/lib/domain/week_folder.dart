import 'core.dart';
import 'desktop_calendar.dart';

class WeekDayFolder {
  const WeekDayFolder(this.day, this.agenda, this.materials);
  final DateTime day;
  final List<CalendarItem> agenda;
  final List<ClassroomDocument> materials;
}

List<WeekDayFolder> buildWeekFolder(
  NotebookSnapshot snapshot,
  DateTime anchor,
) {
  final active = snapshot.active();
  final days = weekOf(anchor);
  final events = calendarItems(
    active,
    dateOnly(days.first),
    dateOnly(days.last),
  );
  final files = preparedMaterialsByDay(active.classroom);
  return [
    for (final day in days)
      WeekDayFolder(day, [
        for (final item in events)
          if (item.date == dateOnly(day)) item,
      ], files[dateOnly(day)] ?? []),
  ];
}

String materialDayOwners(
  ClassroomDocument file,
  String date,
  String Function(String?) name,
) {
  final owners = {
    for (final row in file.rows('pupilDates'))
      if (row['date'] == date) row['pupilId'] as String,
  };
  return owners.map(name).join(', ');
}
