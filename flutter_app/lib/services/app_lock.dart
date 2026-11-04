import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import 'secret_store.dart';

class AppLock extends ChangeNotifier {
  AppLock(
    this.store, {
    required this.authenticate,
    required this.protectScreen,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final SecretStore store;
  final Future<bool> Function() authenticate;
  final Future<void> Function(bool) protectScreen;
  final DateTime Function() now;
  Map<String, dynamic>? _policy;
  bool locked = true, ready = false, working = false;
  String? error;
  int _backgroundGeneration = 0;
  bool get enabled => _policy != null;
  bool get biometrics => _policy?['biometrics'] == true;
  DateTime? get blockedUntil =>
      DateTime.tryParse(_policy?['blockedUntil'] as String? ?? '');
  static const key = 'flex.app-lock.v1';
  static final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );

  Future<void> load() async {
    try {
      final raw = await store.read(key);
      final value = raw == null
          ? null
          : jsonDecode(raw) as Map<String, dynamic>;
      if (value != null &&
          (value['version'] != 1 ||
              value['salt'] is! String ||
              value['hash'] is! String)) {
        throw const DomainError('Die App-Sperre konnte nicht geladen werden.');
      }
      _policy = value;
      await protectScreen(enabled);
      locked = enabled;
      ready = true;
      error = null;
    } catch (_) {
      locked = true;
      ready = false;
      error =
          'Die App-Sperre konnte nicht gelesen werden. Bitte erneut versuchen.';
    }
    notifyListeners();
  }

  Future<String> _hash(String pin, String salt) =>
      compute(_pinHash, {'pin': pin, 'salt': salt});
  Future<void> configure(
    String pin, {
    required bool useBiometrics,
    String? currentPin,
  }) async {
    if (enabled && locked) {
      throw const DomainError('Bitte die App zuerst entsperren.');
    }
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) {
      throw const DomainError('Die PIN muss 6 bis 12 Ziffern enthalten.');
    }
    if (enabled && !await unlockPin(currentPin ?? '')) {
      throw DomainError(error ?? 'Bisherige PIN erforderlich.');
    }
    final generation = _backgroundGeneration;
    final random = Random.secure();
    final salt = base64Encode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
    if (useBiometrics && !await authenticate()) {
      throw const DomainError('Biometrische Bestätigung abgebrochen.');
    }
    final value = <String, dynamic>{
      'version': 1,
      'salt': salt,
      'hash': await _hash(pin, salt),
      'biometrics': useBiometrics,
      'attempts': 0,
    };
    if (generation != _backgroundGeneration) {
      throw const DomainError(
        'Einrichtung unterbrochen. Bitte erneut versuchen.',
      );
    }
    await store.write(key, jsonEncode(value));
    _policy = value;
    await protectScreen(true);
    locked = generation != _backgroundGeneration;
    ready = true;
    error = null;
    notifyListeners();
  }

  void lock({bool background = false}) {
    if (background) _backgroundGeneration++;
    if (!enabled || working && !background) return;
    locked = true;
    error = null;
    notifyListeners();
  }

  Future<bool> unlockPin(String pin) async {
    if (working || !ready || _policy == null) return false;
    final generation = _backgroundGeneration;
    working = true;
    error = null;
    notifyListeners();
    try {
      if (blockedUntil?.isAfter(now()) == true) {
        throw const DomainError(
          'Zu viele Versuche. Bitte später erneut versuchen.',
        );
      }
      final expected = base64Decode(_policy!['hash'] as String);
      final actual = base64Decode(await _hash(pin, _policy!['salt'] as String));
      var difference = expected.length ^ actual.length;
      for (var i = 0; i < min(expected.length, actual.length); i++) {
        difference |= expected[i] ^ actual[i];
      }
      if (difference != 0) {
        final attempts = (_policy!['attempts'] as int? ?? 0) + 1;
        final value = {
          ..._policy!,
          'attempts': attempts,
          if (attempts >= 5)
            'blockedUntil': now()
                .add(Duration(minutes: min(15, 1 << min(4, attempts - 5))))
                .toUtc()
                .toIso8601String(),
        };
        await store.write(key, jsonEncode(value));
        _policy = value;
        throw const DomainError('PIN nicht korrekt.');
      }
      final value = {..._policy!, 'attempts': 0}..remove('blockedUntil');
      await store.write(key, jsonEncode(value));
      _policy = value;
      if (generation != _backgroundGeneration) return false;
      locked = false;
      return true;
    } catch (e) {
      error = e is DomainError
          ? e.message
          : 'Entsperren nicht möglich. Bitte erneut versuchen.';
      return false;
    } finally {
      working = false;
      notifyListeners();
    }
  }

  Future<bool> unlockBiometric() async {
    if (working || !ready || !biometrics) return false;
    final generation = _backgroundGeneration;
    working = true;
    error = null;
    notifyListeners();
    try {
      if (!await authenticate()) return false;
      final value = {..._policy!, 'attempts': 0}..remove('blockedUntil');
      await store.write(key, jsonEncode(value));
      _policy = value;
      if (generation != _backgroundGeneration) return false;
      locked = false;
      return true;
    } catch (_) {
      error = 'Biometrie nicht verfügbar. Bitte die PIN verwenden.';
      return false;
    } finally {
      working = false;
      notifyListeners();
    }
  }

  Future<void> disable(String pin) async {
    if (!await unlockPin(pin)) throw DomainError(error ?? 'PIN nicht korrekt.');
    await store.delete(key);
    _policy = null;
    await protectScreen(false);
    notifyListeners();
  }
}

Future<String> _pinHash(Map<String, String> input) async => base64Encode(
  await (await AppLock.kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(input['pin']!)),
    nonce: base64Decode(input['salt']!),
  )).extractBytes(),
);
