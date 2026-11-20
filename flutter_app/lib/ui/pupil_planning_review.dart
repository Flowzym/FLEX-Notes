import 'package:flutter/material.dart';
import '../domain/classroom.dart';
import '../domain/planning_import.dart';
import 'common.dart';
import 'flex_modal.dart';

Future<List<ClassroomDocument>?> reviewPupilBacklog(
  BuildContext context,
  String pupil,
  String name,
  List<ClassroomDocument> matches,
  PlanningRoster roster, {
  String? reviewedCode,
}) {
  final clear = {
    for (final d in matches)
      if (roster.match(d) case final m when m.clear && m.owners.contains(pupil))
        d.id,
  };
  final existing = {
    for (final d in matches)
      if (d.strings('pupilIds').contains(pupil)) d.id,
  };
  final selected = {...clear, ...existing};
  return showDialog<List<ClassroomDocument>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: Text('Vorhandene Dateien für $name'),
        onClose: () => Navigator.pop(ctx),
        scrollable: false,
        content: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .5,
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text('Alle auswählen'),
                subtitle: Text(
                  '${selected.length} von ${matches.length} ausgewählt',
                ),
                value: selected.isEmpty
                    ? false
                    : selected.length == matches.length
                    ? true
                    : null,
                tristate: true,
                onChanged: (_) => update(() {
                  if (selected.length == matches.length) {
                    selected.clear();
                  } else {
                    selected.addAll(matches.map((d) => d.id));
                  }
                }),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (_, i) {
                    final d = matches[i];
                    final prior =
                        d.flag('planningDismissed') ||
                        d.strings('planningDecisions').contains(pupil);
                    return CheckboxListTile(
                      value: selected.contains(d.id),
                      title: Text(d.title),
                      subtitle: Text(
                        [
                          if (existing.contains(d.id))
                            'Schon zugeordnet'
                          else if (prior)
                            'Früher übersprungen'
                          else if (!clear.contains(d.id))
                            'Bitte prüfen',
                          if (teachingDay(d).isNotEmpty)
                            displayDate(teachingDay(d))
                          else if (teachingWeek(d).isNotEmpty)
                            'Woche ab ${displayDate(teachingWeek(d))}'
                          else
                            planningUses[teachingUse(d)],
                        ].nonNulls.join(' · '),
                      ),
                      onChanged: existing.contains(d.id)
                          ? null
                          : (v) => update(() {
                              if (v == true) {
                                selected.add(d.id);
                              } else {
                                selected.remove(d.id);
                              }
                            }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, [
              for (final d in matches)
                if (roster.automaticOwners(d).contains(pupil))
                  d.patch({
                    'planningDeferred': {
                      ...d.strings('planningDeferred'),
                      pupil,
                    }.toList(),
                  }),
            ]),
            child: const Text('Später prüfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, [
              for (final d in matches)
                decidePlanningPupils(
                  d,
                  [pupil],
                  [if (selected.contains(d.id)) pupil],
                ).patch({
                  if (reviewedCode != null)
                    'planningReviewedCodes': {
                      ...d.strings('planningReviewedCodes'),
                      reviewedCode,
                    }.toList(),
                }),
            ]),
            child: Text('Auswahl übernehmen (${selected.length})'),
          ),
        ],
      ),
    ),
  );
}
