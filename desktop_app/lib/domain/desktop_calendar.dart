import 'core.dart';

/// Date navigation uses civil days so a clock change cannot repeat a weekday.
DateTime calendarDay(DateTime anchor, int offset) =>
    DateTime(anchor.year, anchor.month, anchor.day + offset);

List<DateTime> weekOf(DateTime date) => [
  for (var n = 1; n <= 7; n++) calendarDay(date, n - date.weekday),
];

int clockMinutes(String time) {
  final parts = time.split(':');
  return parts.length == 2
      ? (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0)
      : 0;
}

int calendarEnd(CalendarItem item) => item.end.isEmpty
    ? (clockMinutes(item.time) + 45).clamp(0, 1440)
    : clockMinutes(item.end);

String minutesClock(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

/// Only appointments in the same overlapping time span share horizontal space.
List<({CalendarItem item, int lane, int columns})> calendarLanes(
  Iterable<CalendarItem> items,
) {
  final sorted = items.where((item) => item.time.isNotEmpty).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  final result = <({CalendarItem item, int lane, int columns})>[];
  final group = <({CalendarItem item, int lane})>[];
  final ends = <int>[];
  void flush() {
    for (final slot in group) {
      result.add((item: slot.item, lane: slot.lane, columns: ends.length));
    }
    group.clear();
    ends.clear();
  }

  for (final item in sorted) {
    final start = clockMinutes(item.time);
    if (ends.every((end) => end <= start)) flush();
    var lane = ends.indexWhere((end) => end <= start);
    if (lane < 0) {
      lane = ends.length;
      ends.add(calendarEnd(item));
    } else {
      ends[lane] = calendarEnd(item);
    }
    group.add((item: item, lane: lane));
  }
  flush();
  return result;
}
