import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flex_device/flex_device.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/scan_editor.dart';
import 'package:flex_notizbuch/ui/scan_page_editor.dart';
import 'classroom_test.dart' show classroomMemory;
import 'document_scanner_test.dart' show scannerImage;
import 'material_workspace_test.dart' show MemoryMaterialFiles;

class InterruptedScanRepository extends SqliteNotebook {
  InterruptedScanRepository() : super(classroomMemory().db);
  bool failWrite = false;
  @override
  Future<DialogDraft> saveDialogDraft(DialogDraft draft) async {
    if (failWrite) {
      failWrite = false;
      throw const DomainError('Speicherung unterbrochen');
    }
    return super.saveDialogDraft(draft);
  }
}

void main() {
  Future<NotebookController> controller() async {
    final c = NotebookController(InterruptedScanRepository());
    await c.initialize();
    await c.savePupil(const Pupil(id: 'p', name: 'Alex'));
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    return c;
  }

  Future<void> host(
    WidgetTester t,
    WidgetBuilder dialog, {
    double width = 390,
    ValueChanged<Object?>? onResult,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                final result = await showDialog<Object?>(
                  context: ctx,
                  builder: dialog,
                );
                onResult?.call(result);
              },
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Öffnen'));
    await t.pumpAndSettle();
  }

  Future<void> settleWork(WidgetTester t, bool Function() ready) async {
    for (var i = 0; i < 100; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await t.pump(const Duration(milliseconds: 40));
      if (ready()) {
        await t.pumpAndSettle();
        return;
      }
    }
    fail('Scanner did not finish processing');
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pump();
  }

  testWidgets(
    'photo capture uses photo editor, tags survive draft resume and JPG save',
    (t) async {
      final c = await controller(), files = MemoryMaterialFiles();
      DialogDraft? resume;
      ClassroomDocument? result;
      await host(
        t,
        (_) => ScanEditor(
          controller: c,
          files: files,
          draft: resume,
          scope: const ScanContext(pupilIds: ['p']),
          capturePhoto: () async => scannerImage(),
        ),
        onResult: (v) => result = v as ClassroomDocument?,
      );
      await tap(t, find.byKey(const ValueKey('scanner-photo')));
      await settleWork(
        t,
        () =>
            c.dialogDrafts.isNotEmpty &&
            (c.dialogDrafts.single.data['pages'] as List).isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await t.enterText(
        find.byKey(const ValueKey('scan-tags')),
        '#Mathe, Probe, mathe',
      );
      await tap(t, find.byKey(const ValueKey('scan-edit-page-0')));
      await settleWork(
        t,
        () => find.text('Foto 1 bearbeiten').evaluate().isNotEmpty,
      );
      expect(find.text('Spiegeln'), findsOneWidget);
      await tap(t, find.text('Filter'));
      await t.pumpAndSettle();
      expect(find.text('Warm'), findsOneWidget);
      expect(find.text('Sättigung'), findsOneWidget);
      await tap(t, find.text('Abbrechen').last);
      await t.pumpAndSettle();
      await tap(t, find.text('Später fortsetzen'));
      await t.pumpAndSettle();
      resume = c.dialogDrafts.single;
      expect(resume.data['tags'], ['Mathe', 'Probe']);
      await t.tap(find.text('Öffnen'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('scan-tags')))
            .controller!
            .text,
        'Mathe, Probe',
      );
      await tap(t, find.byKey(const ValueKey('save-scan')));
      await settleWork(t, () => result != null);
      expect(result!.text('extension'), 'jpg');
      expect(result!.strings('tags'), ['Mathe', 'Probe']);
      expect(result!.strings('pupilIds'), ['p']);
      expect(c.dialogDrafts, isEmpty);
      expect(files.values, hasLength(1));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final cameraFails in [false, true]) {
    testWidgets(
      'document scanner falls back without Play Services; camera fails=$cameraFails',
      (t) async {
        final c = await controller(), files = MemoryMaterialFiles();
        final calls = <String>[];
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FlexDevice.channel, (call) async {
              calls.add(call.method);
              if (call.method == 'scanDocument')
                throw PlatformException(
                  code: 'scanner_unavailable',
                  message: 'Google Play-Dienste nicht verfügbar.',
                );
              if (call.method == 'capturePhoto') {
                if (cameraFails)
                  throw PlatformException(
                    code: 'photo_unavailable',
                    message:
                        'Die Kamera konnte nicht geöffnet werden. Alternativ ein Bild aus Dateien hinzufügen.',
                  );
                return {'token': 'fallback-photo', 'bytes': scannerImage()};
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(FlexDevice.channel, null),
        );
        await host(t, (_) => ScanEditor(controller: c, files: files));
        await tap(t, find.byKey(const ValueKey('scanner-camera')));
        if (cameraFails) {
          await t.pumpAndSettle();
          expect(
            find.textContaining('Die Kamera konnte nicht geöffnet werden.'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Speichern oder Laden fehlgeschlagen'),
            findsNothing,
          );
        } else {
          await settleWork(
            t,
            () =>
                calls.contains('finishPhoto') &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          final data = c.dialogDrafts.single.data;
          expect(data['outputFormat'], 'pdf');
          expect(
            ScanPage.fromJson(
              Json.from((data['pages'] as List).single as Map),
            ).photo,
            false,
          );
          expect(data['capturePending'], false);
        }
        expect(calls, containsAllInOrder(['scanDocument', 'capturePhoto']));
        expect(
          find.textContaining('Automatische Dokumenterkennung nicht verfügbar'),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets(
    'interrupted native photo is recovered once and acknowledged only after durable draft',
    (t) async {
      final c = await controller(), files = MemoryMaterialFiles();
      DialogDraft? resume;
      var acknowledged = 0;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(FlexDevice.channel, (call) async {
            if (call.method == 'capturePhoto') {
              expect(c.dialogDrafts.single.data['capturePending'], true);
              throw PlatformException(code: 'activity_closed');
            }
            if (call.method == 'recoverPhoto') {
              return {'token': 'captured-photo', 'bytes': scannerImage()};
            }
            if (call.method == 'finishPhoto') {
              final stored = (await c.repository.dialogDrafts()).single;
              final page = (stored.data['pages'] as List).single;
              expect(page['captureToken'], 'captured-photo');
              expect(await files.exists(page['key'] as String), true);
              acknowledged++;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FlexDevice.channel, null),
      );
      await host(
        t,
        (_) => ScanEditor(controller: c, files: files, draft: resume),
      );
      await tap(t, find.byKey(const ValueKey('scanner-photo')));
      await t.pumpAndSettle();
      await tap(t, find.text('Später fortsetzen'));
      await t.pumpAndSettle();
      resume = c.dialogDrafts.single;
      await t.tap(find.text('Öffnen'));
      await t.pump();
      await settleWork(
        t,
        () =>
            acknowledged == 1 &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(c.dialogDrafts.single.data['capturePending'], false);
      expect(c.dialogDrafts.single.data['pages'] as List, hasLength(1));
      await tap(t, find.text('Später fortsetzen'));
      await t.pumpAndSettle();
      resume = c.dialogDrafts.single;
      await t.tap(find.text('Öffnen'));
      await t.pumpAndSettle();
      expect(acknowledged, 1);
      expect(files.values, hasLength(1));
      await t.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'import, naming, focus, resume, reorder and PDF save preserve pupil context',
    (t) async {
      final c = await controller(), files = MemoryMaterialFiles();
      ClassroomDocument? result;
      DialogDraft? resume;
      await host(
        t,
        (_) => ScanEditor(
          controller: c,
          files: files,
          draft: resume,
          scope: const ScanContext(
            pupilIds: ['p'],
            title: 'Alex',
            category: 'pupilWork',
          ),
          pickFiles: () async => [
            XFile.fromData(scannerImage(), name: 'one.jpg'),
            XFile.fromData(
              scannerImage(width: 240, height: 180),
              name: 'two.jpg',
            ),
          ],
        ),
        onResult: (v) => result = v as ClassroomDocument?,
      );
      await tap(t, find.byKey(const ValueKey('scanner-import')));
      await settleWork(
        t,
        () =>
            c.dialogDrafts.isNotEmpty &&
            (c.dialogDrafts.single.data['pages'] as List).length == 2 &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      final keys = List<Json>.from(
        c.dialogDrafts.single.data['pages'] as List,
      ).map((p) => p['key']).toList();
      await t.enterText(
        find.byKey(const ValueKey('scan-title')),
        'Alex – Arbeitsprobe',
      );
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(
        t
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tap(t, find.text('Später fortsetzen'));
      await t.pumpAndSettle();
      resume = c.dialogDrafts.single;
      expect(resume.data['title'], 'Alex – Arbeitsprobe');
      expect(files.values, hasLength(2));
      await t.tap(find.text('Öffnen'));
      await t.pumpAndSettle();
      await tap(t, find.byTooltip('Seite nach hinten').first);
      await t.pumpAndSettle();
      expect(
        (c.dialogDrafts.single.data['pages'] as List).first['key'],
        keys.last,
      );
      await tap(t, find.byKey(const ValueKey('save-scan')));
      await settleWork(t, () => result != null);
      expect(result!.strings('pupilIds'), ['p']);
      expect(result!.text('documentType'), 'pupilWork');
      expect(result!.number('pageCount'), 2);
      expect(c.dialogDrafts, isEmpty);
      expect(files.values.keys, [result!.text('localKey')]);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'metadata failure keeps page bytes and a close retry persists the draft',
    (t) async {
      final c = await controller(), files = MemoryMaterialFiles();
      await host(
        t,
        (_) => ScanEditor(
          controller: c,
          files: files,
          pickFiles: () async => [
            XFile.fromData(scannerImage(), name: 'one.jpg'),
          ],
        ),
      );
      (c.repository as InterruptedScanRepository).failWrite = true;
      await tap(t, find.byKey(const ValueKey('scanner-import')));
      await settleWork(
        t,
        () => find.text('Speicherung unterbrochen').evaluate().isNotEmpty,
      );
      expect(files.values, hasLength(1));
      await tap(t, find.text('Später fortsetzen'));
      await t.pumpAndSettle();
      final page = (c.dialogDrafts.single.data['pages'] as List).single;
      expect(await files.exists(page['key'] as String), isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'camera cancellation retains content and deleting an open draft removes its pages',
    (t) async {
      final c = await controller(), files = MemoryMaterialFiles();
      var limit = 0;
      await host(
        t,
        (_) => ScanEditor(
          controller: c,
          files: files,
          capturePages: (n) async {
            limit = n;
            return null;
          },
          pickFiles: () async => [
            XFile.fromData(scannerImage(), name: 'one.jpg'),
          ],
        ),
      );
      await tap(t, find.byKey(const ValueKey('scanner-import')));
      await settleWork(
        t,
        () =>
            c.dialogDrafts.isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await tap(t, find.byKey(const ValueKey('scanner-camera')));
      await t.pumpAndSettle();
      expect(limit, 24);
      expect(files.values, hasLength(1));
      await tap(t, find.byTooltip('Scanentwurf löschen'));
      await t.pumpAndSettle();
      await tap(t, find.text('Löschen').last);
      await t.pumpAndSettle();
      expect(c.dialogDrafts, isEmpty);
      expect(files.values, isEmpty);
      expect(t.takeException(), isNull);
    },
  );

  for (final dimensions in [const Size(180, 240), const Size(240, 180)]) {
    testWidgets(
      'redaction matches image coordinates on 320px screen: $dimensions',
      (t) async {
        Map<String, dynamic>? result;
        await host(
          t,
          (_) => ScanPageEditor(
            bytes: scannerImage(
              width: dimensions.width.toInt(),
              height: dimensions.height.toInt(),
            ),
            pageNumber: 1,
            width: dimensions.width.toInt(),
            height: dimensions.height.toInt(),
          ),
          width: 320,
          onResult: (v) => result = v as Map<String, dynamic>?,
        );
        await tap(t, find.text('Schwärzen'));
        await t.pumpAndSettle();
        final canvas = find.byKey(const ValueKey('scan-page-canvas'));
        await t.ensureVisible(canvas);
        await t.pumpAndSettle();
        final box = t.getRect(canvas);
        expect(
          box.width / box.height,
          closeTo(dimensions.width / dimensions.height, .01),
        );
        final gesture = await t.startGesture(
          box.topLeft + Offset(box.width * .2, box.height * .2),
        );
        await gesture.moveTo(
          box.topLeft + Offset(box.width * .8, box.height * .8),
        );
        await gesture.up();
        await t.pump();
        await tap(t, find.text('Übernehmen'));
        await settleWork(t, () => result != null);
        final image = img.decodeJpg(result!['bytes'] as Uint8List)!;
        expect(
          image.getPixel(image.width ~/ 2, image.height ~/ 2).r,
          lessThan(5),
        );
        expect(image.getPixel(3, 3).r, greaterThan(220));
        expect(t.takeException(), isNull);
      },
    );
  }
}
