import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/document_scanner.dart';
import '../domain/school.dart';
import 'common.dart';
import 'document_attachments.dart';

/// The task, its result and its evidence form one unit. Record-wide actions
/// have a separate section so that attachments and comments retain their scope.
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
    required this.onDelivery,
    required this.onReminder,
    required this.onDelete,
    required this.onJournal,
    this.error,
    this.history,
  });
  final NotebookController controller;
  final SchoolRecord record;
  final bool expanded, standalone, busy;
  final VoidCallback onExpand, onEdit, onReminder, onDelete, onJournal;
  final void Function(HomeworkTask, TaskState) onTaskState;
  final void Function(String?) onComment;
  final VoidCallback onDelivery;
  final Widget? error, history;

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
    final editable = !busy && !r.deleted;
    return Column(
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
                  if (title.isNotEmpty || !standalone)
                    Text(
                      title.isEmpty ? 'Hausübung' : title,
                      style: theme.textTheme.titleLarge,
                    ),
                  Text(
                    owner?.name ?? 'Unbekannt',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'Aufgegeben ${displayDate(r.observedOn)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (r.subject.isNotEmpty && r.subject != title)
                    Text(r.subject, style: theme.textTheme.bodySmall),
                  if (r.dueDate != null)
                    Text(
                      'Fällig: ${displayDate(r.dueDate)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('Aufgaben', style: theme.textTheme.titleSmall),
            Text(
              '$complete / ${r.tasks.length} erledigt',
              key: ValueKey('homework-progress-${r.id}'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: r.tasks.isEmpty ? 0 : complete / r.tasks.length,
          minHeight: 3,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: colors.onSurface.withValues(alpha: .1),
          semanticsLabel: '$complete von ${r.tasks.length} Aufgaben erledigt',
        ),
        if (expanded || standalone) ...[
          if (r.tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Noch keine Aufgaben.'),
            ),
          for (var i = 0; i < r.tasks.length; i++)
            _task(context, r.tasks[i], i),
          const Divider(height: 28),
          Text('Zur Hausübung', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Abgabe'),
              TextButton.icon(
                key: ValueKey('homework-delivery-${r.id}'),
                onPressed: editable ? onDelivery : null,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(
                  const {
                        'unknown': 'Nicht überprüft',
                        'submitted': 'Vorgelegt',
                        'missing': 'Nicht vorgelegt',
                        'absent': 'Abwesend',
                      }[r.delivery] ??
                      r.delivery,
                ),
              ),
            ],
          ),
          if (generalNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(generalNotes.last.note),
            ),
          _HomeworkFiles(
            key: ValueKey('record-attachments-${r.id}'),
            controller: c,
            scope: schoolScanContext(c, [r], includeTasks: false),
            readOnly: r.deleted,
            busy: busy,
            leading: _Action(
              label: 'Notiz',
              tooltip: 'Notiz & Verlauf',
              icon: Icons.chat_bubble_outline,
              onPressed: editable ? () => onComment(null) : null,
            ),
          ),
          ?history,
          if (r.needsCompletion) const Text('Später ergänzen'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (r.pending && !r.deleted)
                Expanded(
                  child: _Action(
                    label: 'Erinnern',
                    tooltip: 'Erinnerung verschieben',
                    icon: Icons.snooze,
                    onPressed: busy ? null : onReminder,
                  ),
                ),
              Expanded(
                child: _Action(
                  label: 'Änderungen',
                  tooltip: 'Änderungen',
                  icon: Icons.history,
                  onPressed: onJournal,
                ),
              ),
              Expanded(
                child: _Action(
                  label: r.deleted ? 'Zurückholen' : 'Löschen',
                  tooltip: r.deleted ? 'Wiederherstellen' : 'Papierkorb',
                  icon: r.deleted ? Icons.restore : Icons.delete_outline,
                  onPressed: busy ? null : onDelete,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _task(BuildContext context, HomeworkTask task, int index) {
    final r = record, theme = Theme.of(context);
    final notes = r.liveFeedback.where(
      (f) => f.taskId == task.id && f.note.isNotEmpty,
    );
    final parents = r.tasks.where((t) => t.parentId == null).toList();
    final number = task.parentId == null
        ? '${parents.indexOf(task) + 1}'
        : '${parents.indexWhere((t) => t.id == task.parentId) + 1}.${r.tasks.where((t) => t.parentId == task.parentId).toList().indexOf(task) + 1}';
    return Padding(
      key: ValueKey('homework-task-${task.id}'),
      padding: EdgeInsets.only(top: 18, left: task.parentId == null ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: Text(number, style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: Text(
                  task.text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HomeworkStatusSelector(
            task: task,
            value: r.taskState(task),
            onChanged: busy || r.deleted
                ? null
                : (state) => onTaskState(task, state),
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(notes.last.note),
            ),
          _HomeworkFiles(
            key: ValueKey('task-attachments-${task.id}'),
            controller: controller,
            scope: schoolScanContext(controller, [r], taskIds: {r.id: task.id}),
            readOnly: r.deleted,
            busy: busy,
            leading: _Action(
              key: ValueKey('comment-${task.id}'),
              label: notes.isEmpty
                  ? 'Kommentar'
                  : 'Kommentar (${notes.length})',
              tooltip:
                  '${notes.isEmpty ? 'Kommentar' : 'Kommentar vorhanden'} zu ${task.text}',
              icon: Icons.chat_bubble_outline,
              onPressed: busy || r.deleted ? null : () => onComment(task.id),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final state in TaskState.values)
            Expanded(
              child: Semantics(
                selected: value == state,
                inMutuallyExclusiveGroup: true,
                child: _Action(
                  key: ValueKey('status-${task.id}-${state.name}'),
                  label: switch (state) {
                    TaskState.open => 'Offen',
                    TaskState.complete => 'Erledigt',
                    TaskState.partial => 'Teilweise',
                    TaskState.missing => 'Fehlt',
                  },
                  tooltip: state.label,
                  icon: switch (state) {
                    TaskState.open => Icons.radio_button_unchecked,
                    TaskState.complete => Icons.check_circle_outline,
                    TaskState.partial => Icons.contrast,
                    TaskState.missing => Icons.cancel_outlined,
                  },
                  selected: state == value,
                  onPressed: onChanged == null ? null : () => onChanged!(state),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeworkFiles extends StatelessWidget {
  const _HomeworkFiles({
    super.key,
    required this.controller,
    required this.scope,
    required this.readOnly,
    required this.busy,
    required this.leading,
  });
  final NotebookController controller;
  final ScanContext scope;
  final bool readOnly, busy;
  final Widget leading;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final count = controller.classroom.where(scope.matchesMaterial).length;
      final drafts = controller.dialogDrafts.where(scope.matchesDraft).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!readOnly)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leading),
                Expanded(
                  child: _Action(
                    key: const ValueKey('attachment-scan'),
                    label: 'Scannen',
                    tooltip: 'Scannen / Foto',
                    icon: Icons.document_scanner_outlined,
                    onPressed: busy
                        ? null
                        : () => scanAndShow(context, controller, scope),
                  ),
                ),
                Expanded(
                  child: _Action(
                    key: const ValueKey('attachment-documents'),
                    label: count + drafts == 0
                        ? 'Dateien'
                        : 'Dateien (${count + drafts})',
                    tooltip:
                        'Dokumente · $count${drafts == 0 ? '' : ' · $drafts Entwürfe'}',
                    icon: Icons.attach_file,
                    onPressed: busy
                        ? null
                        : () =>
                              showContextDocuments(context, controller, scope),
                  ),
                ),
              ],
            ),
          DocumentAttachmentSection(
            controller: controller,
            scope: scope,
            compact: true,
            readOnly: readOnly,
            showActions: false,
          ),
        ],
      );
    },
  );
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });
  final String label, tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          backgroundColor: selected
              ? scheme.primary.withValues(alpha: .16)
              : Colors.transparent,
          foregroundColor: selected ? scheme.primary : scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
