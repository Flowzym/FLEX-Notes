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
import 'package:flex_notizbuch/ui/orga_list_editing.dart';
import 'package:flex_notizbuch/ui/overview_entry.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';

class ControlledDraftNotebook extends SqliteNotebook {
  ControlledDraftNotebook(super.db);
  bool failWrites = false;
  Completer<void>? hold;
  @override
  Future<SchoolDraft> saveSchoolDraft(SchoolDraft draft) async {
    if (failWrites) throw const DomainError('Synthetischer Entwurfsfehler');
    await hold?.future;
    return super.saveSchoolDraft(draft);
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
        '${jsonEncode({'file': '$name.png', 'width': size.width, 'height': size.height, 'textScale': scale, 'keyboardInset': keyboard, 'engine': 'flutter_test RenderRepaintBoundary', 'source': '0.16.0-rebuild.8 UI audit', 'data': 'synthetic'})}\n',
        mode: FileMode.append,
      );
    });
  }

  Future<void> close(WidgetTester t) =>
      tap(t, find.byTooltip('Schließen und Eingaben sichern'));
  Future<void> settleDraft(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
  }

  EditableText input(WidgetTester t, Key key) => t.widget<EditableText>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(EditableText))
        .last,
  );
  test(
    'automatic surfaces use neutral role colors and migrate only unchanged old defaults',
    () {
      final a = const Appearance();
      final palette = FlexPalette(a, Brightness.dark);
      for (final color in [palette.card, palette.field]) {
        expect(color.toARGB32() & 0xffffff, 0);
        expect(color.a, lessThan(.5));
      }
      for (final color in [palette.header, palette.footer, palette.button]) {
        expect(color.toARGB32() & 0xffffff, 0xffffff);
        expect(color.a, lessThan(.5));
      }
      final old = {...a.toJson()}..remove('surfaceDefaultsVersion');
      old.addAll({
        'headerOpacity': .65,
        'footerOpacity': .65,
        'cardOpacity': .82,
        'buttonOpacity': .94,
        'fieldOpacity': .94,
        'workspaceOpacity': .88,
      });
      expect(Appearance.fromJson(old).toJson(), a.toJson());
      final custom = Appearance.fromJson({
        ...old,
        'fieldColor': 0xff123456,
        'headerOpacity': .47,
      });
      expect(custom.fieldColor, 0xff123456);
      expect(custom.headerOpacity, .47);
      expect(custom.cardOpacity, .82);
      expect(
        FlexPalette(custom, Brightness.dark).field.toARGB32() & 0xffffff,
        0x123456,
      );
    },
  );

  test(
    'list styling replaces and toggles prefixes across selected lines; Enter renumbers following items',
    () {
      TextEditingValue at(String text, [int? cursor]) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      );
      expect(styleOrgaLines(at('Eins'), 'number').text, '1. Eins');
      expect(styleOrgaLines(at('1. Eins'), 'number').text, 'Eins');
      expect(styleOrgaLines(at('• Eins'), 'number').text, '1. Eins');
      final block = styleOrgaLines(
        const TextEditingValue(
          text: 'Eins\nZwei\nDrei',
          selection: TextSelection(baseOffset: 0, extentOffset: 9),
        ),
        'number',
      );
      expect(block.text, '1. Eins\n2. Zwei\nDrei');
      expect(
        continueOrgaLine(at('1. Eins\n2. Zwei', 7))!.text,
        '1. Eins\n2. \n3. Zwei',
      );
      expect(continueOrgaLine(at('• Eins'))!.text, '• Eins\n• ');
      expect(continueOrgaLine(at('  9. Neun'))!.text, '  9. Neun\n  10. ');
      expect(continueOrgaLine(at('1. Eins\n2. '))!.text, '1. Eins\n');
      expect(
        continueOrgaLine(at('- [x] Fertig'))!.text,
        '- [x] Fertig\n- [ ] ',
      );
      expect(continueOrgaLine(at('Freier Text')), isNull);
      final pasted = at('1. Eins\nUnverändert eingefügt');
      expect(
        OrgaListFormatter().formatEditUpdate(at('1. Eins'), pasted),
        pasted,
      );
      final composing = at(
        '1. Eins\n',
      ).copyWith(composing: const TextRange(start: 0, end: 1));
      expect(
        OrgaListFormatter().formatEditUpdate(at('1. Eins'), composing),
        composing,
      );
    },
  );

  testWidgets(
    'Orga hardware Enter and IME newline continue lists, blank Enter exits, formatting alone is no draft',
    (t) async {
      await app(t);
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(pupilId: 'a'),
        ),
      );
      await tap(t, find.byTooltip('Nummerierung'));
      await settleDraft(t);
      expect(await repo.drafts(), isEmpty);
      await t.enterText(find.byKey(const ValueKey('orga-note')), '1. Milch');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(
        input(t, const ValueKey('orga-note')).controller.text,
        '1. Milch\n2. ',
      );
      await t.enterText(
        find.byKey(const ValueKey('orga-note')),
        '1. Milch\n2. Brot',
      );
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '1. Milch\n2. Brot\n',
          selection: TextSelection.collapsed(offset: 17),
        ),
      );
      await t.pumpAndSettle();
      expect(
        input(t, const ValueKey('orga-note')).controller.text,
        '1. Milch\n2. Brot\n3. ',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(
        input(t, const ValueKey('orga-note')).controller.text,
        '1. Milch\n2. Brot\n',
      );
      await t.enterText(find.byKey(const ValueKey('orga-note')), '• Milch');
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(
        input(t, const ValueKey('orga-note')).controller.text,
        '• Milch\n',
      );
      await t.enterText(find.byKey(const ValueKey('orga-note')), '• Milch');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(
        input(t, const ValueKey('orga-note')).controller.text,
        '• Milch\n• ',
      );
      await close(t);
      final draft = (await repo.drafts()).single;
      expect(draft.entry.body, '• Milch\n• ');
      await open(
        t,
        OrgaEditor(controller: c, entry: draft.entry, draftId: draft.id),
      );
      expect(
        input(t, const ValueKey('orga-note')).controller.text,
        '• Milch\n• ',
      );
      await tap(t, find.text('Speichern'));
      expect((await repo.entries()).single.title, 'Milch');
      expect((await repo.entries()).single.body, '• Milch\n• ');
      await finish(t);
    },
  );

  testWidgets(
    'checklist Enter keeps focus, splits existing items and exits empty rows without losing checks',
    (t) async {
      await app(t);
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(pupilId: 'a'),
        ),
      );
      await t.enterText(find.byKey(const ValueKey('orga-note')), 'Einkauf');
      await tap(t, find.byTooltip('Checkliste'));
      await t.enterText(
        find.byKey(const ValueKey('orga-new-item')),
        'Milch Brot',
      );
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      expect(
        input(t, const ValueKey('orga-new-item')).focusNode.hasFocus,
        isTrue,
      );
      await settleDraft(t);
      final first = (await repo.drafts()).single.entry.items.single;
      final key = ValueKey('orga-item-${first.id}');
      await t.tap(find.byKey(key));
      input(t, key).controller.selection = const TextSelection.collapsed(
        offset: 6,
      );
      await t.testTextInput.receiveAction(TextInputAction.next);
      await settleDraft(t);
      final items = (await repo.drafts()).single.entry.items;
      expect(items.map((i) => i.text), ['Milch ', 'Brot']);
      expect(items.first.id, first.id);
      expect(
        input(t, ValueKey('orga-item-${items.last.id}')).focusNode.hasFocus,
        isTrue,
      );
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      expect(input(t, const ValueKey('orga-note')).focusNode.hasFocus, isTrue);
      await t.tap(find.byType(Checkbox).first);
      await t.pumpAndSettle();
      await tap(t, find.text('Speichern'));
      final entry = (await repo.entries()).single;
      expect(entry.items.map((i) => i.text), ['Milch ', 'Brot']);
      expect(entry.items.first.checked, isTrue);
      expect(entry.items.last.checked, isFalse);
      await finish(t);
    },
  );

  testWidgets(
    'fresh modal header resumes only selected draft; pending input and other categories stay intact',
    (t) async {
      for (final kind in [SchoolKind.social, SchoolKind.work]) {
        await repo.saveSchoolDraft(
          SchoolDraft(
            id: kind.name,
            record: SchoolRecord.empty(
              kind,
              'a',
            ).patch({'body': 'Alt ${kind.name}'}),
            updatedAtUtc: utcNow(),
          ),
        );
      }
      await c.reload();
      await app(t);
      await tap(t, find.byKey(const ValueKey('page-1')));
      expect(find.byIcon(Icons.edit_note), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('count-a-social')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tap(t, find.byKey(const ValueKey('shortcut-a-social')));
      expect(find.text('Alt social'), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('record-body')),
        'Neue Eingabe',
      );
      await tap(t, find.byKey(const ValueKey('entry-drafts')));
      expect(find.text('Alt social'), findsOneWidget);
      expect(find.text('Alt work'), findsNothing);
      expect(find.text('Fortsetzen'), findsOneWidget);
      await tap(t, find.text('Fortsetzen'));
      expect(
        t.widget<SchoolEditor>(find.byType(SchoolEditor).last).draft!.id,
        'social',
      );
      await tap(t, find.byKey(const ValueKey('save-school-record')).last);
      await close(t);
      expect(
        input(t, const ValueKey('record-body')).controller.text,
        'Neue Eingabe',
      );
      await close(t);
      expect((await repo.schoolRecords()).single.body, 'Alt social');
      expect(
        (await repo.schoolDrafts()).map((d) => d.record.body),
        containsAll(['Neue Eingabe', 'Alt work']),
      );
      await finish(t);
    },
  );

  testWidgets(
    'homework header opens assigned homework and keeps unpublished tasks separate',
    (t) async {
      final existing = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'a').patch({
          'tasks': [
            const HomeworkTask(id: 'given', text: 'Schon aufgegeben').toJson(),
          ],
        }),
      );
      await c.reload();
      await app(t, size: const Size(390, 844));
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.homework, 'a'),
        ),
      );
      await t.enterText(find.byType(TextFormField).first, 'Neue Hausübung');
      final header = find.byKey(const ValueKey('modal-header')).last;
      expect(
        find.descendant(
          of: header,
          matching: find.byKey(const ValueKey('assigned-homework')),
        ),
        findsOneWidget,
      );
      await tap(t, find.byKey(const ValueKey('assigned-homework')));
      expect(
        find.descendant(
          of: find.byType(SchoolWorkspace),
          matching: find.text('Schon aufgegeben'),
        ),
        findsOneWidget,
      );
      await tap(t, find.byKey(const ValueKey('status-given-complete')));
      expect(
        (await repo.schoolRecords()).single.taskState(existing.tasks.single),
        TaskState.complete,
      );
      await close(t);
      expect(find.text('Neue Hausübung'), findsOneWidget);
      await close(t);
      expect(
        (await repo.schoolDrafts()).single.record.tasks.single.text,
        'Neue Hausübung',
      );
      await finish(t);
    },
  );

  testWidgets(
    'Orga header filters pupil and class drafts and preserves current note',
    (t) async {
      for (final owner in ['a', 'b', null]) {
        await repo.saveDraft(
          EditDraft(
            id: 'orga-$owner',
            entry: OrgaEntry.empty(
              pupilId: owner,
            ).copyWith(title: 'Alt $owner', body: 'Alt $owner'),
            updatedAtUtc: utcNow(),
          ),
        );
      }
      await c.reload();
      await app(t);
      for (final owner in ['a', null]) {
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: owner),
          ),
        );
        await t.enterText(
          find.byKey(const ValueKey('orga-note')),
          'Neu $owner',
        );
        await tap(t, find.byKey(const ValueKey('entry-drafts')));
        expect(find.text('Alt $owner'), findsOneWidget);
        expect(find.text('Alt b'), findsNothing);
        expect(find.text('Fortsetzen'), findsOneWidget);
        await tap(t, find.text('Fortsetzen'));
        await tap(t, find.text('Speichern'));
        await close(t);
        expect(
          input(t, const ValueKey('orga-note')).controller.text,
          'Neu $owner',
        );
        await close(t);
      }
      expect(
        (await repo.entries()).map((e) => e.body),
        containsAll(['Alt a', 'Alt null']),
      );
      expect(
        (await repo.drafts()).map((d) => d.entry.body),
        containsAll(['Alt b', 'Neu a', 'Neu null']),
      );
      await finish(t);
    },
  );

  testWidgets(
    'header navigation waits for draft storage and stays in editor after a failed write',
    (t) async {
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'a'),
        ),
      );
      repo.failWrites = true;
      await t.enterText(
        find.byKey(const ValueKey('record-body')),
        'Ungesicherte Eingabe',
      );
      await tap(t, find.byKey(const ValueKey('entry-drafts')));
      expect(find.text('Entwürfe · Sozialverhalten'), findsNothing);
      expect(find.text('Entwurf nicht gesichert'), findsOneWidget);
      expect(
        input(t, const ValueKey('record-body')).controller.text,
        'Ungesicherte Eingabe',
      );
      repo.failWrites = false;
      repo.hold = Completer<void>();
      await t.tap(find.byKey(const ValueKey('entry-drafts')));
      await t.pump();
      expect(find.text('Keine weiteren gesicherten Entwürfe.'), findsNothing);
      repo.hold!.complete();
      await t.pumpAndSettle();
      expect(find.text('Keine weiteren gesicherten Entwürfe.'), findsOneWidget);
      await close(t);
      expect(
        input(t, const ValueKey('record-body')).controller.text,
        'Ungesicherte Eingabe',
      );
      await close(t);
      expect(
        (await repo.schoolDrafts()).single.record.body,
        'Ungesicherte Eingabe',
      );
      await finish(t);
    },
  );

  Future<void> seed() async {
    await repo.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.homework, 'a').patch({
        'id': 'homework',
        'subject': 'Mathematik',
        'tasks': [
          const HomeworkTask(
            id: 'task',
            text: 'Seite 12: Aufgaben 1 bis 4',
          ).toJson(),
        ],
        'dueDate': '2026-11-05',
      }),
    );
    await repo.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.social, 'b').patch({
        'body': 'Hat in der Gruppe Verantwortung übernommen.',
        'positive': ['Hilft anderen'],
      }),
    );
    await repo.saveSchoolRecord(
      SchoolRecord.empty(SchoolKind.goal, 'b').patch({
        'title': 'Arbeitsaufträge selbstständig beginnen',
        'nextReviewDate': '2026-11-06',
      }),
    );
    await repo.saveEntry(
      OrgaEntry.empty().copyWith(
        title: 'Material für den Ausflug',
        body: 'Buszeiten und Einverständnisse prüfen',
        isTask: true,
        items: [
          const CheckItem(id: 'check', text: 'Bus gebucht', checked: true),
        ],
      ),
    );
    await repo.saveSchoolDraft(
      SchoolDraft(
        id: 'draft-social',
        record: SchoolRecord.empty(
          SchoolKind.social,
          'a',
        ).patch({'body': 'Begonnene Beobachtung'}),
        updatedAtUtc: utcNow(),
      ),
    );
    await c.reload();
  }

  for (final view in [
    (320.0, 700.0, 1.0),
    (390.0, 844.0, 1.0),
    (1200.0, 1000.0, 1.0),
    (320.0, 800.0, 2.0),
  ]) {
    testWidgets(
      'numeric pupil badges and both homework header routes ${view.$1} font ${view.$3}',
      (t) async {
        await seed();
        for (final kind in [SchoolKind.homework, SchoolKind.work]) {
          await repo.saveSchoolDraft(
            SchoolDraft(
              id: 'draft-${kind.name}',
              record: SchoolRecord.empty(kind, 'a').patch(
                kind == SchoolKind.homework
                    ? {
                        'tasks': [
                          const HomeworkTask(
                            id: 'draft-task',
                            text: 'Noch nicht aufgegeben',
                          ).toJson(),
                        ],
                      }
                    : {'body': 'Begonnene Arbeitsbeobachtung'},
              ),
              updatedAtUtc: utcNow(),
            ),
          );
        }
        await c.reload();
        final boundary = GlobalKey();
        final size = Size(view.$1, view.$2);
        await app(t, size: size, scale: view.$3, boundary: boundary);
        await tap(t, find.byKey(const ValueKey('page-1')));
        for (final entry in {
          'social': '1',
          'work': '1',
          'homework': '2',
        }.entries) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('count-a-${entry.key}')),
              matching: find.text(entry.value),
            ),
            findsOneWidget,
          );
        }
        expect(find.byIcon(Icons.edit_note), findsNothing);
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          'numeric-cards-${view.$1.toInt()}-${view.$3.toInt()}',
          size,
          view.$3,
          0,
        );
        await tap(t, find.byKey(const ValueKey('shortcut-a-homework')));
        expect(find.byKey(const ValueKey('entry-drafts')), findsOneWidget);
        expect(find.byKey(const ValueKey('assigned-homework')), findsOneWidget);
        expect(find.text('Noch nicht aufgegeben'), findsNothing);
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          'homework-header-${view.$1.toInt()}-${view.$3.toInt()}',
          size,
          view.$3,
          0,
        );
        await tap(t, find.byKey(const ValueKey('assigned-homework')));
        expect(find.byType(SchoolWorkspace), findsOneWidget);
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          'assigned-homework-${view.$1.toInt()}-${view.$3.toInt()}',
          size,
          view.$3,
          0,
        );
        await finish(t);
      },
    );
    testWidgets(
      'overview summaries and neutral surfaces ${view.$1} font ${view.$3}',
      (t) async {
        await seed();
        final boundary = GlobalKey();
        final size = Size(view.$1, view.$2);
        await app(t, size: size, scale: view.$3, boundary: boundary);
        if (find.byType(OverviewEntry).evaluate().isEmpty) {
          await t.scrollUntilVisible(
            find.byType(OverviewEntry).first,
            160,
            scrollable: find
                .descendant(
                  of: find.byKey(const PageStorageKey('overview')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        expect(find.byType(OverviewEntry), findsWidgets);
        for (final type in [Chip, ChoiceChip, FilterChip, Checkbox]) {
          expect(find.byType(type), findsNothing);
        }
        expect(find.byType(SchoolRecordCard), findsNothing);
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          'overview-${view.$1.toInt()}-${view.$3.toInt()}',
          size,
          view.$3,
          0,
        );
        await tap(t, find.byKey(const ValueKey('overview-open-homework')));
        await tap(t, find.byKey(const ValueKey('status-task-partial')));
        expect(
          (await repo.schoolRecords())
              .firstWhere((r) => r.id == 'homework')
              .taskState(const HomeworkTask(id: 'task', text: '')),
          TaskState.partial,
        );
        await finish(t);
      },
    );
    testWidgets(
      'shared positive negative pill and header access ${view.$1} font ${view.$3}',
      (t) async {
        await seed();
        final boundary = GlobalKey();
        final size = Size(view.$1, view.$2);
        await app(t, size: size, scale: view.$3, boundary: boundary);
        await open(
          t,
          SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.social, 'a'),
          ),
        );
        final pill = find.byKey(const ValueKey('tone-pill'));
        for (final value in ['positive', 'neutral', 'negative']) {
          expect(
            find.descendant(
              of: pill,
              matching: find.byKey(ValueKey('tone-$value')),
            ),
            findsOneWidget,
          );
        }
        await tap(t, find.byKey(const ValueKey('tone-negative')));
        expect((await repo.schoolDrafts()).single.id, 'draft-social');
        await capture(
          t,
          boundary,
          'pill-${view.$1.toInt()}-${view.$3.toInt()}',
          size,
          view.$3,
          0,
        );
        await close(t);
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: 'a'),
          ),
        );
        await t.enterText(
          find.byKey(const ValueKey('orga-note')),
          '1. Material vorbereiten\n2. Aufgaben ausdrucken',
        );
        t.view.viewInsets = const FakeViewPadding(bottom: 240);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          'orga-keyboard-${view.$1.toInt()}-${view.$3.toInt()}',
          size,
          view.$3,
          240,
        );
        await tap(t, find.text('Speichern'));
        expect(await repo.entries(), hasLength(2));
        await finish(t);
      },
    );
  }
}
