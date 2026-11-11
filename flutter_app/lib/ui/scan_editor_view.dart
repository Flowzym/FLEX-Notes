part of 'scan_editor.dart';

extension _ScanEditorView on _ScanEditorState {
  Widget pageTiles() => LayoutBuilder(
    builder: (_, box) {
      final columns = pages.length == 1
          ? 1
          : (box.maxWidth /
                    (MediaQuery.textScalerOf(context).scale(1) > 1.5
                        ? 220
                        : 145))
                .floor()
                .clamp(1, 4);
      final width = (box.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in pages.indexed)
            DragTarget<int>(
              onWillAcceptWithDetails: (d) => !busy && d.data != item.$1,
              onAcceptWithDetails: (d) => reorderPage(d.data, item.$1),
              builder: (ctx, candidates, _) => LongPressDraggable<int>(
                data: item.$1,
                maxSimultaneousDrags: busy ? 0 : 1,
                feedback: Material(
                  elevation: 8,
                  child: SizedBox(
                    width: 100,
                    height: 130,
                    child: pagePreview(item.$2, item.$1, 100, 130),
                  ),
                ),
                child: SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    color: candidates.isEmpty
                        ? null
                        : Theme.of(ctx).colorScheme.primaryContainer,
                    child: Column(
                      children: [
                        InkWell(
                          key: ValueKey('scan-edit-page-${item.$1}'),
                          onTap: busy ? null : () => editPage(item.$1),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                pagePreview(
                                  item.$2,
                                  item.$1,
                                  width - 16,
                                  pages.length == 1
                                      ? (MediaQuery.sizeOf(context).height *
                                                .38)
                                            .clamp(200, 440)
                                      : 160,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.$2.photo ? 'Foto' : 'Seite'} ${item.$1 + 1} · Bearbeiten',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Seite nach vorne',
                              onPressed: busy || item.$1 == 0
                                  ? null
                                  : () => movePage(item.$1, -1),
                              icon: const Icon(Icons.arrow_back, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Seite nach hinten',
                              onPressed: busy || item.$1 == pages.length - 1
                                  ? null
                                  : () => movePage(item.$1, 1),
                              icon: const Icon(Icons.arrow_forward, size: 20),
                            ),
                            IconButton(
                              key: ValueKey('scan-replace-page-${item.$1}'),
                              tooltip: 'Bild ersetzen',
                              onPressed: busy
                                  ? null
                                  : () => replacePage(item.$1),
                              icon: const Icon(Icons.find_replace, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Seite entfernen',
                              onPressed: busy
                                  ? null
                                  : () => deletePage(item.$1),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget pagePreview(ScanPage page, int index, double width, double height) =>
      DocumentThumbnailView(
        identity: 'draft-page:${page.key}',
        title: '${page.photo ? 'Foto' : 'Seite'} ${index + 1}',
        fileKey: page.key,
        extension: 'jpg',
        files: widget.files,
        width: width,
        height: height,
      );

  Widget scannerView(BuildContext context) => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !busy) close();
    },
    child: FlexModal(
      maxWidth: 900,
      closeLabel: 'Schließen · Änderungen als Entwurf sichern',
      title: const Text('Scan & Foto'),
      onClose: busy ? null : close,
      headerActions: [
        if (buffer.hasContent || buffer.draft.revision > 0)
          IconButton(
            tooltip: 'Scanentwurf löschen',
            onPressed: busy ? null : deleteDraft,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy && !pageEditorOpen) const LinearProgressIndicator(),
          if (progress.isNotEmpty) Text(progress),
          if (cameraNotice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(cameraNotice!),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (removedPage != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('Seite entfernt'),
                TextButton.icon(
                  key: const ValueKey('scan-undo-remove'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : undoRemoval,
                  icon: const Icon(Icons.undo),
                  label: const Text('Rückgängig'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('scan-title'),
            controller: title,
            enabled: !busy,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Dateiname',
              counterText: '',
              suffixText: photoOutput ? '.jpg' : '.pdf',
            ),
            onChanged: (v) => change({'title': v}),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final format in const [
                ('pdf', 'PDF'),
                ('jpg', 'Fotos (JPG)'),
              ])
                ChoiceChip(
                  key: ValueKey('scan-format-${format.$1}'),
                  label: Text(format.$2),
                  selected: (data['outputFormat'] ?? 'pdf') == format.$1,
                  onSelected: busy
                      ? null
                      : (_) => change({'outputFormat': format.$1}),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${pages.length} ${pages.length == 1 ? 'Seite' : 'Seiten'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (pages.any((p) => filterUndo.containsKey(p.key)))
                IconButton(
                  tooltip: 'Stapelfilter rückgängig',
                  onPressed: busy ? null : undoFilter,
                  icon: const Icon(Icons.undo),
                ),
              if (pages.isNotEmpty)
                IconButton(
                  tooltip: 'Teilen',
                  onPressed: busy ? null : shareCurrent,
                  icon: const Icon(Icons.ios_share),
                ),
              if (pages.length > 1)
                IconButton(
                  key: const ValueKey('scan-batch-filter'),
                  tooltip: 'Seiten filtern',
                  onPressed: busy ? null : filterPages,
                  icon: const Icon(Icons.auto_fix_high),
                ),
              IconButton(
                tooltip: pageGrid ? 'Seiten als Liste' : 'Seiten als Raster',
                onPressed: () => updateScanView(() => pageGrid = !pageGrid),
                icon: Icon(
                  pageGrid ? Icons.view_list_outlined : Icons.grid_view,
                ),
              ),
            ],
          ),
          if (pages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.document_scanner_outlined, size: 44),
                  SizedBox(height: 12),
                  Text(
                    'Dein Dokument beginnt hier',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scannen, fotografieren oder eine Datei importieren.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          if (pageGrid)
            pageTiles()
          else
            ReorderableListView(
              key: const ValueKey('scan-page-order'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: busy ? (_, _) {} : reorderPage,
              children: [
                for (final item in pages.indexed)
                  Card(
                    key: ValueKey('scan-row-${item.$2.key}'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              pagePreview(item.$2, item.$1, 88, 120),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.$2.photo ? 'Foto' : 'Seite'} ${item.$1 + 1}',
                                    ),
                                    Wrap(
                                      children: [
                                        ReorderableDragStartListener(
                                          index: item.$1,
                                          enabled: !busy,
                                          child: const Tooltip(
                                            message: 'Zum Umsortieren ziehen',
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Icon(Icons.drag_handle),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Seite nach vorne',
                                          onPressed: busy || item.$1 == 0
                                              ? null
                                              : () => movePage(item.$1, -1),
                                          icon: const Icon(Icons.arrow_upward),
                                        ),
                                        IconButton(
                                          tooltip: 'Seite nach hinten',
                                          onPressed:
                                              busy ||
                                                  item.$1 == pages.length - 1
                                              ? null
                                              : () => movePage(item.$1, 1),
                                          icon: const Icon(
                                            Icons.arrow_downward,
                                          ),
                                        ),
                                        IconButton(
                                          key: ValueKey(
                                            'scan-replace-page-${item.$1}',
                                          ),
                                          tooltip: 'Bild ersetzen',
                                          onPressed: busy
                                              ? null
                                              : () => replacePage(item.$1),
                                          icon: const Icon(Icons.find_replace),
                                        ),
                                        IconButton(
                                          tooltip: 'Seite entfernen',
                                          onPressed: busy
                                              ? null
                                              : () => deletePage(item.$1),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    OutlinedButton.icon(
                                      key: ValueKey(
                                        'scan-edit-page-${item.$1}',
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => editPage(item.$1),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Bearbeiten'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'Zuordnung & Tags',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          MaterialTagEditor(
            key: const ValueKey('scan-tags'),
            values: List<String>.from(data['tags'] as List? ?? []),
            suggestions: materialTagUsage(c).keys,
            enabled: !busy,
            onChanged: (v) => change({'tags': v}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: data['documentType'] as String,
            decoration: const InputDecoration(labelText: 'Kategorie'),
            items: scanTypes.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: busy ? null : (v) => change({'documentType': v}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final ids = await chooseMaterialPupils(
                          context,
                          c,
                          pupilIds,
                        );
                        if (ids != null && mounted) {
                          change({
                            'pupilIds': {
                              ...ids,
                              ...documentLinkPupils(c, links),
                            }.toList(),
                          });
                        }
                      },
                icon: const Icon(Icons.people_outline),
                label: Text(
                  pupilIds.isEmpty
                      ? (links.any((l) => l.kind.endsWith('Draft'))
                            ? 'Über Entwurf zugeordnet'
                            : 'FLEX-Klasse')
                      : '${pupilIds.length} Schüler',
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final next = await chooseDocumentLinks(
                          context,
                          c,
                          links,
                        );
                        if (next != null && mounted) {
                          final owners = {
                            ...pupilIds,
                            ...documentLinkPupils(c, next),
                          };
                          change({
                            'links': next.map((l) => l.toJson()).toList(),
                            'pupilIds': owners.toList(),
                          });
                        }
                      },
                icon: const Icon(Icons.link),
                label: Text('Einträge · ${links.length}'),
              ),
            ],
          ),
          if (pupilIds.isNotEmpty)
            Text(
              c.pupils
                  .where((p) => pupilIds.contains(p.id))
                  .map((p) => p.name)
                  .join(', '),
            ),
          for (final link in links)
            Text(
              documentLinkLabel(c, link),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          if (data['sourceId'] != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vorhandene Datei ersetzen'),
              subtitle: Text(
                replace
                    ? 'Die lokale Fassung wird ersetzt. Bereits exportierte Kopien bleiben erhalten.'
                    : 'Es wird eine neue Kopie gespeichert.',
              ),
              value: replace,
              onChanged: busy
                  ? null
                  : (v) => updateScanView(() => replace = v ?? false),
            ),
          DraftStatus(buffer: buffer),
        ],
      ),
      footerContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.capturePages != null ||
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                ScanTool(
                  key: const ValueKey('scanner-camera'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : capture,
                  icon: Icons.document_scanner_outlined,
                  label: 'Scannen',
                ),
              if (widget.capturePhoto != null || nativeCamera)
                ScanTool(
                  key: const ValueKey('scanner-batch'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : captureSeries,
                  icon: Icons.burst_mode_outlined,
                  label: 'Serie',
                ),
              if (widget.capturePhoto != null || nativeCamera)
                ScanTool(
                  key: const ValueKey('scanner-photo'),
                  onPressed: busy || pages.length >= scanPageLimit
                      ? null
                      : takePhoto,
                  icon: Icons.photo_camera_outlined,
                  label: data['capturePending'] == true ? 'Fortsetzen' : 'Foto',
                ),
              ScanTool(
                key: const ValueKey('scanner-import'),
                onPressed: busy || pages.length >= scanPageLimit ? null : pick,
                icon: Icons.add_photo_alternate_outlined,
                label: 'Import',
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: busy ? null : () => close(keepDraft: true),
                child: const Text('Später fortsetzen'),
              ),
              FilledButton.icon(
                key: const ValueKey('save-scan'),
                onPressed: busy || pages.isEmpty ? null : save,
                icon: Icon(photoOutput ? Icons.photo : Icons.picture_as_pdf),
                label: Text(
                  photoOutput
                      ? (replace ? 'Foto ersetzen' : 'Fotos speichern')
                      : (replace ? 'PDF ersetzen' : 'PDF speichern'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
