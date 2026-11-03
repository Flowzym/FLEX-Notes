import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/dialog_workflows.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/pupil_editor.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';

class DelayedDraftStore extends SqliteNotebook {
  DelayedDraftStore(super.db);
  Completer<void>? writeGate;
  bool failDelete = false;
  int deleteCalls = 0;
  @override
  Future<SchoolDraft> saveSchoolDraft(SchoolDraft draft) async {
    await writeGate?.future;
    return super.saveSchoolDraft(draft);
  }

  @override
  Future<void> discardSchoolDraft(String id, {int? expectedRevision}) async {
    deleteCalls++;
    if (failDelete) {
      throw const DomainError('Entwurf konnte nicht gelöscht werden.');
    }
    await super.discardSchoolDraft(id, expectedRevision: expectedRevision);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DelayedDraftStore repo;
  late NotebookController c;
  setUpAll(() async {
    for (final entry in {
      'FlexSans': [
        'assets/fonts/Selawik-Regular.ttf',
        'assets/fonts/Selawik-Semibold.ttf',
        'assets/fonts/Selawik-Bold.ttf',
      ],
      'FlexSerif': ['assets/fonts/Gelasio-Regular.ttf'],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });
  setUp(() async {
    repo = DelayedDraftStore(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(
      const Pupil(id: 'a', name: 'Anna Beispiel', color: 0xff53747e),
    );
    await c.savePupil(
      const Pupil(id: 'b', name: 'Ben Beispiel', color: 0xff756582),
    );
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });
  Future<void> app(
    WidgetTester t, {
    Size size = const Size(390, 1000),
    double font = 1,
    GlobalKey? boundary,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    t.platformDispatcher.textScaleFactorTestValue = font;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
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
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final list = find
          .descendant(
            of: find.byKey(const PageStorageKey('overview')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        finder,
        finder.describeMatch(Plurality.one).contains('overview-section')
            ? -250
            : 250,
        scrollable: list,
      );
    }
    await t.ensureVisible(finder.last);
    await t.pumpAndSettle();
    await t.tap(finder.last);
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t, Widget dialog) async {
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold)),
        barrierDismissible: false,
        builder: (_) => dialog,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    final dir = Platform.environment['FLEX_RENDER_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> seed() async {
    for (var i = 0; i < 7; i++) {
      await c.saveEntry(
        OrgaEntry.empty(pupilId: i.isEven ? 'a' : null).copyWith(
          title: 'Material für Projekt ${i + 1}',
          isTask: true,
          dueDate: dateOnly(DateTime.now().add(Duration(days: i))),
        ),
      );
    }
    await c.saveEntry(
      OrgaEntry.empty().copyWith(
        title: 'Elterngespräch',
        appointmentDate: dateOnly(DateTime.now().add(const Duration(days: 1))),
        appointmentTime: '14:30',
      ),
    );
    await c.saveEntry(
      OrgaEntry.empty().copyWith(
        title: 'Beobachtung nachtragen',
        needsCompletion: true,
      ),
    );
    await c.saveEntry(
      OrgaEntry.empty(
        pupilId: 'a',
      ).copyWith(title: 'Rückmeldung zur Gruppenarbeit'),
    );
    await repo.saveSchoolDraft(
      SchoolDraft(
        id: 'saved',
        record: SchoolRecord.empty(
          SchoolKind.social,
          'a',
        ).patch({'body': 'Ein Entwurf'}),
        updatedAtUtc: utcNow(),
      ),
    );
    await c.reload();
  }

  test(
    'appointments retain local date/time through database, drafts, backup and legacy payload',
    () async {
      final original = OrgaEntry.empty(pupilId: 'a').copyWith(
        title: 'Elterngespräch',
        appointmentDate: '2030-04-04',
        appointmentTime: '14:30',
      );
      await c.saveEntry(original);
      final draft = await repo.saveDraft(
        EditDraft(
          id: 'appointment-draft',
          entry: original.copyWith(appointmentTime: '15:45'),
          updatedAtUtc: utcNow(),
        ),
      );
      expect((await repo.entries()).single.appointmentTime, '14:30');
      expect(draft.entry.appointmentTime, '15:45');
      final backup = await repo.exportBackup();
      final imported = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      addTearDown(imported.close);
      await imported.initialize();
      await imported.restoreBackup(backup);
      final restored = (await imported.entries()).single;
      expect(restored.appointmentDate, '2030-04-04');
      expect(restored.appointmentTime, '14:30');
      expect(restored.isTask, isFalse);
      expect((await imported.drafts()).single.entry.appointmentTime, '15:45');
      final legacy = original.toJson()
        ..remove('appointmentDate')
        ..remove('appointmentTime');
      expect(OrgaEntry.fromJson(legacy).isAppointment, isFalse);
      final broken = jsonDecode(backup) as Map<String, dynamic>;
      final metadata = (broken['tables']['preferences'] as List)
          .cast<Map>()
          .firstWhere((r) => r['key'] == 'orga-time-${original.id}');
      metadata['payload'] = jsonEncode({
        'hasTime': true,
        'appointmentDate': '2030-02-30',
        'appointmentTime': '29:99',
      });
      await expectLater(
        (() async {
          final rejected = SqliteNotebook(
            NotebookDatabase(
              NativeDatabase.memory(),
              File('assets/schema.sql').readAsStringSync(),
            ),
          );
          addTearDown(rejected.close);
          await rejected.initialize();
          try {
            await rejected.restoreBackup(jsonEncode(broken));
          } finally {
            expect(await rejected.entries(), isEmpty);
          }
        })(),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.entries()).single.appointmentTime, '14:30');
    },
  );

  test(
    'appointment schedule distinguishes future, past, all-day and removed events',
    () {
      final now = DateTime(2030, 4, 4, 12);
      final base = OrgaEntry.empty().copyWith(
        title: 'Termin',
        appointmentDate: '2030-04-04',
      );
      expect(base.appointmentIsUpcoming(now), isTrue);
      expect(
        base.copyWith(appointmentTime: '12:30').appointmentIsUpcoming(now),
        isTrue,
      );
      expect(
        base.copyWith(appointmentTime: '11:59').appointmentIsUpcoming(now),
        isFalse,
      );
      expect(
        base.copyWith(appointmentDate: '2030-04-03').appointmentIsUpcoming(now),
        isFalse,
      );
      expect(base.copyWith(deleted: true).pending, isFalse);
      for (final invalid in [
        base.copyWith(isTask: true),
        base.copyWith(appointmentDate: null, appointmentTime: '12:30'),
        base.copyWith(appointmentTime: '25:00'),
      ]) {
        expect(invalid.validate, throwsA(isA<DomainError>()));
      }
    },
  );

  for (final kind in [SchoolKind.social, SchoolKind.work]) {
    testWidgets(
      '${kind.name}: tone swipe retains selections, ignores vertical drags and switches over text',
      (t) async {
        await app(t);
        await open(
          t,
          SchoolEditor(controller: c, record: SchoolRecord.empty(kind, 'a')),
        );
        await tap(t, find.byKey(const ValueKey('tone-positive')));
        final positive = kind == SchoolKind.social
            ? 'Hilft anderen'
            : 'Beginnt selbstständig';
        await tap(t, find.byKey(ValueKey('observation-$positive')));
        final pill = find.byKey(const ValueKey('tone-pill'));
        await t.ensureVisible(pill);
        await t.pumpAndSettle();
        await t.drag(pill, const Offset(-170, 0));
        await t.pumpAndSettle();
        await t.drag(pill, const Offset(-170, 0));
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextButton>(find.byKey(const ValueKey('tone-negative')))
              .style!
              .backgroundColor!
              .resolve({}),
          isNot(Colors.transparent),
        );
        final negativeOptions = find.byWidgetPredicate(
          (w) =>
              w is TextButton &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('observation-'),
        );
        final negativeLabel =
            ((t.widget<TextButton>(negativeOptions.first).child) as Text).data!;
        await tap(t, negativeOptions.first);
        await t.ensureVisible(pill);
        await t.pumpAndSettle();
        await t.drag(pill, const Offset(170, 0));
        await t.pumpAndSettle();
        await t.drag(pill, const Offset(170, 0));
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextButton>(find.byKey(const ValueKey('tone-positive')))
              .style!
              .backgroundColor!
              .resolve({}),
          isNot(Colors.transparent),
        );
        expect(find.byKey(ValueKey('observation-$positive')), findsNothing);
        expect(
          find.byKey(ValueKey('observation-$negativeLabel')),
          findsNothing,
        );
        await t.drag(pill, const Offset(0, -80));
        await t.pumpAndSettle();
        expect(find.byKey(ValueKey('observation-$positive')), findsNothing);
        final body = find.byKey(const ValueKey('record-body'));
        await t.ensureVisible(body);
        await t.enterText(body, 'Bleibt beim Wischen erhalten');
        await t.drag(body, const Offset(-120, 0));
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextButton>(find.byKey(const ValueKey('tone-neutral')))
              .style!
              .backgroundColor!
              .resolve({}),
          isNot(Colors.transparent),
        );
        expect(find.byKey(ValueKey('observation-$positive')), findsNothing);
        await tap(t, find.byTooltip('Schließen und Eingaben sichern'));
        final saved = (await repo.schoolDrafts()).single.record;
        expect(saved.positive, contains(positive));
        expect(saved.negative, contains(negativeLabel));
        expect(saved.body, 'Bleibt beim Wischen erhalten');
        await finish(t);
      },
    );
  }

  testWidgets(
    'search collapses on loss of focus, preserves filter, and stays open through keyboard resize',
    (t) async {
      await app(t);
      await tap(t, find.byKey(const ValueKey('page-1')));
      expect(find.byKey(const ValueKey('search-false')), findsNothing);
      await tap(t, find.byKey(const ValueKey('toggle-pupil-search')));
      final field = find.byKey(const ValueKey('search-false'));
      await t.enterText(field, 'Anna');
      final editable = t.state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      t.view.viewInsets = const FakeViewPadding(bottom: 380);
      await t.pumpAndSettle();
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(find.byKey(const ValueKey('search-false')), findsOneWidget);
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-false')), findsNothing);
      expect(find.byTooltip('Schüler suchen: Anna'), findsOneWidget);
      expect(find.text('Suche: Anna'), findsNothing);
      expect(find.text('Ben Beispiel'), findsNothing);
      await tap(t, find.byTooltip('Suchtext leeren'));
      expect(find.text('Ben Beispiel'), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets(
    'appointment is created in Orga, reopens with date/time and can become a note',
    (t) async {
      await app(t);
      await tap(t, find.byKey(const ValueKey('overview-add-appointment')));
      expect(
        find.byKey(const ValueKey('orga-appointment-date')),
        findsOneWidget,
      );
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Elterngespräch',
      );
      await tap(t, find.byKey(const ValueKey('orga-appointment-date')));
      expect(find.text('Datum entfernen'), findsNothing);
      await tap(t, find.text('Übernehmen'));
      await tap(t, find.text('Speichern'));
      final saved = (await repo.entries()).single;
      expect(saved.isAppointment, isTrue);
      expect(saved.isTask, isFalse);
      expect(saved.appointmentDate, dateOnly(DateTime.now()));
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: saved.copyWith(appointmentTime: '14:30'),
        ),
      );
      expect(find.textContaining('14:30'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('orga-kind-note')));
      expect(find.byKey(const ValueKey('orga-appointment-date')), findsNothing);
      await tap(t, find.text('Speichern'));
      expect((await repo.entries()).single.appointmentDate, isNull);
      expect((await repo.entries()).single.appointmentTime, isEmpty);
      await finish(t);
    },
  );

  testWidgets(
    'class Orga offers compact search and a direct appointment action',
    (t) async {
      await c.saveEntry(
        OrgaEntry.empty().copyWith(
          title: 'Konferenz',
          appointmentDate: '2030-04-04',
        ),
      );
      await c.saveEntry(
        OrgaEntry.empty().copyWith(title: 'Unterlagen', isTask: true),
      );
      await app(t);
      await tap(t, find.byTooltip('Weitere Bereiche'));
      await tap(t, find.text('Klassen-Orga'));
      Finder inModal(String text) => find.descendant(
        of: find.byType(FlexModal).last,
        matching: find.text(text),
      );
      expect(find.byKey(const ValueKey('class-orga-search')), findsNothing);
      await tap(t, find.byKey(const ValueKey('class-orga-search-button')));
      await t.enterText(
        find.byKey(const ValueKey('class-orga-search')),
        'Konferenz',
      );
      await t.pumpAndSettle();
      expect(inModal('Unterlagen'), findsNothing);
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('Suche: Konferenz'), findsOneWidget);
      await tap(t, find.byTooltip('Suchtext leeren'));
      expect(inModal('Unterlagen'), findsOneWidget);
      await tap(t, find.text('Termine'));
      expect(inModal('Unterlagen'), findsNothing);
      await tap(t, find.byKey(const ValueKey('class-add-appointment')));
      expect(
        find.byKey(const ValueKey('orga-appointment-date')),
        findsOneWidget,
      );
      await t.enterText(find.byKey(const ValueKey('orga-note')), 'Ausflug');
      await tap(t, find.text('Speichern'));
      expect(
        (await repo.entries())
            .where((e) => e.title == 'Ausflug')
            .single
            .isAppointment,
        isTrue,
      );
      await finish(t);
    },
  );

  for (final kind in [
    'social',
    'work',
    'goal',
    'homework',
    'orga',
    'pupil',
    'bulk',
  ]) {
    testWidgets(
      '$kind: delete in the editor discards only the draft and never recreates it',
      (t) async {
        await app(t, size: const Size(390, 1100));
        final originalPupil = c.pupils.first;
        if (kind == 'orga') {
          final saved = await repo.saveEntry(
            OrgaEntry.empty(pupilId: 'a').copyWith(title: 'Originalnotiz'),
          );
          await c.reload();
          await open(t, OrgaEditor(controller: c, entry: saved));
          await t.enterText(
            find.byKey(const ValueKey('orga-note')),
            'Unveröffentlichte Änderung',
          );
        } else if (kind == 'pupil') {
          await open(t, PupilEditor(controller: c, pupil: originalPupil));
          await t.enterText(find.byType(TextField).first, 'Geänderter Name');
        } else if (kind == 'bulk') {
          unawaited(showBulk(t.element(find.byType(Scaffold)), c));
          await t.pumpAndSettle();
          await t.enterText(
            find.byKey(const ValueKey('bulk-social-context')),
            'Gruppenentwurf',
          );
        } else {
          final k = SchoolKind.values.byName(kind);
          var record = SchoolRecord.empty(k, 'a');
          if (k == SchoolKind.goal) {
            record = record.patch({'title': 'Originalziel'});
          } else if (k == SchoolKind.homework) {
            record = record.patch({
              'tasks': [
                const HomeworkTask(
                  id: 'task',
                  text: 'Originalaufgabe',
                ).toJson(),
              ],
            });
          } else {
            record = record.patch({'body': 'Originalbeobachtung'});
          }
          record = await repo.saveSchoolRecord(record);
          await c.reload();
          await open(t, SchoolEditor(controller: c, record: record));
          await t.enterText(
            find.byKey(
              ValueKey(
                k == SchoolKind.goal
                    ? 'record-title'
                    : k == SchoolKind.homework
                    ? 'record-subject'
                    : 'record-body',
              ),
            ),
            'Unveröffentlichte Änderung',
          );
        }
        await t.pump(const Duration(milliseconds: 600));
        await t.pumpAndSettle();
        expect(c.draftCount, 1);
        await tap(t, find.byKey(const ValueKey('delete-editor-draft')));
        await tap(t, find.text('Abbrechen'));
        expect(c.draftCount, 1);
        await tap(t, find.byKey(const ValueKey('delete-editor-draft')));
        await tap(t, find.text('Löschen'));
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(c.draftCount, 0);
        expect((await repo.pupils()).first.name, originalPupil.name);
        if (kind == 'orga') {
          expect((await repo.entries()).single.title, 'Originalnotiz');
        }
        if (SchoolKind.values.any((k) => k.name == kind)) {
          final saved = (await repo.schoolRecords()).single;
          expect(
            saved.toJson().values,
            isNot(contains('Unveröffentlichte Änderung')),
          );
        }
        expect(find.byKey(const ValueKey('delete-editor-draft')), findsNothing);
        await finish(t);
      },
    );
  }

  testWidgets(
    'delete waits for running autosave, handles failure and rejects a newer draft revision',
    (t) async {
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'a'),
        ),
      );
      repo.writeGate = Completer<void>();
      await t.enterText(
        find.byKey(const ValueKey('record-body')),
        'Laufende Speicherung',
      );
      await t.pump(const Duration(milliseconds: 450));
      await tap(t, find.byKey(const ValueKey('delete-editor-draft')));
      await tap(t, find.text('Löschen'));
      expect(repo.deleteCalls, 0);
      await t.enterText(
        find.byKey(const ValueKey('record-body')),
        'Eingabe während des Löschens',
      );
      await t.pump(const Duration(milliseconds: 450));
      repo.failDelete = true;
      repo.writeGate!.complete();
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(
        (await repo.schoolDrafts()).single.record.body,
        'Laufende Speicherung',
      );
      expect(
        find.text('Entwurf konnte nicht gelöscht werden.'),
        findsOneWidget,
      );
      repo.failDelete = false;
      final previous = (await repo.schoolDrafts()).single;
      await repo.saveSchoolDraft(
        SchoolDraft(
          id: previous.id,
          record: previous.record.patch({'body': 'Neuere Änderung'}),
          updatedAtUtc: utcNow(),
          editRevision: previous.editRevision,
          baseline: previous.baseline,
        ),
      );
      await tap(t, find.byKey(const ValueKey('delete-editor-draft')));
      await tap(t, find.text('Löschen'));
      expect((await repo.schoolDrafts()).single.record.body, 'Neuere Änderung');
      expect(find.byKey(const ValueKey('delete-editor-draft')), findsOneWidget);
      await finish(t);
    },
  );

  for (final view in [
    (320.0, 1.0),
    (390.0, 1.0),
    (1200.0, 1.0),
    (320.0, 2.0),
  ]) {
    testWidgets(
      'clean overview and compact Orga/search rendering ${view.$1}/${view.$2}',
      (t) async {
        await seed();
        final key = GlobalKey();
        await app(t, size: Size(view.$1, 1000), font: view.$2, boundary: key);
        final suffix = '${view.$1.toInt()}-${view.$2.toInt()}';
        expect(
          find.byKey(const ValueKey('overview-section-pending')),
          findsOneWidget,
        );
        expect(find.text('Rückmeldung zur Gruppenarbeit'), findsNothing);
        await capture(t, key, 'overview-$suffix');
        await tap(t, find.byKey(const ValueKey('overview-show-more')));
        expect(find.text('Weniger anzeigen'), findsOneWidget);
        await tap(t, find.byKey(const ValueKey('overview-section-complete')));
        expect(find.text('Beobachtung nachtragen'), findsOneWidget);
        await tap(t, find.byKey(const ValueKey('overview-section-recent')));
        expect(find.text('Rückmeldung zur Gruppenarbeit'), findsOneWidget);
        await tap(t, find.byKey(const ValueKey('page-1')));
        await capture(t, key, 'pupils-search-$suffix');
        await tap(t, find.byKey(const ValueKey('pupil-open-a')));
        expect(find.byKey(const ValueKey('pupil-entry-search')), findsNothing);
        await capture(t, key, 'pupil-dialog-$suffix');
        await tap(t, find.byTooltip('Schließen und Eingaben sichern'));
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: 'a').copyWith(
              title: 'Elterngespräch',
              appointmentDate: '2030-04-04',
              appointmentTime: '14:30',
            ),
          ),
        );
        await capture(t, key, 'appointment-$suffix');
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }
}
