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

class _ScannerLibraryState extends State<ScannerLibrary> {
  String query = '', format = 'all';
  bool trash = false, draftsOnly = false;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (ctx, _) {
      final c = widget.controller;
      final documents =
          c.classroom
              .where(
                (d) =>
                    isScannerMaterial(d) &&
                    d.deleted == trash &&
                    (format == 'all' || d.text('extension') == format) &&
                    materialMatches(d, query, pupils: c.pupils),
              )
              .toList()
            ..sort(
              (a, b) =>
                  b.text('updatedAtUtc').compareTo(a.text('updatedAtUtc')),
            );
      final drafts = c.dialogDrafts
          .where(
            (d) =>
                d.type == 'scan' &&
                '${d.data['title']} ${(d.data['tags'] as List? ?? []).join(' ')}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      return ListView(
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
              IconButton(
                tooltip: 'Scannen / Foto',
                onPressed: () => scanAndShow(ctx, c, const ScanContext()),
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
            onChanged: (v) => setState(() => query = v),
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
                  }),
                ),
              FilterChip(
                label: Text('Entwürfe · ${drafts.length}'),
                selected: draftsOnly,
                onSelected: (v) => setState(() {
                  draftsOnly = v;
                  trash = false;
                }),
              ),
              FilterChip(
                label: const Text('Papierkorb'),
                selected: trash,
                onSelected: (v) => setState(() {
                  trash = v;
                  draftsOnly = false;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (draftsOnly) ...[
            if (drafts.isEmpty) const Text('Keine passenden Scanentwürfe.'),
            for (final draft in drafts)
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text(draft.data['title'] as String),
                subtitle: Text(
                  '${(draft.data['pages'] as List).length} Seiten',
                ),
                onTap: () =>
                    scanAndShow(ctx, c, const ScanContext(), draft: draft),
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
              const Text('Keine passenden Scans oder Fotos.'),
            for (final d in documents)
              MaterialRow(
                material: d,
                onOpen: () => guarded(ctx, () => openMaterial(ctx, c, d)),
                onEdit: trash ? null : () => showMaterialDetails(ctx, c, d),
                trailing: IconButton(
                  tooltip: trash ? 'Wiederherstellen' : 'In den Papierkorb',
                  icon: Icon(trash ? Icons.restore : Icons.delete_outline),
                  onPressed: () => guarded(ctx, () async {
                    if (!trash &&
                        !await confirmFlex(
                          ctx,
                          'Datei in den Papierkorb?',
                          'Die Datei bleibt wiederherstellbar.',
                          accept: 'In den Papierkorb',
                        )) {
                      return;
                    }
                    await c.saveClassroom(d.patch({'deleted': !trash}));
                  }),
                ),
              ),
          ],
        ],
      );
    },
  );
}
