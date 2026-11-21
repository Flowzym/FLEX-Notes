part of 'teaching_sheet.dart';

/// Only a selector at the start of a sentence, line or semicolon-delimited
/// instruction can address pupils. An unresolved code stays in the review.
({String common, List<Json> groups, bool exclusive}) _groupInstructions(
  String task,
  TeachingLinks links,
  Set<String> audience, {
  bool materials = false,
}) {
  final prefix = RegExp(
    r'(?:^|(?<=[.;!?\n]))[ \t]*([\p{L}\p{N}][\p{L}\p{N} /,&+\-]{0,65}):[ \t]*',
    unicode: true,
  );
  final code = RegExp(r'^[A-ZÄÖÜ][A-ZÄÖÜ0-9]{0,3}$');
  final markers = prefix.allMatches(task).where((m) {
    final label = m[1]!.trim();
    return _all(label) ||
        links.people.containsKey(sheetFold(label)) ||
        label
            .split(RegExp(r'[/,&+]'))
            .every(
              (t) =>
                  code.hasMatch(t.trim()) ||
                  links.people.containsKey(sheetFold(t)),
            );
  }).toList();
  if (markers.isEmpty) {
    return (common: task, groups: <Json>[], exclusive: false);
  }
  final common = [task.substring(0, markers.first.start).trim()];
  final groups = <Json>[];
  for (final (i, m) in markers.indexed) {
    final who = m[1]!.trim();
    final text = task
        .substring(
          m.end,
          i + 1 < markers.length ? markers[i + 1].start : task.length,
        )
        .trim()
        .replaceFirst(RegExp(r';$'), '')
        .trim();
    if (text.isEmpty) continue;
    if (_all(who)) {
      common.add(text);
      continue;
    }
    final ids = links
        .pupilIds(who)
        .where((id) => audience.isEmpty || audience.contains(id))
        .toList();
    if (ids.isEmpty) continue;
    groups.add({
      'pupilIds': ids,
      'body': materials ? 'Material · $text' : text,
      'minutes': materials ? 0 : sheetMinutes(text) ?? 0,
      'materialIds': links.materialIds(
        materials ? text : TeachingLinks._tokens(text).join('; '),
      ),
    });
  }
  final shared = common.where((s) => s.isNotEmpty).join('\n');
  return (common: shared, groups: groups, exclusive: shared.isEmpty);
}

List<LessonPhase> _groupPhases(LessonPhase phase, List<Json> groups) {
  final counts = <String, int>{};
  final extra = phase.guidance.skip(groups.length);
  return [
    for (final g in groups)
      () {
        final ids = List<String>.from(g['pupilIds'])..sort();
        final who = ids.join('/');
        final occurrence = counts.update(who, (i) => i + 1, ifAbsent: () => 1);
        return phase.patch({
          'id': sheetHash('${phase.id}/group/$who/$occurrence'),
          'body': [
            phase.body,
            sheetText(g, 'body'),
          ].where((s) => s.isNotEmpty).join('\n'),
          'minutes': g['minutes'] == 0 ? phase.minutes : g['minutes'],
          'pupilIds': ids,
          'materialIds': {
            ...phase.materialIds,
            ...List<String>.from(g['materialIds']),
          }.toList(),
          'guidance': extra
              .where((r) => (r['pupilIds'] as List).any(ids.contains))
              .toList(),
        });
      }(),
  ];
}
