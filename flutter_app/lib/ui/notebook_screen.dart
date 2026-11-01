import 'surfaces.dart';
import 'prototype_navigation.dart';
import 'pupil_card.dart';
import 'backup_dialog.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'orga_editor.dart';
import 'settings.dart';
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
  SchoolKind? _schoolKind;
  String? _aux;
  VoidCallback? _refreshPupilDialog;
  final _pupilSearchFocus = FocusNode();
  bool _showPupilSearch = false;
  void _changeView(VoidCallback action) {
    if (!mounted) return;
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
    _pupilSearch.dispose();
    _pupilSearchFocus.dispose();
    _entrySearch.dispose();
    super.dispose();
  }

  final _busyIds = <String>{};
  void _main(int index) => _changeView(() {
    _primary = index;
    _aux = null;
  });
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

  Future<void> _pupilEditor([Pupil? pupil]) async {
    final text = TextEditingController(text: pupil?.name ?? '');
    var color = pupil?.color ?? 0xffa8bb80;
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => FlexModal(
          title: Text(pupil == null ? 'Schüler anlegen' : 'Schüler bearbeiten'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  autofocus: true,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [0xffa8bb80, 0xff9dc9d3, 0xffd9b397, 0xffc1a7d8]
                      .map(
                        (v) => ChoiceChip(
                          label: const Text('●'),
                          avatar: Icon(Icons.circle, color: Color(v)),
                          selected: color == v,
                          onSelected: busy
                              ? null
                              : (_) => update(() => color = v),
                        ),
                      )
                      .toList(),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() => busy = true);
                      try {
                        await c.savePupil(
                          (pupil ?? Pupil(id: newId(), name: '')).copyWith(
                            name: text.text,
                            color: color,
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        update(() {
                          error = friendlyError(e);
                          busy = false;
                        });
                      }
                    },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    // The route may still animate out; its controller can be disposed afterwards.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    text.dispose();
  }

  PopupMenuButton<String> _more() => PopupMenuButton<String>(
    tooltip: 'Weitere Bereiche',
    child: const SizedBox(
      width: double.infinity,
      height: 42,
      child: Center(child: Text('…')),
    ),
    onSelected: (value) => _changeView(() => _aux = value),
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'class', child: Text('Klassen-Orga')),
      PopupMenuItem(
        value: 'drafts',
        child: Text('Entwürfe (${(c.drafts.length + c.schoolDrafts.length)})'),
      ),
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
      if (!didPop) _changeView(() => _aux = null);
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
    if (_aux == 'settings') return SettingsPage(controller: c);
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
    return _primary == 0 ? _overview() : _pupils();
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
                                fontFamily: 'FlexSerif',
                                fontSize: 23,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -.3,
                              ),
                            ),
                            if (_schoolKind != null || _orgaOnly)
                              Text(
                                _schoolKind?.label ?? 'Orga',
                                style: const TextStyle(
                                  fontSize: 18,
                                  height: 1.3,
                                ),
                              ),
                          ],
                        ),
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
    final pendingRecords = c.records.where((r) => r.pending).toList();
    final pendingOrga = c.upcoming(c.entries);
    final drafts = c.drafts.length + c.schoolDrafts.length;
    return ListView(
      key: const PageStorageKey('overview'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Dein Unterricht. Gut im Blick.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Ziele, Hausübungen, Aufgaben und Beobachtungen an einem Ort.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Chip(
              label: Text(
                '${c.pupils.where((p) => !p.archived).length} Schüler',
              ),
            ),
            Chip(
              label: Text(
                '${pendingOrga.length + pendingRecords.length} anstehend',
              ),
            ),
            Chip(label: Text('$drafts Entwürfe')),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _editor(OrgaEntry.empty()),
            icon: const Icon(Icons.add),
            label: const Text('Klassen-Orga anlegen'),
          ),
        ),
        if (drafts > 0)
          FlexCard(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text('$drafts gesicherte Entwürfe'),
              subtitle: const Text('Bearbeitung wieder aufnehmen'),
              onTap: () => _changeView(() => _aux = 'drafts'),
            ),
          ),
        _combinedSection(
          'Anstehend',
          pendingOrga,
          pendingRecords,
          'Keine offenen Ziele, Hausübungen, Aufgaben oder Erinnerungen.',
        ),
        _combinedSection(
          'Noch ergänzen',
          c.entries.where((e) => e.needsCompletion && !e.pending).toList(),
          c.records
              .where((r) => !r.deleted && !r.pending && r.needsCompletion)
              .toList(),
          'Keine Dokumentation nachzutragen.',
        ),
        _combinedSection(
          'Zuletzt',
          c.entries.where((e) => !e.pending && !e.needsCompletion).toList(),
          c.records
              .where((r) => !r.deleted && !r.pending && !r.needsCompletion)
              .toList(),
          'Noch keine weiteren Einträge.',
        ),
      ],
    );
  }

  Widget _combinedSection(
    String title,
    List<OrgaEntry> orga,
    List<SchoolRecord> records,
    String empty,
  ) {
    final sorted = [...records]
      ..sort(
        (a, b) => '${b.observedOn} ${b.observedTime}'.compareTo(
          '${a.observedOn} ${a.observedTime}',
        ),
      );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title · ${orga.length + records.length}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (orga.isEmpty && records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(empty),
            ),
          ...orga.map(_entryCard),
          for (final r in sorted)
            SchoolRecordCard(key: ValueKey(r.id), controller: c, record: r),
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
                      onShortcut: (symbol) => _openPupil(pupil, symbol: symbol),
                      counts: _shortcutCounts(pupil),
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
              FilterChip(
                label: Text(f.value),
                selected: _filter == f.key,
                onSelected: (_) => _changeView(() => _filter = f.key),
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
                'Erinnerung: ${displayDate(e.reminderAtUtc)} · ${switch (e.reminderState) {
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
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => _mutate(e.done ? e.reopen() : e.complete()),
                    icon: Icon(e.done ? Icons.undo : Icons.check),
                    label: Text(e.done ? 'Wieder öffnen' : 'Erledigen'),
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

  Future<void> _history(OrgaEntry entry) async {
    await guarded(context, () async {
      final rows = await c.repository.history(entry.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => FlexModal(
          title: const Text('Nachvollziehbare Änderungen'),
          content: SizedBox(
            width: 650,
            child: ListView(
              shrinkWrap: true,
              children: rows
                  .map(
                    (r) => ExpansionTile(
                      title: Text(
                        'Fassung ${r['revision']} · ${displayDate(r['captured_at_utc'] as String)}',
                      ),
                      children: [
                        SelectableText(
                          const JsonEncoder.withIndent('  ').convert({
                            'vorher': r['before_payload'] == null
                                ? null
                                : jsonDecode(r['before_payload'] as String),
                            'nachher': jsonDecode(r['after_payload'] as String),
                          }),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
    });
  }

  Widget _drafts() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      for (final d in c.schoolDrafts)
        FlexCard(
          child: ListTile(
            leading: FlexIcon(FlexIcon.forKind(d.record.kind)),
            title: Text(
              '${d.record.kind.label} · ${d.record.title.isEmpty ? d.record.subject : d.record.title}',
            ),
            subtitle: Text(
              d.mode == 'comment'
                  ? 'Kommentar fortsetzen'
                  : d.mode == 'review'
                  ? 'Zielüberprüfung fortsetzen'
                  : 'Entwurf fortsetzen',
            ),
            onTap: () => editSchool(context, c, d.record, draft: d),
            trailing: IconButton(
              tooltip: 'Entwurf verwerfen',
              icon: const Icon(Icons.delete),
              onPressed: () async {
                if (await confirmFlex(
                      context,
                      'Entwurf verwerfen?',
                      'Der gespeicherte Eintrag bleibt erhalten.',
                      accept: 'Verwerfen',
                    ) &&
                    mounted) {
                  await guarded(context, () async {
                    await c.repository.discardSchoolDraft(d.id);
                    await c.reload();
                  });
                }
              },
            ),
          ),
        ),
      const Text(
        'Entwürfe sind noch keine veröffentlichten Einträge. Sie bleiben nach einem Neustart verfügbar.',
      ),
      if (c.drafts.isEmpty && c.schoolDrafts.isEmpty)
        const EmptyState('Keine gesicherten Entwürfe.'),
      for (final d in c.drafts)
        FlexCard(
          child: ListTile(
            title: Text(d.entry.title.isEmpty ? 'Ohne Titel' : d.entry.title),
            subtitle: Text(
              '${c.owner(d.entry)} · ${displayDate(d.updatedAtUtc)}',
            ),
            onTap: () => _editor(d.entry, draftId: d.id),
            trailing: IconButton(
              tooltip: 'Entwurf verwerfen',
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => FlexModal(
                    title: const Text('Entwurf verwerfen?'),
                    content: const Text(
                      'Der gespeicherte Eintrag bleibt erhalten. Nur diese ungespeicherten Änderungen werden verworfen.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Behalten'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Verwerfen'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await guarded(context, () async {
                    await c.repository.discardDraft(d.id);
                    await c.reload();
                  });
                }
              },
            ),
          ),
        ),
    ],
  );
}
