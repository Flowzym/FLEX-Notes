import 'dart:convert';
import 'models.dart';

/// Compare user content, not generated IDs, empty task rows or open UI sections.
/// The initial signature is kept in the draft so a restart preserves this rule.
String draftSignature(Object? value) => jsonEncode(_content(value));
Object? _content(Object? value) {
  if (value is String) return value.trim().isEmpty ? null : value.trim();
  if (value == null || value == false) return null;
  if (value is List) {
    final list = <Object?>[];
    for (final item in value) {
      if (item is Map &&
          item.containsKey('text') &&
          (item['text'] as String? ?? '').trim().isEmpty) {
        continue;
      }
      final cleaned = _content(item);
      if (cleaned != null) list.add(cleaned);
    }
    return list.isEmpty ? null : list;
  }
  if (value is Map) {
    final map = <String, Object?>{};
    final isDocumentLink =
        {'orga', 'school', 'classroom', 'lesson'}.contains(value['kind']) &&
        value.keys.every(
          (key) => {'kind', 'id', 'date', 'taskId'}.contains(key),
        );
    for (final key in value.keys.cast<String>().toList()..sort()) {
      if (key == 'id' && isDocumentLink) {
        map[key] = value[key];
        continue;
      }
      if (const {
        'id',
        'revision',
        'editRevision',
        'createdAtUtc',
        'updatedAtUtc',
        'tone',
        '_sections',
      }.contains(key)) {
        continue;
      }
      final cleaned = _content(value[key]);
      if (cleaned != null) map[key] = cleaned;
    }
    return map.isEmpty ? null : map;
  }
  return value;
}

String dialogDraftSignature(String type, Json data) => draftSignature({
  for (final entry in data.entries)
    if (!const {
          'addError',
          'focusTaskId',
          'reminderOpen',
        }.contains(entry.key) &&
        !entry.key.startsWith('append-') &&
        !(type == 'bulk' && entry.key == 'kind'))
      entry.key: entry.value,
});
