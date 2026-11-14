// Full-strength cryptographic operations need headroom on shared CI runners.
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/stream_backup.dart';
import 'package:flex_notizbuch/services/automatic_backup.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show MemoryMaterialFiles;
import 'device_features_test.dart' show MemorySecrets, MemoryBackupFiles;

const password = 'Synthetic streaming password äß';
Stream<List<int>> split(Uint8List bytes, [int size = 71]) async* {
  for (var i = 0; i < bytes.length; i += size) {
    yield Uint8List.sublistView(bytes, i, min(i + size, bytes.length));
  }
}

Future<Uint8List> collect(Stream<List<int>> stream) async {
  final bytes = BytesBuilder();
  await for (final part in stream) {
    bytes.add(part);
  }
  return bytes.takeBytes();
}

class StreamingFiles extends MemoryBackupFiles implements StreamingBackupFiles {
  @override
  Future<String> writeStream(
    String folder,
    String name,
    Stream<List<int>> bytes,
  ) async => write(folder, name, await collect(bytes));
  @override
  Stream<List<int>> readStream(String folder, String uri) =>
      split(data[uri]!, 89);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reads independent Python AES-GCM/PBKDF2 v3 fixture', () async {
    final input = File('test/fixtures/stream_v3.bin');
    final restore = await StreamBackup.prepare(
      input.openRead,
      MemoryMaterialFiles(),
      password: 'Independent password é',
    );
    expect(restore.fileCount, 0);
    expect(jsonDecode(restore.notebook)['tables']['pupils'], isEmpty);
  });

  for (final encrypted in [false, true]) {
    test(
      'bounded archive restores files only after review; encrypted=$encrypted',
      () async {
        final repo = classroomMemory();
        await repo.initialize();
        addTearDown(repo.close);
        final files = MemoryMaterialFiles();
        final pdf = Uint8List(150000)
          ..setAll(0, ascii.encode('%PDF-1.4 synthetic'));
        await files.write('original', pdf);
        await repo.saveClassroomDocument(
          ClassroomDocument.create(ClassroomKind.material, 'Synthetic.pdf', {
            'localKey': 'original',
            'extension': 'pdf',
          }),
        );
        var maxChunk = 0;
        final archive = await collect(
          StreamBackup.capture(
            repo,
            files,
            password: encrypted ? password : null,
          ).map((b) {
            maxChunk = max(maxChunk, b.length);
            return b;
          }),
        );
        expect(maxChunk, lessThanOrEqualTo(StreamBackup.chunkSize + 16));
        expect(await StreamBackup.recognizes(() => split(archive, 1)), isTrue);
        expect(
          await StreamBackup.requiresPassword(() => split(archive)),
          encrypted,
        );
        final target = MemoryMaterialFiles();
        final restore = await StreamBackup.prepare(
          () => split(archive),
          target,
          password: encrypted ? password : null,
        );
        expect(target.values, isEmpty);
        expect(restore.fileCount, 1);
        var committed = false;
        await restore.commit(() async {
          committed = true;
          expect(target.values.values.single, pdf);
        });
        expect(committed, isTrue);
      },
    );
  }
  test(
    'authentication rejects wrong password, tampering, truncation and trailing data',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final archive = await collect(
        StreamBackup.capture(repo, MemoryMaterialFiles(), password: password),
      );
      final corrupt = Uint8List.fromList(archive)..[archive.length - 10] ^= 1;
      final headerStart = StreamBackup.magic.length + 4;
      final headerLength = ByteData.sublistView(
        archive,
        StreamBackup.magic.length,
      ).getUint32(0);
      final frameStart = headerStart + headerLength;
      final frames = <Uint8List>[];
      for (var offset = frameStart; offset < archive.length;) {
        final size = ByteData.sublistView(archive, offset).getUint32(0);
        frames.add(Uint8List.sublistView(archive, offset, offset + 4 + size));
        offset += 4 + size;
      }
      final reordered = Uint8List.fromList([
        ...archive.take(frameStart),
        ...frames[1],
        ...frames[0],
        ...frames.skip(2).expand((f) => f),
      ]);
      final header =
          jsonDecode(utf8.decode(archive.sublist(headerStart, frameStart)))
              as Map;
      final prefix = base64Decode(header['noncePrefix'] as String)..[0] ^= 1;
      header['noncePrefix'] = base64Encode(prefix);
      final changedHeader = Uint8List.fromList(archive)
        ..setRange(headerStart, frameStart, utf8.encode(jsonEncode(header)));
      for (final item in [
        (archive, 'wrong password'),
        (reordered, password),
        (changedHeader, password),
        (corrupt, password),
        (Uint8List.sublistView(archive, 0, archive.length - 25), password),
        (Uint8List.fromList([...archive, 1]), password),
      ]) {
        final target = MemoryMaterialFiles();
        await expectLater(
          StreamBackup.prepare(() => split(item.$1), target, password: item.$2),
          throwsA(isA<DomainError>()),
        );
        expect(target.values, isEmpty);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'second pass modification and database failure roll back only new files',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final original = MemoryMaterialFiles();
      final pdf = Uint8List.fromList(ascii.encode('%PDF-1.4 new'));
      await original.write('original', pdf);
      await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Synthetic.pdf', {
          'localKey': 'original',
          'extension': 'pdf',
        }),
      );
      final target = MemoryMaterialFiles();
      final existing = Uint8List.fromList(ascii.encode('%PDF-1.4 existing'));
      await target.write('original', existing);
      var archive = await collect(StreamBackup.capture(repo, original));
      final restore = await StreamBackup.prepare(() => split(archive), target);
      await expectLater(
        restore.commit(() async => throw StateError('database failure')),
        throwsStateError,
      );
      expect(target.values, {'original': existing});
      archive = Uint8List.sublistView(archive, 0, archive.length - 5);
      var committed = false;
      await expectLater(
        restore.commit(() async {
          committed = true;
        }),
        throwsA(isA<DomainError>()),
      );
      expect(committed, isFalse);
      expect(target.values, {'original': existing});
    },
  );
  test(
    'automatic streaming backup verifies readback before retention',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final files = StreamingFiles();
      final backup = AutomaticBackup(
        store: MemorySecrets(),
        files: files,
        export: () => throw StateError('legacy path must not run'),
        exportStream: (p) =>
            StreamBackup.capture(repo, MemoryMaterialFiles(), password: p),
        schedule: (_) async {},
        withLock: (action) => action(),
      );
      addTearDown(backup.dispose);
      await backup.configure(
        folder: {'uri': 'folder', 'name': 'test'},
        password: password,
        hours: 24,
        retention: 7,
      );
      expect(files.names.keys.single, endsWith('.flexbackup'));
      final first = files.data.keys.single;
      final input = await backup.openInput(first);
      expect(await StreamBackup.recognizes(input.source), isTrue);
      final restore = await StreamBackup.prepare(
        input.source,
        MemoryMaterialFiles(),
        password: input.password,
      );
      expect(restore.fileCount, 0);
      files.corrupt = true;
      await expectLater(backup.run(force: true), throwsA(isA<DomainError>()));
      expect(files.data.keys, [first]);
      expect(backup.lastFailure, contains('geprüft'));
    },
  );
  test('legacy JSON is recognized as legacy without changing input', () async {
    expect(
      await StreamBackup.recognizes(
        () => split(Uint8List.fromList(utf8.encode('{}'))),
      ),
      isFalse,
    );
  });
}
