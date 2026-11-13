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
    this.selected,
    this.onSelect,
  });
  final ClassroomDocument document;
  final MaterialFiles files;
  final bool grid, prepared;
  final List<Pupil> pupils;
  final VoidCallback onOpen, onEdit;
  final VoidCallback? onFavorite, onPrepare, onRestore;
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
      if (names.isNotEmpty) names.join(', '),
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
        if (details.isNotEmpty) smallText(details, lines: 2),
        if (d.text('topic').isNotEmpty) smallText(d.text('topic')),
        if (d.strings('tags').isNotEmpty)
          smallText(d.strings('tags').map((tag) => '#$tag').join(' ')),
      ],
    );
    final availability = FutureBuilder<bool>(
      future: available,
      builder: (_, snapshot) => smallText(
        [
          d.text('extension') == 'jpg'
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
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onFavorite != null)
                  IconButton(
                    tooltip: d.flag('favorite')
                        ? 'Favorit entfernen'
                        : 'Als Favorit merken',
                    onPressed: widget.onFavorite,
                    icon: Icon(
                      d.flag('favorite') ? Icons.star : Icons.star_border,
                      color: d.flag('favorite')
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                if (widget.onPrepare != null)
                  IconButton(
                    tooltip: widget.prepared
                        ? 'Von heute entfernen'
                        : 'Für heute bereitlegen',
                    onPressed: widget.onPrepare,
                    isSelected: widget.prepared,
                    icon: const Icon(Icons.today_outlined),
                    selectedIcon: Icon(
                      Icons.event_available,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  tooltip: 'Materialangaben und Aktionen',
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                if (widget.onRestore != null)
                  IconButton(
                    tooltip: 'Wiederherstellen',
                    onPressed: widget.onRestore,
                    icon: const Icon(Icons.restore),
                  ),
              ],
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
          padding: const EdgeInsets.all(10),
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
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              final wide =
                  constraints.maxWidth >= 540 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.3;
              return Row(
                crossAxisAlignment: wide
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  MaterialThumbnail(
                    material: d,
                    files: widget.files,
                    width: 48,
                    height: 64,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        description,
                        const SizedBox(height: 4),
                        if (wide)
                          availability
                        else
                          Row(
                            children: [
                              Expanded(child: availability),
                              const SizedBox(width: 4),
                              actions,
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (wide) ...[const SizedBox(width: 8), actions],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
