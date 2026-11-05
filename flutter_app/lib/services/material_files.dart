import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:archive/archive.dart' show ZipDecoder;
import 'package:flex_device/flex_device.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';

abstract interface class MaterialFiles {
  Future<void> write(String key, Uint8List bytes);
  Future<Uint8List> read(String key);
  Future<bool> exists(String key);
  Future<void> remove(String key);
}

class DeviceMaterialFiles implements MaterialFiles {
  const DeviceMaterialFiles();
  @override
  Future<void> write(String key, Uint8List bytes) => FlexDevice.channel
      .invokeMethod('writeMaterial', {'key': key, 'bytes': bytes});
  @override
  Future<Uint8List> read(String key) async => (await FlexDevice.channel
      .invokeMethod<Uint8List>('readMaterial', {'key': key}))!;
  @override
  Future<bool> exists(String key) async =>
      key.isNotEmpty &&
      (await FlexDevice.channel.invokeMethod<bool>('hasMaterial', {
            'key': key,
          })) ==
          true;
  @override
  Future<void> remove(String key) =>
      FlexDevice.channel.invokeMethod('removeMaterial', {'key': key});
}

void validateMaterialBytes(Uint8List bytes, String extension) {
  if (bytes.isEmpty || bytes.length > 20000000) {
    throw const DomainError('Bitte eine Datei bis zu 20 MB auswählen.');
  }
  if (extension == 'pdf' &&
          (bytes.length < 5 ||
              ascii.decode(bytes.sublist(0, 5), allowInvalid: true) !=
                  '%PDF-') ||
      extension == 'docx' &&
          (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) ||
      !{'pdf', 'docx'}.contains(extension)) {
    throw const DomainError(
      'Die Datei ist kein gültiges PDF- oder DOCX-Dokument.',
    );
  }
  if (extension == 'docx') {
    try {
      // Inspect only ZIP directory metadata; never decompress untrusted bodies.
      final entries = ZipDecoder().decodeBytes(bytes);
      final names = entries.map((e) => e.name).toSet();
      if (!names.containsAll({'[Content_Types].xml', 'word/document.xml'}) ||
          names.contains('word/vbaProject.bin') ||
          entries.length > 10000 ||
          entries.fold<int>(0, (n, e) => n + e.size) > 100000000) {
        throw const FormatException();
      }
    } catch (_) {
      throw const DomainError('Die Datei ist kein gültiges DOCX-Dokument.');
    }
  }
}

/// A separate encrypted bundle keeps binary materials out of the 20-MB notebook
/// backup. Bounded JSON/base64 avoids ZIP path traversal and decompression bombs.
class MaterialBundle {
  static const maxPlain = 60000000, maxFileTotal = 40000000;
  static final cipher = AesGcm.with256bits();
  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 310000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  static Future<Uint8List> encode(
    List<ClassroomDocument> docs,
    Map<String, Uint8List> files,
    String password,
  ) async {
    if (password.runes.length < 12) {
      throw const DomainError(
        'Bitte ein Passwort mit mindestens zwölf Zeichen verwenden.',
      );
    }
    if (files.values.fold(0, (n, b) => n + b.length) > maxFileTotal) {
      throw const DomainError(
        'Das Materialpaket überschreitet 40 MB. Bitte weniger Dateien auswählen.',
      );
    }
    final payload = {
      'format': 'FLEX-Materials',
      'version': 1,
      'documents': docs.map((d) => d.toJson()).toList(),
      'files': {
        for (final f in files.entries)
          f.key: {
            'data': base64Encode(f.value),
            'sha256': base64Encode((await Sha256().hash(f.value)).bytes),
          },
      },
    };
    final plain = utf8.encode(jsonEncode(payload));
    if (plain.length > maxPlain) {
      throw const DomainError('Das Materialpaket ist zu groß.');
    }
    final random = Random.secure(),
        salt = List<int>.generate(16, (_) => random.nextInt(256)),
        nonce = cipher.newNonce();
    final box = await cipher.encrypt(
      plain,
      secretKey: await _key(password, salt),
      nonce: nonce,
      aad: ascii.encode('FLEXMAT1'),
    );
    return Uint8List.fromList([
      ...ascii.encode('FLEXMAT1'),
      ...salt,
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  static Future<
    ({List<ClassroomDocument> documents, Map<String, Uint8List> files})
  >
  decode(Uint8List bytes, String password) async {
    if (bytes.length < 52 ||
        bytes.length > maxPlain + 52 ||
        ascii.decode(bytes.sublist(0, 8), allowInvalid: true) != 'FLEXMAT1') {
      throw const DomainError('Kein gültiges Materialpaket.');
    }
    try {
      final plain = await cipher.decrypt(
        SecretBox(
          bytes.sublist(36, bytes.length - 16),
          nonce: bytes.sublist(24, 36),
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: await _key(password, bytes.sublist(8, 24)),
        aad: ascii.encode('FLEXMAT1'),
      );
      final j = Json.from(jsonDecode(utf8.decode(plain)) as Map);
      if (j['format'] != 'FLEX-Materials' ||
          j['version'] != 1 ||
          (j['documents'] as List).length > 2000) {
        throw const FormatException();
      }
      final docs = (j['documents'] as List)
          .map((d) => ClassroomDocument.fromJson(Json.from(d as Map)))
          .toList();
      if (docs.any((d) => d.kind != ClassroomKind.material) ||
          docs.map((d) => d.id).toSet().length != docs.length) {
        throw const FormatException();
      }
      final files = <String, Uint8List>{};
      var total = 0;
      for (final entry in (j['files'] as Map).entries) {
        final key = entry.key as String;
        if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(key)) {
          throw const FormatException();
        }
        final data = base64Decode(entry.value['data'] as String);
        total += data.length;
        if (data.length > 20000000 ||
            total > maxFileTotal ||
            base64Encode((await Sha256().hash(data)).bytes) !=
                entry.value['sha256']) {
          throw const FormatException();
        }
        final matching = docs.where((d) => d.text('localKey') == key).toList();
        if (matching.isEmpty) throw const FormatException();
        for (final d in matching) {
          validateMaterialBytes(data, d.text('extension'));
        }
        files[key] = data;
      }
      if (docs.any(
        (d) =>
            d.text('localKey').isNotEmpty &&
            !files.containsKey(d.text('localKey')),
      )) {
        throw const FormatException();
      }
      return (documents: docs, files: files);
    } catch (e) {
      if (e is DomainError) rethrow;
      throw const DomainError('Passwort falsch oder Materialpaket beschädigt.');
    }
  }
}
