import 'package:flex_notizbuch/ui/prototype_navigation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/domain/timetable.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/backup_dialog.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/option_bar.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/ui_audit_data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUp(() {
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'at.flowzym.flex_notizbuch/device',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });
  tearDown(() {
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'at.flowzym.flex_notizbuch/device',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });
  setUpAll(() async {
    for (final font in {
      'FlexSans': 'assets/fonts/Selawik-Regular.ttf',
      'FlexSerif': 'assets/fonts/Gelasio-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  Future<NotebookController> controller() async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    return c;
  }

  Future<GlobalKey> host(
    WidgetTester t,
    NotebookController c, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: FlexApp(controller: c),
      ),
    );
    await t.runAsync(
      () => precacheImage(
        const AssetImage(FlexBackground.defaultDarkImage),
        t.element(find.byType(FlexBackground).first),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    expect(t.takeException(), isNull, reason: name);
    final dir = Platform.environment['FLEX_RENDER_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final view in [
    (390.0, 844.0, 1.0, 'dark'),
    (320.0, 740.0, 1.8, 'light'),
    (768.0, 1024.0, 1.0, 'light'),
    (1280.0, 900.0, 1.0, 'dark'),
  ]) {
    testWidgets(
      'More pills keep all labels inside their touch targets with large text',
      (t) async {
        t.view.physicalSize = const Size(320, 740);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        const pages = {
          0: 'Weitere',
          1: 'Archiv',
          2: 'Papierkorb',
          3: 'Daten',
          4: 'Einstellungen',
          5: 'Scanner',
        };
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'FlexSans'),
            home: Scaffold(
              body: FlexPagePills(
                selected: 4,
                pages: pages,
                keyPrefix: 'more-check',
                onSelected: (_) {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        for (final entry in pages.entries) {
          final label = t.getRect(find.text(entry.value));
          final button = t.getRect(
            find.byKey(ValueKey('more-check-${entry.key}')),
          );
          expect(label.top, greaterThanOrEqualTo(button.top));
          expect(label.bottom, lessThanOrEqualTo(button.bottom));
          expect(button.height, greaterThanOrEqualTo(40));
        }
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'populated navigation and editors remain usable at ${view.$1}/${view.$3}/${view.$4}',
      (t) async {
        final c = await controller();
        await seedUiAudit(c);
        await c.saveAppearance(c.appearance.patch({'mode': view.$4}));
        final key = await host(
          t,
          c,
          size: Size(view.$1, view.$2),
          scale: view.$3,
        );
        final suffix = '${view.$1.toInt()}-${view.$3}-${view.$4}';
        for (final destination in [(1, 3), (0, 3), (2, 3), (3, 4), (4, 6)]) {
          await tap(t, find.byKey(ValueKey('bottom-${destination.$1}')));
          for (var tab = 0; tab < destination.$2; tab++) {
            await tap(
              t,
              find.byKey(
                ValueKey(
                  destination.$1 == 1
                      ? 'page-$tab'
                      : 'context-${destination.$1}-$tab',
                ),
              ),
            );
            await capture(t, key, 'page-${destination.$1}-$tab-$suffix');
          }
        }
        await tap(t, find.byKey(const ValueKey('bottom-1')));
        await tap(t, find.byKey(const ValueKey('page-1')));
        final ctx = t.element(find.byType(Scaffold).first);
        for (final kind in SchoolKind.values) {
          unawaited(
            showDialog<void>(
              context: ctx,
              builder: (_) => SchoolEditor(
                controller: c,
                record: c.records.firstWhere((r) => r.kind == kind),
              ),
            ),
          );
          await t.pumpAndSettle();
          await capture(t, key, 'editor-${kind.name}-$suffix');
          await tap(t, find.byKey(const ValueKey('cancel-editor')));
        }
        for (final kind in ['note', 'task', 'appointment']) {
          unawaited(
            showDialog<void>(
              context: ctx,
              builder: (_) => OrgaEditor(
                controller: c,
                entry: OrgaEntry.empty(pupilId: 'audit-p0'),
              ),
            ),
          );
          await t.pumpAndSettle();
          await tap(t, find.byKey(ValueKey('orga-kind-$kind')));
          await capture(t, key, 'editor-$kind-$suffix');
          await t.enterText(
            find.byKey(const ValueKey('orga-note')),
            'Audit $kind',
          );
          t.view.viewInsets = const FakeViewPadding(bottom: 280);
          await t.pumpAndSettle();
          await t.ensureVisible(find.byKey(const ValueKey('orga-note')));
          await capture(t, key, 'keyboard-$kind-$suffix');
          await tap(t, find.byKey(const ValueKey('cancel-editor')));
          t.view.resetViewInsets();
          await t.pumpAndSettle();
        }
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'import into a fresh app with its timetable merges and preserves the timetable',
    (t) async {
      final target = await controller(), source = await controller();
      await initializeFlexTimetable(target.repository);
      await target.reload();
      final before = target.classroom.map((d) => d.toJson()).toList();
      await source.savePupil(
        const Pupil(id: 'incoming', name: 'Imported example'),
      );
      final backup = await source.repository.exportBackup();
      await host(t, target);
      unawaited(
        showImportReview(
          t.element(find.byType(Scaffold).first),
          target,
          backup,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Sicherung wiederherstellen'), findsNothing);
      await tap(t, find.text('Auswahl zusammenführen'));
      expect(target.pupils.single.name, 'Imported example');
      expect(target.classroom.map((d) => d.toJson()).toList(), before);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a task shows its text once and keeps completion, scanning, attachments, history and trash reachable',
    (t) async {
      final c = await controller();
      await c.repository.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Kopien vorbereiten',
          body: 'Kopien vorbereiten',
          isTask: true,
        ),
      );
      await c.reload();
      await host(t, c);
      await tap(t, find.byKey(const ValueKey('bottom-2')));
      expect(find.text('Kopien vorbereiten'), findsOneWidget);
      for (final label in [
        'Scannen / Foto',
        'Dokumente · 0',
        'Erledigen',
        'Wiederholung',
        'Erinnerung verschieben',
        'Papierkorb',
        'Änderungen',
      ]) {
        expect(
          find.byTooltip(label).hitTestable(),
          findsOneWidget,
          reason: label,
        );
      }
      await tap(t, find.byTooltip('Erledigen'));
      expect(c.entries.single.done, isTrue);
      await tap(t, find.byTooltip('Wieder öffnen'));
      expect(c.entries.single.done, isFalse);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('backup screens show options for the chosen action', (t) async {
    final c = await controller();
    await host(t, c);
    for (final exporting in [true, false]) {
      unawaited(
        showDialog<void>(
          context: t.element(find.byType(Scaffold).first),
          builder: (_) => BackupDialog(controller: c, export: exporting),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Sicherung mit Passwort verschlüsseln'),
        exporting ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Auswahllisten aus der Sicherung übernehmen'),
        exporting ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(exporting ? 'Exportieren' : 'Datei auswählen'),
        findsOneWidget,
      );
      Navigator.pop(t.element(find.byType(BackupDialog)));
      await t.pumpAndSettle();
    }
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'large option labels stay on one line instead of breaking words',
    (t) async {
      final c = await controller();
      await host(t, c, size: const Size(320, 740), scale: 1.8);
      unawaited(
        showDialog<void>(
          context: t.element(find.byType(Scaffold).first),
          builder: (_) => OrgaEditor(controller: c, entry: OrgaEntry.empty()),
        ),
      );
      await t.pumpAndSettle();
      final bar = find.byKey(const ValueKey('orga-kind-bar'));
      expect(t.widget(bar), isA<OptionBar>());
      for (final label in ['Notiz', 'Aufgabe', 'Termin']) {
        final text = find.descendant(of: bar, matching: find.text(label));
        expect(t.getSize(text).height, lessThan(30), reason: label);
      }
      await tap(t, find.byKey(const ValueKey('orga-kind-appointment')));
      expect(
        find.byKey(const ValueKey('orga-appointment-date')),
        findsOneWidget,
      );
      await tap(t, find.byKey(const ValueKey('cancel-editor')));
      await t.pumpWidget(const SizedBox());
    },
  );
}
