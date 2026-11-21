import 'dart:convert';
import 'dart:io';
import 'package:flex_notizbuch/security/backup_codec.dart';

/// Synthetic payload only. Run separately from ordinary CI to measure memory.
Future<void> main(List<String> args) async {
  final size = args.isEmpty ? 8000000 : int.parse(args.single);
  if (size < 1 || size > 150000000) throw ArgumentError('1–150 MB');
  final plain = '{"format":"FLEX-Complete-Backup","synthetic":"${'x' * size}"}';
  const password = 'Synthetic benchmark password';
  final watch = Stopwatch()..start();
  final encrypted = await BackupCodec.encrypt(plain, password);
  final encryptMs = watch.elapsedMilliseconds;
  final decrypted = await BackupCodec.decrypt(encrypted, password);
  if (decrypted != plain) throw StateError('Round trip mismatch');
  stdout.writeln(
    jsonEncode({
      'synthetic': true,
      'plainBytes': plain.length,
      'encryptedBytes': encrypted.length,
      'encryptMs': encryptMs,
      'decryptMs': watch.elapsedMilliseconds - encryptMs,
      'currentRssBytes': ProcessInfo.currentRss,
      'maxRssBytes': ProcessInfo.maxRss,
      'roundTrip': 'verified',
      'device': Platform.operatingSystem,
    }),
  );
}
