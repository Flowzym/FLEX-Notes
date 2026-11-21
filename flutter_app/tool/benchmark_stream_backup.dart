// Run separately: flutter test tool/benchmark_stream_backup.dart --reporter expanded
// Only synthetic data; reports process RSS, not Android-device measurements.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/services/material_files.dart';
import 'package:flex_notizbuch/services/stream_backup.dart';
import 'package:flex_notizbuch/services/complete_backup.dart';
import 'package:flex_notizbuch/security/backup_codec.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import '../test/classroom_test.dart' show classroomMemory;

class DiskFiles implements MaterialFiles {
  DiskFiles(this.directory);
  final Directory directory;
  File file(String key) => File('${directory.path}/$key');
  @override
  Future<bool> exists(String key) => file(key).exists();
  @override
  Future<Uint8List> read(String key) => file(key).readAsBytes();
  @override
  Future<void> remove(String key) => file(key).delete();
  @override
  Future<void> write(String key, Uint8List bytes) async =>
      file(key).writeAsBytes(bytes, flush: true);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test(
    '100 MB of synthetic files: streamed capture, review, restore',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'flex-stream-benchmark-',
      );
      addTearDown(() => root.delete(recursive: true));
      final repo = classroomMemory(), restoredRepo = classroomMemory();
      await repo.initialize();
      await restoredRepo.initialize();
      addTearDown(repo.close);
      addTearDown(restoredRepo.close);
      final source = DiskFiles(await Directory('${root.path}/source').create());
      final target = DiskFiles(await Directory('${root.path}/target').create());
      final baselineRss = ProcessInfo.currentRss;
      for (var i = 0; i < 5; i++) {
        final bytes = Uint8List(20000000)
          ..fillRange(0, 20000000, i + 32)
          ..setAll(0, ascii.encode('%PDF-1.4 synthetic $i'));
        await source.write('file$i', bytes);
        await repo.saveClassroomDocument(
          ClassroomDocument.create(ClassroomKind.material, 'Synthetic $i', {
            'localKey': 'file$i',
            'extension': 'pdf',
            'size': bytes.length,
          }),
        );
      }
      final archive = File('${root.path}/archive.flexbackup');
      final watch = Stopwatch()..start();
      final legacy = Platform.environment['FLEX_BENCHMARK_MODE'] == 'legacy';
      final CompleteRestore restore;
      final int exportMs, reviewMs;
      if (legacy) {
        final plain = await CompleteBackup.capture(repo, source);
        final encoded = await BackupCodec.encrypt(
          plain,
          'Synthetic benchmark password',
        );
        await archive.writeAsString(encoded);
        exportMs = watch.elapsedMilliseconds;
        final decoded = await BackupCodec.decrypt(
          await archive.readAsString(),
          'Synthetic benchmark password',
        );
        restore = await (await CompleteBackup.decode(
          Map<String, dynamic>.from(jsonDecode(decoded) as Map),
        )).prepare(target);
        reviewMs = watch.elapsedMilliseconds - exportMs;
      } else {
        final sink = archive.openWrite();
        await sink.addStream(
          StreamBackup.capture(
            repo,
            source,
            password: 'Synthetic benchmark password',
          ),
        );
        await sink.close();
        exportMs = watch.elapsedMilliseconds;
        restore = await StreamBackup.prepare(
          archive.openRead,
          target,
          password: 'Synthetic benchmark password',
        );
        reviewMs = watch.elapsedMilliseconds - exportMs;
      }
      await restore.commit(() => restoredRepo.restoreBackup(restore.notebook));
      final importMs = watch.elapsedMilliseconds - exportMs - reviewMs;
      expect(await restoredRepo.classroomDocuments(), hasLength(5));
      expect(await target.directory.list().length, 5);
      if (!legacy) {
        expect(
          restore.files,
          isEmpty,
          reason: 'No archive-sized material map retained',
        );
      }
      final result = {
        'synthetic': true,
        'fileBytes': 100000000,
        'archiveBytes': await archive.length(),
        'exportMs': exportMs,
        'reviewMs': reviewMs,
        'importMs': importMs,
        'baselineRssBytes': baselineRss,
        'currentRssBytes': ProcessInfo.currentRss,
        'maxRssBytes': ProcessInfo.maxRss,
        'device': Platform.operatingSystem,
        'format': legacy ? 'v2 buffered' : 'v3 streamed',
        'mode':
            'Flutter test JIT; five files of 20 MB; full repository restore',
        'roundTrip': 'verified',
      };
      final path = Platform.environment['FLEX_BENCHMARK_REPORT'];
      if (path != null) {
        await File(path).writeAsString('${jsonEncode(result)}\n');
      }
      // ignore: avoid_print
      print(jsonEncode(result));
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
