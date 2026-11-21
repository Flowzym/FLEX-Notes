import 'package:flutter/foundation.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'material_files.dart';
import 'material_index.dart';
import 'onedrive.dart';
import 'scan_store.dart';

Future<ClassroomDocument> cacheDriveMaterial(
  NotebookRepository repository,
  ClassroomDocument material,
  OneDriveClient drive,
  MaterialFiles files,
) async {
  if (material.text('extension') == 'link') {
    throw const DomainError(
      'Dieses Lernmedium wird online in OneDrive geöffnet.',
    );
  }
  if (material.text('itemId').isEmpty) {
    if (await files.exists(material.text('localKey'))) return material;
    throw const DomainError(
      'Für diesen Link bitte die Datei über die Dateiauswahl hinzufügen.',
    );
  }
  final info = await drive.item(
    material.text('driveId'),
    material.text('itemId'),
  );
  final exists = await files.exists(material.text('localKey'));
  final remoteName =
      info['name'] as String? ??
      material.text('remoteName', material.text('name'));
  final extension = remoteName.contains('.')
      ? cloudExtension(remoteName)
      : material.text('extension');
  if (exists &&
      material.text('etag').isNotEmpty &&
      material.text('etag') == info['eTag'] &&
      extension == material.text('extension')) {
    return material;
  }
  final bytes = await drive.download(info);
  try {
    validateMaterialBytes(bytes, extension);
  } on DomainError catch (error) {
    throw DomainError(
      '„$remoteName“ konnte nicht offline gespeichert werden. ${error.message}',
    );
  }
  final key = newId();
  late ClassroomDocument saved;
  try {
    await files.write(key, bytes);
    if (!listEquals(bytes, await files.read(key))) {
      throw const DomainError('Die Offlinekopie konnte nicht geprüft werden.');
    }
    saved = await repository.saveClassroomDocument(
      material.patch({
        'extension': extension,
        'name': remoteName,
        'remoteName': remoteName,
        'cachedAt': utcNow(),
        'cloudUpload': <String, dynamic>{},
        'remoteEtag': info['eTag'] ?? '',
        'remoteModifiedAt': info['lastModifiedDateTime'] ?? '',
        'localKey': key,
        'etag': info['eTag'] ?? '',
        'sourceModifiedAt': info['lastModifiedDateTime'] ?? utcNow(),
        'url': info['webUrl'] ?? material.text('url'),
        'size': bytes.length,
      }),
    );
  } catch (_) {
    try {
      await files.remove(key);
    } catch (_) {
      // Preserve the original failure when a staged download cannot be removed.
    }
    rethrow;
  }
  try {
    await removeUnusedScanFiles(repository, files, [material.text('localKey')]);
  } catch (_) {
    /* The new revision is already committed. */
  }
  return saved;
}
