import 'classroom.dart';
import 'models.dart';
import 'school.dart';

class DevelopmentWeek {
  DevelopmentWeek(this.date);
  final String date;
  final List<SchoolRecord> records = [];
  int count(String tone) => records
      .where(
        (r) => switch (tone) {
          'positive' => r.positive.isNotEmpty,
          'negative' => r.negative.isNotEmpty,
          'neutral' => r.neutral.isNotEmpty,
          _ => r.positive.isEmpty && r.neutral.isEmpty && r.negative.isEmpty,
        },
      )
      .length;
}

List<DevelopmentWeek> developmentWeeks(
  Iterable<SchoolRecord> records, {
  required String pupilId,
  required String from,
  required String to,
  String area = 'all',
  String query = '',
}) {
  final start = schoolDay(from), end = schoolDay(to);
  if (end.isBefore(start) || end.difference(start).inDays > 1096) {
    throw const DomainError('Bitte einen Zeitraum bis zu drei Jahren wählen.');
  }
  final weeks = <String, DevelopmentWeek>{};
  for (
    var d = start.subtract(Duration(days: start.weekday - 1));
    !d.isAfter(end);
    d = d.add(const Duration(days: 7))
  ) {
    weeks[dateOnly(d)] = DevelopmentWeek(dateOnly(d));
  }
  for (final r in records) {
    if (r.deleted ||
        r.pupilId != pupilId ||
        ![SchoolKind.social, SchoolKind.work].contains(r.kind) ||
        area != 'all' && r.kind.name != area ||
        r.observedOn.compareTo(from) < 0 ||
        r.observedOn.compareTo(to) > 0 ||
        !r.searchText.toLowerCase().contains(query.trim().toLowerCase())) {
      continue;
    }
    final d = schoolDay(r.observedOn);
    weeks[dateOnly(d.subtract(Duration(days: d.weekday - 1)))]!.records.add(r);
  }
  return weeks.values.toList();
}
