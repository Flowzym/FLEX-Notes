import 'dart:typed_data';

import 'material_files.dart';
import 'material_storage_io.dart'
    if (dart.library.js_interop) 'material_storage_web.dart'
    as platform;

/// Binary documents live outside the notebook backup, on the current device.
class LocalMaterialFiles implements MaterialFiles {
  const LocalMaterialFiles();
  static final MaterialFiles _store = platform.createMaterialFiles();
  @override
  Future<void> write(String key, Uint8List bytes) => _store.write(key, bytes);
  @override
  Future<Uint8List> read(String key) => _store.read(key);
  @override
  Future<bool> exists(String key) =>
      key.isEmpty ? Future.value(false) : _store.exists(key);
  @override
  Future<void> remove(String key) => _store.remove(key);
}
