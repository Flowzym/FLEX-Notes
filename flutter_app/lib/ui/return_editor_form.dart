import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/document_scanner.dart';
import '../domain/models.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'dialog_workflows.dart';
import 'document_attachments.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'material_thumbnail.dart';
import 'person_assignment.dart';
import 'scan_editor.dart';

const _reminders = {
  0: 'Am Tag der Frist',
  1: '1 Tag vorher',
  2: '2 Tage vorher',
  7: '1 Woche vorher',
};

/// A compact return form with capture and previews at the point of creation.
class ReturnEditorForm extends StatelessWidget {
  const ReturnEditorForm({
    super.key,
    required this.controller,
    required this.data,
    required this.onChanged,
    required this.existing,
  });
  final NotebookController controller;
  final Json data;
  final ValueChanged<Json> onChanged;
  final bool existing;

  @override
  Widget build(BuildContext context) {
    final form = ProtectedDialog.of(context);
    final scheme = Theme.of(context).colorScheme;
    final participants = (data['participants'] as List).cast<Map>();
    final materialIds = List<String>.from(data['materialIds'] as List? ?? []);
    final scope = classroomDraftScanContext(form.buffer.draft);
    final savedScope = ScanContext(
      links: [DocumentLink('classroom', data['id'] as String)],
      unassignedPupilsOnly: true,
    );

    Future<void> capture({bool import = false, DialogDraft? draft}) =>
        form.withSavedDraft((owner) async {
          await showDocumentScanner(
            context,
            controller,
            scope: classroomDraftScanContext(owner),
            draft: draft,
            importOnOpen: import,
          );
        });

    Widget heading(String title) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('classroom-title'),
          initialValue: data['title'] as String? ?? '',
          decoration: const InputDecoration(
            labelText: 'Bezeichnung',
            hintText: 'z. B. Einverständnis zum Ausflug',
          ),
          onChanged: (v) => onChanged({'title': v}),
        ),
        heading('Art des Rücklaufs'),
        LayoutBuilder(
          builder: (ctx, box) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in returnTypes.entries)
                SizedBox(
                  width: (box.maxWidth - 6) / 2,
                  child: TextButton.icon(
                    key: ValueKey('return-type-${type.key}'),
                    onPressed: existing
                        ? null
                        : () => onChanged({'type': type.key}),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      minimumSize: const Size(0, 44),
                      alignment: Alignment.centerLeft,
                      foregroundColor: scheme.onSurface,
                      disabledForegroundColor: scheme.onSurface,
                      backgroundColor: data['type'] == type.key
                          ? scheme.primary.withValues(alpha: .16)
                          : scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: data['type'] == type.key
                              ? scheme.primary.withValues(alpha: .5)
                              : scheme.outlineVariant.withValues(alpha: .4),
                        ),
                      ),
                    ),
                    icon: Icon(
                      data['type'] == type.key
                          ? Icons.check
                          : switch (type.key) {
                              'consent' => Icons.verified_outlined,
                              'material' => Icons.backpack_outlined,
                              'payment' => Icons.euro_outlined,
                              _ => Icons.description_outlined,
                            },
                      size: 18,
                    ),
                    label: Text(
                      type.value,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        PersonAssignmentField(
          label: 'Schüler auswählen',
          pupils: controller.pupils,
          selected: {for (final row in participants) row['pupilId'] as String},
          otherNames: data['otherParticipants'] as String? ?? '',
          onChanged: (ids, names) => onChanged({
            'otherParticipants': names,
            'participants': [
              for (final pupil in controller.pupils.where(
                (p) => ids.contains(p.id),
              ))
                participants
                        .where((p) => p['pupilId'] == pupil.id)
                        .firstOrNull ??
                    {
                      'pupilId': pupil.id,
                      'name': pupil.name,
                      'status': 'open',
                      'note': '',
                      'paid': 0,
                    },
            ],
          }),
        ),
        if (data['type'] == 'payment') ...[
          TextFormField(
            key: const ValueKey('return-amount'),
            initialValue: ((data['amountDue'] as int? ?? 0) / 100)
                .toStringAsFixed(2),
            decoration: const InputDecoration(
              labelText: 'Betrag pro Schüler · €',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '.'));
              onChanged({
                'amountDue': n == null || !n.isFinite ? -1 : (n * 100).round(),
              });
            },
          ),
          const SizedBox(height: 8),
        ],
        const Divider(height: 1),
        ListTile(
          key: const ValueKey('return-deadline'),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 20,
          leading: const Icon(Icons.event_outlined, size: 21),
          title: const Text('Frist'),
          subtitle: Text(
            (data['dueDate'] as String? ?? '').isEmpty
                ? 'Ohne Termin'
                : displayDate(data['dueDate'] as String),
          ),
          trailing: (data['dueDate'] as String? ?? '').isEmpty
              ? const Icon(Icons.chevron_right, size: 20)
              : IconButton(
                  tooltip: 'Frist entfernen',
                  onPressed: () => onChanged({'dueDate': ''}),
                  icon: const Icon(Icons.close, size: 18),
                ),
          onTap: () async {
            final result = await pickFlexDate(
              context,
              date: (data['dueDate'] as String? ?? '').isEmpty
                  ? dateOnly(DateTime.now())
                  : data['dueDate'] as String,
              allowTime: false,
            );
            if (result != null) onChanged({'dueDate': result.$1});
          },
        ),
        PopupMenuButton<int>(
          key: const ValueKey('return-reminder'),
          initialValue: data['remindDays'] as int? ?? 0,
          onSelected: (v) => onChanged({'remindDays': v}),
          itemBuilder: (_) => [
            for (final e in _reminders.entries)
              PopupMenuItem(value: e.key, child: Text(e.value)),
          ],
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 20,
            leading: const Icon(Icons.notifications_none, size: 21),
            title: const Text('Erinnerung'),
            subtitle: Text(_reminders[data['remindDays'] ?? 0]!),
            trailing: const Icon(Icons.expand_more, size: 20),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('classroom-note'),
          initialValue: data['note'] as String? ?? '',
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Hinweis · optional'),
          onChanged: (v) => onChanged({'note': v}),
        ),
        heading('Anhänge'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AttachmentAction(
              key: const ValueKey('return-scan'),
              icon: Icons.document_scanner_outlined,
              label: 'Scan / Foto',
              onPressed: capture,
            ),
            _AttachmentAction(
              key: const ValueKey('return-import'),
              icon: Icons.add_photo_alternate_outlined,
              label: 'Bilder / PDF',
              onPressed: () => capture(import: true),
            ),
            _AttachmentAction(
              key: const ValueKey('return-materials'),
              icon: Icons.folder_open_outlined,
              label: 'Material',
              onPressed: () async {
                final ids = await chooseMaterials(
                  context,
                  controller,
                  materialIds,
                );
                if (ids != null) onChanged({'materialIds': ids});
              },
            ),
          ],
        ),
        AnimatedBuilder(
          animation: controller,
          builder: (ctx, _) {
            final docs = controller.classroom.where(
              (d) =>
                  !d.deleted &&
                  (materialIds.contains(d.id) ||
                      scope.matchesMaterial(d) ||
                      savedScope.matchesMaterial(d)),
            );
            final drafts = controller.dialogDrafts.where(
              (d) => scope.matchesDraft(d) || savedScope.matchesDraft(d),
            );
            return Column(
              children: [
                for (final d in docs)
                  ListTile(
                    key: ValueKey('return-file-${d.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: MaterialThumbnail(
                      material: d,
                      width: 44,
                      height: 52,
                    ),
                    title: Text(
                      d.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(d.text('extension').toUpperCase()),
                    trailing: IconButton(
                      tooltip: 'Datei bearbeiten',
                      onPressed: () => form.withSavedDraft(
                        (_) => showMaterialDetails(ctx, controller, d),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                    onTap: () => form.withSavedDraft(
                      (_) => openMaterial(ctx, controller, d),
                    ),
                  ),
                for (final d in drafts)
                  ListTile(
                    key: ValueKey('return-scan-draft-${d.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: ScanDraftThumbnail(draft: d),
                    title: Text(
                      d.data['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text('Scan fortsetzen'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => capture(draft: d),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Expanded(
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 23),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
