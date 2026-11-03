import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/school.dart';
import '../domain/models.dart';
import 'dialog_workflows.dart';
import 'flex_modal.dart';
import 'common.dart';
import 'orga_editor.dart';
import 'school_workspace.dart';
import 'draft_actions.dart';

int entryDraftCount(
  NotebookController c, {
  required String? pupilId,
  SchoolKind? kind,
  required String exclude,
}) =>
    c.schoolDrafts
        .where(
          (d) =>
              d.id != exclude &&
              kind != null &&
              d.record.kind == kind &&
              (d.record.pupilId == pupilId || d.recipients.contains(pupilId)),
        )
        .length +
    c.drafts
        .where(
          (d) => d.id != exclude && kind == null && d.entry.pupilId == pupilId,
        )
        .length +
    c.dialogDrafts
        .where(
          (d) =>
              d.type == 'bulk' &&
              d.data['kind'] == (kind?.name ?? 'orga') &&
              (d.data['recipients'] as List).contains(pupilId),
        )
        .length;

class EntryHeaderButton extends StatelessWidget {
  const EntryHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '$label ($count)',
    iconSize: 20,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    padding: const EdgeInsets.all(6),
    onPressed: onPressed,
    icon: Badge(
      backgroundColor: Theme.of(context).colorScheme.primary,
      textColor: Theme.of(context).colorScheme.onPrimary,
      isLabelVisible: count > 0,
      label: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
      ),
      child: Icon(icon),
    ),
  );
}

Future<void> showEntryDrafts(
  BuildContext context,
  NotebookController c, {
  required String? pupilId,
  SchoolKind? kind,
  required String exclude,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (_, _) {
      final school = c.schoolDrafts
          .where(
            (d) =>
                d.id != exclude &&
                kind != null &&
                d.record.kind == kind &&
                (d.record.pupilId == pupilId || d.recipients.contains(pupilId)),
          )
          .toList();
      final orga = c.drafts
          .where(
            (d) =>
                d.id != exclude && kind == null && d.entry.pupilId == pupilId,
          )
          .toList();
      final bulk = c.dialogDrafts
          .where(
            (d) =>
                d.type == 'bulk' &&
                d.data['kind'] == (kind?.name ?? 'orga') &&
                (d.data['recipients'] as List).contains(pupilId),
          )
          .toList();
      final rows =
          <
              ({
                String id,
                String preview,
                String time,
                String mode,
                VoidCallback open,
                Future<void> Function() discard,
              })
            >[
              for (final d in school)
                (
                  id: 'school-${d.id}',
                  preview: [
                    d.record.title,
                    d.record.body,
                    ...d.record.positive,
                    ...d.record.neutral,
                    ...d.record.negative,
                    ...d.record.tasks.map((t) => t.text),
                  ].where((v) => v.isNotEmpty).join(' · '),
                  time: d.updatedAtUtc,
                  mode: d.mode == 'comment'
                      ? 'Kommentar'
                      : d.mode == 'review'
                      ? 'Überprüfung'
                      : 'Eintrag',
                  open: () => editSchool(ctx, c, d.record, draft: d),
                  discard: () => c.repository.discardSchoolDraft(
                    d.id,
                    expectedRevision: d.editRevision,
                  ),
                ),
              for (final d in orga)
                (
                  id: 'orga-${d.id}',
                  preview: d.entry.body.isEmpty ? d.entry.title : d.entry.body,
                  time: d.updatedAtUtc,
                  mode: 'Eintrag',
                  open: () => showDialog<void>(
                    context: ctx,
                    barrierDismissible: false,
                    builder: (_) => OrgaEditor(
                      controller: c,
                      entry: d.entry,
                      draftId: d.id,
                    ),
                  ),
                  discard: () => c.repository.discardDraft(
                    d.id,
                    expectedRevision: d.editRevision,
                  ),
                ),
              for (final d in bulk)
                (
                  id: 'bulk-${d.id}',
                  preview: '${d.data['context'] ?? d.data['body'] ?? ''}',
                  time: d.updatedAtUtc,
                  mode: 'Für mehrere erfassen',
                  open: () => showBulk(ctx, c, draft: d),
                  discard: () =>
                      c.repository.discardDialogDraft(d.id, d.revision),
                ),
            ]
            ..sort((a, b) => b.time.compareTo(a.time));
      return FlexModal(
        title: Text('Entwürfe · ${kind?.label ?? 'Orga'}'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows.isEmpty)
              const Text('Keine weiteren gesicherten Entwürfe.'),
            for (final row in rows)
              Padding(
                key: ValueKey('draft-row-${row.id}'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      row.mode,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (row.preview.isNotEmpty)
                      Text(
                        row.preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${displayDate(dateOnly(DateTime.parse(row.time).toLocal()))} · ${TimeOfDay.fromDateTime(DateTime.parse(row.time).toLocal()).format(ctx)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: row.open,
                          child: const Text(
                            'Fortsetzen',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        DraftDeleteButton(
                          onDelete: () async {
                            await row.discard();
                            await c.reload();
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  ),
);

Future<void> showAssignedHomework(
  BuildContext context,
  NotebookController c,
  String pupilId,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (_, _) {
      final pupil = c.pupils.firstWhere((p) => p.id == pupilId);
      return FlexModal(
        title: const Text('Hausübungen'),
        headerContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pupil.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  tooltip: 'Schließen und Eingaben sichern',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Hausübungen',
              style: TextStyle(
                fontFamily: 'FlexSerif',
                fontSize: 20,
                height: 1.3,
              ),
            ),
          ],
        ),
        onClose: () => Navigator.pop(ctx),
        scrollable: false,
        content: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .65,
          child: SchoolWorkspace(
            controller: c,
            pupil: pupil,
            kind: SchoolKind.homework,
          ),
        ),
      );
    },
  ),
);
