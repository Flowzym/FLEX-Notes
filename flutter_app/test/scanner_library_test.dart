import 'package:flutter/material.dart';
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
      await t.enterText(find.byType(TextField), '');
      await t.tap(find.text('Fotos'));
      await t.pumpAndSettle();
      expect(find.text('Mathe Scan'), findsNothing);
      expect(find.text('Klassenfoto'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
