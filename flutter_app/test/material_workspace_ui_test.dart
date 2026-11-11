import 'support/app_test_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/material_library.dart';
import 'package:flex_notizbuch/ui/material_thumbnail.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;

void main() {
  setUpAll(loadAppTestFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('at.flowzym.flex_notizbuch/device'),
          (_) async => false,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('at.flowzym.flex_notizbuch/device'),
          null,
        );
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

  Future<void> host(
    WidgetTester t,
    Widget Function(BuildContext) child, {
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlexSans'),
        builder: (ctx, w) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: Scaffold(body: Builder(builder: child)),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    // Filtering can change the list extent and schedule a scroll correction.
    // Wait for that layout before choosing the real touch position.
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    final folder = Platform.environment['FLEX_TEST_ARTIFACT_DIR'];
    if (folder == null) return;
    await t.runAsync(() async {
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(folder).create(recursive: true);
      await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'file title opens directly and edit/star controls have independent targets',
    (t) async {
      var opened = 0, edited = 0, favorite = 0;
      await host(
        t,
        (_) => MaterialRow(
          material: material('Arbeitsblatt'),
          onOpen: () => opened++,
          onEdit: () => edited++,
          onFavorite: () => favorite++,
        ),
      );
      await tap(t, find.text('Arbeitsblatt'));
      expect(opened, 1);
      await tap(t, find.byTooltip('Materialangaben und Aktionen'));
      expect(edited, 1);
      expect(opened, 1);
      await tap(t, find.byTooltip('Als Favorit merken'));
      expect(favorite, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'library retains search when switching views and reloading data',
    (t) async {
      final c = await controller();
      await c.saveClassroom(material('Brüche'));
      await c.saveClassroom(material('Englisch'));
      await host(t, (_) => MaterialLibraryPage(controller: c));
      t
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const PageStorageKey('materials-library')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      await tap(t, find.byTooltip('Materialien suchen'));
      await t.enterText(find.byType(TextField), 'Brüche');
      await t.pumpAndSettle();
      expect(find.text('Englisch'), findsNothing);
      await tap(t, find.widgetWithText(ChoiceChip, 'Pakete'));
      await tap(t, find.widgetWithText(ChoiceChip, 'Dateien'));
      await c.reload();
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Brüche',
      );
      expect(find.text('Englisch'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'multi-selection assigns two files to pupil atomically without duplication',
    (t) async {
      final c = await controller();
      await c.repository.savePupil(const Pupil(id: 'p', name: 'Kind'));
      await c.reload();
      final a = material('A'), b = material('B');
      await c.repository.saveClassroomDocuments([a, b]);
      await c.reload();
      await host(t, (_) => MaterialLibraryPage(controller: c));
      await tap(t, find.byTooltip('Mehrere Dateien auswählen'));
      await tap(t, find.text('Alle angezeigten auswählen'));
      expect(find.text('2 ausgewählt'), findsOneWidget);
      await tap(t, find.widgetWithText(OutlinedButton, 'Schüler'));
      await tap(t, find.text('Kind'));
      await tap(t, find.text('Übernehmen'));
      expect(
        c.classroom.where((d) => d.strings('pupilIds').contains('p')).length,
        2,
      );
      expect(find.text('2 ausgewählt'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('material format, sort, layout and reset work together', (
    t,
  ) async {
    final c = await controller();
    final pdf = material('Alpha Arbeitsblatt');
    final docx = material('Beta Vorlage', fields: {'extension': 'docx'});
    await c.repository.saveClassroomDocuments([docx, pdf]);
    await c.reload();
    await host(
      t,
      (_) => MaterialLibraryPage(controller: c, externalView: 'files'),
    );
    await tap(t, find.byKey(const ValueKey('material-sort')));
    await tap(t, find.widgetWithText(CheckedPopupMenuItem<String>, 'Name A–Z'));
    final a = t.getTopLeft(find.byKey(ValueKey(pdf.id)));
    final b = t.getTopLeft(find.byKey(ValueKey(docx.id)));
    expect(a.dy < b.dy || a.dy == b.dy && a.dx < b.dx, isTrue);
    expect(find.byKey(const ValueKey('material-list')), findsOneWidget);
    await tap(t, find.byTooltip('Rasteransicht'));
    await tap(t, find.byTooltip('Listenansicht'));
    expect(find.byKey(const ValueKey('material-list')), findsOneWidget);
    await tap(t, find.widgetWithText(TextButton, 'Filter'));
    await tap(t, find.byKey(const ValueKey('material-format-docx')));
    expect(find.byKey(ValueKey(pdf.id)), findsNothing);
    expect(find.byKey(ValueKey(docx.id)), findsOneWidget);
    t
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('materials-library')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await t.pumpAndSettle();
    await tap(t, find.byTooltip('Materialien suchen'));
    await t.enterText(find.byType(TextField), 'Kein Treffer');
    await t.pumpAndSettle();
    await tap(t, find.text('Suche und Filter zurücksetzen'));
    expect(find.byKey(ValueKey(pdf.id)), findsOneWidget);
    expect(find.byKey(ValueKey(docx.id)), findsOneWidget);
    expect(find.byKey(const ValueKey('material-list')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'today shortcut preserves other prepared files and favorite is independent',
    (t) async {
      final c = await controller();
      final a = material('Arbeitsblatt'), b = material('Vorlage');
      final today = dateOnly(DateTime.now());
      await c.repository.saveClassroomDocuments([
        a,
        b,
        prepareMaterials([], today, [b.id]),
      ]);
      await c.reload();
      await host(
        t,
        (_) => MaterialLibraryPage(controller: c, externalView: 'files'),
      );
      Finder action(String tooltip) => find.descendant(
        of: find.byKey(ValueKey(a.id)),
        matching: find.byTooltip(tooltip),
      );
      await tap(t, action('Für heute bereitlegen'));
      expect(preparationFor(c.classroom, today).strings('materialIds'), [
        b.id,
        a.id,
      ]);
      await tap(t, action('Als Favorit merken'));
      expect(
        c.classroom.singleWhere((d) => d.id == a.id).flag('favorite'),
        isTrue,
      );
      await tap(t, action('Von heute entfernen'));
      expect(preparationFor(c.classroom, today).strings('materialIds'), [b.id]);
      expect(c.classroom.singleWhere((d) => d.id == a.id).deleted, isFalse);
      await tap(t, find.widgetWithText(FilterChip, 'Favoriten'));
      expect(find.byKey(ValueKey(a.id)), findsOneWidget);
      expect(find.byKey(ValueKey(b.id)), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'material trash can restore a file without exposing preparation actions',
    (t) async {
      final c = await controller();
      final a = material('Gelöschtes Material').patch({'deleted': true});
      await c.saveClassroom(a);
      await host(
        t,
        (_) => MaterialLibraryPage(
          controller: c,
          externalView: 'files',
          initialTrash: true,
        ),
      );
      expect(find.byTooltip('Für heute bereitlegen'), findsNothing);
      await tap(t, find.byTooltip('Wiederherstellen'));
      expect(c.classroom.singleWhere((d) => d.id == a.id).deleted, isFalse);
      expect(find.byKey(ValueKey(a.id)), findsNothing);
      await tap(t, find.widgetWithText(FilterChip, 'Papierkorb'));
      expect(find.byKey(ValueKey(a.id)), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'large libraries build previews near the viewport and remain scrollable',
    (t) async {
      final c = await controller();
      final docs = [
        for (var i = 0; i < 100; i++)
          material('Material ${i.toString().padLeft(3, '0')}'),
      ];
      await c.repository.saveClassroomDocuments(docs);
      await c.reload();
      await host(
        t,
        (_) => MaterialLibraryPage(controller: c, externalView: 'files'),
      );
      await tap(t, find.byKey(const ValueKey('material-sort')));
      await tap(
        t,
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Name A–Z'),
      );
      expect(find.byType(MaterialThumbnail).evaluate().length, lessThan(20));
      await t.scrollUntilVisible(
        find.byKey(ValueKey(docs.last.id)),
        600,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('materials-library')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey(docs.last.id)), findsOneWidget);
      expect(find.byType(MaterialThumbnail).evaluate().length, lessThan(20));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'prepared day removes reference only; next day has a separate selection',
    (t) async {
      final c = await controller();
      final a = material('A'), b = material('B');
      await c.repository.saveClassroomDocuments([
        a,
        b,
        prepareMaterials([], '2026-11-09', [a.id, b.id]),
      ]);
      await c.reload();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showPreparedMaterials(ctx, c, date: '2026-11-09'),
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.byTooltip('Vom Tag entfernen').first);
      expect(preparationFor(c.classroom, '2026-11-09').strings('materialIds'), [
        b.id,
      ]);
      expect(c.classroom.firstWhere((d) => d.id == a.id).deleted, isFalse);
      await tap(t, find.byTooltip('Nächster Tag'));
      expect(
        find.text('Für diesen Tag ist noch nichts bereitgelegt.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'package picker expands file references and clearing does not lose other choices',
    (t) async {
      final c = await controller();
      final a = material('A'), b = material('B'), other = material('C');
      final p = ClassroomDocument.create(
        ClassroomKind.materialSet,
        'Mathepaket',
        {
          'materialIds': [a.id, b.id],
        },
      );
      await c.repository.saveClassroomDocuments([a, b, other, p]);
      await c.reload();
      List<String>? result;
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () async {
            result = await chooseMaterials(ctx, c, [other.id]);
          },
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.text('Mathepaket'));
      await tap(t, find.text('Übernehmen'));
      expect(result!.toSet(), {a.id, b.id, other.id});
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'pupil unlink keeps shared material and package accessible elsewhere',
    (t) async {
      final c = await controller();
      const p = Pupil(id: 'p', name: 'Kind');
      await c.repository.savePupil(p);
      await c.repository.savePupil(const Pupil(id: 'q', name: 'Anderes Kind'));
      final m = material(
        'Lernplan',
        fields: {
          'pupilIds': ['p', 'q'],
        },
      );
      await c.repository.saveClassroomDocument(m);
      await c.reload();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showPupilMaterials(ctx, c, p),
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.byTooltip('Schülerzuordnung entfernen'));
      expect(c.classroom.single.strings('pupilIds'), ['q']);
      expect(c.classroom.single.deleted, isFalse);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'plan editor saves minimal name and keeps text focus through autosave',
    (t) async {
      final c = await controller();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showClassroomEditor(ctx, c, ClassroomKind.plan),
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      final field = find.widgetWithText(TextFormField, 'Bezeichnung');
      await t.enterText(field, 'Woche 1');
      await t.pump(const Duration(seconds: 2));
      expect(t.testTextInput.isVisible, isTrue);
      await tap(t, find.widgetWithText(FilledButton, 'Speichern'));
      expect(c.classroom.single.title, 'Woche 1');
      expect(c.classroom.single.text('status'), 'planned');
      expect(await c.repository.dialogDrafts(), isEmpty);
      expect(t.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('material view and selection fit phone at text scale $scale', (
      t,
    ) async {
      final c = await controller();
      await c.saveClassroom(
        material(
          'Langer Titel für ein differenziertes Arbeitsblatt',
          fields: {'subject': 'Mathematik', 'documentType': 'worksheet'},
        ),
      );
      await host(t, (_) => MaterialLibraryPage(controller: c), scale: scale);
      await tap(t, find.byTooltip('Mehrere Dateien auswählen'));
      expect(t.takeException(), isNull);
      await tap(t, find.text('Fertig'));
      await tap(t, find.widgetWithText(ChoiceChip, 'Planungen'));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('prepared dialog retains title/close and fits large text', (
    t,
  ) async {
    final c = await controller();
    await host(
      t,
      (ctx) => TextButton(
        onPressed: () => showPreparedMaterials(ctx, c, date: '2026-11-09'),
        child: const Text('Open'),
      ),
      scale: 2,
    );
    await tap(t, find.text('Open'));
    expect(find.text('Bereitgelegt'), findsOneWidget);
    expect(find.byTooltip(RegExp(r'^(Schließen.*|Zurück)$')), findsOneWidget);
    expect(t.takeException(), isNull);
    await tap(t, find.byTooltip(RegExp(r'^(Schließen.*|Zurück)$')));
    expect(find.text('Bereitgelegt'), findsNothing);
  });

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0), (1200.0, 1.0)]) {
    testWidgets(
      'actual app material screen and prepared day screenshots $width/$scale',
      (t) async {
        final c = await controller();
        for (final (name, subject, type) in [
          ('Brüche – Übungsblatt', 'Mathematik', 'worksheet'),
          ('Past tense – Wochenplan', 'Englisch', 'weekPlan'),
          ('Elterninformation Wandertag', '', 'parentInfo'),
        ]) {
          await c.saveClassroom(
            material(name, fields: {'subject': subject, 'documentType': type}),
          );
        }
        final docs = c.classroom;
        await c.saveClassroom(
          prepareMaterials(
            docs,
            dateOnly(DateTime.now()),
            docs.take(2).map((d) => d.id),
          ),
        );
        t.view.physicalSize = Size(width, 844);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: FlexApp(controller: c),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('bottom-3')));
        await t.pumpAndSettle();
        await capture(t, key, 'materialien-${width.toInt()}-${scale.toInt()}');
        expect(find.byKey(const ValueKey('material-list')), findsOneWidget);
        await tap(t, find.byTooltip('Rasteransicht'));
        await tap(t, find.byTooltip('Listenansicht'));
        await capture(
          t,
          key,
          'materialien-liste-${width.toInt()}-${scale.toInt()}',
        );
        await t.drag(
          find.byKey(const PageStorageKey('materials-library')),
          const Offset(0, 1600),
        );
        await t.pumpAndSettle();
        await tap(t, find.widgetWithText(TextButton, 'Filter'));
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('material-sort')),
          160,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('materials-library')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tap(t, find.byKey(const ValueKey('material-sort')));
        await tap(t, find.widgetWithText(CheckedPopupMenuItem<String>, 'Fach'));
        expect(t.takeException(), isNull);
        await tap(t, find.byKey(const ValueKey('context-3-1')));
        await tap(t, find.text('2 Unterlagen bereitgelegt'));
        await capture(t, key, 'bereitgelegt-${width.toInt()}-${scale.toInt()}');
        expect(t.takeException(), isNull);
      },
    );
  }
}
