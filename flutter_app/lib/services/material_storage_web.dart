import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import '../domain/models.dart';
import 'material_files.dart';

MaterialFiles createMaterialFiles() => _BrowserMaterials();

class _BrowserMaterials implements MaterialFiles {
  Future<Database>? _database;
  Future<Database> get database => _database ??= idbFactoryBrowser.open(
    'flex-material-files',
    version: 1,
    onUpgradeNeeded: (event) => event.database.createObjectStore('files'),
  );
  void check(String key) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(key)) {
      throw const DomainError('Ungültige Dateizuordnung.');
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    check(key);
    if (bytes.isEmpty || bytes.length > 20000000) {
      throw const DomainError('Datei zu groß.');
    }
    final tx = (await database).transaction('files', idbModeReadWrite);
    await Future.wait([tx.completed, tx.objectStore('files').put(bytes, key)]);
  }

  @override
  Future<Uint8List> read(String key) async {
    check(key);
    final tx = (await database).transaction('files', idbModeReadOnly);
    final results = await Future.wait([
      tx.completed,
      tx.objectStore('files').getObject(key),
    ]);
    final value = results[1];
    if (value is! Uint8List) {
      throw const DomainError(
        'Die lokale Datei fehlt. Bitte die vollständige Sicherung wiederherstellen.',
      );
    }
    return value;
  }

  @override
  Future<bool> exists(String key) async {
    if (key.isEmpty) return false;
    check(key);
    final tx = (await database).transaction('files', idbModeReadOnly);
    final results = await Future.wait([
      tx.completed,
      tx.objectStore('files').count(key),
    ]);
    return (results[1] as int) > 0;
  }

  @override
  Future<void> remove(String key) async {
    check(key);
    final tx = (await database).transaction('files', idbModeReadWrite);
    await Future.wait([tx.completed, tx.objectStore('files').delete(key)]);
  }
}
