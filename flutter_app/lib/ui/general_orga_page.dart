import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'collapsible_search.dart';
import 'draft_actions.dart';
import 'flex_modal.dart';

/// Shared class entries, exposed as focused task/note views without copying data.
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
  String query = '', filter = 'all';
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
        title: const Text('Allgemeine Entwürfe'),
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
              const Text('Keine allgemeinen Entwürfe.'),
          ],
        ),
      ),
    ),
  );

  bool matches(OrgaEntry e) =>
      e.pupilId == null &&
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
                  '${e.title} ${e.body} ${e.items.map((i) => i.text).join(' ')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()) &&
                  (filter == 'all' ||
                      (filter == 'appointments'
                          ? e.isAppointment
                          : filter == 'notes'
                          ? !e.isTask && !e.isAppointment
                          : e.isTask && e.done == (filter == 'done'))),
            )
            .toList();
        values.sort((a, b) {
          if (widget.kind == 'task') {
            if (a.done != b.done) return a.done ? 1 : -1;
            final date = (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
            if (date != 0) return date;
          }
          return b.updatedAtUtc.compareTo(a.updatedAtUtc);
        });
        final title = switch (widget.kind) {
          'task' => 'Aufgaben',
          'note' => 'Allgemeine Notizen',
          _ => 'Organisation',
        };
        final drafts = c.drafts.where((d) => matches(d.entry)).length;
        return ListView(
          key: PageStorageKey('general-${widget.kind}'),
          padding: const EdgeInsets.all(16),
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
                    if (widget.kind == 'all') ...{
                      'notes': 'Notizen',
                      'appointments': 'Termine',
                    },
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: filter == option.key,
                      onSelected: (_) => setState(() => filter = option.key),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              Text(
                widget.kind == 'task'
                    ? 'Keine passenden allgemeinen Aufgaben.'
                    : widget.kind == 'note'
                    ? 'Keine passenden allgemeinen Notizen.'
                    : 'Keine passenden Orga-Einträge.',
              ),
            for (final entry in values) widget.entryBuilder(entry),
          ],
        );
      },
    );
  }
}
