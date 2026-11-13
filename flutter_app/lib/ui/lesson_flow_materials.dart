part of 'lesson_flow_page.dart';

extension _FlowMaterials on _LessonFlowPageState {
  Future<void> showMaterials(
    ClassroomDocument baseline, {
    String? phaseId,
  }) async {
    var query = '', all = false, saving = false;
    final owner = lessonFlowPupil(baseline);
    ClassroomDocument latest() =>
        c.classroom
            .where((d) => d.id == baseline.id && !d.deleted)
            .firstOrNull ??
        baseline;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AnimatedBuilder(
          animation: c,
          builder: (ctx, _) {
            final flow = latest();
            final assigned = <String>{
              for (final p in lessonPhases(flow))
                if (phaseId == null || p.id == phaseId) ...p.materialIds,
              if (phaseId == null)
                ...preparationFor(c.classroom, date).strings('materialIds'),
              if (phaseId == null && owner.isEmpty)
                ...suggestedMaterials(c.classroom, date).map((m) => m.id),
              if (phaseId == null && owner.isNotEmpty)
                for (final m in c.classroom)
                  if (pupilMaterialDates(m, owner).contains(date)) m.id,
            };
            final library = c.classroom
                .where((m) => !m.deleted && m.kind == ClassroomKind.material)
                .toList();
            final values = library
                .where(
                  (m) =>
                      (all || assigned.contains(m.id)) &&
                      '${m.title} ${m.text('subject')} ${m.strings('tags').join(' ')}'
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                )
                .toList();
            return FlexModal(
              title: Text(
                owner.isEmpty
                    ? 'Materialien zum Ablauf'
                    : 'Materialien · ${c.pupils.where((p) => p.id == owner).firstOrNull?.name ?? 'Schüler'}',
              ),
              onClose: saving ? null : () => Navigator.pop(ctx),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Material suchen',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => update(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Zugeordnet'),
                        selected: !all,
                        onSelected: (_) => update(() => all = false),
                      ),
                      ChoiceChip(
                        label: const Text('Alle Materialien'),
                        selected: all,
                        onSelected: (_) => update(() => all = true),
                      ),
                    ],
                  ),
                  if (values.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        all
                            ? 'Keine passenden Materialien.'
                            : 'Noch keine passenden Materialien zugeordnet.',
                      ),
                    ),
                  if (!all && assigned.isEmpty)
                    TextButton.icon(
                      onPressed: () => update(() => all = true),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Materialablage öffnen'),
                    ),
                  for (final m in values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: MaterialThumbnail(
                        material: m,
                        width: 36,
                        height: 48,
                      ),
                      title: Text(
                        m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => guarded(ctx, () => openMaterial(ctx, c, m)),
                      trailing: IconButton(
                        tooltip: 'Zuordnen: ${m.title}',
                        icon: const Icon(Icons.add_link),
                        onPressed: saving
                            ? null
                            : () async {
                                final snapshot = latest();
                                final selected =
                                    phaseId ??
                                    await showDialog<String>(
                                      context: ctx,
                                      builder: (picker) => FlexModal(
                                        title: const Text('Material zuordnen'),
                                        onClose: () => Navigator.pop(picker),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              title: Text(
                                                'Für ${displayDate(date)} bereitlegen',
                                              ),
                                              onTap: () =>
                                                  Navigator.pop(picker, 'day'),
                                            ),
                                            for (final p in lessonPhases(
                                              snapshot,
                                            ))
                                              ListTile(
                                                title: Text(p.title),
                                                onTap: () =>
                                                    Navigator.pop(picker, p.id),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                if (selected == null || !ctx.mounted) return;
                                update(() => saving = true);
                                await guarded(ctx, () async {
                                  if (selected == 'day') {
                                    final material = c.classroom.firstWhere(
                                      (d) => d.id == m.id,
                                    );
                                    await c.saveClassroom(
                                      owner.isEmpty
                                          ? prepareMaterials(
                                              c.classroom,
                                              date,
                                              [m.id],
                                            )
                                          : planPupilMaterial(
                                              material,
                                              owner,
                                              date,
                                            ),
                                    );
                                  } else {
                                    await c.saveClassroom(
                                      withLessonPhases(snapshot, [
                                        for (final p in lessonPhases(snapshot))
                                          p.id != selected
                                              ? p
                                              : p.patch({
                                                  'materialIds': {
                                                    ...p.materialIds,
                                                    m.id,
                                                  }.toList(),
                                                }),
                                      ]),
                                    );
                                  }
                                });
                                if (ctx.mounted) update(() => saving = false);
                              },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
