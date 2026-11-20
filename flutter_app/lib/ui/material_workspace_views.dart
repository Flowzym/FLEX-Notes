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
                onLongPress: widget.selected == null && widget.onSelect != null
                    ? () => widget.onSelect!(true)
                    : null,
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
                                if (teachingUse(d).isNotEmpty)
                                  planningUses[teachingUse(d)]!
                                else if (d.text('documentType', 'other') !=
                                    'other')
                                  materialTypes[d.text('documentType')]!,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            FutureBuilder<bool>(
                              future: available,
                              builder: (_, s) => Text(
                                s.data == true
                                    ? 'Offline verfügbar'
                                    : d.flag('sourceMissing')
                                    ? 'Quelle fehlt'
                                    : hasMaterialSource(d)
                                    ? 'Online'
                                    : 'Datei auf diesem Gerät nicht verfügbar',
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
        final folder = c.classroom
            .where((f) => isDriveRule(f) && f.id == d.text('cloudRule'))
            .firstOrNull;
        final lastSync = DateTime.tryParse(
          folder?.text('lastSync') ?? '',
        )?.toLocal();
        return FlexModal(
          title: Text(d.title),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MaterialThumbnail(material: d, width: 64, height: 84),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            {'jpg', 'png'}.contains(d.text('extension'))
                                ? 'Foto'
                                : d.text('extension').toUpperCase(),
                            materialTypes[d.text('documentType', 'other')]!,
                            if (d.text('audience', 'all') != 'all')
                              materialAudiences[d.text('audience')]!,
                            d.text('subject'),
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                        if (d.text('topic').isNotEmpty) Text(d.text('topic')),
                        if (d.strings('tags').isNotEmpty)
                          Text(
                            d.strings('tags').map((tag) => '#$tag').join(' '),
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        if (d.flag('scan'))
                          Text('${d.number('pageCount')} Seiten'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (d.map('planning').isNotEmpty) _PlanningDetails(c, d),
              ListTile(
                key: const ValueKey('material-detail-assign'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: const Text('Schüler & Einsatz'),
                subtitle: Text(
                  d.strings('pupilIds').isEmpty
                      ? 'Schüler zuordnen · Datum optional'
                      : [
                          for (final id in d.strings('pupilIds'))
                            [
                              c.pupils
                                      .where((p) => p.id == id)
                                      .firstOrNull
                                      ?.name ??
                                  'Nicht verfügbarer Schüler',
                              if (pupilMaterialDates(d, id).isNotEmpty)
                                pupilMaterialDates(
                                  d,
                                  id,
                                ).map(displayDate).join(', ')
                              else
                                'Ohne Einsatzdatum',
                            ].join(' · '),
                        ].join('\n'),
                ),
                trailing: d.deleted ? null : const Icon(Icons.chevron_right),
                onTap: d.deleted
                    ? null
                    : () => showMaterialAssignments(ctx, c, [d]),
              ),
              if (!d.deleted)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
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
              if (d.rows('links').isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final link in d.rows('links').map(DocumentLink.fromJson))
                  Text(
                    documentLinkLabel(c, link),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
              ],
              if (d.text('otherParticipants').isNotEmpty)
                Text('Weitere Namen: ${d.text('otherParticipants')}'),
              if (d.text('note').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(d.text('note')),
                ),
              const Divider(height: 24),
              if (d.flag('sourceMissing'))
                const Text('Die Quelle fehlt im verknüpften Ordner.'),
              if (uploadLabel(d).isNotEmpty) Text(uploadLabel(d)),
              Text('Datei', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
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
                  if (d.text('itemId').isNotEmpty &&
                      d.text('url').isNotEmpty &&
                      !d.flag('sourceMissing'))
                    OutlinedButton.icon(
                      onPressed: () =>
                          guarded(ctx, () => _launchMaterial(d.text('url'))),
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('In OneDrive öffnen'),
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
                      onPressed: () =>
                          guarded(ctx, () => shareMaterials(ctx, [d])),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Teilen'),
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
                          mime: materialMime(d.text('extension')),
                        );
                      }),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Exportieren'),
                    ),
                  if (d.rows('versions').isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => showMaterialVersions(ctx, c, d),
                      icon: const Icon(Icons.history),
                      label: Text('Versionen · ${d.rows('versions').length}'),
                    ),
                ],
              ),
              if (lastSync != null)
                Text(
                  'Ordnerabgleich am ${displayDate(dateOnly(lastSync))} · ${TimeOfDay.fromDateTime(lastSync).format(ctx)}',
                ),
              if (d.text('sourcePath').isNotEmpty)
                Text(
                  d.text('sourcePath'),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              if (materialDeviceAvailable &&
                  d.text('itemId').isNotEmpty &&
                  d.text('extension') != 'link')
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
              if (d.text('itemId').isNotEmpty &&
                  d.text('localKey').isNotEmpty) ...[
                if (DateTime.tryParse(d.text('cachedAt')) case final date?)
                  Text(
                    'Offline geladen am ${displayDate(dateOnly(date.toLocal()))}',
                  ),
                if (d.text('remoteName').isNotEmpty &&
                    (cloudExtension(d.text('remoteName')) !=
                            d.text('extension') ||
                        d.text('remoteEtag').isNotEmpty &&
                            d.text('remoteEtag') != d.text('etag') ||
                        d.text('remoteModifiedAt').isNotEmpty &&
                            d.text('remoteModifiedAt') !=
                                d.text('sourceModifiedAt')))
                  const Text('Neuere OneDrive-Fassung verfügbar'),
              ],
              if (materialDeviceAvailable &&
                  d.text('localKey').isNotEmpty &&
                  d.text('url').isNotEmpty)
                TextButton.icon(
                  onPressed: () => guarded(ctx, () async {
                    final name = d.text('remoteName');
                    await c.saveClassroom(
                      d.patch({
                        'localKey': '',
                        'etag': '',
                        'cachedAt': '',
                        if (name.isNotEmpty) ...{
                          'name': name,
                          'extension': cloudExtension(name),
                        },
                      }),
                    );
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
  String query = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => _PreparedMaterials(
    controller: c,
    date: date ?? dateOnly(DateTime.now()),
    query: query,
  ),
);

class _PreparedMaterials extends StatefulWidget {
  const _PreparedMaterials({
    required this.controller,
    required this.date,
    this.query = '',
  });
  final NotebookController controller;
  final String date;
  final String query;
  @override
  State<_PreparedMaterials> createState() => _PreparedMaterialsState();
}

class _PreparedMaterialsState extends State<_PreparedMaterials> {
  late String date = widget.date;
  late String query = widget.query;
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
      final ids = doc.deleted ? <String>[] : doc.strings('materialIds');
      final allMaterials = resolveMaterials(c.classroom, ids);
      bool matches(ClassroomDocument m) =>
          materialMatches(m, query, pupils: c.pupils);
      final materials = allMaterials.where(matches).toList();
      final scheduled = pupilMaterialsOnDay(
        c.classroom,
        date,
      ).where(matches).toList();
      final dayMaterials = preparedDayMaterials(c.classroom, date);
      final planned = dayMaterials
          .where(
            (d) =>
                teachingDay(d) == date &&
                !ids.contains(d.id) &&
                !scheduled.any((s) => s.id == d.id) &&
                matches(d),
          )
          .toList();
      final weekly = c.classroom
          .where(
            (d) =>
                !d.deleted &&
                d.kind == ClassroomKind.material &&
                teachingDay(d).isEmpty &&
                teachingWeek(d) == weekOfDay(date) &&
                !ids.contains(d.id) &&
                matches(d),
          )
          .toList();
      final suggestions = suggestedMaterials(c.classroom, date)
          .where(
            (m) =>
                matches(m) &&
                !dayMaterials.any((d) => d.id == m.id) &&
                !weekly.any((d) => d.id == m.id),
          )
          .toList();
      return FlexModal(
        title: const Text('Bereitgelegt'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (query.trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('Suche: $query'),
                  onDeleted: () => setState(() => query = ''),
                  deleteButtonTooltipMessage: 'Alle Materialien anzeigen',
                ),
              ),
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
              ],
            ),
            if (dayMaterials.isNotEmpty)
              PreparedOfflineStatus(
                key: ValueKey(date),
                controller: c,
                materials: dayMaterials,
                details: true,
              ),
            if (busy) const LinearProgressIndicator(),
            if (materials.isEmpty &&
                scheduled.isEmpty &&
                planned.isEmpty &&
                weekly.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  query.trim().isEmpty
                      ? 'Für diesen Tag ist noch nichts bereitgelegt.'
                      : 'Keine passenden Materialien an diesem Tag.',
                ),
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
            if (ids.length > allMaterials.length)
              const Text('Dateien im Papierkorb werden hier ausgeblendet.'),
            if (planned.isNotEmpty)
              _PlanningFiles(c, 'Für diesen Unterrichtstag', planned),
            if (weekly.isNotEmpty) _PlanningFiles(c, 'Für diese Woche', weekly),
            if (scheduled.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Für Schüler geplant',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              for (final m in scheduled)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MaterialRow(
                      material: m,
                      onOpen: () => run(() => openMaterial(ctx, c, m)),
                      onEdit: () => showMaterialDetails(ctx, c, m),
                    ),
                    Wrap(
                      children: [
                        for (final p in c.pupils.where(
                          (p) => pupilMaterialDates(m, p.id).contains(date),
                        ))
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => showPupilMaterials(ctx, c, p),
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: Text(p.name),
                          ),
                      ],
                    ),
                  ],
                ),
            ],
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Passend zu Unterricht und Wochenplanung',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              for (final m in suggestions)
                MaterialRow(
                  material: m,
                  onOpen: () => run(() => openMaterial(ctx, c, m)),
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
  bool offerSignIn = false,
}) async {
  final client = drive ?? OneDriveClient();
  var cached = 0;
  final failed = <String>[];
  try {
    if (drive == null && materials.any((m) => m.text('itemId').isNotEmpty)) {
      await client.load();
    }
    if (offerSignIn && !client.connected) {
      if (!context.mounted) return;
      await connectOneDrive(context, client);
      if (!client.connected || !context.mounted) return;
    }
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
      } catch (e) {
        failed.add('${m.title} · ${friendlyError(e)}');
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

class PreparedMaterialsTile extends StatelessWidget {
  const PreparedMaterialsTile({
    super.key,
    required this.controller,
    required this.date,
    this.query = '',
  });
  final NotebookController controller;
  final String date;
  final String query;
  @override
  Widget build(BuildContext context) {
    final dayMaterials = preparedDayMaterials(controller.classroom, date);
    final materials = dayMaterials
        .where((m) => materialMatches(m, query, pupils: controller.pupils))
        .toList();
    final count = materials.length;
    final now = DateTime.now();
    final tomorrow = dateOnly(DateTime(now.year, now.month, now.day + 1));
    final dayLabel = date == dateOnly(now)
        ? 'Heute · '
        : date == tomorrow
        ? 'Morgen · '
        : '';
    return ListTile(
      key: ValueKey('prepared-day-$date'),
      contentPadding: EdgeInsets.zero,
      leading: materials.isEmpty
          ? const Icon(Icons.folder_open_outlined)
          : MaterialThumbnail(material: materials.first, width: 40, height: 52),
      title: Text('$dayLabel${displayDate(date)}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              count == 0
                  ? 'Unterlagen bereitlegen'
                  : '$count ${count == 1 ? 'Material' : 'Materialien'}',
              if (materials.isNotEmpty)
                materials.map((m) => m.title).join(', '),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (dayMaterials.isNotEmpty)
            PreparedOfflineStatus(
              controller: controller,
              materials: dayMaterials,
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          showPreparedMaterials(context, controller, date: date, query: query),
    );
  }
}
