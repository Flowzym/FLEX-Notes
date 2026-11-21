import 'dart:io';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/common.dart';

const legacyDatabaseName = 'flex_notizbuch_rebuild_v1.sqlite';
const encryptedDatabaseName = 'flex_notizbuch_encrypted_v1.sqlite';

void unlockDatabase(CommonDatabase db, String key) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key) ||
      db.select('PRAGMA cipher_version').isEmpty) {
    throw StateError('Encrypted storage is unavailable.');
  }
  // SQLCipher raw key, not a password: no key derivation is required here.
  db.execute('PRAGMA key = "x\'$key\'"');
  db.execute('PRAGMA busy_timeout = 10000');
  db.execute('PRAGMA temp_store = MEMORY');
}

void _verify(Database db) {
  if (db.select('PRAGMA integrity_check').single.values.single != 'ok' ||
      db.select('PRAGMA foreign_key_check').isNotEmpty) {
    throw StateError('Database verification failed.');
  }
}

void _compareLegacy(File old, Database target) {
  final source = sqlite3.open(old.path, mode: OpenMode.readOnly);
  try {
    const schema =
        "SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name";
    if (source.userVersion != target.userVersion ||
        jsonEncode(source.select(schema)) !=
            jsonEncode(target.select(schema))) {
      throw StateError('Migration schema differs. Original retained.');
    }
    for (final table in source.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND (name NOT LIKE 'sqlite_%' OR name='sqlite_sequence')",
    )) {
      final name = (table['name'] as String).replaceAll('"', '""');
      List<String> rows(Database db) =>
          db.select('SELECT * FROM "$name"').map(jsonEncode).toList()..sort();
      if (jsonEncode(rows(source)) != jsonEncode(rows(target))) {
        throw StateError('Migration content differs. Original retained.');
      }
    }
  } finally {
    source.close();
  }
}

/// Called under the Android process-wide storage/backup mutex before a drift
/// connection is opened. An interruption keeps either the old DB or a fully
/// verified new DB. A wrong/lost key never creates a replacement database.
String prepareEncryptedDatabase(Map<String, String> args) {
  final directory = args['directory']!, key = args['key']!;
  final old = File('$directory/$legacyDatabaseName');
  final target = File('$directory/$encryptedDatabaseName');
  final staging = File('${target.path}.migrating');
  void removeOld() {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('${old.path}$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  }

  if (target.existsSync()) {
    // During normal operation drift may already hold this database open.
    // Verify the key without changing schema/journal mode before cleanup.
    final db = sqlite3.open(target.path, mode: OpenMode.readOnly);
    try {
      unlockDatabase(db, key);
      db.select('SELECT count(*) FROM sqlite_master');
      if (old.existsSync()) {
        _verify(db);
        _compareLegacy(old, db);
      }
    } finally {
      db.close();
    }
    removeOld();
    return target.path;
  }
  if (staging.existsSync()) staging.deleteSync();
  for (final suffix in ['-wal', '-shm', '-journal']) {
    final file = File('${staging.path}$suffix');
    if (file.existsSync()) file.deleteSync();
  }
  try {
    if (old.existsSync()) {
      final source = sqlite3.open(old.path);
      try {
        _verify(source);
        final version = source.userVersion;
        // Parameters keep the path and raw key out of error SQL strings.
        source.execute('ATTACH DATABASE ? AS protected KEY ?', [
          staging.path,
          "x'$key'",
        ]);
        source.execute('BEGIN EXCLUSIVE');
        try {
          source.select("SELECT sqlcipher_export('protected')");
          source.execute('PRAGMA protected.user_version = $version');
          source.execute('COMMIT');
        } catch (_) {
          source.execute('ROLLBACK');
          rethrow;
        }
        source.execute('DETACH DATABASE protected');
      } finally {
        source.close();
      }
    } else {
      final db = sqlite3.open(staging.path);
      try {
        unlockDatabase(db, key);
        // Materialize an encrypted, schema-free database for drift onCreate.
        db.execute('VACUUM');
      } finally {
        db.close();
      }
    }
    final verified = sqlite3.open(staging.path, mode: OpenMode.readOnly);
    try {
      unlockDatabase(verified, key);
      _verify(verified);
      if (old.existsSync()) _compareLegacy(old, verified);
    } finally {
      verified.close();
    }
    final handle = staging.openSync(mode: FileMode.append);
    try {
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
    staging.renameSync(target.path);
    removeOld();
    return target.path;
  } catch (_) {
    // Do not remove the original or an already committed target on failure.
    rethrow;
  }
}
