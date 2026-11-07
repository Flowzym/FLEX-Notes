import 'dart:async';
import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flex_notizbuch/services/material_thumbnails.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/services/scan_images.dart';
import 'package:flex_notizbuch/ui/material_thumbnail.dart';
import 'document_scanner_test.dart' show scannerImage;
import 'material_workspace_test.dart'
    show MemoryMaterialFiles, material, docx, word;
import 'material_services_test.dart'
    show MaterialSecrets, clientId, tokenKey, jsonResponse;

class CountingFiles extends MemoryMaterialFiles {
  int reads = 0;
  @override
  Future<Uint8List> read(String key) async {
    reads++;
    return super.read(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'photo miniature preserves aspect and redaction at bounded resolution',
    () async {
      final source = scannerImage(width: 900, height: 1200);
      final edited = editScanPixels({
        'bytes': source,
        'redactions': [
          [.2, .2, .8, .8],
        ],
      });
      final preview = await renderDocumentThumbnail(
        edited['bytes'] as Uint8List,
        'jpg',
      );
      final pixels = img.decodeJpg(preview.image!)!;
      expect([pixels.width, pixels.height], [180, 240]);
      expect(pixels.getPixel(90, 120).r, lessThan(5));
      expect(pixels.getPixel(4, 4).r, greaterThan(220));
    },
  );
  test(
    'PDF thumbnail is the first visible page and not another page',
    () async {
      final temp = Directory.systemTemp.createTempSync('flex-thumbnail-');
      Pdfrx.cacheDirectoryPath = temp.path;
      if (Platform.isLinux) {
        Pdfrx.pdfiumModulePath = File(
          'build/native_assets/linux/libpdfium.so',
        ).absolute.path;
      }
      addTearDown(() => temp.deleteSync(recursive: true));
      final pdf = pw.Document();
      for (final color in [const PdfColor(1, 0, 0), const PdfColor(0, 0, 1)]) {
        pdf.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(400, 600, marginAll: 0),
            build: (_) => pw.Container(color: color),
          ),
        );
      }
      final preview = await renderDocumentThumbnail(await pdf.save(), 'pdf');
      final image = img.decodeJpg(preview.image!)!;
      expect([image.width, image.height], [160, 240]);
      final p = image.getPixel(80, 120);
      expect(p.r, greaterThan(220));
      expect(p.b, lessThan(20));
    },
  );
  test('DOCX preview uses bounded document content', () async {
    final preview = await renderDocumentThumbnail(
      docx(word('<w:p><w:r><w:t>Material für morgen</w:t></w:r></w:p>')),
      'docx',
    );
    expect(preview.text, 'Material für morgen');
    expect(preview.image, isNull);
  });
  test(
    'cache shares reads, invalidates replacement and retries missing files',
    () async {
      final files = CountingFiles(), cache = MaterialThumbnailCache();
      Future<DocumentThumbnail> load() => cache.load(
        identity: 'm',
        files: files,
        fileKey: 'page',
        extension: 'jpg',
      );
      expect((await load()).unavailable, true);
      await files.write('page', scannerImage());
      final before = await load();
      await load();
      expect(files.reads, 1);
      expect(before.image, isNotNull);
      await files.write(
        'page',
        editScanPixels({
              'bytes': scannerImage(),
              'redactions': [
                [.1, .1, .9, .9],
              ],
            })['bytes']
            as Uint8List,
      );
      cache.invalidate('page');
      final after = await load();
      expect(files.reads, 2);
      final pixels = img.decodeJpg(after.image!)!;
      expect(
        pixels.getPixel(pixels.width ~/ 2, pixels.height ~/ 2).r,
        lessThan(5),
      );
    },
  );
  test(
    'preview loading limits concurrent work and recovers from an unreadable file',
    () async {
      final cache = MaterialThumbnailCache(), files = CountingFiles();
      var active = 0, maxActive = 0;
      final gates = List.generate(5, (_) => Completer<Uint8List?>());
      final futures = [
        for (var i = 0; i < 5; i++)
          cache.load(
            identity: 'remote-$i',
            files: files,
            fileKey: '',
            extension: 'pdf',
            driveId: 'drive',
            itemId: '$i',
            remoteLoader: () async {
              active++;
              if (active > maxActive) maxActive = active;
              try {
                return await gates[i].future;
              } finally {
                active--;
              }
            },
          ),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(active, 2);
      gates[0].completeError(StateError('unavailable'));
      gates[1].complete(scannerImage());
      await Future.wait(futures.take(2));
      expect(maxActive, 2);
      for (var i = 2; i < 5; i++) {
        gates[i].complete(scannerImage());
      }
      final result = await Future.wait(futures);
      expect(result.first.unavailable, true);
      expect(result.skip(1).every((r) => r.image != null), true);
      expect(maxActive, 2);
    },
  );
  test(
    'OneDrive loads the actual thumbnail without sending Graph credentials to its image host',
    () async {
      final secrets = MaterialSecrets();
      secrets.values[tokenKey] = jsonEncode({
        'clientId': clientId,
        'access': 'test-token',
        'expires': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      });
      var requests = 0;
      final drive = OneDriveClient(
        store: secrets,
        clientId: clientId,
        client: MockClient((r) async {
          requests++;
          if (r.url.host == 'graph.microsoft.com') {
            expect(r.headers['authorization'], 'Bearer test-token');
            expect(r.url.path.endsWith('/thumbnails'), true);
            return jsonResponse({
              'value': [
                {
                  'medium': {'url': 'https://example.org/thumbnail.jpg'},
                },
              ],
            });
          }
          expect(r.headers['authorization'], isNull);
          return http.Response.bytes(scannerImage(), 200);
        }),
      );
      addTearDown(drive.dispose);
      await drive.load();
      expect(await drive.thumbnail('drive', 'id'), isNotEmpty);
      expect(requests, 2);
    },
  );
  testWidgets(
    'changing a material clears old pixels immediately and displays the new preview',
    (t) async {
      final files = CountingFiles();
      await files.write('old', scannerImage());
      await files.write(
        'new',
        editScanPixels({
              'bytes': scannerImage(),
              'redactions': [
                [0, 0, 1, 1],
              ],
            })['bytes']
            as Uint8List,
      );
      final before = material(
        'Foto',
        fields: {'extension': 'jpg', 'localKey': 'old'},
      );
      Future<void> show(bool changed) => t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialThumbnail(
              material: changed
                  ? before.patch({'localKey': 'new', 'revision': 1})
                  : before,
              files: files,
            ),
          ),
        ),
      );
      Future<void> waitImage() async {
        for (var i = 0; i < 100 && find.byType(Image).evaluate().isEmpty; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump();
        }
        expect(find.byType(Image), findsOneWidget);
      }

      await show(false);
      await waitImage();
      await show(true);
      expect(find.byType(Image), findsNothing);
      await waitImage();
      final bytes =
          (t.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
      expect(img.decodeJpg(bytes)!.getPixel(80, 80).r, lessThan(5));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
