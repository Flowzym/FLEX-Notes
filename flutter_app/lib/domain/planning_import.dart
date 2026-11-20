import 'package:uuid/uuid.dart';
import 'classroom.dart';
import 'models.dart';
import 'planning_fields.dart';

export 'planning_fields.dart' show planningUses, schoolYearLabel, yearOfDay;

final _isoDate = RegExp(r'(?:^|[^\d])(\d{4}-\d{2}-\d{2})(?!\d)');
final _weekFolder = RegExp(r'^KW[\s_-]*(\d{1,2})$', caseSensitive: false);
final _weekInName = RegExp(r'\bKW[\s_-]*(\d{1,2})\b', caseSensitive: false);
final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final _numbered = RegExp(r'^([A-ZÄÖÜ]{1,12})(\d{2})(L?)$');
final _group = RegExp(
  r'(?:^|[^\p{L}\p{N}])([A-ZÄÖÜ]{1,12}(?:(?:\s+und\s+|\s*[+&]\s*)[A-ZÄÖÜ]{1,12})+)(?![\p{L}\p{N}])',
  unicode: true,
);

String weekOfDay(String day) {
  final d = schoolDay(day);
  return dateOnly(d.subtract(Duration(days: d.weekday - 1)));
}

String _weekInYear(String year, int number) {
  if (year.isEmpty || number < 1 || number > 53) return '';
  final start = int.parse(year.substring(0, 4));
  for (final calendar in [start, start + 1]) {
    final jan4 = DateTime.utc(calendar, 1, 4);
    final monday = jan4.add(
      Duration(days: (number - 1) * 7 - jan4.weekday + 1),
    );
    final thursday = monday.add(const Duration(days: 3));
    if (thursday.year == calendar && yearOfDay(thursday) == year) {
      return dateOnly(monday);
    }
  }
  return '';
}

String _fold(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ü', 'ue')
    .replaceAll('ö', 'oe')
    .replaceAll('ß', 'ss');
String _words(String s) =>
    _word.allMatches(_fold(s)).map((m) => m[0]).join(' ');
String _stem(String name) =>
    name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;

class PlanningFilename {
  PlanningFilename(this.name) {
    final stem = _stem(name);
    for (final word in _word.allMatches(stem)) {
      final m = _numbered.firstMatch(word[0]!);
      if (m == null || !validMaterialCode(m[1]!)) continue;
      codes.add(m[1]!);
      numbers.add('${m[1]}${m[2]}');
      if (m[3] == 'L') solution = true;
    }
    for (final match in _group.allMatches(stem)) {
      final parts = match[1]!.split(RegExp(r'\s+und\s+|\s*[+&]\s*'));
      if (parts.every(validMaterialCode)) groups.addAll(parts);
    }
  }
  final String name;
  final codes = <String>{}, numbers = <String>{}, groups = <String>{};
  bool solution = false;
}

/// The folder describes the actual lesson. A date printed on a reusable
/// worksheet is only a fallback inside its week.
Json classifyPlanningFile(String path) {
  final parts = path
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  final name = parts.isEmpty ? '' : parts.removeLast();
  final folders = parts.map(_fold).toList(), stem = _fold(_stem(name));
  var year = '', folderDay = '', weekNumber = 0;
  for (final part in parts) {
    final y = normalizedSchoolYear(part);
    if (y.isNotEmpty) year = y;
    if (validDate(part)) folderDay = part;
    final kw = _weekFolder.firstMatch(part);
    if (kw != null) weekNumber = int.parse(kw[1]!);
  }
  final dates = _isoDate
      .allMatches(name)
      .map((m) => m[1]!)
      .where(validDate)
      .toSet();
  final filenameDay = dates.length == 1 ? dates.single : '';
  final yearDay = folderDay.isEmpty ? filenameDay : folderDay;
  if (year.isEmpty && yearDay.isNotEmpty) year = yearOfDay(schoolDay(yearDay));
  final isWeekPlan =
      stem.contains('wochenuebersicht') || stem.contains('wochenplan');
  if (isWeekPlan && weekNumber == 0) {
    final kw = _weekInName.firstMatch(stem);
    if (kw != null) {
      weekNumber = int.parse(kw[1]!);
      final calendar = RegExp(r'\b(\d{4})\s*[- ]*kw').firstMatch(stem);
      if (year.isEmpty && calendar != null) {
        final jan4 = DateTime.utc(int.parse(calendar[1]!), 1, 4);
        year = yearOfDay(
          jan4.add(Duration(days: (weekNumber - 1) * 7 + 4 - jan4.weekday)),
        );
      }
    }
  }
  String week = _weekInYear(year, weekNumber);
  String day = folderDay;
  if (day.isEmpty &&
      filenameDay.isNotEmpty &&
      (year.isEmpty || yearOfDay(schoolDay(filenameDay)) == year) &&
      (weekNumber == 0
          ? stem.contains('tagesplan')
          : weekOfDay(filenameDay) == week)) {
    day = filenameDay;
  }
  if (day.isNotEmpty) week = weekOfDay(day);
  final code = PlanningFilename(name);
  final substitute =
      folders.any(
        (s) => s.contains('supplierung') || s.contains('vertretung'),
      ) ||
      stem.contains('supplierung');
  final use =
      folders.any((s) => s == 'vorlagen' || s == 'vorlage') ||
          RegExp(r'\bvorlage\b').hasMatch(stem)
      ? 'template'
      : code.solution ||
            RegExp(r'\bloesung(?:en|sblatt|sblaetter)?\b').hasMatch(stem)
      ? 'solution'
      : isWeekPlan
      ? 'weekPlan'
      : stem.contains('tagesplan')
      ? 'dayPlan'
      : RegExp(r'\.(?:html?|url)$', caseSensitive: false).hasMatch(name)
      ? 'media'
      : RegExp(
          r'\b(?:lehrkraft|lehrerhinweise?|handreichung|erwartungshorizont)\b',
        ).hasMatch(stem)
      ? 'teacher'
      : substitute
      ? 'substitute'
      : 'lesson';
  return {
    'use': use,
    'year': year,
    if (substitute && use != 'substitute') 'substitute': true,
    'day': use == 'template' || use == 'weekPlan' ? '' : day,
    'week': use == 'template' ? '' : week,
  };
}

Json teachingPlan(ClassroomDocument d) => {
  ...d.map('planning'),
  ...d.map('planningOverride'),
};
String teachingUse(ClassroomDocument d) =>
    teachingPlan(d)['use'] as String? ?? '';
bool hasTeachingUse(ClassroomDocument d, String use) =>
    teachingUse(d) == use ||
    use == 'substitute' &&
        d.map('planningOverride').isEmpty &&
        d.map('planning')['substitute'] == true;
String teachingDay(ClassroomDocument d) =>
    teachingPlan(d)['day'] as String? ?? '';
String teachingWeek(ClassroomDocument d) =>
    teachingPlan(d)['week'] as String? ?? '';

Iterable<ClassroomDocument> materialProfiles(
  Iterable<ClassroomDocument> docs,
  String year,
) => docs.where(
  (d) =>
      d.kind == ClassroomKind.materialProfile &&
      !d.deleted &&
      d.text('schoolYear') == year,
);
ClassroomDocument? pupilProfile(
  Iterable<ClassroomDocument> docs,
  String pupil,
  String year,
) => materialProfiles(
  docs,
  year,
).where((d) => d.strings('pupilIds').contains(pupil)).firstOrNull;

String suggestMaterialCode(
  String name,
  Iterable<ClassroomDocument> docs,
  String pupil,
  String year,
) {
  final reserved = {
    for (final d in materialProfiles(docs, year))
      if (!d.strings('pupilIds').contains(pupil)) ...d.strings('reserved'),
  };
  final letters = name.trim().toUpperCase().replaceAll(
    RegExp(r'[^A-ZÄÖÜ]'),
    '',
  );
  for (var i = 1; i <= letters.length && i <= 12; i++) {
    final candidate = letters.substring(0, i);
    if (validMaterialCode(candidate) && !reserved.contains(candidate)) {
      return candidate;
    }
  }
  return '';
}

ClassroomDocument buildMaterialProfile(
  Iterable<ClassroomDocument> docs,
  String pupil,
  String year,
  String code,
  List<String> aliases,
) {
  final old = pupilProfile(docs, pupil, year);
  final fields = <String, dynamic>{
    'schoolYear': year,
    'pupilIds': [pupil],
    'code': code,
    'reserved': {
      ...?old?.strings('reserved'),
      if (code.isNotEmpty) code,
    }.toList(),
    'aliases': aliases,
  };
  if (code.isNotEmpty &&
      materialProfiles(
        docs,
        year,
      ).any((d) => d.id != old?.id && d.strings('reserved').contains(code))) {
    throw DomainError(
      'Das Kürzel „$code“ ist im Schuljahr $year bereits vergeben.',
    );
  }
  return old?.patch(fields) ??
      ClassroomDocument.create(
        ClassroomKind.materialProfile,
        'Materialkürzel $year',
        fields,
        id: const Uuid().v5(
          Namespace.url.value,
          'flex-material-profile:$year:$pupil',
        ),
      );
}

void checkCodeReservations(Iterable<ClassroomDocument> docs) {
  final used = <(String, String)>{}, owners = <(String, String)>{};
  for (final d in docs.where((d) => d.kind == ClassroomKind.materialProfile)) {
    final year = d.text('schoolYear');
    for (final code in d.strings('reserved')) {
      if (!used.add((year, code))) {
        throw DomainError('„$code“ ist im Schuljahr $year bereits vergeben.');
      }
    }
    for (final id in d.strings('pupilIds')) {
      if (!owners.add((year, id))) {
        throw const DomainError(
          'Doppelte Kürzelverwaltung für diesen Schüler.',
        );
      }
    }
  }
}

class PlanningMatch {
  final owners = <String>{}, unknown = <String>{};
  bool ambiguous = false;
  bool get needsReview => owners.isNotEmpty || unknown.isNotEmpty || ambiguous;
}

Map<String, int> planningRosterRevisions(
  Iterable<ClassroomDocument> docs,
  Iterable<Pupil> pupils, {
  bool includeFolders = false,
}) => {
  if (includeFolders)
    for (final f in docs.where((d) => d.kind == ClassroomKind.folder))
      'folder-${f.id}': f.revision,
  for (final p in pupils) 'pupil-${p.id}': p.revision,
  for (final d in docs.where((d) => d.kind == ClassroomKind.materialProfile))
    'profile-${d.id}': d.revision,
};

class PlanningRoster {
  PlanningRoster(Iterable<ClassroomDocument> docs, Iterable<Pupil> pupils) {
    for (final f in docs.where((d) => d.kind == ClassroomKind.folder)) {
      if (f.deleted || !f.flag('planningFolder') || !f.flag('incoming')) {
        _inactiveFolders.add(f.id);
      }
    }
    final active = pupils
        .where((p) => !p.archived && !p.deleted)
        .map((p) => p.id)
        .toSet();
    for (final profile in docs.where(
      (d) => !d.deleted && d.kind == ClassroomKind.materialProfile,
    )) {
      final id = profile.strings('pupilIds').firstOrNull;
      if (!active.contains(id) || id == null) continue;
      final year = profile.text('schoolYear'), code = profile.text('code');
      if (code.isNotEmpty) (_codes[year] ??= {})[code] = id;
      for (final alias in profile.strings('aliases')) {
        ((_aliases[year] ??= {})[_words(alias)] ??= {}).add(id);
      }
    }
  }
  final _inactiveFolders = <String>{};
  final _codes = <String, Map<String, String>>{};
  final _aliases = <String, Map<String, Set<String>>>{};
  PlanningMatch match(ClassroomDocument d, {bool includeDecided = false}) {
    final result = PlanningMatch();
    if (d.deleted ||
        d.flag('sourceMissing') ||
        d.text('cloudReview').isNotEmpty ||
        _inactiveFolders.contains(d.text('cloudRule')) ||
        d.map('planning').isEmpty ||
        !includeDecided && d.flag('planningDismissed') ||
        {'template', 'dayPlan', 'weekPlan'}.contains(teachingUse(d))) {
      return result;
    }
    final year = d.map('planning')['year'] as String? ?? '';
    final name = d.text('remoteName', d.text('name'));
    final file = PlanningFilename(name);
    final codes = _codes[year] ?? {};
    final groupCodes = file.groups.any(codes.containsKey)
        ? file.groups
        : <String>{};
    if (groupCodes.isNotEmpty) result.ambiguous = true;
    for (final key in {...file.codes, ...groupCodes}) {
      final id = codes[key];
      if (id == null) {
        result.unknown.add(key);
      } else {
        result.owners.add(id);
      }
    }
    final sourceDay = d.map('planning')['day'] as String? ?? '';
    if (sourceDay.isNotEmpty &&
        year.isNotEmpty &&
        yearOfDay(schoolDay(sourceDay)) != year) {
      result.ambiguous = true;
    }
    final numberedOwners = result.owners.toSet();
    final nameWords = ' ${_words(_stem(name))} ';
    final aliases = _aliases[year] ?? {};
    for (final entry in aliases.entries) {
      if (nameWords.contains(' ${entry.key} ')) {
        result.owners.addAll(entry.value);
        if (entry.value.length > 1 ||
            numberedOwners.isNotEmpty &&
                !numberedOwners.containsAll(entry.value)) {
          result.ambiguous = true;
        }
      }
    }
    if (numberedOwners.isEmpty && result.owners.length > 1) {
      result.ambiguous = true;
    }
    if (!includeDecided) {
      result.owners.removeAll({
        ...d.strings('planningDecisions'),
        ...d.strings('pupilIds'),
      });
      if (result.owners.isEmpty && result.unknown.isEmpty) {
        result.ambiguous = false;
      }
    }
    return result;
  }
}

/// Remember the decision even after a manual unassignment. Only an untouched
/// teaching date created here follows a later rescheduling in OneDrive.
ClassroomDocument decidePlanningPupils(
  ClassroomDocument d,
  Iterable<String> considered,
  Iterable<String> selected,
) {
  final ids = d.strings('pupilIds').toSet(),
      dates = d.rows('pupilDates'),
      auto = d.strings('planningAutoDates').toSet();
  final day = teachingDay(d);
  for (final id in selected) {
    ids.add(id);
    if (day.isNotEmpty && !dates.any((row) => row['pupilId'] == id)) {
      dates.add({'pupilId': id, 'date': day});
      auto.add(id);
    }
  }
  return d.patch({
    'pupilIds': ids.toList(),
    'pupilDates': dates,
    'planningAutoDates': auto.toList(),
    'planningDecisions': {
      ...d.strings('planningDecisions'),
      ...considered,
    }.toList(),
  });
}

ClassroomDocument updateTeachingPlan(ClassroomDocument d, Json fields) {
  final before = teachingDay(d),
      next = d.patch(fields),
      after = teachingDay(next);
  if (before == after || before.isEmpty) return next;
  final dates = next.rows('pupilDates'),
      auto = next.strings('planningAutoDates').toSet();
  for (final id in auto.toList()) {
    final original = dates
        .where((r) => r['pupilId'] == id && r['date'] == before)
        .firstOrNull;
    if (original == null) {
      auto.remove(id);
      continue;
    }
    dates.remove(original);
    if (after.isNotEmpty &&
        !dates.any((r) => r['pupilId'] == id && r['date'] == after)) {
      dates.add({'pupilId': id, 'date': after});
    } else {
      auto.remove(id);
    }
  }
  return next.patch({'pupilDates': dates, 'planningAutoDates': auto.toList()});
}

List<ClassroomDocument> relatedPlanningFiles(
  ClassroomDocument d,
  Iterable<ClassroomDocument> docs,
) {
  final path = d.text('sourcePath');
  if (d.map('planning').isEmpty || !path.contains('/')) return [];
  final parent = path.substring(0, path.lastIndexOf('/') + 1);
  final name = d.text('remoteName'),
      stem = _stem(name).toLowerCase(),
      numbers = PlanningFilename(name).numbers;
  return docs.where((o) {
    final other = o.text('sourcePath');
    if (o.id == d.id ||
        o.deleted ||
        o.map('planning').isEmpty ||
        o.text('driveId') != d.text('driveId') ||
        !other.contains('/') ||
        other.substring(0, other.lastIndexOf('/') + 1) != parent) {
      return false;
    }
    final file = o.text('remoteName');
    return (_stem(file).toLowerCase() == stem &&
            o.text('extension') != d.text('extension')) ||
        teachingUse(d) != teachingUse(o) &&
            [teachingUse(d), teachingUse(o)].contains('solution') &&
            PlanningFilename(file).numbers.intersection(numbers).isNotEmpty;
  }).toList();
}
