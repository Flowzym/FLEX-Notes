import 'models.dart';

String cleanMaterialTag(String value) => value
    .trim()
    .replaceFirst(RegExp(r'^#+'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

String materialTagKey(String value) => cleanMaterialTag(value).toLowerCase();

List<String> normalizeMaterialTags(Iterable<String> values) {
  final tags = <String, String>{};
  for (final value in values) {
    final clean = cleanMaterialTag(value);
    if (clean.isNotEmpty) tags.putIfAbsent(materialTagKey(clean), () => clean);
  }
  return tags.values.toList();
}

String checkedMaterialTag(String value) {
  final tag = cleanMaterialTag(value);
  if (tag.isEmpty || tag.length > 64 || tag.contains(',')) {
    throw const DomainError(
      'Bitte einen Tag mit 1–64 Zeichen ohne Komma eingeben.',
    );
  }
  return tag;
}

enum TagChange { add, remove, replace }

List<String> changeMaterialTags(
  Iterable<String> existing,
  Iterable<String> selected,
  TagChange mode,
) {
  final tags = normalizeMaterialTags(selected);
  final keys = tags.map(materialTagKey).toSet();
  final result = normalizeMaterialTags(switch (mode) {
    TagChange.add => [...existing, ...tags],
    TagChange.remove => existing.where(
      (t) => !keys.contains(materialTagKey(t)),
    ),
    TagChange.replace => tags,
  });
  if (mode != TagChange.remove && result.length > 30) {
    throw const DomainError('Bitte höchstens 30 Tags pro Datei verwenden.');
  }
  return result;
}

bool matchesMaterialTags(Iterable<String> actual, Iterable<String> selected) =>
    actual
        .map(materialTagKey)
        .toSet()
        .containsAll(selected.map(materialTagKey));
