import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../domain/material_versions.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import 'material_files.dart';

/// One snapshot contains notebook rows and every locally referenced binary,
/// including trash, scan drafts and the retained document versions.
class CompleteBackup {
  const CompleteBackup(this.notebook, this.files);
  final String notebook;
  final Map<String, Uint8List> files;
  static const format = 'FLEX-Complete-Backup';
  static const maxFilesBytes = 100000000;

  static Map<String, String> references(String notebook) {
    final root = jsonDecode(notebook) as Map;
    final tables = root['tables'] as Map;
    final result = <String, String>{};
    // The schema stores classroom and scan documents as JSON payloads.
    for (final table in tables.entries) {
      for (final row in table.value as List) {
        if (row is! Map ||
            row['payload'] is! String ||
            !(table.key == 'context_drafts' ||
                table.key == 'preferences' &&
                    (row['key'] as String).startsWith('classroom:'))) {
          continue;
        }
        final value = Json.from(jsonDecode(row['payload'] as String) as Map);
        if (table.key == 'preferences') {
          for (final key in materialFileKeys(value)) {
            final version = materialVersions(
              value,
            ).where((v) => v['localKey'] == key).firstOrNull;
            result[key] =
                version?['extension'] as String? ??
                value['extension'] as String? ??
                '';
          }
        } else if (table.key == 'context_drafts') {
          final data = value['data'] is Map
              ? Json.from(value['data'] as Map)
              : value;
          if (row['type'] == 'scan' || value['type'] == 'scan') {
            for (final key in scanFileKeys(data)) {
              result[key] = 'jpg';
            }
          }
          for (final key in materialFileKeys(data)) {
            final version = materialVersions(
              data,
            ).where((v) => v['localKey'] == key).firstOrNull;
            result[key] =
                version?['extension'] as String? ??
                data['extension'] as String? ??
                '';
          }
        }
      }
    }
    return result;
  }

  static Future<String> capture(
    NotebookRepository repository,
    MaterialFiles storage, {
    bool appearance = true,
  }) async {
    final data = Json.from(jsonDecode(await repository.exportBackup()) as Map);
    if (!appearance) {
      (data['tables']['preferences'] as List).removeWhere(
        (r) => r['key'] == 'appearance',
      );
    }
    final notebook = jsonEncode(data);
    if (utf8.encode(notebook).length > 20000000) {
      throw const DomainError('Die Notizbuchdaten überschreiten 20 MB.');
    }
    final files = <String, Json>{};
    var total = 0;
    for (final ref in references(notebook).entries) {
      if (!await storage.exists(ref.key)) {
        throw const DomainError(
          'Eine verknüpfte lokale Datei fehlt. Die vollständige Sicherung wurde nicht erstellt. Bitte die Datei wiederherstellen.',
        );
      }
      final bytes = await storage.read(ref.key);
      validateMaterialBytes(bytes, ref.value);
      total += bytes.length;
      if (total > maxFilesBytes) {
        throw const DomainError(
          'Die vollständige Sicherung enthält mehr als 100 MB Dateien.',
        );
      }
      files[ref.key] = {
        'data': base64Encode(bytes),
        'sha256': base64Encode((await Sha256().hash(bytes)).bytes),
      };
    }
    return jsonEncode({
      'format': format,
      'version': 1,
      'notebook': data,
      'files': files,
    });
  }

  static Future<CompleteBackup> decode(Json data) async {
    try {
      if (data['format'] != format ||
          data['version'] != 1 ||
          data['notebook'] is! Map ||
          data['files'] is! Map) {
        throw const FormatException();
      }
      final notebook = jsonEncode(data['notebook']);
      if (utf8.encode(notebook).length > 20000000) {
        throw const FormatException();
      }
      final expected = references(notebook), raw = data['files'] as Map;
      if (raw.length != expected.length || raw.length > 10000) {
        throw const FormatException();
      }
      final files = <String, Uint8List>{};
      var total = 0;
      for (final ref in expected.entries) {
        if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(ref.key)) {
          throw const FormatException();
        }
        final value = raw[ref.key];
        if (value is! Map ||
            value['data'] is! String ||
            (value['data'] as String).length > 27000000) {
          throw const FormatException();
        }
        final bytes = base64Decode(value['data'] as String);
        total += bytes.length;
        if (total > maxFilesBytes ||
            base64Encode((await Sha256().hash(bytes)).bytes) !=
                value['sha256']) {
          throw const FormatException();
        }
        validateMaterialBytes(bytes, ref.value);
        files[ref.key] = bytes;
      }
      return CompleteBackup(notebook, files);
    } catch (e) {
      if (e is DomainError) rethrow;
      throw const DomainError(
        'Die vollständige Sicherung ist beschädigt oder unvollständig. Es wurde nichts übernommen.',
      );
    }
  }

  Future<CompleteRestore> prepare(MaterialFiles storage) async {
    final mapping = <String, String>{}, writes = <String, Uint8List>{};
    for (final entry in files.entries) {
      final hash = (await Sha256().hash(entry.value)).bytes;
      Future<bool> same(String key) async =>
          await storage.exists(key) &&
          _equal((await Sha256().hash(await storage.read(key))).bytes, hash);
      var key = entry.key;
      if (!await same(key)) {
        key =
            'full_${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
        if (!await same(key)) {
          if (await storage.exists(key)) key = newId();
          writes[key] = entry.value;
        }
      }
      mapping[entry.key] = key;
    }
    dynamic rewrite(dynamic value) {
      if (value is List) return value.map(rewrite).toList();
      if (value is! Map) return value;
      return <String, dynamic>{
        for (final e in value.entries)
          e.key as String:
              e.key == 'localKey' ||
                  e.key == 'key' &&
                      value.containsKey('width') &&
                      value.containsKey('height')
              ? mapping[e.value] ?? e.value
              : e.key == 'filterUndo' && e.value is Map
              ? {
                  for (final p in (e.value as Map).entries)
                    mapping[p.key] ?? p.key: rewrite(p.value),
                }
              : (e.key == 'payload' ||
                        e.key == 'before_payload' ||
                        e.key == 'after_payload') &&
                    e.value is String
              ? jsonEncode(rewrite(jsonDecode(e.value as String)))
              : rewrite(e.value),
      };
    }

    return CompleteRestore(
      jsonEncode(rewrite(jsonDecode(notebook))),
      writes,
      storage,
      files.length,
    );
  }
}

bool _equal(List<int> a, List<int> b) =>
    a.length == b.length && a.indexed.every((e) => e.$2 == b[e.$1]);

class CompleteRestore {
  CompleteRestore(this.notebook, this.files, this.storage, this.fileCount);
  final String notebook;
  final Map<String, Uint8List> files;
  final MaterialFiles storage;
  final int fileCount;
  Future<void> commit(Future<void> Function() databaseCommit) async {
    final created = <String>[];
    try {
      for (final e in files.entries) {
        if (await storage.exists(e.key)) {
          if (!_equal(await storage.read(e.key), e.value)) {
            throw const StaleRevision();
          }
          continue;
        }
        created.add(e.key);
        await storage.write(e.key, e.value);
        if (!_equal(await storage.read(e.key), e.value)) {
          throw const DomainError(
            'Eine wiederhergestellte Datei konnte nicht geprüft werden.',
          );
        }
      }
      // The notebook transaction runs only after every binary is verified.
      await databaseCommit();
    } catch (_) {
      for (final key in created) {
        try {
          await storage.remove(key);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
