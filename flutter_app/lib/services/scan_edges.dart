import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'scan_images.dart';

/// Bounded, on-device Hough detection. Returns a suggested quadrilateral only
/// when all four edges have image evidence; an uncertain image stays uncropped.
Map<String, dynamic> detectScanEdges(Uint8List bytes) {
  final original = scanPixels(bytes);
  final image = img.gaussianBlur(
    img.copyResize(
      original,
      width: original.width >= original.height ? 360 : null,
      height: original.height > original.width ? 360 : null,
      interpolation: img.Interpolation.average,
    ),
    radius: 1,
  );
  final w = image.width, h = image.height;
  final gray = Float32List(w * h), strength = Float32List(w * h);
  for (final p in image) {
    gray[p.y * w + p.x] = p.luminance.toDouble();
  }
  final points = <(int, int, double, double)>[];
  for (var y = 2; y < h - 2; y++) {
    for (var x = 2; x < w - 2; x++) {
      final i = y * w + x;
      final gx =
          gray[i - w + 1] +
          2 * gray[i + 1] +
          gray[i + w + 1] -
          gray[i - w - 1] -
          2 * gray[i - 1] -
          gray[i + w - 1];
      final gy =
          gray[i + w - 1] +
          2 * gray[i + w] +
          gray[i + w + 1] -
          gray[i - w - 1] -
          2 * gray[i - w] -
          gray[i - w + 1];
      final magnitude = math.sqrt(gx * gx + gy * gy);
      strength[i] = magnitude;
      if (magnitude > 65) {
        points.add((x, y, gx, gy));
      }
    }
  }
  final diagonal = math.sqrt(w * w + h * h).ceil(), bins = 2 * diagonal + 1;
  final votes = Uint16List(180 * bins);
  final cos = List.generate(180, (a) => math.cos(a * math.pi / 180));
  final sin = List.generate(180, (a) => math.sin(a * math.pi / 180));
  for (final p in points) {
    final normal = (math.atan2(p.$4, p.$3) * 180 / math.pi).round();
    for (var da = -4; da <= 4; da += 2) {
      final a = (normal + da) % 180;
      final r = (p.$1 * cos[a] + p.$2 * sin[a]).round() + diagonal;
      for (var d = -1; d <= 1; d++) {
        if (r + d >= 0 && r + d < bins) {
          votes[a * bins + r + d]++;
        }
      }
    }
  }
  final peaks = <(int, int, int)>[];
  final threshold = math.max(16, math.min(w, h) * .16);
  for (var a = 0; a < 180; a++) {
    for (var r = 1; r < bins - 1; r++) {
      final v = votes[a * bins + r];
      if (v >= threshold &&
          v >= votes[a * bins + r - 1] &&
          v >= votes[a * bins + r + 1]) {
        peaks.add((a, r - diagonal, v));
      }
    }
  }
  peaks.sort((a, b) => b.$3.compareTo(a.$3));
  final lines = <(int, int, int)>[];
  for (final p in peaks) {
    if (lines.any((l) {
      final da = (p.$1 - l.$1).abs();
      return da < 8 && (p.$2 - l.$2).abs() < 12 ||
          da > 172 && (p.$2 + l.$2).abs() < 12;
    })) {
      continue;
    }
    lines.add(p);
    if (lines.length == 24) {
      break;
    }
  }
  double angle(int a, int b) {
    final d = (a - b).abs();
    return math.min(d, 180 - d).toDouble();
  }

  (double, double)? intersect((int, int, int) a, (int, int, int) b) {
    final det = cos[a.$1] * sin[b.$1] - sin[a.$1] * cos[b.$1];
    if (det.abs() < .2) {
      return null;
    }
    final x = (a.$2 * sin[b.$1] - b.$2 * sin[a.$1]) / det;
    final y = (cos[a.$1] * b.$2 - cos[b.$1] * a.$2) / det;
    if (x < -2 || y < -2 || x > w + 1 || y > h + 1) {
      return null;
    }
    return (x.clamp(0, w - 1).toDouble(), y.clamp(0, h - 1).toDouble());
  }

  final pairs = <(int, int)>[];
  for (var a = 0; a < lines.length; a++) {
    for (var b = a + 1; b < lines.length; b++) {
      if (angle(lines[a].$1, lines[b].$1) < 28) {
        pairs.add((a, b));
      }
    }
  }
  List<(double, double)>? best;
  var bestScore = 0.0;
  for (var i = 0; i < pairs.length; i++) {
    for (var j = i + 1; j < pairs.length; j++) {
      final a = pairs[i], b = pairs[j];
      if ({a.$1, a.$2, b.$1, b.$2}.length != 4 ||
          angle(lines[a.$1].$1, lines[b.$1].$1) < 48) {
        continue;
      }
      final corners = [
        intersect(lines[a.$1], lines[b.$1]),
        intersect(lines[a.$1], lines[b.$2]),
        intersect(lines[a.$2], lines[b.$2]),
        intersect(lines[a.$2], lines[b.$1]),
      ];
      if (corners.any((p) => p == null)) {
        continue;
      }
      final p = corners.cast<(double, double)>();
      final cx = p.fold(0.0, (s, p) => s + p.$1) / 4,
          cy = p.fold(0.0, (s, p) => s + p.$2) / 4;
      p.sort(
        (a, b) => math
            .atan2(a.$2 - cy, a.$1 - cx)
            .compareTo(math.atan2(b.$2 - cy, b.$1 - cx)),
      );
      var area = 0.0;
      for (var k = 0; k < 4; k++) {
        area += p[k].$1 * p[(k + 1) % 4].$2 - p[k].$2 * p[(k + 1) % 4].$1;
      }
      area = area.abs() / 2 / (w * h);
      if (area < .15 || area > .99) {
        continue;
      }
      var support = 0.0, weak = false;
      for (var k = 0; k < 4; k++) {
        final from = p[k], to = p[(k + 1) % 4];
        var hits = 0;
        for (var n = 0; n < 60; n++) {
          final t = (n + .5) / 60,
              x = (from.$1 + (to.$1 - from.$1) * t).round(),
              y = (from.$2 + (to.$2 - from.$2) * t).round();
          var hit = false;
          for (var dy = -2; dy <= 2; dy++) {
            for (var dx = -2; dx <= 2; dx++) {
              if (x + dx >= 0 &&
                  x + dx < w &&
                  y + dy >= 0 &&
                  y + dy < h &&
                  strength[(y + dy) * w + x + dx] > 65) {
                hit = true;
              }
            }
          }
          if (hit) {
            hits++;
          }
        }
        if (hits < 35) {
          weak = true;
          break;
        }
        support += hits / 240;
      }
      if (weak) {
        continue;
      }
      final score = area * support * support;
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
  }
  if (best != null) {
    var first = 0;
    for (var i = 1; i < 4; i++) {
      if (best[i].$1 + best[i].$2 < best[first].$1 + best[first].$2) {
        first = i;
      }
    }
    best = List.generate(4, (i) => best![(first + i) % 4]);
  }
  final stride = math.max(1, (points.length / 5000).ceil());
  return {
    'corners': best?.map((p) => [p.$1 / (w - 1), p.$2 / (h - 1)]).toList(),
    'edges': [
      for (var i = 0; i < points.length; i += stride)
        [points[i].$1 / (w - 1), points[i].$2 / (h - 1)],
    ],
  };
}

/// The threshold is in display pixels, not image pixels: snapping feels the
/// same on a phone and a tablet. Detected corners take priority over edge noise.
List<double> snapScanPoint(
  List<double> point,
  List<List<double>> corners,
  List<List<double>> edges,
  double width,
  double height, {
  double radius = 14,
}) {
  List<double>? closest(List<List<double>> values) {
    List<double>? best;
    var distance = radius * radius;
    for (final p in values) {
      final d =
          math.pow((p[0] - point[0]) * width, 2) +
          math.pow((p[1] - point[1]) * height, 2);
      if (d < distance) {
        distance = d.toDouble();
        best = p;
      }
    }
    return best;
  }

  return closest(corners) ?? closest(edges) ?? point;
}
