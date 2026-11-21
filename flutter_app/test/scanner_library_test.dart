import 'package:flutter/material.dart';
import 'package:flex_notizbuch/ui/material_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/scanner_library.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;

void main() {
  test(
    'scanner management recognizes existing PDFs and legacy local photos',
    () {
      expect(isScannerMaterial(material('Scan', fields: {'scan': true})), true);
      expect(
        isScannerMaterial(
          material(
            'Foto',
            fields: {'extension': 'jpg', 'localKey': 'localphoto'},
          ),
        ),
        true,
      );
      expect(
        isScannerMaterial(material('Neu', fields: {'scanner': true})),
        true,
      );
      expect(isScannerMaterial(material('Arbeitsblatt')), false);
      expect(
        () => material('Invalid', fields: {'scanner': 'true'}),
        throwsA(isA<DomainError>()),
      );
    },
  );
  testWidgets(
    'library searches pupil and tags, filters formats and restores shared material',
    (t) async {
      final c = NotebookController(classroomMemory());
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await c.repository.close();
      });
      await c.savePupil(const Pupil(id: 'alex', name: 'Alex'));
      await c.saveClassroom(
        material(
          'Mathe Scan',
          fields: {
            'scan': true,
            'pupilIds': ['alex'],
            'tags': ['Probe'],
          },
        ),
      );
      await c.saveClassroom(
        material('Klassenfoto', fields: {'scanner': true, 'extension': 'jpg'}),
      );
      await c.saveClassroom(material('Unverknüpftes Material'));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScannerLibrary(controller: c)),
        ),
      );
      expect(find.text('Mathe Scan'), findsOneWidget);
      expect(find.text('Klassenfoto'), findsOneWidget);
      expect(find.text('Unverknüpftes Material'), findsNothing);
      await t.tap(find.byKey(const ValueKey('scanner-library-search-button')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Alex');
      await t.pumpAndSettle();
      expect(find.text('Mathe Scan'), findsOneWidget);
      expect(find.text('Klassenfoto'), findsNothing);
      await t.enterText(find.byType(TextField), 'Probe');
      await t.pumpAndSettle();
      expect(find.text('Mathe Scan'), findsOneWidget);
      await t.tap(find.byTooltip('In den Papierkorb'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'In den Papierkorb'));
      await t.pumpAndSettle();
      expect(
        c.classroom.singleWhere((d) => d.title == 'Mathe Scan').deleted,
        true,
      );
      expect(find.text('Mathe Scan'), findsNothing);
      await t.tap(find.text('Papierkorb'));
      await t.pumpAndSettle();
      expect(find.text('Mathe Scan'), findsOneWidget);
      await t.tap(find.byTooltip('Wiederherstellen'));
      await t.pumpAndSettle();
      expect(
        c.classroom.singleWhere((d) => d.title == 'Mathe Scan').deleted,
        false,
      );
      await t.tap(find.text('Papierkorb'));
      await t.tap(find.byTooltip('Suchtext leeren'));
      await t.pumpAndSettle();
      await t.tap(find.text('Fotos'));
      await t.pumpAndSettle();
      expect(find.text('Mathe Scan'), findsNothing);
      expect(find.text('Klassenfoto'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'grid and list share sorting, selection, additive tags and atomic trash restore',
    (t) async {
      final c = NotebookController(classroomMemory());
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await c.repository.close();
      });
      for (final name in ['Zebra', 'Alpha']) {
        await c.saveClassroom(
          material(
            name,
            fields: {
              'scanner': true,
              'tags': ['Bestehend'],
            },
          ),
        );
      }
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScannerLibrary(controller: c)),
        ),
      );
      await t.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        await t.ensureVisible(finder);
        await t.pumpAndSettle();
        await t.tap(finder);
        await t.pumpAndSettle();
      }

      await tap(find.byTooltip('Sortieren'));
      await tap(find.text('Name A–Z'));
      expect(
        t.getTopLeft(find.text('Alpha')).dx,
        lessThan(t.getTopLeft(find.text('Zebra')).dx),
      );
      await tap(find.byTooltip('Listenansicht'));
      expect(
        t.getTopLeft(find.text('Alpha')).dy,
        lessThan(t.getTopLeft(find.text('Zebra')).dy),
      );
      await tap(find.byTooltip('Mehrere auswählen'));
      await tap(find.text('Alle auswählen'));
      expect(find.text('2 ausgewählt'), findsOneWidget);
      await tap(find.text('Tags'));
      await t.enterText(
        find.widgetWithText(TextField, 'Tag hinzufügen'),
        'Neu',
      );
      await tap(find.widgetWithText(FilledButton, 'Übernehmen'));
      expect(
        c.classroom.every(
          (d) => d.strings('tags').toSet().containsAll(['Bestehend', 'Neu']),
        ),
        true,
      );
      expect(c.classroom.every((d) => d.strings('tags').length == 2), true);
      await tap(find.byTooltip('Mehrere auswählen'));
      await tap(find.text('Alle auswählen'));
      await tap(find.widgetWithText(TextButton, 'Papierkorb'));
      await tap(find.widgetWithText(FilledButton, 'In den Papierkorb'));
      expect(c.classroom.every((d) => d.deleted), true);
      await tap(find.widgetWithText(FilterChip, 'Papierkorb'));
      await tap(find.byTooltip('Mehrere auswählen'));
      await tap(find.text('Alle auswählen'));
      await tap(find.widgetWithText(TextButton, 'Wiederherstellen'));
      expect(c.classroom.every((d) => !d.deleted), true);
      expect(c.classroom.every((d) => d.strings('tags').contains('Neu')), true);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'large scan library builds previews lazily and reaches the last file',
    (t) async {
      final c = NotebookController(classroomMemory());
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await c.repository.close();
      });
      final docs = [
        for (var i = 0; i < 80; i++)
          material(
            'Scan ${i.toString().padLeft(3, '0')}',
            fields: {'scanner': true},
          ),
      ];
      await c.saveClassroomBatch(docs);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScannerLibrary(controller: c)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(MaterialThumbnail).evaluate().length, lessThan(25));
      await t.tap(find.byTooltip('Sortieren'));
      await t.pumpAndSettle();
      await t.tap(find.text('Name A–Z').last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Scan 079'),
        500,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
      await t.ensureVisible(find.text('Scan 079'));
      await t.pumpAndSettle();
      expect(
        find.byKey(ValueKey('scanner-file-${docs.last.id}')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(MaterialThumbnail).evaluate().length, lessThan(25));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('management remains usable at 320 pixels with doubled text', (
    t,
  ) async {
    final c = NotebookController(classroomMemory());
    await c.initialize();
    addTearDown(() async {
      c.dispose();
      await c.repository.close();
    });
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await c.saveClassroom(
      material(
        'Lange Dokumentbezeichnung für Schülerarbeiten',
        fields: {
          'scanner': true,
          'tags': ['Mathematik'],
        },
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScannerLibrary(controller: c)),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Listenansicht'));
    await t.tap(find.byTooltip('Listenansicht'));
    await t.pumpAndSettle();
    await t.ensureVisible(
      find.text('Lange Dokumentbezeichnung für Schülerarbeiten'),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
