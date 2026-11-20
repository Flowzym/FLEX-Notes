import 'models.dart';

const planningUses = {
  'lesson': 'Unterrichtsmaterial',
  'dayPlan': 'Tagesplanung',
  'weekPlan': 'Wochenübersicht',
  'solution': 'Lösung · Lehrkraft',
  'teacher': 'Lehrkraft',
  'substitute': 'Supplierung',
  'template': 'Vorlage',
  'media': 'Lernmedium',
};

final _yearPattern = RegExp(r'^(\d{4})[-–/](\d{2}|\d{4})$');
String schoolYearLabel(int start) =>
    '$start-${((start + 1) % 100).toString().padLeft(2, '0')}';
String yearOfDay(DateTime day) =>
    schoolYearLabel(day.month < 9 ? day.year - 1 : day.year);
String normalizedSchoolYear(String text) {
  final match = _yearPattern.firstMatch(text.trim());
  if (match == null) return '';
  final year = int.parse(match[1]!);
  final next = match[2]!;
  return (next.length == 2 ? (year + 1) % 100 : year + 1) == int.parse(next)
      ? schoolYearLabel(year)
      : '';
}

bool validMaterialCode(String code) =>
    RegExp(r'^[A-ZÄÖÜ]{1,12}$').hasMatch(code) && code != 'KW';

void validateMaterialProfile(Json data) {
  final year = data['schoolYear'], code = data['code'];
  final reserved = data['reserved'], aliases = data['aliases'];
  if (year is! String ||
      year.isEmpty ||
      normalizedSchoolYear(year) != year ||
      code is! String ||
      code.isNotEmpty && !validMaterialCode(code) ||
      reserved is! List ||
      reserved.length > 200 ||
      reserved.any((c) => c is! String || !validMaterialCode(c)) ||
      reserved.toSet().length != reserved.length ||
      code.isNotEmpty && !reserved.contains(code) ||
      aliases is! List ||
      aliases.length > 30 ||
      aliases.any(
        (a) =>
            a is! String ||
            a.length > 80 ||
            RegExp(r'[\p{L}\p{N}]', unicode: true).allMatches(a).length < 2,
      ) ||
      aliases.map((a) => (a as String).toLowerCase()).toSet().length !=
          aliases.length ||
      (data['pupilIds'] as List? ?? []).length > 1 ||
      (data['pupilIds'] as List? ?? []).isEmpty &&
          (code.isNotEmpty || aliases.isNotEmpty)) {
    throw const DomainError(
      'Bitte Schuljahr, Materialkürzel und weitere Dateinamen prüfen.',
    );
  }
}

void validatePlanningFields(Json data) {
  for (final key in ['planning', 'planningOverride']) {
    final plan = data[key];
    if (plan == null) continue;
    if (plan is! Map ||
        plan.keys.any(
          (k) => !{'use', 'year', 'day', 'week', 'substitute'}.contains(k),
        ) ||
        plan.containsKey('substitute') && plan['substitute'] is! bool ||
        plan.containsKey('use') && !planningUses.containsKey(plan['use']) ||
        plan.containsKey('year') &&
            (plan['year'] is! String ||
                normalizedSchoolYear(plan['year'] as String) != plan['year']) ||
        ['week', 'day'].any(
          (k) =>
              plan.containsKey(k) &&
              (plan[k] is! String ||
                  plan[k] != '' && !validDate(plan[k] as String)),
        )) {
      throw const DomainError('Ungültiger Unterrichtseinsatz.');
    }
  }
  for (final key in [
    'planningDecisions',
    'planningAutoDates',
    'planningDeferred',
  ]) {
    final ids = data[key];
    if (ids != null &&
        (ids is! List ||
            ids.length > 5000 ||
            ids.any((id) => id is! String || id.isEmpty || id.length > 250) ||
            ids.toSet().length != ids.length)) {
      throw const DomainError('Ungültige Materialzuordnung.');
    }
  }
  final reviewed = data['planningReviewedCodes'];
  if (reviewed != null &&
      (reviewed is! List ||
          reviewed.length > 200 ||
          reviewed.any((c) => c is! String || !validMaterialCode(c)) ||
          reviewed.toSet().length != reviewed.length)) {
    throw const DomainError('Ungültige Materialkürzel.');
  }
  if (data.containsKey('planningDismissed') &&
      data['planningDismissed'] is! bool) {
    throw const DomainError('Ungültige Zuordnungsentscheidung.');
  }
}
