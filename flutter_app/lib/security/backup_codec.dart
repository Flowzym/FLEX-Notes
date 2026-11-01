import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../domain/models.dart';

class BackupCodec {
  static const maxPlainBytes = 20000000,
      maxEnvelopeBytes = 28000000,
      iterations = 310000;
  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  static List<int> _random(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (_) => random.nextInt(256));
  }

  static Future<SecretKey> _key(String password, List<int> salt) =>
      _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  static bool isEncrypted(String text) {
    final value = jsonDecode(text);
    return value is Map && value['format'] == 'FLEX-Encrypted';
  }

  static Future<String> encrypt(String text, String password) async {
    if (password.runes.length < 12) {
      throw const DomainError(
        'Bitte mindestens 12 Zeichen als Sicherungspasswort verwenden.',
      );
    }
    final data = utf8.encode(text);
    if (data.length > maxPlainBytes) {
      throw const DomainError('Die Sicherung überschreitet 20 MB.');
    }
    if (jsonDecode(text) is! Map) {
      throw const DomainError('Die Sicherung ist kein JSON-Objekt.');
    }
    final salt = _random(16), nonce = _random(12);
    final box = await _cipher.encrypt(
      data,
      secretKey: await _key(password, salt),
      nonce: nonce,
      aad: utf8.encode('FLEX-Encrypted-1'),
    );
    return jsonEncode({
      'format': 'FLEX-Encrypted',
      'version': 1,
      'kdf': 'PBKDF2-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'iv': base64Encode(nonce),
      'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
    });
  }

  static Future<String> decrypt(String text, String password) async {
    if (utf8.encode(text).length > maxEnvelopeBytes) {
      throw const DomainError('Die Sicherungsdatei überschreitet 28 MB.');
    }
    try {
      final value = jsonDecode(text) as Map<String, dynamic>;
      if (value['format'] != 'FLEX-Encrypted' ||
          value['version'] != 1 ||
          value['kdf'] != 'PBKDF2-SHA256' ||
          value['iterations'] != iterations) {
        throw const DomainError('Unbekanntes Sicherungsformat.');
      }
      final salt = base64Decode(value['salt'] as String),
          nonce = base64Decode(value['iv'] as String),
          bytes = base64Decode(value['ciphertext'] as String);
      if (salt.length != 16 ||
          nonce.length != 12 ||
          bytes.length < 16 ||
          bytes.length > maxPlainBytes + 16) {
        throw const DomainError('Ungültige Sicherungsdaten.');
      }
      final box = SecretBox(
        bytes.sublist(0, bytes.length - 16),
        nonce: nonce,
        mac: Mac(bytes.sublist(bytes.length - 16)),
      );
      final plain = await _cipher.decrypt(
        box,
        secretKey: await _key(password, salt),
        aad: utf8.encode('FLEX-Encrypted-1'),
      );
      final decoded = utf8.decode(plain);
      if (jsonDecode(decoded) is! Map) {
        throw const DomainError('Die Sicherung ist kein JSON-Objekt.');
      }
      return decoded;
    } on DomainError {
      rethrow;
    } catch (_) {
      throw const DomainError('Passwort falsch oder Sicherung beschädigt.');
    }
  }
}
