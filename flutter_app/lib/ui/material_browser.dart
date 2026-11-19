part of 'material_library.dart';

const _materialSortLabels = {
  'recent': 'Zuletzt geändert',
  'name': 'Name A–Z',
  'subject': 'Fach',
  'format': 'Dateiformat',
};

class _MaterialBrowserCard extends StatefulWidget {
  const _MaterialBrowserCard({
    super.key,
    required this.document,
    required this.files,
    required this.grid,
    required this.pupils,
    required this.prepared,
    required this.onOpen,
    required this.onEdit,
    this.onFavorite,
    this.onPrepare,
    this.onRestore,
    this.onAssign,
    this.selected,
    this.onSelect,
  });
  final ClassroomDocument document;
  final MaterialFiles files;
  final bool grid, prepared;
  final List<Pupil> pupils;
  final VoidCallback onOpen, onEdit;
  final VoidCallback? onFavorite, onPrepare, onRestore, onAssign;
  final bool? selected;
  final ValueChanged<bool>? onSelect;

  @override
  State<_MaterialBrowserCard> createState() => _MaterialBrowserCardState();
}

class _MaterialBrowserCardState extends State<_MaterialBrowserCard> {
  late Future<bool> available = check();

  Future<bool> check() => widget.files
      .exists(widget.document.text('localKey'))
      .catchError((Object _) => false);

  @override
  void didUpdateWidget(covariant _MaterialBrowserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.files != widget.files) {
      available = check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document, theme = Theme.of(context);
    final names = [
      for (final p in widget.pupils)
        if (d.strings('pupilIds').contains(p.id)) p.name,
    ];
    final details = [
      d.text('subject'),
      if (d.text('documentType', 'other') != 'other')
        materialTypes[d.text('documentType')] ?? '',
      if (widget.onAssign == null && names.isNotEmpty) names.join(', '),
    ].where((text) => text.isNotEmpty).join(' · ');
    Widget smallText(String text, {int lines = 1}) => Tooltip(
      message: text,
      child: Text(
        text,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
    );
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: d.title,
          child: Text(
            d.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 4),
        if (widget.grid && details.isNotEmpty) smallText(details, lines: 2),
        if (widget.grid && d.text('topic').isNotEmpty)
          smallText(d.text('topic')),
        if (widget.grid && d.strings('tags').isNotEmpty)
          smallText(d.strings('tags').map((tag) => '#$tag').join(' ')),
      ],
    );
    final availability = FutureBuilder<bool>(
      future: available,
      builder: (_, snapshot) => smallText(
        [
          if (!widget.grid && details.isNotEmpty) details,
          {'jpg', 'png'}.contains(d.text('extension'))
              ? 'Foto'
              : d.text('extension').toUpperCase(),
          if (snapshot.connectionState != ConnectionState.done)
            'Verfügbarkeit prüfen …'
          else if (snapshot.data == true)
            'Offline'
          else if (d.text('url').isNotEmpty)
            'Online'
          else
            'Datei fehlt',
          if (uploadLabel(d).isNotEmpty) uploadLabel(d),
          if (d.flag('sourceMissing')) 'Quelle fehlt',
        ].where((text) => text.isNotEmpty).join(' · '),
        lines: 2,
      ),
    );
    final actions = IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          maximumSize: const Size.square(44),
          padding: const EdgeInsets.all(10),
          iconSize: 22,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: widget.selected != null
          ? SizedBox.square(
              dimension: 44,
              child: Tooltip(
                message: 'Auswählen',
                child: Checkbox(
                  value: widget.selected,
                  onChanged: (v) => widget.onSelect?.call(v == true),
                  semanticLabel: 'Material auswählen',
                ),
              ),
            )
          : PopupMenuButton<String>(
              tooltip: 'Materialangaben und Aktionen',
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'details':
                    widget.onEdit();
                  case 'favorite':
                    widget.onFavorite?.call();
                  case 'today':
                    widget.onPrepare?.call();
                  case 'restore':
                    widget.onRestore?.call();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Text('Materialangaben'),
                ),
                if (widget.onFavorite != null)
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(
                      d.flag('favorite')
                          ? 'Favorit entfernen'
                          : 'Als Favorit merken',
                    ),
                  ),
                if (widget.onPrepare != null)
                  PopupMenuItem(
                    value: 'today',
                    child: Text(
                      widget.prepared
                          ? 'Von heute entfernen'
                          : 'Für heute bereitlegen',
                    ),
                  ),
                if (widget.onRestore != null)
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Wiederherstellen'),
                  ),
              ],
            ),
    );
    final assignment = widget.onAssign == null || widget.selected != null
        ? null
        : TextButton.icon(
            key: ValueKey('material-assign-${d.id}'),
            onPressed: widget.onAssign,
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text(
              names.isEmpty ? 'Zuordnen' : names.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
    return Material(
      color: theme.colorScheme.surfaceContainer.withValues(alpha: .8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.selected == true
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: .4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.selected == null
            ? widget.onOpen
            : () => widget.onSelect?.call(!widget.selected!),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: LayoutBuilder(
            builder: (_, constraints) {
              if (widget.grid) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MaterialThumbnail(
                      material: d,
                      files: widget.files,
                      width: double.infinity,
                      height: 140,
                    ),
                    const SizedBox(height: 8),
                    description,
                    const SizedBox(height: 4),
                    availability,
                    ?assignment,
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MaterialThumbnail(
                    material: d,
                    files: widget.files,
                    width: 42,
                    height: 56,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [description, availability, ?assignment],
                    ),
                  ),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
