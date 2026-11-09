import 'detail_flow.dart';
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
import 'material_library.dart';
import 'document_attachments.dart';
import 'material_thumbnail.dart';
import '../domain/document_scanner.dart';
import 'surfaces.dart';

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
  String? selectedRecordId, selectedEntryId;
  bool get splitView =>
      MediaQuery.sizeOf(context).width >= 900 &&
      MediaQuery.textScalerOf(context).scale(1) <= 1.4;
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
      final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
      final columns = constraints.maxWidth >= 300 && textScale <= 1.4
          ? 6
          : constraints.maxWidth >= 300
          ? 3
          : textScale > 1.4
          ? 2
          : 6;
      return Wrap(
        spacing: 2,
        runSpacing: 4,
        children: [
          for (final symbol in [null, ...FlexSymbol.values])
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 2) / columns,
              child: Semantics(
                button: true,
                selected: area == symbol,
                label: symbol == null ? 'Aktuelle Einträge' : fullLabel(symbol),
                child: Material(
                  color: area == symbol
                      ? scheme.primary.withValues(alpha: .16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: ValueKey('pupil-area-${symbol?.name ?? 'all'}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => area = symbol),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 1,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          symbol == null
                              ? Icon(
                                  Icons.view_agenda_outlined,
                                  size: 21,
                                  color: area == symbol
                                      ? scheme.primary
                                      : scheme.onSurface,
                                )
                              : FlexIcon(
                                  symbol,
                                  size: 21,
                                  color: area == symbol
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                          const SizedBox(height: 4),
                          Text(
                            areaLabel(symbol),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
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

  Widget detailContent({String? recordId, String? entryId}) {
    final c = widget.controller;
    final record = c.records
        .where((r) => r.id == recordId && !r.deleted)
        .firstOrNull;
    final entry = c.entries.where((e) => e.id == entryId).firstOrNull;
    return record != null
        ? SchoolRecordCard(
            key: ValueKey(record.id),
            controller: c,
            record: record,
            standalone: true,
          )
        : entry != null
        ? widget.entryCard(entry)
        : const Text('Dieser Eintrag wurde entfernt.');
  }

  Future<void> details({String? recordId, String? entryId}) async {
    if (splitView) {
      setState(() {
        selectedRecordId = recordId;
        selectedEntryId = entryId;
      });
      return;
    }
    await showFlexDetail<void>(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: widget.controller,
        builder: (_, _) => FlexModal(
          title: Text(
            widget.controller.records
                    .where((r) => r.id == recordId)
                    .firstOrNull
                    ?.kind
                    .label ??
                'Orga',
          ),
          onClose: () => Navigator.pop(ctx),
          content: detailContent(recordId: recordId, entryId: entryId),
        ),
      ),
    );
  }

  Widget workspace(Widget list) {
    if (!splitView) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 4, child: list),
        const VerticalDivider(width: 28),
        Expanded(
          flex: 6,
          child: selectedRecordId == null && selectedEntryId == null
              ? const Center(child: Text('Eintrag auswählen'))
              : SingleChildScrollView(
                  key: ValueKey(
                    'pupil-detail-${selectedRecordId ?? selectedEntryId}',
                  ),
                  child: detailContent(
                    recordId: selectedRecordId,
                    entryId: selectedEntryId,
                  ),
                ),
        ),
      ],
    );
  }

  Widget preview({
    required String id,
    required FlexSymbol symbol,
    required String title,
    required String date,
    required String summary,
    required String status,
    required ScanContext scope,
    required VoidCallback onOpen,
  }) {
    final c = widget.controller;
    final docs = c.classroom.where(scope.matchesMaterial).toList();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: scheme.onSurface.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('pupil-open-entry-$id'),
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: FlexIcon(symbol, size: 22, color: scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (date.isNotEmpty)
                            Text(
                              displayDate(date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                if (summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      status,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                    ),
                  ),
                if (docs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Tooltip(
                          message: docs[i].title,
                          child: InkWell(
                            key: ValueKey('pupil-preview-file-${docs[i].id}'),
                            onTap: () => guarded(
                              context,
                              () => openMaterial(context, c, docs[i]),
                            ),
                            child: MaterialThumbnail(
                              material: docs[i],
                              width: 44,
                              height: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            card: preview(
              id: r.id,
              symbol: FlexSymbol.values.byName(r.kind.name),
              title: r.title.isNotEmpty
                  ? r.title
                  : r.kind == SchoolKind.homework && r.subject.isNotEmpty
                  ? 'Hausübung · ${r.subject}'
                  : r.kind.label,
              date: r.observedOn,
              summary: r.kind == SchoolKind.homework
                  ? r.tasks.map((t) => t.text).join(' · ')
                  : [
                      r.body,
                      ...r.positive.map((t) => '+ $t'),
                      ...r.neutral.map((t) => '• $t'),
                      ...r.negative.map((t) => '− $t'),
                    ].where((s) => s.isNotEmpty).join(' · '),
              status: [
                if (r.kind == SchoolKind.homework)
                  '${r.tasks.where((t) => r.taskState(t) == TaskState.complete).length} / ${r.tasks.length} erledigt',
                if (r.kind == SchoolKind.goal)
                  r.goalStatus == 'active'
                      ? 'In Arbeit'
                      : r.goalStatus == 'achieved'
                      ? 'Erreicht'
                      : 'Beendet',
                if (r.dueDate != null) 'Fällig ${displayDate(r.dueDate)}',
                if (r.nextReviewDate != null)
                  'Überprüfen ${displayDate(r.nextReviewDate)}',
              ].join(' · '),
              scope: schoolScanContext(c, [r]),
              onOpen: () => details(recordId: r.id),
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
            card: preview(
              id: e.id,
              symbol: FlexSymbol.orga,
              title: e.title.isEmpty ? 'Orga' : e.title,
              date: e.observedOn,
              summary: [
                e.body,
                ...e.items.map((i) => i.text),
              ].where((s) => s.isNotEmpty).join(' · '),
              status: e.isTask
                  ? e.done
                        ? 'Erledigt'
                        : 'Offen'
                  : e.isAppointment
                  ? 'Termin ${displayDate(e.appointmentDate)}'
                  : 'Notiz',
              scope: orgaScanContext(c, e),
              onOpen: () => details(entryId: e.id),
            ),
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
      EntryHeaderButton(
        label: 'Entwürfe',
        icon: Icons.edit_note,
        count: widget.draftCount,
        onPressed: widget.showDrafts,
      ),
      PopupMenuButton<String>(
        useRootNavigator: true,
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
      maxWidth: 1120,
      accentColor: Color(p.color),
      title: title,
      headerContent: LayoutBuilder(
        builder: (context, constraints) {
          final close = IconButton(
            tooltip: 'Schließen',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          );
          final stacked =
              constraints.maxWidth < 360 ||
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
      footerContent: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => showDevelopment(context, c, p),
              icon: const Icon(Icons.insights_outlined, size: 19),
              label: const Text('Entwicklung', textAlign: TextAlign.center),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () => showPupilHistory(context, c, p.id),
              icon: const Icon(Icons.history, size: 19),
              label: const Text('Verlauf', textAlign: TextAlign.center),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      ),
      scrollable: false,
      content: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: workspace(
          ListView(
            key: const PageStorageKey('pupil-workspace'),
            padding: EdgeInsets.zero,
            children: [
              navigation(),
              const SizedBox(height: 8),
              CollapsibleSearch(
                fieldKey: const ValueKey('pupil-entry-search'),
                buttonKey: const ValueKey('pupil-search-button'),
                controller: search,
                label: 'Einträge durchsuchen',
                iconOnly: true,
                leading: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showPupilMaterials(context, c, p),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Dokumente'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                onChanged: (v) => setState(() => query = v),
                actions: [
                  if (!p.archived && area == FlexSymbol.orga)
                    IconButton(
                      tooltip: 'Termin anlegen',
                      onPressed: widget.newAppointment,
                      icon: const Icon(Icons.event_outlined),
                    ),
                  if (!p.archived) ...[
                    const SizedBox(width: 8),
                    if (area != null)
                      IconButton(
                        tooltip: '${fullLabel(area!)} anlegen',
                        onPressed: () => create(area!),
                        icon: const Icon(Icons.add),
                      )
                    else
                      PopupMenuButton<FlexSymbol>(
                        tooltip: 'Eintrag anlegen',
                        icon: const Icon(Icons.add),
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
              Wrap(
                key: const ValueKey('pupil-entry-filter'),
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final option in const {
                    'all': 'Alle',
                    'open': 'Noch offen',
                    'closed': 'Abgeschlossen',
                  }.entries)
                    transparentChip(
                      ChoiceChip(
                        key: ValueKey('pupil-filter-${option.key}'),
                        label: Text(option.value),
                        selected: filter == option.key,
                        onSelected: (_) => setState(() => filter = option.key),
                        backgroundColor: Colors.transparent,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                    ),
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
      ),
    );
  }
}
