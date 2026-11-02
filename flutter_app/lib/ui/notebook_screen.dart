import 'symbol_button.dart';
import 'pupil_history.dart';
import 'conflict_dialog.dart';
import 'maintenance_dialog.dart';
import 'pupil_editor.dart';
import 'dialog_workflows.dart';
import 'surfaces.dart';
import 'overview_entry.dart';
import 'prototype_navigation.dart';
import 'pupil_card.dart';
import 'backup_dialog.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'orga_editor.dart';
import 'settings.dart';
import 'appearance_settings.dart';
import '../domain/school.dart';
import 'flex_icons.dart';
import 'flex_modal.dart';
import 'school_workspace.dart';

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  NotebookController get c => widget.controller;
  int _primary = 0;
  final _pages = PageController();
  final _settingsLayout = SettingsLayoutState();
  SchoolKind? _schoolKind;
  String? _aux;
  VoidCallback? _refreshPupilDialog;
  final _pupilSearchFocus = FocusNode();
  bool _showPupilSearch = false;
  void _changeView(VoidCallback action) {
    if (!mounted) return;
    c.flushAppearance();
    setState(action);
    _refreshPupilDialog?.call();
  }

  String _pupilQuery = '', _entryQuery = '', _filter = 'all';
  bool _orgaOnly = false;
  final _expandedSections = <String>{};
  final _pupilSearch = TextEditingController();
  final _entrySearch = TextEditingController();
  @override
  void dispose() {
    _pages.dispose();
    _pupilSearch.dispose();
    _pupilSearchFocus.dispose();
    _entrySearch.dispose();
    super.dispose();
  }

  final _busyIds = <String>{};
  void _main(int index) {
    final fromAux = _aux != null;
    FocusManager.instance.primaryFocus?.unfocus();
    _changeView(() {
      _primary = index;
      _aux = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      if (fromAux) {
        _pages.jumpToPage(index);
      } else {
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _editor(OrgaEntry entry, {String? draftId}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrgaEditor(controller: c, entry: entry, draftId: draftId),
    );
    if (mounted) await guarded(context, c.reload);
  }

  Future<void> _mutate(OrgaEntry value) async {
    if (_busyIds.contains(value.id)) return;
    _changeView(() => _busyIds.add(value.id));
    await guarded(context, () => c.saveEntry(value));
    if (mounted) _changeView(() => _busyIds.remove(value.id));
  }

  Future<void> _pupilEditor([Pupil? pupil, DialogDraft? draft]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PupilEditor(controller: c, pupil: pupil, draft: draft),
    );
    await c.reload();
  }

  Future<void> _classOrga() async {
    var filter = 'all';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AnimatedBuilder(
          animation: c,
          builder: (ctx, _) {
            final values = c.entries
                .where(
                  (e) =>
                      e.pupilId == null &&
                      (filter == 'all' ||
                          e.isTask && (filter == 'done' ? e.done : !e.done)),
                )
                .toList();
            return FlexModal(
              maxWidth: 1000,
              title: const Text('Klassen-Orga'),
              onClose: () => Navigator.pop(ctx),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const {
                        'all': 'Alle',
                        'open': 'Offen',
                        'done': 'Erledigt',
                      }.entries)
                        transparentChip(
                          ChoiceChip(
                            label: Text(option.value),
                            selected: filter == option.key,
                            onSelected: (_) =>
                                update(() => filter = option.key),
                          ),
                        ),
                    ],
                  ),
                  if (values.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Keine Einträge.'),
                    ),
                  for (final e in values)
                    FlexCard(
                      child: InkWell(
                        onTap: () => _editor(e),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                e.isTask
                                    ? e.done
                                          ? 'Aufgabe erledigt'
                                          : 'Aufgabe offen'
                                    : 'Notiz',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                e.body.isEmpty ? e.title : e.body,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (e.dueDate != null)
                                Text('Termin: ${displayDate(e.dueDate)}'),
                              if (e.reminderState == ReminderState.planned)
                                Text('Erinnern am: ${displayReminder(e)}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => _editor(OrgaEntry.empty()),
                  child: const Text('Eintrag hinzufügen'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _auxDialog(String type) async {
    if (type == 'class') {
      await _classOrga();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) => FlexModal(
          title: Text(
            type == 'drafts'
                ? 'Gesicherte Entwürfe'
                : type == 'class'
                ? 'Klassen-Orga'
                : 'Papierkorb',
          ),
          maxWidth: type == 'class' ? 1000 : 760,
          actions: type == 'trash'
              ? [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: ctx,
                      builder: (_) =>
                          MaintenanceDialog(controller: c, emptyTrash: true),
                    ),
                    child: const Text('Papierkorb endgültig leeren'),
                  ),
                ]
              : const [],
          onClose: () => Navigator.pop(ctx),
          scrollable: false,
          content: SizedBox(
            height:
                type == 'drafts' && c.draftCount == 0 ||
                    type == 'trash' &&
                        c.trashedEntries.isEmpty &&
                        !c.records.any((r) => r.deleted)
                ? 140
                : MediaQuery.sizeOf(ctx).height * .7,
            child: type == 'drafts'
                ? _drafts()
                : type == 'trash'
                ? SchoolTools(controller: c, mode: 'trash')
                : _entries(
                    c.entries.where((e) => e.pupilId == null).toList(),
                    scope: 'class',
                    orga: true,
                    pupil: null,
                  ),
          ),
        ),
      ),
    );
  }

  PopupMenuButton<String> _more() => PopupMenuButton<String>(
    tooltip: 'Weitere Bereiche',
    child: const SizedBox(
      width: double.infinity,
      height: 42,
      child: Center(child: Text('…')),
    ),
    onSelected: (value) {
      if (value == 'conflicts') {
        showDialog<void>(
          context: context,
          builder: (_) => ConflictDialog(controller: c),
        );
      } else if (value == 'bulk') {
        showBulk(context, c);
      } else if (['drafts', 'class', 'trash'].contains(value)) {
        _auxDialog(value);
      } else {
        _changeView(() => _aux = value);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'conflicts',
        child: Text('Änderungskonflikte'),
      ),
      const PopupMenuItem(value: 'bulk', child: Text('Für mehrere erfassen')),
      const PopupMenuItem(value: 'class', child: Text('Klassen-Orga')),
      PopupMenuItem(value: 'drafts', child: Text('Entwürfe (${c.draftCount})')),
      const PopupMenuItem(value: 'archive', child: Text('Archiv')),
      const PopupMenuItem(value: 'trash', child: Text('Papierkorb')),
      const PopupMenuItem(value: 'groups', child: Text('Gruppenerfassungen')),
      const PopupMenuItem(value: 'settings', child: Text('Einstellungen')),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _aux == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _main(_primary);
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (c.appearanceError != null)
              MaterialBanner(
                content: Text(c.appearanceError!),
                actions: [
                  TextButton(
                    onPressed: () => _changeView(() => _aux = 'settings'),
                    child: const Text('Einstellungen'),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: FlexPagePills(
                selected: _aux == null ? _primary : 2,
                onSelected: _main,
                more: _more(),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _body() {
    if (_aux == 'settings') {
      return SettingsPage(controller: c, layout: _settingsLayout);
    }
    if (_aux == 'trash' || _aux == 'groups') {
      return SchoolTools(controller: c, mode: _aux!);
    }
    if (_aux == 'drafts') return _drafts();
    if (_aux == 'archive') return _pupils(archived: true);
    if (_aux == 'class') {
      return _entries(
        c.entries.where((e) => e.pupilId == null).toList(),
        scope: 'class',
        orga: true,
        pupil: null,
      );
    }
    return PageView(
      key: const ValueKey('main-pages'),
      controller: _pages,
      onPageChanged: (index) {
        FocusManager.instance.primaryFocus?.unfocus();
        _changeView(() => _primary = index);
      },
      children: [_overview(), _pupils()],
    );
  }

  Future<void> _openPupil(Pupil pupil, {FlexSymbol? symbol}) async {
    _schoolKind = switch (symbol) {
      FlexSymbol.goal => SchoolKind.goal,
      FlexSymbol.social => SchoolKind.social,
      FlexSymbol.work => SchoolKind.work,
      FlexSymbol.homework => SchoolKind.homework,
      _ => null,
    };
    _orgaOnly = symbol == FlexSymbol.orga;
    _entryQuery = '';
    _entrySearch.clear();
    _filter = 'all';
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (modalContext, refresh) {
            _refreshPupilDialog = () {
              if (modalContext.mounted) refresh(() {});
            };
            return AnimatedBuilder(
              animation: c,
              builder: (context, _) {
                final current =
                    c.pupils.where((p) => p.id == pupil.id).firstOrNull ??
                    pupil;
                return FlexModal(
                  accentColor: Color(current.color),
                  title: Row(
                    children: [
                      if (_schoolKind != null || _orgaOnly)
                        IconButton(
                          tooltip: 'Zur Schülerübersicht',
                          icon: const Icon(Icons.arrow_back, size: 20),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 40,
                          ),
                          padding: const EdgeInsets.only(right: 8),
                          onPressed: () => _changeView(() {
                            _schoolKind = null;
                            _orgaOnly = false;
                          }),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              current.name,
                              style: const TextStyle(
                                fontFamily: 'FlexSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -.3,
                              ),
                            ),
                            if (_schoolKind != null || _orgaOnly)
                              Text(
                                _schoolKind?.label ?? 'Orga',
                                style: const TextStyle(
                                  fontFamily: 'FlexSerif',
                                  fontSize: 24,
                                  height: 1.3,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Verlauf',
                        onPressed: () =>
                            showPupilHistory(context, c, current.id),
                        icon: const Icon(Icons.history),
                      ),
                    ],
                  ),
                  onClose: () => Navigator.pop(dialogContext),
                  scrollable: false,
                  content: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: _schoolKind != null
                        ? SchoolWorkspace(
                            controller: c,
                            pupil: current,
                            kind: _schoolKind!,
                          )
                        : _entries(
                            c.entries
                                .where((e) => e.pupilId == pupil.id)
                                .toList(),
                            scope: pupil.id,
                            orga: _orgaOnly,
                            pupil: current,
                          ),
                  ),
                );
              },
            );
          },
        ),
      );
    } finally {
      _refreshPupilDialog = null;
    }
  }

  Widget _overview() {
    final records = c.records.where((r) => !r.deleted).toList();
    final pendingRecords = records.where((r) => r.pending).toList();
    final pendingOrga = c.upcoming(c.entries);
    final pending = pendingRecords.length + pendingOrga.length;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final todo = _combinedSection(
      'Anstehend',
      pendingOrga,
      pendingRecords,
      'Gerade stehen keine Aufgaben, Hausübungen oder Ziele an.',
      upcoming: true,
    );
    final complete = _combinedSection(
      'Noch ergänzen',
      c.entries.where((e) => e.needsCompletion && !e.pending).toList(),
      records.where((r) => !r.pending && r.needsCompletion).toList(),
      'Alle Einträge sind ergänzt.',
    );
    final recent = _combinedSection(
      'Zuletzt dokumentiert',
      c.entries.where((e) => !e.pending && !e.needsCompletion).toList(),
      records.where((r) => !r.pending && !r.needsCompletion).toList(),
      'Noch keine weiteren Einträge.',
    );
    return ListView(
      key: const PageStorageKey('overview'),
      padding: EdgeInsets.fromLTRB(
        width <= 360 ? 12 : 24,
        20,
        width <= 360 ? 12 : 24,
        32,
      ),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Überblick',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: 'FlexSerif',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${displayDate(dateOnly(DateTime.now()))} · ${c.pupils.where((p) => !p.archived).length} Schüler · $pending anstehend',
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _editor(OrgaEntry.empty()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Klassen-Orga anlegen'),
            ),
          ],
        ),
        if (c.draftCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FlexCard(
              child: ListTile(
                key: const ValueKey('overview-drafts'),
                leading: const Icon(Icons.edit_note),
                title: Text(
                  '${c.draftCount} ${c.draftCount == 1 ? 'Entwurf' : 'Entwürfe'}',
                ),
                subtitle: const Text('Gesicherte Eingaben öffnen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _auxDialog('drafts'),
              ),
            ),
          ),
        if (width >= 1000)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: Column(children: [todo, complete])),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: recent),
            ],
          )
        else ...[
          todo,
          complete,
          recent,
        ],
      ],
    );
  }

  Future<void> _overviewDetails({SchoolRecord? record, OrgaEntry? entry}) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => AnimatedBuilder(
          animation: c,
          builder: (_, _) {
            final school = record == null
                ? null
                : c.records
                      .where((r) => r.id == record.id && !r.deleted)
                      .firstOrNull;
            final orga = entry == null
                ? null
                : c.entries.where((e) => e.id == entry.id).firstOrNull;
            return FlexModal(
              title: Text(school?.kind.label ?? 'Orga'),
              onClose: () => Navigator.pop(ctx),
              content: school != null
                  ? SchoolRecordCard(
                      key: ValueKey(school.id),
                      controller: c,
                      record: school,
                    )
                  : orga != null
                  ? _entryCard(orga)
                  : const Text('Dieser Eintrag wurde entfernt.'),
            );
          },
        ),
      );

  Widget _combinedSection(
    String title,
    List<OrgaEntry> orga,
    List<SchoolRecord> records,
    String empty, {
    bool upcoming = false,
  }) {
    final items = <OverviewEntry>[
      for (final e in orga)
        OverviewEntry(
          id: e.id,
          title: e.title,
          meta:
              '${c.owner(e)} · ${e.isTask ? 'Aufgabe' : 'Notiz'} · ${displayDate(e.observedOn)}',
          summary: e.body.trim() == e.title.trim() ? '' : e.body,
          status: [
            if (e.items.isNotEmpty)
              '${e.items.where((i) => i.checked).length} von ${e.items.length} Listenpunkten erledigt',
            if (e.isTask) e.done ? 'Erledigt' : 'Offen',
            if (e.dueDate != null) 'Fällig ${displayDate(e.dueDate)}',
            if (e.reminderState == ReminderState.planned)
              'Erinnerung ${displayReminder(e)}',
            if (e.needsCompletion) 'Noch ergänzen',
          ].join(' · '),
          order: upcoming
              ? ([
                      if (e.dueDate != null) e.dueDate!,
                      if (e.reminderState == ReminderState.planned)
                        e.reminderAtUtc!,
                    ].toList()..sort()).firstOrNull ??
                    '9999'
              : '${e.observedOn} ${e.observedTime}',
          symbol: FlexSymbol.orga,
          onOpen: () => _overviewDetails(entry: e),
          onEdit: () => _editor(e),
        ),
      for (final r in records)
        OverviewEntry(
          id: r.id,
          title: r.kind == SchoolKind.homework
              ? (r.subject.isEmpty ? 'Hausübung' : 'Hausübung · ${r.subject}')
              : r.title.isNotEmpty
              ? r.title
              : r.kind.label,
          meta:
              '${c.pupils.where((p) => p.id == r.pupilId).firstOrNull?.name ?? 'Schüler'} · ${displayDate(r.observedOn)}',
          summary: r.kind == SchoolKind.homework
              ? r.tasks.map((t) => t.text).join(' · ')
              : [
                  r.body,
                  ...r.positive.map((v) => '+ $v'),
                  ...r.negative.map((v) => '− $v'),
                ].where((v) => v.isNotEmpty).join(' · '),
          status: [
            if (r.kind == SchoolKind.homework)
              '${r.tasks.where((t) => r.taskState(t) == TaskState.complete).length} von ${r.tasks.length} Aufgaben vollständig',
            if (r.kind == SchoolKind.goal)
              r.goalStatus == 'active'
                  ? 'In Arbeit'
                  : r.goalStatus == 'achieved'
                  ? 'Ziel erreicht'
                  : 'Beendet',
            if (r.dueDate != null) 'Termin ${displayDate(r.dueDate)}',
            if (r.kind == SchoolKind.goal && r.nextReviewDate != null)
              'Überprüfen ${displayDate(r.nextReviewDate)}',
            if (r.needsCompletion) 'Noch ergänzen',
          ].join(' · '),
          order: upcoming
              ? (r.kind == SchoolKind.goal
                        ? r.nextReviewDate ?? r.dueDate
                        : r.dueDate) ??
                    '9999'
              : '${r.observedOn} ${r.observedTime}',
          symbol: FlexSymbol.values.byName(r.kind.name),
          onOpen: () => _overviewDetails(record: r),
          onEdit: () => editSchool(context, c, r),
        ),
    ]..sort((a, b) => upcoming ? a.order.compareTo(b.order) : b.order.compareTo(a.order));
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${items.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(empty),
            ),
          ...items,
        ],
      ),
    );
  }

  Widget _pupils({bool archived = false}) {
    final all = c.pupils.where((p) => p.archived == archived).toList();
    final pupils = all
        .where((p) => p.name.toLowerCase().contains(_pupilQuery.toLowerCase()))
        .toList();
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width <= 360
        ? 12.0
        : width <= 700
        ? 16.0
        : 40.0;
    return ListView(
      key: PageStorageKey('pupils-$archived'),
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${all.length} ${archived ? 'im Archiv' : 'Schüler'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              key: const ValueKey('toggle-pupil-search'),
              tooltip: _showPupilSearch ? 'Suche schließen' : 'Schüler suchen',
              icon: Icon(_showPupilSearch ? Icons.close : Icons.search),
              onPressed: () {
                _changeView(() {
                  _showPupilSearch = !_showPupilSearch;
                  if (!_showPupilSearch) {
                    _pupilQuery = '';
                    _pupilSearch.clear();
                  }
                });
                if (_showPupilSearch) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _pupilSearchFocus.requestFocus();
                  });
                }
              },
            ),
            if (!archived)
              IconButton(
                tooltip: 'Neuer Schüler',
                onPressed: () => _pupilEditor(),
                icon: const Icon(Icons.person_add),
              ),
            IconButton(
              tooltip: 'Datensicherung herunterladen',
              icon: const Icon(Icons.download),
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => BackupDialog(controller: c, export: true),
              ),
            ),
          ],
        ),
        if (_showPupilSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _pupilSearch,
              focusNode: _pupilSearchFocus,
              key: ValueKey('search-$archived'),
              decoration: InputDecoration(
                labelText: 'Schüler suchen',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Suchtext leeren',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _changeView(() {
                      _pupilQuery = '';
                      _pupilSearch.clear();
                    });
                    _pupilSearchFocus.requestFocus();
                  },
                ),
              ),
              onChanged: (value) => _changeView(() => _pupilQuery = value),
            ),
          ),
        const SizedBox(height: 10),
        if (pupils.isEmpty)
          EmptyState(
            archived
                ? 'Keine passenden archivierten Schüler.'
                : 'Noch keine passenden Schüler.',
            icon: Icons.people,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = ((constraints.maxWidth + 20) / 310).floor().clamp(
              1,
              4,
            );
            final cardWidth =
                ((constraints.maxWidth - (columns - 1) * 20) / columns).clamp(
                  0.0,
                  420.0,
                );
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final pupil in pupils)
                  SizedBox(
                    width: cardWidth,
                    child: PupilCard(
                      key: ValueKey('pupil-card-${pupil.id}'),
                      pupil: pupil,
                      onOpen: () => _openPupil(pupil),
                      onShortcut: (symbol) => _entryShortcut(pupil, symbol),
                      counts: _shortcutCounts(pupil),
                      draftCounts: {
                        for (final symbol in FlexSymbol.values)
                          symbol: _pupilDraftCount(pupil.id, symbol),
                      },
                      due: _dueShortcuts(pupil),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _entryShortcut(Pupil pupil, FlexSymbol symbol) async {
    if (pupil.archived) {
      await _openPupil(pupil, symbol: symbol);
      return;
    }
    if (symbol == FlexSymbol.orga) {
      await _editor(OrgaEntry.empty(pupilId: pupil.id));
      return;
    }
    final kind = switch (symbol) {
      FlexSymbol.goal => SchoolKind.goal,
      FlexSymbol.social => SchoolKind.social,
      FlexSymbol.work => SchoolKind.work,
      _ => SchoolKind.homework,
    };
    await editSchool(context, c, SchoolRecord.empty(kind, pupil.id));
  }

  int _pupilDraftCount(String pupilId, FlexSymbol symbol) =>
      c.schoolDrafts
          .where(
            (d) =>
                d.record.kind.name == symbol.name &&
                (d.record.pupilId == pupilId || d.recipients.contains(pupilId)),
          )
          .length +
      (symbol == FlexSymbol.orga
          ? c.drafts.where((d) => d.entry.pupilId == pupilId).length
          : 0) +
      c.dialogDrafts
          .where(
            (d) =>
                d.type == 'bulk' &&
                d.data['kind'] == symbol.name &&
                (d.data['recipients'] as List).contains(pupilId),
          )
          .length;

  Map<FlexSymbol, int> _shortcutCounts(Pupil pupil) {
    final records = c.records.where((r) => r.pupilId == pupil.id && !r.deleted);
    return {
      FlexSymbol.goal: records
          .where((r) => r.kind == SchoolKind.goal && r.pending)
          .length,
      FlexSymbol.social: records
          .where((r) => r.kind == SchoolKind.social && r.needsCompletion)
          .length,
      FlexSymbol.work: records
          .where((r) => r.kind == SchoolKind.work && r.needsCompletion)
          .length,
      FlexSymbol.homework: records
          .where((r) => r.kind == SchoolKind.homework && r.pending)
          .length,
      FlexSymbol.orga: c.entries
          .where((e) => e.pupilId == pupil.id && e.isTask && !e.done)
          .length,
    };
  }

  Set<FlexSymbol> _dueShortcuts(Pupil pupil) {
    final today = dateOnly(DateTime.now());
    return {
      if (c.records.any(
        (r) =>
            r.pupilId == pupil.id &&
            !r.deleted &&
            r.kind == SchoolKind.homework &&
            r.pending &&
            r.dueDate != null &&
            r.dueDate!.compareTo(today) <= 0,
      ))
        FlexSymbol.homework,
      if (c.entries.any(
        (e) =>
            e.pupilId == pupil.id &&
            e.isTask &&
            !e.done &&
            e.dueDate != null &&
            e.dueDate!.compareTo(today) <= 0,
      ))
        FlexSymbol.orga,
    };
  }

  Widget _entries(
    List<OrgaEntry> entries, {
    required String scope,
    required bool orga,
    required Pupil? pupil,
  }) {
    final visible = entries
        .where(
          (e) =>
              '${e.title} ${e.body} ${e.items.map((i) => i.text).join(' ')}'
                  .toLowerCase()
                  .contains(_entryQuery.toLowerCase()) &&
              (_filter == 'all' || (e.isTask && e.done == (_filter == 'done'))),
        )
        .toList();
    return ListView(
      key: PageStorageKey('entries-$scope-$orga'),
      padding: EdgeInsets.all(pupil == null ? 24 : 0),
      children: [
        if (pupil == null)
          Text('Klassen-Orga', style: Theme.of(context).textTheme.titleLarge),
        if (pupil != null && !orga) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in [
                'Aktuell',
                'Ziele',
                'Sozialverhalten',
                'Arbeitsverhalten',
                'Hausübung',
                'Orga',
              ])
                transparentChip(
                  ChoiceChip(
                    avatar: category == 'Aktuell'
                        ? null
                        : FlexIcon(
                            category == 'Orga'
                                ? FlexSymbol.orga
                                : FlexIcon.forKind(
                                    SchoolKind.values.firstWhere(
                                      (kind) => kind.label == category,
                                    ),
                                  ),
                            size: 20,
                          ),
                    label: Text(category),
                    selected: category == (orga ? 'Orga' : 'Aktuell'),
                    onSelected: (_) {
                      if (category == 'Orga' || category == 'Aktuell') {
                        _changeView(() => _orgaOnly = category == 'Orga');
                        return;
                      }
                      _changeView(
                        () => _schoolKind = SchoolKind.values.firstWhere(
                          (kind) => kind.label == category,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _pupilEditor(pupil),
                icon: const Icon(Icons.edit),
                label: const Text('Schüler bearbeiten'),
              ),
              TextButton.icon(
                onPressed: () => guarded(
                  context,
                  () => c.savePupil(pupil.copyWith(archived: !pupil.archived)),
                ),
                icon: Icon(pupil.archived ? Icons.unarchive : Icons.archive),
                label: Text(
                  pupil.archived ? 'Aus Archiv holen' : 'Archivieren',
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => showBrief(context, c, pupil),
            icon: const Icon(Icons.description),
            label: const Text('Gesprächsvorbereitung'),
          ),
          if (pupil.archived)
            const Text('Archiv · offene Verpflichtungen bleiben sichtbar.'),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _editor(OrgaEntry.empty(pupilId: pupil?.id)),
            icon: const Icon(Icons.add),
            label: const Text('Orga anlegen'),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _entrySearch,
          key: ValueKey('entry-query-$scope'),
          decoration: const InputDecoration(
            labelText: 'Einträge durchsuchen',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => _changeView(() => _entryQuery = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final f in {
              'all': 'Alle',
              'open': 'Offene Aufgaben',
              'done': 'Erledigte Aufgaben',
            }.entries)
              transparentChip(
                FilterChip(
                  label: Text(f.value),
                  selected: _filter == f.key,
                  onSelected: (_) => _changeView(() => _filter = f.key),
                ),
              ),
          ],
        ),
        if (pupil != null && !orga)
          for (final r in c.records.where(
            (r) =>
                r.pupilId == pupil.id &&
                !r.deleted &&
                r.searchText.toLowerCase().contains(_entryQuery.toLowerCase()),
          ))
            SchoolRecordCard(controller: c, record: r),
        if (orga || _entryQuery.isNotEmpty || _filter != 'all')
          _section(
            '$scope-list',
            'Orga',
            visible,
            empty: 'Keine passenden Orga-Einträge.',
          )
        else ...[
          _section(
            '$scope-pending',
            'Anstehend',
            c.upcoming(visible),
            empty: 'Keine offenen Aufgaben oder Erinnerungen.',
          ),
          _section(
            '$scope-docs',
            'Noch ergänzen',
            visible.where((e) => e.needsCompletion && !e.pending).toList(),
            empty: 'Keine Dokumentation nachzutragen.',
          ),
          _section(
            '$scope-recent',
            'Zuletzt',
            visible.where((e) => !e.pending && !e.needsCompletion).toList(),
            empty: 'Noch keine abgeschlossenen Vorgänge oder Notizen.',
          ),
        ],
      ],
    );
  }

  Widget _section(
    String key,
    String title,
    List<OrgaEntry> entries, {
    required String empty,
  }) {
    final expanded = _expandedSections.contains(key);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title · ${entries.length}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(empty),
            ),
          ...entries.take(expanded ? entries.length : 4).map(_entryCard),
          if (entries.length > 4)
            TextButton(
              onPressed: () => _changeView(() {
                if (expanded) {
                  _expandedSections.remove(key);
                } else {
                  _expandedSections.add(key);
                }
              }),
              child: Text(
                expanded
                    ? 'Weniger anzeigen'
                    : '${entries.length - 4} weitere anzeigen',
              ),
            ),
        ],
      ),
    );
  }

  Widget _entryCard(OrgaEntry e) {
    final busy = _busyIds.contains(e.id);
    return FlexCard(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  e.isTask
                      ? (e.done
                            ? Icons.task_alt
                            : Icons.check_box_outline_blank)
                      : Icons.notes,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${c.owner(e)} · ${e.isTask ? (e.done ? 'Aufgabe erledigt' : 'Aufgabe offen') : 'Notiz'}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Bearbeiten',
                  onPressed: () => _editor(e),
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            if (e.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  e.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            for (final item in e.items.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.checked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.text)),
                  ],
                ),
              ),
            if (e.items.isNotEmpty)
              Text(
                '${e.items.where((i) => i.checked).length} / ${e.items.length} Listenpunkte',
              ),
            if (e.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Aufgabentermin: ${displayDate(e.dueDate)}${!e.done && e.dueDate!.compareTo(dateOnly(DateTime.now())) < 0 ? ' · überfällig' : ''}',
                ),
              ),
            if (e.reminderAtUtc != null)
              Text(
                'Erinnerung: ${displayReminder(e)} · ${switch (e.reminderState) {
                  ReminderState.planned => 'aktiv',
                  ReminderState.acknowledged => 'quittiert',
                  ReminderState.cancelled => 'beendet',
                  ReminderState.none => '',
                }}',
              ),
            if (e.needsCompletion)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Dokumentation noch ergänzen'),
              ),
            Wrap(
              spacing: 8,
              children: [
                if (e.isTask)
                  FlexSymbolButton(
                    onPressed: busy
                        ? null
                        : () => _mutate(e.done ? e.reopen() : e.complete()),
                    icon: e.done ? Icons.undo : Icons.check_circle_outline,
                    label: e.done ? 'Wieder öffnen' : 'Erledigen',
                  ),
                if (e.reminderState == ReminderState.planned)
                  TextButton(
                    onPressed: busy ? null : () => _mutate(e.acknowledge()),
                    child: const Text('Erinnerung quittieren'),
                  ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirmFlex(
                            context,
                            'Orga in den Papierkorb?',
                            'Geplante Erinnerungen werden beendet. Der Eintrag bleibt wiederherstellbar.',
                            accept: 'In den Papierkorb',
                          )) {
                            await _mutate(
                              e.copyWith(
                                deleted: true,
                                reminderState:
                                    e.reminderState == ReminderState.planned
                                    ? ReminderState.cancelled
                                    : e.reminderState,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.delete),
                  label: const Text('Papierkorb'),
                ),
                TextButton(
                  onPressed: () => _history(e),
                  child: const Text('Änderungen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _history(OrgaEntry entry) => showJournal(context, c, entry.id);

  Widget _drafts({String? pupilId, FlexSymbol? symbol}) {
    String pupilName(String? id) => id == null
        ? 'Klasse'
        : c.pupils.where((p) => p.id == id).firstOrNull?.name ??
              'Unbekannte Zuordnung';
    final rows =
        <
            ({
              String title,
              String preview,
              String time,
              VoidCallback open,
              Future<void> Function() discard,
            })
          >[
            for (final d in c.dialogDrafts.where(
              (d) =>
                  pupilId == null ||
                  d.type == 'bulk' &&
                      d.data['kind'] == symbol?.name &&
                      (d.data['recipients'] as List).contains(pupilId),
            ))
              (
                title: d.type == 'pupil'
                    ? 'Schüler · ${d.data['name']}'
                    : d.type == 'context'
                    ? 'Gemeinsame Situation'
                    : d.type == 'catalog'
                    ? '${d.ownerId == 'social' ? 'Sozialverhalten' : 'Arbeitsverhalten'} · Auswahl'
                    : 'Gemeinsam · ${const {'social': 'Sozialverhalten', 'work': 'Arbeitsverhalten', 'homework': 'Hausübung', 'orga': 'Orga'}[d.data['kind']]} · ${(d.data['recipients'] as List? ?? []).map((id) => pupilName(id as String)).join(', ')}',
                preview:
                    '${d.data['text'] ?? d.data['context'] ?? d.data['body'] ?? ''}',
                time: d.updatedAtUtc,
                open: () {
                  if (d.type == 'pupil') {
                    _pupilEditor(null, d);
                  } else if (d.type == 'catalog') {
                    showCatalog(context, c, d.ownerId, draft: d);
                  } else if (d.type == 'context') {
                    showSituation(context, c, d.ownerId, draft: d);
                  } else {
                    showBulk(context, c, draft: d);
                  }
                },
                discard: () =>
                    c.repository.discardDialogDraft(d.id, d.revision),
              ),
            for (final d in c.schoolDrafts.where(
              (d) =>
                  pupilId == null ||
                  d.record.kind.name == symbol?.name &&
                      (d.record.pupilId == pupilId ||
                          d.recipients.contains(pupilId)),
            ))
              (
                title:
                    '${pupilName(d.record.pupilId)} · ${d.record.kind.label}${d.mode == 'comment'
                        ? ' · Kommentar'
                        : d.mode == 'review'
                        ? ' · Überprüfung'
                        : ''}',
                preview: d.mode == 'comment'
                    ? d.record.feedback
                              .where((f) => f.id == d.feedbackId)
                              .firstOrNull
                              ?.note ??
                          ''
                    : d.mode == 'review'
                    ? d.record.reviews
                              .where((r) => r.id == d.feedbackId)
                              .firstOrNull
                              ?.note ??
                          d.record.title
                    : [
                        d.record.title,
                        d.record.subject,
                        d.record.body,
                        ...d.record.positive,
                        ...d.record.negative,
                      ].where((v) => v.isNotEmpty).join(' · '),
                time: d.updatedAtUtc,
                open: () => editSchool(context, c, d.record, draft: d),
                discard: () => c.repository.discardSchoolDraft(
                  d.id,
                  expectedRevision: d.editRevision,
                ),
              ),
            for (final d in c.drafts.where(
              (d) =>
                  pupilId == null ||
                  symbol == FlexSymbol.orga && d.entry.pupilId == pupilId,
            ))
              (
                title: '${pupilName(d.entry.pupilId)} · Orga',
                preview: d.entry.body.isEmpty ? d.entry.title : d.entry.body,
                time: d.updatedAtUtc,
                open: () => _editor(d.entry, draftId: d.id),
                discard: () => c.repository.discardDraft(
                  d.id,
                  expectedRevision: d.editRevision,
                ),
              ),
          ]
          ..sort((a, b) => b.time.compareTo(a.time));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rows.isEmpty) const EmptyState('Keine gesicherten Entwürfe.'),
        for (final row in rows)
          FlexCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    row.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (row.preview.isNotEmpty)
                    Text(
                      row.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    displayDate(row.time),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: row.open,
                        child: const Text('Fortsetzen'),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (await confirmFlex(
                                context,
                                'Entwurf verwerfen?',
                                'Der gespeicherte Eintrag bleibt erhalten.',
                                accept: 'Verwerfen',
                              ) &&
                              mounted) {
                            await guarded(context, () async {
                              await row.discard();
                              await c.reload();
                            });
                          }
                        },
                        child: const Text('Verwerfen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (rows.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Entwürfe sind noch keine veröffentlichten Einträge. Sie bleiben nach einem Neustart verfügbar.',
            ),
          ),
      ],
    );
  }
}
