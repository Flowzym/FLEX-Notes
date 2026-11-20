import 'package:uuid/uuid.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import '../domain/planning_import.dart';
import 'onedrive.dart';

String cloudExtension(String name) {
  final extension = name.toLowerCase().split('.').last;
  return extension == 'jpeg' ? 'jpg' : extension;
}

bool cloudLearningLink(String name) =>
    {'html', 'htm', 'url'}.contains(cloudExtension(name));
bool cloudFileSupported(String name) =>
    {'pdf', 'docx', 'jpg', 'png'}.contains(cloudExtension(name)) ||
    cloudLearningLink(name);

String driveFolderPath(ClassroomDocument folder) {
  final path = folder.text('folderPath');
  return path.isEmpty ? folder.title : path;
}

// Older folder links can start at "Materialien" or a single calendar week.
// Graph's parent path restores the year above that starting point.
String? _sourcePath(String driveId, Json item, String name, String? path) {
  final parent = item['parentReference'];
  if (parent is! Map ||
      parent['driveId'] != driveId ||
      parent['path'] is! String) {
    return path;
  }
  final location = parent['path'] as String;
  final root = location.indexOf('/root:');
  if (root < 0) return path;
  final parts = location
      .substring(root + '/root:'.length)
      .split('/')
      .where((s) => s.isNotEmpty);
  final String full;
  try {
    full = [...parts.map(Uri.decodeComponent), name].join('/');
  } on FormatException {
    return path;
  } on ArgumentError {
    return path;
  }
  return path == null ||
          (!isPlanningSourcePath(path) && isPlanningSourcePath(full))
      ? full
      : path;
}

/// Index a snapshot once while browsing or walking a folder tree. A detached
/// local edit keeps its ID, so the cloud original can reappear independently.
class OneDriveMaterialIndex {
  OneDriveMaterialIndex(Iterable<ClassroomDocument> existing) {
    for (final d in existing) {
      _documents[d.id] = d;
      if (d.kind == ClassroomKind.material &&
          d.text('driveId').isNotEmpty &&
          d.text('itemId').isNotEmpty) {
        _sources.putIfAbsent((d.text('driveId'), d.text('itemId')), () => d);
      }
    }
  }
  final _documents = <String, ClassroomDocument>{};
  final _sources = <(String, String), ClassroomDocument>{};
  bool available(String id) => _documents[id]?.deleted == false;
  String idFor(String driveId, String itemId) {
    final linked = _sources[(driveId, itemId)];
    if (linked != null) return linked.id;
    var id = const Uuid().v5(
      Namespace.url.value,
      'flex-onedrive:$driveId:$itemId',
    );
    for (var i = 0; i <= _documents.length; i++) {
      if (!_documents.containsKey(id)) return id;
      id = const Uuid().v5(
        Namespace.url.value,
        'flex-onedrive:$driveId:$itemId:after:$id',
      );
    }
    throw const DomainError(
      'Die OneDrive-Datei konnte nicht eindeutig zugeordnet werden.',
    );
  }

  ClassroomDocument material(
    String driveId,
    Json item, {
    String? path,
    bool restore = false,
  }) {
    final id = idFor(driveId, item['id'] as String);
    final old = _documents[id];
    final name = item['name'] as String;
    final title = name.length <= 160 ? name : name.substring(0, 160);
    final cached = old != null && old.text('localKey').isNotEmpty;
    final fields = <String, dynamic>{
      'driveId': driveId,
      'itemId': item['id'],
      'url': item['webUrl'] ?? old?.text('url') ?? '',
      'remoteName': name,
      if (item['createdDateTime'] is String)
        'remoteCreatedAt': item['createdDateTime'],
      'remoteEtag': item['eTag'] ?? '',
      'remoteModifiedAt': item['lastModifiedDateTime'] ?? '',
      'sourcePath': ?_sourcePath(driveId, item, name, path),
      if (cached && old.text('extension') == cloudExtension(name)) 'name': name,
      if (restore) 'deleted': false,
      if (!cached) ...{
        'name': name,
        'extension': cloudLearningLink(name) ? 'link' : cloudExtension(name),
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
}

String oneDriveMaterialId(
  String driveId,
  String itemId,
  Iterable<ClassroomDocument> existing,
) => OneDriveMaterialIndex(existing).idFor(driveId, itemId);

/// Read-only scan, bounded across the whole tree (not only per Graph page).
/// Identity is drive/item based, so moving or renaming a source keeps all links.
Future<List<ClassroomDocument>> scanMaterialFolder(
  OneDriveClient drive,
  ClassroomDocument folder,
  Iterable<ClassroomDocument> existing, {
  bool Function()? cancelled,
  void Function(int folders, int files)? progress,
  Set<String> boundaryFolders = const {},
  Set<String>? directFileIds,
  int maxFiles = 2000,
  int maxFolders = 250,
}) async {
  final materials = OneDriveMaterialIndex(existing);
  final queue = <({String id, String path})>[
    (id: folder.text('itemId'), path: driveFolderPath(folder)),
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
        if (!boundaryFolders.contains(itemId)) {
          queue.add((id: itemId, path: path));
        }
        continue;
      }
      if (!cloudFileSupported(name) || !seen.add(itemId)) continue;
      if (current.id == folder.text('itemId')) directFileIds?.add(itemId);
      if (result.length >= maxFiles) {
        throw const DomainError(
          'Bitte einen kleineren Unterordner wählen (höchstens 2000 Dateien).',
        );
      }
      result.add(materials.material(folder.text('driveId'), item, path: path));
    }
    progress?.call(visited.length, result.length);
  }
  result.sort((a, b) => a.text('sourcePath').compareTo(b.text('sourcePath')));
  return result;
}
