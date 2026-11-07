import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';
import 'material_files.dart';

MaterialFiles createMaterialFiles() =>
    Platform.isAndroid ? const DeviceMaterialFiles() : _DiskMaterials();

class _DiskMaterials implements MaterialFiles {
  Future<File> file(String key) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(key)) {
      throw const DomainError('Ungültige Dateizuordnung.');
    }
    final root = await getApplicationSupportDirectory();
    final dir = await Directory(
      '${root.path}/materials',
    ).create(recursive: true);
    return File('${dir.path}/$key');
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 20000000) {
      throw const DomainError('Datei zu groß.');
    }
    final target = await file(key), temporary = await file('${newId()}-tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<Uint8List> read(String key) async {
    final target = await file(key);
    if (await target.length() > 20000000) {
      throw const DomainError('Datei zu groß.');
    }
    return target.readAsBytes();
  }

  @override
  Future<bool> exists(String key) async =>
      key.isNotEmpty && await (await file(key)).exists();
  @override
  Future<void> remove(String key) async {
    final target = await file(key);
    if (await target.exists()) await target.delete();
  }
}
