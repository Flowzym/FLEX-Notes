part of 'material_library.dart';

String _fileCount(int count) => '$count ${count == 1 ? 'Datei' : 'Dateien'}';

String _formatGroup(ClassroomDocument d) =>
    switch (d.text('extension').toLowerCase()) {
      'jpg' || 'jpeg' || 'png' => 'jpg',
      final extension => extension,
    };

String _formatName(String group) => switch (group) {
  'jpg' => 'Fotos',
  'link' => 'Links',
  _ => group.toUpperCase(),
};

class _LibraryFilter {
  String format = '', type = '', subject = '', use = '', pupil = '';
  bool favorites = false;
  final tags = <String>{};

  _LibraryFilter();
  _LibraryFilter.copy(_LibraryFilter other)
    : format = other.format,
      type = other.type,
      subject = other.subject,
      use = other.use,
      pupil = other.pupil,
      favorites = other.favorites {
    tags.addAll(other.tags);
  }

  List<String> get labels => [
    if (favorites) 'Favoriten',
    if (format.isNotEmpty) _formatName(format),
    if (type.isNotEmpty) materialTypes[type] ?? type,
    if (subject.isNotEmpty) subject,
    if (use.isNotEmpty) planningUses[use] ?? use,
    for (final tag in tags) '#$tag',
  ];
  int get count => labels.length + (pupil.isEmpty ? 0 : 1);
  bool get isActive => count > 0;

  bool matches(ClassroomDocument d) =>
      (!favorites || d.flag('favorite')) &&
      (format.isEmpty || _formatGroup(d) == format) &&
      (type.isEmpty || d.text('documentType', 'other') == type) &&
      (subject.isEmpty || d.text('subject') == subject) &&
      (use.isEmpty || hasTeachingUse(d, use)) &&
      (pupil.isEmpty ||
          (pupil == 'unassigned'
              ? d.strings('pupilIds').isEmpty
              : d.strings('pupilIds').contains(pupil))) &&
      (tags.isEmpty || matchesMaterialTags(d.strings('tags'), tags));
}

Map<String, String> _pupilOptions(
  List<Pupil> pupils,
  Iterable<ClassroomDocument> documents,
  String selected,
) {
  final assigned = documents.expand((d) => d.strings('pupilIds')).toSet();
  return {
    '': 'Alle Zuordnungen',
    'unassigned': 'Ohne Schülerzuordnung',
    for (final p in pupils)
      if (!p.archived || p.id == selected || assigned.contains(p.id))
        p.id: '${p.name}${p.archived ? ' · Archiv' : ''}',
  };
}

extension _LibraryControls on _MaterialLibraryPageState {
  Future<void> editLibraryFilter(BuildContext ctx) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final deleted = fileTrash;
    final value = await showModalBottomSheet<_LibraryFilter>(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _LibraryFilterSheet(
        initial: filter,
        controller: c,
        matchesSearch: matchesSearch,
        contents: () => folderContents(ClassroomKind.material, deleted),
      ),
    );
    if (value == null || !mounted || view != 'files' || deleted != fileTrash) {
      return;
    }
    changeFilters(() => replaceFilter(value));
  }

  Widget librarySearchBar(BuildContext ctx) {
    final compact =
        MediaQuery.sizeOf(ctx).width < MediaQuery.textScalerOf(ctx).scale(220);
    final icon = Icon(
      filter.isActive ? Icons.filter_alt : Icons.tune,
      size: 20,
    );
    final label = filter.isActive ? 'Filter (${filter.count})' : 'Filter';
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: ValueKey(fileTrash ? 'trash-search' : 'library-search'),
            controller: currentSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: compact
                  ? 'Suchen'
                  : fileTrash
                  ? 'Papierkorb durchsuchen'
                  : 'Material suchen',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 11,
                horizontal: 12,
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: currentSearch.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Suche leeren',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => changeFilters(currentSearch.clear),
                    ),
            ),
            onChanged: (_) => changeFilters(() {}),
          ),
        ),
        const SizedBox(width: 6),
        compact
            ? IconButton(
                key: const ValueKey('library-filter'),
                tooltip: label,
                icon: icon,
                color: filter.isActive
                    ? Theme.of(ctx).colorScheme.primary
                    : null,
                onPressed: () => editLibraryFilter(ctx),
              )
            : TextButton.icon(
                key: const ValueKey('library-filter'),
                onPressed: () => editLibraryFilter(ctx),
                icon: icon,
                label: Text(label),
              ),
      ],
    );
  }
}

class _LibraryFilterSheet extends StatefulWidget {
  const _LibraryFilterSheet({
    required this.initial,
    required this.controller,
    required this.contents,
    required this.matchesSearch,
  });
  final _LibraryFilter initial;
  final NotebookController controller;
  final Iterable<ClassroomDocument> Function() contents;
  final bool Function(ClassroomDocument) matchesSearch;

  @override
  State<_LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends State<_LibraryFilterSheet> {
  late var draft = _LibraryFilter.copy(widget.initial);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (ctx, _) {
      final docs = widget.contents().toList();
      final hits = docs
          .where((d) => draft.matches(d) && widget.matchesSearch(d))
          .length;
      final formats = {
        for (final d in docs) _formatGroup(d),
        draft.format,
      }.where((v) => v.isNotEmpty).toList()..sort();
      final types = {
        for (final d in docs) d.text('documentType', 'other'),
        if (draft.type.isNotEmpty) draft.type,
      };
      final subjects = {
        for (final d in docs) d.text('subject'),
        draft.subject,
      }.where((s) => s.isNotEmpty).toList()..sort();
      final uses = {
        for (final d in docs) teachingUse(d),
        draft.use,
        if (docs.any((d) => hasTeachingUse(d, 'substitute'))) 'substitute',
      }..remove('');
      final tags = normalizeMaterialTags([
        ...draft.tags,
        ...docs.expand((d) => d.strings('tags')),
      ])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final theme = Theme.of(ctx);
      final compact =
          MediaQuery.sizeOf(ctx).width <
          MediaQuery.textScalerOf(ctx).scale(290);
      final apply = FilledButton(
        key: const ValueKey('library-apply-filter'),
        onPressed: () => Navigator.pop(ctx, draft),
        child: Text(
          compact ? 'Anzeigen ($hits)' : '${_fileCount(hits)} anzeigen',
        ),
      );
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Material filtern',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Schließen',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilterChip(
                          label: const Text('Favoriten'),
                          avatar: const Icon(Icons.star_outline, size: 18),
                          selected: draft.favorites,
                          onSelected: (v) =>
                              setState(() => draft.favorites = v),
                        ),
                      ),
                      if (formats.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Text(
                            'Dateiformat',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final format in formats)
                              ChoiceChip(
                                key: ValueKey('material-format-$format'),
                                label: Text(_formatName(format)),
                                selected: draft.format == format,
                                onSelected: (on) => setState(
                                  () => draft.format = on ? format : '',
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      _FilterFacet(
                        label: 'Schüler',
                        value: draft.pupil,
                        options: _pupilOptions(
                          widget.controller.pupils,
                          docs,
                          draft.pupil,
                        ),
                        onChanged: (v) => setState(() => draft.pupil = v),
                      ),
                      if (types.length > 1 || draft.type.isNotEmpty)
                        _FilterFacet(
                          label: 'Dokumentart',
                          value: draft.type,
                          options: {
                            '': 'Alle Dokumentarten',
                            for (final e in materialTypes.entries)
                              if (types.contains(e.key)) e.key: e.value,
                          },
                          onChanged: (v) => setState(() => draft.type = v),
                        ),
                      if (subjects.isNotEmpty)
                        _FilterFacet(
                          label: 'Fach',
                          value: draft.subject,
                          options: {
                            '': 'Alle Fächer',
                            for (final s in subjects) s: s,
                          },
                          onChanged: (v) => setState(() => draft.subject = v),
                        ),
                      if (uses.isNotEmpty)
                        _FilterFacet(
                          label: 'Verwendung',
                          value: draft.use,
                          options: {
                            '': 'Alle Verwendungen',
                            for (final e in planningUses.entries)
                              if (uses.contains(e.key)) e.key: e.value,
                          },
                          onChanged: (v) => setState(() => draft.use = v),
                        ),
                      if (tags.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Text(
                            'Tags',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final tag in tags)
                              FilterChip(
                                label: Text(tag),
                                selected: draft.tags.contains(tag),
                                onSelected: (on) => setState(() {
                                  if (on) {
                                    draft.tags.add(tag);
                                  } else {
                                    draft.tags.remove(tag);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: compact
                    ? Row(
                        children: [
                          if (draft.isActive)
                            IconButton(
                              tooltip: 'Zurücksetzen',
                              onPressed: () =>
                                  setState(() => draft = _LibraryFilter()),
                              icon: const Icon(Icons.restart_alt),
                            ),
                          Expanded(child: apply),
                        ],
                      )
                    : Row(
                        children: [
                          if (draft.isActive)
                            TextButton(
                              onPressed: () =>
                                  setState(() => draft = _LibraryFilter()),
                              child: const Text('Zurücksetzen'),
                            ),
                          const Spacer(),
                          apply,
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FilterFacet extends StatelessWidget {
  const _FilterFacet({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label, value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '$label wählen',
    initialValue: value,
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final e in options.entries)
        CheckedPopupMenuItem(
          value: e.key,
          checked: e.key == value,
          child: Text(e.value),
        ),
    ],
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final compact =
              constraints.maxWidth < MediaQuery.textScalerOf(ctx).scale(260);
          final title = Text(label, style: Theme.of(ctx).textTheme.titleSmall);
          final chosen = Text(
            options[value] ?? value,
            textAlign: compact ? TextAlign.start : TextAlign.end,
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
          );
          return Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 8 : 0),
            child: Row(
              children: [
                if (compact)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, chosen],
                    ),
                  )
                else ...[
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: chosen),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
          );
        },
      ),
    ),
  );
}
