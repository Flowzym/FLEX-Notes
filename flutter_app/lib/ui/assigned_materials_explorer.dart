part of 'material_library.dart';

enum _FileGroup {
  files('Alle Dateien'),
  folder('Ordner'),
  pupil('Schüler'),
  day('Unterrichtstag'),
  subject('Fach');

  const _FileGroup(this.label);
  final String label;
}

Future<void> showAssignedMaterials(
  BuildContext context,
  NotebookController c, {
  Pupil? pupil,
  String? day,
  Future<void> Function(ClassroomDocument)? openFile,
  MaterialFiles files = const LocalMaterialFiles(),
}) => showDialog<void>(
  context: context,
  builder: (ctx) => FlexModal(
    title: Text(
      pupil == null ? 'Zugewiesene Materialien' : 'Materialien · ${pupil.name}',
    ),
    maxWidth: 860,
    scrollable: false,
    onClose: () => Navigator.pop(ctx),
    content: SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .64,
      child: AssignedMaterialsExplorer(
        controller: c,
        pupil: pupil,
        day: day,
        openFile: openFile,
        files: files,
        onImport: () =>
            guarded(ctx, () => importMaterialFile(ctx, c, pupilId: pupil?.id)),
      ),
    ),
  ),
);

class AssignedMaterialsExplorer extends StatefulWidget {
  const AssignedMaterialsExplorer({
    super.key,
    required this.controller,
    this.pupil,
    this.day,
    this.openFile,
    this.onImport,
    this.files = const LocalMaterialFiles(),
    this.includeUnassigned = false,
  });
  final NotebookController controller;
  final Pupil? pupil;
  final String? day;
  final Future<void> Function(ClassroomDocument)? openFile;
  final VoidCallback? onImport;
  final MaterialFiles files;
  final bool includeUnassigned;
  @override
  State<AssignedMaterialsExplorer> createState() =>
      _AssignedMaterialsExplorerState();
}

class _AssignedMaterialsExplorerState extends State<AssignedMaterialsExplorer> {
  NotebookController get c => widget.controller;
  late var group = widget.day != null
      ? _FileGroup.day
      : widget.pupil != null
      ? _FileGroup.folder
      : _FileGroup.pupil;
  late final trail = <String>[if (widget.day != null) widget.day!];
  final search = TextEditingController();
  final marked = <String>{};
  bool selecting = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void browse(VoidCallback change) => setState(() {
    change();
    marked.clear();
    selecting = false;
  });

  Future<void> addFiles() async {
    final ids = await chooseMaterials(context, c, []);
    if (ids == null || ids.isEmpty || !mounted) return;
    await showMaterialAssignments(
      context,
      c,
      resolveMaterials(c.classroom, ids),
      pupil: widget.pupil,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final docs = c.classroom;
      final classDates = <String, Set<String>>{};
      for (final d in docs.where(
        (d) => !d.deleted && d.kind == ClassroomKind.preparation,
      )) {
        for (final id in d.strings('materialIds')) {
          (classDates[id] ??= {}).add(d.text('date'));
        }
      }
      Set<String> dates(ClassroomDocument m) => {
        ...?classDates[m.id],
        if (teachingDay(m).isNotEmpty) teachingDay(m),
        for (final row in m.rows('pupilDates'))
          if (widget.pupil == null || row['pupilId'] == widget.pupil!.id)
            row['date'] as String,
      };
      final people = {for (final p in c.pupils) p.id: p.name};
      String label(String key) => switch (group) {
        _FileGroup.pupil =>
          key.isEmpty
              ? 'Ohne Schülerzuordnung'
              : people[key] ?? 'Archivierter Schüler',
        _FileGroup.day =>
          key.isEmpty ? 'Ohne Unterrichtsdatum' : displayDate(key),
        _FileGroup.subject => key.isEmpty ? 'Ohne Fach' : key,
        _ => key,
      };
      final query = search.text.trim();
      final folders = <String, int>{}, matches = <ClassroomDocument>[];
      final folderPaths = <String, List<String>>{};
      final currentPath = group == _FileGroup.folder && trail.isNotEmpty
          ? trail.last.split('/')
          : const <String>[];
      var count = 0;
      for (final m in docs) {
        if (m.deleted || m.kind != ClassroomKind.material) continue;
        final ids = m.strings('pupilIds');
        if (widget.pupil != null && !ids.contains(widget.pupil!.id)) continue;
        final days = dates(m);
        if (!widget.includeUnassigned && ids.isEmpty && days.isEmpty) continue;
        if (query.isNotEmpty &&
            !materialMatches(m, query, pupils: c.pupils) &&
            !days.any(
              (d) => d.contains(query) || displayDate(d).contains(query),
            )) {
          continue;
        }
        if (group == _FileGroup.folder) {
          final parts = m
              .text('sourcePath')
              .replaceAll('\\', '/')
              .split('/')
              .where((p) => p.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) parts.removeLast();
          if (parts.length < currentPath.length ||
              !listEquals(
                parts.take(currentPath.length).toList(),
                currentPath,
              )) {
            continue;
          }
          count++;
          if (query.isEmpty && parts.length > currentPath.length) {
            final name = parts[currentPath.length];
            folders.update(name, (n) => n + 1, ifAbsent: () => 1);
            final shared = folderPaths.putIfAbsent(name, () => List.of(parts));
            while (shared.length > currentPath.length + 1 &&
                (parts.length < shared.length ||
                    !listEquals(shared, parts.take(shared.length).toList()))) {
              shared.removeLast();
            }
          } else {
            matches.add(m);
          }
        } else {
          final keys = switch (group) {
            _FileGroup.pupil => ids.toSet(),
            _FileGroup.day => days,
            _FileGroup.subject => {m.text('subject')},
            _ => <String>{},
          };
          if (keys.isEmpty) keys.add('');
          if (trail.isNotEmpty && !keys.contains(trail.first)) continue;
          count++;
          if (query.isEmpty && group != _FileGroup.files && trail.isEmpty) {
            for (final key in keys) {
              folders.update(key, (n) => n + 1, ifAbsent: () => 1);
            }
          } else {
            matches.add(m);
          }
        }
      }
      matches.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      final buckets = folders.keys.toList()
        ..sort(
          (a, b) => group == _FileGroup.day
              ? b.compareTo(a)
              : label(a).toLowerCase().compareTo(label(b).toLowerCase()),
        );
      final chosen = matches.where((m) => marked.contains(m.id)).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Dateien suchen',
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Suche löschen',
                            icon: const Icon(Icons.close),
                            onPressed: () => browse(search.clear),
                          ),
                  ),
                  onChanged: (_) => browse(() {}),
                ),
              ),
              if (widget.pupil != null)
                IconButton(
                  tooltip: 'Aus der Bibliothek zuordnen',
                  onPressed: () => guarded(context, addFiles),
                  icon: const Icon(Icons.playlist_add),
                ),
              if (widget.onImport != null)
                IconButton(
                  tooltip: 'Dateien importieren',
                  onPressed: widget.onImport,
                  icon: const Icon(Icons.file_upload_outlined),
                ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              PopupMenuButton<_FileGroup>(
                tooltip: 'Materialien gruppieren',
                initialValue: group,
                onSelected: (value) => browse(() {
                  group = value;
                  trail.clear();
                }),
                itemBuilder: (_) => [
                  for (final g in _FileGroup.values)
                    if (g != _FileGroup.pupil || widget.pupil == null)
                      CheckedPopupMenuItem(
                        value: g,
                        checked: g == group,
                        child: Text(g.label),
                      ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(group.label),
                      const Icon(Icons.expand_more, size: 16),
                    ],
                  ),
                ),
              ),
              if (trail.isNotEmpty)
                TextButton.icon(
                  onPressed: () => browse(() => trail.removeLast()),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(
                    group == _FileGroup.folder
                        ? trail.last.replaceAll('/', ' / ')
                        : trail.map(label).join(' / '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(
                selecting
                    ? '${chosen.length} ausgewählt'
                    : '$count ${count == 1 ? 'Datei' : 'Dateien'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (matches.isNotEmpty || selecting)
                IconButton(
                  tooltip: selecting
                      ? 'Auswahl beenden'
                      : 'Mehrere Dateien auswählen',
                  icon: Icon(selecting ? Icons.close : Icons.checklist),
                  onPressed: () => setState(() {
                    selecting = !selecting;
                    marked.clear();
                  }),
                ),
              if (selecting && matches.isNotEmpty)
                IconButton(
                  tooltip: 'Alle angezeigten auswählen',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() {
                    if (chosen.length == matches.length) {
                      marked.clear();
                    } else {
                      marked.addAll(matches.map((m) => m.id));
                    }
                  }),
                ),
              if (chosen.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Zuordnen'),
                  onPressed: () async {
                    final saved = await showMaterialAssignments(
                      context,
                      c,
                      chosen,
                    );
                    if (mounted && saved) browse(() {});
                  },
                ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: count == 0
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'Keine zugewiesenen Materialien in dieser Ansicht.'
                          : 'Keine passenden Dateien.',
                    ),
                  )
                : ListView.builder(
                    key: ValueKey((group, trail.join('/'), query)),
                    primary: false,
                    itemCount: buckets.length + matches.length,
                    itemBuilder: (ctx, i) {
                      if (i < buckets.length) {
                        final key = buckets[i], n = folders[key]!;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            group == _FileGroup.folder
                                ? folderPaths[key]!
                                      .skip(currentPath.length)
                                      .join(' / ')
                                : label(key),
                          ),
                          subtitle: Text('$n ${n == 1 ? 'Datei' : 'Dateien'}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => browse(
                            () => trail.add(
                              group == _FileGroup.folder
                                  ? folderPaths[key]!.join('/')
                                  : key,
                            ),
                          ),
                        );
                      }
                      final m = matches[i - buckets.length];
                      final ids = m.strings('pupilIds'),
                          ds = dates(m).toList()..sort();
                      void mark() => setState(() {
                        selecting = true;
                        if (!marked.remove(m.id)) marked.add(m.id);
                      });
                      final props = [
                        m.text('extension').toUpperCase(),
                        m.text('subject'),
                        if (widget.pupil == null)
                          ids
                              .map((id) => people[id] ?? 'Archivierter Schüler')
                              .join(', '),
                        if (ds.isNotEmpty) ds.map(displayDate).join(', '),
                      ].where((s) => s.isNotEmpty).join(' · ');
                      return ListTile(
                        key: ValueKey('assigned-file-${m.id}'),
                        dense: true,
                        selected: marked.contains(m.id),
                        leading: selecting
                            ? Checkbox(
                                value: marked.contains(m.id),
                                onChanged: (_) => mark(),
                              )
                            : MaterialThumbnail(
                                material: m,
                                files: widget.files,
                                width: 32,
                                height: 38,
                              ),
                        title: Text(
                          m.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          props,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onLongPress: mark,
                        onTap: selecting
                            ? mark
                            : () => guarded(
                                context,
                                () =>
                                    widget.openFile?.call(m) ??
                                    openMaterial(
                                      context,
                                      c,
                                      m,
                                      files: widget.files,
                                    ),
                              ),
                        trailing: selecting
                            ? null
                            : PopupMenuButton<String>(
                                tooltip: 'Dateiaktionen',
                                onSelected: (action) =>
                                    guarded(context, () async {
                                      if (action == 'assign') {
                                        await showMaterialAssignments(
                                          context,
                                          c,
                                          [m],
                                        );
                                      } else {
                                        await c.saveClassroom(
                                          m.patch({
                                            'favorite': !m.flag('favorite'),
                                          }),
                                        );
                                      }
                                    }),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'assign',
                                    child: Text('Zuordnung bearbeiten'),
                                  ),
                                  PopupMenuItem(
                                    value: 'favorite',
                                    child: Text(
                                      m.flag('favorite')
                                          ? 'Favorit entfernen'
                                          : 'Als Favorit merken',
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}
