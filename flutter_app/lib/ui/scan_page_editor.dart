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
  bool busy = false;
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
    previewTimer?.cancel();
    previewRevision++;
    sourceRevision++;
    super.dispose();
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
      if (mounted) setState(() => error = friendlyError(e));
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
  Future<void> render({
    int turns = 0,
    bool crop = false,
    bool finish = false,
    bool flip = false,
  }) async {
    if (busy || detecting) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      var result = await compute(editScanPixels, args(crop: crop));
      if (turns != 0 || flip) {
        result = await compute(editScanPixels, {
          'bytes': result['bytes'],
          'turns': turns,
          'flip': flip,
        });
      }
      if (!mounted) return;
      if (finish) {
        Navigator.pop(context, result);
        return;
      }
      setState(() {
        current = result['bytes'] as Uint8List;
        currentWidth = result['width'] as int;
        currentHeight = result['height'] as int;
        filter = 'color';
        brightness = 1;
        contrast = 1;
        saturation = 1;
        redactions.clear();
        corners = const [Offset.zero, Offset(1, 0), Offset(1, 1), Offset(0, 1)];
        mode = 'preview';
        preview = null;
        previewSource = null;
        detected = [];
        edges = [];
      });
      previewRevision++;
      await preparePreview();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FlexModal(
      maxWidth: 950,
      title: Text(
        '${widget.photo ? 'Foto' : 'Seite'} ${widget.pageNumber} bearbeiten',
      ),
      onClose: busy ? null : () => Navigator.pop(context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (busy) const LinearProgressIndicator(),
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
              ],
            ),
            if (detectionMessage != null) Text(detectionMessage!),
            if (snapped) const Text('An Kante eingerastet'),
            Text(
              widget.photo
                  ? 'Die Ecken für den Bildausschnitt ziehen.'
                  : 'Die vier Ecken an die Dokumentränder ziehen.',
            ),
            TextButton.icon(
              onPressed: busy || detecting ? null : () => render(crop: true),
              icon: const Icon(Icons.check),
              label: const Text('Zuschnitt anwenden'),
            ),
          ],
          if (mode == 'redact') ...[
            const Text('Über die zu entfernenden Inhalte ein Rechteck ziehen.'),
            TextButton.icon(
              onPressed: busy || redactions.isEmpty
                  ? null
                  : () => setState(() => redactions.removeLast()),
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
                    (mode == 'filter' || mode == 'preview' ? .42 : .52),
              );
              return Center(
                child: SizedBox(
                  width: height * aspect,
                  height: height,
                  child: _imageOverlay(
                    Image.memory(
                      mode == 'filter' || mode == 'preview'
                          ? preview ?? current
                          : current,
                      key: const ValueKey('scan-live-preview'),
                      gaplessPlayback: true,
                      fit: BoxFit.fill,
                    ),
                    height * aspect,
                  ),
                ),
              );
            },
          ),
          if (previewBusy)
            const Text('Vorschau …', style: TextStyle(fontSize: 12)),
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
                      setState(() => filter = value);
                      schedulePreview();
                    },
            ),
            Row(
              children: [
                const SizedBox(width: 95, child: Text('Helligkeit')),
                Expanded(
                  child: Slider(
                    value: brightness,
                    min: .5,
                    max: 1.5,
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() => brightness = v);
                            schedulePreview();
                          },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 95, child: Text('Kontrast')),
                Expanded(
                  child: Slider(
                    value: contrast,
                    min: .5,
                    max: 1.8,
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() => contrast = v);
                            schedulePreview();
                          },
                  ),
                ),
              ],
            ),
            if (widget.photo)
              Row(
                children: [
                  const SizedBox(width: 95, child: Text('Sättigung')),
                  Expanded(
                    child: Slider(
                      value: saturation,
                      min: 0,
                      max: 2,
                      onChanged: busy
                          ? null
                          : (v) {
                              setState(() => saturation = v);
                              schedulePreview();
                            },
                    ),
                  ),
                ],
              ),
            TextButton.icon(
              onPressed: busy ? null : () => render(),
              icon: const Icon(Icons.check),
              label: const Text('Filter anwenden'),
            ),
          ],
          const SizedBox(height: 8),
          if (mode == 'crop' && preview != null) ...[
            const Text('Zuschnittvorschau'),
            SizedBox(
              height: 140,
              child: Image.memory(
                preview!,
                gaplessPlayback: true,
                fit: BoxFit.contain,
              ),
            ),
          ],
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
                      : () async {
                          if (mode == 'crop' ||
                              redactions.isNotEmpty ||
                              filter != 'color' ||
                              brightness != 1 ||
                              contrast != 1 ||
                              saturation != 1) {
                            await render(crop: mode == 'crop');
                          }
                          if (mounted) {
                            setState(() {
                              mode = tool.$1;
                              start = null;
                              end = null;
                            });
                            if (mode == 'crop' &&
                                !widget.photo &&
                                edges.isEmpty) {
                              await detectEdges();
                            }
                            schedulePreview();
                          }
                        },
                  icon: tool.$3,
                  selected:
                      mode == tool.$1 ||
                      mode == 'preview' && tool.$1 == 'filter',
                  label: tool.$2,
                ),
              ScanTool(
                onPressed: busy || detecting
                    ? null
                    : () => render(turns: 1, crop: mode == 'crop'),
                icon: Icons.rotate_right,
                label: 'Drehen',
              ),
              if (widget.photo)
                ScanTool(
                  onPressed: busy || detecting
                      ? null
                      : () => render(flip: true, crop: mode == 'crop'),
                  icon: Icons.flip,
                  label: 'Spiegeln',
                ),
              ScanTool(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        current = widget.bytes;
                        currentWidth = widget.width;
                        currentHeight = widget.height;
                        redactions.clear();
                        filter = 'color';
                        brightness = 1;
                        contrast = 1;
                        saturation = 1;
                        corners = const [
                          Offset.zero,
                          Offset(1, 0),
                          Offset(1, 1),
                          Offset(0, 1),
                        ];
                        mode = 'preview';
                        preview = null;
                        previewSource = null;
                        previewRevision++;
                        previewTimer?.cancel();
                        detected = [];
                        edges = [];
                        preparePreview();
                      }),
                icon: Icons.undo,
                label: 'Zurücksetzen',
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
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
                  onPanStart: busy || !{'crop', 'redact'}.contains(mode)
                      ? null
                      : (d) => setState(() {
                          start = point(d.localPosition);
                          end = start;
                          if (mode == 'crop') {
                            final distances = corners
                                .map((p) => (p - start!).distanceSquared)
                                .toList();
                            dragging = distances.indexOf(
                              distances.reduce((a, b) => a < b ? a : b),
                            );
                          }
                        }),
                  onPanUpdate: busy || !{'crop', 'redact'}.contains(mode)
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
                  onPanEnd: busy || !{'crop', 'redact'}.contains(mode)
                      ? null
                      : (_) => setState(() {
                          if (mode == 'redact' &&
                              start != null &&
                              end != null) {
                            final rect = Rect.fromPoints(start!, end!);
                            if (rect.width > .005 && rect.height > .005) {
                              redactions.add(rect);
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
        ],
      );
    },
  );
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
