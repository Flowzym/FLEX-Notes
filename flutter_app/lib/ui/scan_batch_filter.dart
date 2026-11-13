import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/document_scanner.dart';
import '../services/material_files.dart';
import '../services/scan_images.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'scan_tools.dart';

class ScanBatchFilter extends StatefulWidget {
  const ScanBatchFilter({super.key, required this.pages, required this.files});
  final List<ScanPage> pages;
  final MaterialFiles files;
  @override
  State<ScanBatchFilter> createState() => _ScanBatchFilterState();
}

class _ScanBatchFilterState extends State<ScanBatchFilter> {
  late final selected = widget.pages.map((p) => p.key).toSet();
  String filter = 'document';
  int preview = 0, generation = 0, previewGeneration = 0;
  Uint8List? base, rendered;
  bool rendering = false;
  Map<String, Uint8List>? thumbnails;
  String? error;
  @override
  void initState() {
    super.initState();
    loadPreview(0);
  }

  Future<void> loadPreview(int index) async {
    final token = ++generation;
    setState(() {
      preview = index;
      thumbnails = null;
      base = null;
      rendered = null;
      error = null;
    });
    try {
      final bundle = await compute(
        scanPreviewBundle,
        await widget.files.read(widget.pages[index].key),
      );
      if (mounted && generation == token) {
        setState(() {
          thumbnails = Map<String, Uint8List>.from(bundle['thumbnails'] as Map);
          base = bundle['preview'] as Uint8List;
        });
        await renderFilter();
      }
    } catch (e) {
      if (mounted && generation == token) {
        setState(() => error = friendlyError(e));
      }
    }
  }

  Future<void> renderFilter() async {
    final pixels = base, pageToken = generation, token = ++previewGeneration;
    if (pixels == null) return;
    setState(() => rendering = true);
    try {
      final result = await compute(editScanPixels, {
        'bytes': pixels,
        'filter': filter,
        'previewMax': 720,
      });
      if (mounted && generation == pageToken && previewGeneration == token) {
        setState(() {
          rendered = result['bytes'] as Uint8List;
          rendering = false;
        });
      }
    } catch (e) {
      if (mounted && generation == pageToken && previewGeneration == token) {
        setState(() {
          error = friendlyError(e);
          rendering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FlexModal(
    title: const Text('Seiten filtern'),
    onClose: () => Navigator.pop(context),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${selected.length} von ${widget.pages.length} ausgewählt',
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                selected.length == widget.pages.length
                    ? selected.clear()
                    : selected.addAll(widget.pages.map((p) => p.key));
              }),
              child: Text(
                selected.length == widget.pages.length ? 'Keine' : 'Alle',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final item in widget.pages.indexed)
              FilterChip(
                label: Text('Seite ${item.$1 + 1}'),
                selected: selected.contains(item.$2.key),
                onSelected: (v) {
                  setState(() {
                    v
                        ? selected.add(item.$2.key)
                        : selected.remove(item.$2.key);
                  });
                  if (v) loadPreview(item.$1);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Vorige Vorschauseite',
              onPressed: preview == 0 ? null : () => loadPreview(preview - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                'Vorschau · Seite ${preview + 1}',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Nächste Vorschauseite',
              onPressed: preview + 1 == widget.pages.length
                  ? null
                  : () => loadPreview(preview + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (error != null) Text(error!),
        SizedBox(
          height: 230,
          child: rendered == null
              ? error != null
                    ? Center(
                        child: TextButton.icon(
                          onPressed: () => loadPreview(preview),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Vorschau erneut laden'),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator())
              : Image.memory(
                  rendered!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
        ),
        if (thumbnails != null)
          ScanFilterStrip(
            thumbnails: thumbnails!,
            selected: filter,
            onSelected: (v) {
              setState(() => filter = v);
              renderFilter();
            },
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        key: const ValueKey('scan-batch-apply'),
        onPressed: selected.isEmpty || rendered == null || rendering
            ? null
            : () => Navigator.pop(context, (filter, selected)),
        child: Text('Anwenden · ${selected.length}'),
      ),
    ],
  );
}
