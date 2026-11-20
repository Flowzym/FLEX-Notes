part of 'workspace.dart';

extension _MaterialViews on _DesktopWorkspaceState {
  Future<void> importLocal() async {
    final picked = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Dokumente & Fotos',
          extensions: ['pdf', 'docx', 'jpg', 'jpeg'],
        ),
      ],
    );
    if (picked.isEmpty) return;
    if (picked.length > 25) {
      throw const DomainError(
        'Bitte höchstens 25 Dateien gleichzeitig importieren.',
      );
    }
    final batch = <({String name, Uint8List bytes})>[];
    var total = 0;
    for (final file in picked) {
      final size = await file.length();
      if (size > 20000000 || total + size > 100000000) {
        throw const DomainError(
          'Bitte bis zu 20 MB pro Datei und 100 MB insgesamt auswählen.',
        );
      }
      final buffer = BytesBuilder();
      await for (final chunk in file.openRead()) {
        if (buffer.length + chunk.length > 20000000 ||
            total + buffer.length + chunk.length > 100000000) {
          throw const DomainError('Die ausgewählten Dateien sind zu groß.');
        }
        buffer.add(chunk);
      }
      final bytes = buffer.takeBytes();
      total += bytes.length;
      batch.add((
        name: file.name.replaceFirst(
          RegExp(r'\.jpeg$', caseSensitive: false),
          '.jpg',
        ),
        bytes: bytes,
      ));
    }
    await c.importFiles(
      batch,
      assignTo: c.section == WorkspaceSection.journal ? c.pupilId : null,
    );
    c.navigate(WorkspaceSection.materials);
    message(
      '${picked.length} Datei${picked.length == 1 ? '' : 'en'} importiert',
    );
  }

  Widget materials() {
    final scheduled = materialScope == 'Bereitgelegt'
        ? preparedDayMaterials(
            c.notebook.classroom,
            dateOnly(c.date),
          ).map((m) => m.id).toSet()
        : const <String>{};
    final pupils = c.pupils;
    final entries =
        c.materials
            .where(
              (m) =>
                  (!favoritesOnly || m.flag('favorite')) &&
                  materialMatches(m, c.query, pupils: pupils) &&
                  switch (materialScope) {
                    'Ohne Zuordnung' => m.strings('pupilIds').isEmpty,
                    'Bereitgelegt' => scheduled.contains(m.id),
                    'OneDrive' =>
                      m.text('driveId').isNotEmpty &&
                          m.text('itemId').isNotEmpty,
                    _ => true,
                  },
            )
            .toList()
          ..sort((a, b) {
            final order = materialSort == 'Name'
                ? 0
                : b.text('updatedAtUtc').compareTo(a.text('updatedAtUtc'));
            return order != 0
                ? order
                : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
    final visible = entries.map((m) => m.id).toSet();
    final selected = c.selectedMaterials.intersection(visible);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
          child: SectionHeading(
            'Materialien',
            actions: [
              if (c.notebook.classroom.any(isDriveRule))
                IconButton(
                  tooltip: 'Verknüpfte OneDrive-Ordner abgleichen',
                  icon: c.notebook.syncingMaterials
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  onPressed: c.notebook.syncingMaterials
                      ? null
                      : () => run(() async {
                          await c.notebook.syncMaterials();
                          if (mounted) message(c.notebook.syncMessage);
                        }),
                ),
              OutlinedButton.icon(
                onPressed: () => run(openDrive),
                icon: const Icon(Icons.cloud_outlined, size: 17),
                label: const Text('OneDrive'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => run(importLocal),
                icon: const Icon(Icons.file_upload_outlined, size: 17),
                label: const Text('Importieren'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('material-search'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Name, Fach, Tag oder Schüler suchen',
                  ),
                  onChanged: (v) {
                    c.selectedMaterials.clear();
                    c.search(v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Favoriten'),
                avatar: const Icon(Icons.star_outline, size: 15),
                selected: favoritesOnly,
                onSelected: (v) => redraw(() {
                  favoritesOnly = v;
                  c.selectedMaterials.clear();
                }),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 3),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 7,
              runSpacing: 4,
              children: [
                for (final scope in [
                  'Alle',
                  'Ohne Zuordnung',
                  'Bereitgelegt',
                  'OneDrive',
                ])
                  ChoiceChip(
                    label: Text(
                      scope == 'Bereitgelegt'
                          ? 'Für ${c.date.day}.${c.date.month}.'
                          : scope,
                    ),
                    selected: materialScope == scope,
                    onSelected: (_) => redraw(() {
                      materialScope = scope;
                      c.selectedMaterials.clear();
                    }),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          child: Row(
            children: [
              Tooltip(
                message: 'Alle sichtbaren Materialien auswählen',
                child: Checkbox(
                  tristate: true,
                  value: selected.isEmpty
                      ? false
                      : selected.length == visible.length
                      ? true
                      : null,
                  onChanged: visible.isEmpty
                      ? null
                      : (_) => redraw(() {
                          if (selected.length == visible.length) {
                            c.selectedMaterials.clear();
                          } else {
                            c.selectedMaterials.addAll(visible);
                          }
                        }),
                ),
              ),
              Expanded(
                child: Text(
                  selected.isEmpty
                      ? '${entries.length} Materialien'
                      : '${selected.length} ausgewählt',
                  style: const TextStyle(color: muted),
                ),
              ),
              if (selected.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Auswahl Schülern zuordnen',
                  icon: const Icon(Icons.person_add_alt),
                  onPressed: () => run(() => assignDialog(selected.toList())),
                ),
                IconButton(
                  tooltip: 'Auswahl für einen Tag bereitlegen',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () => run(() async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: c.date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    await c.prepareForDay(selected, picked);
                    redraw(() => c.selectedMaterials.clear());
                    if (mounted) {
                      message(
                        '${selected.length} für ${shortDate(dateOnly(picked))} bereitgelegt',
                      );
                    }
                  }),
                ),
                IconButton(
                  tooltip: 'Auswahl aufheben',
                  onPressed: () => redraw(() => c.selectedMaterials.clear()),
                  icon: const Icon(Icons.close),
                ),
              ] else ...[
                PopupMenuButton<String>(
                  tooltip: 'Materialien sortieren',
                  initialValue: materialSort,
                  onSelected: (s) => redraw(() => materialSort = s),
                  icon: const Icon(Icons.sort),
                  itemBuilder: (_) => [
                    for (final s in ['Zuletzt geändert', 'Name'])
                      CheckedPopupMenuItem(
                        value: s,
                        checked: materialSort == s,
                        child: Text(s),
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => run(addLink),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Link hinzufügen'),
                ),
              ],
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: entries.isEmpty
              ? QuietEmpty(
                  c.materials.isEmpty
                      ? 'Deine Materialablage'
                      : 'Keine passenden Materialien',
                  c.materials.isEmpty
                      ? 'Dateien vom Computer importieren oder aus OneDrive auswählen.'
                      : 'Ändere die Suche oder die gewählten Filter.',
                  icon: Icons.folder_open_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  itemCount: entries.length,
                  itemBuilder: (_, i) =>
                      materialRow(entries[i], selectable: true),
                ),
        ),
      ],
    );
  }

  Widget materialRow(ClassroomDocument m, {bool selectable = false}) =>
      Draggable<String>(
        data: m.id,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(m.title),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: c.materialId == m.id
                ? wash.withValues(alpha: .5)
                : Colors.transparent,
            border: const Border(bottom: BorderSide(color: line)),
          ),
          child: InkWell(
            onTap: () => run(() => c.edit(m)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  if (selectable)
                    SizedBox(
                      width: 34,
                      child: Checkbox(
                        value: c.selectedMaterials.contains(m.id),
                        onChanged: (v) => redraw(() {
                          v == true
                              ? c.selectedMaterials.add(m.id)
                              : c.selectedMaterials.remove(m.id);
                        }),
                      ),
                    ),
                  MaterialThumbnail(
                    material: m,
                    files: c.files,
                    width: 42,
                    height: 54,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            m.text('extension').toUpperCase(),
                            m.text('subject'),
                            m.text('localKey').isEmpty
                                ? 'OneDrive / Link'
                                : 'Offline verfügbar',
                          ].where((v) => v.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                        if (m.strings('pupilIds').isNotEmpty)
                          Text(
                            m.strings('pupilIds').map(c.name).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: olive),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: m.flag('favorite')
                        ? 'Favorit entfernen'
                        : 'Als Favorit markieren',
                    onPressed: () => run(
                      () => c.notebook.saveClassroom(
                        m.patch({'favorite': !m.flag('favorite')}),
                      ),
                    ),
                    icon: Icon(
                      m.flag('favorite')
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 19,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schüler und Unterrichtsdatum zuordnen',
                    onPressed: () => run(() => assignDialog([m.id])),
                    icon: const Icon(Icons.person_add_alt, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  Widget materialInspector(ClassroomDocument m) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Dokumentvorschau',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            IconButton(
              tooltip: 'Vorschau vergrößern',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  child: SizedBox(
                    width: 1000,
                    height: MediaQuery.sizeOf(ctx).height * .88,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Schließen',
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: DocumentPreview(material: m, files: c.files),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_full, size: 17),
            ),
            IconButton(
              tooltip: 'Vorschau schließen',
              onPressed: () => redraw(() => c.materialId = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      const Divider(),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              m.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                Pill(m.text('extension').toUpperCase()),
                if (m.text('subject').isNotEmpty) Pill(m.text('subject')),
                for (final tag in m.strings('tags')) Pill(tag),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 330,
              child: DocumentPreview(
                key: ValueKey('${m.id}:${m.revision}'),
                material: m,
                files: c.files,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => run(() => openOriginal(m)),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(
                      m.text('localKey').isEmpty
                          ? 'Quelle öffnen'
                          : 'Datei exportieren',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Details bearbeiten',
                  onPressed: () => run(() => editMaterial(m)),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                ),
              ],
            ),
            if (m.text('itemId').isNotEmpty)
              TextButton.icon(
                onPressed: () => run(() async {
                  if (!drive.connected) await connectOneDrive(context, drive);
                  if (!drive.connected) return;
                  await cacheMaterial(c.notebook, m, drive, c.files);
                }, success: 'Offline-Kopie aktualisiert'),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: Text(
                  m.text('localKey').isEmpty
                      ? 'Offline verfügbar machen'
                      : 'Offline-Kopie aktualisieren',
                ),
              ),
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Schüler & Unterrichtsdaten',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Zuordnung ergänzen',
                  onPressed: () => run(() => assignDialog([m.id])),
                  icon: const Icon(Icons.add, size: 17),
                ),
              ],
            ),
            if (m.strings('pupilIds').isEmpty)
              const Text(
                'Noch keiner Person zugeordnet.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            for (final id in m.strings('pupilIds'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name(id),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Schülerzuordnung entfernen',
                          onPressed: () => run(() async {
                            if (await confirm(
                              'Zuordnung entfernen?',
                              'Die Datei bleibt erhalten. Nur die Zuordnung und Unterrichtsdaten für ${c.name(id)} werden entfernt.',
                              action: 'Entfernen',
                            )) {
                              await c.notebook.saveClassroom(
                                m.patch({
                                  'pupilIds': m
                                      .strings('pupilIds')
                                      .where((p) => p != id)
                                      .toList(),
                                }),
                              );
                            }
                          }),
                          icon: const Icon(Icons.link_off, size: 14),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final date in pupilMaterialDates(m, id))
                          InputChip(
                            label: Text(
                              shortDate(date),
                              style: const TextStyle(fontSize: 10),
                            ),
                            onDeleted: () => run(
                              () => c.notebook.saveClassroom(
                                m.patch({
                                  'pupilDates': m
                                      .rows('pupilDates')
                                      .where(
                                        (r) =>
                                            !(r['pupilId'] == id &&
                                                r['date'] == date),
                                      )
                                      .toList(),
                                }),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (m.text('note').isNotEmpty) ...[
              const Divider(height: 20),
              Text(m.text('note'), style: const TextStyle(fontSize: 12)),
            ],
            const Divider(height: 24),
            TextButton.icon(
              onPressed: () => run(() async {
                if (await confirm(
                  'In den Papierkorb verschieben?',
                  m.title,
                  action: 'Verschieben',
                )) {
                  await c.notebook.saveClassroom(m.patch({'deleted': true}));
                  redraw(() => c.materialId = null);
                }
              }),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('In den Papierkorb'),
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> assignDialog(List<String> ids) async {
    final wanted = ids.toSet();
    final docs = c.materials.where((m) => wanted.contains(m.id)).toList();
    final saved = await showMaterialAssignments(
      context,
      c.notebook,
      docs,
      pupil: c.section == WorkspaceSection.journal ? c.pupil : null,
    );
    if (saved && mounted) {
      redraw(() => c.selectedMaterials.clear());
      message('Zuordnung gespeichert');
    }
  }

  Future<void> editMaterial(ClassroomDocument m) async {
    final name = TextEditingController(text: m.title),
        subject = TextEditingController(text: m.text('subject')),
        tags = TextEditingController(text: m.strings('tags').join(', ')),
        note = TextEditingController(text: m.text('note'));
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Materialdetails'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: 'Fach'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Tags · durch Komma trennen',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notiz'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (save == true) {
      await c.notebook.saveClassroom(
        m.patch({
          'title': name.text.trim(),
          'subject': subject.text.trim(),
          'tags': tags.text
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList(),
          'note': note.text,
        }),
      );
    }
  }

  Future<void> openOriginal(ClassroomDocument m) async {
    if (m.text('localKey').isNotEmpty) {
      await saveBytesFile(
        m.text('name', '${m.title}.${m.text('extension')}'),
        await c.files.read(m.text('localKey')),
        mime: switch (m.text('extension')) {
          'pdf' => 'application/pdf',
          'jpg' => 'image/jpeg',
          _ =>
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        },
      );
    } else {
      final url = Uri.tryParse(m.text('url'));
      if (url == null ||
          url.scheme != 'https' ||
          !await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const DomainError('Die Quelle konnte nicht geöffnet werden.');
      }
    }
  }

  Future<void> addLink() async {
    final title = TextEditingController(), url = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Material verlinken'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Bezeichnung'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: url,
                decoration: const InputDecoration(labelText: 'HTTPS-Adresse'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (save == true) {
      await c.notebook.saveClassroom(
        ClassroomDocument.create(ClassroomKind.material, title.text.trim(), {
          'url': url.text.trim(),
          'extension': 'link',
        }),
      );
    }
  }

  Future<void> openDrive() async {
    if (!driveLoaded) {
      await drive.load();
      driveLoaded = true;
    }
    if (!drive.connected) {
      if (!mounted) return;
      await connectOneDrive(context, drive);
    }
    if (!drive.connected || !mounted) return;
    await browseOneDrive(context, c.notebook, drive);
  }
}

class DocumentPreview extends StatefulWidget {
  const DocumentPreview({
    super.key,
    required this.material,
    required this.files,
  });
  final ClassroomDocument material;
  final MaterialFiles files;
  @override
  State<DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<DocumentPreview> {
  late final Future<Uint8List?> bytes = widget.material.text('localKey').isEmpty
      ? Future.value(null)
      : widget.files.read(widget.material.text('localKey'));
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: ColoredBox(
      color: paper,
      child: FutureBuilder<Uint8List?>(
        future: bytes,
        builder: (ctx, s) {
          if (s.hasError) {
            return const QuietEmpty(
              'Datei nicht verfügbar',
              'Offline-Kopie aktualisieren oder die Originaldatei erneut importieren.',
            );
          }
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.data == null) {
            return const QuietEmpty(
              'In OneDrive / im Web',
              'Öffne die Quelle oder lade eine Offline-Kopie.',
              icon: Icons.cloud_outlined,
            );
          }
          return switch (widget.material.text('extension')) {
            'pdf' => PdfViewer.data(
              s.data!,
              sourceName: widget.material.id,
              params: const PdfViewerParams(),
            ),
            'jpg' => InteractiveViewer(
              child: Image.memory(s.data!, fit: BoxFit.contain),
            ),
            'docx' => FutureBuilder<List<Json>>(
              future: Future.sync(() => readDocxPreview(s.data!)),
              builder: (ctx, doc) {
                if (doc.hasError) {
                  return const QuietEmpty(
                    'Vorschau nicht möglich',
                    'Die Originaldatei lässt sich weiterhin exportieren.',
                  );
                }
                if (!doc.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TEXTVORSCHAU',
                          style: TextStyle(fontSize: 9, color: muted),
                        ),
                        const SizedBox(height: 12),
                        for (final block in doc.data!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              block['text'] as String? ??
                                  (block['rows'] as List? ?? [])
                                      .map((r) => (r as List).join('  |  '))
                                      .join('\n'),
                              style: TextStyle(
                                fontSize: block['type'] == 'heading' ? 18 : 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            _ => const SizedBox(),
          };
        },
      ),
    ),
  );
}
