import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../domain/models.dart';

/// v1 stays readable. v2 authenticates bounded chunks, their order and total
/// length; it avoids allocating a second full-size ciphertext/base64 buffer.
/// The surrounding JSON capture/import still requires memory for the snapshot.
class BackupCodec {
  static const maxPlainBytes = 20000000, maxEnvelopeBytes = 28000000;
  static const maxCompletePlainBytes = 160000000,
      maxCompleteEnvelopeBytes = 220000000;
  static const iterations = 600000, legacyIterations = 310000;
  static const chunkBytes = 1024 * 1024;
  static final _cipher = AesGcm.with256bits();
  static List<int> _random(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (_) => random.nextInt(256));
  }

  static Future<SecretKey> _key(String password, List<int> salt, int rounds) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: rounds,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  static bool isEncrypted(String text) {
    final value = jsonDecode(text);
    return value is Map &&
        {'FLEX-Encrypted', 'FLEX-Complete-Encrypted'}.contains(value['format']);
  }

  static Uint8List _nonce(List<int> prefix, int index) {
    final nonce = Uint8List(12)..setRange(0, 8, prefix);
    ByteData.sublistView(nonce).setUint32(8, index);
    return nonce;
  }

  static List<int> _aad(String format, int length, int index) =>
      utf8.encode('$format-2:$length:$chunkBytes:$index');

  static Future<String> encrypt(String text, String password) async {
    if (password.runes.length < 12) {
      throw const DomainError(
        'Bitte mindestens 12 Zeichen als Sicherungspasswort verwenden.',
      );
    }
    if (text.length > maxCompletePlainBytes) {
      throw const DomainError('Die Sicherung überschreitet 160 MB.');
    }
    final decoded = jsonDecode(text);
    final complete =
        decoded is Map && decoded['format'] == 'FLEX-Complete-Backup';
    if (decoded is! Map) {
      throw const DomainError('Die Sicherung ist kein JSON-Objekt.');
    }
    final data = utf8.encode(text);
    if (data.length > (complete ? maxCompletePlainBytes : maxPlainBytes)) {
      throw DomainError(
        'Die Sicherung überschreitet ${complete ? 160 : 20} MB.',
      );
    }
    final format = complete ? 'FLEX-Complete-Encrypted' : 'FLEX-Encrypted';
    final salt = _random(16), prefix = _random(8);
    final key = await _key(password, salt, iterations);
    final metadata = jsonEncode({
      'format': format,
      'version': 2,
      'kdf': 'PBKDF2-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'noncePrefix': base64Encode(prefix),
      'plainBytes': data.length,
      'chunkBytes': chunkBytes,
    });
    final out = StringBuffer(metadata.substring(0, metadata.length - 1))
      ..write(',"chunks":[');
    for (
      var offset = 0, index = 0;
      offset < data.length;
      offset += chunkBytes, index++
    ) {
      final box = await _cipher.encrypt(
        Uint8List.sublistView(
          data,
          offset,
          min(offset + chunkBytes, data.length),
        ),
        secretKey: key,
        nonce: _nonce(prefix, index),
        aad: _aad(format, data.length, index),
      );
      final bytes = Uint8List(box.cipherText.length + 16)
        ..setRange(0, box.cipherText.length, box.cipherText)
        ..setRange(
          box.cipherText.length,
          box.cipherText.length + 16,
          box.mac.bytes,
        );
      if (index > 0) out.write(',');
      out.write('"${base64Encode(bytes)}"');
    }
    return (out..write(']}')).toString();
  }

  static Future<String> decrypt(String text, String password) async {
    if (text.length > maxCompleteEnvelopeBytes) {
      throw const DomainError('Die Sicherungsdatei überschreitet 220 MB.');
    }
    try {
      final value = jsonDecode(text) as Map<String, dynamic>;
      final format = value['format'];
      final complete = format == 'FLEX-Complete-Encrypted';
      final limit = complete ? maxCompletePlainBytes : maxPlainBytes;
      final version = value['version'];
      if ((!complete && format != 'FLEX-Encrypted') ||
          value['kdf'] != 'PBKDF2-SHA256' ||
          !(version == 1 && value['iterations'] == legacyIterations ||
              version == 2 && value['iterations'] == iterations)) {
        throw const DomainError('Unbekanntes Sicherungsformat.');
      }
      if (text.length >
          (complete ? maxCompleteEnvelopeBytes : maxEnvelopeBytes)) {
        throw const DomainError('Die Sicherungsdatei ist zu groß.');
      }
      final salt = base64Decode(value['salt'] as String);
      if (salt.length != 16) throw const FormatException();
      final key = await _key(password, salt, value['iterations'] as int);
      Uint8List plain;
      if (version == 1) {
        final nonce = base64Decode(value['iv'] as String);
        final bytes = base64Decode(value['ciphertext'] as String);
        if (nonce.length != 12 ||
            bytes.length < 16 ||
            bytes.length > limit + 16) {
          throw const FormatException();
        }
        plain = Uint8List.fromList(
          await _cipher.decrypt(
            SecretBox(
              Uint8List.sublistView(bytes, 0, bytes.length - 16),
              nonce: nonce,
              mac: Mac(Uint8List.sublistView(bytes, bytes.length - 16)),
            ),
            secretKey: key,
            aad: utf8.encode('$format-1'),
          ),
        );
      } else {
        final length = value['plainBytes'];
        final chunks = value['chunks'];
        final prefix = base64Decode(value['noncePrefix'] as String);
        if (length is! int ||
            length < 1 ||
            length > limit ||
            prefix.length != 8 ||
            value['chunkBytes'] != chunkBytes ||
            chunks is! List ||
            chunks.length != (length + chunkBytes - 1) ~/ chunkBytes) {
          throw const FormatException();
        }
        plain = Uint8List(length);
        for (var index = 0; index < chunks.length; index++) {
          final encoded = chunks[index];
          if (encoded is! String ||
              encoded.length > ((chunkBytes + 18) ~/ 3) * 4) {
            throw const FormatException();
          }
          final bytes = base64Decode(encoded);
          final offset = index * chunkBytes,
              count = min(chunkBytes, length - offset);
          if (bytes.length != count + 16) throw const FormatException();
          final chunk = await _cipher.decrypt(
            SecretBox(
              Uint8List.sublistView(bytes, 0, count),
              nonce: _nonce(prefix, index),
              mac: Mac(Uint8List.sublistView(bytes, count)),
            ),
            secretKey: key,
            aad: _aad(format as String, length, index),
          );
          plain.setRange(offset, offset + count, chunk);
        }
      }
      final decoded = utf8.decode(plain);
      if (jsonDecode(decoded) is! Map) throw const FormatException();
      return decoded;
    } on DomainError {
      rethrow;
    } catch (_) {
      throw const DomainError('Passwort falsch oder Sicherung beschädigt.');
    }
  }
}
