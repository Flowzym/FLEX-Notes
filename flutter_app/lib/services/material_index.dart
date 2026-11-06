import 'package:uuid/uuid.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import 'onedrive.dart';

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
      final id = const Uuid().v5(
        Namespace.url.value,
        'flex-onedrive:${folder.text('driveId')}:$itemId',
      );
      final previous = old[id];
      final fields = <String, dynamic>{
        'name': name, 'driveId': folder.text('driveId'), 'itemId': itemId,
        'url': item['webUrl'] as String? ?? '', 'extension': extension,
        'sourcePath': path,
        // A cached copy's timestamp/size describe its bytes until refreshed.
        if (previous == null || previous.text('localKey').isEmpty) ...{
          'size': item['size'] as int? ?? 0,
          'sourceModifiedAt': item['lastModifiedDateTime'] as String? ?? '',
        },
      };
      final title = name.length <= 160 ? name : name.substring(0, 160);
      result.add(
        previous == null
            ? ClassroomDocument.create(ClassroomKind.material, title, {
                ...fields,
                ...suggestMaterialMetadata(name),
              }, id: id)
            : previous.patch({
                ...fields,
                if (previous.title == previous.text('name')) 'title': title,
              }),
      );
    }
    progress?.call(visited.length, result.length);
  }
  result.sort((a, b) => a.text('sourcePath').compareTo(b.text('sourcePath')));
  return result;
}
