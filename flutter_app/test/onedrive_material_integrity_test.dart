import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/material_index.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/services/secret_store.dart';
import 'package:flex_notizbuch/services/scan_store.dart';
import 'package:flex_notizbuch/ui/material_library.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart'
    show FolderDrive, DownloadDrive, MemoryMaterialFiles;
import 'document_scanner_test.dart' show scannerImage;

class Secrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class OfflineDrive extends OneDriveClient {
  int calls = 0;
  @override
  bool get connected => true;
  @override
  Future<Json> item(String drive, String id) async {
    calls++;
    throw StateError('No network');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'edited OneDrive PDF and its references survive folder refresh, cloud download and backup',
    () async {
      final c = NotebookController(classroomMemory());
      await c.initialize();
      await c.savePupil(const Pupil(id: 'p', name: 'Anna Beispiel'));
      final files = MemoryMaterialFiles();
      final drive = FolderDrive({
        'folder': [
          {
            'id': 'file-1',
            'name': 'Blatt.pdf',
            'webUrl': 'https://example.org/Blatt.pdf',
            'size': 20,
          },
        ],
      });
      final download = DownloadDrive();
      addTearDown(() async {
        drive.dispose();
        download.dispose();
        c.dispose();
        await c.repository.close();
      });
      final folder = ClassroomDocument.create(
        ClassroomKind.folder,
        'Unterricht',
        {
          'driveId': 'drive',
          'itemId': 'folder',
          'url': 'https://example.org/folder',
        },
      );
      final source = (await scanMaterialFolder(drive, folder, [])).single;
      await files.write(
        'original',
        Uint8List.fromList(utf8.encode('%PDF-1.4 original')),
      );
      final saved = await c.repository.saveClassroomDocument(
        planPupilMaterial(source, 'p', '2026-11-16').patch({
          'localKey': 'original',
          'etag': 'old',
          'tags': ['Übung'],
        }),
      );
      await files.write('edited-page', scannerImage());
      final draft = await c.repository.saveDialogDraft(
        DialogDraft(
          id: newId(),
          type: 'scan',
          ownerId: newId(),
          updatedAtUtc: utcNow(),
          data: {
            ...const ScanContext(
              title: 'Bearbeitet',
              pupilIds: ['p'],
            ).initial(),
            'tags': ['Übung'],
            'pages': [const ScanPage('edited-page', 180, 240).toJson()],
            'sourceId': saved.id,
            'sourceRevision': saved.revision,
          },
        ),
      );
      final edited = await saveScan(c.repository, files, draft, replace: true);
      final editedKey = edited.text('localKey');
      expect(edited.text('itemId'), isEmpty);
      final editedBytes = await files.read(editedKey);
      final reviewed = (await scanMaterialFolder(
        drive,
        folder,
        await c.repository.classroomDocuments(),
      )).single;
      expect(reviewed.id, isNot(edited.id));
      expect(reviewed.revision, 0);
      final remote = await c.repository.saveClassroomDocument(reviewed);
      await cacheMaterial(c, remote, download, files);
      final all = await c.repository.classroomDocuments();
      final preserved = all.singleWhere((d) => d.id == edited.id);
      expect(preserved.toJson(), edited.toJson());
      expect(preserved.strings('pupilIds'), ['p']);
      expect(pupilMaterialDates(preserved, 'p'), ['2026-11-16']);
      expect(preserved.strings('tags'), ['Übung']);
      expect(await files.read(editedKey), editedBytes);
      expect(oneDriveMaterialId('drive', 'file-1', all), remote.id);
      expect(
        (await scanMaterialFolder(drive, folder, all)).single.id,
        remote.id,
      );
      final restored = classroomMemory();
      await restored.initialize();
      addTearDown(restored.close);
      await restored.restoreBackup(await c.repository.exportBackup());
      expect(
        (await restored.classroomDocuments())
            .singleWhere((d) => d.id == edited.id)
            .toJson(),
        edited.toJson(),
      );
    },
  );
  test(
    'revoked web session clears stale authentication and exposes reconnect',
    () async {
      const id = '12345678-1234-4321-1234-123456789012';
      final store = Secrets()
        ..values['flex.onedrive.tokens.v1'] = jsonEncode({
          'clientId': id,
          'access': 'fake-access',
          'refresh': 'fake-refresh',
          'expires': '2020-01-01T00:00:00Z',
        });
      final drive = OneDriveClient(
        store: store,
        clientId: id,
        useNativeAuthentication: false,
        client: MockClient(
          (r) async =>
              http.Response(jsonEncode({'error': 'invalid_grant'}), 400),
        ),
      );
      addTearDown(drive.dispose);
      await drive.load();
      await expectLater(
        drive.graph('/me/drive/root'),
        throwsA(isA<DomainError>()),
      );
      expect(drive.connected, false);
      expect(store.values.containsKey('flex.onedrive.tokens.v1'), false);
    },
  );
  testWidgets('cached OneDrive material opens without a network request', (
    t,
  ) async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    final files = MemoryMaterialFiles();
    final drive = OfflineDrive();
    addTearDown(() async {
      drive.dispose();
      c.dispose();
      await c.repository.close();
    });
    final material =
        ClassroomDocument.create(ClassroomKind.material, 'Lokales Foto', {
          'extension': 'jpg',
          'localKey': 'offline',
          'driveId': 'drive',
          'itemId': 'file',
        });
    await files.write('offline', scannerImage());
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () =>
                  openMaterial(ctx, c, material, drive: drive, files: files),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Öffnen'));
    await t.pumpAndSettle();
    expect(find.text('Lokales Foto'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(drive.calls, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });
}
