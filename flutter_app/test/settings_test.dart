import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/database.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/settings.dart';
import 'package:flex_notizbuch/ui/appearance_settings.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';

class AppearanceStore extends SqliteNotebook {
  AppearanceStore(super.db);
  Completer<void>? hold;
  bool fail = false;
  @override
  Future<void> saveAppearance(Appearance appearance) async {
    await hold?.future;
    if (fail) throw const DomainError('Synthetischer Speicherfehler');
    await super.saveAppearance(appearance);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final schema = File('assets/schema.sql').readAsStringSync();
  late AppearanceStore repo;
  late NotebookController c;
  setUpAll(() async {
    await (FontLoader(
      'FlexSans',
    )..addFont(rootBundle.load('assets/fonts/Selawik-Regular.ttf'))).load();
  });
  setUp(() async {
    repo = AppearanceStore(NotebookDatabase(NativeDatabase.memory(), schema));
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(const Pupil(id: 'alpha', name: 'Alex Beispiel'));
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });

  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty &&
        find.byType(SettingsPage).evaluate().isNotEmpty) {
      t
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SettingsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      if (f.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          f,
          -150,
          scrollable: find
              .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> app(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(FlexApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> settings(WidgetTester t) async {
    await tap(t, find.byKey(const ValueKey('bottom-4')));
    await tap(t, find.byKey(const ValueKey('context-4-4')));
    await t.scrollUntilVisible(
      find.byType(AppearanceSettings),
      100,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.runAsync(c.flushAppearance);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  test(
    'legacy customization cannot override the new design; functional preferences survive',
    () {
      final a = Appearance.fromJson({
        'surfaceDefaultsVersion': 3,
        'mode': 'dark',
        'textScale': 1.25,
        'accent': 0xffff00ff,
        'cardColor': 0xff123456,
        'cardOpacity': .1,
        'desktopImage': 'old wallpaper',
        'mobileImage': 'old wallpaper',
        'uiScale': 1.2,
        'buttonRadius': 0,
        'pupilCompact': false,
        'defaultObservationTone': 'negative',
        'materialGrid': true,
        'materialSort': 'name',
        'shortcutOrder': ['orga', 'social', 'work', 'homework', 'goal'],
      });
      expect(a.mode, 'light');
      expect(a.textScale, 1.25);
      expect(a.defaultObservationTone, 'negative');
      expect(a.materialGrid, isTrue);
      expect(a.materialSort, 'name');
      expect(a.shortcutOrder.first, 'orga');
      for (final old in [
        'accent',
        'desktopImage',
        'mobileImage',
        'uiScale',
        'buttonRadius',
        'cardOpacity',
        'pupilCompact',
      ]) {
        expect(a.toJson(), isNot(contains(old)));
      }
      expect(Appearance.fromJson(a.toJson()).toJson(), a.toJson());
      expect(
        Appearance.fromJson(a.patch({'mode': 'dark'}).toJson()).mode,
        'dark',
      );
      for (final invalid in <Json>[
        {'textScale': double.nan},
        {'textScale': .79},
        {'textScale': 1.61},
        {'mode': 'invalid'},
        {
          'shortcutOrder': ['goal'],
        },
      ]) {
        expect(() => a.patch(invalid), throwsA(isA<DomainError>()));
      }
    },
  );

  test(
    'both fixed palettes give readable text on opaque fields, navigation and cards',
    () {
      for (final brightness in Brightness.values) {
        final p = FlexPalette(const Appearance(), brightness);
        for (final pair in [
          (p.field, p.fieldInk),
          (p.card, p.cardInk),
          (p.selection, p.ink),
          (p.backdrop, p.secondaryInk),
        ]) {
          expect(pair.$1.a, 1);
          final luminances = [
            pair.$1.computeLuminance(),
            pair.$2.computeLuminance(),
          ]..sort();
          expect(
            (luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    },
  );

  test(
    'serial writes retain latest preview and roll back a failed latest write',
    () async {
      repo.hold = Completer();
      final first = c.saveAppearance(c.appearance.change({'textScale': 1.2}));
      final second = c.saveAppearance(c.appearance.change({'mode': 'dark'}));
      expect(c.appearance.textScale, 1.2);
      expect(c.appearance.mode, 'dark');
      repo.hold!.complete();
      await Future.wait([first, second]);
      expect((await repo.appearance()).toJson(), c.appearance.toJson());
      repo.fail = true;
      await expectLater(
        c.saveAppearance(c.appearance.change({'textScale': 1.5})),
        throwsA(isA<DomainError>()),
      );
      expect(c.appearance.textScale, 1.2);
      expect(c.appearanceError, isNotNull);
      repo.fail = false;
      await c.saveAppearance(c.appearance.change({'textScale': 1.1}));
      expect(c.appearanceError, isNull);
    },
  );

  test(
    'old database preferences migrate through restart and backup without losing pupils, records or drafts',
    () async {
      final entry = await repo.saveEntry(
        OrgaEntry.empty(pupilId: 'alpha').copyWith(
          title: 'Elterngespräch vorbereiten',
          body: 'Elterngespräch vorbereiten',
          isTask: true,
        ),
      );
      final draft = SchoolDraft(
        id: 'draft',
        record: SchoolRecord.empty(
          SchoolKind.social,
          'alpha',
        ).patch({'body': 'Beobachtung bleibt erhalten'}),
        updatedAtUtc: utcNow(),
      );
      await repo.saveSchoolDraft(draft);
      await repo.db.customStatement(
        "INSERT INTO preferences(key,payload) VALUES ('appearance',?)",
        [
          jsonEncode({
            'mode': 'dark',
            'desktopImage': 'legacy',
            'textScale': 1.3,
            'defaultObservationTone': 'positive',
          }),
        ],
      );
      await c.reload();
      expect(c.appearance.mode, 'light');
      expect(c.appearance.textScale, 1.3);
      final backup = await repo.exportBackup();
      final restored = SqliteNotebook(
        NotebookDatabase(NativeDatabase.memory(), schema),
      );
      await restored.initialize();
      await restored.restoreBackup(backup);
      expect((await restored.pupils()).single.name, 'Alex Beispiel');
      expect((await restored.entries()).single.toJson(), entry.toJson());
      expect(
        (await restored.schoolDrafts()).single.record.body,
        draft.record.body,
      );
      expect((await restored.appearance()).mode, 'light');
      expect((await restored.appearance()).defaultObservationTone, 'positive');
      await restored.close();
      final dir = Directory.systemTemp.createTempSync('flex-design-');
      final file = File('${dir.path}/test.sqlite');
      var disk = SqliteNotebook(NotebookDatabase(NativeDatabase(file), schema));
      await disk.initialize();
      await disk.saveAppearance(c.appearance.patch({'mode': 'system'}));
      await disk.close();
      disk = SqliteNotebook(NotebookDatabase(NativeDatabase(file), schema));
      await disk.initialize();
      expect((await disk.appearance()).mode, 'system');
      expect((await disk.appearance()).textScale, 1.3);
      await disk.close();
      dir.deleteSync(recursive: true);
    },
  );

  for (final view in [
    (const Size(390, 844), 1.0),
    (const Size(320, 740), 2.0),
    (const Size(1100, 900), 1.0),
  ]) {
    testWidgets(
      'only two design controls, live preview and reachable settings at $view',
      (t) async {
        await app(t, size: view.$1, scale: view.$2);
        await settings(t);
        expect(find.byType(Slider), findsOneWidget);
        for (final label in ['Hell', 'Dunkel', 'System', 'Schriftgröße']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Hintergrundbild'), findsNothing);
        await tap(t, find.byKey(const ValueKey('appearance-mode-dark')));
        await t.runAsync(c.flushAppearance);
        expect(c.appearance.mode, 'dark');
        final slider = find.byKey(const ValueKey('appearance-text-scale'));
        await t.ensureVisible(slider);
        t.widget<Slider>(slider).onChanged!(1.3);
        await t.pumpAndSettle();
        await t.runAsync(c.flushAppearance);
        expect((await repo.appearance()).textScale, 1.3);
        await tap(t, find.byKey(const ValueKey('appearance-reset-size')));
        expect(c.appearance.textScale, 1);
        await tap(t, find.byKey(const ValueKey('settings-tab-1')));
        expect(find.text('Standard für Beobachtungen'), findsOneWidget);
        await tap(t, find.byKey(const ValueKey('shortcut-up-orga')));
        expect(c.appearance.shortcutOrder[3], 'orga');
        await tap(t, find.byKey(const ValueKey('settings-tab-0')));
        t
            .widget<TextButton>(find.byKey(const ValueKey('settings-tab-0')))
            .focusNode!
            .requestFocus();
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.end);
        await t.pumpAndSettle();
        expect(find.text('Standard für Beobachtungen'), findsOneWidget);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  testWidgets(
    'all five pupil actions open fresh editors without changing an existing draft',
    (t) async {
      final draft = SchoolRecord.empty(
        SchoolKind.social,
        'alpha',
      ).patch({'body': 'Noch nicht gespeichert'});
      await repo.saveSchoolDraft(
        SchoolDraft(id: 'resume', record: draft, updatedAtUtc: utcNow()),
      );
      await c.reload();
      await app(t);
      await tap(t, find.byKey(const ValueKey('bottom-1')));
      await tap(t, find.byKey(const ValueKey('page-1')));
      for (final symbol in ['social', 'work', 'goal', 'homework', 'orga']) {
        await tap(t, find.byKey(ValueKey('shortcut-alpha-$symbol')));
        if (symbol == 'orga') {
          expect(find.byType(OrgaEditor), findsOneWidget);
        } else {
          final editor = t.widget<SchoolEditor>(find.byType(SchoolEditor));
          expect(editor.record.pupilId, 'alpha');
          expect(editor.record.kind.name, symbol);
          if (symbol == 'social') {
            expect(editor.draft, isNull);
            expect(editor.record.id, isNot(draft.id));
          }
        }
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
      }
      expect(await repo.schoolRecords(), isEmpty);
      expect((await repo.schoolDrafts()).single.id, 'resume');
      await finish(t);
    },
  );

  testWidgets(
    'failed pending preference save is visible after leaving settings',
    (t) async {
      await app(t);
      await settings(t);
      repo.fail = true;
      c.previewAppearance({'textScale': 1.3});
      await tap(t, find.byKey(const ValueKey('bottom-1')));
      await t.runAsync(c.flushAppearance);
      await t.pumpAndSettle();
      expect(c.appearance.textScale, 1);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(
        find.text('Nicht gespeichert. Bitte erneut versuchen.'),
        findsOneWidget,
      );
      repo.fail = false;
      await finish(t);
    },
  );
}
