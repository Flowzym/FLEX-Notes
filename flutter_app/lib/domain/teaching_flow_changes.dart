part of 'lesson_flow.dart';

Json _phaseAnchor(LessonPhase p) {
  final lines = p.body.split('\n').where((s) => s.trim().isNotEmpty).toList();
  final time = lines.isEmpty ? null : sheetTime(lines.first);
  final task = lines.skip(time == null ? 0 : 1).firstOrNull ?? '';
  final audience = [...p.pupilIds]..sort();
  final name = sheetFold(p.title);
  final scope = jsonEncode([name, audience]);
  return {
    'name': sheetHash(name),
    if (p.sourceRow.isNotEmpty)
      'row': sheetHash(
        jsonEncode([
          p.sourceRow.replaceFirstMapped(
            RegExp(r'^([0-9a-f-]{36})-\d+$'),
            (m) => m[1]!,
          ),
          audience,
        ]),
      ),
    if (time != null && task.isNotEmpty)
      'content': sheetHash(
        jsonEncode([time.$1, time.$2, sheetFold(task), audience]),
      ),
    if (time != null) 'slot': sheetHash('$scope/${time.$1}-${time.$2}'),
    if (task.isNotEmpty) 'task': sheetHash('$scope/${sheetFold(task)}'),
  };
}

class TeachingFlowChanges {
  TeachingFlowChanges(this.current, this.incoming) {
    final flow = current.map('flow');
    final sameSource = flow['sourceId'] == incoming.source.id;
    final rows = flow['sourceRows'] as Map? ?? {};
    for (final entry in (flow['sourceBase'] as Map? ?? {}).entries) {
      final id = entry.key as String;
      final phase = held[id];
      before[id] = {
        if (phase != null) ..._phaseAnchor(phase),
        if (rows[id] is Map) ...Json.from(rows[id] as Map),
        'signature': entry.value,
      };
    }
    final after = {
      for (final p in incoming.phases)
        p.id: {..._phaseAnchor(p), 'signature': _phaseSignature(p)},
    };
    if (!sameSource) return;
    matches.addAll(
      uniquePlanMatches(before, after, [
        'row',
        'signature',
        'content',
        'task',
        'slot',
      ]),
    );
    final used = matches.values.toSet();
    for (final p in incoming.phases.where((p) => !matches.containsKey(p.id))) {
      final options = [
        for (final e in before.entries)
          if (!used.contains(e.key) &&
              (e.value['name'] == null ||
                  e.value['name'] == after[p.id]!['name']))
            e.key,
      ];
      if (options.isNotEmpty) ambiguous[p.id] = options;
    }
  }
  final ClassroomDocument current;
  final ImportedTeachingFlow incoming;
  late final held = {for (final p in lessonPhases(current)) p.id: p};
  final before = <String, Json>{};
  final matches = <String, String>{};
  final ambiguous = <String, List<String>>{};

  bool unchanged(LessonPhase p, String oldId) =>
      before[oldId]?['signature'] == _phaseSignature(p);
  bool locallyEdited(LessonPhase p) =>
      before[p.id]?['signature'] != _phaseSignature(p);

  ImportedTeachingFlow normalized(Map<String, String> decisions) {
    for (final e in decisions.entries) {
      if (!ambiguous.containsKey(e.key) &&
          (!matches.containsKey(e.key) ||
              e.value.isNotEmpty && e.value != matches[e.key])) {
        throw const DomainError(
          'Die gewählte Zuordnung gehört nicht zu diesem Planvergleich.',
        );
      }
    }
    final used = matches.values.toSet();
    for (final e in ambiguous.entries) {
      final choice = decisions[e.key];
      if (choice == null ||
          choice.isNotEmpty &&
              (!e.value.contains(choice) || !used.add(choice))) {
        throw const DomainError(
          'Bitte mehrdeutige Phasen im Vergleich zuordnen.',
        );
      }
    }
    final reserved = {...held.keys, ...before.keys};
    final phases = <LessonPhase>[];
    for (final p in incoming.phases) {
      final match = decisions[p.id] ?? matches[p.id];
      var id = match != null && match.isNotEmpty ? match : p.id;
      if (match == null || match.isEmpty) {
        while (reserved.contains(id)) {
          id = sheetHash(
            '${current.id}/${teachingVersion(incoming.source)}/new/$id',
          );
        }
        reserved.add(id);
      }
      phases.add(p.patch({'id': id}));
    }
    return ImportedTeachingFlow(incoming.source, phases, incoming.issues);
  }
}
