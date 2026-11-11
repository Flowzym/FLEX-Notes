import '../domain/classroom.dart';
import '../domain/material_versions.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'material_files.dart';
import 'scan_store.dart';

Future<void> changeMaterialVersion(
  NotebookRepository repository,
  MaterialFiles files,
  ClassroomDocument document,
  String id, {
  bool remove = false,
}) async {
  final versions = materialVersions(document.toJson());
  final selected = versions.where((v) => v['id'] == id).firstOrNull;
  if (selected == null || document.deleted) throw const StaleRevision();
  final remaining = versions.where((v) => v['id'] != id).toList();
  Json patch;
  if (remove) {
    patch = {'versions': remaining};
  } else {
    final bytes = await files.read(selected['localKey'] as String);
    validateMaterialBytes(bytes, selected['extension'] as String);
    patch = {
      for (final key in versionFileFields) key: selected[key],
      'versions': [
        materialVersionSnapshot(document.toJson()),
        ...remaining,
      ].take(materialVersionLimit).toList(),
      'url': '',
      'driveId': '',
      'itemId': '',
      'etag': '',
      'sourcePath': '',
    }..removeWhere((key, value) => value == null);
  }
  await repository.saveClassroomDocument(document.patch(patch));
  try {
    await removeUnusedScanFiles(
      repository,
      files,
      materialFileKeys(document.toJson()),
    );
  } catch (_) {
    /* The committed version remains valid if cleanup must retry. */
  }
}
