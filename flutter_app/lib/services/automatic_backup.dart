import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flex_device/flex_device.dart';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../security/backup_codec.dart';
import 'secret_store.dart';

abstract interface class BackupFiles {
  Future<Map<String, dynamic>?> chooseDirectory();
  Future<List<Map<String, dynamic>>> list(String folder);
  Future<String> write(String folder, String name, Uint8List bytes);
  Future<Uint8List> read(String folder, String uri);
  Future<void> delete(String folder, String uri);
}

class DeviceBackupFiles implements BackupFiles {
  const DeviceBackupFiles();
  static const device = FlexDevice();
  @override
  Future<Map<String, dynamic>?> chooseDirectory() => device.chooseDirectory();
  @override
  Future<List<Map<String, dynamic>>> list(String folder) =>
      device.backups(folder);
  @override
  Future<String> write(String folder, String name, Uint8List bytes) =>
      device.write(folder, name, bytes);
  @override
  Future<Uint8List> read(String folder, String uri) => device.read(folder, uri);
  @override
  Future<void> delete(String folder, String uri) => device.delete(folder, uri);
}

Future<String> _encryptBackup(Map<String, String> input) =>
    BackupCodec.encrypt(input['text']!, input['password']!);
Future<String> _decryptBackup(Map<String, String> input) =>
    BackupCodec.decrypt(input['text']!, input['password']!);

class AutomaticBackup extends ChangeNotifier {
  AutomaticBackup({
    required this.store,
    required this.files,
    required this.export,
    required this.schedule,
    required this.withLock,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final SecretStore store;
  final BackupFiles files;
  final Future<String> Function() export;
  final Future<void> Function(int?) schedule;
  final Future<void> Function(Future<void> Function()) withLock;
  final DateTime Function() now;
  static const key = 'flex.auto-backup.v1';
  Map<String, dynamic> _config = {};
  bool busy = false;
  String? error;
  bool get enabled => _config['enabled'] == true;
  int get intervalHours => _config['intervalHours'] as int? ?? 24;
  int get keep => _config['keep'] as int? ?? 14;
  String get folderName => _config['folderName'] as String? ?? '';
  DateTime? get lastSuccess =>
      DateTime.tryParse(_config['lastSuccess'] as String? ?? '');
  String? get lastFailure => _config['lastError'] as String?;
  Future<void> load() async {
    final raw = await store.read(key);
    _config = raw == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    notifyListeners();
  }

  Future<void> configure({
    required Map<String, dynamic> folder,
    required String password,
    required int hours,
    required int retention,
  }) async {
    if (password.runes.length < 12) {
      throw const DomainError(
        'Bitte mindestens zwölf Zeichen als Sicherungspasswort verwenden.',
      );
    }
    if (![24, 168].contains(hours) ||
        ![7, 14, 30].contains(retention) ||
        folder['uri'] is! String) {
      throw const DomainError('Ungültige Sicherungseinstellung.');
    }
    await withLock(() async {
      await load();
      final config = {
        ..._config,
        'enabled': true,
        'groupId': _config['groupId'] ?? newId(),
        'folder': folder['uri'],
        'folderName': folder['name'],
        'password': password,
        'intervalHours': hours,
        'keep': retention,
      };
      await store.write(key, jsonEncode(config));
      _config = config;
    });
    try {
      await schedule(hours);
    } catch (_) {
      await withLock(() async {
        await load();
        final failed = {
          ..._config,
          'enabled': false,
          'lastError':
              'Android konnte keine Hintergrundsicherung einrichten. Bitte erneut versuchen.',
        };
        await store.write(key, jsonEncode(failed));
        _config = failed;
      });
      notifyListeners();
      throw const DomainError(
        'Android konnte keine Hintergrundsicherung einrichten. Bitte erneut versuchen.',
      );
    }
    notifyListeners();
    await run(force: true);
  }

  Future<void> disable() async {
    await withLock(() async {
      await load();
      final value = {..._config, 'enabled': false};
      await store.write(key, jsonEncode(value));
      _config = value;
    });
    await schedule(null);
    notifyListeners();
  }

  Future<void> run({bool force = false}) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await withLock(() async {
        await load();
        if (!enabled ||
            !force &&
                lastSuccess != null &&
                !lastSuccess!.isAfter(now().toUtc()) &&
                now().toUtc().difference(lastSuccess!) <
                    Duration(hours: intervalHours)) {
          return;
        }
        final folder = _config['folder'] as String;
        String? created;
        try {
          final text = await export();
          final encrypted = await compute(_encryptBackup, {
            'text': text,
            'password': _config['password'] as String,
          });
          final bytes = Uint8List.fromList(utf8.encode(encrypted));
          final stamp = now()
              .toUtc()
              .toIso8601String()
              .split('.')
              .first
              .replaceAll(':', '');
          created = await files.write(
            folder,
            'FLEX-Auto-${stamp}Z-${_config['groupId']}-${newId()}.json',
            bytes,
          );
          final read = await files.read(folder, created);
          if (read.length != bytes.length ||
              !listEquals(
                (await Sha256().hash(read)).bytes,
                (await Sha256().hash(bytes)).bytes,
              )) {
            throw const DomainError(
              'Die gespeicherte Sicherung konnte nicht geprüft werden.',
            );
          }
          final value = {
            ..._config,
            'lastSuccess': now().toUtc().toIso8601String(),
            'lastUri': created,
          }..remove('lastError');
          await store.write(key, jsonEncode(value));
          _config = value;
          try {
            final entries = await files.list(folder);
            // New verified backup is always retained, even with a backwards clock.
            final older =
                entries
                    .where(
                      (e) =>
                          e['uri'] != created &&
                          (e['name'] as String).contains(
                            '-${_config['groupId']}-',
                          ),
                    )
                    .toList()
                  ..sort(
                    (a, b) =>
                        (b['name'] as String).compareTo(a['name'] as String),
                  );
            for (final item in older.skip(keep - 1)) {
              await files.delete(folder, item['uri'] as String);
            }
          } catch (_) {
            final warning = {
              ..._config,
              'lastError':
                  'Sicherung erfolgreich. Ältere Sicherungen konnten nicht vollständig aufgeräumt werden.',
            };
            await store.write(key, jsonEncode(warning));
            _config = warning;
          }
        } catch (e) {
          // Preserve all previous backups when export, encryption or verification fails.
          if (created != null && _config['lastUri'] != created) {
            try {
              await files.delete(folder, created);
            } catch (_) {}
          }
          error = e is DomainError
              ? e.message
              : 'Sicherung nicht abgeschlossen. Bitte Ordnerzugriff und Speicherplatz prüfen.';
          final value = {..._config, 'lastError': error};
          await store.write(key, jsonEncode(value));
          _config = value;
          rethrow;
        }
      });
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> available() async {
    await load();
    return _config['folder'] == null
        ? []
        : files.list(_config['folder'] as String);
  }

  Future<String> open(String uri, {String? password}) async {
    await load();
    final bytes = await files.read(_config['folder'] as String, uri);
    return compute(_decryptBackup, {
      'text': utf8.decode(bytes),
      'password': password ?? _config['password'] as String,
    });
  }
}
