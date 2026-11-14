import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import '../domain/models.dart';
import '../domain/repository.dart';
import 'complete_backup.dart';
import 'material_files.dart';

/// Re-openable input. Callers must supply bounded stream chunks (e.g. 256 KiB).
typedef BackupSource = Stream<List<int>> Function();
typedef BackupProgress = void Function(int files, int bytes);

/// Binary v3 archive: bounded metadata/data frames, each authenticated with the
/// exact header and its sequence number. The mandatory authenticated end record
/// prevents accepting truncated files. Never retains all material bytes at once.
class StreamBackup {
  static const magic = 'FLEXBACKUP3\n';
  static const chunkSize = 65536, maxArchiveBytes = 160000000;
  static const iterations = 600000;

  static Future<bool> recognizes(BackupSource source) async {
    final input = _Input(source());
    try {
      return listEqual(await input.read(magic.length), ascii.encode(magic));
    } on FormatException {
      return false;
    } finally {
      await input.close();
    }
  }

  static Future<bool> requiresPassword(BackupSource source) async {
    final input = _Input(source());
    try {
      if (!listEqual(await input.read(magic.length), ascii.encode(magic))) {
        throw const FormatException();
      }
      final length = await input.number();
      if (length < 1 || length > 1024) throw const FormatException();
      return (jsonDecode(utf8.decode(await input.read(length)))
              as Map)['encrypted'] ==
          true;
    } finally {
      await input.close();
    }
  }

  static Stream<List<int>> capture(
    NotebookRepository repository,
    MaterialFiles files, {
    String? password,
    bool appearance = true,
    BackupProgress? progress,
  }) async* {
    if (password != null && password.runes.length < 12) {
      throw const DomainError(
        'Bitte mindestens zwölf Zeichen als Sicherungspasswort verwenden.',
      );
    }
    final data = Json.from(jsonDecode(await repository.exportBackup()) as Map);
    if (!appearance) {
      (data['tables']['preferences'] as List).removeWhere(
        (r) => r['key'] == 'appearance',
      );
    }
    final notebook = jsonEncode(data);
    final refs = CompleteBackup.references(notebook);
    if (refs.length > 10000) {
      throw const DomainError('Zu viele Dateien in der Sicherung.');
    }
    final random = Random.secure();
    List<int> randomBytes(int n) =>
        List.generate(n, (_) => random.nextInt(256));
    final header = utf8.encode(
      jsonEncode({
        'format': 'FLEX-Stream-Backup',
        'version': 3,
        'encrypted': password != null,
        'chunkBytes': chunkSize,
        'iterations': password == null ? 0 : iterations,
        'salt': base64Encode(randomBytes(16)),
        'noncePrefix': base64Encode(randomBytes(8)),
      }),
    );
    final frames = await _Frames.create(header, password);
    yield ascii.encode(magic);
    yield _uint32(header.length);
    yield header;
    Stream<List<int>> item(Json meta, Uint8List bytes) async* {
      if (bytes.isEmpty || bytes.length > 20000000) {
        throw const DomainError(
          'Ein Sicherungsbestandteil überschreitet 20 MB.',
        );
      }
      yield* frames.encode(
        utf8.encode(
          jsonEncode({
            ...meta,
            'size': bytes.length,
            'hash': base64Encode((await Sha256().hash(bytes)).bytes),
          }),
        ),
      );
      for (var start = 0; start < bytes.length; start += chunkSize) {
        yield* frames.encode(
          Uint8List.sublistView(
            bytes,
            start,
            min(bytes.length, start + chunkSize),
          ),
        );
      }
    }

    yield* item({'type': 'notebook'}, utf8.encode(notebook));
    var total = 0, count = 0;
    for (final ref in refs.entries) {
      _checkKey(ref.key);
      if (!await files.exists(ref.key)) {
        throw const DomainError(
          'Eine verknüpfte Datei fehlt. Die Sicherung wurde nicht abgeschlossen.',
        );
      }
      final bytes = await files.read(ref.key);
      validateMaterialBytes(bytes, ref.value);
      total += bytes.length;
      if (total > CompleteBackup.maxFilesBytes) {
        throw const DomainError(
          'Die Sicherung enthält mehr als 100 MB Dateien.',
        );
      }
      yield* item({
        'type': 'file',
        'key': ref.key,
        'extension': ref.value,
      }, bytes);
      count++;
      progress?.call(count, total);
    }
    yield* frames.encode(
      utf8.encode(jsonEncode({'type': 'end', 'files': count, 'bytes': total})),
    );
  }

  /// Fully verifies the archive before showing the import review. Keeps only
  /// notebook metadata and file hashes; commit reads and verifies files again.
  static Future<CompleteRestore> prepare(
    BackupSource source,
    MaterialFiles storage, {
    String? password,
    BackupProgress? progress,
  }) async {
    final mapping = <String, String>{};
    final manifest = await _inspect(source, password, (meta, bytes) async {
      final original = meta['key'] as String, hash = meta['hash'] as String;
      Future<bool> same(String key) async =>
          await storage.exists(key) &&
          base64Encode((await Sha256().hash(await storage.read(key))).bytes) ==
              hash;
      var target = original;
      if (!await same(target)) {
        target =
            'full_${base64Decode(hash).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
        if (await storage.exists(target) && !await same(target)) {
          target = newId();
        }
      }
      mapping[original] = target;
    }, progress);
    return _StreamRestore(source, password, manifest, mapping, storage);
  }
}

class _Manifest {
  _Manifest(this.notebook, this.files);
  final String notebook;
  final Map<String, Json> files;
}

Future<_Manifest> _inspect(
  BackupSource source,
  String? password,
  Future<void> Function(Json, Uint8List) consume,
  BackupProgress? progress,
) async {
  final input = _Input(source());
  try {
    if (!listEqual(
      await input.read(StreamBackup.magic.length),
      ascii.encode(StreamBackup.magic),
    )) {
      throw const FormatException();
    }
    final headerLength = await input.number();
    if (headerLength < 1 || headerLength > 1024) throw const FormatException();
    final frames = await _Frames.create(
      await input.read(headerLength),
      password,
    );
    Future<Uint8List> next() async {
      final size = await input.number();
      if (size < 1 || size > StreamBackup.chunkSize + 16) {
        throw const FormatException();
      }
      return frames.decode(await input.read(size));
    }

    Future<Json> metadata() async {
      final bytes = await next();
      if (bytes.length > 1024) throw const FormatException();
      return Json.from(jsonDecode(utf8.decode(bytes)) as Map);
    }

    Future<Uint8List> body(Json meta) async {
      final size = meta['size'], hash = meta['hash'];
      if (size is! int ||
          size < 1 ||
          size > 20000000 ||
          hash is! String ||
          base64Decode(hash).length != 32) {
        throw const FormatException();
      }
      final bytes = Uint8List(size);
      for (var offset = 0; offset < size;) {
        final chunk = await next();
        if (chunk.length != min(StreamBackup.chunkSize, size - offset)) {
          throw const FormatException();
        }
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      if (base64Encode((await Sha256().hash(bytes)).bytes) != hash) {
        throw const FormatException();
      }
      return bytes;
    }

    final meta = await metadata();
    if (meta['type'] != 'notebook') throw const FormatException();
    final notebook = utf8.decode(await body(meta));
    final root = jsonDecode(notebook) as Map;
    if (root['format'] != 'FLEX-Flutter-Rebuild-Backup') {
      throw const FormatException();
    }
    final refs = CompleteBackup.references(notebook);
    if (refs.length > 10000) throw const FormatException();
    final seen = <String, Json>{};
    var total = 0;
    while (true) {
      final item = await metadata();
      if (item['type'] == 'end') {
        if (seen.length != refs.length ||
            item['files'] != seen.length ||
            item['bytes'] != total ||
            !await input.atEnd()) {
          throw const FormatException();
        }
        return _Manifest(notebook, seen);
      }
      final key = item['key'];
      if (item['type'] != 'file' ||
          key is! String ||
          seen.containsKey(key) ||
          !refs.containsKey(key) ||
          item['extension'] != refs[key]) {
        throw const FormatException();
      }
      _checkKey(key);
      final size = item['size'];
      if (size is! int ||
          size < 1 ||
          total + size > CompleteBackup.maxFilesBytes) {
        throw const FormatException();
      }
      final bytes = await body(item);
      validateMaterialBytes(bytes, refs[key]!);
      total += size;
      seen[key] = item;
      await consume(item, bytes);
      progress?.call(seen.length, total);
    }
  } on DomainError {
    rethrow;
  } catch (_) {
    throw const DomainError(
      'Die Sicherung ist unvollständig, beschädigt oder das Passwort ist nicht korrekt. Es wurde nichts übernommen.',
    );
  } finally {
    await input.close();
  }
}

class _StreamRestore extends CompleteRestore {
  _StreamRestore(
    this.source,
    this.password,
    this.manifest,
    this.mapping,
    MaterialFiles storage,
  ) : super(
        rewriteBackupFileKeys(manifest.notebook, mapping),
        {},
        storage,
        manifest.files.length,
      );
  final BackupSource source;
  final String? password;
  final _Manifest manifest;
  final Map<String, String> mapping;
  @override
  Future<void> commit(Future<void> Function() databaseCommit) async {
    final created = <String>[];
    try {
      final read = await _inspect(source, password, (meta, bytes) async {
        final original = meta['key'] as String;
        if (jsonEncode(meta) != jsonEncode(manifest.files[original])) {
          throw const StaleRevision();
        }
        final key = mapping[original]!;
        if (await storage.exists(key)) {
          if (!listEqual(await storage.read(key), bytes)) {
            throw const StaleRevision();
          }
        } else {
          created.add(key);
          await storage.write(key, bytes);
          if (!listEqual(await storage.read(key), bytes)) {
            throw const DomainError(
              'Eine wiederhergestellte Datei konnte nicht geprüft werden.',
            );
          }
        }
      }, null);
      if (read.notebook != manifest.notebook ||
          read.files.length != manifest.files.length) {
        throw const StaleRevision();
      }
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

class _Frames {
  _Frames(this.header, this.prefix, this.key);
  final Uint8List header, prefix;
  final SecretKey? key;
  final cipher = AesGcm.with256bits();
  var index = 0;
  static Future<_Frames> create(Uint8List bytes, String? password) async {
    final h = Json.from(jsonDecode(utf8.decode(bytes)) as Map);
    final encrypted = h['encrypted'];
    if (h['format'] != 'FLEX-Stream-Backup' ||
        h['version'] != 3 ||
        h['chunkBytes'] != StreamBackup.chunkSize ||
        encrypted is! bool ||
        h['iterations'] != (encrypted ? StreamBackup.iterations : 0)) {
      throw const FormatException();
    }
    final salt = base64Decode(h['salt'] as String),
        prefix = base64Decode(h['noncePrefix'] as String);
    if (salt.length != 16 || prefix.length != 8) throw const FormatException();
    if (encrypted && password == null) {
      throw const DomainError('Diese Sicherung benötigt ein Passwort.');
    }
    final key = !encrypted
        ? null
        : SecretKey(
            await compute(_deriveStreamKey, {
              'password': password!,
              'salt': salt,
            }),
          );
    return _Frames(bytes, prefix, key);
  }

  Uint8List nonce() => Uint8List(12)
    ..setRange(0, 8, prefix)
    ..setRange(8, 12, _uint32(index));
  Uint8List aad() => Uint8List(header.length + 4)
    ..setRange(0, header.length, header)
    ..setRange(header.length, header.length + 4, _uint32(index));
  Stream<List<int>> encode(Uint8List plain) async* {
    if (plain.isEmpty || plain.length > StreamBackup.chunkSize) {
      throw const FormatException();
    }
    Uint8List result = plain;
    if (key != null) {
      final box = await cipher.encrypt(
        plain,
        secretKey: key!,
        nonce: nonce(),
        aad: aad(),
      );
      result = Uint8List(plain.length + 16)
        ..setRange(0, plain.length, box.cipherText)
        ..setRange(plain.length, plain.length + 16, box.mac.bytes);
    }
    index++;
    yield _uint32(result.length);
    yield result;
  }

  Future<Uint8List> decode(Uint8List bytes) async {
    if (key == null) {
      index++;
      return bytes;
    }
    if (bytes.length < 17) throw const FormatException();
    final result = await cipher.decrypt(
      SecretBox(
        Uint8List.sublistView(bytes, 0, bytes.length - 16),
        nonce: nonce(),
        mac: Mac(Uint8List.sublistView(bytes, bytes.length - 16)),
      ),
      secretKey: key!,
      aad: aad(),
    );
    index++;
    return Uint8List.fromList(result);
  }
}

class _Input {
  _Input(Stream<List<int>> source) : iterator = StreamIterator(source);
  final StreamIterator<List<int>> iterator;
  List<int> current = const [];
  int offset = 0, total = 0;
  Future<bool> available() async {
    while (offset == current.length) {
      if (!await iterator.moveNext()) return false;
      current = iterator.current;
      offset = 0;
      total += current.length;
      if (total > StreamBackup.maxArchiveBytes) throw const FormatException();
    }
    return true;
  }

  Future<Uint8List> read(int length) async {
    final result = Uint8List(length);
    for (var written = 0; written < length;) {
      if (!await available()) throw const FormatException('Unexpected end');
      final count = min(length - written, current.length - offset);
      result.setRange(written, written + count, current, offset);
      offset += count;
      written += count;
    }
    return result;
  }

  Future<int> number() async =>
      ByteData.sublistView(await read(4)).getUint32(0);
  Future<bool> atEnd() async => !await available();
  Future<void> close() => iterator.cancel();
}

Uint8List _uint32(int n) => Uint8List(4)..buffer.asByteData().setUint32(0, n);
void _checkKey(String key) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(key)) {
    throw const FormatException();
  }
}

bool listEqual(List<int> a, List<int> b) =>
    a.length == b.length && a.indexed.every((e) => e.$2 == b[e.$1]);

Future<List<int>> _deriveStreamKey(Map<String, dynamic> args) async {
  // Keep the expensive KDF off Android's UI thread. Web uses WebCrypto when
  // available; Android AES-GCM frames use the registered native crypto plugin.
  final kdf = kIsWeb
      ? Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: StreamBackup.iterations,
          bits: 256,
        )
      : const DartPbkdf2(
          macAlgorithm: DartHmac(DartSha256()),
          iterations: StreamBackup.iterations,
          bits: 256,
        );
  return (await kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(args['password'] as String)),
    nonce: args['salt'] as List<int>,
  )).extractBytes();
}
