import 'dart:convert';
import 'classroom.dart';
import 'lesson_flow_data.dart';
import 'models.dart';
import 'planning_import.dart';
import 'teaching_sheet_data.dart';
export 'teaching_sheet_data.dart';

bool isTeachingSource(ClassroomDocument d) =>
    !d.deleted &&
    d.kind == ClassroomKind.material &&
    {'weekPlan', 'dayPlan'}.contains(teachingUse(d)) &&
    !d.flag('sourceMissing') &&
    d.text('cloudReview').isEmpty;
String sourceStamp(ClassroomDocument m) => [
  m.text('remoteEtag'),
  m.text('remoteModifiedAt'),
  m.text('remoteName'),
  m.number('size'),
].join('|');
List<Json> teachingRows(ClassroomDocument m) =>
    effectiveSheetRows(m.map('planSheet'), m.map('planEdits'));
String teachingVersion(ClassroomDocument m) => sheetHash(
  jsonEncode([
    m.map('planSheet')['stamp'],
    m.map('planEdits')['order'],
    m.map('planEdits')['changes'],
  ]),
);
bool sheetUsable(ClassroomDocument m) =>
    sheetText(m.map('planSheet'), 'item') == m.text('itemId') &&
    sheetText(m.map('planSheet'), 'drive') == m.text('driveId') &&
    m.map('planSheet')['stamp'] == sourceStamp(m);
List<ClassroomDocument> teachingSources(
  Iterable<ClassroomDocument> docs,
  String date, {
  bool week = false,
}) =>
    docs
        .where(
          (d) =>
              isTeachingSource(d) &&
              (week
                  ? teachingUse(d) == 'weekPlan' &&
                        teachingWeek(d) == weekOfDay(date)
                  : teachingUse(d) == 'dayPlan' && teachingDay(d) == date),
        )
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

/// Scoped to one plan, one planning root, and one year. Prefer the dated sheet
/// over the week, then a unique reusable document elsewhere in the same year.
class TeachingLinks {
  TeachingLinks(
    this.source,
    Iterable<ClassroomDocument> docs,
    Iterable<Pupil> pupils,
  ) {
    final year = teachingPlan(source)['year'] as String? ?? '';
    for (final p in pupils.where((p) => !p.deleted && !p.archived)) {
      final profile = pupilProfile(docs, p.id, year);
      for (final s in [
        p.name,
        if (profile != null) ...[
          profile.text('code'),
          ...profile.strings('aliases'),
        ],
      ]) {
        if (s.trim().isNotEmpty) (people[sheetFold(s)] ??= {}).add(p.id);
      }
    }
    for (final d in docs) {
      if (d.deleted ||
          d.kind != ClassroomKind.material ||
          d.id == source.id ||
          d.flag('sourceMissing') ||
          d.text('cloudReview').isNotEmpty ||
          d.text('driveId') != source.text('driveId') ||
          source.text('cloudRule') != d.text('cloudRule') ||
          teachingPlan(d)['year'] != year ||
          {'dayPlan', 'weekPlan', 'template'}.contains(teachingUse(d))) {
        continue;
      }
      if (d.text('itemId').isNotEmpty) items[d.text('itemId')] = d;
      final name = d.text('remoteName', d.title);
      final stem = name.replaceFirst(
        RegExp(r'\.[a-z0-9]+$', caseSensitive: false),
        '',
      );
      for (final token in {sheetFold(stem), ..._tokens(stem).map(sheetFold)}) {
        (materials[token] ??= []).add(d);
      }
    }
  }
  final ClassroomDocument source;
  final items = <String, ClassroomDocument>{};
  List<String> rowMaterials(Json row) {
    if (!row.containsKey('files')) return materialIds(sheetText(row, 'refs'));
    final ids = <String>{};
    for (final item in sheetText(
      row,
      'files',
    ).split('\n').where((id) => id.isNotEmpty)) {
      final m = items[item];
      if (m == null) {
        issues.add('Verknüpfte Unterlage fehlt · ${row['line']}');
      } else {
        ids.add(m.id);
      }
    }
    return ids.toList();
  }

  final people = <String, Set<String>>{};
  final materials = <String, List<ClassroomDocument>>{};
  final issues = <String>{};
  static final _code = RegExp(
    r'(?<![A-Za-z0-9])([A-ZÄÖÜ]{1,5})(\d{2,3})(L?)(?![A-Za-z0-9])',
  );
  static Iterable<String> _tokens(String s) sync* {
    for (final m in _code.allMatches(s)) {
      yield m[0]!;
    }
  }

  Set<String> pupilIds(String who) {
    final ids = <String>{};
    final whole = people[sheetFold(who)];
    if (whole?.length == 1) return whole!;
    for (final token in who.split(
      RegExp(r'\s*(?:[/&,;+]|\bund\b)\s*', caseSensitive: false),
    )) {
      final matches = people[sheetFold(token)] ?? {};
      if (matches.length == 1) {
        ids.add(matches.single);
      } else {
        issues.add('Schülerzuordnung prüfen · $token');
      }
    }
    return ids;
  }

  List<String> materialIds(String raw) {
    final refs = <String>{};
    for (final part in raw.split(RegExp(r'[;\n]'))) {
      final codes = _tokens(part).toSet();
      final ranges = RegExp(
        r'\b([A-ZÄÖÜ]{1,5})(\d{2,3})\s*[-–—]\s*([A-ZÄÖÜ]{1,5})?(\d{2,3})(?![0-9A-Za-z])',
      );
      for (final m in ranges.allMatches(part)) {
        final a = int.parse(m[2]!), b = int.parse(m[4]!);
        if ((m[3] == null || m[1] == m[3]) && b >= a && b - a <= 100) {
          for (var n = a; n <= b; n++) {
            codes.add('${m[1]}${n.toString().padLeft(m[2]!.length, '0')}');
          }
        } else {
          issues.add('Materialbereich prüfen · ${m[0]}');
        }
      }
      for (final token in codes.isEmpty ? [part.trim()] : codes) {
        if (token.isEmpty) continue;
        final candidates = materials[sheetFold(token)] ?? [];
        int rank(ClassroomDocument m) =>
            teachingDay(m).isNotEmpty && teachingDay(m) == teachingDay(source)
            ? 0
            : teachingWeek(m).isNotEmpty &&
                  teachingWeek(m) == teachingWeek(source)
            ? 1
            : 2;
        for (var priority = 0; priority <= 2; priority++) {
          final best = candidates.where((m) => rank(m) == priority).toList();
          if (best.isEmpty) continue;
          if (best.length == 1) {
            refs.add(best.single.id);
          } else {
            issues.add('Mehrere Unterlagen · $token');
          }
          break;
        }
        if (codes.isNotEmpty && candidates.isEmpty) {
          issues.add('Material fehlt · $token');
        }
      }
    }
    return refs.toList();
  }
}

bool _all(String who) => {
  'alle',
  'klasse',
  'alle schueler',
  'flex klasse',
  'gesamtgruppe',
}.contains(sheetFold(who));
bool _allPhases(String phase) =>
    {'alle', 'alle phasen', 'durchgehend'}.contains(sheetFold(phase));
bool _phaseMatch(String selector, String title) {
  final a = sheetFold(selector), b = sheetFold(title);
  return _allPhases(selector) ||
      a == b ||
      a == b.replaceFirst(RegExp(r'\s+\d+$'), '');
}

bool _inWindow(Json r, LessonOccurrence? lesson) {
  if (lesson == null) return true;
  final phase = sheetTime(sheetText(r, 'time')),
      window = sheetTime('${lesson.start}–${lesson.end}');
  return phase != null &&
      window != null &&
      phase.$1 < window.$2 &&
      phase.$2 > window.$1;
}

List<Json> weeklyContext(ClassroomDocument m, String date) =>
    sourceDateWarning(m).isNotEmpty
    ? []
    : [
        for (final row in teachingRows(m))
          if (row['type'] == 'goal' ||
              row['type'] == 'week' &&
                  sheetWeekdays(
                    sheetText(row, 'day'),
                  ).contains(schoolDay(date).weekday))
            row,
      ];
String sourceDateWarning(ClassroomDocument m) {
  final plan = teachingPlan(m);
  final weekly = teachingUse(m) == 'weekPlan';
  final expected = plan[weekly ? 'week' : 'day'] as String? ?? '';
  if (!validDate(expected) ||
      m.map('planningOverride').containsKey(weekly ? 'week' : 'day')) {
    return '';
  }
  for (final row in teachingRows(m).take(8)) {
    if (row['type'] != 'note' && row['type'] != 'review') continue;
    final text = sheetText(row, 'raw');
    if (!RegExp(
      r'\bKW\s*\d|\bDatum\b|Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag',
      caseSensitive: false,
    ).hasMatch(text)) {
      continue;
    }
    final date = RegExp(r'\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b').firstMatch(text);
    if (date == null) continue;
    final printed =
        '${date[3]}-${date[2]!.padLeft(2, '0')}-${date[1]!.padLeft(2, '0')}';
    if (validDate(printed) &&
        (weekly ? weekOfDay(printed) : printed) != expected) {
      return 'Datum im Dokument ($printed) und Planung ($expected) prüfen.';
    }
    return '';
  }
  return '';
}

List<ClassroomDocument> dayCandidates(
  Iterable<ClassroomDocument> docs,
  String date,
  LessonOccurrence? lesson,
) {
  final all = teachingSources(docs, date);
  return all
      .where(
        (m) =>
            sheetUsable(m) &&
            sourceDateWarning(m).isEmpty &&
            teachingRows(
              m,
            ).any((r) => r['type'] == 'phase' && _inWindow(r, lesson)),
      )
      .toList();
}

class ImportedTeachingFlow {
  ImportedTeachingFlow(this.source, this.phases, this.issues);
  final ClassroomDocument source;
  final List<LessonPhase> phases;
  final Set<String> issues;
}

ImportedTeachingFlow buildTeachingFlow(
  ClassroomDocument m,
  Iterable<ClassroomDocument> docs,
  Iterable<Pupil> pupils, {
  LessonOccurrence? lesson,
  bool explicit = false,
}) {
  final rows = teachingRows(m), links = TeachingLinks(m, docs, pupils);
  final warning = sourceDateWarning(m);
  if (warning.isNotEmpty) links.issues.add(warning);
  final phases = <LessonPhase>[];
  var draftSize = 0;
  final all = rows.where((r) => r['type'] == 'phase').toList();
  final aids = rows.where((r) => r['type'] == 'aid').toList();
  for (final r in rows.where((r) => r['type'] == 'review')) {
    links.issues.add('${r['line']} · Zuordnung prüfen');
  }
  for (final r in aids.where(
    (r) => !all.any(
      (p) => _phaseMatch(sheetText(r, 'phase'), sheetText(p, 'phase')),
    ),
  )) {
    links.issues.add('${r['line']} · Phase „${r['phase']}“ zuordnen');
  }
  final seq = <String, int>{}, keys = <String, String>{};
  for (final r in sheetList(m.map('planSheet'), 'rows')) {
    final name = sheetFold(sheetText(r, 'phase'));
    if (r['type'] == 'phase') {
      keys[r['id'] as String] =
          '$name-${seq.update(name, (i) => i + 1, ifAbsent: () => 1)}';
    }
  }
  for (final r in all) {
    final time = sheetText(r, 'time'), span = sheetTime(time);
    if (span == null) links.issues.add('${r['line']} · Zeit prüfen');
    if (!_inWindow(r, lesson) && !(explicit && span == null)) continue;
    final title = sheetText(r, 'phase');
    if (title.trim().isEmpty) {
      links.issues.add('${r['line']} · Phasentitel fehlt');
      continue;
    }
    final window = lesson == null
        ? null
        : sheetTime('${lesson.start}–${lesson.end}');
    final minutes =
        int.tryParse(sheetText(r, 'duration')) ??
        (span != null
            ? (window == null
                  ? span.$2 - span.$1
                  : span.$2.clamp(window.$1, window.$2) -
                        span.$1.clamp(window.$1, window.$2))
            : sheetMinutes(sheetText(r, 'subject')) ?? 0);
    if (minutes > 600) {
      links.issues.add('${r['line']} · Dauer prüfen');
      continue;
    }
    final body = <String>[
      if (time.isNotEmpty) time,
      if (sheetText(r, 'task').isNotEmpty) r['task'],
      if (sheetText(r, 'goal').isNotEmpty) 'Ziel · ${r['goal']}',
      if (sheetText(r, 'subject').isNotEmpty) r['subject'],
      if (sheetText(r, 'owner').isNotEmpty) 'Zuständig · ${r['owner']}',
      if (sheetText(r, 'refs').isNotEmpty) 'Material · ${r['refs']}',
    ];
    final materialIds = links.rowMaterials(r).toSet();
    final guidance = <Json>[];
    for (final aid in aids.where(
      (a) => _phaseMatch(sheetText(a, 'phase'), title),
    )) {
      final who = sheetText(aid, 'who'),
          targets = _all(who) ? <String>{} : links.pupilIds(who);
      if (!_all(who) && targets.isEmpty) continue;
      final refs = links.rowMaterials(aid);
      final text = [
        sheetText(aid, 'task'),
        if (sheetText(aid, 'refs').isNotEmpty) 'Material · ${aid['refs']}',
      ].where((s) => s.isNotEmpty).join('\n');
      if (_all(who)) {
        body.add(text);
        materialIds.addAll(refs);
      } else {
        guidance.add({
          'pupilIds': targets.toList(),
          'body': text,
          'materialIds': refs,
          'minutes':
              int.tryParse(sheetText(aid, 'duration')) ??
              sheetMinutes(sheetText(aid, 'subject')) ??
              0,
        });
      }
    }
    final phase = LessonPhase(
      id: sheetHash('${m.id}:${keys[r['id']] ?? r['id']}'),
      title: title,
      body: body.where((s) => s.isNotEmpty).join('\n'),
      minutes: minutes,
      materialIds: materialIds.toList(),
      guidance: guidance,
      kind:
          RegExp(
            r'\bh[üu]\s*[- ]?\s*kontrolle',
            caseSensitive: false,
          ).hasMatch(title)
          ? 'homework'
          : 'work',
    );
    final perPupil = <String, int>{};
    final durations = <String, Set<int>>{};
    for (final a in guidance) {
      for (final id in List<String>.from(a['pupilIds'])) {
        perPupil.update(
          id,
          (n) => n + sheetText(a, 'body').length + 1,
          ifAbsent: () => phase.body.length + sheetText(a, 'body').length + 1,
        );
        if (a['minutes'] > 0) (durations[id] ??= {}).add(a['minutes']);
      }
    }
    if (phase.body.length > 12000 ||
        perPupil.values.any((n) => n > 12000) ||
        guidance.any((a) => a['minutes'] > 600)) {
      links.issues.add(
        '${r['line']} · Umfang oder Dauer der Schülerhilfen im Original prüfen',
      );
      continue;
    }
    if (durations.values.any((set) => set.length > 1)) {
      links.issues.add(
        '${r['line']} · Unterschiedliche Dauern für dieselbe Person prüfen',
      );
    }
    draftSize += jsonEncode(phase.toJson()).length;
    if (draftSize > 290000) {
      links.issues.add('Weitere Phasen im Original prüfen.');
      break;
    }
    phases.add(phase);
    if (phases.length == 80) {
      if (all.length > 80) {
        links.issues.add('Weitere Phasen im Original prüfen.');
      }
      break;
    }
  }
  return ImportedTeachingFlow(m, phases, links.issues);
}

LessonPhase individualTeachingPhase(LessonPhase p, String id) {
  final rows = p.guidance
      .where((r) => (r['pupilIds'] as List).contains(id))
      .toList();
  final durations = rows
      .map((r) => r['minutes'] as int)
      .where((n) => n > 0)
      .toSet();
  return p.fresh().patch({
    'id': sheetHash('${p.id}/pupil/$id'),
    'pupilIds': <String>[],
    'guidance': <Json>[],
    'body': [
      p.body,
      ...rows.map((r) => sheetText(r, 'body')),
    ].where((s) => s.isNotEmpty).join('\n'),
    if (durations.length == 1) 'minutes': durations.single,
    'materialIds': {
      ...p.materialIds,
      for (final r in rows) ...List<String>.from(r['materialIds']),
    }.toList(),
  });
}
