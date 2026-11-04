import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/conflict_dialog.dart';

// Review probes: assert the desired behavior. These expose known Build 35 defects.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteNotebook repo;
  late NotebookController c;
  setUp(() async {
    repo = SqliteNotebook(NotebookDatabase(NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync()));
    c = NotebookController(repo);
    await c.initialize();
  });
  tearDown(() async { c.dispose(); await repo.close(); });
  Future<void> open(WidgetTester t, Widget dialog) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 1000);
    addTearDown(t.view.reset);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
    unawaited(showDialog<void>(context: t.element(find.byType(Scaffold)),
        builder: (_) => dialog));
    await t.pumpAndSettle();
  }
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }
  for (final appointment in [true, false]) {
    testWidgets('REVIEW: ${appointment ? 'appointment date/time' : 'task due date/completion'} survives swipe away and back', (t) async {
      final original = await repo.saveEntry(OrgaEntry.empty().copyWith(
        title: 'Prüfeintrag', body: 'Prüfeintrag', isTask: !appointment,
        done: !appointment, dueDate: appointment ? null : '2030-04-04',
        appointmentDate: appointment ? '2030-04-04' : null,
        appointmentTime: appointment ? '14:30' : '',
      ));
      await c.reload();
      await open(t, OrgaEditor(controller: c, entry: original));
      final bar = find.byKey(const ValueKey('orga-kind-bar'));
      for (final delta in [110.0, -110.0]) {
        await t.ensureVisible(bar); await t.pumpAndSettle();
        await t.drag(bar, Offset(delta, 0)); await t.pumpAndSettle();
      }
      await t.ensureVisible(find.text('Speichern'));
      await t.tap(find.text('Speichern')); await t.pumpAndSettle();
      final actual = (await repo.entries()).single;
      final expectedValues = appointment
          ? [original.appointmentDate, original.appointmentTime]
          : [original.dueDate, original.done];
      final actualValues = appointment
          ? [actual.appointmentDate, actual.appointmentTime]
          : [actual.dueDate, actual.done];
      // ignore: avoid_print
      print(jsonEncode({'probe': appointment ? 'appointment' : 'task',
        'expected': expectedValues, 'actual': actualValues}));
      await finish(t);
      expect(actualValues, expectedValues);
    });
  }
  testWidgets('REVIEW: conflict comparison shows both appointment dates and times', (t) async {
    final original = await repo.saveEntry(OrgaEntry.empty().copyWith(
      title: 'Terminvergleich', body: 'Terminvergleich',
      appointmentDate: '2030-04-04', appointmentTime: '14:30',
    ));
    await repo.saveDraft(EditDraft(id: 'review-conflict',
      entry: original.copyWith(appointmentDate: '2030-05-05', appointmentTime: '15:45'),
      updatedAtUtc: utcNow()));
    await repo.saveEntry(original.copyWith(appointmentDate: '2030-06-06', appointmentTime: '16:00'));
    await c.reload();
    await open(t, ConflictDialog(controller: c));
    expect(find.text('Andere übernehmen'), findsOneWidget);
    final comparisons = t.widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data ?? '').join('\n');
    // ignore: avoid_print
    print(jsonEncode({'probe':'conflict', 'visible_comparisons': comparisons,
      'appointment_date_label':conflictFieldLabels['appointmentDate'],
      'appointment_time_label':conflictFieldLabels['appointmentTime']}));
    await finish(t);
    expect(comparisons, contains('15:45'));
    expect(comparisons, contains('16:00'));
    expect(comparisons, contains('2030'));
  });
}
