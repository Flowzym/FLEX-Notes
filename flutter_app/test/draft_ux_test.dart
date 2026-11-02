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
import 'package:flex_notizbuch/ui/draft_buffer.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';
import 'package:flex_notizbuch/domain/drafts.dart';
import 'package:flex_notizbuch/ui/pupil_card.dart';
import 'package:flex_notizbuch/ui/flex_icons.dart';

class ControlledDraftNotebook extends SqliteNotebook {
  ControlledDraftNotebook(super.db);
  bool failWrites = false;
  Completer<void>? hold;
  @override
  Future<DialogDraft> saveDialogDraft(DialogDraft draft) async {
    if (failWrites) throw const DomainError('Synthetischer Entwurfsfehler');
    await hold?.future;
    return super.saveDialogDraft(draft);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControlledDraftNotebook repo;
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
    repo = ControlledDraftNotebook(
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

  Future<void> close(WidgetTester t) =>
      tap(t, find.byTooltip('Schließen und Eingaben sichern'));
  Future<void> autosave(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
  }

  for (final kind in SchoolKind.values) {
    testWidgets(
      '${kind.name}: empty scaffolding is not a draft, clear after resume removes only own draft',
      (t) async {
        await app(t);
        await open(
          t,
          SchoolEditor(controller: c, record: SchoolRecord.empty(kind, 'a')),
        );
        if (kind == SchoolKind.social || kind == SchoolKind.work) {
          await tap(t, find.text('Negativ'));
          await tap(t, find.text('Positiv'));
        } else if (kind == SchoolKind.homework) {
          await tap(t, find.text('Aufgabe hinzufügen'));
        }
        await autosave(t);
        expect(await repo.schoolDrafts(), isEmpty);
        await close(t);
        expect(await repo.schoolDrafts(), isEmpty);
        final other = await repo.saveSchoolDraft(
          SchoolDraft(
            id: 'unrelated',
            record: SchoolRecord.empty(
              kind,
              'b',
            ).patch({'body': 'Nicht ändern'}),
            updatedAtUtc: utcNow(),
          ),
        );
        await c.reload();
        await open(
          t,
          SchoolEditor(controller: c, record: SchoolRecord.empty(kind, 'a')),
        );
        final field = kind == SchoolKind.homework
            ? find.byType(TextFormField).first
            : find.byKey(
                ValueKey(
                  kind == SchoolKind.goal ? 'record-title' : 'record-body',
                ),
              );
        await t.ensureVisible(field);
        await t.enterText(field, 'Vorübergehender Inhalt');
        await autosave(t);
        final draft = (await repo.schoolDrafts()).firstWhere(
          (d) => d.id != other.id,
        );
        expect(draft.baseline, isNotNull);
        await close(t);
        await open(
          t,
          SchoolEditor(controller: c, record: draft.record, draft: draft),
        );
        final resumed = kind == SchoolKind.homework
            ? find.byType(TextFormField).first
            : find.byKey(
                ValueKey(
                  kind == SchoolKind.goal ? 'record-title' : 'record-body',
                ),
              );
        await t.ensureVisible(resumed);
        await t.enterText(resumed, '   ');
        await autosave(t);
        expect((await repo.schoolDrafts()).single.toJson(), other.toJson());
        expect(find.text('Entwurf gesichert'), findsNothing);
        await close(t);
        expect((await repo.schoolDrafts()).single.id, other.id);
        await finish(t);
      },
    );
  }

  testWidgets(
    'selected tags alone save; deselect and optional section toggles leave no draft',
    (t) async {
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'a'),
        ),
      );
      await tap(t, find.text('Hilft anderen'));
      await autosave(t);
      expect((await repo.schoolDrafts()).single.record.positive, [
        'Hilft anderen',
      ]);
      final selected = find.byType(InputChip).first;
      final chip = t.widget<InputChip>(selected);
      expect((chip.label as Text).style!.fontSize, 12);
      expect(chip.materialTapTargetSize, MaterialTapTargetSize.padded);
      await tap(t, find.byTooltip(chip.deleteButtonTooltipMessage!));
      await autosave(t);
      expect(await repo.schoolDrafts(), isEmpty);
      await close(t);
      await finish(t);
    },
  );

  testWidgets(
    'Orga empty checklist and reminder toggles create no draft; resumed text can be cleared',
    (t) async {
      await app(t);
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(pupilId: 'a'),
        ),
      );
      await tap(t, find.text('☐ Checkliste'));
      await autosave(t);
      expect(await repo.drafts(), isEmpty);
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Orga Entwurf',
      );
      await autosave(t);
      final draft = (await repo.drafts()).single;
      expect(draft.baseline, isNotNull);
      await close(t);
      await open(
        t,
        OrgaEditor(controller: c, entry: draft.entry, draftId: draft.id),
      );
      await t.enterText(find.byKey(const ValueKey('orga-note')), '');
      await autosave(t);
      expect(await repo.drafts(), isEmpty);
      await close(t);
      await finish(t);
    },
  );

  testWidgets(
    'reverting an existing observation removes edit draft without changing saved record',
    (t) async {
      final original = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.work, 'a').patch({'body': 'Original'}),
      );
      await c.reload();
      await app(t);
      await open(t, SchoolEditor(controller: c, record: original));
      await t.enterText(find.byKey(const ValueKey('record-body')), 'Änderung');
      await autosave(t);
      expect(await repo.schoolDrafts(), hasLength(1));
      await t.enterText(find.byKey(const ValueKey('record-body')), 'Original');
      await autosave(t);
      expect(await repo.schoolDrafts(), isEmpty);
      expect((await repo.schoolRecords()).single.toJson(), original.toJson());
      await tap(t, find.text('Sozialverhalten'));
      await autosave(t);
      expect((await repo.schoolDrafts()).single.record.kind, SchoolKind.social);
      expect((await repo.schoolRecords()).single.kind, SchoolKind.work);
      await close(t);
      await finish(t);
    },
  );

  testWidgets(
    'social and work badges count own and group drafts; header opens filtered explicit continuation',
    (t) async {
      for (final kind in [SchoolKind.social, SchoolKind.work]) {
        await repo.saveSchoolDraft(
          SchoolDraft(
            id: kind.name,
            record: SchoolRecord.empty(
              kind,
              'a',
            ).patch({'body': 'Entwurf ${kind.name}'}),
            recipients: ['a'],
            updatedAtUtc: utcNow(),
          ),
        );
      }
      await repo.saveDialogDraft(
        DialogDraft(
          id: 'group-work',
          type: 'bulk',
          ownerId: 'group',
          updatedAtUtc: utcNow(),
          data: {
            'kind': 'work',
            'recipients': ['b'],
            'body': 'Gemeinsame Beobachtung',
            'observedOn': dateOnly(DateTime.now()),
            'observedTime': '',
            'individual': {},
            'needsCompletion': false,
          },
        ),
      );
      await c.reload();
      await app(t, size: const Size(390, 844));
      await tap(t, find.byKey(const ValueKey('page-1')));
      final cards = t.widgetList<PupilCard>(find.byType(PupilCard));
      expect(cards, hasLength(2));
      for (final card in cards) {
        expect(
          card.draftCounts[FlexSymbol.social],
          card.pupil.id == 'a' ? 1 : 0,
        );
        expect(card.draftCounts[FlexSymbol.work], 1);
        expect(card.draftCounts[FlexSymbol.homework], 0);
      }
      await tap(t, find.byKey(const ValueKey('shortcut-a-social')));
      expect(t.widget<SchoolEditor>(find.byType(SchoolEditor)).draft, isNull);
      await tap(t, find.byKey(const ValueKey('entry-drafts')));
      expect(find.text('Entwurf social'), findsOneWidget);
      expect(find.text('Entwurf work'), findsNothing);
      await tap(t, find.text('Fortsetzen'));
      expect(
        t.widget<SchoolEditor>(find.byType(SchoolEditor).last).draft!.id,
        'social',
      );
      await t.enterText(
        find.byKey(const ValueKey('record-body')).last,
        'Bewusst fortgesetzt',
      );
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      expect((await repo.schoolDrafts()).single.id, 'work');
      expect(
        (await repo.schoolRecords()).every(
          (r) => r.body == 'Bewusst fortgesetzt',
        ),
        isTrue,
      );
      expect(await repo.schoolRecords(), hasLength(1));
      await finish(t);
    },
  );

  testWidgets(
    'homework stable numbered rows and Enter, nesting, deletion preserve remaining input',
    (t) async {
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.homework, 'a'),
        ),
      );
      await t.enterText(find.byType(TextFormField).first, 'Lesen');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      final rows = find.byType(TextFormField);
      await t.enterText(rows.at(1), 'Schreiben');
      await tap(t, find.byTooltip('Teilaufgabe hinzufügen').at(1));
      await t.enterText(rows.at(2), 'Satz ergänzen');
      await autosave(t);
      final draft = (await repo.schoolDrafts()).single;
      expect(draft.record.tasks.map((v) => v.text), [
        'Lesen',
        'Schreiben',
        'Satz ergänzen',
      ]);
      expect(draft.record.tasks.last.parentId, draft.record.tasks[1].id);
      final container = t.getRect(
        find.byKey(const ValueKey('homework-task-list')),
      );
      expect(container.height, lessThan(190));
      await t.binding.setSurfaceSize(const Size(600, 1000));
      await t.pumpAndSettle();
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      await tap(
        t,
        find.byKey(ValueKey('task-remove-${draft.record.tasks[1].id}')),
      );
      await autosave(t);
      final changed = (await repo.schoolDrafts()).single.record;
      expect(changed.tasks.map((v) => v.text), ['Lesen', 'Satz ergänzen']);
      expect(changed.tasks.last.parentId, isNull);
      expect(changed.tasks.last.id, draft.record.tasks.last.id);
      await close(t);
      await finish(t);
    },
  );

  test(
    'generic drafts persist baseline, clear after restart and protect concurrent changes',
    () async {
      final buffer = DraftBuffer(
        repo,
        type: 'pupil',
        ownerId: 'new',
        data: {
          'id': 'new',
          'name': '',
          'color': 12,
          'archived': false,
          'revision': 0,
        },
      );
      buffer.change({
        'id': 'new',
        'name': ' ',
        'color': 12,
        'archived': false,
        'revision': 0,
      });
      await buffer.flush();
      expect(await repo.dialogDrafts(), isEmpty);
      buffer.change({
        'id': 'new',
        'name': 'Name',
        'color': 12,
        'archived': false,
        'revision': 0,
      });
      await buffer.flush();
      final saved = (await repo.dialogDrafts()).single;
      buffer.dispose();
      final resumed = DraftBuffer(
        repo,
        type: 'pupil',
        ownerId: 'new',
        data: saved.data,
        initial: saved,
      );
      resumed.change({
        'id': 'new',
        'name': '',
        'color': 12,
        'archived': false,
        'revision': 0,
      });
      await resumed.flush();
      expect(await repo.dialogDrafts(), isEmpty);
      resumed.change({
        'id': 'new',
        'name': 'Erste Fassung',
        'color': 12,
        'archived': false,
        'revision': 0,
      });
      await resumed.flush();
      final mine = resumed.draft;
      final theirs = await repo.saveDialogDraft(
        DialogDraft(
          id: mine.id,
          type: mine.type,
          ownerId: mine.ownerId,
          data: {...mine.data, 'name': 'Neuere Fassung'},
          updatedAtUtc: utcNow(),
          revision: mine.revision,
          baseline: mine.baseline,
        ),
      );
      resumed.change({
        'id': 'new',
        'name': '',
        'color': 12,
        'archived': false,
        'revision': 0,
      });
      await expectLater(resumed.flush(), throwsA(isA<StaleRevision>()));
      expect((await repo.dialogDrafts()).single.toJson(), theirs.toJson());
      resumed.dispose();
    },
  );

  test(
    'empty row signatures ignore generated scaffolding but count date and recipient selections',
    () {
      final base = SchoolRecord.empty(SchoolKind.homework, 'a');
      expect(
        draftSignature(base.toJson()),
        draftSignature(
          base.patch({
            'tasks': [const HomeworkTask(id: 'empty', text: ' ').toJson()],
          }).toJson(),
        ),
      );
      expect(
        draftSignature(base.toJson()),
        isNot(draftSignature(base.patch({'dueDate': '2027-01-02'}).toJson())),
      );
      expect(
        draftSignature({
          'recipients': ['a'],
        }),
        isNot(
          draftSignature({
            'recipients': ['a', 'b'],
          }),
        ),
      );
    },
  );

  test(
    'clearing school and Orga drafts refuses a concurrent newer revision',
    () async {
      final first = await repo.saveSchoolDraft(
        SchoolDraft(
          id: 'school',
          record: SchoolRecord.empty(
            SchoolKind.work,
            'a',
          ).patch({'body': 'Erste'}),
          updatedAtUtc: utcNow(),
        ),
      );
      final newer = await repo.saveSchoolDraft(
        SchoolDraft(
          id: first.id,
          record: first.record.patch({'body': 'Neuere'}),
          updatedAtUtc: utcNow(),
          editRevision: first.editRevision,
        ),
      );
      await expectLater(
        repo.discardSchoolDraft(first.id, expectedRevision: first.editRevision),
        throwsA(isA<StaleRevision>()),
      );
      expect((await repo.schoolDrafts()).single.toJson(), newer.toJson());
      final orga = await repo.saveDraft(
        EditDraft(
          id: 'orga',
          entry: OrgaEntry.empty(pupilId: 'a').copyWith(title: 'Erste'),
          updatedAtUtc: utcNow(),
        ),
      );
      final newerOrga = await repo.saveDraft(
        EditDraft(
          id: orga.id,
          entry: orga.entry.copyWith(title: 'Neuere'),
          updatedAtUtc: utcNow(),
          editRevision: orga.editRevision,
        ),
      );
      await expectLater(
        repo.discardDraft(orga.id, expectedRevision: orga.editRevision),
        throwsA(isA<StaleRevision>()),
      );
      expect((await repo.drafts()).single.entry.title, newerOrga.entry.title);
    },
  );

  test(
    'queued clear cannot resurrect a draft after a delayed save, and failed writes can retry',
    () async {
      final initial = const Pupil(id: 'new', name: '').toJson();
      final buffer = DraftBuffer(
        repo,
        type: 'pupil',
        ownerId: 'new',
        data: initial,
      );
      repo.hold = Completer<void>();
      buffer.change({...initial, 'name': 'Unterwegs'});
      final saving = buffer.flush();
      buffer.change(initial);
      final clearing = buffer.flush();
      repo.hold!.complete();
      await Future.wait([saving, clearing]);
      expect(await repo.dialogDrafts(), isEmpty);
      expect(buffer.dirty, isFalse);
      repo.failWrites = true;
      buffer.change({...initial, 'name': 'Erneuter Versuch'});
      await expectLater(buffer.flush(), throwsA(isA<DomainError>()));
      expect(buffer.dirty, isTrue);
      repo.failWrites = false;
      await buffer.flush();
      expect(
        (await repo.dialogDrafts()).single.data['name'],
        'Erneuter Versuch',
      );
      buffer.dispose();
    },
  );

  testWidgets(
    'catalog validation, tabs, blank group tasks and optional reminder leave no drafts',
    (t) async {
      await app(t);
      unawaited(
        showCatalog(t.element(find.byType(Scaffold).first), c, 'social'),
      );
      await t.pumpAndSettle();
      await tap(t, find.text('− Negativ'));
      await tap(t, find.text('Hinzufügen'));
      await autosave(t);
      expect(await repo.dialogDrafts(), isEmpty);
      await close(t);
      unawaited(showBulk(t.element(find.byType(Scaffold).first), c));
      await t.pumpAndSettle();
      await tap(t, find.text('Hausübung'));
      await tap(t, find.text('Aufgabe hinzufügen'));
      await autosave(t);
      expect(await repo.dialogDrafts(), isEmpty);
      await t.enterText(find.byType(TextFormField).first, 'Lesen');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await autosave(t);
      final saved = (await repo.dialogDrafts()).single;
      expect((saved.data['tasks'] as List).first['text'], 'Lesen');
      await t.enterText(find.byType(TextFormField).first, '');
      await autosave(t);
      expect(await repo.dialogDrafts(), isEmpty);
      await tap(t, find.text('Organisatorisches'));
      await tap(t, find.text('Erinnern'));
      await autosave(t);
      expect(await repo.dialogDrafts(), isEmpty);
      await close(t);
      await finish(t);
    },
  );

  testWidgets(
    'Orga save and next always starts blank and preserves next pupil draft',
    (t) async {
      final old = await repo.saveDraft(
        EditDraft(
          id: 'existing-b',
          entry: OrgaEntry.empty(pupilId: 'b').copyWith(title: 'Alter Entwurf'),
          updatedAtUtc: utcNow(),
        ),
      );
      await c.reload();
      await app(t);
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(pupilId: 'a'),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        'Neue Notiz Anna',
      );
      await tap(t, find.text('Speichern & weiter'));
      final field = t.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('orga-note')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, isEmpty);
      await close(t);
      expect((await repo.drafts()).single.id, old.id);
      expect((await repo.entries()).single.pupilId, 'a');
      await finish(t);
    },
  );

  test(
    'baseline survives SQLite close, reopen and complete backup restore for all draft stores',
    () async {
      final dir = Directory.systemTemp.createTempSync('flex-draft-baseline-');
      SqliteNotebook connect(String name) => SqliteNotebook(
        NotebookDatabase(
          NativeDatabase(File('${dir.path}/$name.sqlite')),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      var disk = connect('original');
      await disk.initialize();
      final pupil = const Pupil(id: 'p', name: 'Prüfung');
      await disk.savePupil(pupil);
      final initial = SchoolRecord.empty(SchoolKind.social, 'p');
      final school = await disk.saveSchoolDraft(
        SchoolDraft(
          id: 's',
          record: initial.patch({'body': 'Eingabe'}),
          updatedAtUtc: utcNow(),
          baseline: draftSignature(initial.toJson()),
        ),
      );
      final orga = await disk.saveDraft(
        EditDraft(
          id: 'o',
          entry: OrgaEntry.empty(pupilId: 'p').copyWith(title: 'Eingabe'),
          updatedAtUtc: utcNow(),
          baseline: 'orga-original',
        ),
      );
      final dialog = await disk.saveDialogDraft(
        DialogDraft(
          id: 'd',
          type: 'pupil',
          ownerId: 'new',
          data: const Pupil(id: 'new', name: 'Eingabe').toJson(),
          updatedAtUtc: utcNow(),
          baseline: 'pupil-original',
        ),
      );
      await disk.close();
      disk = connect('original');
      await disk.initialize();
      expect((await disk.schoolDrafts()).single.baseline, school.baseline);
      expect((await disk.drafts()).single.baseline, orga.baseline);
      expect((await disk.dialogDrafts()).single.baseline, dialog.baseline);
      final backup = await disk.exportBackup();
      final restored = connect('restored');
      await restored.initialize();
      await restored.restoreBackup(backup);
      expect((await restored.schoolDrafts()).single.baseline, school.baseline);
      expect((await restored.drafts()).single.baseline, orga.baseline);
      expect((await restored.dialogDrafts()).single.baseline, dialog.baseline);
      await disk.close();
      await restored.close();
      dir.deleteSync(recursive: true);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'draft badges and pending counts stay distinct at narrow width scale $scale',
      (t) async {
        for (final kind in [SchoolKind.social, SchoolKind.work]) {
          for (var i = 0; i < 12; i++) {
            await repo.saveSchoolDraft(
              SchoolDraft(
                id: '${kind.name}-$i',
                record: SchoolRecord.empty(
                  kind,
                  'a',
                ).patch({'body': 'Entwurf $i'}),
                updatedAtUtc: utcNow(),
              ),
            );
          }
          await repo.saveSchoolRecord(
            SchoolRecord.empty(
              kind,
              'a',
            ).patch({'body': 'Noch ergänzen', 'needsCompletion': true}),
          );
        }
        await c.reload();
        final boundary = GlobalKey();
        const size = Size(320, 800);
        await app(t, size: size, boundary: boundary, scale: scale);
        await tap(t, find.byKey(const ValueKey('page-1')));
        final badge = find.byKey(const ValueKey('count-a-social'));
        await t.ensureVisible(badge);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final icon = find.descendant(
          of: find.byKey(const ValueKey('shortcut-a-social')),
          matching: find.byType(FlexIcon),
        );
        expect(t.getRect(icon).overlaps(t.getRect(badge)), isFalse);
        await capture(
          t,
          boundary,
          'ux-badges-320-${scale.toInt()}',
          size,
          scale,
          0,
        );
        await tap(t, find.byKey(const ValueKey('shortcut-a-social')));
        await tap(t, find.byKey(const ValueKey('entry-drafts')));
        expect(find.text('Fortsetzen'), findsWidgets);
        await finish(t);
      },
    );
  }

  testWidgets(
    'large text calendar keeps complete month and year readable above keyboard',
    (t) async {
      final boundary = GlobalKey();
      const size = Size(320, 700);
      await app(t, size: size, boundary: boundary, scale: 2, keyboard: 280);
      unawaited(
        pickFlexDate(
          t.element(find.byType(Scaffold).first),
          date: '2026-11-02',
        ),
      );
      await t.pumpAndSettle();
      for (final value in ['November', '2026']) {
        final text = find.text(value).hitTestable().first;
        final paragraph = t.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(paragraph.size.width + .01),
        );
      }
      await capture(t, boundary, 'ux-calendar-320-2', size, 2, 280);
      await tap(t, find.byTooltip('Nächster Monat'));
      await t.ensureVisible(find.byKey(const ValueKey('calendar-month')));
      await t.pumpAndSettle();
      expect(find.text('Dezember').hitTestable(), findsOneWidget);
      await tap(t, find.text('Übernehmen'));
      await finish(t);
    },
  );

  for (final view in [
    (320.0, 760.0, 1.0, 0.0),
    (390.0, 844.0, 1.0, 0.0),
    (1100.0, 900.0, 1.0, 0.0),
    (390.0, 844.0, 2.0, 260.0),
  ]) {
    for (final kind in [SchoolKind.homework, SchoolKind.social]) {
      testWidgets(
        'compact ${kind.name} filled rendering ${view.$1} scale ${view.$3} keyboard ${view.$4}',
        (t) async {
          final key = GlobalKey();
          final size = Size(view.$1, view.$2);
          final record = SchoolRecord.empty(kind, 'a').patch(
            kind == SchoolKind.homework
                ? {
                    'tasks': [
                      const HomeworkTask(
                        id: 'one',
                        text: 'Seite 12 lesen',
                      ).toJson(),
                      const HomeworkTask(
                        id: 'two',
                        text: 'Fragen beantworten',
                      ).toJson(),
                      const HomeworkTask(
                        id: 'child',
                        text: 'Beispiel ergänzen',
                        parentId: 'two',
                      ).toJson(),
                    ],
                  }
                : {
                    'positive': [
                      'Hilft anderen',
                      'Hält gemeinsame Absprachen ein',
                    ],
                    'contextTags': ['Vor Unterricht'],
                    'body': 'Beobachtung mit Freitext',
                  },
          );
          await app(
            t,
            size: size,
            boundary: key,
            scale: view.$3,
            keyboard: view.$4,
          );
          await open(t, SchoolEditor(controller: c, record: record));
          expect(t.takeException(), isNull);
          if (kind == SchoolKind.homework && view.$1 == 390 && view.$3 == 1) {
            expect(
              t.getSize(find.byKey(const ValueKey('modal-footer'))).height,
              lessThan(140),
            );
            expect(
              t.getSize(find.byKey(const ValueKey('modal-header'))).height,
              lessThan(110),
            );
          }
          await capture(
            t,
            key,
            'ux-${kind.name}-${view.$1.toInt()}-${view.$3.toInt()}',
            size,
            view.$3,
            view.$4,
          );
          await tap(t, find.byKey(const ValueKey('save-school-record')));
          expect(await repo.schoolRecords(), hasLength(1));
          expect(t.takeException(), isNull);
          await finish(t);
        },
      );
    }
  }
}
