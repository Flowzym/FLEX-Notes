import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'models.dart';

const sheetFields = <String, String>{
  'type': 'Zeilenart',
  'phase': 'Phase',
  'time': 'Zeit',
  'task': 'Auftrag oder Hilfe',
  'goal': 'Ziel',
  'subject': 'Fach und Dauer',
  'refs': 'Material',
  'files': 'Verknüpfte Dateien',
  'who': 'Schüler oder Kürzel',
  'owner': 'Zuständig',
  'day': 'Wochentag',
  'prep': 'Vorbereitung',
  'duration': 'Dauer in Minuten',
  'groupMode': 'Aufträge mit Schülerkürzel',
};
const sheetTypes = {
  'phase': 'Unterrichtsphase',
  'aid': 'Individuelle Hilfe',
  'week': 'Tagesschwerpunkt',
  'goal': 'Wochenziel',
  'note': 'Hinweis',
  'review': 'Zu prüfen',
};
String sheetHash(String value) => const Uuid().v5(Namespace.url.value, value);
String sheetText(Json row, String key) => row[key] as String? ?? '';
List<Json> sheetList(Json m, String key) =>
    (m[key] as List? ?? []).map((r) => Json.from(r as Map)).toList();
String sheetFold(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

void validateTeachingSheet(dynamic value, {bool edits = false}) {
  void fail() => throw const DomainError(
    'Die Daten der Unterrichtsplanung sind ungültig.',
  );
  if (value is! Map || jsonEncode(value).length > (edits ? 125000 : 305000)) {
    fail();
  }
  final j = Json.from(value as Map);
  final keys = edits
      ? {'changes', 'order', 'cloudTag', 'dirty'}
      : {'stamp', 'rows', 'issue', 'drive', 'item', 'parser'};
  if (j.keys.any((k) => !keys.contains(k))) fail();
  for (final k in ['stamp', 'drive', 'item', 'issue', 'cloudTag']) {
    if (j.containsKey(k) &&
        (j[k] is! String || (j[k] as String).length > 2000)) {
      fail();
    }
  }
  if (j.containsKey('parser') && j['parser'] is! int) fail();
  if (edits && j.containsKey('dirty') && j['dirty'] is! bool) fail();
  if (edits && j.containsKey('order')) {
    final v = j['order'];
    if (v is! List ||
        v.length > 500 ||
        v.any((i) => i is! String || i.length > 80) ||
        v.toSet().length != v.length) {
      fail();
    }
  }
  final rows = j[edits ? 'changes' : 'rows'];
  if (rows is! List || rows.length > 500) fail();
  final ids = <String>{};
  for (final r in rows as List) {
    if (r is! Map ||
        r['id'] is! String ||
        (r['id'] as String).isEmpty ||
        (r['id'] as String).length > 80 ||
        !ids.add(r['id'])) {
      fail();
    }
    if ((r as Map).entries.any(
      (e) =>
          !{'id', 'raw', 'line', ...sheetFields.keys}.contains(e.key) ||
          e.value is! String ||
          (e.value as String).length > 12000,
    )) {
      fail();
    }
    if (r.containsKey('type') && !sheetTypes.containsKey(r['type']) ||
        !edits && !r.containsKey('type')) {
      fail();
    }
    if ((r['phase'] as String? ?? '').length > 160) fail();
    if (r.containsKey('groupMode') &&
        !{'', 'separate'}.contains(r['groupMode'])) {
      fail();
    }
    if ((r['duration'] as String? ?? '').isNotEmpty) {
      final n = int.tryParse(r['duration']);
      if (n == null || n < 1 || n > 600) fail();
    }
  }
}

List<Json> effectiveSheetRows(Json sheet, Json edits) {
  final rows = sheetList(sheet, 'rows');
  final changes = {for (final r in sheetList(edits, 'changes')) r['id']: r};
  final result = [
    for (final r in rows) {...r, ...?changes[r['id']]},
  ];
  final order = List<String>.from(edits['order'] as List? ?? []);
  if (order.isNotEmpty) {
    // Keep unreviewed new rows in their source slots when a file grows.
    final byId = {for (final r in result) r['id']: r};
    final sorted = [
      for (final id in order)
        if (byId.containsKey(id)) byId[id]!,
    ].iterator;
    for (var i = 0; i < result.length; i++) {
      if (order.contains(result[i]['id']) && sorted.moveNext()) {
        result[i] = sorted.current;
      }
    }
  }
  return result;
}

(int, int)? sheetTime(String text) {
  final m = RegExp(
    r'^\s*(\d{1,2})[:.](\d{2})\s*(?:Uhr\s*)?(?:[-–—−]|bis)\s*(\d{1,2})[:.](\d{2})(?:\s*Uhr)?\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final h = int.parse(m[1]!),
      n = int.parse(m[2]!),
      hh = int.parse(m[3]!),
      nn = int.parse(m[4]!);
  if (h > 23 || hh > 23 || n > 59 || nn > 59 || h * 60 + n >= hh * 60 + nn) {
    return null;
  }
  return (h * 60 + n, hh * 60 + nn);
}

int? sheetMinutes(String s) {
  final m = RegExp(
    r'(?:^|\b)(\d{1,3})\s*(?:min\b|minuten\b)',
    caseSensitive: false,
  ).firstMatch(s);
  return m == null ? null : int.tryParse(m[1]!);
}

Set<int> sheetWeekdays(String s) {
  const names = ['mo', 'di', 'mi', 'do', 'fr', 'sa', 'so'];
  final normalized = s.toLowerCase().replaceAllMapped(
    RegExp(r'montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag'),
    (m) => m[0]!.substring(0, 2),
  );
  final out = <int>{};
  for (final m in RegExp(
    r'\b(mo|di|mi|do|fr|sa|so)\.?(?:\s*[-–—]\s*(mo|di|mi|do|fr|sa|so)\.?)?\b',
  ).allMatches(normalized)) {
    final a = names.indexOf(m[1]!) + 1, b = names.indexOf(m[2] ?? m[1]!) + 1;
    for (var i = a; i <= b; i++) {
      out.add(i);
    }
  }
  return out;
}

/// Match only one-to-one evidence. Keys shared by several rows never decide a pairing.
Map<String, String> uniquePlanMatches(
  Map<String, Json> before,
  Map<String, Json> after,
  List<String> fields,
) {
  final matches = <String, String>{}, used = <String>{};
  Map<String, List<String>> by(Map<String, Json> rows, String field) {
    final index = <String, List<String>>{};
    for (final e in rows.entries) {
      final key = sheetText(e.value, field);
      if (key.isNotEmpty) (index[key] ??= []).add(e.key);
    }
    return index;
  }

  for (final field in fields) {
    final a = by(before, field), b = by(after, field);
    for (final e in b.entries) {
      final olds = a[e.key];
      if (e.value.length != 1 || olds?.length != 1) continue;
      final id = e.value.single, old = olds!.single;
      if (!matches.containsKey(id) && used.add(old)) matches[id] = old;
    }
  }
  return matches;
}

Json rebaseTeachingEdits(List<Json> previous, List<Json> incoming, Json edits) {
  if (edits.isEmpty || previous.isEmpty || incoming.isEmpty) return edits;
  Map<String, Json> anchors(List<Json> rows) => {
    for (final r in rows)
      sheetText(r, 'id'): () {
        final type = sheetText(r, 'type');
        final scope = [
          type,
          sheetFold(sheetText(r, 'phase')),
          sheetFold(sheetText(r, 'who')),
          sheetFold(sheetText(r, 'day')),
        ];
        final slot = sheetText(r, 'time'), task = sheetText(r, 'task');
        return <String, dynamic>{
          'exact': sheetHash(sheetText(r, 'raw')),
          if (slot.isNotEmpty && task.isNotEmpty)
            'content': sheetHash(
              jsonEncode([
                type,
                slot,
                sheetFold(task),
                sheetFold(sheetText(r, 'who')),
              ]),
            ),
          if (task.isNotEmpty)
            'task': sheetHash(jsonEncode([...scope, sheetFold(task)])),
          if (slot.isNotEmpty) 'slot': sheetHash(jsonEncode([...scope, slot])),
          if (type == 'aid' || type == 'week')
            'scope': sheetHash(jsonEncode(scope)),
        };
      }(),
  };
  final matched = uniquePlanMatches(anchors(previous), anchors(incoming), [
    'exact',
    'content',
    'task',
    'slot',
    'scope',
  ]);
  final inverse = {for (final e in matched.entries) e.value: e.key};
  final originals = {
    for (final r in previous) sheetText(r, 'id'): sheetText(r, 'raw'),
  };
  final newKeys = incoming.map((r) => sheetText(r, 'id')).toSet();
  Map<String, int> counts(List<Json> rows) {
    final result = <String, int>{};
    for (final r in rows) {
      result.update(sheetText(r, 'raw'), (n) => n + 1, ifAbsent: () => 1);
    }
    return result;
  }

  final earlier = counts(previous), later = counts(incoming);
  final changes = sheetList(edits, 'changes'),
      order = List<String>.from(edits['order'] ?? []);
  // A previously orphaned correction at the new ID has to be resolved by the teacher.
  final occupied = changes.map((r) => sheetText(r, 'id')).toSet();
  String migrate(String id) {
    final to = inverse[id];
    final raw = originals[id];
    if (to == null &&
        raw != null &&
        earlier[raw] != later[raw] &&
        occupied.contains(id) &&
        newKeys.contains(id)) {
      // Identical duplicate rows can inherit an ordinal after an insertion.
      // Keep the correction recoverable in the existing manual reassignment UI.
      return sheetHash('ambiguous correction/$id');
    }
    return to != null && !occupied.contains(to) ? to : id;
  }

  if (![...occupied, ...order].any((id) => migrate(id) != id)) return edits;
  return {
    ...edits,
    'dirty': true,
    'changes': [
      for (final r in changes) {...r, 'id': migrate(sheetText(r, 'id'))},
    ],
    if (order.isNotEmpty) 'order': order.map(migrate).toSet().toList(),
  };
}
