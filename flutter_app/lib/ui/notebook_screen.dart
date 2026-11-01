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
  String? _aux, _selectedPupil;
  String _pupilQuery = '', _entryQuery = '', _filter = 'all';
  bool _orgaOnly = false;
  final _expandedSections = <String>{};
  final _pupilSearch = TextEditingController();
  final _entrySearch = TextEditingController();
  @override
  void dispose() {
    _pupilSearch.dispose();
    _entrySearch.dispose();
    super.dispose();
  }

  final _busyIds = <String>{};
  void _main(int index) => setState(() {
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
    setState(() => _busyIds.add(value.id));
    await guarded(context, () => c.saveEntry(value));
    if (mounted) setState(() => _busyIds.remove(value.id));
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
    icon: const Icon(Icons.more_horiz),
    onSelected: (value) => setState(() => _aux = value),
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
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final selected = c.pupils.where((p) => p.id == _selectedPupil).firstOrNull;
    final title = switch (_aux) {
      'class' => 'Klassen-Orga',
      'drafts' => 'Entwürfe',
      'archive' => 'Archiv',
      'settings' => 'Einstellungen',
      'trash' => 'Papierkorb',
      'groups' => 'Gruppenerfassungen',
      _ => _primary == 0 ? 'Übersicht' : selected?.name ?? 'Schüler',
    };
    return PopScope(
      canPop: _aux == null && !(_primary == 1 && selected != null),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            if (_aux != null) {
              _aux = null;
            } else {
              _selectedPupil = null;
              _orgaOnly = false;
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _aux != null || (_primary == 1 && selected != null)
              ? IconButton(
                  tooltip: 'Zurück',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    if (_aux != null) {
                      _aux = null;
                    } else {
                      _selectedPupil = null;
                      _orgaOnly = false;
                      _entryQuery = '';
                      _entrySearch.clear();
                      _filter = 'all';
                    }
                  }),
                )
              : null,
          title: Text(title),
          actions: [
            IconButton(
              tooltip: 'Daten erneut laden',
              onPressed: () => guarded(context, c.reload),
              icon: const Icon(Icons.refresh),
            ),
            _more(),
            const SizedBox(width: 12),
          ],
        ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                extended: true,
                minExtendedWidth: 190,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'FLEX\nNotizbuch',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                selectedIndex: _primary,
                onDestinationSelected: _main,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Übersicht'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people),
                    selectedIcon: Icon(Icons.people),
                    label: Text('Schüler'),
                  ),
                ],
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: _body(selected),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _primary,
                onDestinationSelected: _main,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard),
                    label: 'Übersicht',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people),
                    label: 'Schüler',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _body(Pupil? selected) {
    if (_aux == 'settings') return SettingsPage(controller: c);
    if (_aux == 'trash' || _aux == 'groups') {
      return SchoolTools(controller: c, mode: _aux!);
    }
    if (_aux == null &&
        _primary == 1 &&
        selected != null &&
        _schoolKind != null) {
      return SchoolWorkspace(
        controller: c,
        pupil: selected,
        kind: _schoolKind!,
        onKind: (kind) => setState(() => _schoolKind = kind),
      );
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
    if (_primary == 0) return _overview();
    if (selected != null) {
      return _entries(
        c.entries.where((e) => e.pupilId == selected.id).toList(),
        scope: selected.id,
        orga: _orgaOnly,
        pupil: selected,
      );
    }
    return _pupils();
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text('$drafts gesicherte Entwürfe'),
              subtitle: const Text('Bearbeitung wieder aufnehmen'),
              onTap: () => setState(() => _aux = 'drafts'),
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
    final pupils = c.pupils
        .where(
          (p) =>
              p.archived == archived &&
              p.name.toLowerCase().contains(_pupilQuery.toLowerCase()),
        )
        .toList();
    return ListView(
      key: PageStorageKey('pupils-$archived'),
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pupilSearch,
                key: ValueKey('search-$archived'),
                decoration: const InputDecoration(
                  labelText: 'Schüler suchen',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _pupilQuery = value),
              ),
            ),
            const SizedBox(width: 12),
            if (!archived)
              FilledButton.icon(
                onPressed: () => _pupilEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Anlegen'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (pupils.isEmpty)
          EmptyState(
            archived
                ? 'Keine archivierten Schüler.'
                : 'Noch keine passenden Schüler. Neue Arbeitsbereiche starten leer.',
            icon: Icons.people,
          ),
        for (final pupil in pupils)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(pupil.color),
                foregroundColor: const Color(0xff23311e),
                child: Text(pupil.name.characters.first.toUpperCase()),
              ),
              title: Text(pupil.name),
              subtitle: Text(
                '${c.entries.where((e) => e.pupilId == pupil.id && e.pending).length + c.records.where((r) => r.pupilId == pupil.id && r.pending).length} anstehend${pupil.archived ? ' · Archiv' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _selectedPupil = pupil.id;
                _primary = 1;
                _aux = null;
                _orgaOnly = false;
                _schoolKind = null;
                _entryQuery = '';
                _entrySearch.clear();
                _filter = 'all';
              }),
            ),
          ),
      ],
    );
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
      padding: const EdgeInsets.all(24),
      children: [
        if (pupil != null) ...[
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
                      setState(() => _orgaOnly = category == 'Orga');
                      return;
                    }
                    setState(
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
          onChanged: (value) => setState(() => _entryQuery = value),
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
                onSelected: (_) => setState(() => _filter = f.key),
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
              onPressed: () => setState(() {
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
    return Card(
      child: Padding(
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
        Card(
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
        Card(
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
