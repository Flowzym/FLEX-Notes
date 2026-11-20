import 'package:flutter/material.dart';
import '../domain/classroom.dart';
import '../domain/planning_import.dart';
import 'common.dart';
import 'flex_modal.dart';

/// Empty updates defer the decision. An explicit selection also remembers
/// the unchecked rows, so a later background import respects that choice.
Future<List<ClassroomDocument>?> reviewPupilBacklog(
  BuildContext context,
  String pupil,
  String name,
  List<ClassroomDocument> matches,
) {
  final selected = <String>{};
  return showDialog<List<ClassroomDocument>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: Text('Vorhandene Dateien für $name'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${matches.length} passende Dateien. Wähle die Materialien aus, die zu $name gehören.',
            ),
            CheckboxListTile(
              title: const Text('Alle auswählen'),
              value: selected.length == matches.length,
              onChanged: (v) => update(() {
                selected.clear();
                if (v == true) selected.addAll(matches.map((d) => d.id));
              }),
            ),
            for (final d in matches)
              CheckboxListTile(
                value: selected.contains(d.id),
                title: Text(d.title),
                subtitle: Text(
                  [
                    planningUses[teachingUse(d)],
                    if (teachingDay(d).isNotEmpty) displayDate(teachingDay(d)),
                  ].nonNulls.join(' · '),
                ),
                onChanged: (v) => update(() {
                  if (v == true) {
                    selected.add(d.id);
                  } else {
                    selected.remove(d.id);
                  }
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, <ClassroomDocument>[]),
            child: const Text('Später prüfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, [
              for (final d in matches)
                decidePlanningPupils(
                  d,
                  [pupil],
                  [if (selected.contains(d.id)) pupil],
                ),
            ]),
            child: Text('Auswahl übernehmen (${selected.length})'),
          ),
        ],
      ),
    ),
  );
}
