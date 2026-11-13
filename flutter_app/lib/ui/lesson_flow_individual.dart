part of 'lesson_flow_page.dart';

extension _IndividualFlow on _LessonFlowPageState {
  ClassroomDocument pupilFlow(String id) {
    final base = shared;
    final key = '${base.id}|${base.revision}|$id';
    final initial = individualSeeds.putIfAbsent(
      key,
      () => lessonFlowFor(
        c.classroom,
        date,
        lesson: lesson,
        lessonTarget: target,
        pupilId: id,
        sharedFlow: base,
      ),
    );
    return c.classroom
            .where((d) => d.id == initial.id && !d.deleted)
            .firstOrNull ??
        initial;
  }

  Widget _scopeSelector() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        for (final choice in {false: 'Gemeinsam', true: 'Individuell'}.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                key: ValueKey('flow-scope-${choice.key}'),
                label: SizedBox(
                  width: double.infinity,
                  child: Text(choice.value, textAlign: TextAlign.center),
                ),
                selected: individual == choice.key,
                showCheckmark: false,
                onSelected: busy
                    ? null
                    : (_) => updateFlow(() {
                        individual = choice.key;
                        pupilId = null;
                        expanded = null;
                        editing = false;
                      }),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _pupilHeading() => Row(
    children: [
      IconButton(
        tooltip: 'Alle Schülerabläufe',
        icon: const Icon(Icons.arrow_back),
        onPressed: busy
            ? null
            : () => updateFlow(() {
                pupilId = null;
                expanded = null;
                editing = false;
              }),
      ),
      Expanded(
        child: Text(
          c.pupils.where((p) => p.id == pupilId).firstOrNull?.name ?? 'Schüler',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ],
  );

  List<Widget> _pupilRows() {
    final pupils = c.pupils.where((p) => !p.archived).toList();
    return [
      if (pupils.isEmpty) const EmptyState('Noch keine Schüler angelegt.'),
      for (final pupil in pupils) _pupilRow(pupil),
    ];
  }

  Widget _pupilRow(Pupil pupil) {
    final value = pupilFlow(pupil.id), phases = lessonPhases(value);
    final active = phases.where((p) => p.status == 'active').firstOrNull;
    final next = active ?? phases.where((p) => p.pending).firstOrNull;
    final name = pupil.name;
    void open() => updateFlow(() {
      pupilId = pupil.id;
      expanded = next?.id;
    });
    return Container(
      key: ValueKey('flow-pupil-${pupil.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              next == null
                  ? 'Abgeschlossen'
                  : '${next.title} · ${next.minutes} Min.${active == null
                        ? ''
                        : active.running
                        ? ' · Läuft'
                        : ' · Pausiert'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: open,
          ),
          if (active != null && active.minutes > 0) _PhaseClock(phase: active),
          Wrap(
            spacing: 4,
            children: [
              if (next != null)
                TextButton.icon(
                  key: ValueKey('flow-pupil-start-${pupil.id}'),
                  onPressed: busy
                      ? null
                      : () => save(
                          active == null
                              ? activateLessonPhase(
                                  value,
                                  next.id,
                                  DateTime.now(),
                                )
                              : finishLessonPhase(
                                  value,
                                  active.id,
                                  DateTime.now(),
                                ),
                        ),
                  icon: Icon(
                    active == null
                        ? Icons.play_arrow
                        : Icons.skip_next_outlined,
                    size: 19,
                  ),
                  label: Text(active == null ? 'Starten' : 'Weiter'),
                ),
              if (active != null)
                IconButton(
                  tooltip: '${active.running ? 'Pause' : 'Fortsetzen'} · $name',
                  onPressed: busy
                      ? null
                      : () => save(
                          withLessonPhases(value, [
                            for (final p in phases)
                              p.id != active.id
                                  ? p
                                  : p.running
                                  ? p.pause(DateTime.now())
                                  : p.patch({'startedAt': utcNow()}),
                          ]),
                        ),
                  icon: Icon(active.running ? Icons.pause : Icons.play_arrow),
                ),
              TextButton.icon(
                onPressed: () => showMaterials(value),
                icon: const Icon(Icons.folder_open_outlined, size: 19),
                label: const Text('Materialien'),
              ),
              IconButton(
                tooltip: 'Ablauf anpassen · $name',
                onPressed: busy ? null : open,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
