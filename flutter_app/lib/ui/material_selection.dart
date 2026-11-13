part of 'material_library.dart';

extension _MaterialSelectionView on _MaterialLibraryPageState {
  Widget selectionBar(BuildContext ctx) => Material(
    color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('${selection.length} ausgewählt')),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => updateLibrary(() {
                          selection.clear();
                          selecting = false;
                        }),
                  child: const Text('Fertig'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(
                          () => prepareForDate(ctx, c, selection.toList()),
                        ),
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('Bereitlegen'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(assignSelection, showProgress: false),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Schüler'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () =>
                            action(addSelectionToPackage, showProgress: false),
                  icon: const Icon(Icons.folder_copy_outlined),
                  label: const Text('Paket'),
                ),
                IconButton(
                  tooltip: 'Tags der Auswahl bearbeiten',
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(tagSelection, showProgress: false),
                  icon: const Icon(Icons.sell_outlined),
                ),
                IconButton(
                  tooltip: 'Auswahl teilen',
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(
                          () => shareMaterials(
                            ctx,
                            c.classroom.where((d) => selection.contains(d.id)),
                          ),
                          showProgress: false,
                        ),
                  icon: const Icon(Icons.ios_share),
                ),
                IconButton(
                  tooltip: 'Auswahl offline laden',
                  onPressed:
                      busy || selection.isEmpty || !materialDeviceAvailable
                      ? null
                      : () => action(
                          () => cacheMaterials(
                            ctx,
                            c,
                            resolveMaterials(c.classroom, selection),
                            drive: drive,
                          ),
                        ),
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Auswahl in Papierkorb',
                  onPressed: busy || selection.isEmpty
                      ? null
                      : () => action(() async {
                          final docs = c.classroom
                              .where((d) => selection.contains(d.id))
                              .toList();
                          await c.repository.saveClassroomDocuments([
                            for (final d in docs) d.patch({'deleted': true}),
                          ]);
                          await c.reload();
                          if (mounted) {
                            updateLibrary(() {
                              selection.clear();
                              selecting = false;
                            });
                          }
                        }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget materialBrowserToolbar(BuildContext ctx, int count) {
    final countLabel = Text('$count ${count == 1 ? 'Datei' : 'Dateien'}');
    final layout = IconButton(
      key: const ValueKey('material-layout'),
      tooltip: grid ? 'Listenansicht' : 'Rasteransicht',
      onPressed: () => guarded(
        context,
        () => c.saveAppearance(c.appearance.patch({'materialGrid': !grid})),
      ),
      icon: Icon(grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
    );
    final sorting = PopupMenuButton<String>(
      key: const ValueKey('material-sort'),
      tooltip: 'Materialien sortieren',
      initialValue: sort,
      onSelected: (value) => guarded(
        context,
        () => c.saveAppearance(c.appearance.patch({'materialSort': value})),
      ),
      itemBuilder: (_) => [
        for (final entry in _materialSortLabels.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: sort == entry.key,
            child: Text(entry.value),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(_materialSortLabels[sort]!, maxLines: 2)),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 480 &&
            MediaQuery.textScalerOf(ctx).scale(1) > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: countLabel),
                  layout,
                ],
              ),
              sorting,
            ],
          );
        }
        return Row(
          children: [
            countLabel,
            Expanded(child: sorting),
            layout,
          ],
        );
      },
    );
  }

  List<Widget> materialFiles(
    BuildContext ctx,
    List<ClassroomDocument> documents,
    double availableWidth,
  ) {
    final preparation = preparationFor(c.classroom, dateOnly(DateTime.now()));
    final prepared = preparation.deleted
        ? <String>[]
        : preparation.strings('materialIds');
    Widget card(ClassroomDocument d) => _MaterialBrowserCard(
      key: ValueKey(d.id),
      document: d,
      files: files,
      pupils: c.pupils,
      grid: grid,
      prepared: prepared.contains(d.id),
      selected: selecting ? selection.contains(d.id) : null,
      onSelect: (value) => updateLibrary(() {
        if (value) {
          selection.add(d.id);
        } else {
          selection.remove(d.id);
        }
      }),
      onOpen: () => action(
        () => trash
            ? showMaterialDetails(ctx, c, d, drive: drive)
            : openMaterial(ctx, c, d, drive: drive, files: files),
      ),
      onEdit: () => showMaterialDetails(ctx, c, d, drive: drive),
      onFavorite: trash
          ? null
          : () => action(
              () => c.saveClassroom(d.patch({'favorite': !d.flag('favorite')})),
              showProgress: false,
            ),
      onPrepare: trash
          ? null
          : () => action(() => togglePreparedToday(d.id), showProgress: false),
      onRestore: trash
          ? () => action(() => c.saveClassroom(d.patch({'deleted': false})))
          : null,
    );
    final minWidth = MediaQuery.textScalerOf(ctx).scale(1) > 1.4
        ? 270.0
        : 160.0;
    final columns = grid
        ? ((availableWidth + 12) / (minWidth + 12)).floor().clamp(1, 5)
        : 1;
    // Separate rows let the outer ListView load previews only near the viewport.
    return [
      for (var start = 0; start < documents.length; start += columns)
        Padding(
          key: start == 0
              ? ValueKey(grid ? 'material-grid' : 'material-list')
              : null,
          padding: EdgeInsets.only(bottom: grid ? 12 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 12),
                Expanded(
                  child: start + column < documents.length
                      ? card(documents[start + column])
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
    ];
  }
}
