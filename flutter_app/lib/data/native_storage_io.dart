import 'dart:io';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flex_device/flex_device.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models.dart';
import '../platform/backup_mutex.dart';
import 'encrypted_database.dart';

Future<DriftNativeOptions?> notebookNativeOptions() async {
  if (!Platform.isAndroid) {
    return DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
      shareAcrossIsolates: true,
    );
  }
  try {
    late DriftNativeOptions options;
    await backupMutex(() async {
      final key = await FlexDevice.channel.invokeMethod<String>(
        'preparePrivateStorage',
      );
      if (key == null) throw StateError('Storage key unavailable');
      final directory = await getApplicationSupportDirectory();
      final path = await compute(prepareEncryptedDatabase, {
        'directory': directory.path,
        'key': key,
      });
      options = DriftNativeOptions(
        databasePath: () async => path,
        shareAcrossIsolates: true,
        setup: (db) => unlockDatabase(db, key),
      );
    });
    return options;
  } catch (_) {
    throw const DomainError(
      'Der geschützte Speicher konnte nicht geöffnet werden. '
      'Bitte FLEX erneut starten und freien Speicher prüfen. App-Daten nicht löschen; '
      'falls der Geräteschlüssel fehlt, ist eine verschlüsselte Sicherung zur Wiederherstellung erforderlich.',
    );
  }
}
