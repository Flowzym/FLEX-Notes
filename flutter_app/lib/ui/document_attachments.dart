import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/document_scanner.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'draft_actions.dart';
import '../services/material_storage.dart';
import '../services/scan_store.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'scan_editor.dart';

class DocumentAttachmentsButton extends StatelessWidget {
  const DocumentAttachmentsButton({
    super.key,
    required this.controller,
    required this.scope,
  });
  final NotebookController controller;
  final ScanContext scope;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (ctx, _) {
      final count = controller.classroom.where(scope.matchesMaterial).length;
      return OutlinedButton.icon(
        onPressed: () => showContextDocuments(ctx, controller, scope),
        icon: const Icon(Icons.folder_open_outlined),
        label: Text(count == 0 ? 'Dokumente' : 'Dokumente · $count'),
      );
    },
  );
}

Future<void> scanAndShow(
  BuildContext context,
  NotebookController c,
  ScanContext scope, {
  DialogDraft? draft,
  ClassroomDocument? source,
}) async {
  final saved = await showDocumentScanner(
    context,
    c,
    scope: scope,
    draft: draft,
    source: source,
  );
  if (saved != null && context.mounted) {
    await showMaterialDetails(context, c, saved);
  }
}

Future<void> showContextDocuments(
  BuildContext context,
  NotebookController c,
  ScanContext scope,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final docs = c.classroom.where(scope.matchesMaterial).toList()
        ..sort(
          (a, b) => b.text('updatedAtUtc').compareTo(a.text('updatedAtUtc')),
        );
      final drafts = c.dialogDrafts.where(scope.matchesDraft).toList();
      return FlexModal(
        maxWidth: 800,
        title: Text(
          scope.title.isEmpty ? 'Dokumente' : '${scope.title} · Dokumente',
        ),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: () => scanAndShow(ctx, c, scope),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scannen / PDF erstellen'),
                ),
                OutlinedButton.icon(
                  onPressed: () => guarded(ctx, () async {
                    final ids = await chooseMaterials(ctx, c, const []);
                    if (ids == null) return;
                    final selected = c.classroom
                        .where(
                          (d) =>
                              ids.contains(d.id) &&
                              d.kind == ClassroomKind.material,
                        )
                        .toList();
                    await c.repository.saveClassroomDocuments([
                      for (final d in selected)
                        d.patch({
                          'pupilIds': {
                            ...d.strings('pupilIds'),
                            ...scope.pupilIds,
                          }.toList(),
                          'links': {
                            for (final l in [
                              ...d.rows('links').map(DocumentLink.fromJson),
                              ...scope.links,
                            ])
                              l.identity: l,
                          }.values.map((l) => l.toJson()).toList(),
                        }),
                    ]);
                    await c.reload();
                  }),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Vorhandene Datei zuordnen'),
                ),
              ],
            ),
            if (drafts.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Scanentwürfe',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final draft in drafts)
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text(draft.data['title'] as String),
                  subtitle: Text(
                    '${(draft.data['pages'] as List).length} Seiten',
                  ),
                  onTap: () => scanAndShow(ctx, c, scope, draft: draft),
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
            ],
            const SizedBox(height: 14),
            if (docs.isEmpty) const Text('Noch keine zugeordneten Dokumente.'),
            for (final d in docs)
              MaterialRow(
                material: d,
                onOpen: () => guarded(ctx, () => openMaterial(ctx, c, d)),
                onEdit: () => showMaterialDetails(ctx, c, d),
              ),
          ],
        ),
      );
    },
  ),
);

ScanContext orgaScanContext(NotebookController c, OrgaEntry e) => ScanContext(
  pupilIds: [if (e.pupilId != null) e.pupilId!],
  links: [DocumentLink('orga', e.id)],
  title: '${c.owner(e)} · ${e.title}',
  category: e.isAppointment ? 'protocol' : 'form',
);
ScanContext schoolScanContext(
  NotebookController c,
  List<SchoolRecord> records,
) => ScanContext(
  pupilIds: records.map((r) => r.pupilId).toSet().toList(),
  links: records.map((r) => DocumentLink('school', r.id)).toList(),
  title: records.isEmpty
      ? 'Schülerdokument'
      : records.length > 1
      ? 'FLEX-Klasse · ${records.first.kind.label}'
      : '${c.pupils.where((p) => p.id == records.first.pupilId).firstOrNull?.name ?? 'Schüler'} · ${records.first.kind.label}',
  category: records.isNotEmpty && records.first.kind == SchoolKind.homework
      ? 'pupilWork'
      : 'other',
);
