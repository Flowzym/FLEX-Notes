import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../domain/models.dart';
import 'material_files.dart';

part 'docx_document.dart';

class _BoundedXmlOutput extends OutputMemoryStream {
  static const limit = 2000000;
  _BoundedXmlOutput([this.maximum = limit]);
  final int maximum;
  void check(int extra) {
    if (length + extra > maximum) {
      throw const FormatException('Document too large');
    }
  }

  @override
  void writeByte(int value) {
    check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    check(count);
    super.writeBackReference(distance, count);
  }

  @override
  void reserve(int total) {
    if (total > maximum) throw const FormatException('Document too large');
    super.reserve(total);
  }
}

/// Content preview only. No HTML, remote relationships, macros or external XML
/// entities are executed. The original stays available for Word layout/printing.
List<Json> readDocxPreview(Uint8List bytes, {bool planningLayout = false}) =>
    _readDocx(bytes, planningLayout: planningLayout);

/// Rich blocks for the on-screen document, including local embedded pictures.
List<Json> readDocxDocument(Uint8List bytes) => _readDocx(bytes, rich: true);

/// Word can store a raster preview of the first page in the package.
Uint8List? readDocxCover(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  for (final ext in ['jpeg', 'png', 'jpg']) {
    final file = zip.findFile('docProps/thumbnail.$ext');
    if (file == null || file.size <= 0 || file.size > 2000000) continue;
    try {
      final out = _BoundedXmlOutput(file.size);
      file.writeContent(out);
      final image = out.getBytes();
      validateMaterialBytes(image, ext == 'jpeg' ? 'jpg' : ext);
      return image;
    } catch (_) {
      continue;
    }
  }
  return null;
}

XmlDocument _docxXml(ArchiveFile file) {
  if (file.size > _BoundedXmlOutput.limit) throw const FormatException();
  final out = _BoundedXmlOutput();
  file.writeContent(out);
  final source = utf8.decode(out.getBytes());
  if (source.contains(RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false))) {
    throw const FormatException();
  }
  return XmlDocument.parse(source);
}

List<Json> _readDocx(
  Uint8List bytes, {
  bool planningLayout = false,
  bool rich = false,
}) {
  try {
    validateMaterialBytes(bytes, 'docx');
    final zip = ZipDecoder().decodeBytes(bytes);
    final doc = zip.findFile('word/document.xml');
    if (doc == null) throw const FormatException();
    final xml = _docxXml(doc);
    final body = xml.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'body')
        .firstOrNull;
    if (body == null) throw const FormatException();
    final nodes = body.descendants.whereType<XmlElement>().toList();
    if (nodes.length > 50000) throw const FormatException();
    if (rich) return _DocxDocument(zip).blocks(body);
    String text(XmlElement p) {
      final buffer = StringBuffer();
      for (final e in p.descendants.whereType<XmlElement>()) {
        if (e.ancestors.whereType<XmlElement>().any(
          (a) => a.name.local == 'del',
        )) {
          continue;
        }
        switch (e.name.local) {
          case 't':
            buffer.write(e.innerText);
          case 'tab':
            buffer.write('  ');
          case 'br':
          case 'cr':
            buffer.write('\n');
        }
      }
      return buffer.toString();
    }

    final result = <Json>[];
    for (final e in body.childElements) {
      if (e.name.local == 'p') {
        final value = text(e);
        final props = e.descendants.whereType<XmlElement>();
        final style =
            props
                .where((p) => p.name.local == 'pStyle')
                .firstOrNull
                ?.attributes
                .where((a) => a.name.local == 'val')
                .firstOrNull
                ?.value ??
            '';
        final list = props.any((p) => p.name.local == 'numPr');
        if (value.trim().isNotEmpty) {
          result.add({
            'type':
                style.toLowerCase().contains(
                  RegExp('heading|überschrift|title'),
                )
                ? 'heading'
                : 'paragraph',
            'text': '${list ? '• ' : ''}$value',
          });
        }
        if (props.any(
          (p) => p.name.local == 'drawing' || p.name.local == 'pict',
        )) {
          result.add({
            'type': 'notice',
            'text': '[Abbildung – im Original öffnen]',
          });
        }
      } else if (e.name.local == 'tbl') {
        final rows = <List<String>>[];
        final vertical = <int, String>{};
        for (final row in e.childElements.where((r) => r.name.local == 'tr')) {
          final cells = <String>[];
          for (final cell in row.childElements.where(
            (c) => c.name.local == 'tc',
          )) {
            final col = cells.length;
            var value = cell.descendants
                .whereType<XmlElement>()
                .where((p) => p.name.local == 'p')
                .map(text)
                .join('\\n');
            int span = 1;
            if (planningLayout) {
              final properties = cell.childElements
                  .where((x) => x.name.local == 'tcPr')
                  .firstOrNull;
              final merge = properties?.childElements
                  .where((x) => x.name.local == 'vMerge')
                  .firstOrNull;
              final spanNode = properties?.childElements
                  .where((x) => x.name.local == 'gridSpan')
                  .firstOrNull;
              String? val(XmlElement? n) => n?.attributes
                  .where((a) => a.name.local == 'val')
                  .firstOrNull
                  ?.value;
              span = int.tryParse(val(spanNode) ?? '1') ?? 1;
              if (span < 1 || span > 30 || col + span > 30) {
                throw const FormatException();
              }
              if (merge == null) {
                vertical.remove(col);
              } else if (val(merge) == 'restart') {
                vertical[col] = value;
              } else if (value.trim().isEmpty) {
                value = vertical[col] ?? '';
              }
            }
            cells.add(value);
            cells.addAll(List.filled(span - 1, ''));
          }
          rows.add(cells);
        }
        if (rows.length > 500 || rows.any((r) => r.length > 30)) {
          throw const FormatException();
        }
        result.add({'type': 'table', 'rows': rows});
      }
      if (result.length > 3000) throw const FormatException();
    }
    if (result.isEmpty) {
      result.add({
        'type': 'notice',
        'text': 'Kein darstellbarer Text. Bitte das Original öffnen.',
      });
    }
    return result;
  } catch (_) {
    throw const DomainError(
      'Diese DOCX-Datei kann nicht als Textvorschau dargestellt werden. Bitte das Original öffnen.',
    );
  }
}
