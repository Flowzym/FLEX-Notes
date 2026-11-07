import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;

import '../domain/models.dart';

Uint8List _encodePdfPage(Map<String, dynamic> p) => Uint8List.fromList(
  img.encodeJpg(
    img.Image.fromBytes(
      width: p['width'] as int,
      height: p['height'] as int,
      bytes: (p['pixels'] as Uint8List).buffer,
      order: img.ChannelOrder.bgra,
    ),
    quality: 92,
  ),
);

/// Rasterization deliberately excludes the original PDF's text, attachments,
/// metadata and actions. Only the visible page enters the scanner editor.
Stream<Uint8List> importPdfPages(Uint8List bytes, {required int limit}) async* {
  if (bytes.isEmpty || bytes.length > 20000000) {
    throw const DomainError('Bitte eine PDF bis zu 20 MB wählen.');
  }
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openData(
    bytes,
    passwordProvider: () async => null,
  );
  try {
    if (document.pages.isEmpty || document.pages.length > limit) {
      throw DomainError(
        'Es sind noch $limit Seiten möglich. Bitte eine kleinere PDF wählen.',
      );
    }
    for (final page in document.pages) {
      if (page.width <= 0 || page.height <= 0) {
        throw const DomainError('Ungültige PDF-Seite.');
      }
      final factor = 2400 / math.max(page.width, page.height);
      final rendered = await page.render(
        fullWidth: page.width * factor,
        fullHeight: page.height * factor,
        backgroundColor: 0xffffffff,
      );
      if (rendered == null) {
        throw const DomainError('Die PDF-Seite konnte nicht gelesen werden.');
      }
      try {
        yield await compute(_encodePdfPage, {
          'pixels': Uint8List.fromList(rendered.pixels),
          'width': rendered.width,
          'height': rendered.height,
        });
      } finally {
        rendered.dispose();
      }
    }
  } finally {
    await document.dispose();
  }
}
