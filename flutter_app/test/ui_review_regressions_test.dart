import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/ui/scan_editor.dart';
import 'package:flex_notizbuch/ui/calendar_page.dart';
import 'package:flex_notizbuch/ui/compact_switch.dart';
import 'classroom_test.dart' show classroomMemory;
import 'document_scanner_test.dart' show scannerImage;
import 'material_workspace_test.dart' show MemoryMaterialFiles, material;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    final temp = Directory.systemTemp.createTempSync('flex-review-pdf-');
    addTearDown(() => temp.deleteSync(recursive: true));
    Pdfrx.cacheDirectoryPath = temp.path;
    if (Platform.isLinux) {
      Pdfrx.pdfiumModulePath = File(
        'build/native_assets/linux/libpdfium.so',
      ).absolute.path;
    }
    await pdfrxFlutterInitialize();
  });
  Future<void> waitFor(WidgetTester t, bool Function() ready) async {
    for (var i = 0; i < 600; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump(const Duration(milliseconds: 30));
      if (ready()) {
        await t.pump(const Duration(milliseconds: 300));
        return;
      }
    }
    fail('Operation did not finish');
  }

  for (final extension in ['jpg', 'pdf']) {
    for (final mode in ['unchanged', 'edited', 'keep', 'save']) {
      testWidgets(
        '$extension editing session: $mode keeps only intentional drafts and original bytes',
        (t) async {
          final repo = classroomMemory();
          final c = NotebookController(repo);
          await c.initialize();
          final files = MemoryMaterialFiles();
          var bytes = scannerImage();
          if (extension == 'pdf') {
            final pdf = pw.Document();
            pdf.addPage(pw.Page(build: (_) => pw.Image(pw.MemoryImage(bytes))));
            bytes = await pdf.save();
          }
          await files.write('original', bytes);
          final source = await repo.saveClassroomDocument(
            material(
              'Original',
              fields: {
                'extension': extension,
                'localKey': 'original',
                'url': '',
                'size': bytes.length,
              },
            ),
          );
          await c.reload();
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: ctx,
                      builder: (_) => ScanEditor(
                        controller: c,
                        files: files,
                        source: source,
                      ),
                    ),
                    child: const Text('Start'),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('Start'));
          await waitFor(
            t,
            () =>
                find
                    .byKey(const ValueKey('scan-edit-page-0'))
                    .evaluate()
                    .isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          expect(await repo.dialogDrafts(), isEmpty);
          expect(
            t.getSize(find.byKey(const ValueKey('scan-edit-page-0'))).width,
            greaterThan(280),
          );
          if (mode == 'edited') {
            await t.enterText(
              find.byKey(const ValueKey('scan-title')),
              'Geänderter Name',
            );
            await t.pump(const Duration(milliseconds: 450));
          }
          final close = mode == 'save'
              ? find.byKey(const ValueKey('save-scan'))
              : mode == 'keep'
              ? find.text('Später fortsetzen')
              : find.byTooltip('Schließen · Änderungen als Entwurf sichern');
          await t.ensureVisible(close);
          await t.tap(close);
          await waitFor(t, () => find.byType(ScanEditor).evaluate().isEmpty);
          final drafts = await repo.dialogDrafts();
          expect(drafts.length, mode == 'unchanged' || mode == 'save' ? 0 : 1);
          expect(files.values['original'], bytes);
          expect(
            (await repo.classroomDocuments())
                .firstWhere((d) => d.id == source.id)
                .revision,
            source.revision,
          );
          if (mode == 'unchanged') expect(files.values.keys, ['original']);
          if (mode == 'edited') {
            expect(drafts.single.data['title'], 'Geänderter Name');
          }
          if (mode == 'save') {
            expect((await repo.classroomDocuments()).length, 2);
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          c.dispose();
          await repo.close();
        },
      );
    }
  }

  test(
    'display choices survive controller restart and backup without dropping data',
    () async {
      final repo = classroomMemory();
      final c = NotebookController(repo);
      await c.initialize();
      await c.savePupil(const Pupil(id: 'p', name: 'Alex'));
      await c.saveAppearance(
        c.appearance.patch({
          'materialGrid': true,
          'materialSort': 'format',
          'pupilCompact': true,
        }),
      );
      final backup = await repo.exportBackup();
      c.dispose();
      final next = NotebookController(repo);
      await next.reload();
      expect(next.appearance.materialGrid, isTrue);
      expect(next.appearance.materialSort, 'format');
      expect(next.appearance.pupilCompact, isTrue);
      expect(next.pupils.single.name, 'Alex');
      final other = classroomMemory();
      await other.initialize();
      await other.restoreBackup(backup);
      expect((await other.appearance()).materialSort, 'format');
      expect(
        Appearance.fromJson({'materialSort': 'unsupported'}).materialSort,
        'recent',
      );
      next.dispose();
      await repo.close();
      await other.close();
    },
  );

  test(
    'return list general files do not also include pupil-specific scans',
    () {
      const link = DocumentLink('classroom', 'r');
      const general = ScanContext(links: [link], unassignedPupilsOnly: true);
      final common = material(
        'Formular',
        fields: {
          'links': [link.toJson()],
        },
      );
      final pupil = material(
        'Antwort',
        fields: {
          'links': [link.toJson()],
          'pupilIds': ['p'],
        },
      );
      expect(general.matchesMaterial(common), isTrue);
      expect(general.matchesMaterial(pupil), isFalse);
      expect(
        const ScanContext(
          links: [link],
          pupilIds: ['p'],
        ).matchesMaterial(pupil),
        isTrue,
      );
    },
  );

  testWidgets('switch label toggles and exposes one named semantic control', (
    t,
  ) async {
    var value = false;
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      MaterialApp(
        home: Material(
          child: StatefulBuilder(
            builder: (ctx, update) => CompactSwitchListTile(
              title: const Text('Reaktion / Unterstützung'),
              value: value,
              onChanged: (v) => update(() => value = v),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Reaktion / Unterstützung'));
    await t.pumpAndSettle();
    expect(value, isTrue);
    expect(find.bySemanticsLabel('Reaktion / Unterstützung'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Today brings the current time into the day viewport', (t) async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            controller: c,
            clock: () => DateTime(2026, 11, 9, 15, 30),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('calendar-today')));
    await t.pumpAndSettle();
    final position = t.getCenter(
      find.byKey(const ValueKey('calendar-now-line')),
    );
    expect(position.dy, inInclusiveRange(120, 760));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
    await c.repository.close();
  });
}
