import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/scan_images.dart';
import 'common.dart';
import 'flex_modal.dart';

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
  String mode = 'preview', filter = 'color';
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
    if (busy) return;
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
      });
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tool in [
                ('crop', 'Zuschneiden', Icons.crop),
                ('filter', 'Filter', Icons.tune),
                ('redact', 'Schwärzen', Icons.format_color_fill),
              ])
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          if (redactions.isNotEmpty ||
                              filter != 'color' ||
                              brightness != 1 ||
                              contrast != 1 ||
                              saturation != 1) {
                            await render();
                          }
                          if (mounted) {
                            setState(() {
                              mode = tool.$1;
                              start = null;
                              end = null;
                            });
                          }
                        },
                  icon: Icon(tool.$3),
                  label: Text(tool.$2),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => render(turns: 1),
                icon: const Icon(Icons.rotate_right),
                label: const Text('Drehen'),
              ),
              if (widget.photo)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => render(flip: true),
                  icon: const Icon(Icons.flip),
                  label: const Text('Spiegeln'),
                ),
              TextButton.icon(
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
                      }),
                icon: const Icon(Icons.undo),
                label: const Text('Zurücksetzen'),
              ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (busy) const LinearProgressIndicator(),
          if (mode == 'crop') ...[
            Text(
              widget.photo
                  ? 'Die Ecken für den Bildausschnitt ziehen.'
                  : 'Die vier Ecken an die Dokumentränder ziehen.',
            ),
            TextButton.icon(
              onPressed: busy ? null : () => render(crop: true),
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
          if (mode == 'filter') ...[
            Wrap(
              spacing: 6,
              children: [
                for (final f
                    in widget.photo
                        ? [
                            ('color', 'Original'),
                            ('warm', 'Warm'),
                            ('cool', 'Kühl'),
                            ('gray', 'Schwarzweiß'),
                          ]
                        : [
                            ('color', 'Farbe'),
                            ('gray', 'Graustufen'),
                            ('bw', 'Schwarzweiß'),
                          ])
                  ChoiceChip(
                    label: Text(f.$2),
                    selected: filter == f.$1,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => filter = f.$1),
                  ),
              ],
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
                        : (v) => setState(() => brightness = v),
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
                        : (v) => setState(() => contrast = v),
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
                          : (v) => setState(() => saturation = v),
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
          LayoutBuilder(
            builder: (ctx, constraints) {
              final aspect = currentWidth / currentHeight;
              final height = (constraints.maxWidth / aspect).clamp(
                1.0,
                MediaQuery.sizeOf(ctx).height * .55,
              );
              return Center(
                child: SizedBox(
                  width: height * aspect,
                  height: height,
                  child: _imageOverlay(
                    Image.memory(current, fit: BoxFit.fill),
                    height * aspect,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Schwärzungen werden beim Übernehmen fest in die Seite eingerechnet.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => render(crop: mode == 'crop', finish: true),
          child: const Text('Übernehmen'),
        ),
      ],
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
