part of 'material_library.dart';

extension _MaterialSelectionView on _MaterialLibraryPageState {
  Widget selectionBar(BuildContext ctx, List<ClassroomDocument> visible) {
    final canAct = !busy && selection.isNotEmpty;
    void finish() => updateLibrary(() {
      selection.clear();
      selecting = false;
    });
    final assign = OutlinedButton.icon(
      onPressed: canAct
          ? () => action(assignSelection, showProgress: false)
          : null,
      icon: const Icon(Icons.people_outline),
      label: const Text('Zuordnen'),
    );
    final options = PopupMenuButton<String>(
      tooltip: 'Aktionen für Auswahl',
      icon: const Icon(Icons.more_vert),
      enabled: canAct,
      onSelected: (value) => action(() async {
        final ids = selection.toList();
        final docs = resolveMaterials(c.classroom, ids);
        switch (value) {
          case 'favorite':
            final add = docs.any((d) => !d.flag('favorite'));
            await c.saveClassroomBatch([
              for (final d in docs)
                if (d.flag('favorite') != add) d.patch({'favorite': add}),
            ]);
          case 'prepare':
            await prepareForDate(ctx, c, ids);
          case 'package':
            await addSelectionToPackage(ids);
          case 'tags':
            await tagSelection();
          case 'share':
            await shareMaterials(ctx, docs);
          case 'offline':
            await cacheMaterials(ctx, c, docs, drive: drive);
          case 'trash':
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
        }
      }, showProgress: value == 'offline'),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'favorite',
          child: Text(
            visible
                    .where((d) => selection.contains(d.id))
                    .every((d) => d.flag('favorite'))
                ? 'Favoriten entfernen'
                : 'Als Favoriten merken',
          ),
        ),
        const PopupMenuItem(value: 'prepare', child: Text('Bereitlegen')),
        const PopupMenuItem(
          value: 'package',
          child: Text('Zu Paket hinzufügen'),
        ),
        const PopupMenuItem(value: 'tags', child: Text('Tags bearbeiten')),
        const PopupMenuItem(value: 'share', child: Text('Auswahl teilen')),
        PopupMenuItem(
          value: 'offline',
          enabled: materialDeviceAvailable,
          child: const Text('Offline laden'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'trash', child: Text('In den Papierkorb')),
      ],
    );
    final all =
        visible.isNotEmpty && visible.every((d) => selection.contains(d.id));
    return SafeArea(
      top: false,
      child: SelectionControls(
        count: selection.length,
        allVisibleSelected: all,
        onFinish: busy ? null : finish,
        onToggleAll: busy || visible.isEmpty
            ? null
            : () => updateLibrary(() {
                if (all) {
                  selection.removeAll(visible.map((d) => d.id));
                } else {
                  selection.addAll(visible.map((d) => d.id));
                }
              }),
        actions: [
          if (trash)
            TextButton.icon(
              onPressed: canAct
                  ? () => action(() async {
                      await c.saveClassroomBatch([
                        for (final d in visible)
                          if (selection.contains(d.id))
                            d.patch({'deleted': false}),
                      ]);
                      if (mounted) finish();
                    }, showProgress: false)
                  : null,
              icon: const Icon(Icons.restore),
              label: const Text('Wiederherstellen'),
            )
          else ...[
            assign,
            options,
          ],
        ],
      ),
    );
  }

  Widget addMaterialMenu(BuildContext ctx) => PopupMenuButton<String>(
    tooltip: 'Material hinzufügen',
    icon: const Icon(Icons.add),
    enabled: !busy,
    onSelected: (value) => action(() async {
      switch (value) {
        case 'scan':
          await scanAndShow(ctx, c, const ScanContext());
        case 'file':
          await importFile();
        case 'link':
          await showClassroomEditor(ctx, c, ClassroomKind.material);
        case 'add':
          await showQuickAdd(ctx, c);
      }
    }),
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'scan',
        child: Text('Scannen oder fotografieren'),
      ),
      PopupMenuItem(
        value: 'file',
        enabled: materialDeviceAvailable,
        child: const Text('Datei hinzufügen'),
      ),
      const PopupMenuItem(value: 'link', child: Text('Link hinzufügen')),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'add',
        child: Text('Weitere Einträge anlegen'),
      ),
    ],
  );

  Widget libraryOptions(BuildContext ctx) => PopupMenuButton<String>(
    tooltip: 'Bibliotheksoptionen',
    icon: const Icon(Icons.more_horiz),
    enabled: !busy,
    onSelected: (value) {
      switch (value) {
        case 'assigned':
          showAssignedMaterials(ctx, c);
        case 'trash':
          openFileTrash(true);
        case 'tags':
          showMaterialTagManager(ctx, c);
        case 'export':
          action(exportBundle);
        case 'import':
          action(importBundle);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'assigned',
        child: Text('Zugewiesene Materialien'),
      ),
      const PopupMenuItem(value: 'tags', child: Text('Tags verwalten')),
      const PopupMenuItem(value: 'trash', child: Text('Papierkorb')),
      if (materialDeviceAvailable) ...[
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'export',
          child: Text('Materialpaket exportieren'),
        ),
        const PopupMenuItem(
          value: 'import',
          child: Text('Materialpaket öffnen'),
        ),
      ],
    ],
  );

  Widget materialBrowserToolbar(BuildContext ctx, int count) {
    final theme = Theme.of(ctx);
    final labels = filter.labels.join(' · ');
    final total = Text(
      _fileCount(count),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final pupilLabel = switch (filter.pupil) {
      '' => 'Schüler',
      'unassigned' => 'Ohne Zuordnung',
      final id =>
        c.pupils.where((p) => p.id == id).firstOrNull?.name ??
            'Unbekannte Zuordnung',
    };
    return LayoutBuilder(
      builder: (_, constraints) {
        final showName =
            constraints.maxWidth >= MediaQuery.textScalerOf(ctx).scale(230);
        return Row(
          children: [
            Expanded(
              child: labels.isEmpty
                  ? total
                  : Tooltip(
                      message: 'Alle Filter aufheben',
                      child: TextButton(
                        onPressed: () => changeFilters(
                          () => replaceFilter(_LibraryFilter()),
                        ),
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.zero,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  total,
                                  Text(
                                    labels,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.close, size: 15),
                          ],
                        ),
                      ),
                    ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: showName ? constraints.maxWidth * .44 : 48,
              ),
              child: PopupMenuButton<String>(
                key: const ValueKey('material-pupil-filter'),
                tooltip: filter.pupil.isEmpty
                    ? 'Nach Schüler filtern'
                    : 'Schülerfilter · $pupilLabel',
                initialValue: filter.pupil,
                onSelected: (v) => changeFilters(() => filter.pupil = v),
                itemBuilder: (_) => [
                  for (final e in _pupilOptions(
                    c.pupils,
                    folderContents(ClassroomKind.material, trash),
                    filter.pupil,
                  ).entries)
                    CheckedPopupMenuItem(
                      value: e.key,
                      checked: filter.pupil == e.key,
                      child: Text(e.value),
                    ),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        filter.pupil.isEmpty
                            ? Icons.person_outline
                            : Icons.person,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      if (showName) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            pupilLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('material-sort'),
              tooltip: 'Sortierung · ${_materialSortLabels[sort]}',
              icon: const Icon(Icons.sort, size: 20),
              initialValue: sort,
              onSelected: (v) => guarded(
                ctx,
                () => c.saveAppearance(c.appearance.patch({'materialSort': v})),
              ),
              itemBuilder: (_) => [
                for (final e in _materialSortLabels.entries)
                  CheckedPopupMenuItem(
                    value: e.key,
                    checked: sort == e.key,
                    child: Text(e.value),
                  ),
              ],
            ),
            MaterialLayoutButton(
              key: const ValueKey('material-layout'),
              value: layout,
              onChanged: (choice) => guarded(
                ctx,
                () => c.saveAppearance(
                  c.appearance.patch({'materialLayout': choice.name}),
                ),
              ),
            ),
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
      layout: layout,
      prepared: prepared.contains(d.id),
      selected: selecting ? selection.contains(d.id) : null,
      onSelect: busy
          ? null
          : (value) => updateLibrary(() {
              if (value) {
                selecting = true;
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
      onAssign: trash || busy
          ? null
          : () => showMaterialAssignments(ctx, c, [d]),
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
    final grid = layout == MaterialLayout.grid;
    final columns = grid
        ? ((availableWidth + 12) / (minWidth + 12)).floor().clamp(1, 5)
        : 1;
    // Separate rows let the outer ListView load previews only near the viewport.
    return [
      if (documents.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: MaterialGroupingButton(c),
        ),
      ...groupedMaterialRows(
        c,
        documents,
        (group) => [
          for (var start = 0; start < group.length; start += columns)
            Padding(
              key: start == 0 ? ValueKey('material-${layout.name}') : null,
              padding: EdgeInsets.only(bottom: grid ? 12 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 12),
                    Expanded(
                      child: start + column < group.length
                          ? card(group[start + column])
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    ];
  }
}
