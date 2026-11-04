import 'package:flutter/services.dart';

class FlexDevice {
  Future<String> acquireBackupLock() async => (await const MethodChannel(
    'at.flowzym.flex_notizbuch/device',
  ).invokeMethod<String>('acquireBackupLock'))!;
  Future<void> releaseBackupLock(String token) => const MethodChannel(
    'at.flowzym.flex_notizbuch/device',
  ).invokeMethod('releaseBackupLock', {'token': token});
  const FlexDevice();
  static const channel = MethodChannel('at.flowzym.flex_notizbuch/device');
  Future<Map<String, dynamic>?> chooseDirectory() async {
    final value = await channel.invokeMapMethod<String, dynamic>(
      'chooseBackupDirectory',
    );
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  Future<List<Map<String, dynamic>>> backups(String folder) async =>
      (await channel.invokeListMethod<dynamic>('listBackups', {
                'folder': folder,
              }) ??
              [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  Future<String> write(String folder, String name, Uint8List bytes) async =>
      (await channel.invokeMethod<String>('writeBackup', {
        'folder': folder,
        'name': name,
        'bytes': bytes,
      }))!;
  Future<Uint8List> read(String folder, String uri) async => (await channel
      .invokeMethod<Uint8List>('readBackup', {'folder': folder, 'uri': uri}))!;
  Future<void> delete(String folder, String uri) =>
      channel.invokeMethod('deleteBackup', {'folder': folder, 'uri': uri});
  Future<void> protectScreen(bool enabled) =>
      channel.invokeMethod('protectScreen', {'enabled': enabled});
}
