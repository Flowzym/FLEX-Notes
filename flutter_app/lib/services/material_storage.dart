import 'dart:typed_data';

import 'material_files.dart';
import 'material_thumbnails.dart';
import 'material_storage_io.dart'
    if (dart.library.js_interop) 'material_storage_web.dart'
    as platform;

/// Binary storage on this device; complete backups include referenced files.
class LocalMaterialFiles implements MaterialFiles {
  const LocalMaterialFiles();
  static final MaterialFiles _store = platform.createMaterialFiles();
  @override
  Future<void> write(String key, Uint8List bytes) async {
    await _store.write(key, bytes);
    materialThumbnails.invalidate(key);
  }

  @override
  Future<Uint8List> read(String key) => _store.read(key);
  @override
  Future<bool> exists(String key) =>
      key.isEmpty ? Future.value(false) : _store.exists(key);
  @override
  Future<void> remove(String key) async {
    await _store.remove(key);
    materialThumbnails.invalidate(key);
  }
}
