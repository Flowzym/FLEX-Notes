import 'detail_flow.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/document_scanner.dart';
import '../domain/school.dart';
import 'common.dart';
import 'document_attachments.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'material_thumbnail.dart';

/// Checking tasks stays in the list; notes and evidence open for one task.
class HomeworkRecordView extends StatelessWidget {
  const HomeworkRecordView({
    super.key,
    required this.controller,
    required this.record,
    required this.expanded,
    required this.standalone,
    required this.busy,
    required this.onExpand,
    required this.onEdit,
    required this.onTaskState,
    required this.onComment,
    required this.onReminder,
    required this.onDelete,
    required this.onHistory,
    this.error,
  });
  final NotebookController controller;
  final SchoolRecord record;
  final bool expanded, standalone, busy;
  final VoidCallback onExpand, onEdit, onReminder, onDelete, onHistory;
  final void Function(HomeworkTask, TaskState) onTaskState;
  final void Function(String?) onComment;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final r = record, c = controller;
    final theme = Theme.of(context), colors = theme.colorScheme;
    final owner = c.pupils.where((p) => p.id == r.pupilId).firstOrNull;
    final title = r.title.isNotEmpty ? r.title : r.subject;
    final complete = r.tasks
        .where((t) => r.taskState(t) == TaskState.complete)
        .length;
    final generalNotes = r.liveFeedback.where(
      (f) => f.taskId == null && f.note.isNotEmpty,
    );
    final scope = schoolScanContext(c, [r], includeTasks: false);
    final count = c.classroom.where(scope.matchesMaterial).length;
    final draftCount = c.dialogDrafts.where(scope.matchesDraft).length;
    final editable = !busy && !r.deleted;
    return Column(
      key: ValueKey('homework-content-${r.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?error,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? owner?.name ?? 'Unbekannt' : title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      if (title.isNotEmpty) owner?.name ?? 'Unbekannt',
                      'Aufgegeben ${displayDate(r.observedOn)}',
                      if (r.subject.isNotEmpty && r.subject != title) r.subject,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!standalone)
              IconButton(
                tooltip: expanded
                    ? 'Hausübung einklappen'
                    : 'Hausübung aufklappen',
                onPressed: onExpand,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            if (!r.deleted)
              IconButton(
                tooltip: 'Eintrag bearbeiten',
                onPressed: editable ? onEdit : null,
                icon: const Icon(Icons.edit_outlined, size: 22),
              ),
          ],
        ),
        if (r.dueDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Fällig: ${displayDate(r.dueDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$complete / ${r.tasks.length} erledigt',
            key: ValueKey('homework-progress-${r.id}'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (expanded || standalone) ...[
          if (r.tasks.isEmpty)
            const Text('Noch keine Aufgaben.')
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: .035),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < r.tasks.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color: colors.onSurface.withValues(alpha: .1),
                      ),
                    _task(context, r.tasks[i]),
                  ],
                ],
              ),
            ),
          if (generalNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                generalNotes.last.note,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Tooltip(
                message: 'Notiz & Verlauf',
                child: TextButton(
                  onPressed: editable ? () => onComment(null) : null,
                  style: _quietButton(context),
                  child: const Text('Notiz'),
                ),
              ),
              TextButton(
                key: ValueKey('record-attachments-${r.id}'),
                onPressed: r.deleted
                    ? null
                    : () => showContextDocuments(context, c, scope),
                style: _quietButton(context),
                child: Text(
                  'Dateien${count == 0 ? '' : ' ($count)'}${draftCount == 0 ? '' : ' · $draftCount Entw.'}',
                ),
              ),
              TextButton(
                key: ValueKey('homework-history-${r.id}'),
                onPressed: onHistory,
                style: _quietButton(context),
                child: Text(
                  'Verlauf${r.liveFeedback.isEmpty ? '' : ' (${r.liveFeedback.length})'}',
                ),
              ),
              if (r.pending && !r.deleted)
                IconButton(
                  tooltip: 'Erinnerung verschieben',
                  onPressed: busy ? null : onReminder,
                  icon: const Icon(Icons.snooze, size: 20),
                ),
              IconButton(
                tooltip: r.deleted ? 'Wiederherstellen' : 'Papierkorb',
                onPressed: busy ? null : onDelete,
                icon: Icon(
                  r.deleted ? Icons.restore : Icons.delete_outline,
                  size: 20,
                ),
              ),
            ],
          ),
          HomeworkThumbnails(controller: c, scope: scope, readOnly: r.deleted),
          if (r.needsCompletion) const Text('Später ergänzen'),
        ],
      ],
    );
  }

  Widget _task(BuildContext context, HomeworkTask task) {
    final r = record, theme = Theme.of(context);
    final notes = r.liveFeedback.where(
      (f) => f.taskId == task.id && f.note.isNotEmpty,
    );
    final parents = r.tasks.where((t) => t.parentId == null).toList();
    final number = task.parentId == null
        ? '${parents.indexOf(task) + 1}'
        : '${parents.indexWhere((t) => t.id == task.parentId) + 1}.${r.tasks.where((t) => t.parentId == task.parentId).toList().indexOf(task) + 1}';
    final title = InkWell(
      key: ValueKey('homework-task-details-${task.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openTask(context, task.id, number),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            Text(number, style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.taskState(task).label}${notes.isEmpty ? '' : ' · ${notes.length} Kommentar${notes.length == 1 ? '' : 'e'}'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
      ),
    );
    final states = HomeworkStatusSelector(
      task: task,
      value: r.taskState(task),
      onChanged: busy || r.deleted ? null : (value) => onTaskState(task, value),
    );
    return Padding(
      key: ValueKey('homework-task-${task.id}'),
      padding: EdgeInsets.only(left: task.parentId == null ? 0 : 10, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= 540 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20
                ? Row(
                    children: [
                      Expanded(child: title),
                      states,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      Align(alignment: Alignment.centerLeft, child: states),
                    ],
                  ),
          ),
          HomeworkThumbnails(
            key: ValueKey('task-previews-${task.id}'),
            controller: controller,
            scope: schoolScanContext(controller, [r], taskIds: {r.id: task.id}),
            readOnly: r.deleted,
          ),
        ],
      ),
    );
  }

  Future<void> _openTask(
    BuildContext context,
    String taskId,
    String number,
  ) => showFlexDetail<void>(
    context: context,
    builder: (dialogContext) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.records
            .where((r) => r.id == record.id)
            .firstOrNull;
        final task = current?.tasks.where((t) => t.id == taskId).firstOrNull;
        final notes = current?.liveFeedback.where(
          (f) => f.taskId == taskId && f.note.isNotEmpty,
        );
        return FlexModal(
          title: Text(
            '${task?.parentId == null ? 'Aufgabe' : 'Teilaufgabe'} $number',
          ),
          onClose: () => Navigator.pop(dialogContext),
          content: task == null || current == null
              ? const Text('Diese Aufgabe wurde entfernt.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.text,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Stand: ${current.taskState(task).label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (!current.deleted)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: ValueKey('comment-$taskId'),
                          onPressed: () => onComment(taskId),
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          label: Text(
                            notes!.isEmpty
                                ? 'Kommentar hinzufügen'
                                : 'Kommentar ergänzen',
                          ),
                        ),
                      ),
                    for (final note in notes!.toList().reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note.note),
                            Text(
                              '${displayDate(note.observedOn)} ${note.observedTime}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    DocumentAttachmentSection(
                      key: ValueKey('task-attachments-$taskId'),
                      controller: controller,
                      scope: schoolScanContext(
                        controller,
                        [current],
                        taskIds: {current.id: taskId},
                      ),
                      readOnly: current.deleted,
                    ),
                  ],
                ),
        );
      },
    ),
  );
}

String homeworkDeliveryLabel(String value) =>
    const {
      'unknown': 'Nicht überprüft',
      'submitted': 'Vorgelegt',
      'missing': 'Nicht vorgelegt',
      'absent': 'Abwesend',
    }[value] ??
    value;

ButtonStyle _quietButton(BuildContext context) => TextButton.styleFrom(
  backgroundColor: Colors.transparent,
  foregroundColor: Theme.of(context).colorScheme.onSurface,
  minimumSize: const Size(44, 44),
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  textStyle: const TextStyle(fontFamily: 'FlexSans', fontSize: 13),
);

class HomeworkStatusSelector extends StatelessWidget {
  const HomeworkStatusSelector({
    super.key,
    required this.task,
    required this.value,
    required this.onChanged,
  });
  final HomeworkTask task;
  final TaskState value;
  final ValueChanged<TaskState>? onChanged;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final state in TaskState.values)
          Semantics(
            selected: value == state,
            inMutuallyExclusiveGroup: true,
            child: IconButton(
              key: ValueKey('status-${task.id}-${state.name}'),
              tooltip: state.label,
              onPressed: onChanged == null ? null : () => onChanged!(state),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                maximumSize: const Size(44, 44),
                padding: const EdgeInsets.all(10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: value == state
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: .65),
                backgroundColor: value == state
                    ? scheme.primary.withValues(alpha: .13)
                    : Colors.transparent,
              ),
              icon: Icon(switch (state) {
                TaskState.open => Icons.radio_button_unchecked,
                TaskState.complete => Icons.check_circle_outline,
                TaskState.partial => Icons.contrast,
                TaskState.missing => Icons.cancel_outlined,
              }, size: 24),
            ),
          ),
      ],
    );
  }
}

/// Evidence stays visible in the list even while task details are closed.
class HomeworkThumbnails extends StatelessWidget {
  const HomeworkThumbnails({
    super.key,
    required this.controller,
    required this.scope,
    required this.readOnly,
  });
  final NotebookController controller;
  final ScanContext scope;
  final bool readOnly;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final docs = controller.classroom.where(scope.matchesMaterial).toList();
      final drafts = controller.dialogDrafts.where(scope.matchesDraft).toList();
      if (docs.isEmpty && drafts.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: SizedBox(
          height: math.max(
            56,
            MediaQuery.textScalerOf(context).scale(12) * 2.5 + 12,
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length + drafts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final doc = index < docs.length ? docs[index] : null;
              final draft = doc == null ? drafts[index - docs.length] : null;
              return SizedBox(
                width: 200,
                child: InkWell(
                  key: ValueKey(
                    doc == null
                        ? 'homework-draft-${draft!.id}'
                        : 'attachment-file-${doc.id}',
                  ),
                  onTap: doc != null
                      ? () => guarded(
                          context,
                          () => openMaterial(context, controller, doc),
                        )
                      : readOnly
                      ? null
                      : () => scanAndShow(
                          context,
                          controller,
                          scope,
                          draft: draft,
                        ),
                  child: Row(
                    children: [
                      if (doc != null)
                        MaterialThumbnail(material: doc, width: 44, height: 56)
                      else
                        ScanDraftThumbnail(draft: draft!),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doc?.title ??
                              '${draft!.data['title'] ?? 'Scan'} · Entwurf',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
