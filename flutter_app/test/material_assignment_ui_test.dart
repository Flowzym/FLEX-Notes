import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/material_library.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  setUp(() {
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'at.flowzym.flex_notizbuch/device',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });
  tearDown(() {
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'at.flowzym.flex_notizbuch/device',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
  Future<NotebookController> controller() async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    await c.repository.savePupil(const Pupil(id: 'p', name: 'Anna'));
    await c.repository.savePupil(const Pupil(id: 'q', name: 'Emil'));
    await c.reload();
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    return c;
  }

  Future<void> host(
    WidgetTester t,
    Widget Function(BuildContext) child, {
    double width = 390,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 844);
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

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  testWidgets(
    'direct assignment is discoverable, optional dates are personal and survive reload',
    (t) async {
      final c = await controller();
      await c.saveClassroom(
        planPupilMaterial(material('Brüche'), 'p', '2026-10-01'),
      );
      final id = c.classroom.single.id;
      await host(
        t,
        (ctx) => Column(
          children: [
            Expanded(
              child: MaterialLibraryPage(controller: c, externalView: 'files'),
            ),
            TextButton(
              onPressed: () => showPupilMaterials(
                ctx,
                c,
                c.pupils.firstWhere((p) => p.id == 'q'),
              ),
              child: const Text('Emils Materialien'),
            ),
          ],
        ),
      );
      await tap(t, find.byKey(ValueKey('material-assign-$id')));
      await tap(t, find.byKey(const ValueKey('material-assignment-q')));
      await tap(t, find.byKey(const ValueKey('assignment-plan-q')));
      await tap(t, find.text('Übernehmen').last);
      await tap(t, find.byKey(const ValueKey('material-assignment-save')));
      await c.reload();
      expect(c.classroom, hasLength(1));
      expect(pupilMaterialDates(c.classroom.single, 'p'), ['2026-10-01']);
      final today = dateOnly(DateTime.now());
      expect(pupilMaterialDates(c.classroom.single, 'q'), [today]);
      await tap(t, find.text('Emils Materialien'));
      expect(find.byKey(ValueKey('pupil-material-$id')), findsOneWidget);
      expect(
        find.byKey(ValueKey('pupil-material-date-$id-$today')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'pupil can receive material without a date, preserving another pupil date',
    (t) async {
      final c = await controller();
      await c.saveClassroom(
        planPupilMaterial(material('Leseübung'), 'p', '2026-10-01'),
      );
      final id = c.classroom.single.id;
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showPupilMaterials(
            ctx,
            c,
            c.pupils.firstWhere((p) => p.id == 'q'),
          ),
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.byKey(const ValueKey('pupil-assign-materials')));
      await tap(t, find.text('Leseübung'));
      await tap(t, find.text('Übernehmen').last);
      await tap(t, find.byKey(const ValueKey('material-assignment-save')));
      expect(c.classroom.single.strings('pupilIds'), containsAll(['p', 'q']));
      expect(pupilMaterialDates(c.classroom.single, 'q'), isEmpty);
      expect(pupilMaterialDates(c.classroom.single, 'p'), ['2026-10-01']);
      expect(find.byKey(ValueKey('pupil-material-plan-$id')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelling assignment changes nothing; removing a date keeps the pupil',
    (t) async {
      final c = await controller();
      await c.saveClassroom(
        planPupilMaterial(
          planPupilMaterial(material('Lernplan'), 'p', '2026-10-01'),
          'q',
          '2026-11-16',
        ),
      );
      final before = c.classroom.single.toJson();
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () =>
              showMaterialAssignments(ctx, c, [c.classroom.single]),
          child: const Text('Open'),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.byKey(const ValueKey('material-assignment-p')));
      await tap(t, find.text('Abbrechen'));
      expect(c.classroom.single.toJson(), before);
      await tap(t, find.text('Open'));
      await tap(t, find.byKey(const ValueKey('assignment-date-q-2026-11-16')));
      await tap(t, find.text('Datum entfernen'));
      await tap(t, find.byKey(const ValueKey('material-assignment-save')));
      expect(c.classroom.single.strings('pupilIds'), containsAll(['p', 'q']));
      expect(pupilMaterialDates(c.classroom.single, 'q'), isEmpty);
      expect(pupilMaterialDates(c.classroom.single, 'p'), ['2026-10-01']);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'long press plans two files for one pupil and unlinking preserves the other pupil and dates',
    (t) async {
      final c = await controller();
      for (final name in ['Leseblatt', 'Wortkarten']) {
        await c.saveClassroom(
          planPupilMaterial(
            planPupilMaterial(material(name), 'q', '2030-12-01'),
            'p',
            '2026-10-05',
          ),
        );
      }
      await host(
        t,
        (ctx) => TextButton(
          onPressed: () => showPupilMaterials(
            ctx,
            c,
            c.pupils.firstWhere((p) => p.id == 'p'),
          ),
          child: const Text('Öffnen'),
        ),
      );
      await tap(t, find.text('Öffnen'));
      Future<void> select() async {
        final first = find.text('Leseblatt');
        await t.ensureVisible(first);
        await t.longPress(first);
        await t.pumpAndSettle();
        expect(find.text('1 ausgewählt'), findsOneWidget);
        await tap(t, find.byTooltip('Alle angezeigten auswählen'));
        expect(find.text('2 ausgewählt'), findsOneWidget);
      }

      await select();
      await tap(t, find.text('Unterricht planen'));
      await tap(t, find.text('Übernehmen').last);
      expect(
        c.classroom.every(
          (d) => pupilMaterialDates(d, 'p').contains(dateOnly(DateTime.now())),
        ),
        isTrue,
      );
      await select();
      await tap(t, find.text('Zuordnung lösen'));
      await tap(t, find.text('Entfernen'));
      await c.reload();
      expect(c.classroom, hasLength(2));
      for (final d in c.classroom) {
        expect(d.deleted, isFalse);
        expect(d.strings('pupilIds'), ['q']);
        expect(pupilMaterialDates(d, 'p'), isEmpty);
        expect(pupilMaterialDates(d, 'q'), ['2030-12-01']);
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('batch assignment rejects stale revisions atomically', (t) async {
    final c = await controller();
    await c.saveClassroom(material('A'));
    await c.saveClassroom(material('B'));
    await host(
      t,
      (ctx) => TextButton(
        onPressed: () => showMaterialAssignments(ctx, c, c.classroom.toList()),
        child: const Text('Open'),
      ),
    );
    await tap(t, find.text('Open'));
    await tap(t, find.byKey(const ValueKey('material-assignment-p')));
    await c.saveClassroom(
      c.classroom.last.patch({'note': 'Extern bearbeitet'}),
    );
    await tap(t, find.byKey(const ValueKey('material-assignment-save')));
    expect(c.classroom.every((m) => m.strings('pupilIds').isEmpty), isTrue);
    expect(
      c.classroom.any((m) => m.text('note') == 'Extern bearbeitet'),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('material-assignment-save')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'pupil filter finds personal and unassigned files without leaking into packages',
    (t) async {
      final c = await controller();
      await c.saveClassroom(
        material(
          'Anna Blatt',
          fields: {
            'pupilIds': ['p'],
          },
        ),
      );
      await c.saveClassroom(material('Allgemein'));
      await c.saveClassroom(
        ClassroomDocument.create(ClassroomKind.materialSet, 'Lesepaket', {}),
      );
      await host(t, (_) => MaterialLibraryPage(controller: c));
      await tap(t, find.byKey(const ValueKey('material-pupil-filter')));
      await tap(t, find.widgetWithText(CheckedPopupMenuItem<String>, 'Anna'));
      expect(find.text('Anna Blatt'), findsOneWidget);
      expect(find.text('Allgemein'), findsNothing);
      await tap(t, find.widgetWithText(ChoiceChip, 'Bereitgelegt'));
      await tap(t, find.byTooltip('Unterricht planen'));
      await tap(t, find.text('Pakete').last);
      expect(find.text('Lesepaket'), findsOneWidget);
      await tap(t, find.widgetWithText(ChoiceChip, 'Bibliothek'));
      await tap(t, find.byKey(const ValueKey('material-pupil-filter')));
      await tap(
        t,
        find.widgetWithText(
          CheckedPopupMenuItem<String>,
          'Ohne Schülerzuordnung',
        ),
      );
      expect(find.text('Allgemein'), findsOneWidget);
      expect(find.text('Anna Blatt'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'prepared search finds personal-only future days and filters the opened day',
    (t) async {
      final c = await controller();
      final date = dateOnly(DateTime.now().add(const Duration(days: 14)));
      await c.saveClassroom(planPupilMaterial(material('Brüche'), 'p', date));
      await c.saveClassroom(planPupilMaterial(material('Englisch'), 'q', date));
      await host(
        t,
        (_) => MaterialLibraryPage(controller: c, externalView: 'prepared'),
      );
      expect(find.text('Nächste Einsätze'), findsOneWidget);
      await tap(t, find.byTooltip('Materialien suchen'));
      await t.enterText(find.byType(TextField), 'Brüche');
      await t.pumpAndSettle();
      await tap(t, find.byKey(ValueKey('prepared-day-$date')));
      expect(find.widgetWithText(MaterialRow, 'Brüche'), findsOneWidget);
      expect(find.text('Englisch'), findsNothing);
      await tap(t, find.byTooltip('Alle Materialien anzeigen'));
      expect(find.text('Englisch'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'details and personal assignment fit 320px at text scale $scale',
      (t) async {
        final c = await controller();
        await c.saveClassroom(
          planPupilMaterial(
            material('Ein längeres Arbeitsblatt zum Leseverständnis'),
            'p',
            '2026-11-16',
          ),
        );
        await host(
          t,
          (ctx) => TextButton(
            onPressed: () => showMaterialDetails(ctx, c, c.classroom.single),
            child: const Text('Open'),
          ),
          width: 320,
          scale: scale,
        );
        await tap(t, find.text('Open'));
        await tap(t, find.byKey(const ValueKey('material-detail-assign')));
        await tap(t, find.byKey(const ValueKey('material-assignment-q')));
        await tap(t, find.byKey(const ValueKey('material-assignment-save')));
        expect(c.classroom.single.strings('pupilIds'), containsAll(['p', 'q']));
        expect(t.takeException(), isNull);
      },
    );
  }
}
