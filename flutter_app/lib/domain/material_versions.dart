import 'models.dart';

const materialVersionLimit = 5;
const versionFileFields = [
  'localKey',
  'extension',
  'size',
  'pageCount',
  'name',
];

List<Json> materialVersions(Json data) {
  final rows = data['versions'] ?? const [];
  if (rows is! List || rows.length > materialVersionLimit) {
    throw const DomainError('Ungültiger Dokumentverlauf.');
  }
  final result = <Json>[];
  for (final row in rows) {
    if (row is! Map) throw const DomainError('Ungültige Dokumentversion.');
    final v = Json.from(row);
    if (v['id'] is! String ||
        (v['id'] as String).isEmpty ||
        v['createdAtUtc'] is! String ||
        DateTime.tryParse(v['createdAtUtc'] as String) == null ||
        v['localKey'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(v['localKey'] as String) ||
        !{'pdf', 'jpg', 'docx'}.contains(v['extension']) ||
        v['size'] is! int ||
        v['size'] < 1 ||
        v['size'] > 20000000 ||
        v['name'] is! String ||
        (v['name'] as String).length > 250 ||
        v.keys.any(
          (k) => !{'id', 'createdAtUtc', ...versionFileFields}.contains(k),
        ) ||
        v['pageCount'] != null &&
            (v['pageCount'] is! int ||
                v['pageCount'] < 1 ||
                v['pageCount'] > 25)) {
      throw const DomainError('Ungültige Dokumentversion.');
    }
    result.add(v);
  }
  if (result.map((v) => v['id']).toSet().length != result.length ||
      result.map((v) => v['localKey']).toSet().length != result.length) {
    throw const DomainError('Doppelte Dokumentversion.');
  }
  return result;
}

Json materialVersionSnapshot(Json data) => {
  'id': newId(),
  'createdAtUtc': utcNow(),
  for (final key in versionFileFields)
    if (data[key] != null) key: data[key],
  'name': (data['name'] as String? ?? '').isEmpty
      ? '${data['title'] ?? 'Dokument'}.${data['extension']}'
      : data['name'],
};

Set<String> materialFileKeys(Json data) => {
  if (data['localKey'] is String && (data['localKey'] as String).isNotEmpty)
    data['localKey'] as String,
  for (final v in materialVersions(data)) v['localKey'] as String,
};

Set<String> scanFileKeys(Json data) => {
  for (final page in data['pages'] as List? ?? []) page['key'] as String,
  for (final page in (data['filterUndo'] as Map? ?? {}).values)
    page['key'] as String,
};
