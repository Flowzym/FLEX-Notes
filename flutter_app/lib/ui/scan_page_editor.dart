import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/scan_images.dart';
import '../services/scan_edges.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'scan_tools.dart';

/// All changes remain reversible until Apply. Applying replaces the page pixels
/// in the draft, so subsequent filters can never reveal a committed redaction.
class ScanPageEditor extends StatefulWidget {
  const ScanPageEditor({
    super.key,
    required this.bytes,
    required this.pageNumber,
    required this.width,
    required this.height,
    this.photo = false,
  });
  final bool photo;
  final Uint8List bytes;
  final int pageNumber, width, height;
  @override
  State<ScanPageEditor> createState() => _ScanPageEditorState();
}

class _ScanPageEditorState extends State<ScanPageEditor> {
  late Uint8List current = widget.bytes;
  late int currentWidth = widget.width, currentHeight = widget.height;
  String mode = 'filter', filter = 'color';
  double brightness = 1, contrast = 1, saturation = 1;
  bool busy = false, comparing = false, cropPreview = false;
  final undo = <_ScanEditSnapshot>[], redo = <_ScanEditSnapshot>[];
  final zoom = TransformationController();
  String? error;
  final redactions = <Rect>[];
  List<Offset> corners = const [
    Offset.zero,
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  ];
  Offset? start, end;
  int? dragging;
  Uint8List? previewSource, preview;
  Map<String, Uint8List> thumbnails = {};
  List<Offset> detected = [], edges = [];
  bool detecting = false, snapping = true, snapped = false, previewBusy = false;
  String? detectionMessage;
  Timer? previewTimer;
  int previewRevision = 0, sourceRevision = 0;

  @override
  void initState() {
    super.initState();
    preparePreview();
  }

  @override
  void dispose() {
    zoom.dispose();
    previewTimer?.cancel();
    previewRevision++;
    sourceRevision++;
    super.dispose();
  }

  _ScanEditSnapshot snapshot({bool geometry = false}) => _ScanEditSnapshot(
    bytes: current,
    width: currentWidth,
    height: currentHeight,
    filter: filter,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    corners: geometry
        ? const [Offset.zero, Offset(1, 0), Offset(1, 1), Offset(0, 1)]
        : [...corners],
    redactions: [...redactions],
    mode: geometry ? 'filter' : mode,
  );

  void remember({bool geometry = false}) {
    undo.add(snapshot(geometry: geometry));
    // Image buffers are shared by parameter-only changes; geometric history is
    // bounded to avoid retaining a full batch of high-resolution source images.
    redo.clear();
    int historyBytes() => {
      for (final state in undo) state.bytes,
    }.fold(0, (sum, bytes) => sum + bytes.lengthInBytes);
    while (undo.length > 1 && (undo.length > 12 || historyBytes() > 24000000)) {
      undo.removeAt(0);
    }
  }

  Future<void> restore(_ScanEditSnapshot state) async {
    previewRevision++;
    sourceRevision++;
    previewTimer?.cancel();
    setState(() {
      current = state.bytes;
      currentWidth = state.width;
      currentHeight = state.height;
      filter = state.filter;
      brightness = state.brightness;
      contrast = state.contrast;
      saturation = state.saturation;
      corners = [...state.corners];
      redactions
        ..clear()
        ..addAll(state.redactions);
      mode = state.mode;
      comparing = false;
      cropPreview = false;
      error = null;
      start = end = null;
      dragging = null;
      preview = previewSource = null;
      thumbnails = {};
      detected = [];
      edges = [];
      previewBusy = false;
      detectionMessage = null;
      zoom.value = Matrix4.identity();
    });
    await preparePreview();
  }

  void undoEdit() {
    if (busy || detecting || undo.isEmpty) return;
    redo.add(snapshot());
    restore(undo.removeLast());
  }

  void redoEdit() {
    if (busy || detecting || redo.isEmpty) return;
    undo.add(snapshot());
    restore(redo.removeLast());
  }

  Future<void> selectTool(String value) async {
    if (busy || detecting || mode == value) return;
    if (mode == 'crop') {
      final ok = await render(crop: true);
      if (!ok || !mounted) return;
    }
    setState(() {
      mode = value;
      cropPreview = false;
      start = end = null;
      comparing = false;
      zoom.value = Matrix4.identity();
    });
    if (mode == 'crop' && !widget.photo && edges.isEmpty) await detectEdges();
    schedulePreview();
  }

  Future<void> preparePreview() async {
    final revision = ++sourceRevision;
    try {
      final bundle = await compute(scanPreviewBundle, current);
      if (!mounted || revision != sourceRevision) return;
      setState(() {
        previewSource = bundle['preview'] as Uint8List;
        thumbnails = Map<String, Uint8List>.from(bundle['thumbnails'] as Map);
      });
      schedulePreview();
    } catch (e) {
      if (mounted && revision == sourceRevision) {
        setState(() => error = friendlyError(e));
      }
    }
  }

  void schedulePreview() {
    final revision = ++previewRevision;
    previewTimer?.cancel();
    previewTimer = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted || previewSource == null) return;
      setState(() => previewBusy = true);
      try {
        final result = await compute(editScanPixels, {
          ...args(crop: mode == 'crop'),
          'bytes': previewSource!,
        });
        if (mounted && revision == previewRevision) {
          setState(() => preview = result['bytes'] as Uint8List);
        }
      } catch (_) {
        // A temporarily crossed polygon is shown as an overlay, never committed.
      } finally {
        if (mounted && revision == previewRevision) {
          setState(() => previewBusy = false);
        }
      }
    });
  }

  Future<void> detectEdges() async {
    if (detecting || busy) return;
    final revision = sourceRevision;
    setState(() => detecting = true);
    try {
      final result = await compute(detectScanEdges, current);
      if (!mounted || revision != sourceRevision) return;
      List<Offset> points(dynamic values) => (values as List? ?? [])
          .map(
            (v) => Offset((v[0] as num).toDouble(), (v[1] as num).toDouble()),
          )
          .toList();
      if ((result['corners'] as List? ?? []).length == 4) remember();
      setState(() {
        detected = points(result['corners']);
        edges = points(result['edges']);
        if (detected.length == 4) corners = [...detected];
        detectionMessage = detected.isEmpty
            ? 'Keine sicheren Ränder erkannt. Ecken manuell setzen.'
            : 'Dokumentränder erkannt.';
      });
      schedulePreview();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => detecting = false);
    }
  }

  Map<String, dynamic> args({int turns = 0, bool crop = false}) => {
    'bytes': current,
    'turns': turns,
    'filter': filter,
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    if (crop) 'corners': corners.map((p) => [p.dx, p.dy]).toList(),
    'redactions': redactions
        .map((r) => [r.left, r.top, r.right, r.bottom])
        .toList(),
  };
  Future<bool> render({
    int turns = 0,
    bool crop = false,
    bool finish = false,
    bool flip = false,
  }) async {
    if (busy || detecting) return false;
    setState(() {
      busy = true;
      error = null;
      comparing = false;
    });
    try {
      // Tool changes never bake filters. Only geometry is committed losslessly;
      // brightness, color and contrast remain adjustable until final export.
      final geometry = turns != 0 || crop || flip;
      Map<String, dynamic>? transformed;
      if (geometry) {
        transformed = await compute(transformScanPixels, {
          'bytes': current,
          'turns': turns,
          'flip': flip,
          if (crop) 'corners': corners.map((p) => [p.dx, p.dy]).toList(),
          'redactions': redactions
              .map((r) => [r.left, r.top, r.right, r.bottom])
              .toList(),
        });
      }
      if (finish) {
        final result = await compute(editScanPixels, {
          ...args(),
          if (transformed != null) 'bytes': transformed['bytes'],
          if (transformed != null) 'redactions': <List<double>>[],
        });
        if (mounted) Navigator.pop(context, result);
        return true;
      }
      if (!mounted) return false;
      if (transformed != null) {
        remember(geometry: true);
        setState(() {
          current = transformed!['bytes'] as Uint8List;
          currentWidth = transformed['width'] as int;
          currentHeight = transformed['height'] as int;
          redactions.clear();
          corners = const [
            Offset.zero,
            Offset(1, 0),
            Offset(1, 1),
            Offset(0, 1),
          ];
          mode = 'filter';
          cropPreview = false;
          preview = previewSource = null;
          detected = [];
          edges = [];
          detectionMessage = null;
          zoom.value = Matrix4.identity();
        });
        previewRevision++;
        await preparePreview();
      }
      return true;
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget adjustment(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> update,
  ) => Row(
    children: [
      SizedBox(
        width: 90,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: Slider(
          key: ValueKey('scan-adjust-$label'),
          value: value,
          min: min,
          max: max,
          label: '${(value * 100).round()} %',
          onChangeStart: busy ? null : (_) => remember(),
          onChanged: busy
              ? null
              : (v) {
                  setState(() {
                    update(v);
                    comparing = false;
                  });
                  schedulePreview();
                },
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !detecting,
    child: FlexModal(
      closeLabel: 'Änderungen verwerfen',
      maxWidth: 950,
      title: Text(
        '${widget.photo ? 'Foto' : 'Seite'} ${widget.pageNumber} bearbeiten',
      ),
      onClose: busy || detecting ? null : () => Navigator.pop(context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (busy) const LinearProgressIndicator(),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              IconButton(
                tooltip: 'Rückgängig',
                onPressed: busy || detecting || undo.isEmpty ? null : undoEdit,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Wiederholen',
                onPressed: busy || detecting || redo.isEmpty ? null : redoEdit,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: mode == 'crop'
                    ? (cropPreview ? 'Ecken bearbeiten' : 'Zuschnittvorschau')
                    : comparing
                    ? 'Bearbeitung anzeigen'
                    : 'Original vergleichen',
                isSelected: mode == 'crop' ? cropPreview : comparing,
                onPressed:
                    busy ||
                        detecting ||
                        mode == 'redact' ||
                        mode == 'crop' && preview == null
                    ? null
                    : () => setState(() {
                        if (mode == 'crop') {
                          cropPreview = !cropPreview;
                        } else {
                          comparing = !comparing;
                        }
                      }),
                icon: Icon(
                  mode == 'crop'
                      ? Icons.preview_outlined
                      : Icons.compare_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Drehen',
                onPressed: busy || detecting
                    ? null
                    : () => render(turns: 1, crop: mode == 'crop'),
                icon: const Icon(Icons.rotate_right),
              ),
              if (widget.photo)
                IconButton(
                  tooltip: 'Spiegeln',
                  onPressed: busy || detecting
                      ? null
                      : () => render(flip: true, crop: mode == 'crop'),
                  icon: const Icon(Icons.flip),
                ),
              IconButton(
                tooltip: 'Bild zurücksetzen',
                onPressed: busy || detecting
                    ? null
                    : () {
                        remember();
                        restore(
                          _ScanEditSnapshot(
                            bytes: widget.bytes,
                            width: widget.width,
                            height: widget.height,
                          ),
                        );
                      },
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
          if (mode == 'crop') ...[
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('scan-auto-edges'),
                  onPressed: busy || detecting ? null : detectEdges,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(detecting ? 'Erkennen …' : 'Kanten erkennen'),
                ),
                FilterChip(
                  label: const Text('Einrasten'),
                  selected: snapping,
                  onSelected: (v) => setState(() => snapping = v),
                ),
                IconButton(
                  tooltip: 'Zuschnitt anwenden',
                  onPressed: busy || detecting
                      ? null
                      : () => render(crop: true),
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
            if (detectionMessage != null) Text(detectionMessage!),
            if (snapped) const Text('An Kante eingerastet'),
            Text(
              widget.photo
                  ? 'Die Ecken für den Bildausschnitt ziehen.'
                  : 'Die vier Ecken an die Dokumentränder ziehen.',
            ),
          ],
          if (mode == 'redact') ...[
            const Text('Über die zu entfernenden Inhalte ein Rechteck ziehen.'),
            TextButton.icon(
              onPressed: busy || redactions.isEmpty
                  ? null
                  : () {
                      remember();
                      setState(() => redactions.removeLast());
                      schedulePreview();
                    },
              icon: const Icon(Icons.undo),
              label: const Text('Letzte Schwärzung zurück'),
            ),
          ],
          LayoutBuilder(
            builder: (ctx, constraints) {
              final aspect = currentWidth / currentHeight;
              final height = (constraints.maxWidth / aspect).clamp(
                1.0,
                MediaQuery.sizeOf(ctx).height *
                    (mode == 'filter' || mode == 'preview' ? .34 : .46),
              );
              final image = Image.memory(
                comparing
                    ? widget.bytes
                    : mode == 'crop' && !cropPreview
                    ? current
                    : preview ?? current,
                key: const ValueKey('scan-live-preview'),
                gaplessPlayback: true,
                fit: comparing || cropPreview ? BoxFit.contain : BoxFit.fill,
              );
              return Center(
                child: SizedBox(
                  width: height * aspect,
                  height: height,
                  child: mode == 'crop' || mode == 'redact'
                      ? cropPreview
                            ? image
                            : _imageOverlay(image, height * aspect)
                      : InteractiveViewer(
                          transformationController: zoom,
                          minScale: 1,
                          maxScale: 4,
                          child: _imageOverlay(image, height * aspect),
                        ),
                ),
              );
            },
          ),
          SizedBox(
            height: 20,
            child: Center(
              child: Text(
                comparing
                    ? 'Original'
                    : previewBusy
                    ? 'Vorschau …'
                    : mode == 'crop'
                    ? cropPreview
                          ? 'Zuschnittvorschau'
                          : 'Ecke ziehen · Lupe zur Feinkorrektur'
                    : mode == 'redact'
                    ? 'Schwärzung durch Ziehen markieren'
                    : 'Mit zwei Fingern vergrößern',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (mode == 'filter' || mode == 'preview') ...[
            const Text(
              'Filtervorschau',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ScanFilterStrip(
              thumbnails: thumbnails,
              selected: filter,
              onSelected: busy
                  ? null
                  : (value) {
                      if (filter == value) return;
                      remember();
                      setState(() {
                        filter = value;
                        comparing = false;
                      });
                      schedulePreview();
                    },
            ),
            adjustment(
              'Helligkeit',
              brightness,
              .5,
              1.5,
              (v) => brightness = v,
            ),
            adjustment('Kontrast', contrast, .5, 1.8, (v) => contrast = v),
            if (widget.photo)
              adjustment('Sättigung', saturation, 0, 2, (v) => saturation = v),
          ],
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          if (mode == 'redact')
            const Text(
              'Schwärzungen werden beim Übernehmen fest in die Seite eingerechnet.',
            ),
        ],
      ),
      footerContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final tool in [
                ('crop', 'Zuschneiden', Icons.crop),
                ('filter', 'Filter', Icons.tune),
                ('redact', 'Schwärzen', Icons.format_color_fill),
              ])
                ScanTool(
                  onPressed: busy || detecting
                      ? null
                      : () => selectTool(tool.$1),
                  icon: tool.$3,
                  selected:
                      mode == tool.$1 ||
                      mode == 'preview' && tool.$1 == 'filter',
                  label: tool.$2,
                ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy || detecting
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: busy || detecting
                    ? null
                    : () => render(crop: mode == 'crop', finish: true),
                child: const Text('Übernehmen'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _imageOverlay(Widget image, double width) => LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
        alignment: Alignment.center,
        children: [
          image,
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                // The outer image sizes itself to its intrinsic aspect ratio. The overlay
                // uses that exact box, so saved and drawn rectangles share coordinates.
                Offset point(Offset p) => Offset(
                  (p.dx / box.maxWidth).clamp(0, 1),
                  (p.dy / box.maxHeight).clamp(0, 1),
                );
                return GestureDetector(
                  key: const ValueKey('scan-page-canvas'),
                  dragStartBehavior: DragStartBehavior.down,
                  behavior: HitTestBehavior.opaque,
                  onPanStart:
                      busy || detecting || !{'crop', 'redact'}.contains(mode)
                      ? null
                      : (d) => setState(() {
                          start = point(d.localPosition);
                          end = start;
                          if (mode == 'crop') {
                            final distances = corners
                                .map(
                                  (p) => Offset(
                                    (p.dx - start!.dx) * box.maxWidth,
                                    (p.dy - start!.dy) * box.maxHeight,
                                  ).distanceSquared,
                                )
                                .toList();
                            final nearest = distances.reduce(
                              (a, b) => a < b ? a : b,
                            );
                            dragging = nearest <= 48 * 48
                                ? distances.indexOf(nearest)
                                : null;
                            if (dragging != null) remember();
                          }
                        }),
                  onPanUpdate:
                      busy || detecting || !{'crop', 'redact'}.contains(mode)
                      ? null
                      : (d) => setState(() {
                          end = point(d.localPosition);
                          snapped = false;
                          if (mode == 'crop' && snapping) {
                            final p = snapScanPoint(
                              [end!.dx, end!.dy],
                              detected.map((p) => [p.dx, p.dy]).toList(),
                              edges.map((p) => [p.dx, p.dy]).toList(),
                              box.maxWidth,
                              box.maxHeight,
                            );
                            snapped = p[0] != end!.dx || p[1] != end!.dy;
                            end = Offset(p[0], p[1]);
                          }
                          if (mode == 'crop' && dragging != null) {
                            corners = [...corners];
                            if (widget.photo) {
                              final opposite = corners[(dragging! + 2) % 4];
                              final rect = Rect.fromPoints(opposite, end!);
                              corners = [
                                rect.topLeft,
                                rect.topRight,
                                rect.bottomRight,
                                rect.bottomLeft,
                              ];
                              dragging =
                                  (end!.dx < opposite.dx ? 0 : 1) +
                                  (end!.dy < opposite.dy
                                      ? 0
                                      : (end!.dx < opposite.dx ? 3 : 1));
                            } else {
                              corners[dragging!] = end!;
                            }
                          }
                          if (mode == 'crop') schedulePreview();
                        }),
                  onPanCancel: () => setState(() {
                    start = end = null;
                    dragging = null;
                    snapped = false;
                  }),
                  onPanEnd:
                      busy || detecting || !{'crop', 'redact'}.contains(mode)
                      ? null
                      : (_) => setState(() {
                          if (mode == 'redact' &&
                              start != null &&
                              end != null) {
                            final rect = Rect.fromPoints(start!, end!);
                            if (rect.width > .005 && rect.height > .005) {
                              remember();
                              redactions.add(rect);
                              schedulePreview();
                            }
                          }
                          start = null;
                          end = null;
                          dragging = null;
                        }),
                  child: CustomPaint(
                    painter: _ScanOverlay(
                      corners: mode == 'crop' ? corners : null,
                      rects: [
                        ...redactions,
                        if (mode == 'redact' && start != null && end != null)
                          Rect.fromPoints(start!, end!),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (mode == 'crop' && dragging != null && end != null)
            Positioned(
              top: 8,
              left: end!.dx > .5 ? 8 : null,
              right: end!.dx > .5 ? null : 8,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('scan-crop-loupe'),
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        Positioned(
                          left: 52 - end!.dx * constraints.maxWidth * 2,
                          top: 52 - end!.dy * constraints.maxHeight * 2,
                          width: constraints.maxWidth * 2,
                          height: constraints.maxHeight * 2,
                          child: Image.memory(
                            current,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.add,
                            size: 24,
                            color: Colors.cyanAccent,
                          ),
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
}

class _ScanEditSnapshot {
  const _ScanEditSnapshot({
    required this.bytes,
    required this.width,
    required this.height,
    this.filter = 'color',
    this.brightness = 1,
    this.contrast = 1,
    this.saturation = 1,
    this.corners = const [
      Offset.zero,
      Offset(1, 0),
      Offset(1, 1),
      Offset(0, 1),
    ],
    this.redactions = const [],
    this.mode = 'filter',
  });
  final Uint8List bytes;
  final int width, height;
  final String filter, mode;
  final double brightness, contrast, saturation;
  final List<Offset> corners;
  final List<Rect> redactions;
}

class _ScanOverlay extends CustomPainter {
  const _ScanOverlay({required this.corners, required this.rects});
  final List<Offset>? corners;
  final List<Rect> rects;
  @override
  void paint(Canvas canvas, Size size) {
    for (final r in rects) {
      canvas.drawRect(
        Rect.fromLTRB(
          r.left * size.width,
          r.top * size.height,
          r.right * size.width,
          r.bottom * size.height,
        ),
        Paint()..color = Colors.black,
      );
    }
    if (corners != null) {
      final points = corners!
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addPolygon(points, true),
        Paint()..color = Colors.black.withValues(alpha: .48),
      );
      canvas.drawPath(
        Path()..addPolygon(points, true),
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (final p in points) {
        canvas.drawCircle(p, 10, Paint()..color = Colors.cyanAccent);
        canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScanOverlay oldDelegate) => true;
}
