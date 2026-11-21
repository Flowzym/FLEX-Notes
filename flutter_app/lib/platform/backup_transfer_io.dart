import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../domain/models.dart';

Future<bool> saveBackupStream(String name, Stream<List<int>> stream) async {
  if (Platform.isAndroid) {
    const channel = MethodChannel('at.flowzym.flex_notizbuch/files');
    final token = await channel.invokeMethod<String>('beginFileStream', {
      'name': name,
      'mime': 'application/octet-stream',
    });
    if (token == null) return false;
    try {
      await for (final chunk in stream) {
        await channel.invokeMethod('writeFileChunk', {
          'token': token,
          'bytes': Uint8List.fromList(chunk),
        });
      }
      await channel.invokeMethod('finishFileWrite', {'token': token});
      return true;
    } catch (_) {
      try {
        await channel.invokeMethod('abortFileWrite', {'token': token});
      } catch (_) {}
      rethrow;
    }
  }
  final target = await getSaveLocation(suggestedName: name);
  if (target == null) return false;
  final temporary = File('${target.path}.${newId()}.partial');
  final sink = temporary.openWrite();
  try {
    await sink.addStream(stream);
    await sink.flush();
    await sink.close();
    await temporary.rename(target.path);
    return true;
  } finally {
    await sink.close();
    if (await temporary.exists()) await temporary.delete();
  }
}
