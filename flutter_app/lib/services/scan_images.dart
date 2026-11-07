import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models.dart';

/// Decode a bounded still image and remove EXIF/embedded thumbnails by copying
/// only pixels. All persisted scan pages have the same normalized orientation.
img.Image scanPixels(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 20000000) {
    throw const DomainError('Bitte ein Bild bis zu 20 MB wählen.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width * info.height > 40000000 ||
      info.numFrames > 1) {
    throw const DomainError(
      'Bitte ein einzelnes JPEG-, PNG- oder WebP-Bild bis 40 Megapixel wählen.',
    );
  }
  var decoded = decoder!.decodeFrame(0);
  if (decoded == null) {
    throw const DomainError('Das Bild konnte nicht geöffnet werden.');
  }
  decoded = img.bakeOrientation(decoded);
  if (math.max(decoded.width, decoded.height) > 2400) {
    decoded = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? 2400 : null,
      height: decoded.height > decoded.width ? 2400 : null,
      interpolation: img.Interpolation.average,
    );
  }
  final clean = img.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: 3,
  );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, decoded);
  return clean;
}

Map<String, dynamic> normalizeScan(Uint8List bytes) {
  final pixels = scanPixels(bytes);
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(pixels, quality: 92)),
    'width': pixels.width,
    'height': pixels.height,
  };
}

/// This same renderer feeds preview AND saved pages. Rectangles are burned into
/// pixels after all transforms; the PDF never contains source text or overlays.
Map<String, dynamic> editScanPixels(Map<String, dynamic> args) {
  var pixels = scanPixels(args['bytes'] as Uint8List);
  final maxSize = args['previewMax'] as int?;
  if (maxSize != null && math.max(pixels.width, pixels.height) > maxSize) {
    pixels = img.copyResize(
      pixels,
      width: pixels.width >= pixels.height ? maxSize : null,
      height: pixels.height > pixels.width ? maxSize : null,
      interpolation: img.Interpolation.average,
    );
  }
  final turns = args['turns'] as int? ?? 0;
  if (turns % 4 != 0) pixels = img.copyRotate(pixels, angle: (turns % 4) * 90);
  if (args['flip'] == true) pixels = img.flipHorizontal(pixels);
  final corners = args['corners'] as List?;
  if (corners != null) {
    if (corners.length != 4) {
      throw const DomainError('Bitte vier Dokumentecken wählen.');
    }
    final points = corners
        .map(
          (p) => img.Point(
            (p[0] as num).toDouble() * (pixels.width - 1),
            (p[1] as num).toDouble() * (pixels.height - 1),
          ),
        )
        .toList();
    double cross(img.Point a, img.Point b, img.Point c) =>
        ((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)).toDouble();
    if (corners.any(
          (p) => (p as List).any(
            (v) => v is! num || !v.isFinite || v < 0 || v > 1,
          ),
        ) ||
        List.generate(
          4,
          (i) => cross(points[i], points[(i + 1) % 4], points[(i + 2) % 4]),
        ).any((v) => v <= 0)) {
      throw const DomainError(
        'Die Dokumentecken dürfen sich nicht überkreuzen.',
      );
    }
    double distance(img.Point a, img.Point b) =>
        math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
    final w = math
        .max(distance(points[0], points[1]), distance(points[3], points[2]))
        .round()
        .clamp(16, 2400);
    final h = math
        .max(distance(points[0], points[3]), distance(points[1], points[2]))
        .round()
        .clamp(16, 2400);
    pixels = img.copyRectify(
      pixels,
      topLeft: points[0],
      topRight: points[1],
      bottomRight: points[2],
      bottomLeft: points[3],
      toImage: img.Image(width: w, height: h),
      interpolation: img.Interpolation.linear,
    );
  }
  final filter = args['filter'] as String? ?? 'color';
  final brightness = (args['brightness'] as num? ?? 1).toDouble().clamp(
    .5,
    1.5,
  );
  final contrast = (args['contrast'] as num? ?? 1).toDouble().clamp(.5, 1.8);
  if (filter == 'document') {
    // Stretch the paper/ink range without a binary threshold; colored markings
    // remain legible. The same renderer is used for preview and saved output.
    img.normalize(pixels, min: 0, max: 255);
  }
  if ({'gray', 'bw'}.contains(filter)) {
    img.grayscale(pixels);
  }
  img.adjustColor(
    pixels,
    brightness: brightness,
    contrast: filter == 'document' ? contrast * 1.15 : contrast,
    saturation: {'gray', 'bw'}.contains(filter)
        ? null
        : (args['saturation'] as num? ?? 1).clamp(0, 2),
  );
  if (filter == 'warm' || filter == 'cool') {
    for (final p in pixels) {
      final shift = filter == 'warm' ? 12 : -12;
      p.setRgb((p.r + shift).clamp(0, 255), p.g, (p.b - shift).clamp(0, 255));
    }
  }
  if (filter == 'bw') {
    for (final p in pixels) {
      final v = p.luminance > 160 ? 255 : 0;
      p.setRgb(v, v, v);
    }
  }
  for (final rect in args['redactions'] as List? ?? []) {
    final values = (rect as List).cast<num>();
    if (values.length != 4 ||
        values.any((v) => !v.isFinite || v < 0 || v > 1) ||
        values[2] <= values[0] ||
        values[3] <= values[1]) {
      throw const DomainError('Ungültige Schwärzung.');
    }
    img.fillRect(
      pixels,
      x1: (values[0] * pixels.width).floor(),
      y1: (values[1] * pixels.height).floor(),
      x2: (values[2] * pixels.width).ceil().clamp(0, pixels.width - 1),
      y2: (values[3] * pixels.height).ceil().clamp(0, pixels.height - 1),
      color: img.ColorRgb8(0, 0, 0),
    );
  }
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(pixels, quality: 92)),
    'width': pixels.width,
    'height': pixels.height,
  };
}

const scanFilters = {
  'color': 'Original',
  'document': 'Dokument',
  'gray': 'Graustufen',
  'bw': 'Schwarzweiß',
  'warm': 'Warm',
  'cool': 'Kühl',
};

Map<String, dynamic> scanPreviewBundle(Uint8List bytes) {
  final base =
      editScanPixels({'bytes': bytes, 'previewMax': 720})['bytes'] as Uint8List;
  return {
    'preview': base,
    'thumbnails': {
      for (final filter in scanFilters.keys)
        filter: editScanPixels({
          'bytes': base,
          'previewMax': 96,
          'filter': filter,
        })['bytes'],
    },
  };
}

Future<Uint8List> scanPdf(List<Uint8List> pages) async {
  if (pages.isEmpty || pages.length > 25) {
    throw const DomainError('Bitte 1 bis 25 Seiten hinzufügen.');
  }
  final pdf = pw.Document(creator: 'FLEX', producer: 'FLEX Dokumentenscanner');
  for (final page in pages) {
    final info = img.JpegDecoder().startDecode(page);
    if (info == null || info.width > 2400 || info.height > 2400) {
      throw const DomainError('Ungültige Scanseite.');
    }
    final image = pw.MemoryImage(page);
    final size = info.width > info.height
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;
    pdf.addPage(
      pw.Page(
        pageFormat: size,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  final bytes = await pdf.save();
  if (bytes.length > 20000000) {
    throw const DomainError(
      'Die PDF überschreitet 20 MB. Bitte weniger Seiten speichern.',
    );
  }
  return bytes;
}
