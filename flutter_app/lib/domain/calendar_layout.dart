import 'dart:math' as math;
import 'calendar.dart';
import 'classroom.dart';
import 'models.dart';

int clockMinutes(String clock) =>
    int.parse(clock.substring(0, 2)) * 60 + int.parse(clock.substring(3, 5));
String minuteClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
bool calendarTimed(CalendarItem item) =>
    validClock(item.time) &&
    (item.category == 'lesson' || item.category == 'appointment');
bool calendarDue(CalendarItem item) =>
    const {'task', 'homework', 'goal', 'return'}.contains(item.category);

class CalendarPlacement {
  const CalendarPlacement(
    this.item,
    this.start,
    this.finish,
    this.column,
    this.columns,
    this.cluster,
  );
  final CalendarItem item;

  /// Logical layout minutes; point appointments get a touch-sized display slot,
  /// never an invented end time in labels.
  final int start, finish, column, columns, cluster;
}

/// Interval colouring per connected overlap group. Back-to-back lessons can
/// occupy the full width. Input order cannot change the chosen lanes.
List<CalendarPlacement> placeCalendarItems(
  Iterable<CalendarItem> items, {
  int minimumMinutes = 30,
}) {
  final sorted = items.where(calendarTimed).toList()
    ..sort((a, b) {
      final start = a.time.compareTo(b.time);
      if (start != 0) return start;
      final end = b.end.compareTo(a.end);
      return end != 0 ? end : a.id.compareTo(b.id);
    });
  final result = <CalendarPlacement>[];
  final group = <({CalendarItem item, int start, int end, int lane})>[];
  final laneEnds = <int>[];
  var groupEnd = -1;
  void flush() {
    for (final p in group) {
      result.add(
        CalendarPlacement(
          p.item,
          p.start,
          p.end,
          p.lane,
          laneEnds.length,
          group.first.start,
        ),
      );
    }
    group.clear();
    laneEnds.clear();
    groupEnd = -1;
  }

  for (final item in sorted) {
    final start = clockMinutes(item.time);
    final end = math.max(
      validClock(item.end) ? clockMinutes(item.end) : start,
      start + minimumMinutes,
    );
    if (group.isNotEmpty && start >= groupEnd) flush();
    var lane = laneEnds.indexWhere((end) => end <= start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(end);
    } else {
      laneEnds[lane] = end;
    }
    group.add((item: item, start: start, end: end, lane: lane));
    groupEnd = math.max(groupEnd, end);
  }
  flush();
  return result;
}

({int start, int end}) calendarHours(
  Iterable<CalendarItem> items, {
  int minimumMinutes = 30,
}) {
  var start = 8 * 60, end = 14 * 60;
  for (final item in items.where(calendarTimed)) {
    final time = clockMinutes(item.time);
    start = math.min(start, (time ~/ 60) * 60);
    end = math.max(
      end,
      ((math.max(
                    validClock(item.end) ? clockMinutes(item.end) : time,
                    time + minimumMinutes,
                  ) +
                  59) ~/
              60) *
          60,
    );
  }
  return (start: start, end: end);
}

CalendarItem? currentCalendarItem(Iterable<CalendarItem> items, DateTime now) {
  final date = dateOnly(now), minutes = now.hour * 60 + now.minute;
  return items
      .where(
        (i) =>
            i.date == date &&
            calendarTimed(i) &&
            !i.done &&
            validClock(i.end) &&
            clockMinutes(i.time) <= minutes &&
            clockMinutes(i.end) > minutes,
      )
      .firstOrNull;
}

CalendarItem? nextCalendarItem(Iterable<CalendarItem> items, DateTime now) {
  final future =
      items
          .where(
            (i) =>
                i.date == dateOnly(now) &&
                calendarTimed(i) &&
                !i.done &&
                clockMinutes(i.time) > now.hour * 60 + now.minute,
          )
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
  return future.firstOrNull;
}

String calendarWeekday(DateTime day, {bool short = false}) => (short
    ? const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
    : const [
        'Montag',
        'Dienstag',
        'Mittwoch',
        'Donnerstag',
        'Freitag',
        'Samstag',
        'Sonntag',
      ])[day.weekday - 1];
String calendarMonth(DateTime day) => const [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
][day.month - 1];

List<List<CalendarPlacement>> calendarClusters(
  Iterable<CalendarItem> items, {
  int minimumMinutes = 30,
}) {
  final groups = <int, List<CalendarPlacement>>{};
  for (final p in placeCalendarItems(items, minimumMinutes: minimumMinutes)) {
    groups.putIfAbsent(p.cluster, () => []).add(p);
  }
  return groups.values.toList();
}
