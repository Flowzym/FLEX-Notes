import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/drafts.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/services/material_files.dart';
import 'package:flex_notizbuch/services/scan_images.dart';
import 'package:flex_notizbuch/services/scan_pdf_import.dart';
import 'package:flex_notizbuch/services/scan_store.dart';
import 'classroom_test.dart' show classroomMemory, lesson;
import 'material_workspace_test.dart' show MemoryMaterialFiles;

Uint8List scannerImage({int width = 180, int height = 240}) {
  final pixels = img.Image(width: width, height: height);
  img.fill(pixels, color: img.ColorRgb8(245, 245, 245));
  img.fillRect(
    pixels,
    x1: width ~/ 4,
    y1: height ~/ 4,
    x2: width * 3 ~/ 4,
    y2: height * 3 ~/ 4,
    color: img.ColorRgb8(210, 40, 30),
  );
  return Uint8List.fromList(img.encodeJpg(pixels, quality: 95));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  late MemoryMaterialFiles files;
  setUp(() async {
    repo = classroomMemory();
    await repo.initialize();
    files = MemoryMaterialFiles();
    await repo.savePupil(const Pupil(id: 'p', name: 'Alex'));
  });
  tearDown(() => repo.close());
  Future<DialogDraft> draft({Json fields = const {}, String? ownerId}) async {
    final normalized = normalizeScan(scannerImage());
    final key = newId();
    await files.write(key, normalized['bytes'] as Uint8List);
    return repo.saveDialogDraft(
      DialogDraft(
        id: newId(),
        type: 'scan',
        ownerId: ownerId ?? newId(),
        updatedAtUtc: utcNow(),
        data: {
          ...const ScanContext(
            pupilIds: ['p'],
            title: 'Alex',
            category: 'pupilWork',
          ).initial(now: DateTime(2026, 11, 9)),
          'pages': [
            ScanPage(
              key,
              normalized['width'] as int,
              normalized['height'] as int,
            ).toJson(),
          ],
          ...fields,
        },
      ),
    );
  }

  test(
    'adaptive document filters preserve dark text across a paper shadow',
    () {
      final page = img.Image(width: 260, height: 320);
      for (final p in page) {
        final paper = (100 + p.x / 259 * 135).round();
        final ink = p.y % 40 >= 18 && p.y % 40 < 22 && p.x % 35 < 22;
        p.setRgb(ink ? 30 : paper, ink ? 30 : paper, ink ? 30 : paper);
      }
      final bytes = Uint8List.fromList(img.encodePng(page));
      final bw = img.decodeJpg(
        editScanPixels({'bytes': bytes, 'filter': 'bw'})['bytes'] as Uint8List,
      )!;
      final document = img.decodeJpg(
        editScanPixels({'bytes': bytes, 'filter': 'document'})['bytes']
            as Uint8List,
      )!;
      for (final x in [10, 150, 250]) {
        expect(bw.getPixel(x, 5).luminance, greaterThan(245));
        expect(document.getPixel(x, 5).luminance, greaterThan(220));
        expect(bw.getPixel(x, 20).luminance, lessThan(10));
        expect(document.getPixel(x, 20).luminance, lessThan(100));
      }
    },
  );

  test(
    'geometric editing is lossless and redaction moves with rotated pixels',
    () {
      final bytes = scannerImage();
      var transformed = bytes;
      for (var i = 0; i < 4; i++) {
        transformed =
            transformScanPixels({'bytes': transformed, 'turns': 1})['bytes']
                as Uint8List;
        expect(img.PngDecoder().isValidFile(transformed), true);
      }
      expect(
        img.decodePng(transformed)!.getBytes(),
        img.decodeJpg(bytes)!.getBytes(),
      );
      final hidden = transformScanPixels({
        'bytes': bytes,
        'turns': 1,
        'redactions': [
          [.1, .1, .4, .4],
        ],
      });
      final result = img.decodePng(hidden['bytes'] as Uint8List)!;
      expect([result.width, result.height], [240, 180]);
      expect(result.getPixel(180, 45).luminance, 0);
      expect(result.getPixel(3, 3).luminance, greaterThan(220));
    },
  );

  test(
    'photo export keeps tags and links and round trips encrypted material backup',
    () async {
      final d = await draft(
        fields: {
          'outputFormat': 'jpg',
          'tags': scanTags(' #Mathe, Probe, mathe, ,'),
        },
      );
      final saved = await saveScan(repo, files, d);
      expect(saved.text('extension'), 'jpg');
      expect(saved.strings('tags'), ['Mathe', 'Probe']);
      expect(saved.strings('pupilIds'), ['p']);
      final bytes = files.values[saved.text('localKey')]!;
      validateMaterialBytes(bytes, 'jpg');
      expect(img.decodeJpg(bytes), isNotNull);
      final backup = await MaterialBundle.encode(
        [saved],
        files.values,
        'test-photo-backup-password',
      );
      final restored = await MaterialBundle.decode(
        backup,
        'test-photo-backup-password',
      );
      expect(restored.documents.single.strings('tags'), ['Mathe', 'Probe']);
      expect(restored.files[saved.text('localKey')], bytes);
    },
  );
  test(
    'multiple JPGs commit together and failed references retain all draft images',
    () async {
      final first = await draft();
      final other = normalizeScan(scannerImage(width: 240, height: 180));
      final key = newId();
      await files.write(key, other['bytes'] as Uint8List);
      final d = await repo.saveDialogDraft(
        DialogDraft(
          id: first.id,
          type: 'scan',
          ownerId: first.ownerId,
          updatedAtUtc: utcNow(),
          revision: first.revision,
          data: {
            ...first.data,
            'outputFormat': 'jpg',
            'pages': [
              ...first.data['pages'] as List,
              ScanPage(key, 240, 180, photo: true).toJson(),
            ],
            'links': [const DocumentLink('orga', 'missing').toJson()],
          },
        ),
      );
      final keys = files.values.keys.toSet();
      await expectLater(saveScan(repo, files, d), throwsA(isA<DomainError>()));
      expect(files.values.keys.toSet(), keys);
      expect(await repo.classroomDocuments(), isEmpty);
      final fixed = await repo.saveDialogDraft(
        DialogDraft(
          id: d.id,
          type: 'scan',
          ownerId: d.ownerId,
          updatedAtUtc: utcNow(),
          revision: d.revision,
          data: {...d.data, 'links': <Json>[]},
        ),
      );
      await saveScan(repo, files, fixed);
      final docs = await repo.classroomDocuments();
      expect(docs, hasLength(2));
      expect(files.values, hasLength(2));
      expect(docs.map((d) => d.text('extension')), everyElement('jpg'));
      expect(docs.map((d) => d.title).toSet(), hasLength(2));
      expect(await repo.dialogDrafts(), isEmpty);
    },
  );
  test(
    'photo filters, mirror and saturation preserve committed redactions',
    () {
      final redacted = editScanPixels({
        'bytes': scannerImage(),
        'redactions': [
          [.1, .1, .4, .4],
        ],
      });
      final edited = editScanPixels({
        'bytes': redacted['bytes'],
        'flip': true,
        'filter': 'warm',
        'saturation': 1.4,
      });
      final pixels = img.decodeJpg(edited['bytes'] as Uint8List)!;
      final hidden = pixels.getPixel(140, 60);
      expect(hidden.luminance, lessThan(10));
      final color = pixels.getPixel(90, 140);
      expect(color.r, greaterThan(color.b));
      final gray = editScanPixels({'bytes': scannerImage(), 'saturation': 0});
      final g = img.decodeJpg(gray['bytes'] as Uint8List)!.getPixel(90, 120);
      expect((g.r - g.b).abs(), lessThan(3));
    },
  );
  test(
    'scan context limits filename, validates links and never guesses students from text',
    () {
      final data = ScanContext(
        title: 'x' * 300,
        pupilIds: ['p'],
        links: [const DocumentLink('lesson', 'l', date: '2026-11-09')],
      ).initial();
      validateScanData(data);
      expect((data['title'] as String).length, lessThanOrEqualTo(200));
      expect(scanFilename('  a/b: c.pdf  '), 'a_b_ c.pdf');
      expect(
        () => DocumentLink.fromJson({
          'kind': 'lesson',
          'id': 'l',
          'date': 'not-a-date',
        }),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => ScanPage.fromJson({
          'key': '../secret',
          'width': 100,
          'height': 100,
        }),
        throwsA(isA<DomainError>()),
      );
      expect(const ScanContext(title: 'Alex').initial()['pupilIds'], isEmpty);
      expect(
        dialogDraftSignature('scan', {
          'links': [const DocumentLink('orga', 'a').toJson()],
        }),
        isNot(
          dialogDraftSignature('scan', {
            'links': [const DocumentLink('orga', 'b').toJson()],
          }),
        ),
      );
    },
  );
  test(
    'normalization strips original metadata, caps dimensions and keeps landscape',
    () {
      final jpeg = scannerImage(width: 2600, height: 400),
          secret = utf8.encode('PRIVATE-EXIF-NOTE');
      final withComment = Uint8List.fromList([
        ...jpeg.take(2),
        255,
        254,
        0,
        secret.length + 2,
        ...secret,
        ...jpeg.skip(2),
      ]);
      final normalized = normalizeScan(withComment),
          bytes = normalized['bytes'] as Uint8List;
      expect(normalized['width'], 2400);
      expect(normalized['height'], lessThan(400));
      expect(latin1.decode(bytes), isNot(contains('PRIVATE-EXIF-NOTE')));
      expect(
        () => normalizeScan(Uint8List(20000001)),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => normalizeScan(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test('redaction burns pixels, filters and crops produce usable pages', () {
    final input = scannerImage();
    final redacted = editScanPixels({
      'bytes': input,
      'brightness': 1.4,
      'redactions': [
        [.2, .2, .8, .8],
      ],
    });
    final pixels = img.decodeJpg(redacted['bytes'] as Uint8List)!;
    expect(pixels.getPixel(90, 120).luminance, lessThan(3));
    expect(pixels.getPixel(3, 3).luminance, greaterThan(200));
    final cropped = editScanPixels({
      'bytes': input,
      'corners': [
        [.1, .1],
        [.9, .1],
        [.9, .9],
        [.1, .9],
      ],
      'filter': 'gray',
    });
    expect(cropped['width'], lessThan(180));
    expect(cropped['height'], lessThan(240));
    final gray = img.decodeJpg(cropped['bytes'] as Uint8List)!.getPixel(60, 60);
    expect((gray.r - gray.g).abs(), lessThanOrEqualTo(2));
    final turned = editScanPixels({'bytes': redacted['bytes'], 'turns': 1});
    expect(turned['width'], 240);
    expect(turned['height'], 180);
    expect(
      img.decodeJpg(turned['bytes'] as Uint8List)!.getPixel(120, 90).luminance,
      lessThan(3),
    );
    expect(
      () => editScanPixels({
        'bytes': input,
        'corners': [
          [0, 0],
          [1, 1],
          [1, 0],
          [0, 1],
        ],
      }),
      throwsA(isA<DomainError>()),
    );
  });
  test(
    'one PDF is attached to a pupil, Orga and school entry; draft pixels cleaned only after commit',
    () async {
      final orga = await repo.saveEntry(
        OrgaEntry.empty(
          pupilId: 'p',
        ).copyWith(title: 'Ausflug', body: 'Ausflug'),
      );
      final school = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.goal, 'p').patch({
          'title': 'Lesen',
          'body': 'Leseziel',
          'criterion': 'Zehn Minuten',
        }),
      );
      final d = await draft(
        fields: {
          'links': [
            DocumentLink('orga', orga.id).toJson(),
            DocumentLink('school', school.id).toJson(),
          ],
        },
      );
      final result = await saveScan(repo, files, d);
      expect(result.flag('scan'), isTrue);
      expect(result.strings('pupilIds'), ['p']);
      expect(result.rows('links'), hasLength(2));
      expect(await repo.dialogDrafts(), isEmpty);
      expect(files.values.keys, [result.text('localKey')]);
      expect(
        ScanContext(
          links: [DocumentLink('orga', orga.id)],
        ).matchesMaterial(result),
        isTrue,
      );
      expect(
        const ScanContext(pupilIds: ['p']).matchesMaterial(result),
        isTrue,
      );
      final backup = await MaterialBundle.encode(
        [result],
        files.values,
        'twelve-letters-password',
      );
      final restored = await MaterialBundle.decode(
        backup,
        'twelve-letters-password',
      );
      expect(restored.documents.single.rows('links'), result.rows('links'));
      expect(
        restored.files[result.text('localKey')],
        files.values[result.text('localKey')],
      );
    },
  );
  test(
    'invalid assignment rolls back PDF and retains the recoverable draft',
    () async {
      final d = await draft(
        fields: {
          'links': [const DocumentLink('orga', 'missing').toJson()],
        },
      );
      final before = files.values.keys.toSet();
      await expectLater(saveScan(repo, files, d), throwsA(isA<DomainError>()));
      expect(files.values.keys.toSet(), before);
      expect((await repo.dialogDrafts()).single.id, d.id);
      expect(await repo.classroomDocuments(), isEmpty);
    },
  );
  test(
    'replace removes old local PDF, stale replacement preserves both draft and newer file',
    () async {
      final first = await saveScan(repo, files, await draft());
      final edit = await draft(
        fields: {'sourceId': first.id, 'sourceRevision': first.revision},
      );
      final replaced = await saveScan(repo, files, edit, replace: true);
      expect(replaced.id, first.id);
      expect(replaced.revision, first.revision + 1);
      expect(files.values.containsKey(first.text('localKey')), isFalse);
      final stale = await draft(
        fields: {'sourceId': replaced.id, 'sourceRevision': replaced.revision},
      );
      await repo.saveClassroomDocument(
        replaced.patch({'title': 'Inzwischen geändert'}),
      );
      final keys = files.values.keys.toSet();
      await expectLater(
        saveScan(repo, files, stale, replace: true),
        throwsA(isA<StaleRevision>()),
      );
      expect(files.values.keys.toSet(), keys);
      expect((await repo.dialogDrafts()).single.id, stale.id);
    },
  );
  test(
    'copy keeps original file and associations; draft deletion removes only its pages',
    () async {
      final original = await saveScan(repo, files, await draft());
      final d = await draft(
        fields: {'sourceId': original.id, 'sourceRevision': original.revision},
      );
      final copy = await saveScan(repo, files, d);
      expect(copy.id, isNot(original.id));
      expect(files.values, hasLength(2));
      final discarded = await draft();
      await discardScan(repo, files, discarded);
      expect(files.values, hasLength(2));
      expect(await repo.dialogDrafts(), isEmpty);
    },
  );
  test('lesson occurrence scans are suggested only for that day', () async {
    final l = await repo.saveClassroomDocument(
      lesson(
        date: '2026-11-09',
        rule: const RepeatRule(frequency: 'weekly'),
      ),
    );
    final scan = await saveScan(
      repo,
      files,
      await draft(
        fields: {
          'links': [DocumentLink('lesson', l.id, date: '2026-11-09').toJson()],
        },
      ),
    );
    final docs = await repo.classroomDocuments();
    expect(
      suggestedMaterials(docs, '2026-11-09').map((d) => d.id),
      contains(scan.id),
    );
    expect(suggestedMaterials(docs, '2026-11-16'), isEmpty);
  });
  test(
    'emptying trash detaches deleted entry and keeps the pupil PDF accessible',
    () async {
      var entry = await repo.saveEntry(
        OrgaEntry.empty(
          pupilId: 'p',
        ).copyWith(title: 'Vorgang', body: 'Vorgang'),
      );
      final scan = await saveScan(
        repo,
        files,
        await draft(
          fields: {
            'links': [DocumentLink('orga', entry.id).toJson()],
          },
        ),
      );
      entry = await repo.saveEntry(entry.copyWith(deleted: true));
      await repo.maintainStorage(await repo.exportBackup(), emptyTrash: true);
      final kept = (await repo.classroomDocuments()).single;
      expect(kept.rows('links'), isEmpty);
      expect(kept.strings('pupilIds'), ['p']);
      expect(kept.text('localKey'), scan.text('localKey'));
      await repo.saveClassroomDocument(
        kept.patch({'title': 'Weiter verfügbar'}),
      );
    },
  );
  test(
    'PDF import and redaction discard hidden text, metadata and original objects',
    () async {
      final temp = Directory.systemTemp.createTempSync('flex-scan-pdf-');
      addTearDown(() => temp.deleteSync(recursive: true));
      Pdfrx.cacheDirectoryPath = temp.path;
      // flutter_tester does not resolve PDFium's background-isolate native
      // asset through the application loader. Use the actual hook-built library.
      if (Platform.isLinux) {
        Pdfrx.pdfiumModulePath = File(
          'build/native_assets/linux/libpdfium.so',
        ).absolute.path;
      }
      await pdfrxFlutterInitialize();
      final source = pw.Document(title: 'SECRET-METADATA');
      source.addPage(pw.Page(build: (_) => pw.Text('SECRET-TEXT-123456')));
      final rasterized = await importPdfPages(
        await source.save(),
        limit: 2,
      ).toList();
      final clean = editScanPixels({
        'bytes': rasterized.single,
        'redactions': [
          [0, 0, 1, 1],
        ],
      });
      final output = await scanPdf([clean['bytes'] as Uint8List]);
      final pdf = await PdfDocument.openData(output);
      try {
        expect(pdf.pages, hasLength(1));
        final text = await pdf.pages.single.loadText();
        expect(text?.fullText.trim() ?? '', isEmpty);
        expect(latin1.decode(output), isNot(contains('SECRET')));
        final rendered = await pdf.pages.single.render(
          width: 100,
          height: 140,
          fullWidth: 100,
          fullHeight: 140,
          backgroundColor: 0xffffffff,
        );
        expect(rendered, isNotNull);
        final pixels = rendered!.pixels;
        final center = (70 * 100 + 50) * 4;
        expect(pixels[center], lessThan(5));
        rendered.dispose();
      } finally {
        await pdf.dispose();
      }
      final folder = Platform.environment['FLEX_TEST_ARTIFACT_DIR'];
      if (folder != null) {
        await Directory(folder).create(recursive: true);
        await File('$folder/scanner-redacted.pdf').writeAsBytes(output);
      }
    },
  );
}
