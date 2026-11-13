import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/classroom.dart';
import 'classroom_editor.dart';
import 'collapsible_search.dart';
import 'draft_actions.dart';
import 'flex_modal.dart';
import 'return_lists.dart';

/// Entries by kind, including pupil assignments, without copying data.
class GeneralOrgaPage extends StatefulWidget {
  const GeneralOrgaPage({
    super.key,
    required this.controller,
    required this.kind,
    required this.onEdit,
    required this.entryBuilder,
    required this.onEditDraft,
  });
  final NotebookController controller;
  final String kind;
  final ValueChanged<OrgaEntry> onEdit;
  final Widget Function(OrgaEntry) entryBuilder;
  final ValueChanged<EditDraft> onEditDraft;
  @override
  State<GeneralOrgaPage> createState() => _GeneralOrgaPageState();
}

class _GeneralOrgaPageState extends State<GeneralOrgaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String query = '', filter = 'all', typeFilter = 'all';
  final search = TextEditingController();
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
            if (!widget.controller.drafts.any((d) => matches(d.entry)))
              const Text('Keine Entwürfe.'),
          ],
        ),
      ),
    ),
  );

  bool matches(OrgaEntry e) =>
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
        final values = c.entries
            .where(
              (e) =>
                  matches(e) &&
                  typeFilter != 'returns' &&
                  (typeFilter == 'all' ||
                      typeFilter == 'tasks' && e.isTask ||
                      typeFilter == 'appointments' && e.isAppointment ||
                      typeFilter == 'notes' && !e.isTask && !e.isAppointment) &&
                  '${e.title} ${e.body} ${c.owner(e)} ${e.items.map((i) => i.text).join(' ')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()) &&
                  (filter == 'all' || e.isTask && e.done == (filter == 'done')),
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
              (filter == 'all' || d.flag('closed') == (filter == 'done')),
        );
        final items =
            <
              ({
                OrgaEntry? entry,
                ClassroomDocument? document,
                bool done,
                String due,
                String updated,
              })
            >[
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
                  done: d.flag('closed'),
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
          'note' => 'Notizen',
          _ => 'Organisation',
        };
        final drafts = c.drafts.where((d) => matches(d.entry)).length;
        final types = {
          'all': 'Alle Arten',
          'tasks': 'Aufgaben',
          'returns': 'Rückläufe',
          if (widget.kind == 'all') ...{
            'notes': 'Notizen',
            'appointments': 'Termine',
          },
        };
        return ListView(
          key: PageStorageKey('general-${widget.kind}'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
                if (widget.kind != 'note')
                  IconButton(
                    tooltip: 'Rücklauf anlegen',
                    onPressed: () =>
                        showClassroomEditor(ctx, c, ClassroomKind.returnList),
                    icon: const Icon(Icons.add_task),
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
                  tooltip: widget.kind == 'task'
                      ? 'Aufgabe anlegen'
                      : widget.kind == 'note'
                      ? 'Notiz anlegen'
                      : 'Orga anlegen',
                  onPressed: () => widget.onEdit(
                    OrgaEntry.empty().copyWith(isTask: widget.kind == 'task'),
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (widget.kind != 'note')
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final option in {
                    'all': 'Alle',
                    'open': 'Offen',
                    'done': 'Erledigt',
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: filter == option.key,
                      onSelected: (_) => setState(() => filter = option.key),
                    ),
                  Semantics(
                    container: true,
                    button: true,
                    child: PopupMenuButton<String>(
                      key: ValueKey('general-type-filter-${widget.kind}'),
                      tooltip: 'Eintragsart filtern',
                      initialValue: typeFilter,
                      onSelected: (value) => setState(() => typeFilter = value),
                      itemBuilder: (_) => [
                        for (final type in types.entries)
                          CheckedPopupMenuItem(
                            value: type.key,
                            checked: type.key == typeFilter,
                            child: Text(type.value),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list, size: 18),
                            const SizedBox(width: 6),
                            Text(types[typeFilter]!),
                            const Icon(Icons.expand_more, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                widget.kind == 'task'
                    ? 'Keine passenden Aufgaben.'
                    : widget.kind == 'note'
                    ? 'Keine passenden Notizen.'
                    : 'Keine passenden Orga-Einträge.',
              ),
            for (final item in items)
              if (item.entry != null)
                widget.entryBuilder(item.entry!)
              else
                ReturnListCard(controller: c, document: item.document!),
          ],
        );
      },
    );
  }
}
