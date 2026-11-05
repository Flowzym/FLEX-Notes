import 'dart:convert';
import 'models.dart';

/// Canonical equality ignores JSON key and database row ordering.
String canonical(Object? value) {
  Object? sorted(Object? v) {
    if (v is Map) {
      return {
        for (final k in v.keys.map((k) => k.toString()).toList()..sort())
          k: sorted(v[k]),
      };
    }
    if (v is List) return v.map(sorted).toList();
    return v;
  }

  return jsonEncode(sorted(value));
}

const mergeIdentityFields = {
  'id',
  'revision',
  'createdAtUtc',
  'updatedAtUtc',
  'situationId',
  'pupilId',
  'generated',
};

class MergeItem {
  MergeItem({
    required this.kind,
    required this.id,
    required this.label,
    required this.incoming,
    this.local,
  });
  final String kind, id, label;
  final Json incoming;
  final Json? local;
  String get key => '$kind:$id';
  bool get isNew => local == null;
  List<String> get differences => incoming.keys
      .where(
        (key) =>
            !mergeIdentityFields.contains(key) &&
            canonical(incoming[key]) != canonical(local?[key]),
      )
      .toList();
  bool get identical => !isNew && differences.isEmpty;
  Json resolve(Set<String> fields) => local == null
      ? Json.from(incoming)
      : {
          ...local!,
          for (final field in differences.where(fields.contains))
            field: incoming[field],
        };
}

class BackupMergePlan {
  BackupMergePlan({
    required this.original,
    required this.localStamp,
    required this.items,
    required this.pupilLinks,
    required this.sameNames,
    required this.draftCount,
    this.catalogs = true,
  });
  final String original, localStamp;
  final List<MergeItem> items;
  final Map<String, String> pupilLinks;
  final Map<String, List<Pupil>> sameNames;
  final int draftCount;
  final bool catalogs;
  int get newCount => items.where((i) => i.isNew).length;
  int get duplicates => items.where((i) => i.identical).length;
  int get conflicts => items.where((i) => !i.isNew && !i.identical).length;
}

abstract interface class BackupMergeRepository {
  Future<BackupMergePlan> prepareBackupMerge(
    String text, {
    Map<String, String> pupilLinks = const {},
    bool catalogs = true,
  });
  Future<void> applyBackupMerge(
    BackupMergePlan plan,
    Map<String, Set<String>> incomingFields,
  );
  Future<List<Json>> importArchives();
  Future<String> importArchive(String id);
}
