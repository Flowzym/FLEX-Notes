part of 'material_library.dart';

Future<void> showPupilMaterials(
  BuildContext context,
  NotebookController c,
  Pupil pupil,
) => showDialog<void>(
  context: context,
  builder: (_) => _PupilMaterials(controller: c, pupil: pupil),
);

class _PupilMaterials extends StatefulWidget {
  const _PupilMaterials({required this.controller, required this.pupil});
  final NotebookController controller;
  final Pupil pupil;
  @override
  State<_PupilMaterials> createState() => _PupilMaterialsState();
}

class _PupilMaterialsState extends State<_PupilMaterials> {
  NotebookController get c => widget.controller;
  Pupil get pupil => widget.pupil;
  bool busy = false;

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(context, work);
    if (mounted) setState(() => busy = false);
  }

  Future<void> assign() => run(() async {
    final ids = await chooseMaterials(context, c, []);
    if (ids == null || ids.isEmpty || !mounted) return;
    final date = await pickFlexDate(
      context,
      date: dateOnly(DateTime.now()),
      allowTime: false,
      allowDateClear: false,
      title: 'Im Unterricht geplant',
    );
    if (date == null || !mounted) return;
    final materials = resolveMaterials(c.classroom, ids);
    await c.repository.saveClassroomDocuments([
      for (final material in materials)
        planPupilMaterial(material, pupil.id, date.$1),
    ]);
    await c.reload();
  });

  Future<void> plan(
    ClassroomDocument material, {
    String? previous,
  }) => run(() async {
    final date = await pickFlexDate(
      context,
      date: previous ?? dateOnly(DateTime.now()),
      allowTime: false,
      allowDateClear: previous != null,
      title: 'Im Unterricht geplant',
    );
    if (date == null || !mounted) return;
    // Keep the original revision: an external edit must be reviewed, not overwritten.
    await c.saveClassroom(
      date.$1.isEmpty
          ? material.patch({
              'pupilDates': [
                for (final row in material.rows('pupilDates'))
                  if (!(row['pupilId'] == pupil.id && row['date'] == previous))
                    row,
              ],
            })
          : planPupilMaterial(
              material,
              pupil.id,
              date.$1,
              replaceDate: previous,
            ),
    );
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final direct =
          c.classroom
              .where(
                (d) =>
                    !d.deleted &&
                    d.kind == ClassroomKind.material &&
                    d.strings('pupilIds').contains(pupil.id),
              )
              .toList()
            ..sort((a, b) {
              final ad = pupilMaterialDates(a, pupil.id).firstOrNull ?? '9999';
              final bd = pupilMaterialDates(b, pupil.id).firstOrNull ?? '9999';
              return ad == bd ? a.title.compareTo(b.title) : ad.compareTo(bd);
            });
      final collections = c.classroom.where(
        (d) =>
            !d.deleted &&
            (d.kind == ClassroomKind.materialSet ||
                d.kind == ClassroomKind.plan) &&
            d.strings('pupilIds').contains(pupil.id),
      );
      final scope = ScanContext(
        pupilIds: [pupil.id],
        title: pupil.name,
        category: 'pupilWork',
      );
      return FlexModal(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pupil.name, style: Theme.of(ctx).textTheme.bodySmall),
            const Text('Materialien'),
          ],
        ),
        onClose: busy ? null : () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  key: const ValueKey('pupil-assign-materials'),
                  onPressed: busy ? null : assign,
                  icon: const Icon(Icons.add),
                  label: const Text('Material zuordnen'),
                ),
                IconButton(
                  tooltip: 'Scannen',
                  onPressed: busy
                      ? null
                      : () => run(() => scanAndShow(ctx, c, scope)),
                  icon: const Icon(Icons.document_scanner_outlined),
                ),
                IconButton(
                  tooltip: 'Dokumente / Dateien hinzufügen',
                  onPressed: busy
                      ? null
                      : () => showContextDocuments(ctx, c, scope),
                  icon: const Icon(Icons.attach_file),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => showClassroomEditor(
                          ctx,
                          c,
                          ClassroomKind.plan,
                          fields: {
                            'pupilIds': [pupil.id],
                          },
                        ),
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Planung'),
                ),
              ],
            ),
            if (direct.isEmpty && collections.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Noch keine Materialien zugeordnet.'),
              ),
            for (final material in direct)
              Padding(
                key: ValueKey('pupil-material-${material.id}'),
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MaterialRow(
                      material: material,
                      onOpen: () => run(() => openMaterial(ctx, c, material)),
                      trailing: IconButton(
                        tooltip: 'Schülerzuordnung entfernen',
                        icon: const Icon(Icons.link_off),
                        onPressed: busy
                            ? null
                            : () => run(
                                () => c.saveClassroom(
                                  material.patch({
                                    'pupilIds': material
                                        .strings('pupilIds')
                                        .where((id) => id != pupil.id)
                                        .toList(),
                                  }),
                                ),
                              ),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (pupilMaterialDates(material, pupil.id).isEmpty)
                          TextButton.icon(
                            key: ValueKey('pupil-material-plan-${material.id}'),
                            onPressed: busy ? null : () => plan(material),
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: const Text('Unterricht planen'),
                          ),
                        for (final date in pupilMaterialDates(
                          material,
                          pupil.id,
                        ))
                          TextButton.icon(
                            key: ValueKey(
                              'pupil-material-date-${material.id}-$date',
                            ),
                            onPressed: busy
                                ? null
                                : () => plan(material, previous: date),
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: Text('Geplant: ${displayDate(date)}'),
                          ),
                        if (pupilMaterialDates(material, pupil.id).isNotEmpty)
                          IconButton(
                            tooltip: 'Weiteren Unterrichtstermin planen',
                            onPressed: busy ? null : () => plan(material),
                            icon: const Icon(Icons.add, size: 18),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            for (final d in collections)
              ListTile(
                leading: Icon(
                  d.kind == ClassroomKind.plan
                      ? Icons.event_note_outlined
                      : Icons.folder_copy_outlined,
                ),
                title: Text(d.title),
                subtitle: Text(d.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showMaterialCollection(ctx, c, d),
              ),
          ],
        ),
      );
    },
  );
}
