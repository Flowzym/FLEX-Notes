import 'package:uuid/uuid.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import 'onedrive.dart';

/// A detached, edited copy keeps its identity and all its pupil/entry links.
/// Re-importing the cloud original must create/reuse a separate material.
String oneDriveMaterialId(
  String driveId,
  String itemId,
  Iterable<ClassroomDocument> existing,
) {
  final documents = {for (final d in existing) d.id: d};
  final linked = documents.values
      .where(
        (d) =>
            d.kind == ClassroomKind.material &&
            d.text('driveId') == driveId &&
            d.text('itemId') == itemId,
      )
      .firstOrNull;
  if (linked != null) return linked.id;
  var id = const Uuid().v5(
    Namespace.url.value,
    'flex-onedrive:$driveId:$itemId',
  );
  for (var i = 0; i <= documents.length; i++) {
    if (!documents.containsKey(id)) return id;
    id = const Uuid().v5(
      Namespace.url.value,
      'flex-onedrive:$driveId:$itemId:after:$id',
    );
  }
  throw const DomainError(
    'Die OneDrive-Datei konnte nicht eindeutig zugeordnet werden.',
  );
}

ClassroomDocument indexOneDriveFile(
  String driveId,
  Json item,
  Iterable<ClassroomDocument> existing, {
  String? path,
  bool restore = false,
}) {
  final id = oneDriveMaterialId(driveId, item['id'] as String, existing);
  final old = existing.where((d) => d.id == id).firstOrNull;
  final name = item['name'] as String;
  final title = name.length <= 160 ? name : name.substring(0, 160);
  final cached = old != null && old.text('localKey').isNotEmpty;
  final fields = <String, dynamic>{
    'driveId': driveId,
    'itemId': item['id'],
    'url': item['webUrl'] ?? old?.text('url') ?? '',
    'remoteName': name,
    'remoteEtag': item['eTag'] ?? '',
    'remoteModifiedAt': item['lastModifiedDateTime'] ?? '',
    'sourcePath': ?path,
    if (cached && old.text('extension') == name.split('.').last.toLowerCase())
      'name': name,
    if (restore) 'deleted': false,
    if (!cached) ...{
      'name': name,
      'extension': name.split('.').last.toLowerCase(),
      'size': item['size'] ?? 0,
      'sourceModifiedAt': item['lastModifiedDateTime'] ?? '',
    },
  };
  if (old == null) {
    return ClassroomDocument.create(ClassroomKind.material, title, {
      ...fields,
      ...suggestMaterialMetadata(name),
    }, id: id);
  }
  return old.patch({
    ...fields,
    if (old.title == old.text('remoteName', old.text('name'))) 'title': title,
  });
}

/// Read-only scan, bounded across the whole tree (not only per Graph page).
/// Identity is drive/item based, so moving or renaming a source keeps all links.
Future<List<ClassroomDocument>> scanMaterialFolder(
  OneDriveClient drive,
  ClassroomDocument folder,
  Iterable<ClassroomDocument> existing, {
  bool Function()? cancelled,
  void Function(int folders, int files)? progress,
  int maxFiles = 2000,
  int maxFolders = 250,
}) async {
  final old = {
    for (final d in existing.where((d) => d.kind == ClassroomKind.material))
      d.id: d,
  };
  final queue = <({String id, String path})>[
    (id: folder.text('itemId'), path: folder.title),
  ];
  final visited = <String>{}, seen = <String>{};
  final result = <ClassroomDocument>[];
  var count = 0;
  for (var index = 0; index < queue.length; index++) {
    if (cancelled?.call() == true) {
      throw const DomainError('Einlesen abgebrochen.');
    }
    final current = queue[index];
    if (!visited.add(current.id)) continue;
    if (visited.length > maxFolders) {
      throw const DomainError(
        'Bitte einen kleineren Unterordner wählen (höchstens 250 Ordner).',
      );
    }
    final items = await drive.children(
      drive: folder.text('driveId'),
      folder: current.id,
    );
    if (cancelled?.call() == true) {
      throw const DomainError('Einlesen abgebrochen.');
    }
    for (final item in items) {
      if (++count > 10000) {
        throw const DomainError('Bitte einen kleineren Unterordner wählen.');
      }
      final name = item['name'] as String? ?? '',
          itemId = item['id'] as String? ?? '';
      if (itemId.isEmpty || item['remoteItem'] != null) continue;
      final path = '${current.path}/$name';
      if (item['folder'] != null) {
        queue.add((id: itemId, path: path));
        continue;
      }
      final extension = name.split('.').last.toLowerCase();
      if (!{'pdf', 'docx'}.contains(extension) || !seen.add(itemId)) continue;
      if (result.length >= maxFiles) {
        throw const DomainError(
          'Bitte einen kleineren Unterordner wählen (höchstens 2000 Dateien).',
        );
      }
      result.add(
        indexOneDriveFile(folder.text('driveId'), item, old.values, path: path),
      );
    }
    progress?.call(visited.length, result.length);
  }
  result.sort((a, b) => a.text('sourcePath').compareTo(b.text('sourcePath')));
  return result;
}
