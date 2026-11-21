part of 'lesson_flow_page.dart';

extension _FlowTransfer on _LessonFlowPageState {
  Future<void> previewCarry(ClassroomDocument baseline, String day) async {
    final available = lessonOccurrences(
      c.classroom,
      day,
      day,
    ).where((l) => l.document.isTeachingLesson).toList();
    LessonOccurrence? selected;
    ClassroomDocument? chosen;
    int? position;
    final pending = lessonPhases(baseline).where((p) => p.pending).toList();
    final result = await showDialog<(ClassroomDocument, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final destination = carryDestination(
            c.classroom,
            day,
            pupils: c.pupils,
            pupilId: lessonFlowPupil(baseline),
            lesson: selected,
            chosenSource: chosen,
          );
          final phases = lessonPhases(destination);
          final candidates = dayCandidates(c.classroom, day, selected);
          final needsChoice =
              destination.revision == 0 &&
              destination.map('flow')['sourceId'] == null &&
              candidates.isNotEmpty;
          return FlexModal(
            title: Text('Weiterführen am ${displayDate(day)}'),
            onClose: () => Navigator.pop(ctx),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${pending.length} offene Phasen · ${pending.map((p) => p.title).join(' · ')}',
                ),
                if (available.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selected?.target ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Zielstunde'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Freier Tagesablauf'),
                      ),
                      for (final l in available)
                        DropdownMenuItem(
                          value: l.target,
                          child: Text(
                            '${l.start} · ${l.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => update(() {
                      selected = available
                          .where((l) => l.target == id)
                          .firstOrNull;
                      chosen = null;
                      position = null;
                    }),
                  ),
                if (needsChoice || chosen != null)
                  DropdownButtonFormField<String>(
                    key: ValueKey(selected?.target),
                    initialValue: chosen?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tagesplanung wählen',
                    ),
                    items: [
                      for (final m in candidates)
                        DropdownMenuItem(
                          value: m.id,
                          child: Text(m.title, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) => update(() {
                      chosen = candidates.firstWhere((x) => x.id == id);
                      position = null;
                    }),
                  ),
                const SizedBox(height: 12),
                Text(
                  phases.isEmpty
                      ? 'Bisher keine Phasen am Ziel.'
                      : 'Am Ziel bereits geplant',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                for (final p in phases)
                  Text(
                    '${p.title}${p.minutes > 0 ? ' · ${p.minutes} Min.' : ''}',
                  ),
                if (phases.isNotEmpty)
                  DropdownButtonFormField<int>(
                    key: ValueKey((destination.id, phases.length)),
                    initialValue: position ?? phases.length,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Offene Phasen einfügen',
                    ),
                    items: [
                      for (final (i, p) in phases.indexed)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            'Vor ${i + 1}. ${p.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      DropdownMenuItem(
                        value: phases.length,
                        child: const Text('Am Ende'),
                      ),
                    ],
                    onChanged: (v) => update(() => position = v),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: needsChoice
                    ? null
                    : () => Navigator.pop(ctx, (
                        destination,
                        position ?? phases.length,
                      )),
                child: const Text('Weiterführen'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) {
      await run(
        () => c.saveClassroomBatch(
          carryLessonPhases(
            baseline,
            result.$1,
            DateTime.now(),
            insertAt: result.$2,
          ),
        ),
      );
    }
  }
}
