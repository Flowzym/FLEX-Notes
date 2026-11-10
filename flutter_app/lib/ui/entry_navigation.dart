import 'detail_flow.dart';
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

/// Shared context and heading for the school and organisation editors.
class EntryPageHeader extends StatelessWidget {
  const EntryPageHeader({
    super.key,
    required this.owner,
    required this.title,
    required this.onClose,
    this.actions = const [],
    this.titleActions = const [],
  });
  final String owner, title;
  final VoidCallback? onClose;
  final List<Widget> actions, titleActions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scheme = Theme.of(context).colorScheme;
      final compact =
          constraints.maxWidth < 330 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
          constraints.maxWidth - (actions.length + 2) * 44 - 8 < 140;
      final actionsWithTitle =
          compact &&
          constraints.maxWidth >= 330 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.4;
      Widget exit(IconData icon, String label) => IconButton(
        tooltip: label,
        iconSize: 20,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(6),
        onPressed: onClose,
        icon: Icon(icon),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                exit(Icons.arrow_back, 'Zurück und Eingaben sichern'),
                Expanded(
                  child: Tooltip(
                    message: owner,
                    child: Text(
                      owner,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (!compact) ...actions,
                exit(Icons.close, 'Schließen und Eingaben sichern'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (compact && !actionsWithTitle)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(children: actions),
            ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 2),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              if (actionsWithTitle) ...actions,
              ...titleActions,
            ],
          ),
        ],
      );
    },
  );
}

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
}) => showFlexDetail<void>(
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
                  open: () => showFlexDetail<void>(
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
) => showFlexDetail<void>(
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
                  tooltip: (DetailFlowScope.maybeOf(context)?.depth ?? 0) > 0
                      ? 'Zurück'
                      : 'Schließen',
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(
                    (DetailFlowScope.maybeOf(context)?.depth ?? 0) > 0
                        ? Icons.arrow_back
                        : Icons.close,
                  ),
                ),
              ],
            ),
            const Text(
              'Hausübungen',
              style: TextStyle(
                fontFamily: 'FlexSans',
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
