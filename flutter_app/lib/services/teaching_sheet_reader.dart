import 'dart:convert';
import 'dart:typed_data';
import '../domain/models.dart';
import '../domain/teaching_sheet_data.dart';
import 'docx_preview.dart';

/// Parse Word's actual cells. A prose paragraph containing a clock or a name
/// is never enough to create a lesson or assign a pupil.
List<Json> readTeachingRows(Uint8List bytes) {
  final blocks = readDocxPreview(bytes, planningLayout: true);
  final result = <Json>[], counts = <String, int>{};
  var table = 0, paragraph = 0;
  void add(String line, List<String> cells, Json fields) {
    final raw = cells.join(' | ').trim();
    if (raw.isEmpty) return;
    if (raw.length > 12000 || result.length >= 500) {
      throw const DomainError(
        'Der Plan ist zu umfangreich. Bitte das Original prüfen.',
      );
    }
    final digest = sheetHash(jsonEncode(cells)),
        offset = counts.update(digest, (v) => v + 1, ifAbsent: () => 1);
    result.add({'id': '$digest-$offset', 'line': line, 'raw': raw, ...fields});
  }

  const headers = {
    'phase': 'phase',
    'unterrichtsphase': 'phase',
    'zeit': 'time',
    'uhrzeit': 'time',
    'auftrag': 'task',
    'arbeitsauftrag': 'task',
    'aufgabe': 'task',
    'aufgabe oder hilfe': 'task',
    'ziel': 'goal',
    'fach dauer': 'subject',
    'fach und dauer': 'subject',
    'fach': 'subject',
    'material': 'refs',
    'materialien': 'refs',
    'zustaendig': 'owner',
    'schueler': 'who',
    'schueler in': 'who',
    'schuelerinnen': 'who',
    'tag': 'day',
    'wochentag': 'day',
    'schwerpunkte': 'task',
    'schwerpunkt': 'task',
    'vorbereitung': 'prep',
    'fachbereiche': 'subject',
    'wochenziele': 'goal',
    'geplante einheiten und fachzeiten': 'time',
  };
  for (final block in blocks) {
    if (block['type'] != 'table') {
      final text = sheetText(block, 'text').trim();
      if (text.isNotEmpty) {
        add(
          'Absatz ${++paragraph}',
          [text],
          {'type': block['type'] == 'notice' ? 'review' : 'note', 'task': text},
        );
      }
      continue;
    }
    table++;
    var mapping = <int, String>{}, type = '', lastPhase = '';
    var index = 0;
    for (final r in block['rows'] as List) {
      index++;
      final cells = List<String>.from(r as List).map((s) => s.trim()).toList();
      if (cells.every((s) => s.isEmpty)) continue;
      final h = {
        for (var i = 0; i < cells.length; i++)
          if (headers.containsKey(sheetFold(cells[i])))
            i: headers[sheetFold(cells[i])]!,
      };
      final fields = h.values.toSet();
      final layout = fields.containsAll({'phase', 'who', 'task'})
          ? 'aid'
          : fields.containsAll({'phase', 'time', 'task'})
          ? 'phase'
          : fields.containsAll({'day', 'task'})
          ? 'week'
          : fields.containsAll({'subject', 'goal'})
          ? 'goal'
          : '';
      if (layout.isNotEmpty) {
        mapping = h;
        type = layout;
        lastPhase = '';
        continue;
      }
      final line = 'Tabelle $table · Zeile $index';
      if (type.isEmpty) {
        add(line, cells, {'type': 'review', 'task': cells.join(' · ')});
        continue;
      }
      final values = <String, dynamic>{'type': type};
      for (final entry in mapping.entries) {
        if (entry.key < cells.length && cells[entry.key].isNotEmpty) {
          values[entry.value] = cells[entry.key];
        }
      }
      if (type == 'aid' &&
          sheetText(values, 'phase').isEmpty &&
          lastPhase.isNotEmpty) {
        values['phase'] = lastPhase;
      }
      lastPhase = sheetText(values, 'phase');
      if (lastPhase.length > 160 ||
          type == 'phase' && lastPhase.isEmpty ||
          type == 'aid' &&
              (lastPhase.isEmpty || sheetText(values, 'who').isEmpty) ||
          type == 'week' && sheetWeekdays(sheetText(values, 'day')).isEmpty) {
        values['type'] = 'review';
        if (lastPhase.length > 160) values.remove('phase');
      }
      add(line, cells, values);
    }
  }
  return result;
}
