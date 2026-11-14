import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/development_dialog.dart';
import 'classroom_test.dart' show classroomMemory;
import 'support/app_test_fonts.dart';

void main() {
  setUpAll(loadAppTestFonts);
  late NotebookController c;
  late SchoolRecord positive, neutral;
  const pupil = Pupil(id: 'p', name: 'Alex Beispiel');
  setUp(() async {
    c = NotebookController(classroomMemory());
    await c.initialize();
    await c.savePupil(pupil);
    positive = await c.repository.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.social, 'p').patch({
        'body': 'Hilft beim gemeinsamen Lesen',
        'positive': ['Hilft anderen'],
        'observedTime': '10:00',
      }),
    );
    neutral = await c.repository.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.work, 'p').patch({
        'body': 'Fragt nach einem weiteren Arbeitsblatt',
        'neutral': ['Fragt nach'],
        'observedTime': '09:00',
      }),
    );
    await c.repository.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.social, 'p').patch({
        'body': 'Ältere Beobachtung',
        'negative': ['Unterbricht'],
        'observedOn': dateOnly(
          DateTime.now().subtract(const Duration(days: 35)),
        ),
      }),
    );
    await c.repository.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.goal, 'p').patch({
        'title': 'Selbstständig beginnen',
        'criterion': 'An drei Tagen selbst starten',
      }),
    );
    await c.reload();
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  Future<void> host(WidgetTester t, {double scale = 1}) async {
    t.view.physicalSize = const Size(320, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    unawaited(
      showDevelopment(t.element(find.byType(Scaffold).first), c, pupil),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.pumpAndSettle();
    await t.ensureVisible(f.last);
    await t.pumpAndSettle();
    await t.tap(f.last);
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  testWidgets(
    'latest observations are compact, filterable and open their original',
    (t) async {
      await host(t);
      expect(
        find.byKey(ValueKey('development-record-${positive.id}')),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tap(t, find.byKey(const ValueKey('development-area-work')));
      expect(
        find.byKey(ValueKey('development-record-${positive.id}')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('development-record-${neutral.id}')),
        findsOneWidget,
      );
      await tap(t, find.byKey(const ValueKey('development-area-all')));
      await tap(
        t,
        find.byKey(const ValueKey('development-topic-Hilft anderen')),
      );
      expect(
        find.byKey(ValueKey('development-record-${neutral.id}')),
        findsNothing,
      );
      await tap(t, find.byKey(ValueKey('development-record-${positive.id}')));
      expect(find.text('Sozialverhalten'), findsWidgets);
      expect(find.text('Hilft beim gemeinsamen Lesen'), findsWidgets);
      expect(c.records, hasLength(4));
      await finish(t);
    },
  );

  testWidgets(
    'assignment-only work entries have a readable summary and selection label',
    (t) async {
      final record = await c.repository.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.work,
          'p',
        ).patch({'subject': 'Lesetagebuch Kapitel 2'}),
      );
      await c.reload();
      await host(t);
      expect(find.text('Lesetagebuch Kapitel 2'), findsOneWidget);
      final checkbox = t.widget<Checkbox>(
        find.byKey(ValueKey('development-select-${record.id}')),
      );
      expect(
        checkbox.semanticLabel,
        'Für Gespräch auswählen: Lesetagebuch Kapitel 2',
      );
      await tap(t, find.byKey(ValueKey('development-record-${record.id}')));
      expect(find.textContaining('Lesetagebuch Kapitel 2'), findsWidgets);
      await finish(t);
    },
  );

  testWidgets(
    'selection follows visible records and goals remain reachable with large text',
    (t) async {
      await host(t, scale: 1.8);
      await tap(t, find.byKey(ValueKey('development-select-${positive.id}')));
      expect(find.text('Gespräch vorbereiten · 1'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('development-tone-neutral')));
      expect(find.text('Für Gespräch auswählen'), findsOneWidget);
      expect(
        find.byKey(ValueKey('development-record-${positive.id}')),
        findsNothing,
      );
      await tap(t, find.byKey(const ValueKey('development-select-all')));
      expect(find.text('Gespräch vorbereiten · 1'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('development-period-84')));
      expect(find.text('Für Gespräch auswählen'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('development-goals')));
      expect(find.text('Selbstständig beginnen'), findsOneWidget);
      await finish(t);
    },
  );
}
