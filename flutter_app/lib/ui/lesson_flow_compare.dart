part of 'lesson_flow_page.dart';

extension _FlowCompare on _LessonFlowPageState {
  Future<(Map<String, String>, Set<String>)?> comparePlan(
    TeachingFlowChanges changes,
  ) {
    final decisions = <String, String>{}, restore = <String>{};
    bool locked(LessonPhase p) =>
        p.status != 'open' || p.running || p.elapsed > 0;
    return showDialog<(Map<String, String>, Set<String>)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final matched = {...changes.matches, ...decisions};
          final remaining = changes.before.keys.where(
            (id) => !matched.containsValue(id),
          );
          final ready = changes.ambiguous.keys.every(decisions.containsKey);

          return FlexModal(
            title: const Text('Planänderungen vergleichen'),
            maxWidth: 730,
            onClose: () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  changes.incoming.source.title,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                for (final p in changes.incoming.phases)
                  Builder(
                    builder: (_) {
                      final id = matched[p.id],
                          previous = changes.held[id],
                          ambiguous = changes.ambiguous[p.id];
                      final same =
                          id != null &&
                          id.isNotEmpty &&
                          changes.unchanged(p, id);
                      final label = ambiguous != null && id == null
                          ? 'Zuordnung offen'
                          : id == null || id.isEmpty
                          ? 'Neu'
                          : previous == null
                          ? 'Lokal entfernt'
                          : same
                          ? 'Unverändert'
                          : locked(previous) || changes.locallyEdited(previous)
                          ? 'Bisheriger Stand bleibt erhalten'
                          : 'Geändert';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('$label · ${p.title}'),
                            subtitle: Text(
                              [
                                if (!same && previous != null)
                                  'Bisher · ${previous.body} · ${previous.minutes} Min.',
                                'Dokument · ${p.body} · ${p.minutes} Min.',
                              ].join('\n'),
                            ),
                          ),
                          if (id != null && id.isNotEmpty && previous == null)
                            CheckboxListTile(
                              value: restore.contains(id),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Fehlende Phase wieder aufnehmen',
                              ),
                              onChanged: (v) => update(() {
                                if (v == true) {
                                  restore.add(id);
                                } else {
                                  restore.remove(id);
                                }
                              }),
                            ),
                          if (changes.matches[p.id] case final original?
                              when changes.held[original] != null &&
                                  (!changes.unchanged(p, original) ||
                                      changes.locallyEdited(
                                        changes.held[original]!,
                                      )) &&
                                  (locked(changes.held[original]!) ||
                                      changes.locallyEdited(
                                        changes.held[original]!,
                                      )))
                            CheckboxListTile(
                              value: decisions[p.id] == '',
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Dokumentauftrag als zusätzliche offene Phase aufnehmen',
                              ),
                              onChanged: (v) => update(() {
                                if (v == true) {
                                  decisions[p.id] = '';
                                } else {
                                  decisions.remove(p.id);
                                }
                              }),
                            ),
                          if (ambiguous != null)
                            DropdownButtonFormField<String>(
                              key: ValueKey(p.id),
                              isExpanded: true,
                              initialValue: decisions[p.id],
                              decoration: const InputDecoration(
                                labelText: 'Zeile zuordnen',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Als neue Phase übernehmen'),
                                ),
                                for (final old in ambiguous.where(
                                  (key) =>
                                      key == decisions[p.id] ||
                                      !decisions.containsValue(key),
                                ))
                                  DropdownMenuItem(
                                    value: old,
                                    child: Text(
                                      changes.held[old] == null
                                          ? 'Lokal entfernte Phase'
                                          : '${changes.held[old]!.title} · ${changes.held[old]!.body}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  update(() => decisions[p.id] = v);
                                }
                              },
                            ),
                        ],
                      );
                    },
                  ),
                if (ready)
                  for (final id in remaining)
                    if (changes.held[id] != null)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Entfallen · ${changes.held[id]!.title}'),
                        subtitle: Text(
                          locked(changes.held[id]!) ||
                                  changes.locallyEdited(changes.held[id]!)
                              ? 'Der dokumentierte Stand bleibt im Ablauf.'
                              : changes.held[id]!.body,
                        ),
                      ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Zurück'),
              ),
              FilledButton(
                onPressed: ready
                    ? () => Navigator.pop(ctx, (decisions, restore))
                    : null,
                child: const Text('Übernehmen'),
              ),
            ],
          );
        },
      ),
    );
  }
}
