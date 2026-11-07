import 'material_thumbnail.dart';
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
    this.showPreviews = true,
  });
  final NotebookController controller;
  final ScanContext scope;
  final bool showPreviews;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (ctx, _) {
      final docs = controller.classroom.where(scope.matchesMaterial).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => scanAndShow(ctx, controller, scope),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scannen / Foto'),
              ),
              OutlinedButton.icon(
                onPressed: () => showContextDocuments(ctx, controller, scope),
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(
                  docs.isEmpty ? 'Dokumente' : 'Dokumente · ${docs.length}',
                ),
              ),
            ],
          ),
          if (showPreviews && docs.isNotEmpty)
            SizedBox(
              height: 84 + MediaQuery.textScalerOf(ctx).scale(11) * 3,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(
                  width: 90,
                  child: InkWell(
                    onTap: () => guarded(
                      ctx,
                      () => openMaterial(ctx, controller, docs[i]),
                    ),
                    child: Column(
                      children: [
                        MaterialThumbnail(
                          material: docs[i],
                          width: 72,
                          height: 72,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          docs[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// A direct capture action and visible files at the point where they belong.
/// Editors can persist their draft (or save a new owner) before opening capture.
class DocumentAttachmentSection extends StatelessWidget {
  const DocumentAttachmentSection({
    super.key,
    required this.controller,
    required this.scope,
    this.onScan,
    this.onDocuments,
    this.saveFirst = false,
    this.readOnly = false,
    this.compact = false,
    this.showActions = true,
    this.showFiles = true,
    this.actions = const [],
    this.leadingActions = const [],
  });
  final NotebookController controller;
  final ScanContext scope;
  final VoidCallback? onScan, onDocuments;
  final bool saveFirst, readOnly;
  final bool compact, showActions, showFiles;

  /// Always-visible record actions sharing the attachment toolbar.
  final List<Widget> actions, leadingActions;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (ctx, _) {
      final docs = controller.classroom.where(scope.matchesMaterial).toList()
        ..sort((a, b) => a.title.compareTo(b.title));
      final drafts = controller.dialogDrafts.where(scope.matchesDraft).length;
      return Column(
        crossAxisAlignment: compact && !showFiles
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showActions &&
              (!readOnly || actions.isNotEmpty || leadingActions.isNotEmpty))
            Wrap(
              spacing: compact ? 4 : 8,
              runSpacing: 4,
              children: [
                ...leadingActions,
                if (!readOnly && compact)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('attachment-scan'),
                        tooltip: saveFirst
                            ? 'Speichern & scannen'
                            : 'Scannen / Foto',
                        onPressed:
                            onScan ?? () => scanAndShow(ctx, controller, scope),
                        icon: const Icon(Icons.document_scanner_outlined),
                      ),
                      IconButton(
                        key: const ValueKey('attachment-documents'),
                        tooltip: saveFirst
                            ? 'Speichern & Dokumente'
                            : 'Dokumente · ${docs.length}${drafts == 0 ? '' : ' · $drafts Entwürfe'}',
                        onPressed:
                            onDocuments ??
                            () => showContextDocuments(ctx, controller, scope),
                        icon: Badge(
                          isLabelVisible: docs.isNotEmpty || drafts > 0,
                          label: Text('${docs.length + drafts}'),
                          child: const Icon(Icons.attach_file),
                        ),
                      ),
                    ],
                  )
                else if (!readOnly) ...[
                  TextButton.icon(
                    key: const ValueKey('attachment-scan'),
                    onPressed:
                        onScan ?? () => scanAndShow(ctx, controller, scope),
                    icon: const Icon(Icons.document_scanner_outlined, size: 20),
                    label: Text(
                      saveFirst ? 'Speichern & scannen' : 'Scannen / Foto',
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('attachment-documents'),
                    onPressed:
                        onDocuments ??
                        () => showContextDocuments(ctx, controller, scope),
                    icon: const Icon(Icons.attach_file, size: 20),
                    label: Text(
                      saveFirst
                          ? 'Speichern & Dokumente'
                          : 'Dokumente${docs.isEmpty ? '' : ' · ${docs.length}'}${drafts == 0 ? '' : ' · $drafts Entw.'}',
                    ),
                  ),
                ],
                ...actions,
              ],
            ),
          if (showFiles)
            for (final d in docs)
              ListTile(
                key: ValueKey('attachment-file-${d.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: MaterialThumbnail(material: d, width: 48, height: 56),
                title: Text(
                  d.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () =>
                    guarded(ctx, () => openMaterial(ctx, controller, d)),
              ),
        ],
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
                  label: const Text('Scannen / Foto'),
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
                  leading: ScanDraftThumbnail(draft: draft),
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
  List<SchoolRecord> records, {
  Map<String, String> taskIds = const {},
  bool includeTasks = true,
}) => ScanContext(
  pupilIds: records.map((r) => r.pupilId).toSet().toList(),
  links: records
      .map((r) => DocumentLink('school', r.id, taskId: taskIds[r.id] ?? ''))
      .toList(),
  includeTasks: includeTasks,
  title:
      (records.isEmpty
          ? 'Schülerdokument'
          : records.length > 1
          ? 'FLEX-Klasse · ${records.first.kind.label}'
          : '${c.pupils.where((p) => p.id == records.first.pupilId).firstOrNull?.name ?? 'Schüler'} · ${records.first.kind.label}') +
      (taskIds.isEmpty || records.isEmpty
          ? ''
          : ' · ${records.first.tasks.where((t) => t.id == taskIds[records.first.id]).firstOrNull?.text ?? 'Aufgabe'}'),
  subject: records.isEmpty ? '' : records.first.subject,
  category: records.isNotEmpty && records.first.kind == SchoolKind.homework
      ? 'pupilWork'
      : 'other',
);
