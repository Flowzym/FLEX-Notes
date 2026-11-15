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
    await c.importFiles(batch);
    c.navigate(WorkspaceSection.materials);
    message(
      '${picked.length} Datei${picked.length == 1 ? '' : 'en'} importiert',
    );
  }

  Widget materials() {
    final entries = c.materials
        .where(
          (m) =>
              (!favoritesOnly || m.flag('favorite')) &&
              '${m.title} ${m.text('subject')} ${m.strings('tags').join(' ')} ${m.strings('pupilIds').map(c.name).join(' ')}'
                  .toLowerCase()
                  .contains(c.query.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
          child: SectionHeading(
            'Materialien',
            subtitle: 'Dokumente finden. Unterricht vorbereiten.',
            actions: [
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
                    prefixIcon: Icon(Icons.search, size: 19),
                    hintText: 'Name, Fach, Tag oder Schüler suchen',
                  ),
                  onChanged: c.search,
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Favoriten', style: TextStyle(fontSize: 11)),
                avatar: const Icon(Icons.star_outline, size: 15),
                selected: favoritesOnly,
                onSelected: (v) => redraw(() => favoritesOnly = v),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            children: [
              Text(
                '${entries.length} Materialien',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              const Spacer(),
              if (c.selectedMaterials.isNotEmpty) ...[
                Text(
                  '${c.selectedMaterials.length} ausgewählt',
                  style: const TextStyle(fontSize: 11, color: olive),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () =>
                      run(() => assignDialog(c.selectedMaterials.toList())),
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('Zuordnen'),
                ),
                IconButton(
                  tooltip: 'Auswahl aufheben',
                  onPressed: () => redraw(() => c.selectedMaterials.clear()),
                  icon: const Icon(Icons.close, size: 17),
                ),
              ] else
                TextButton.icon(
                  onPressed: () => run(addLink),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Link hinzufügen'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 36),
                Expanded(
                  child: Text(
                    'DOKUMENT',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      color: muted,
                    ),
                  ),
                ),
                Text(
                  'ZUORDNUNG & AKTIONEN',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? QuietEmpty(
                  c.materials.isEmpty
                      ? 'Deine Materialablage'
                      : 'Keine passenden Materialien',
                  c.materials.isEmpty
                      ? 'PDFs, Word-Dokumente und Fotos importieren oder Dateien aus OneDrive verknüpfen.'
                      : 'Ändere den Suchbegriff oder den Favoritenfilter.',
                  icon: Icons.folder_open_outlined,
                  action: c.materials.isEmpty
                      ? FilledButton(
                          onPressed: () => run(importLocal),
                          child: const Text('Dateien auswählen'),
                        )
                      : null,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) =>
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
    final selected = <String>{if (c.pupilId != null) c.pupilId!};
    DateTime? date;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Schülern zuordnen'),
          content: SizedBox(
            width: 430,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${ids.length} Material${ids.length == 1 ? '' : 'ien'} · vorhandene Zuordnungen bleiben erhalten',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date ?? c.date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) update(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 17),
                  label: Text(
                    date == null
                        ? 'Unterrichtsdatum wählen · optional'
                        : shortDate(dateOnly(date!)),
                  ),
                ),
                if (date != null)
                  TextButton(
                    onPressed: () => update(() => date = null),
                    child: const Text('Datum entfernen'),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final p in c.pupils)
                        CheckboxListTile(
                          title: Text(
                            p.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: selected.contains(p.id),
                          onChanged: (v) => update(
                            () => v == true
                                ? selected.add(p.id)
                                : selected.remove(p.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Zuordnen'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await c.assignMaterials(
        ids,
        selected,
        date == null ? null : dateOnly(date!),
      );
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
    await showDialog<void>(
      context: context,
      builder: (_) => DesktopDriveBrowser(controller: c, drive: drive),
    );
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

class DesktopDriveBrowser extends StatefulWidget {
  const DesktopDriveBrowser({
    super.key,
    required this.controller,
    required this.drive,
  });
  final WorkspaceController controller;
  final OneDriveClient drive;
  @override
  State<DesktopDriveBrowser> createState() => _DesktopDriveBrowserState();
}

class _DesktopDriveBrowserState extends State<DesktopDriveBrowser> {
  final stack = <({String id, String name})>[];
  final selected = <String, Json>{};
  List<Json> items = [];
  String? driveId, error;
  String query = '';
  bool busy = true;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (driveId == null) {
        final root = await widget.drive.graph('/me/drive/root');
        driveId =
            (root['parentReference'] as Map?)?['driveId'] as String? ??
            (await widget.drive.graph('/me/drive'))['id'] as String;
        stack.add((id: root['id'] as String, name: 'OneDrive'));
      }
      final next = await widget.drive.children(
        drive: driveId,
        folder: stack.last.id,
      );
      if (mounted) setState(() => items = next);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> link() async {
    setState(() => busy = true);
    try {
      final docs = <ClassroomDocument>[];
      for (final item in selected.values) {
        final id = oneDriveMaterialId(
          driveId!,
          item['id'] as String,
          widget.controller.notebook.classroom,
        );
        final old = widget.controller.materials
            .where((m) => m.id == id)
            .firstOrNull;
        if (old != null) continue;
        docs.add(
          ClassroomDocument.create(
            ClassroomKind.material,
            item['name'] as String,
            {
              'driveId': driveId,
              'itemId': item['id'],
              'url': item['webUrl'],
              'name': item['name'],
              'extension': (item['name'] as String)
                  .split('.')
                  .last
                  .toLowerCase(),
              'size': item['size'] ?? 0,
              'etag': item['eTag'] ?? '',
              'sourceModifiedAt': item['lastModifiedDateTime'] ?? utcNow(),
              'sourcePath': stack.map((s) => s.name).join(' / '),
            },
            id: id,
          ),
        );
      }
      await widget.controller.notebook.saveClassroomBatch(docs);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 850,
      height: 620,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                const Icon(Icons.cloud_outlined, color: olive),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Dateien aus OneDrive',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Schließen',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Übergeordneter Ordner',
                  onPressed: stack.length > 1 && !busy
                      ? () {
                          stack.removeLast();
                          load();
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    stack.map((s) => s.name).join('  /  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'In diesem Ordner suchen',
                      prefixIcon: Icon(Icons.search, size: 16),
                    ),
                    onChanged: (v) => setState(() => query = v.toLowerCase()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final item in items.where(
                  (i) => (i['name'] as String).toLowerCase().contains(query),
                ))
                  if (item['folder'] != null)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(item['name'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy
                          ? null
                          : () {
                              stack.add((
                                id: item['id'] as String,
                                name: item['name'] as String,
                              ));
                              load();
                            },
                    )
                  else if (['pdf', 'docx', 'jpg'].contains(
                    (item['name'] as String).split('.').last.toLowerCase(),
                  ))
                    CheckboxListTile(
                      secondary: const Icon(Icons.description_outlined),
                      title: Text(item['name'] as String),
                      subtitle: Text(
                        '${((item['size'] as int? ?? 0) / 1024).round()} KB',
                        style: const TextStyle(fontSize: 10),
                      ),
                      value: selected.containsKey(item['id']),
                      onChanged: busy
                          ? null
                          : (v) => setState(
                              () => v == true
                                  ? selected[item['id'] as String] = item
                                  : selected.remove(item['id']),
                            ),
                    ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Die Originale bleiben in OneDrive. Offline-Kopien lädst du anschließend in der Vorschau.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
                const SizedBox(width: 20),
                FilledButton(
                  onPressed: busy || selected.isEmpty ? null : link,
                  child: Text('${selected.length} Dateien verknüpfen'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
