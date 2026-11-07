import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flex_notizbuch/services/scan_edges.dart';
import 'package:flex_notizbuch/services/scan_images.dart';

Uint8List perspectivePage({bool rotated = false}) {
  final image = img.Image(width: 480, height: 640);
  final corners = rotated
      ? [
          [.25, .08],
          [.91, .23],
          [.74, .93],
          [.07, .76],
        ]
      : [
          [.18, .11],
          [.86, .17],
          [.92, .87],
          [.09, .91],
        ];
  for (final pixel in image) {
    var inside = true;
    for (var i = 0; i < 4; i++) {
      final a = corners[i], b = corners[(i + 1) % 4];
      if ((b[0] - a[0]) * (pixel.y / 640 - a[1]) -
              (b[1] - a[1]) * (pixel.x / 480 - a[0]) <
          0) {
        inside = false;
      }
    }
    final value = inside ? 225 + pixel.x ~/ 48 : 35 + pixel.y ~/ 64;
    pixel.setRgb(value, value, value);
  }
  for (var y = 180; y <= 420; y += 35) {
    img.drawLine(
      image,
      x1: 130,
      y1: y,
      x2: 330,
      y2: y,
      color: img.ColorRgb8(60, 60, 60),
      thickness: 3,
    );
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  for (final rotated in [false, true]) {
    test(
      'detects perspective document despite text and uneven light, rotated=$rotated',
      () {
        final bytes = perspectivePage(rotated: rotated);
        final detection = detectScanEdges(bytes);
        final corners = detection['corners'] as List;
        final expected = rotated
            ? [
                [.25, .08],
                [.91, .23],
                [.74, .93],
                [.07, .76],
              ]
            : [
                [.18, .11],
                [.86, .17],
                [.92, .87],
                [.09, .91],
              ];
        expect(corners.length, 4);
        for (var i = 0; i < 4; i++) {
          for (var axis = 0; axis < 2; axis++) {
            expect(corners[i][axis], closeTo(expected[i][axis], .035));
          }
        }
        final cropped = editScanPixels({'bytes': bytes, 'corners': corners});
        expect(cropped['width'], lessThan(480));
        expect(cropped['height'], lessThan(640));
        final pixels = img.decodeJpg(cropped['bytes'] as Uint8List)!;
        expect(pixels.getPixel(pixels.width ~/ 2, 20).r, greaterThan(200));
        expect((detection['edges'] as List).length, lessThanOrEqualTo(5000));
      },
    );
  }
  test('blank and random noise never propose a document', () {
    final random = math.Random(47);
    for (final noise in [false, true]) {
      final image = img.Image(width: 360, height: 480);
      for (final p in image) {
        final v = noise ? random.nextInt(256) : 170;
        p.setRgb(v, v, v);
      }
      expect(
        detectScanEdges(Uint8List.fromList(img.encodeJpg(image)))['corners'],
        isNull,
        reason: 'noise=$noise',
      );
    }
  });
  test('snapping prioritizes corners and uses display pixels', () {
    final corners = [
          [.1, .2],
        ],
        edges = [
          [.12, .22],
        ];
    expect(snapScanPoint([.12, .22], corners, edges, 200, 300), corners.single);
    expect(snapScanPoint([.14, .23], [], edges, 200, 300), edges.single);
    expect(snapScanPoint([.14, .23], [], edges, 2000, 3000), [.14, .23]);
    expect(snapScanPoint([.5, .5], corners, edges, 200, 300), [.5, .5]);
  });
  test(
    'preview thumbnails cover every preset and preserve full export resolution',
    () {
      final bytes = perspectivePage();
      final bundle = scanPreviewBundle(bytes);
      final thumbs = bundle['thumbnails'] as Map;
      expect(thumbs.keys, scanFilters.keys);
      for (final f in scanFilters.keys) {
        final thumb = img.decodeJpg(thumbs[f] as Uint8List)!;
        expect(math.max(thumb.width, thumb.height), lessThanOrEqualTo(96));
        final full = editScanPixels({'bytes': bytes, 'filter': f});
        expect([full['width'], full['height']], [480, 640]);
      }
    },
  );
}
