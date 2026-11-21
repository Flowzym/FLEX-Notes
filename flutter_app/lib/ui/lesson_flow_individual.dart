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
        pupils: c.pupils,
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
    final planned = {
      for (final d in c.classroom.where(
        (d) => d.kind == ClassroomKind.material && !d.deleted,
      ))
        d.id: d,
    };
    final nextMaterial =
        [
          for (final id in next?.materialIds ?? const <String>[]) ?planned[id],
        ].firstOrNull ??
        planned.values
            .where((m) => pupilMaterialDates(m, pupil.id).contains(date))
            .firstOrNull;
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
          if (next != null && next.body.trim().isNotEmpty)
            Text(next.body.trim()),
          if (next != null)
            for (final g in next.guidance)
              if ((g['body'] as String).trim().isNotEmpty)
                Text(g['body'] as String),
          if (next != null && next.resumeNote.isNotEmpty) Text(next.resumeNote),

          if (nextMaterial != null)
            TextButton.icon(
              onPressed: () => guarded(context, () => openFile(nextMaterial)),
              icon: const Icon(Icons.description_outlined),
              label: Text(
                nextMaterial.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => showMaterials(value),
                icon: const Icon(Icons.folder_open_outlined, size: 19),
                label: const Text('Materialien'),
              ),
              if (next != null)
                IconButton(
                  key: ValueKey('flow-pupil-live-${pupil.id}'),
                  tooltip: 'Live-Steuerung · $name',
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  onPressed: busy
                      ? null
                      : () => _showLiveControls(forPupil: pupil.id),
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
