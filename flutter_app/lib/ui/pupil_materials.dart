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
  String query = '';
  bool searching = false, selecting = false;
  final selected = <String>{};
  void endSelection() {
    selected.clear();
    selecting = false;
  }

  void mark(String id, bool value) => setState(() {
    selecting = true;
    if (value) {
      selected.add(id);
    } else {
      selected.remove(id);
    }
  });
  Future<void> changeSelected(
    List<ClassroomDocument> docs, {
    required bool unlink,
  }) => run(() async {
    String? date;
    if (unlink) {
      if (!await confirmFlex(
        context,
        'Zuordnung entfernen?',
        '${docs.length} Materialien aus der Übersicht von ${pupil.name} entfernen?',
        accept: 'Entfernen',
      )) {
        return;
      }
    } else {
      date = (await pickFlexDate(
        context,
        date: dateOnly(DateTime.now()),
        allowTime: false,
        title: 'Unterrichtstermin für ${pupil.name}',
      ))?.$1;
      if (date == null || date.isEmpty) return;
    }
    await c.saveClassroomBatch([
      for (final d in docs)
        if (unlink)
          d.patch({
            'pupilIds': d
                .strings('pupilIds')
                .where((id) => id != pupil.id)
                .toList(),
          })
        else
          planPupilMaterial(d, pupil.id, date!),
    ]);
    if (mounted) setState(endSelection);
  });
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(context, work);
    if (mounted) setState(() => busy = false);
  }

  Future<void> assign() => run(() async {
    final ids = await chooseMaterials(context, c, []);
    if (ids == null || ids.isEmpty || !mounted) return;
    final materials = resolveMaterials(c.classroom, ids);
    await showMaterialAssignments(context, c, materials, pupil: pupil);
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
      final today = dateOnly(DateTime.now());
      String nextDate(ClassroomDocument d) =>
          pupilMaterialDates(
            d,
            pupil.id,
          ).where((date) => date.compareTo(today) >= 0).firstOrNull ??
          '9999';
      final direct =
          c.classroom
              .where(
                (d) =>
                    !d.deleted &&
                    d.kind == ClassroomKind.material &&
                    d.strings('pupilIds').contains(pupil.id) &&
                    materialMatches(d, query, pupils: c.pupils),
              )
              .toList()
            ..sort((a, b) {
              final ad = nextDate(a);
              final bd = nextDate(b);
              return ad == bd ? a.title.compareTo(b.title) : ad.compareTo(bd);
            });
      final collections = c.classroom.where(
        (d) =>
            !d.deleted &&
            (d.kind == ClassroomKind.materialSet ||
                d.kind == ClassroomKind.plan) &&
            d.strings('pupilIds').contains(pupil.id) &&
            materialMatches(d, query, pupils: c.pupils),
      );
      final scope = ScanContext(
        pupilIds: [pupil.id],
        title: pupil.name,
        category: 'pupilWork',
      );
      final chosen = direct.where((d) => selected.contains(d.id)).toList();
      final all = direct.isNotEmpty && chosen.length == direct.length;
      return FlexModal(
        headerActions: [
          IconButton(
            tooltip: 'Material-Explorer öffnen',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () => showAssignedMaterials(ctx, c, pupil: pupil),
          ),
          if (direct.isNotEmpty && !selecting)
            IconButton(
              tooltip: 'Mehrere Materialien auswählen',
              onPressed: busy ? null : () => setState(() => selecting = true),
              icon: const Icon(Icons.checklist),
            ),
        ],
        actions: selecting
            ? [
                TextButton.icon(
                  onPressed: busy || chosen.isEmpty
                      ? null
                      : () => changeSelected(chosen, unlink: true),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Zuordnung lösen'),
                ),
                FilledButton.icon(
                  onPressed: busy || chosen.isEmpty
                      ? null
                      : () => changeSelected(chosen, unlink: false),
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Unterricht planen'),
                ),
              ]
            : [],
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
            if (selecting)
              SelectionControls(
                count: chosen.length,
                allVisibleSelected: all,
                onFinish: busy ? null : () => setState(endSelection),
                onToggleAll: busy || direct.isEmpty
                    ? null
                    : () => setState(() {
                        if (all) {
                          selected.removeAll(direct.map((d) => d.id));
                        } else {
                          selected.addAll(direct.map((d) => d.id));
                        }
                      }),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('pupil-assign-materials'),
                    onPressed: busy ? null : assign,
                    icon: const Icon(Icons.add),
                    label: const Text('Zuordnen'),
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
                  IconButton(
                    tooltip: 'Materialien durchsuchen',
                    onPressed: () => setState(() => searching = !searching),
                    icon: const Icon(Icons.search),
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
            if (searching || query.isNotEmpty)
              TextField(
                key: const ValueKey('pupil-material-search'),
                controller: search,
                decoration: InputDecoration(
                  hintText: 'Materialien durchsuchen',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Suche löschen',
                    onPressed: () => setState(() {
                      search.clear();
                      query = '';
                      searching = false;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            if (direct.isEmpty && collections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  query.isEmpty
                      ? 'Noch keine Materialien zugeordnet.'
                      : 'Keine passenden Materialien.',
                ),
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
                      selected: selecting
                          ? selected.contains(material.id)
                          : null,
                      onSelect: busy ? null : (v) => mark(material.id, v),
                      onOpen: () => run(() => openMaterial(ctx, c, material)),
                      onEdit: () => showMaterialDetails(ctx, c, material),
                      trailing: selecting
                          ? null
                          : IconButton(
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
                    if (!selecting)
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (pupilMaterialDates(material, pupil.id).isEmpty)
                            TextButton.icon(
                              key: ValueKey(
                                'pupil-material-plan-${material.id}',
                              ),
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
            if (!selecting)
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
