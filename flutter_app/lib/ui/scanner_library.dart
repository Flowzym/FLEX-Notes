import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/document_scanner.dart';
import '../domain/material_workspace.dart';
import '../services/material_storage.dart';
import '../services/scan_store.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'document_attachments.dart';
import 'draft_actions.dart';
import 'material_library.dart';
import 'material_thumbnail.dart';

bool isScannerMaterial(ClassroomDocument d) =>
    d.kind == ClassroomKind.material &&
    (d.flag('scanner') ||
        d.flag('scan') ||
        d.text('extension') == 'jpg' && d.text('localKey').isNotEmpty);

class ScannerLibrary extends StatefulWidget {
  const ScannerLibrary({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<ScannerLibrary> createState() => _ScannerLibraryState();
}

class _ScannerLibraryState extends State<ScannerLibrary>
    with AutomaticKeepAliveClientMixin {
  String query = '', format = 'all', sort = 'recent', tag = '';
  bool trash = false,
      draftsOnly = false,
      grid = true,
      selecting = false,
      busy = false;
  final selected = <String>{};
  final search = TextEditingController();
  NotebookController get c => widget.controller;
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void resetSelection() {
    selected.clear();
    selecting = false;
  }

  void toggle(String id) => setState(() {
    selecting = true;
    if (!selected.add(id)) selected.remove(id);
  });

  Future<void> changeFiles(
    List<ClassroomDocument> documents, {
    required bool deleted,
  }) async {
    if (busy || documents.isEmpty) return;
    if (deleted &&
        !await confirmFlex(
          context,
          'Dateien in den Papierkorb?',
          '${documents.length} ${documents.length == 1 ? 'Datei bleibt' : 'Dateien bleiben'} wiederherstellbar.',
          accept: 'In den Papierkorb',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await guarded(context, () async {
      await c.saveClassroomBatch([
        for (final d in documents) d.patch({'deleted': deleted}),
      ]);
      if (mounted) setState(resetSelection);
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> tagFiles(List<ClassroomDocument> documents) async {
    final text = TextEditingController();
    final tags = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => FlexModal(
        title: Text('${documents.length} Dateien taggen'),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tags hinzufügen',
            hintText: 'Mit Komma trennen',
          ),
        ),
        onClose: () => Navigator.pop(ctx),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, scanTags(text.text)),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    // The closing route still owns the field during its reverse animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
    if (!mounted || tags == null || tags.isEmpty) return;
    setState(() => busy = true);
    await guarded(context, () async {
      await c.saveClassroomBatch([
        for (final d in documents)
          d.patch({
            'tags': {...d.strings('tags'), ...tags}.toList(),
          }),
      ]);
      if (mounted) setState(resetSelection);
    });
    if (mounted) setState(() => busy = false);
  }

  Widget fileActions(ClassroomDocument d) => Wrap(
    alignment: WrapAlignment.end,
    children: [
      if (!trash)
        IconButton(
          tooltip: 'Datei bearbeiten',
          onPressed: busy ? null : () => showMaterialDetails(context, c, d),
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
      IconButton(
        tooltip: trash ? 'Wiederherstellen' : 'In den Papierkorb',
        onPressed: busy ? null : () => changeFiles([d], deleted: !trash),
        icon: Icon(trash ? Icons.restore : Icons.delete_outline, size: 20),
      ),
    ],
  );

  Widget tile(ClassroomDocument d, double width) {
    final checked = selected.contains(d.id);
    final owners = c.pupils
        .where((p) => d.strings('pupilIds').contains(p.id))
        .map((p) => p.name)
        .join(', ');
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: checked
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          key: ValueKey('scanner-file-${d.id}'),
          onLongPress: busy ? null : () => toggle(d.id),
          onTap: busy
              ? null
              : () => selecting
                    ? toggle(d.id)
                    : guarded(context, () => openMaterial(context, c, d)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    MaterialThumbnail(
                      material: d,
                      width: width - 28,
                      height: 155,
                    ),
                    if (selecting)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Checkbox(
                          value: checked,
                          onChanged: busy ? null : (_) => toggle(d.id),
                          semanticLabel: '${d.title} auswählen',
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d.text('extension').toUpperCase()}${d.number('pageCount') == 0 ? '' : ' · ${d.number('pageCount')} S.'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (owners.isNotEmpty)
                      Text(
                        owners,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (d.strings('tags').isNotEmpty)
                      Text(
                        d.strings('tags').map((t) => '#$t').join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (!selecting) fileActions(d) else const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final all = c.classroom.where(isScannerMaterial).toList();
        final tags = {
          for (final d in all.where((d) => d.deleted == trash))
            ...d.strings('tags'),
        }.toList()..sort();
        final documents =
            all
                .where(
                  (d) =>
                      d.deleted == trash &&
                      (format == 'all' || d.text('extension') == format) &&
                      (tag.isEmpty || d.strings('tags').contains(tag)) &&
                      materialMatches(d, query, pupils: c.pupils),
                )
                .toList()
              ..sort(
                (a, b) => sort == 'name'
                    ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
                    : b.text('updatedAtUtc').compareTo(a.text('updatedAtUtc')),
              );
        final chosen = documents.where((d) => selected.contains(d.id)).toList();
        final drafts = c.dialogDrafts
            .where(
              (d) =>
                  d.type == 'scan' &&
                  '${d.data['title']} ${(d.data['tags'] as List? ?? []).join(' ')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList();
        return Column(
          children: [
            Expanded(
              child: ListView(
                key: const PageStorageKey('scanner-library'),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Scans & Fotos',
                          style: Theme.of(ctx).textTheme.headlineSmall,
                        ),
                      ),
                      if (!draftsOnly)
                        IconButton(
                          tooltip: selecting
                              ? 'Auswahl beenden'
                              : 'Mehrere auswählen',
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  selecting
                                      ? resetSelection()
                                      : selecting = true;
                                }),
                          icon: Icon(selecting ? Icons.close : Icons.checklist),
                        ),
                      IconButton(
                        tooltip: 'Scannen / Foto',
                        onPressed: busy
                            ? null
                            : () => scanAndShow(ctx, c, const ScanContext()),
                        icon: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Name, Tag oder Schüler suchen',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() {
                      query = v;
                      resetSelection();
                    }),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final type in const {
                        'all': 'Alle',
                        'pdf': 'PDF',
                        'jpg': 'Fotos',
                      }.entries)
                        ChoiceChip(
                          label: Text(type.value),
                          selected: format == type.key && !draftsOnly,
                          onSelected: (_) => setState(() {
                            format = type.key;
                            draftsOnly = false;
                            resetSelection();
                          }),
                        ),
                      FilterChip(
                        label: Text('Entwürfe · ${drafts.length}'),
                        selected: draftsOnly,
                        onSelected: (v) => setState(() {
                          draftsOnly = v;
                          trash = false;
                          resetSelection();
                        }),
                      ),
                      FilterChip(
                        label: const Text('Papierkorb'),
                        selected: trash,
                        onSelected: (v) => setState(() {
                          trash = v;
                          draftsOnly = false;
                          tag = '';
                          resetSelection();
                        }),
                      ),
                    ],
                  ),
                  if (!draftsOnly) ...[
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${documents.length} Dateien'),
                        PopupMenuButton<String>(
                          tooltip: 'Sortieren',
                          initialValue: sort,
                          onSelected: (v) => setState(() => sort = v),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'recent',
                              child: Text('Zuletzt geändert'),
                            ),
                            PopupMenuItem(
                              value: 'name',
                              child: Text('Name A–Z'),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort, size: 18),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    sort == 'name'
                                        ? 'Name A–Z'
                                        : 'Zuletzt geändert',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: grid ? 'Listenansicht' : 'Rasteransicht',
                          onPressed: () => setState(() => grid = !grid),
                          icon: Icon(
                            grid ? Icons.view_list_outlined : Icons.grid_view,
                          ),
                        ),
                      ],
                    ),
                    if (tags.isNotEmpty || tag.isNotEmpty)
                      SizedBox(
                        height: 36 + MediaQuery.textScalerOf(ctx).scale(14),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: const Text('Alle Tags'),
                                selected: tag.isEmpty,
                                onSelected: (_) => setState(() {
                                  tag = '';
                                  resetSelection();
                                }),
                              ),
                            ),
                            for (final t in {...tags, if (tag.isNotEmpty) tag})
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(t),
                                  selected: tag == t,
                                  onSelected: (_) => setState(() {
                                    tag = t;
                                    resetSelection();
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                  if (busy) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  if (draftsOnly) ...[
                    if (drafts.isEmpty)
                      const Text('Keine passenden Scanentwürfe.'),
                    for (final draft in drafts)
                      ListTile(
                        leading: ScanDraftThumbnail(draft: draft),
                        title: Text(draft.data['title'] as String),
                        subtitle: Text(
                          '${(draft.data['pages'] as List).length} Seiten',
                        ),
                        onTap: () => scanAndShow(
                          ctx,
                          c,
                          const ScanContext(),
                          draft: draft,
                        ),
                        trailing: IconButton(
                          tooltip: 'Scanentwurf löschen',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => guarded(ctx, () async {
                            if (!await confirmEditorDraftDeletion(ctx)) return;
                            await discardScan(
                              c.repository,
                              const LocalMaterialFiles(),
                              draft,
                            );
                            await c.reload();
                          }),
                        ),
                      ),
                  ] else ...[
                    if (documents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('Keine passenden Scans oder Fotos.'),
                        ),
                      ),
                    if (grid)
                      LayoutBuilder(
                        builder: (_, box) {
                          final columns =
                              (box.maxWidth /
                                      (MediaQuery.textScalerOf(ctx).scale(1) >
                                              1.5
                                          ? 240
                                          : 160))
                                  .floor()
                                  .clamp(1, 5);
                          final width =
                              (box.maxWidth - 12 * (columns - 1)) / columns;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final d in documents) tile(d, width),
                            ],
                          );
                        },
                      )
                    else
                      for (final d in documents)
                        Row(
                          children: [
                            if (selecting)
                              Checkbox(
                                value: selected.contains(d.id),
                                onChanged: busy ? null : (_) => toggle(d.id),
                                semanticLabel: '${d.title} auswählen',
                              ),
                            Expanded(
                              child: MaterialRow(
                                material: d,
                                onOpen: () => selecting
                                    ? toggle(d.id)
                                    : guarded(
                                        ctx,
                                        () => openMaterial(ctx, c, d),
                                      ),
                                trailing: selecting ? null : fileActions(d),
                              ),
                            ),
                          ],
                        ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (selecting)
              Material(
                color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${chosen.length} ausgewählt'),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                if (chosen.length == documents.length) {
                                  selected.clear();
                                } else {
                                  selected.addAll(documents.map((d) => d.id));
                                }
                              }),
                        child: Text(
                          chosen.length == documents.length
                              ? 'Keine'
                              : 'Alle auswählen',
                        ),
                      ),
                      if (!trash)
                        TextButton.icon(
                          onPressed: busy || chosen.isEmpty
                              ? null
                              : () => tagFiles(chosen),
                          icon: const Icon(Icons.sell_outlined),
                          label: const Text('Tags'),
                        ),
                      TextButton.icon(
                        onPressed: busy || chosen.isEmpty
                            ? null
                            : () => changeFiles(chosen, deleted: !trash),
                        icon: Icon(
                          trash ? Icons.restore : Icons.delete_outline,
                        ),
                        label: Text(trash ? 'Wiederherstellen' : 'Papierkorb'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
