import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/classroom.dart';
import 'collapsible_search.dart';
import 'draft_actions.dart';
import 'flex_modal.dart';
import 'common.dart';
import 'selection_controls.dart';
import 'surfaces.dart';
import 'return_lists.dart';
import 'classroom_editor.dart';
import '../domain/calendar_layout.dart' show calendarMonth;

typedef _OrgaRow = ({
  OrgaEntry? entry,
  ClassroomDocument? document,
  bool done,
  String due,
  String updated,
});
String _rowId(_OrgaRow r) =>
    r.entry != null ? 'entry-${r.entry!.id}' : 'return-${r.document!.id}';
String _rowType(_OrgaRow r) => r.document != null
    ? 'returns'
    : r.entry!.isAppointment
    ? 'appointments'
    : r.entry!.isTask
    ? 'tasks'
    : 'notes';
const _sections = {
  'tasks': 'Aufgaben',
  'returns': 'Rückläufe',
  'appointments': 'Termine',
  'notes': 'Notizen',
};

/// Entries by kind, including pupil assignments, without copying data.
class GeneralOrgaPage extends StatefulWidget {
  const GeneralOrgaPage({
    super.key,
    required this.controller,
    required this.kind,
    this.returnRequest = 0,
    required this.onEdit,
    this.onOpen,
    required this.entryBuilder,
    required this.onEditDraft,
  });
  final NotebookController controller;
  final String kind;
  final int returnRequest;
  final Future<void> Function(OrgaEntry) onEdit;
  final Future<void> Function(OrgaEntry)? onOpen;
  final Widget Function(OrgaEntry) entryBuilder;
  final ValueChanged<EditDraft> onEditDraft;
  @override
  State<GeneralOrgaPage> createState() => _GeneralOrgaPageState();
}

class _GeneralOrgaPageState extends State<GeneralOrgaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool classOnly = false;
  String query = '', filter = 'all', typeFilter = 'all';
  final search = TextEditingController();
  bool selecting = false, saving = false;
  final selected = <String>{};
  void mark(String id) => setState(() {
    selecting = true;
    if (!selected.add(id)) selected.remove(id);
  });
  void finish() {
    selected.clear();
    selecting = false;
  }

  Future<void> apply(List<_OrgaRow> rows, String action) async {
    if (rows.isEmpty || saving) return;
    if (action == 'trash' &&
        !await confirmFlex(
          context,
          'Auswahl in den Papierkorb?',
          '${rows.length} Einträge verschieben?',
          accept: 'Verschieben',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => saving = true);
    final ok = await guarded(context, () async {
      final entries = <OrgaEntry>[], returns = <ClassroomDocument>[];
      for (final r in rows) {
        final e = r.entry;
        if (e == null) {
          if (action == 'trash') {
            returns.add(r.document!.patch({'deleted': true}));
          }
          continue;
        }
        if (action == 'trash') {
          entries.add(
            e.copyWith(
              deleted: true,
              reminderState: e.reminderState == ReminderState.planned
                  ? ReminderState.cancelled
                  : e.reminderState,
            ),
          );
        }
        if (action == 'complete' && e.isTask && !e.done) {
          entries.add(e.complete());
        }
        if (action == 'reopen' && e.isTask && e.done) entries.add(e.reopen());
      }
      await widget.controller.repository.saveOrganisationSelection(
        entries,
        returns,
      );
      await widget.controller.reload();
    });
    if (mounted) {
      setState(() {
        saving = false;
        if (ok) finish();
      });
    }
  }

  Iterable<DialogDraft> get returnDrafts => widget.controller.dialogDrafts
      .where((d) => widget.kind != 'note' && isReturnDraft(d));

  @override
  void initState() {
    super.initState();
    classOnly = widget.kind == 'class';
    if (widget.returnRequest > 0) typeFilter = 'returns';
  }

  @override
  void didUpdateWidget(covariant GeneralOrgaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.returnRequest != oldWidget.returnRequest) {
      classOnly = false;
      filter = 'all';
      typeFilter = 'returns';
      query = '';
      search.clear();
    }
  }

  Future<void> revealSavedReturn(Future<void> Function() edit) async {
    final before = widget.controller.classroom.map((d) => d.id).toSet();
    await edit();
    if (!mounted) return;
    final saved = widget.controller.classroom
        .where(
          (d) =>
              d.kind == ClassroomKind.returnList &&
              !d.deleted &&
              !before.contains(d.id),
        )
        .firstOrNull;
    if (saved == null) return;
    if (widget.kind == 'note') {
      await showReturnDetail(context, widget.controller, saved.id);
      return;
    }
    // A successful creation must not disappear behind the previous filters.
    setState(() {
      filter = 'all';
      if (typeFilter != 'all') typeFilter = 'returns';
      query = '';
      search.clear();
    });
  }

  Future<void> create() => revealSavedReturn(
    () => typeFilter == 'returns'
        ? showClassroomEditor(
            context,
            widget.controller,
            ClassroomKind.returnList,
          )
        : widget.onEdit(
            OrgaEntry.empty().copyWith(
              isTask: widget.kind == 'task' || typeFilter == 'tasks',
              appointmentDate: typeFilter == 'appointments'
                  ? dateOnly(DateTime.now())
                  : null,
            ),
          ),
  );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> showDrafts() => showDialog<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: widget.controller,
      builder: (ctx, _) => FlexModal(
        title: const Text('Entwürfe'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final draft in widget.controller.drafts.where(
              (d) => matches(d.entry),
            ))
              ListTile(
                title: Text(
                  draft.entry.body.isEmpty
                      ? draft.entry.title
                      : draft.entry.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(widget.controller.owner(draft.entry)),
                onTap: () => widget.onEditDraft(draft),
                trailing: DraftDeleteButton(
                  onDelete: () async {
                    await widget.controller.repository.discardDraft(
                      draft.id,
                      expectedRevision: draft.editRevision,
                    );
                    await widget.controller.reload();
                  },
                ),
              ),
            for (final draft in returnDrafts)
              ListTile(
                title: Text(
                  (draft.data['title'] as String? ?? '').trim().isEmpty
                      ? 'Rücklauf'
                      : draft.data['title'] as String,
                ),
                subtitle: const Text('Rücklauf · Entwurf'),
                onTap: () {
                  Navigator.pop(ctx);
                  revealSavedReturn(
                    () => showClassroomEditor(
                      context,
                      widget.controller,
                      ClassroomKind.returnList,
                      draft: draft,
                    ),
                  );
                },
                trailing: DraftDeleteButton(
                  onDelete: () async {
                    await widget.controller.repository.discardDialogDraft(
                      draft.id,
                      draft.revision,
                    );
                    await widget.controller.reload();
                  },
                ),
              ),
            if (!widget.controller.drafts.any((d) => matches(d.entry)) &&
                returnDrafts.isEmpty)
              const Text('Keine Entwürfe.'),
          ],
        ),
      ),
    ),
  );

  bool matches(OrgaEntry e) =>
      (!classOnly || e.pupilId == null) &&
      (e.pupilId == null ||
          widget.controller.pupils.any(
            (p) => p.id == e.pupilId && !p.archived,
          )) &&
      !e.deleted &&
      switch (widget.kind) {
        'task' => e.isTask,
        'note' => !e.isTask && !e.isAppointment,
        _ => true,
      };
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (ctx, _) {
        final c = widget.controller;
        final today = dateOnly(DateTime.now());
        bool matchesStatus(bool done, String? due) => switch (filter) {
          'overdue' =>
            !done && due != null && due.isNotEmpty && due.compareTo(today) < 0,
          'open' => !done,
          'done' => done,
          _ => true,
        };
        final values = c.entries
            .where(
              (e) =>
                  matches(e) &&
                  typeFilter != 'returns' &&
                  (typeFilter == 'all' ||
                      typeFilter == 'tasks' && e.isTask ||
                      typeFilter == 'appointments' && e.isAppointment ||
                      typeFilter == 'notes' && !e.isTask && !e.isAppointment) &&
                  '${e.title} ${e.body} ${c.owner(e)} ${e.tags.join(' ')} ${e.items.map((i) => i.text).join(' ')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()) &&
                  (filter == 'all' ||
                      e.isTask && matchesStatus(e.done, e.dueDate)),
            )
            .toList();
        final returns = c.classroom.where(
          (d) =>
              widget.kind != 'note' &&
              (typeFilter == 'all' || typeFilter == 'returns') &&
              d.kind == ClassroomKind.returnList &&
              !d.deleted &&
              '${d.title} ${d.text('note')} ${d.text('otherParticipants')} ${d.rows('participants').map((r) => r['name']).join(' ')}'
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              matchesStatus(d.returnFinished, d.text('dueDate')),
        );
        final items = <_OrgaRow>[
          for (final e in values)
            (
              entry: e,
              document: null,
              done: e.done,
              due: e.dueDate ?? '9999',
              updated: e.updatedAtUtc,
            ),
          for (final d in returns)
            (
              entry: null,
              document: d,
              done: d.returnFinished,
              due: d.text('dueDate').isEmpty ? '9999' : d.text('dueDate'),
              updated: d.text('updatedAtUtc'),
            ),
        ];
        items.sort((a, b) {
          if (widget.kind == 'task') {
            if (a.done != b.done) return a.done ? 1 : -1;
            final date = a.due.compareTo(b.due);
            if (date != 0) return date;
          }
          return b.updated.compareTo(a.updated);
        });
        final title = switch (widget.kind) {
          'task' => 'Aufgaben',
          'note' => 'Orga-Notizen',
          'class' => 'Klassen-Orga',
          _ => 'Organisation',
        };
        final drafts =
            c.drafts.where((d) => matches(d.entry)).length +
            returnDrafts.length;
        final types = {
          'all': 'Alle Arten',
          'tasks': widget.kind == 'task' ? 'Nur Aufgaben' : 'Aufgaben',
          'returns': 'Rückläufe',
          if (widget.kind == 'all' || widget.kind == 'class') ...{
            'notes': 'Notizen',
            'appointments': 'Termine',
          },
        };
        final overview = widget.kind == 'all';
        final chosen = items
            .where((d) => selected.contains(_rowId(d)))
            .toList();
        final all = items.isNotEmpty && chosen.length == items.length;
        final allTasks =
            chosen.isNotEmpty && chosen.every((r) => r.entry?.isTask == true);
        final allDone = allTasks && chosen.every((r) => r.done);
        Widget row(_OrgaRow item) {
          final e = item.entry, d = item.document;
          final id = _rowId(item);
          final title = e?.title ?? d!.title;
          final meta = e == null
              ? [
                  if (d!.returnFinished)
                    d.returnState.label
                  else
                    '${d.rows('participants').where(returnPending).length} von ${d.rows('participants').length} offen',
                  if (d.text('dueDate').isNotEmpty)
                    'Frist ${displayDate(d.text('dueDate'))}',
                ]
              : [
                  c.owner(e),
                  if (e.isAppointment) ...[
                    displayDate(e.appointmentDate!),
                    if (e.appointmentTime.isNotEmpty) e.appointmentTime,
                  ] else if (e.isTask) ...[
                    e.done ? 'Erledigt' : 'Offen',
                    if (e.dueDate != null) 'Fällig ${displayDate(e.dueDate)}',
                    if (e.items.isNotEmpty)
                      '${e.items.where((i) => i.checked).length}/${e.items.length} Unteraufgaben',
                  ] else if (e.observedOn.isNotEmpty)
                    displayDate(e.observedOn),
                ];
          final type = _rowType(item);
          final child = overview
              ? _OverviewRow(
                  key: ValueKey(
                    e == null ? 'return-entry-${d!.id}' : 'orga-entry-${e.id}',
                  ),
                  type: type,
                  date: e?.appointmentDate == null
                      ? null
                      : schoolDay(e!.appointmentDate!),
                  returnProgress: d == null || d.rows('participants').isEmpty
                      ? null
                      : 1 -
                            d.rows('participants').where(returnPending).length /
                                d.rows('participants').length,
                  title: title,
                  meta: meta.join(' · '),
                  snippet: type == 'notes' && e!.body.trim() != title
                      ? e.body.trim()
                      : '',
                  done: item.done,
                  onOpen: () => e == null
                      ? showReturnDetail(ctx, c, d!.id)
                      : (widget.onOpen ?? widget.onEdit)(e),
                  onCheck: e != null && e.isTask
                      ? () => guarded(
                          ctx,
                          () => c.saveEntry(e.done ? e.reopen() : e.complete()),
                        )
                      : null,
                )
              : e != null
              ? widget.entryBuilder(e)
              : ReturnListCard(controller: c, document: d!);
          return SelectableEntry(
            key: ValueKey('select-$id'),
            selected: selecting ? selected.contains(id) : null,
            onSelect: saving ? null : () => mark(id),
            title: title,
            subtitle: meta.join(' · '),
            child: child,
          );
        }

        final sections = <String, List<_OrgaRow>>{
          for (final k in _sections.keys)
            k: items.where((r) => _rowType(r) == k).toList(),
        };
        for (final kind in ['tasks', 'returns', 'appointments']) {
          sections[kind]!.sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            String order(_OrgaRow r) => r.entry?.appointmentDate == null
                ? r.due
                : '${r.entry!.appointmentDate} ${r.entry!.appointmentTime}';
            if (kind == 'appointments') {
              final now = DateTime.now(),
                  ap = a.entry!.appointmentIsUpcoming(now),
                  bp = b.entry!.appointmentIsUpcoming(now);
              if (ap != bp) return ap ? -1 : 1;
              if (!ap) return order(b).compareTo(order(a));
            }
            final dates = order(a).compareTo(order(b));
            return dates == 0 ? b.updated.compareTo(a.updated) : dates;
          });
        }
        return ListView(
          key: PageStorageKey('general-${widget.kind}'),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
          children: [
            CollapsibleSearch(
              controller: search,
              fieldKey: ValueKey('general-search-${widget.kind}'),
              buttonKey: ValueKey('general-search-button-${widget.kind}'),
              label: 'Einträge durchsuchen',
              iconOnly: true,
              onChanged: (v) => setState(() => query = v),
              leading: Text(
                title,
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              actions: [
                if (items.isNotEmpty && !selecting)
                  IconButton(
                    tooltip: 'Einträge auswählen',
                    icon: const Icon(Icons.checklist),
                    onPressed: () => setState(() => selecting = true),
                  ),
                if (drafts > 0)
                  IconButton(
                    tooltip: 'Entwürfe · $drafts',
                    onPressed: showDrafts,
                    icon: Badge(
                      label: Text('$drafts'),
                      child: const Icon(Icons.edit_note),
                    ),
                  ),
                IconButton(
                  key: ValueKey('general-add-${widget.kind}'),
                  tooltip: typeFilter == 'returns'
                      ? 'Rücklauf anlegen'
                      : typeFilter == 'appointments'
                      ? 'Termin anlegen'
                      : widget.kind == 'task'
                      ? 'Aufgabe anlegen'
                      : widget.kind == 'note'
                      ? 'Notiz anlegen'
                      : 'Orga anlegen',
                  onPressed: create,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (selecting)
              SelectionControls(
                count: chosen.length,
                allVisibleSelected: all,
                onFinish: saving ? null : () => setState(finish),
                onToggleAll: saving || items.isEmpty
                    ? null
                    : () => setState(() {
                        if (all) {
                          selected.clear();
                        } else {
                          selected.addAll(items.map(_rowId));
                        }
                      }),
                actions: [
                  if (allTasks)
                    TextButton.icon(
                      onPressed: saving
                          ? null
                          : () =>
                                apply(chosen, allDone ? 'reopen' : 'complete'),
                      icon: Icon(allDone ? Icons.undo : Icons.done_all),
                      label: Text(allDone ? 'Wieder öffnen' : 'Erledigen'),
                    ),
                  IconButton(
                    tooltip: 'Auswahl in den Papierkorb',
                    onPressed: saving || chosen.isEmpty
                        ? null
                        : () => apply(chosen, 'trash'),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              )
            else if (overview) ...[
              Wrap(
                spacing: 5,
                runSpacing: 2,
                children: [
                  for (final type in _sections.entries)
                    FilterChip(
                      key: ValueKey('general-type-all-${type.key}'),
                      label: Text(type.value),
                      selected: typeFilter == type.key,
                      onSelected: (v) =>
                          setState(() => typeFilter = v ? type.key : 'all'),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    key: const ValueKey('general-class-only-all'),
                    label: const Text('Nur Klasse'),
                    selected: classOnly,
                    onSelected: (v) => setState(() => classOnly = v),
                  ),
                  for (final pair in {
                    'open': 'Offen',
                    'overdue': 'Überfällig',
                    'done': 'Erledigt',
                  }.entries)
                    FilterChip(
                      label: Text(pair.value),
                      selected: filter == pair.key,
                      onSelected: (v) =>
                          setState(() => filter = v ? pair.key : 'all'),
                    ),
                ],
              ),
            ] else if (widget.kind != 'note') ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  FilterChip(
                    key: ValueKey('general-class-only-${widget.kind}'),
                    label: const Text('Nur Klasse'),
                    selected: classOnly,
                    onSelected: (v) => setState(() => classOnly = v),
                  ),
                  for (final option in {
                    'all': 'Alle',
                    'open': 'Offen',
                    'overdue': 'Überfällig',
                    'done': 'Erledigt',
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: filter == option.key,
                      onSelected: (_) => setState(() => filter = option.key),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                key: ValueKey('general-type-filter-${widget.kind}'),
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final type in types.entries)
                    ChoiceChip(
                      key: ValueKey('general-type-${widget.kind}-${type.key}'),
                      label: Text(type.value),
                      selected: typeFilter == type.key,
                      onSelected: (_) => setState(() => typeFilter = type.key),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                widget.kind == 'task'
                    ? 'Keine passenden Aufgaben.'
                    : widget.kind == 'note'
                    ? 'Keine passenden Notizen.'
                    : 'Keine passenden Orga-Einträge.',
              ),
            if (overview) ...[
              for (final section in sections.entries.where(
                (s) => s.value.isNotEmpty,
              )) ...[
                Padding(
                  key: ValueKey('orga-section-${section.key}'),
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sections[section.key]!,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${section.value.length}',
                        style: Theme.of(ctx).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                for (final (index, item) in section.value.indexed)
                  Material(
                    color: Theme.of(ctx).colorScheme.surfaceContainerLow,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(15) : Radius.zero,
                      bottom: index == section.value.length - 1
                          ? const Radius.circular(15)
                          : Radius.zero,
                    ),
                    child: Column(
                      children: [
                        if (index > 0)
                          const Divider(height: 1, indent: 62, endIndent: 12),
                        row(item),
                      ],
                    ),
                  ),
              ],
            ] else
              for (final item in items) row(item),
          ],
        );
      },
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    super.key,
    required this.type,
    required this.title,
    required this.meta,
    required this.snippet,
    required this.done,
    required this.onOpen,
    this.date,
    this.returnProgress,
    this.onCheck,
  });
  final String type, title, meta, snippet;
  final bool done;
  final VoidCallback onOpen;
  final DateTime? date;
  final double? returnProgress;
  final VoidCallback? onCheck;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), s = theme.colorScheme;
    final (icon, color) = switch (type) {
      'tasks' => (
        done ? Icons.task_alt : Icons.check_box_outline_blank_rounded,
        s.primary,
      ),
      'returns' => (Icons.assignment_return_outlined, FlexDesign.dueColor(s)),
      'appointments' => (
        Icons.calendar_today_outlined,
        FlexDesign.appointmentColor(s),
      ),
      _ => (Icons.sticky_note_2_outlined, s.onSurfaceVariant),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: onCheck == null
            ? SizedBox.square(
                dimension: 42,
                child: date == null
                    ? Icon(icon, color: color, size: 21)
                    : ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  calendarMonth(date!).substring(0, 3),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    height: 1.1,
                                    color: color,
                                  ),
                                ),
                                Text(
                                  '${date!.day}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              )
            : IconButton(
                tooltip: done ? 'Wieder öffnen' : 'Erledigen',
                onPressed: onCheck,
                icon: Icon(icon, color: color),
              ),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snippet.isNotEmpty)
            Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(meta, style: theme.textTheme.bodySmall),
          if (returnProgress != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 3),
              child: SizedBox(
                width: 78,
                child: LinearProgressIndicator(
                  value: returnProgress,
                  minHeight: 3,
                  color: color,
                  backgroundColor: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
      trailing: Tooltip(
        message: switch (type) {
          'tasks' => 'Aufgabendetails',
          'appointments' => 'Termindetails',
          'returns' => 'Rücklauf öffnen',
          _ => 'Notiz öffnen',
        },
        child: const Icon(Icons.chevron_right, size: 18),
      ),
      onTap: onOpen,
    );
  }
}
