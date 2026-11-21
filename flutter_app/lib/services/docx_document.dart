part of 'docx_preview.dart';

String? _attr(XmlElement? node, String name) =>
    node?.attributes.where((a) => a.name.local == name).firstOrNull?.value;

XmlElement? _child(XmlElement? node, String name) =>
    node?.childElements.where((e) => e.name.local == name).firstOrNull;

class _DocxDocument {
  _DocxDocument(this.zip);
  final Archive zip;
  late final Map<String, String> relationships = imageRelationships();
  final pictures = <String, Uint8List?>{};
  int imageBytes = 0;

  Map<String, String> imageRelationships() {
    final file = zip.findFile('word/_rels/document.xml.rels');
    if (file == null) return {};
    final targets = <String, String>{};
    try {
      for (final rel in _docxXml(file).rootElement.childElements) {
        if (_attr(rel, 'TargetMode')?.toLowerCase() == 'external' ||
            _attr(rel, 'Type')?.endsWith('/image') != true) {
          continue;
        }
        final id = _attr(rel, 'Id'), target = _attr(rel, 'Target');
        if (id == null || target == null) continue;
        final uri = Uri.tryParse(target);
        if (uri == null ||
            uri.hasScheme ||
            uri.hasAuthority ||
            uri.hasQuery ||
            uri.hasFragment) {
          continue;
        }
        final path = Uri(path: '/word/document.xml').resolveUri(uri).path;
        if (path.startsWith('/word/media/')) targets[id] = path.substring(1);
      }
    } on FormatException {
      // Even without readable image references the document text is useful.
    } on XmlException {
      return {};
    }
    return targets;
  }

  Uint8List? picture(String? id) {
    final path = relationships[id];
    if (path == null || pictures.length >= 48 && !pictures.containsKey(path)) {
      return null;
    }
    if (pictures.containsKey(path)) return pictures[path];
    pictures[path] = null;
    final extension = path.toLowerCase().split('.').last;
    if (!{'png', 'jpeg', 'jpg'}.contains(extension)) return null;
    final file = zip.findFile(path);
    if (file == null ||
        file.size <= 0 ||
        file.size > 6000000 ||
        imageBytes + file.size > 16000000) {
      return null;
    }
    imageBytes += file.size;
    try {
      final output = _BoundedXmlOutput(file.size);
      file.writeContent(output);
      final data = output.getBytes();
      validateMaterialBytes(data, extension == 'jpeg' ? 'jpg' : extension);
      return pictures[path] = data;
    } catch (_) {
      return null;
    }
  }

  List<Json> blocks(XmlElement container, [int depth = 0]) {
    if (depth > 24) throw const FormatException();
    final result = <Json>[];
    for (final el in container.childElements) {
      switch (el.name.local) {
        case 'p':
          result.addAll(paragraph(el));
        case 'tbl':
          result.add(table(el, depth + 1));
        case 'sdt':
        case 'sdtContent':
        case 'customXml':
        case 'ins':
          result.addAll(blocks(el, depth + 1));
      }
    }
    return result;
  }

  List<Json> paragraph(XmlElement p) {
    final properties = _child(p, 'pPr');
    final style = (_attr(_child(properties, 'pStyle'), 'val') ?? '')
        .toLowerCase();
    final heading =
        RegExp('heading|überschrift|title|titel').hasMatch(style) ||
        _child(properties, 'outlineLvl') != null;
    final align = _attr(_child(properties, 'jc'), 'val');
    final out = <Json>[], runs = <Json>[];
    if (_child(properties, 'numPr') != null) runs.add({'text': '• '});
    void flush() {
      if (runs.isEmpty) return;
      out.add({
        'type': heading ? 'heading' : 'paragraph',
        'runs': List<Json>.of(runs),
        'align': align,
      });
      runs.clear();
    }

    void visit(XmlElement el, Json format, int depth) {
      if (depth > 64) throw const FormatException();
      switch (el.name.local) {
        case 'pPr':
        case 'rPr':
        case 'del':
        case 'moveFrom':
        case 'instrText':
          return;
        case 'r':
          final props = _child(el, 'rPr');
          format = {
            for (final name in ['b', 'i', 'u'])
              if (_child(props, name) case final prop?)
                name: !{
                  '0',
                  'false',
                  'off',
                  'none',
                }.contains(_attr(prop, 'val')),
          };
        case 't':
        case 'tab':
        case 'br':
        case 'cr':
          final value = switch (el.name.local) {
            't' => el.innerText,
            'tab' => '    ',
            _ => '\n',
          };
          runs.add({'text': value, ...format});
          return;
        case 'drawing':
        case 'pict':
          flush();
          final nodes = el.descendants.whereType<XmlElement>();
          final blip = nodes
              .where(
                (n) => n.name.local == 'blip' || n.name.local == 'imagedata',
              )
              .firstOrNull;
          final properties = nodes
              .where((n) => n.name.local == 'docPr')
              .firstOrNull;
          final bytes = picture(_attr(blip, 'embed') ?? _attr(blip, 'id'));
          final alt =
              _attr(properties, 'descr') ?? _attr(properties, 'title') ?? '';
          out.add(
            bytes == null
                ? {
                    'type': 'notice',
                    'text': alt.isEmpty ? 'Abbildung im Original öffnen' : alt,
                  }
                : {'type': 'image', 'bytes': bytes, 'alt': alt},
          );
          return;
        case 'AlternateContent':
          final choice = _child(el, 'Choice') ?? _child(el, 'Fallback');
          if (choice != null) visit(choice, format, depth + 1);
          return;
      }
      for (final child in el.childElements) {
        visit(child, format, depth + 1);
      }
    }

    visit(p, {}, 0);
    flush();
    return out;
  }

  Json table(XmlElement el, int depth) {
    final grid = [
      for (final column
          in _child(el, 'tblGrid')?.childElements ?? <XmlElement>[])
        if (column.name.local == 'gridCol')
          int.tryParse(_attr(column, 'w') ?? '') ?? 0,
    ];
    final rows = <List<Json>>[];
    final headerRows = <int>[];
    var columns = grid.length;
    for (final row in el.childElements.where((e) => e.name.local == 'tr')) {
      if (rows.length >= 500) throw const FormatException();
      final cells = <Json>[];
      final props = _child(row, 'trPr');
      if (_child(props, 'tblHeader') != null) headerRows.add(rows.length);
      var width = 0;
      for (final cell in row.childElements.where((e) => e.name.local == 'tc')) {
        final span =
            int.tryParse(
              _attr(_child(_child(cell, 'tcPr'), 'gridSpan'), 'val') ?? '',
            ) ??
            1;
        if (span < 1 || width + span > 30) throw const FormatException();
        width += span;
        cells.add({'span': span, 'blocks': blocks(cell, depth)});
      }
      if (width > columns) columns = width;
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (columns > 30) throw const FormatException();
    return {
      'type': 'table',
      'rows': rows,
      'columns': columns,
      'widths': grid,
      'headers': headerRows,
    };
  }
}
