part of 'material_library.dart';

Future<void> prepareForDate(
  BuildContext context,
  NotebookController c,
  Iterable<String> ids, {
  String? initialDate,
}) async {
  final result = await pickFlexDate(
    context,
    date: initialDate ?? dateOnly(DateTime.now()),
    allowTime: false,
  );
  if (result == null || !context.mounted) return;
  await c.saveClassroom(prepareMaterials(c.classroom, result.$1, ids));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Für ${displayDate(result.$1)} bereitgelegt')),
    );
  }
}

/// Compact, directly opening rows. Selection and metadata editing never open files.
class MaterialRow extends StatefulWidget {
  const MaterialRow({
    super.key,
    required this.material,
    required this.onOpen,
    this.onEdit,
    this.onFavorite,
    this.selected,
    this.onSelect,
    this.trailing,
    this.files = const LocalMaterialFiles(),
  });
  final ClassroomDocument material;
  final VoidCallback onOpen;
  final VoidCallback? onEdit, onFavorite;
  final bool? selected;
  final ValueChanged<bool>? onSelect;
  final Widget? trailing;
  final MaterialFiles files;
  @override
  State<MaterialRow> createState() => _MaterialRowState();
}

class _MaterialRowState extends State<MaterialRow> {
  late Future<bool> available = check();
  Future<bool> check() => materialDeviceAvailable
      ? widget.files
            .exists(widget.material.text('localKey'))
            .catchError((Object _) => false)
      : Future.value(false);
  @override
  void didUpdateWidget(MaterialRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.material.text('localKey') !=
        widget.material.text('localKey')) {
      available = check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.material;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainer.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.selected != null)
              Checkbox(
                value: widget.selected,
                onChanged: (v) => widget.onSelect?.call(v == true),
              ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.selected == null
                    ? widget.onOpen
                    : () => widget.onSelect?.call(!widget.selected!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      MaterialThumbnail(material: d, files: widget.files),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              [
                                d.text('extension').toUpperCase(),
                                d.text('subject'),
                                if (d.text('documentType', 'other') != 'other')
                                  materialTypes[d.text('documentType')]!,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            FutureBuilder<bool>(
                              future: available,
                              builder: (_, s) => Text(
                                s.data == true
                                    ? 'Offline verfügbar'
                                    : d.text('url').isEmpty
                                    ? 'Datei auf diesem Gerät nicht verfügbar'
                                    : 'Online',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.selected == null && widget.onFavorite != null)
              IconButton(
                tooltip: d.flag('favorite')
                    ? 'Favorit entfernen'
                    : 'Als Favorit merken',
                onPressed: widget.onFavorite,
                icon: Icon(d.flag('favorite') ? Icons.star : Icons.star_border),
              ),
            if (widget.selected == null && widget.onEdit != null)
              IconButton(
                tooltip: 'Materialangaben und Aktionen',
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ?widget.trailing,
          ],
        ),
      ),
    );
  }
}

Future<void> showMaterialDetails(
  BuildContext context,
  NotebookController c,
  ClassroomDocument material, {
  OneDriveClient? drive,
}) async {
  await showFlexDetail<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final d =
            c.classroom.where((m) => m.id == material.id).firstOrNull ??
            material;
        return FlexModal(
          title: Text(d.title),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MaterialThumbnail(material: d, width: 96, height: 120),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilledButton.icon(
                    onPressed: () => guarded(
                      ctx,
                      () => openMaterial(ctx, c, d, drive: drive),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Öffnen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => guarded(ctx, () async {
                      final links = await chooseDocumentLinks(
                        ctx,
                        c,
                        d.rows('links').map(DocumentLink.fromJson).toList(),
                      );
                      if (links != null) {
                        await c.saveClassroom(
                          d.patch({
                            'links': links.map((l) => l.toJson()).toList(),
                            'pupilIds': {
                              ...d.strings('pupilIds'),
                              ...documentLinkPupils(c, links),
                            }.toList(),
                          }),
                        );
                      }
                    }),
                    icon: const Icon(Icons.link),
                    label: const Text('Einträge zuordnen'),
                  ),
                  if ({'pdf', 'jpg'}.contains(d.text('extension')) &&
                      d.text('localKey').isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () =>
                          scanAndShow(ctx, c, const ScanContext(), source: d),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text(
                        d.text('extension') == 'jpg'
                            ? 'Foto bearbeiten'
                            : 'PDF bearbeiten',
                      ),
                    ),
                  if (d.text('localKey').isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => guarded(ctx, () async {
                        final bytes = await const LocalMaterialFiles().read(
                          d.text('localKey'),
                        );
                        await saveBytesFile(
                          d.text('name', '${d.title}.${d.text('extension')}'),
                          bytes,
                          mime: d.text('extension') == 'pdf'
                              ? 'application/pdf'
                              : d.text('extension') == 'jpg'
                              ? 'image/jpeg'
                              : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                        );
                      }),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Teilen / Exportieren'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => showClassroomEditor(
                      ctx,
                      c,
                      ClassroomKind.material,
                      document: d,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Angaben bearbeiten'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        guarded(ctx, () => prepareForDate(ctx, c, [d.id])),
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Bereitlegen'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                [
                  materialTypes[d.text('documentType', 'other')]!,
                  materialAudiences[d.text('audience', 'all')]!,
                  d.text('subject'),
                  d.text('topic'),
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              for (final link in d.rows('links').map(DocumentLink.fromJson))
                Text(documentLinkLabel(c, link)),
              if (d.flag('scan')) Text('${d.number('pageCount')} Seiten · PDF'),
              if (d.strings('pupilIds').isNotEmpty)
                Text(
                  c.pupils
                      .where((p) => d.strings('pupilIds').contains(p.id))
                      .map((p) => p.name)
                      .join(', '),
                ),
              if (d.strings('tags').isNotEmpty)
                Text(d.strings('tags').join(' · ')),
              if (d.text('note').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(d.text('note')),
                ),
              if (d.text('sourcePath').isNotEmpty)
                Text(
                  d.text('sourcePath'),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              if (materialDeviceAvailable && d.text('itemId').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => guarded(ctx, () async {
                    final client = drive ?? OneDriveClient();
                    try {
                      if (drive == null) await client.load();
                      await cacheMaterial(
                        c,
                        d,
                        client,
                        const LocalMaterialFiles(),
                      );
                    } finally {
                      if (drive == null) client.dispose();
                    }
                  }),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Offline laden / aktualisieren'),
                ),
              if (materialDeviceAvailable &&
                  d.text('localKey').isNotEmpty &&
                  d.text('url').isNotEmpty)
                TextButton.icon(
                  onPressed: () => guarded(ctx, () async {
                    await c.saveClassroom(d.patch({'localKey': ''}));
                    await removeUnusedMaterialFile(
                      c,
                      const LocalMaterialFiles(),
                      d.text('localKey'),
                    );
                  }),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Offlinekopie entfernen'),
                ),
              const Divider(),
              TextButton.icon(
                onPressed: () => guarded(ctx, () async {
                  await c.saveClassroom(d.patch({'deleted': !d.deleted}));
                  if (ctx.mounted) Navigator.pop(ctx);
                }),
                icon: Icon(d.deleted ? Icons.restore : Icons.delete_outline),
                label: Text(
                  d.deleted
                      ? 'Material wiederherstellen'
                      : 'Material in Papierkorb',
                ),
              ),
              if (d.text('itemId').isNotEmpty || d.text('url').isNotEmpty)
                const Text('Die Originaldatei in OneDrive bleibt erhalten.'),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> showPreparedMaterials(
  BuildContext context,
  NotebookController c, {
  String? date,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _PreparedMaterials(controller: c, date: date ?? dateOnly(DateTime.now())),
);

class _PreparedMaterials extends StatefulWidget {
  const _PreparedMaterials({required this.controller, required this.date});
  final NotebookController controller;
  final String date;
  @override
  State<_PreparedMaterials> createState() => _PreparedMaterialsState();
}

class _PreparedMaterialsState extends State<_PreparedMaterials> {
  late String date = widget.date;
  bool busy = false;
  NotebookController get c => widget.controller;
  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(context, operation);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final doc = preparationFor(c.classroom, date);
      final ids = doc.strings('materialIds');
      final materials = resolveMaterials(c.classroom, ids);
      final suggestions = suggestedMaterials(c.classroom, date);
      return FlexModal(
        title: const Text('Bereitgelegt'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Voriger Tag',
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => date = dateOnly(
                            schoolDay(date).subtract(const Duration(days: 1)),
                          ),
                        ),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final result = await pickFlexDate(
                            ctx,
                            date: date,
                            allowTime: false,
                          );
                          if (result != null && mounted) {
                            setState(() => date = result.$1);
                          }
                        },
                  child: Text(displayDate(date)),
                ),
                IconButton(
                  tooltip: 'Nächster Tag',
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => date = dateOnly(
                            schoolDay(date).add(const Duration(days: 1)),
                          ),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final chosen = await chooseMaterials(ctx, c, ids);
                          if (chosen != null) {
                            await c.saveClassroom(
                              doc.patch({
                                'materialIds': chosen,
                                'deleted': false,
                              }),
                            );
                          }
                        }),
                  icon: const Icon(Icons.add),
                  label: const Text('Dateien / Paket'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      busy || materials.isEmpty || !materialDeviceAvailable
                      ? null
                      : () => run(() => cacheMaterials(ctx, c, materials)),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Offline laden'),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (materials.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Für diesen Tag ist noch nichts bereitgelegt.'),
              ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: materials.length,
              onReorderItem: (from, to) {
                if (busy) return;
                // Keep hidden trash references intact; reorder only visible references.
                final visible = materials.map((m) => m.id).toList();
                visible.insert(to, visible.removeAt(from));
                var index = 0;
                final active = visible.toSet();
                final next = [
                  for (final id in ids)
                    if (active.contains(id)) visible[index++] else id,
                ];
                run(() => c.saveClassroom(doc.patch({'materialIds': next})));
              },
              itemBuilder: (_, i) => MaterialRow(
                key: ValueKey(materials[i].id),
                material: materials[i],
                onOpen: () => run(() => openMaterial(ctx, c, materials[i])),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Vom Tag entfernen',
                      onPressed: busy
                          ? null
                          : () => run(
                              () => c.saveClassroom(
                                doc.patch({
                                  'materialIds': ids
                                      .where((id) => id != materials[i].id)
                                      .toList(),
                                }),
                              ),
                            ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (ids.length > materials.length)
              const Text('Dateien im Papierkorb werden hier ausgeblendet.'),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Passend zu Unterricht und Wochenplanung',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              for (final m in suggestions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.title),
                  leading: const Icon(Icons.description_outlined),
                  trailing: IconButton(
                    tooltip: 'Zum Tag hinzufügen',
                    onPressed: busy
                        ? null
                        : () => run(
                            () => c.saveClassroom(
                              prepareMaterials(c.classroom, date, [m.id]),
                            ),
                          ),
                    icon: const Icon(Icons.add),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

Future<void> cacheMaterials(
  BuildContext context,
  NotebookController c,
  List<ClassroomDocument> materials, {
  OneDriveClient? drive,
}) async {
  final client = drive ?? OneDriveClient();
  var cached = 0;
  final failed = <String>[];
  try {
    if (drive == null) await client.load();
    for (final m in materials) {
      try {
        if (m.text('itemId').isNotEmpty) {
          await cacheMaterial(c, m, client, const LocalMaterialFiles());
        } else if (!await const LocalMaterialFiles().exists(
          m.text('localKey'),
        )) {
          throw const DomainError('Nur als Link verfügbar');
        }
        cached++;
      } catch (_) {
        failed.add(m.title);
      }
    }
  } finally {
    if (drive == null) client.dispose();
  }
  if (context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => FlexModal(
        title: const Text('Offline verfügbar'),
        onClose: () => Navigator.pop(ctx),
        content: Text(
          '$cached von ${materials.length} Dateien auf diesem Gerät.'
          '${failed.isEmpty ? '' : '\n\nNicht geladen:\n${failed.join('\n')}\n\nVerbindung und OneDrive-Anmeldung prüfen; reine Links lassen sich nicht herunterladen.'}',
        ),
      ),
    );
  }
}

Future<void> showMaterialCollection(
  BuildContext context,
  NotebookController c,
  ClassroomDocument document,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final d =
          c.classroom.where((m) => m.id == document.id).firstOrNull ?? document;
      final materials = resolveMaterials(c.classroom, {
        ...d.strings('materialIds'),
        ...linkedMaterials(c.classroom, d.id).map((m) => m.id),
      });
      return FlexModal(
        title: Text(d.title),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.kind == ClassroomKind.plan) ...[
              Text(
                [
                  planStatuses[d.text('status', 'planned')]!,
                  if (d.text('date').isNotEmpty) displayDate(d.text('date')),
                  if (d.text('endDate').isNotEmpty)
                    'bis ${displayDate(d.text('endDate'))}',
                ].join(' · '),
              ),
              if (d.strings('lessonIds').isNotEmpty)
                Text(
                  'Unterricht: ${c.classroom.where((l) => d.strings('lessonIds').contains(l.id)).map((l) => l.title).join(', ')}',
                ),
            ],
            if (d.text('note').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(d.text('note')),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                DocumentAttachmentsButton(
                  showPreviews: false,
                  controller: c,
                  scope: ScanContext(
                    links: [DocumentLink('classroom', d.id)],
                    pupilIds: d.strings('pupilIds'),
                    title: d.title,
                    category: 'planning',
                    subject: d.text('subject'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: materials.isEmpty
                      ? null
                      : () => guarded(
                          ctx,
                          () => prepareForDate(
                            ctx,
                            c,
                            materials.map((m) => m.id),
                          ),
                        ),
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('Bereitlegen'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      showClassroomEditor(ctx, c, d.kind, document: d),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Bearbeiten'),
                ),
                OutlinedButton.icon(
                  onPressed: materials.isEmpty || !materialDeviceAvailable
                      ? null
                      : () => guarded(
                          ctx,
                          () => cacheMaterials(ctx, c, materials),
                        ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Offline laden'),
                ),
              ],
            ),
            if (materials.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Noch keine Dateien zugeordnet.'),
              ),
            for (final m in materials)
              MaterialRow(
                material: m,
                onOpen: () => guarded(ctx, () => openMaterial(ctx, c, m)),
              ),
            if (d.kind == ClassroomKind.plan &&
                d.text('followUp').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Nachbereitung', style: Theme.of(ctx).textTheme.titleSmall),
              Text(d.text('followUp')),
            ],
            const Divider(),
            TextButton.icon(
              onPressed: () => guarded(ctx, () async {
                await c.saveClassroom(d.patch({'deleted': !d.deleted}));
                if (ctx.mounted) Navigator.pop(ctx);
              }),
              icon: Icon(d.deleted ? Icons.restore : Icons.delete_outline),
              label: Text(
                d.deleted
                    ? '${d.label} wiederherstellen'
                    : '${d.label} in Papierkorb',
              ),
            ),
            const Text('Zugeordnete Dateien bleiben erhalten.'),
          ],
        ),
      );
    },
  ),
);

Future<void> showPupilMaterials(
  BuildContext context,
  NotebookController c,
  Pupil pupil,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final direct = c.classroom.where(
        (d) =>
            !d.deleted &&
            d.kind == ClassroomKind.material &&
            d.strings('pupilIds').contains(pupil.id),
      );
      final collections = c.classroom.where(
        (d) =>
            !d.deleted &&
            (d.kind == ClassroomKind.materialSet ||
                d.kind == ClassroomKind.plan) &&
            d.strings('pupilIds').contains(pupil.id),
      );
      return FlexModal(
        title: Text('${pupil.name} · Unterlagen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => scanAndShow(
                    ctx,
                    c,
                    ScanContext(
                      pupilIds: [pupil.id],
                      title: pupil.name,
                      category: 'pupilWork',
                    ),
                  ),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scannen'),
                ),
                DocumentAttachmentsButton(
                  showPreviews: false,
                  controller: c,
                  scope: ScanContext(
                    pupilIds: [pupil.id],
                    title: pupil.name,
                    category: 'pupilWork',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => guarded(ctx, () async {
                    final baseline = c.classroom
                        .where(
                          (d) => !d.deleted && d.kind == ClassroomKind.material,
                        )
                        .toList();
                    final ids = await chooseMaterials(
                      ctx,
                      c,
                      direct.map((d) => d.id).toList(),
                    );
                    if (ids == null) return;
                    final changes = <ClassroomDocument>[];
                    for (final d in baseline) {
                      final pupils = d.strings('pupilIds').toSet();
                      if (ids.contains(d.id) != pupils.contains(pupil.id)) {
                        if (ids.contains(d.id)) {
                          pupils.add(pupil.id);
                        } else {
                          pupils.remove(pupil.id);
                        }
                        changes.add(d.patch({'pupilIds': pupils.toList()}));
                      }
                    }
                    await c.repository.saveClassroomDocuments(changes);
                    await c.reload();
                  }),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Dateien zuordnen'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showClassroomEditor(
                    ctx,
                    c,
                    ClassroomKind.plan,
                    fields: {
                      'pupilIds': [pupil.id],
                    },
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Planung'),
                ),
              ],
            ),
            if (direct.isEmpty && collections.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Noch keine Unterlagen zugeordnet.'),
              ),
            for (final d in direct)
              MaterialRow(
                material: d,
                onOpen: () => guarded(ctx, () => openMaterial(ctx, c, d)),
                trailing: IconButton(
                  tooltip: 'Schülerzuordnung entfernen',
                  icon: const Icon(Icons.link_off),
                  onPressed: () => guarded(
                    ctx,
                    () => c.saveClassroom(
                      d.patch({
                        'pupilIds': d
                            .strings('pupilIds')
                            .where((id) => id != pupil.id)
                            .toList(),
                      }),
                    ),
                  ),
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
  ),
);

class PreparedMaterialsTile extends StatelessWidget {
  const PreparedMaterialsTile({
    super.key,
    required this.controller,
    required this.date,
  });
  final NotebookController controller;
  final String date;
  @override
  Widget build(BuildContext context) {
    final count = resolveMaterials(
      controller.classroom,
      preparationFor(controller.classroom, date).strings('materialIds'),
    ).length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.folder_open_outlined),
      title: Text(
        count == 0
            ? 'Unterlagen bereitlegen'
            : '$count Unterlagen bereitgelegt',
      ),
      subtitle: Text(displayDate(date)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showPreparedMaterials(context, controller, date: date),
    );
  }
}
