import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/pupil_card.dart';
import 'package:flex_notizbuch/ui/pupil_workspace.dart';
import 'package:flex_notizbuch/ui/quick_add.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  testWidgets(
    'wide pupil list keeps selected detail beside it, narrow opens dialog',
    (t) async {
      final c = NotebookController(classroomMemory());
      await c.initialize();
      addTearDown(() async {
        c.dispose();
        await c.repository.close();
      });
      await c.savePupil(const Pupil(id: 'a', name: 'Anna'));
      await c.savePupil(const Pupil(id: 'b', name: 'Ben'));
      await c.saveRecord(
        SchoolRecord.empty(
          SchoolKind.social,
          'a',
        ).patch({'body': 'Annas Eintrag'}),
      );
      await c.saveRecord(
        SchoolRecord.empty(
          SchoolKind.work,
          'b',
        ).patch({'body': 'Bens Eintrag'}),
      );
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(FlexApp(controller: c));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pupil-master-detail')), findsOneWidget);
      expect(find.byType(QuickAddButton), findsOneWidget);
      expect(
        t
            .widget<PupilWorkspaceDialog>(find.byType(PupilWorkspaceDialog))
            .pupil
            .id,
        'a',
      );
      final ben = t.widget<PupilCard>(
        find.byKey(const ValueKey('pupil-card-b')),
      );
      ben.onOpen();
      await t.pumpAndSettle();
      expect(
        t
            .widget<PupilWorkspaceDialog>(find.byType(PupilWorkspaceDialog))
            .pupil
            .id,
        'b',
      );
      expect(find.text('Bens Eintrag'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(t.takeException(), isNull);
      t.view.physicalSize = const Size(390, 844);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pupil-master-detail')), findsNothing);
      t.widget<PupilCard>(find.byKey(const ValueKey('pupil-card-b'))).onOpen();
      await t.pumpAndSettle();
      expect(find.byType(PupilWorkspaceDialog), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
