import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'collapsible_search.dart';
import 'entry_navigation.dart';
import 'flex_icons.dart';
import 'flex_modal.dart';
import 'pupil_history.dart';
import 'school_workspace.dart';
import 'development_dialog.dart';

/// One pupil's entries with persistent area navigation and a quiet action bar.
class PupilWorkspaceDialog extends StatefulWidget {
  const PupilWorkspaceDialog({
    super.key,
    required this.controller,
    required this.pupil,
    required this.entryCard,
    required this.editPupil,
    required this.newOrga,
    required this.newAppointment,
    required this.showDrafts,
    required this.draftCount,
    this.initialArea,
  });
  final NotebookController controller;
  final Pupil pupil;
  final FlexSymbol? initialArea;
  final Widget Function(OrgaEntry) entryCard;
  final VoidCallback editPupil, newOrga, newAppointment, showDrafts;
  final int draftCount;
  @override
  State<PupilWorkspaceDialog> createState() => _PupilWorkspaceDialogState();
}

class _PupilWorkspaceDialogState extends State<PupilWorkspaceDialog> {
  late FlexSymbol? area = widget.initialArea;
  String query = '', filter = 'all';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String areaLabel(FlexSymbol? symbol) => switch (symbol) {
    null => 'Aktuell',
    FlexSymbol.goal => 'Ziele',
    FlexSymbol.social => 'Sozial',
    FlexSymbol.work => 'Arbeit',
    FlexSymbol.homework => 'HÜ',
    FlexSymbol.orga => 'Orga',
  };
  String fullLabel(FlexSymbol symbol) => switch (symbol) {
    FlexSymbol.goal => 'Ziele',
    FlexSymbol.social => 'Sozialverhalten',
    FlexSymbol.work => 'Arbeitsverhalten',
    FlexSymbol.homework => 'Hausübung',
    FlexSymbol.orga => 'Orga',
  };
  void create(FlexSymbol symbol) {
    if (symbol == FlexSymbol.orga) {
      widget.newOrga();
      return;
    }
    editSchool(
      context,
      widget.controller,
      SchoolRecord.empty(
        SchoolKind.values.byName(symbol.name),
        widget.pupil.id,
      ),
    );
  }

  bool matches(bool pending, String text) =>
      text.toLowerCase().contains(query.toLowerCase()) &&
      (filter == 'all' || (filter == 'open' ? pending : !pending));

  Widget navigation() => LayoutBuilder(
    builder: (context, constraints) {
      final scheme = Theme.of(context).colorScheme;
      final columns = constraints.maxWidth >= 620
          ? 6
          : MediaQuery.textScalerOf(context).scale(12) > 21
          ? 2
          : 3;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final symbol in [null, ...FlexSymbol.values])
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 6) / columns,
              child: Semantics(
                button: true,
                selected: area == symbol,
                label: symbol == null ? 'Aktuelle Einträge' : fullLabel(symbol),
                child: Material(
                  color: area == symbol
                      ? scheme.primary.withValues(alpha: .16)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: area == symbol
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('pupil-area-${symbol?.name ?? 'all'}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => area = symbol),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          symbol == null
                              ? Icon(
                                  Icons.view_agenda_outlined,
                                  size: 24,
                                  color: area == symbol
                                      ? scheme.primary
                                      : scheme.onSurface,
                                )
                              : FlexIcon(
                                  symbol,
                                  size: 24,
                                  color: area == symbol
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                          const SizedBox(height: 4),
                          Text(
                            areaLabel(symbol),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: area == symbol
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, p = widget.pupil;
    final rows = <({String id, String date, bool pending, Widget card})>[
      if (area != FlexSymbol.orga)
        for (final r in c.records.where(
          (r) =>
              r.pupilId == p.id &&
              !r.deleted &&
              (area == null || r.kind.name == area!.name) &&
              matches(r.pending, r.searchText),
        ))
          (
            id: r.id,
            date: '${r.observedOn} ${r.observedTime}',
            pending: r.pending,
            card: SchoolRecordCard(
              key: ValueKey(r.id),
              controller: c,
              record: r,
            ),
          ),
      if (area == null || area == FlexSymbol.orga)
        for (final e in c.entries.where(
          (e) =>
              e.pupilId == p.id &&
              matches(
                e.pending,
                '${e.title} ${e.body} ${e.items.map((i) => i.text).join(' ')}',
              ),
        ))
          (
            id: e.id,
            date: e.observedOn.isEmpty ? e.updatedAtUtc : e.observedOn,
            pending: e.pending,
            card: widget.entryCard(e),
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final title = Column(
      key: const ValueKey('pupil-workspace-title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          p.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'FlexSerif',
            fontSize: 20,
            height: 1.15,
          ),
        ),
        Text(
          area == null ? 'Schülerübersicht' : fullLabel(area!),
          style: const TextStyle(fontFamily: 'FlexSans', fontSize: 12),
        ),
      ],
    );
    final headerActions = <Widget>[
      IconButton(
        tooltip: 'Entwicklung',
        icon: const Icon(Icons.insights_outlined),
        onPressed: () => showDevelopment(context, c, p),
      ),
      EntryHeaderButton(
        label: 'Entwürfe',
        icon: Icons.edit_note,
        count: widget.draftCount,
        onPressed: widget.showDrafts,
      ),
      IconButton(
        tooltip: 'Verlauf',
        icon: const Icon(Icons.history, size: 21),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
        padding: const EdgeInsets.all(6),
        onPressed: () => showPupilHistory(context, c, p.id),
      ),
      PopupMenuButton<String>(
        tooltip: 'Schüleraktionen',
        icon: const Icon(Icons.more_vert, size: 21),
        padding: const EdgeInsets.all(6),
        onSelected: (action) {
          if (action == 'edit') {
            widget.editPupil();
          } else if (action == 'brief') {
            showBrief(context, c, p);
          } else {
            guarded(
              context,
              () => c.savePupil(p.copyWith(archived: !p.archived)),
            );
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Schüler bearbeiten')),
          const PopupMenuItem(
            value: 'brief',
            child: Text('Gesprächsvorbereitung'),
          ),
          PopupMenuItem(
            value: 'archive',
            child: Text(p.archived ? 'Aus Archiv holen' : 'Archivieren'),
          ),
        ],
      ),
    ];
    return FlexModal(
      maxWidth: 840,
      accentColor: Color(p.color),
      title: title,
      headerContent: LayoutBuilder(
        builder: (context, constraints) {
          final close = IconButton(
            tooltip: 'Schließen und Eingaben sichern',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          );
          final stacked =
              constraints.maxWidth < 350 ||
              (constraints.maxWidth < 600 &&
                  MediaQuery.textScalerOf(context).scale(20) > 28);
          if (stacked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: title),
                    close,
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: headerActions,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              ...headerActions,
              close,
            ],
          );
        },
      ),
      scrollable: false,
      content: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: ListView(
          key: const PageStorageKey('pupil-workspace'),
          padding: EdgeInsets.zero,
          children: [
            navigation(),
            const SizedBox(height: 16),
            CollapsibleSearch(
              fieldKey: const ValueKey('pupil-entry-search'),
              buttonKey: const ValueKey('pupil-search-button'),
              controller: search,
              label: 'Einträge durchsuchen',
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('pupil-entry-filter'),
                    initialValue: filter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Anzeige',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Alle Einträge'),
                      ),
                      DropdownMenuItem(
                        value: 'open',
                        child: Text('Noch offen'),
                      ),
                      DropdownMenuItem(
                        value: 'closed',
                        child: Text('Abgeschlossen'),
                      ),
                    ],
                    onChanged: (v) => setState(() => filter = v!),
                  ),
                ),
                if (!p.archived && area == FlexSymbol.orga)
                  IconButton(
                    tooltip: 'Termin anlegen',
                    onPressed: widget.newAppointment,
                    icon: const Icon(Icons.event_outlined),
                  ),
                if (!p.archived) ...[
                  const SizedBox(width: 8),
                  if (area != null)
                    IconButton.filledTonal(
                      tooltip: '${fullLabel(area!)} anlegen',
                      onPressed: () => create(area!),
                      icon: const Icon(Icons.add),
                    )
                  else
                    PopupMenuButton<FlexSymbol>(
                      tooltip: 'Eintrag anlegen',
                      icon: const Icon(Icons.add_circle_outline),
                      onSelected: create,
                      itemBuilder: (_) => [
                        for (final s in FlexSymbol.values)
                          PopupMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                FlexIcon(s, size: 20),
                                const SizedBox(width: 10),
                                Flexible(child: Text(fullLabel(s))),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${rows.length} ${rows.length == 1 ? 'Eintrag' : 'Einträge'} · ${rows.where((r) => r.pending).length} offen',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (p.archived) const Text('Archiviert'),
            const SizedBox(height: 6),
            if (rows.isEmpty) const EmptyState('Keine passenden Einträge.'),
            for (final row in rows)
              KeyedSubtree(
                key: ValueKey('pupil-entry-${row.id}'),
                child: row.card,
              ),
          ],
        ),
      ),
    );
  }
}
