import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import '../domain/models.dart';
import 'docx_preview.dart';
import 'material_files.dart';
import 'onedrive.dart';

class DocumentThumbnail {
  const DocumentThumbnail({this.image, this.text, this.unavailable = false});
  final Uint8List? image;
  final String? text;
  final bool unavailable;
}

Uint8List thumbnailImage(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width * info.height > 40000000) {
    throw const DomainError('Vorschau nicht verfügbar.');
  }
  final image = img.bakeOrientation(decoder!.decodeFrame(0)!);
  final small = img.copyResize(
    image,
    width: image.width >= image.height ? 240 : null,
    height: image.height > image.width ? 240 : null,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(small, quality: 82));
}

Future<DocumentThumbnail> renderDocumentThumbnail(
  Uint8List bytes,
  String extension,
) async {
  validateMaterialBytes(bytes, extension);
  if (extension == 'jpg') {
    return DocumentThumbnail(image: await compute(thumbnailImage, bytes));
  }
  if (extension == 'docx') {
    final blocks = await compute(readDocxPreview, bytes);
    final text = blocks
        .map(
          (b) =>
              b['text'] ??
              (b['rows'] as List? ?? [])
                  .map((r) => (r as List).join(' · '))
                  .join('\n'),
        )
        .join('\n');
    return DocumentThumbnail(
      text: text.length > 600 ? text.substring(0, 600) : text,
    );
  }
  await pdfrxFlutterInitialize();
  final pdf = await PdfDocument.openData(
    bytes,
    passwordProvider: () async => null,
  );
  try {
    if (pdf.pages.isEmpty) throw const DomainError('Leeres PDF.');
    final page = pdf.pages.first;
    if (page.width <= 0 || page.height <= 0) {
      throw const DomainError('Ungültige PDF-Seite.');
    }
    final scale = 240 / math.max(page.width, page.height);
    final raster = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xffffffff,
    );
    if (raster == null) throw const DomainError('Vorschau nicht verfügbar.');
    try {
      final pixels = img.Image.fromBytes(
        width: raster.width,
        height: raster.height,
        bytes: raster.pixels.buffer,
        bytesOffset: raster.pixels.offsetInBytes,
        order: img.ChannelOrder.bgra,
      );
      return DocumentThumbnail(
        image: Uint8List.fromList(img.encodeJpg(pixels, quality: 82)),
      );
    } finally {
      raster.dispose();
    }
  } finally {
    await pdf.dispose();
  }
}

/// Memory-only previews: no extra copy of a redacted document is persisted.
/// Limit concurrent file/PDF work and cache only small results, never originals.
class MaterialThumbnailCache {
  final _cache = <String, Future<DocumentThumbnail>>{};
  final _versions = <String, int>{};
  final _waiting = Queue<Completer<void>>();
  int _active = 0;
  int version(String key) => _versions[key] ?? 0;
  void invalidate(String key) {
    _versions[key] = version(key) + 1;
    _cache.clear();
  }

  void clear() => _cache.clear();
  Future<DocumentThumbnail> load({
    required String identity,
    required MaterialFiles files,
    required String fileKey,
    required String extension,
    String driveId = '',
    String itemId = '',
    Future<Uint8List?> Function()? remoteLoader,
  }) {
    final key = '${identityHashCode(files)}:$identity:${version(fileKey)}';
    final existing = _cache.remove(key);
    if (existing != null) {
      _cache[key] = existing;
      return existing;
    }
    final future = _run(() async {
      if (fileKey.isNotEmpty && await files.exists(fileKey)) {
        return renderDocumentThumbnail(await files.read(fileKey), extension);
      }
      if (driveId.isNotEmpty && itemId.isNotEmpty) {
        final OneDriveClient? drive = remoteLoader == null
            ? OneDriveClient()
            : null;
        try {
          Uint8List? bytes;
          if (remoteLoader != null) {
            bytes = await remoteLoader();
          } else {
            await drive!.load();
            if (drive.connected) bytes = await drive.thumbnail(driveId, itemId);
          }
          if (bytes != null) {
            return DocumentThumbnail(
              image: await compute(thumbnailImage, bytes),
            );
          }
        } finally {
          drive?.dispose();
        }
      }
      return const DocumentThumbnail(unavailable: true);
    });
    _cache[key] = future;
    while (_cache.length > 64) {
      _cache.remove(_cache.keys.first);
    }
    // Missing/offline previews can be retried after reconnect or restoring files.
    unawaited(
      future.then((value) {
        if (value.unavailable && identical(_cache[key], future)) {
          _cache.remove(key);
        }
      }),
    );
    return future;
  }

  Future<DocumentThumbnail> _run(
    Future<DocumentThumbnail> Function() load,
  ) async {
    if (_active >= 2) {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _active++;
    }
    try {
      return await load();
    } catch (_) {
      return const DocumentThumbnail(unavailable: true);
    } finally {
      if (_waiting.isEmpty) {
        _active--;
      } else {
        _waiting.removeFirst().complete();
      }
    }
  }
}

final materialThumbnails = MaterialThumbnailCache();
