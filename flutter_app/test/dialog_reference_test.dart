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
import 'package:flex_notizbuch/ui/backup_dialog.dart';
import 'package:flex_notizbuch/ui/conflict_dialog.dart';
import 'package:flex_notizbuch/ui/dialog_workflows.dart';
import 'package:flex_notizbuch/ui/draft_buffer.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/maintenance_dialog.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/pupil_editor.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';
import 'package:flex_notizbuch/ui/tag_text_field.dart';
import 'package:flex_notizbuch/ui/pupil_history.dart';

class FailingDraftNotebook extends SqliteNotebook {
  FailingDraftNotebook(super.db);
  bool failWrites = true;
  @override
  Future<void> discardDialogDraft(String id, int revision) async {
    throw const DomainError('Synthetischer Verwerfungsfehler');
  }

  @override
  Future<DialogDraft> saveDialogDraft(DialogDraft draft) async {
    if (failWrites) throw const DomainError('Synthetischer Entwurfsfehler');
    return super.saveDialogDraft(draft);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteNotebook repo;
  late NotebookController c;
  setUpAll(() async {
    for (final font in {
      'FlexSans': [
        'assets/fonts/Selawik-Regular.ttf',
        'assets/fonts/Selawik-Semibold.ttf',
        'assets/fonts/Selawik-Bold.ttf',
      ],
      'FlexSerif': [
        'assets/fonts/Gelasio-Regular.ttf',
        'assets/fonts/Gelasio-Medium.ttf',
        'assets/fonts/Gelasio-SemiBold.ttf',
        'assets/fonts/Gelasio-Bold.ttf',
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(font.key);
      for (final path in font.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });
  setUp(() async {
    repo = SqliteNotebook(
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
    Size size = const Size(1100, 1000),
    GlobalKey? boundary,
    double scale = 1,
    double keyboard = 0,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    t.view.viewInsets = FakeViewPadding(bottom: keyboard);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    await t.binding.setSurfaceSize(size);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FlexApp(controller: c),
      ),
    );
    await t.runAsync(
      () => precacheImage(
        const AssetImage(FlexBackground.defaultDarkImage),
        t.element(find.byType(FlexBackground)),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    t.view.resetViewInsets();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    await t.binding.setSurfaceSize(null);
  }

  Future<void> open(WidgetTester t, Widget widget) async {
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold).first),
        barrierDismissible: false,
        builder: (_) => widget,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await t.ensureVisible(target.last);
    await t.pumpAndSettle();
    await t.tap(target.last);
    await t.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester t,
    GlobalKey key,
    String name,
    Size size,
    double scale,
    double keyboard,
  ) async {
    final directory = Platform.environment['FLEX_RENDER_DIR'];
    if (directory == null) return;
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      Directory(directory).createSync(recursive: true);
      File(
        '$directory/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      picture.dispose();
      File('$directory/manifest.jsonl').writeAsStringSync(
        '${jsonEncode({'file': '$name.png', 'width': size.width, 'height': size.height, 'textScale': scale, 'keyboardInset': keyboard, 'engine': 'flutter_test RenderRepaintBoundary', 'source': '0.16.0-rebuild.7 UI/UX audit', 'data': 'synthetic'})}\n',
        mode: FileMode.append,
      );
    });
  }

  testWidgets(
    'selected suggestions move into the input; stars, timing and hidden support preserve independent data',
    (t) async {
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'a'),
        ),
      );
      await tap(t, find.byKey(const ValueKey('tone-positive')));
      await tap(t, find.byKey(const ValueKey('favorite-Hilft anderen')));
      expect((await repo.observationCatalog('social-positive')).favorites, [
        'Hilft anderen',
      ]);
      expect(
        find.byKey(const ValueKey('selected-positive-Hilft anderen')),
        findsNothing,
      );
      await tap(t, find.byKey(const ValueKey('observation-Hilft anderen')));
      expect(
        find.byKey(const ValueKey('favorite-Hilft anderen')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('observation-Hilft anderen')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TagTextField),
          matching: find.text('+ Hilft anderen'),
        ),
        findsOneWidget,
      );
      await t.enterText(
        find.byKey(const ValueKey('record-body')),
        'Eigenständiger Freitext bleibt.',
      );
      await tap(t, find.text('Vor Unterricht'));
      await tap(t, find.text('Pause'));
      expect(find.byKey(const ValueKey('selected-situation')), findsOneWidget);
      await tap(
        t,
        find.byKey(const ValueKey('section-Reaktion / Unterstützung')),
      );
      await t.enterText(
        find.byKey(const ValueKey('record-support')),
        'Gespräch angeboten',
      );
      await tap(
        t,
        find.byKey(const ValueKey('section-Reaktion / Unterstützung')),
      );
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      final saved = (await repo.schoolRecords()).single;
      expect(saved.body, 'Eigenständiger Freitext bleibt.');
      expect(saved.situation, 'break');
      expect(saved.support, 'Gespräch angeboten');
      expect(saved.positive, ['Hilft anderen']);
      await finish(t);
    },
  );

  testWidgets(
    'observation forms omit recent assignments while preserving own tags and free text',
    (t) async {
      final other = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.work,
          'b',
        ).patch({'subject': 'Arbeitsblatt · Seite 4'}),
      );
      final own = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.work, 'a').patch({
          'taskTags': ['Bestehender Auftrag'],
          'taskFree': 'Eigener Freitext',
          'subject': 'Bestehender Auftrag · Eigener Freitext',
        }),
      );
      await c.reload();
      await app(t);
      for (final kind in [SchoolKind.social, SchoolKind.work]) {
        await open(
          t,
          SchoolEditor(controller: c, record: SchoolRecord.empty(kind, 'a')),
        );
        expect(find.text('Zuletzt verwendet'), findsNothing);
        expect(find.text('Arbeitsblatt · Seite 4'), findsNothing);
        expect(find.text('Bestehender Auftrag'), findsNothing);
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
      }
      await open(t, SchoolEditor(controller: c, record: own));
      expect(find.text('Zuletzt verwendet'), findsNothing);
      expect(find.text('Arbeitsblatt · Seite 4'), findsNothing);
      expect(find.text('Bestehender Auftrag'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('record-subject')),
        'Bearbeiteter Freitext',
      );
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      final records = await repo.schoolRecords();
      final record = records.firstWhere((r) => r.id == own.id);
      expect(record.taskTags, ['Bestehender Auftrag']);
      expect(record.taskFree, 'Bearbeiteter Freitext');
      expect(record.subject, 'Bestehender Auftrag · Bearbeiteter Freitext');
      expect(
        records.firstWhere((r) => r.id == other.id).toJson(),
        other.toJson(),
      );
      await finish(t);
    },
  );

  testWidgets('cancel keeps an unpublished draft for the same pupil', (
    t,
  ) async {
    await app(t);
    await open(
      t,
      SchoolEditor(
        controller: c,
        record: SchoolRecord.empty(SchoolKind.social, 'b'),
      ),
    );
    await t.enterText(
      find.byKey(const ValueKey('record-body')),
      'Nicht veröffentlichen',
    );
    expect(find.text('Speichern & weiter'), findsNothing);
    await tap(t, find.byKey(const ValueKey('cancel-editor')));
    expect(find.byType(SchoolEditor), findsNothing);
    expect(await repo.schoolRecords(), isEmpty);
    final draft = (await repo.schoolDrafts()).single;
    expect(draft.record.pupilId, 'b');
    expect(draft.record.body, 'Nicht veröffentlichen');
    await open(
      t,
      SchoolEditor(controller: c, record: draft.record, draft: draft),
    );
    await tap(t, find.byKey(const ValueKey('save-school-record')));
    expect((await repo.schoolRecords()).single.body, 'Nicht veröffentlichen');
    expect(await repo.schoolDrafts(), isEmpty);
    await finish(t);
  });

  testWidgets(
    'comment conflict rebase preserves newer task status and other feedback',
    (t) async {
      final task = const HomeworkTask(id: 't', text: 'Lesen');
      final original = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'a').patch({
          'tasks': [task.toJson()],
        }),
      );
      await c.reload();
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: original,
          mode: 'comment',
          taskId: 't',
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('homework-comment')),
        'Kommentar aus dem Entwurf',
      );
      final newer = SchoolFeedback(
        id: 'external',
        observedOn: dateOnly(DateTime.now()),
        createdAtUtc: utcNow(),
        taskId: 't',
        state: TaskState.complete,
      );
      await repo.saveSchoolRecord(
        original.patch({
          'feedback': [newer.toJson()],
        }),
      );
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      await tap(t, find.text('Aktuelle Fassung übernehmen'));
      await tap(t, find.text('Aktuelle Fassung übernehmen'));
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      final saved = (await repo.schoolRecords()).single;
      expect(saved.taskState(task), TaskState.complete);
      expect(
        saved.feedback.any((f) => f.note == 'Kommentar aus dem Entwurf'),
        isTrue,
      );
      await finish(t);
    },
  );

  test(
    'Orga and generic drafts reject stale writes and publishing does not delete a newer draft',
    () async {
      final entry = OrgaEntry.empty(pupilId: 'a').copyWith(title: 'Entwurf');
      final one = await repo.saveDraft(
        EditDraft(id: 'd', entry: entry, updatedAtUtc: utcNow()),
      );
      final two = await repo.saveDraft(
        EditDraft(
          id: 'd',
          entry: entry.copyWith(body: 'neuer'),
          updatedAtUtc: utcNow(),
          editRevision: one.editRevision,
        ),
      );
      await expectLater(repo.saveDraft(one), throwsA(isA<StaleRevision>()));
      await expectLater(
        repo.saveEntry(entry, draftId: 'd', draftRevision: one.editRevision),
        throwsA(isA<StaleRevision>()),
      );
      expect((await repo.drafts()).single.editRevision, two.editRevision);
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: 'p',
          type: 'pupil',
          ownerId: 'a',
          data: c.pupils.first.toJson(),
          updatedAtUtc: utcNow(),
        ),
      );
      await repo.saveDialogDraft(draft);
      await expectLater(
        repo.discardDialogDraft('p', draft.revision),
        throwsA(isA<StaleRevision>()),
      );
    },
  );

  test(
    'group records have distinct observations and one shared context; undo is atomic',
    () async {
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: 'group',
          type: 'bulk',
          ownerId: 'group',
          updatedAtUtc: utcNow(),
          data: {
            'kind': 'social',
            'recipients': ['a', 'b'],
            'context': 'Gemeinsames Gespräch',
            'observedOn': '2026-11-01',
            'individual': {
              'a': {
                'body': 'Hat zugehört',
                'positive': ['Hilft anderen'],
              },
              'b': {'body': 'Hat nachgefragt'},
            },
          },
        ),
      );
      await repo.saveBulkDialog(draft);
      await repo.saveBulkDialog(draft);
      final records = await repo.schoolRecords();
      expect(records, hasLength(2));
      expect(records.map((r) => r.situationId).toSet(), hasLength(1));
      expect(records.firstWhere((r) => r.pupilId == 'b').positive, isEmpty);
      final context = (await repo.situation(records.first.situationId!))!;
      await repo.saveSituation(
        context['id'] as String,
        context['revision'] as int,
        'Geänderter Ablauf',
        null,
      );
      expect(
        (await repo.schoolRecords()).every(
          (r) => r.context == 'Geänderter Ablauf',
        ),
        isTrue,
      );
      await expectLater(
        repo.undoSchoolGroup('group'),
        throwsA(isA<StaleRevision>()),
      );
      expect((await repo.schoolRecords()).any((r) => r.deleted), isFalse);
    },
  );

  test(
    'maintenance rejects changed snapshots and removes only trash after validated export',
    () async {
      final record = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.goal,
          'a',
        ).patch({'title': 'Gelöscht', 'deleted': true}),
      );
      final oldBackup = await repo.exportBackup();
      await repo.savePupil(c.pupils.first.copyWith(name: 'Geänderter Name'));
      await expectLater(
        repo.maintainStorage(oldBackup, emptyTrash: true),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.schoolRecords()).single.id, record.id);
      await repo.maintainStorage(await repo.exportBackup(), emptyTrash: true);
      expect(await repo.schoolRecords(), isEmpty);
      expect(await repo.pupils(), hasLength(2));
    },
  );

  test(
    'date-only reminders, task metadata and pupil drafts survive a real SQLite reopen',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'flex-dialog-roundtrip-',
      );
      final file = File('${directory.path}/notebook.sqlite');
      SqliteNotebook connect() => SqliteNotebook(
        NotebookDatabase(
          NativeDatabase(file),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      var disk = connect();
      await disk.initialize();
      await disk.savePupil(const Pupil(id: 'disk', name: 'Dateitest'));
      final first = await disk.saveEntry(
        OrgaEntry.empty(pupilId: 'disk').copyWith(
          title: 'Erinnerung ohne Zeit',
          reminderAtUtc: '2026-11-05T00:00:00.000Z',
          reminderHasTime: false,
          reminderState: ReminderState.planned,
        ),
      );
      final midnight = await disk.saveEntry(
        OrgaEntry.empty(pupilId: 'disk').copyWith(
          title: 'Mitternacht',
          reminderAtUtc: '2026-11-05T00:00:00.000Z',
          reminderHasTime: true,
          reminderState: ReminderState.planned,
        ),
      );
      await disk.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.work, 'disk').patch({
          'subject': 'Text · bleibt frei',
          'taskFree': 'Text · bleibt frei',
          'taskTags': <String>[],
        }),
      );
      await disk.saveDialogDraft(
        DialogDraft(
          id: 'pd',
          type: 'pupil',
          ownerId: 'new',
          data: const Pupil(id: 'new', name: 'Noch ungespeichert').toJson(),
          updatedAtUtc: utcNow(),
        ),
      );
      final backup = await disk.exportBackup();
      await disk.close();
      disk = connect();
      await disk.initialize();
      expect(
        (await disk.entries())
            .firstWhere((e) => e.id == first.id)
            .reminderHasTime,
        isFalse,
      );
      expect(
        (await disk.entries())
            .firstWhere((e) => e.id == midnight.id)
            .reminderHasTime,
        isTrue,
      );
      expect(
        (await disk.schoolRecords()).single.taskFree,
        'Text · bleibt frei',
      );
      expect(
        (await disk.dialogDrafts()).single.data['name'],
        'Noch ungespeichert',
      );
      final copy = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      await copy.initialize();
      await copy.restoreBackup(backup);
      expect(
        (await copy.entries())
            .firstWhere((e) => e.id == first.id)
            .reminderHasTime,
        isFalse,
      );
      await copy.close();
      await disk.close();
      directory.deleteSync(recursive: true);
    },
  );

  testWidgets(
    'pupil fields resume together and validation leaves the editor open',
    (t) async {
      await app(t);
      await open(t, PupilEditor(controller: c));
      await tap(t, find.text('Hinzufügen'));
      expect(find.byType(PupilEditor), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Clara Entwurf',
      );
      await tap(t, find.byTooltip('#AC5D72'));
      await tap(t, find.byTooltip('Schließen und Eingaben sichern'));
      final draft = (await repo.dialogDrafts()).single;
      expect(await repo.pupils(), hasLength(2));
      await open(t, PupilEditor(controller: c, draft: draft));
      expect(find.text('Clara Entwurf'), findsOneWidget);
      await tap(t, find.text('Hinzufügen'));
      expect(
        (await repo.pupils())
            .firstWhere((p) => p.name == 'Clara Entwurf')
            .color,
        0xffac5d72,
      );
      expect(await repo.dialogDrafts(), isEmpty);
      await finish(t);
    },
  );

  test(
    'bulk Orga and homework commit atomically and undo restores a distinct draft',
    () async {
      DialogDraft raw(String id, String kind, Json extra) => DialogDraft(
        id: id,
        type: 'bulk',
        ownerId: 'group',
        updatedAtUtc: utcNow(),
        data: {
          'kind': kind,
          'recipients': ['a', 'b'],
          'individual': <String, dynamic>{},
          'observedOn': '2026-11-01',
          ...extra,
        },
      );
      var draft = await repo.saveDialogDraft(
        raw('orga-group', 'orga', {
          'body': 'Klassenfest vorbereiten',
          'isTask': true,
          'dueDate': '2026-11-20',
          'reminderOpen': true,
          'reminderDate': '2026-11-15',
          'reminderTime': '',
        }),
      );
      await repo.saveBulkDialog(draft);
      final orga = await repo.entries();
      expect(orga, hasLength(2));
      expect(
        orga.every((e) => !e.reminderHasTime && e.dueDate == '2026-11-20'),
        isTrue,
      );
      await repo.undoSchoolGroup(draft.id);
      expect((await repo.entries()).every((e) => e.deleted), isTrue);
      expect((await repo.dialogDrafts()).single.id, isNot(draft.id));
      draft = await repo.saveDialogDraft(
        raw('hw-group', 'homework', {
          'subject': 'Lesen',
          'tasks': [
            const HomeworkTask(id: 'main', text: 'Eine Seite').toJson(),
            const HomeworkTask(
              id: 'child',
              text: 'Wörter markieren',
              parentId: 'main',
            ).toJson(),
          ],
        }),
      );
      await repo.saveBulkDialog(draft);
      final records = await repo.schoolRecords();
      expect(records, hasLength(2));
      expect(
        records[0].tasks
            .map((t) => t.id)
            .toSet()
            .intersection(records[1].tasks.map((t) => t.id).toSet()),
        isEmpty,
      );
      expect(
        records.every((r) => r.tasks.last.parentId == r.tasks.first.id),
        isTrue,
      );
      final invalid = raw('invalid-group', 'social', {
        'context': '',
        'individual': {
          'a': {'body': 'Gültig'},
          'b': {'body': ''},
        },
      });
      await repo.saveDialogDraft(invalid);
      await expectLater(
        repo.saveBulkDialog(
          DialogDraft.fromJson({...invalid.toJson(), 'revision': 1}),
        ),
        throwsA(isA<DomainError>()),
      );
      expect(await repo.schoolRecords(), hasLength(2));
      expect(
        (await repo.dialogDrafts()).any((d) => d.id == 'invalid-group'),
        isTrue,
      );
    },
  );

  testWidgets(
    'calendar keyboard navigation crosses months and cancel is atomic',
    (t) async {
      await app(t);
      (String, String)? result;
      unawaited(
        pickFlexDate(
          t.element(find.byType(Scaffold).first),
          date: '2026-10-31',
          time: '00:00',
        ).then((v) => result = v),
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('calendar-day-2026-10-31')));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar-day-2026-11-01')),
        findsOneWidget,
      );
      await tap(t, find.text('Übernehmen'));
      expect(result, ('2026-11-01', '00:00'));
      result = null;
      unawaited(
        pickFlexDate(
          t.element(find.byType(Scaffold).first),
          date: '2026-11-01',
          time: '00:00',
        ).then((v) => result = v),
      );
      await t.pumpAndSettle();
      await tap(t, find.byTooltip('Uhrzeit entfernen'));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(result, isNull);
      await finish(t);
    },
  );

  testWidgets(
    'catalog pending text saves both tones and rejects duplicates atomically',
    (t) async {
      await app(t);
      unawaited(
        showCatalog(t.element(find.byType(Scaffold).first), c, 'social'),
      );
      await t.pumpAndSettle();
      await tap(t, find.text('+ Positiv'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Neuer Auswahleintrag'),
        'Individuelle positive Auswahl',
      );
      await tap(t, find.text('− Negativ'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Neuer Auswahleintrag'),
        'Individuelle negative Auswahl',
      );
      await tap(t, find.text('Änderungen speichern'));
      expect(
        (await repo.observationCatalog('social-positive')).options.last,
        'Individuelle positive Auswahl',
      );
      expect(
        (await repo.observationCatalog('social-negative')).options.last,
        'Individuelle negative Auswahl',
      );
      await expectLater(
        repo.saveCatalogs({
          'social-positive': ['Neu'],
          'social-negative': ['Doppelt', 'doppelt'],
        }, null),
        throwsA(isA<DomainError>()),
      );
      expect(
        (await repo.observationCatalog('social-positive')).options.last,
        'Individuelle positive Auswahl',
      );
      expect(await repo.dialogDrafts(), isEmpty);
      await finish(t);
    },
  );

  testWidgets(
    'backup review preserves local catalogs when their import is disabled',
    (t) async {
      await repo.saveObservationOptions('social-positive', ['Aus der Datei']);
      final backup = await repo.exportBackup();
      final target = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final targetController = NotebookController(target);
      await targetController.initialize();
      await target.saveObservationOptions('social-positive', [
        'Lokal behalten',
      ]);
      try {
        await app(t);
        unawaited(
          showImportReview(
            t.element(find.byType(Scaffold).first),
            targetController,
            backup,
            catalogs: false,
          ),
        );
        await t.pumpAndSettle();
        await tap(t, find.text('Sicherung wiederherstellen'));
        expect(
          find.text(
            'Bitte die Wiederherstellung als neuen Datenstand bestätigen.',
          ),
          findsOneWidget,
        );
        expect(await target.pupils(), isEmpty);
        await tap(
          t,
          find.text('Diese Sicherung als neuen Datenstand verwenden'),
        );
        await tap(t, find.text('Sicherung wiederherstellen'));
        expect(await target.pupils(), hasLength(2));
        expect((await target.observationCatalog('social-positive')).options, [
          'Lokal behalten',
        ]);
        await finish(t);
      } finally {
        targetController.dispose();
        await target.close();
      }
    },
  );

  testWidgets('generic drafts count and resume only the selected pupil draft', (
    t,
  ) async {
    for (final id in ['draft-one', 'draft-two']) {
      await repo.saveDialogDraft(
        DialogDraft(
          id: id,
          type: 'pupil',
          ownerId: id,
          data: Pupil(id: id, name: id).toJson(),
          updatedAtUtc: utcNow(),
        ),
      );
    }
    await c.reload();
    expect(c.draftCount, 2);
    await app(t);
    await tap(t, find.byTooltip('Weitere Bereiche'));
    await tap(t, find.text('Entwürfe (2)'));
    expect(find.text('Keine gesicherten Entwürfe.'), findsNothing);
    await tap(
      t,
      find.descendant(
        of: find.ancestor(
          of: find.text('Schüler · draft-two'),
          matching: find.byType(FlexCard),
        ),
        matching: find.text('Fortsetzen'),
      ),
    );
    await t.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Fortgesetzter Schüler',
    );
    await tap(t, find.text('Hinzufügen'));
    expect(
      (await repo.pupils()).any((p) => p.name == 'Fortgesetzter Schüler'),
      isTrue,
    );
    expect((await repo.dialogDrafts()).single.id, 'draft-one');
    await finish(t);
  });

  testWidgets(
    'pupil history filters Orga and observations and displays revision contents',
    (t) async {
      final initial = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.social,
          'a',
        ).patch({'body': 'Frühere Beobachtung'}),
      );
      final changed = await repo.saveSchoolRecord(
        initial.patch({'body': 'Aktuelle Beobachtung'}),
      );
      await repo.saveEntry(
        OrgaEntry.empty(
          pupilId: 'a',
        ).copyWith(title: 'Notiz', body: 'Gespräch mit Eltern'),
      );
      await c.reload();
      await app(t);
      unawaited(
        showPupilHistory(t.element(find.byType(Scaffold).first), c, 'a'),
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(FlexModal),
          matching: find.textContaining('Gespräch mit Eltern'),
        ),
        findsOneWidget,
      );
      await t.enterText(
        find.widgetWithText(TextField, 'Verlauf durchsuchen'),
        'Aktuelle Beobachtung',
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(FlexModal),
          matching: find.textContaining('Gespräch mit Eltern'),
        ),
        findsNothing,
      );
      expect(find.text('Aktuelle Beobachtung'), findsWidgets);
      unawaited(
        showJournal(t.element(find.byType(FlexModal).last), c, changed.id),
      );
      await t.pumpAndSettle();
      await tap(t, find.textContaining('Fassung 2'));
      expect(find.textContaining('Frühere Beobachtung'), findsOneWidget);
      expect(find.textContaining('Aktuelle Beobachtung'), findsWidgets);
      expect(find.textContaining('rebuildFormat'), findsNothing);
      await finish(t);
    },
  );

  test(
    'conflict resolution preserves both alternatives and publishes a new revision',
    () async {
      final initial = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.social, 'a').patch({'body': 'Ausgang'}),
      );
      final draft = await repo.saveSchoolDraft(
        SchoolDraft(
          id: 'conflict',
          record: initial.patch({'body': 'Entwurf'}),
          updatedAtUtc: utcNow(),
        ),
      );
      await repo.saveSchoolRecord(initial.patch({'body': 'Aktuell'}));
      await repo.resolveSchoolConflict(draft, useOther: true);
      expect((await repo.schoolRecords()).single.body, 'Entwurf');
      expect(await repo.schoolDrafts(), isEmpty);
      final backup = jsonDecode(await repo.exportBackup()) as Map;
      final alternatives = (backup['tables']['preferences'] as List).where(
        (r) => (r['key'] as String).startsWith('resolved-conflict-'),
      );
      final saved = jsonDecode(alternatives.single['payload'] as String) as Map;
      expect(saved['current']['body'], 'Aktuell');
      expect(saved['other']['body'], 'Entwurf');
      expect(await repo.history(initial.id), hasLength(3));
    },
  );

  testWidgets(
    'editing goal status records a review without changing its target date',
    (t) async {
      final goal = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.goal, 'a').patch({
          'title': 'Testziel',
          'dueDate': '2026-12-01',
          'nextReviewDate': '2026-11-08',
        }),
      );
      await c.reload();
      await app(t);
      await open(t, SchoolEditor(controller: c, record: goal));
      await tap(t, find.text('Erreicht'));
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      final result = (await repo.schoolRecords()).single;
      expect(result.goalStatus, 'achieved');
      expect(result.dueDate, '2026-12-01');
      expect(result.nextReviewDate, isNull);
      expect(result.reviews.single.decision, 'achieved');
      expect(result.reviews.single.nextReviewDate, isNull);
      await finish(t);
    },
  );

  testWidgets(
    'failed draft close offers recovery and retry keeps the entered pupil data',
    (t) async {
      final failing = FailingDraftNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      final local = NotebookController(failing);
      await local.initialize();
      try {
        await app(t);
        await open(t, PupilEditor(controller: local));
        await t.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Nicht verlieren',
        );
        await tap(t, find.byTooltip('Schließen und Eingaben sichern'));
        expect(find.text('Entwurf nicht gesichert'), findsOneWidget);
        expect(await failing.dialogDrafts(), isEmpty);
        await tap(t, find.text('Verwerfen'));
        expect(find.text('Synthetischer Verwerfungsfehler'), findsOneWidget);
        expect(t.takeException(), isNull);
        await tap(t, find.byTooltip('Schließen und Eingaben sichern'));
        await tap(t, find.text('Weiterbearbeiten'));
        expect(find.text('Nicht verlieren'), findsOneWidget);
        failing.failWrites = false;
        await tap(t, find.byTooltip('Schließen und Eingaben sichern'));
        final draft = (await failing.dialogDrafts()).single;
        expect(draft.data['name'], 'Nicht verlieren');
        expect(await failing.pupils(), isEmpty);
        await finish(t);
      } finally {
        local.dispose();
        await failing.close();
      }
    },
  );

  for (final variant in ['wide', 'narrow', 'large-keyboard']) {
    testWidgets('direct Flutter dialog matrix $variant', (t) async {
      final size = variant == 'wide'
          ? const Size(1440, 1000)
          : const Size(320, 700);
      final scale = variant == 'large-keyboard' ? 2.0 : 1.0;
      final keyboard = variant == 'large-keyboard' ? 280.0 : 0.0;
      final boundary = GlobalKey();
      final hw = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'a').patch({
          'subject': 'Mathematik',
          'tasks': [
            const HomeworkTask(
              id: 'task',
              text: 'Aufgabe mit einer längeren Beschreibung',
            ).toJson(),
          ],
        }),
      );
      final goal = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.goal, 'a').patch({
          'title': 'In Ruhe mit der Aufgabe beginnen',
          'criterion': 'Beginnt ohne weitere Aufforderung',
          'body': 'Ersten Schritt gemeinsam klären',
          'dueDate': '2026-11-30',
        }),
      );
      final social = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.social, 'a').patch({
          'body': 'Hat einem Mitschüler geholfen.',
          'positive': ['Hilft anderen'],
          'context': 'Gruppenarbeit',
          'participantIds': ['b'],
          'support': 'Rückmeldung gegeben',
        }),
      );
      await c.reload();
      final backup = await repo.exportBackup();
      final scenarios = <String, Future<void> Function(BuildContext)>{
        'social-empty': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.social, 'a'),
          ),
        ),
        'social-filled': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(controller: c, record: social),
        ),
        'work-empty': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.work, 'a'),
          ),
        ),
        'goal-new': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.goal, 'a'),
          ),
        ),
        'goal-edit': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(controller: c, record: goal),
        ),
        'orga-filled': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: 'a').copyWith(
              title: 'Vorbereitung',
              body: 'Material für das Gespräch vorbereiten.',
              isTask: true,
              dueDate: '2026-11-20',
              reminderAtUtc: '2026-11-18T00:00:00.000Z',
              reminderState: ReminderState.planned,
              reminderHasTime: false,
              reminderText: 'Unterlagen mitnehmen',
            ),
          ),
        ),
        'goal-review': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) =>
              SchoolEditor(controller: c, record: goal, mode: 'review'),
        ),
        'homework-new': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.homework, 'a'),
          ),
        ),
        'homework-edit': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(controller: c, record: hw),
        ),
        'homework-comment': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(
            controller: c,
            record: hw,
            mode: 'comment',
            taskId: 'task',
          ),
        ),
        'homework-note': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) =>
              SchoolEditor(controller: c, record: hw, mode: 'comment'),
        ),
        'orga-pupil': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: 'a'),
          ),
        ),
        'orga-class': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => OrgaEditor(controller: c, entry: OrgaEntry.empty()),
        ),
        'pupil-new': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => PupilEditor(controller: c),
        ),
        'pupil-edit': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => PupilEditor(controller: c, pupil: c.pupils.first),
        ),
        'catalog': (ctx) => showCatalog(ctx, c, 'social'),
        'bulk': (ctx) => showBulk(ctx, c),
        'context': (ctx) => showSituation(ctx, c, social.situationId!),
        'history': (ctx) => showPupilHistory(ctx, c, 'a'),
        'brief': (ctx) => showBrief(ctx, c, c.pupils.first),
        'calendar': (ctx) async {
          await pickFlexDate(ctx, date: '2026-11-01', time: '00:00');
        },
        'backup': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => BackupDialog(controller: c),
        ),
        'password': (ctx) async {
          await backupPassword(ctx, opening: false);
        },
        'maintenance': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => MaintenanceDialog(controller: c, emptyTrash: true),
        ),
        'import-review': (ctx) => showImportReview(ctx, c, backup),
        'password-open': (ctx) async {
          await backupPassword(ctx, opening: true);
        },
        'calendar-without-time': (ctx) async {
          await pickFlexDate(ctx, date: '2026-11-01');
        },
        'maintenance-error': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => MaintenanceDialog(controller: c),
        ),
        'social-error': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.social, 'a'),
          ),
        ),
        'pupil-error': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => PupilEditor(controller: c),
        ),
        for (final menu in ['drafts', 'class', 'trash', 'drafts-filled'])
          'menu-$menu': (ctx) async {
            await t.tap(find.byTooltip('Weitere Bereiche'));
            await t.pumpAndSettle();
            await t.tap(
              menu.startsWith('drafts')
                  ? find.textContaining('Entwürfe (').last
                  : find
                        .text(menu == 'class' ? 'Klassen-Orga' : 'Papierkorb')
                        .last,
            );
          },
        'conflicts': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => ConflictDialog(controller: c),
        ),
        'conflicts-filled': (ctx) => showDialog<void>(
          context: ctx,
          builder: (_) => ConflictDialog(controller: c),
        ),
        'unsaved': (ctx) async {
          await unsavedDraft(ctx, repo, {'synthetic': true});
        },
      };
      for (final scenario in scenarios.entries) {
        if (scenario.key == 'menu-drafts-filled') {
          await repo.saveDialogDraft(
            DialogDraft(
              id: 'matrix-pupil',
              type: 'pupil',
              ownerId: 'new',
              data: const Pupil(id: 'new', name: 'Begonnener Schüler').toJson(),
              updatedAtUtc: utcNow(),
            ),
          );
          await c.reload();
        }
        if (scenario.key == 'conflicts-filled') {
          await repo.saveSchoolDraft(
            SchoolDraft(
              id: 'matrix-conflict',
              record: social.patch({
                'body': 'Andere Beobachtung aus dem Entwurf',
              }),
              updatedAtUtc: utcNow(),
            ),
          );
          await repo.saveSchoolRecord(
            social.patch({'body': 'Aktuelle gespeicherte Beobachtung'}),
          );
          await c.reload();
        }
        await app(
          t,
          size: size,
          boundary: boundary,
          scale: scale,
          keyboard: keyboard,
        );
        if (scenario.key.startsWith('menu-')) {
          await scenario.value(t.element(find.byType(Scaffold).first));
        } else {
          unawaited(scenario.value(t.element(find.byType(Scaffold).first)));
        }
        await t.pumpAndSettle();
        await t.runAsync(() => repo.snapshot());
        await t.pumpAndSettle();
        expect(find.byType(FlexModal), findsOneWidget, reason: scenario.key);
        final rect = t.getRect(find.byKey(const ValueKey('flex-modal-frame')));
        expect(rect.left, greaterThanOrEqualTo(9.9), reason: scenario.key);
        expect(rect.right, lessThanOrEqualTo(size.width - 9.9));
        expect(
          rect.bottom,
          lessThanOrEqualTo(size.height - keyboard - 9.9),
          reason: scenario.key,
        );
        expect(t.takeException(), isNull, reason: scenario.key);
        if (scenario.key.endsWith('-error')) {
          await tap(
            t,
            find.text(
              scenario.key == 'pupil-error'
                  ? 'Hinzufügen'
                  : scenario.key == 'maintenance-error'
                  ? 'Ausführen'
                  : 'Speichern',
            ),
          );
          expect(find.byType(FlexModal), findsOneWidget);
          if (scenario.key == 'social-error') {
            final error = find.byKey(const ValueKey('record-error'));
            expect(error, findsOneWidget);
            final errorRect = t.getRect(error);
            expect(errorRect.top, greaterThanOrEqualTo(10));
            expect(
              errorRect.bottom,
              lessThanOrEqualTo(size.height - keyboard - 10),
            );
          }
        }
        if (scenario.key == 'social-filled') {
          await t.ensureVisible(find.byKey(const ValueKey('record-body')));
          await t.pumpAndSettle();
        }
        await capture(
          t,
          boundary,
          '${scenario.key}-$variant',
          size,
          scale,
          keyboard,
        );
        // Actions remain reachable when the keyboard or large type requires full-dialog scrolling.
        final actions = find.descendant(
          of: find.byKey(const ValueKey('modal-footer')),
          matching: find.byType(FilledButton),
        );
        if (actions.evaluate().isNotEmpty) {
          await t.ensureVisible(actions.last);
          await t.pumpAndSettle();
          expect(
            t.getRect(actions.last).bottom,
            lessThanOrEqualTo(size.height - keyboard - 9.9),
            reason: '${scenario.key} action',
          );
        }
        expect(t.takeException(), isNull, reason: scenario.key);
        await finish(t);
      }
    });
  }
}
