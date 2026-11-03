import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
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
import 'package:flex_notizbuch/ui/appearance_settings.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/pupil_card.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/ui/settings.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';

class AppearanceStore extends SqliteNotebook {
  AppearanceStore(super.db);
  Completer<void>? hold;
  bool fail = false;
  final saved = <Appearance>[];
  @override
  Future<void> saveAppearance(Appearance appearance) async {
    await hold?.future;
    if (fail) throw const DomainError('Synthetischer Speicherfehler');
    await super.saveAppearance(appearance);
    saved.add(appearance);
  }
}

class PicturePicker extends FileSelectorPlatform {
  XFile? next;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => next;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final schema = File('assets/schema.sql').readAsStringSync();
  final pattern = base64Encode(
    File('test/fixtures/appearance-pattern.png').readAsBytesSync(),
  );
  final solid = base64Encode(
    File('test/fixtures/appearance-solid.png').readAsBytesSync(),
  );
  late AppearanceStore repo;
  late NotebookController c;
  setUpAll(() async {
    for (final font in {
      'FlexSans': [
        'assets/fonts/Selawik-Regular.ttf',
        'assets/fonts/Selawik-Semibold.ttf',
        'assets/fonts/Selawik-Bold.ttf',
      ],
      'FlexSerif': ['assets/fonts/Gelasio-Regular.ttf'],
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
    repo = AppearanceStore(NotebookDatabase(NativeDatabase.memory(), schema));
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(const Pupil(id: 'alpha', name: 'Anna Beispiel'));
    await c.saveAppearance(
      const Appearance().patch({
        'defaultTexture': false,
        'backgroundColor': 0xff304050,
      }),
    );
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });
  Future<void> app(
    WidgetTester t, {
    Size size = const Size(1100, 900),
    GlobalKey? boundary,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    await t.binding.setSurfaceSize(size);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FlexApp(controller: c),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.runAsync(c.flushAppearance);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    t.view.resetViewInsets();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    await t.binding.setSurfaceSize(null);
  }

  Future<void> settings(WidgetTester t) async {
    await t.tap(find.byType(PopupMenuButton<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Einstellungen').last);
    await t.pumpAndSettle();
  }

  Future<void> click(WidgetTester t, Finder f) async {
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
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    final directory = Platform.environment['FLEX_RENDER_DIR'];
    if (directory == null) return;
    await t.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test(
    'partial old values keep each existing value and reject invalid values',
    () {
      final a = Appearance.fromJson({'accent': 0xffabcdef, 'cardOpacity': .3});
      expect(a.accent, 0xffabcdef);
      expect(a.cardOpacity, .3);
      expect(a.workspaceOpacity, .12);
      for (final change in <Json>[
        {'fieldOpacity': double.nan},
        {'modalOpacity': -1},
        {'backgroundDim': .81},
        {
          'shortcutOrder': ['goal'],
        },
        {'cardRadius': 33},
        {'mobileFit': 'unknown'},
      ]) {
        expect(() => a.patch(change), throwsA(isA<DomainError>()));
      }
    },
  );
  test(
    'linking uses button values, includes every surface and preserves alpha on color change',
    () {
      var a = c.appearance.change({
        'buttonColor': 0xffeeeedd,
        'buttonOpacity': .4,
      });
      a = a.change({'coupleSurfaces': true});
      for (final key in Appearance.surfaceColors) {
        expect(a.toJson()[key], 0xffeeeedd);
      }
      for (final key in Appearance.surfaceOpacities) {
        expect(a.toJson()[key], .4);
      }
      a = a.change({'dialogColor': 0xff004433});
      for (final key in Appearance.surfaceColors) {
        expect(a.toJson()[key], 0xff004433);
      }
      for (final key in Appearance.surfaceOpacities) {
        expect(a.toJson()[key], .4);
      }
      a = a.change({'coupleSurfaces': false}).change({'fieldOpacity': .8});
      expect(a.buttonOpacity, .4);
      expect(a.fieldOpacity, .8);
    },
  );
  test(
    'readability guard is disabled only by manual reading-surface alpha changes',
    () {
      final a = c.appearance.patch({
        'desktopImage': solid,
        'readabilityProtection': true,
      });
      expect(a.change({'fieldOpacity': .1}).readabilityProtection, isTrue);
      expect(a.change({'cardOpacity': .1}).readabilityProtection, isFalse);
      expect(
        a.change({
          'coupleSurfaces': true,
          'buttonOpacity': .1,
        }).readabilityProtection,
        isFalse,
      );
      final protected = FlexPalette(a, Brightness.dark);
      expect(protected.card.a, 1);
      expect(protected.modal.a, 1);
      expect(a.cardOpacity, .28);
    },
  );
  test(
    'serial writes keep latest preview and roll back only a failed latest write',
    () async {
      repo.hold = Completer();
      final first = c.saveAppearance(c.appearance.change({'cardOpacity': .2}));
      final second = c.saveAppearance(
        c.appearance.change({'dialogColor': 0xffeeeeee}),
      );
      expect(c.appearance.cardOpacity, .2);
      expect(c.appearance.dialogColor, 0xffeeeeee);
      repo.hold!.complete();
      await Future.wait([first, second]);
      expect((await repo.appearance()).toJson(), c.appearance.toJson());
      repo.fail = true;
      await expectLater(
        c.saveAppearance(c.appearance.change({'cardOpacity': .7})),
        throwsA(isA<DomainError>()),
      );
      expect(c.appearance.cardOpacity, .2);
      expect(c.appearanceError, isNotNull);
      repo.fail = false;
      await c.saveAppearance(c.appearance.change({'fieldOpacity': .3}));
      expect(c.appearanceError, isNull);
    },
  );
  test(
    'file restart and full backup retain all appearance values and both images',
    () async {
      final directory = await Directory.systemTemp.createTemp('flex-settings-');
      final file = File('${directory.path}/notebook.sqlite');
      var database = SqliteNotebook(
        NotebookDatabase(NativeDatabase(file), schema),
      );
      await database.initialize();
      final value = c.appearance.change({
        'uiScale': .85,
        'textScale': 1.55,
        'fieldRadius': 4.0,
        'buttonRadius': 6.0,
        'modalRadius': 12.0,
        'desktopImage': pattern,
        'mobileImage': solid,
        'desktopImageName': 'Desktop.png',
        'mobileImageName': 'Mobil.png',
        'desktopFit': 'fill',
        'mobileFit': 'tile',
        'dialogColor': 0xff324d60,
        'headerOpacity': .2,
        'footerOpacity': .6,
        'workspaceOpacity': .4,
        'cardOpacity': .3,
        'buttonOpacity': .7,
        'fieldOpacity': .8,
        'modalOpacity': .9,
        'backgroundTintStrength': .25,
        'backgroundDim': .3,
        'shortcutOrder': ['orga', 'homework', 'work', 'social', 'goal'],
      });
      await database.saveAppearance(value);
      await database.close();
      database = SqliteNotebook(NotebookDatabase(NativeDatabase(file), schema));
      await database.initialize();
      expect((await database.appearance()).toJson(), value.toJson());
      final backup = await database.exportBackup();
      await database.close();
      final restored = SqliteNotebook(
        NotebookDatabase(NativeDatabase.memory(), schema),
      );
      await restored.initialize();
      await restored.restoreBackup(backup);
      expect((await restored.appearance()).toJson(), value.toJson());
      await restored.close();
      await directory.delete(recursive: true);
    },
  );
  test(
    'width, rotation, missing image fallback and chosen view mode are independent',
    () {
      final a = c.appearance.patch({
        'desktopImage': pattern,
        'mobileImage': solid,
        'desktopFit': 'fill',
        'mobileFit': 'contain',
      });
      expect(a.imageForWidth(700), solid);
      expect(a.imageForWidth(701), pattern);
      expect(a.patch({'mobileImage': ''}).imageForWidth(390), pattern);
      expect(a.patch({'desktopImage': ''}).imageForWidth(1100), solid);
      expect(a.fitForWidth(390), 'contain');
      expect(a.fitForWidth(844), 'fill');
      expect(a.preset('calm').imageEnabled, isFalse);
      expect(a.preset('calm').desktopImage, pattern);
    },
  );
  testWidgets(
    'image preparation accepts PNG and rejects broken data without replacing originals',
    (t) async {
      await t.runAsync(() async {
        final prepared = await prepareAppearanceImage(base64Decode(pattern));
        expect(prepared, isNotEmpty);
        await expectLater(
          prepareAppearanceImage(base64Decode('YWJj')),
          throwsA(isA<DomainError>()),
        );
        await expectLater(
          prepareAppearanceImage(base64Decode(pattern).sublist(0, 10)),
          throwsA(anything),
        );
      });
    },
  );
  for (final size in [const Size(1100, 900), const Size(320, 740)]) {
    testWidgets(
      'settings controls, invalid HEX, keyboard, tab state and direct rendering ${size.width}',
      (t) async {
        final key = GlobalKey();
        if (size.width == 320) {
          await c.saveAppearance(c.appearance.copyWith(textScale: 1.3));
        }
        await app(t, size: size, boundary: key);
        await settings(t);
        expect(find.byType(SettingsPage), findsOneWidget);
        await capture(t, key, 'settings-${size.width.round()}');

        final hex = find.byKey(const ValueKey('hex-Dialogkopf und -fuß'));
        await t.ensureVisible(hex);
        await t.enterText(hex, '#ZZZZZZ');
        await t.pumpAndSettle();
        expect(find.textContaining('Bitte einen gültigen HEX'), findsOneWidget);
        if (size.width == 320) {
          t.view.viewInsets = const FakeViewPadding(bottom: 260);
          await t.pumpAndSettle();
        }
        await t.ensureVisible(hex);
        await capture(t, key, 'settings-invalid-${size.width.round()}');
        await t.enterText(hex, '#DCE5D7');
        await t.pump(const Duration(milliseconds: 300));
        await t.runAsync(c.flushAppearance);
        await t.pumpAndSettle();
        expect(c.appearance.dialogColor, 0xffdce5d7);
        expect(c.appearance.headerOpacity, .18);
        t.view.resetViewInsets();
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        await click(t, find.byKey(const ValueKey('settings-tab-1')));
        await click(t, find.byKey(const ValueKey('shortcut-up-orga')));
        expect(c.appearance.shortcutOrder[3], 'orga');
        await click(t, find.byKey(const ValueKey('page-1')));
        await settings(t);
        expect(find.text('Karten-Shortcuts'), findsOneWidget);
        await click(t, find.byKey(const ValueKey('settings-tab-0')));
        t
            .widget<TextButton>(find.byKey(const ValueKey('settings-tab-0')))
            .focusNode!
            .requestFocus();
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.end);
        await t.pumpAndSettle();
        expect(find.text('Sichern & wiederherstellen'), findsOneWidget);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }
  testWidgets(
    'file selection, cancellation, failure, replacement, removal and preview keep real app in sync',
    (t) async {
      final original = FileSelectorPlatform.instance, picker = PicturePicker();
      FileSelectorPlatform.instance = picker;
      addTearDown(() => FileSelectorPlatform.instance = original);
      await app(t);
      await settings(t);

      Future<void> choose(XFile? file) async {
        picker.next = file;
        final button = find
            .widgetWithText(
              TextButton,
              c.appearance.desktopImage.isEmpty
                  ? 'Bild wählen'
                  : 'Anderes Bild wählen',
            )
            .first;
        await t.ensureVisible(button);
        await t.pumpAndSettle();
        await t.runAsync(() async {
          await t.tap(button);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await t.pumpAndSettle();
      }

      await choose(XFile('test/fixtures/appearance-pattern.png'));
      final saved = c.appearance.desktopImage;
      expect(saved, isNotEmpty);
      await choose(null);
      expect(c.appearance.desktopImage, saved);
      await choose(
        XFile.fromData(
          base64Decode('YWJj'),
          name: 'broken.png',
          mimeType: 'image/png',
        ),
      );
      expect(c.appearance.desktopImage, saved);
      await choose(XFile('test/fixtures/appearance-solid.png'));
      expect(c.appearance.desktopImage, isNot(saved));
      await click(t, find.widgetWithText(TextButton, 'Bild entfernen'));
      expect(c.appearance.desktopImage, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'every shortcut opens a fresh editor while existing drafts remain untouched',
    (t) async {
      final social = SchoolRecord.empty(
        SchoolKind.social,
        'alpha',
      ).patch({'body': 'Noch nicht gespeichert'});
      await repo.saveSchoolDraft(
        SchoolDraft(id: 'resume', record: social, updatedAtUtc: utcNow()),
      );
      await c.reload();
      await app(t);
      await t.tap(find.byKey(const ValueKey('page-1')));
      await t.pumpAndSettle();
      for (final symbol in ['social', 'work', 'goal', 'homework', 'orga']) {
        await click(t, find.byKey(ValueKey('shortcut-alpha-$symbol')));
        expect(find.byType(FlexModal), findsOneWidget);
        if (symbol == 'orga') {
          expect(find.byType(OrgaEditor), findsOneWidget);
        } else {
          final editor = t.widget<SchoolEditor>(find.byType(SchoolEditor));
          expect(editor.record.pupilId, 'alpha');
          expect(editor.record.kind.name, symbol);
          if (symbol == 'social') {
            expect(editor.draft, isNull);
            expect(editor.record.id, isNot(social.id));
            expect(find.text('Noch nicht gespeichert'), findsNothing);
          }
        }
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
      }
      expect(await repo.schoolRecords(), isEmpty);
      expect((await repo.schoolDrafts()).single.id, 'resume');
      expect(await repo.drafts(), isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'seven alpha controls reach actual widgets and shared bars update in all five editors',
    (t) async {
      await app(t);
      await t.tap(find.byKey(const ValueKey('page-1')));
      await t.pumpAndSettle();
      for (final value in [0.0, .5, 1.0]) {
        final changes = {
          for (final key in Appearance.surfaceOpacities) key: value,
        };
        await c.saveAppearance(
          c.appearance.change({
            ...changes,
            'dialogColor': 0xffeeeeee,
            'fieldColor': 0xffdddddd,
            'buttonColor': 0xffdddddd,
          }),
        );
        await t.pumpAndSettle();
        final theme = Theme.of(t.element(find.byType(PupilCard).first));
        expect(theme.cardTheme.color!.a, closeTo(value, .005));
        expect(
          theme.extension<FlexSurfaces>()!.palette!.workspace.a,
          closeTo(value, .005),
        );
        await click(t, find.byKey(const ValueKey('shortcut-alpha-social')));
        final header = t.widget<Container>(
          find.byKey(const ValueKey('modal-header')),
        );
        final footer = t.widget<Container>(
          find.byKey(const ValueKey('modal-footer')),
        );
        expect(header.color!.a, closeTo(value, .005));
        expect(footer.color!.a, closeTo(value, .005));
        expect(
          t
              .widget<ColoredBox>(find.byKey(const ValueKey('modal-surface')))
              .color
              .a,
          closeTo(value, .005),
        );
        final field = t.widget<DecoratedBox>(
          find.byKey(const ValueKey("tag-frame-[<'record-body'>]")),
        );
        expect(
          (field.decoration as BoxDecoration).color!.a,
          closeTo(value, .005),
        );
        final chips = t
            .widgetList<Container>(
              find.descendant(
                of: find.byType(SchoolEditor),
                matching: find.byType(Container),
              ),
            )
            .where(
              (w) =>
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color ==
                      Color(0xffdddddd).withValues(alpha: value),
            );
        expect(chips, isNotEmpty);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
      }
      for (final kind in ['social', 'work', 'goal', 'homework', 'orga']) {
        await click(t, find.byKey(ValueKey('shortcut-alpha-$kind')));
        await c.saveAppearance(
          c.appearance.change({
            'dialogColor': 0xff324d60,
            'headerOpacity': .3,
            'footerOpacity': .6,
          }),
        );
        await t.pumpAndSettle();
        expect(
          t.widget<Container>(find.byKey(const ValueKey('modal-header'))).color,
          const Color(0xff324d60).withValues(alpha: .3),
        );
        expect(
          t.widget<Container>(find.byKey(const ValueKey('modal-footer'))).color,
          const Color(0xff324d60).withValues(alpha: .6),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
      }
      await finish(t);
    },
  );
  testWidgets(
    'direct edited social and orga renderings at narrow and wide widths',
    (t) async {
      final key = GlobalKey();
      await c.saveAppearance(
        c.appearance.change({
          'desktopImage': solid,
          'mobileImage': pattern,
          'backgroundOpacity': 1.0,
          'dialogColor': 0xffdce5d7,
          'cardColor': 0xff324d60,
          'headerOpacity': .75,
          'footerOpacity': .75,
          'buttonColor': 0xfff2ede2,
          'fieldColor': 0xfff7f7f5,
          'fieldOpacity': .9,
        }),
      );
      await app(t, boundary: key);
      await t.runAsync(
        () => precacheImage(
          backgroundProvider(solid),
          t.element(find.byType(FlexBackground).first),
        ),
      );
      await t.tap(find.byKey(const ValueKey('page-1')));
      await t.pumpAndSettle();
      for (final size in [const Size(1100, 900), const Size(390, 844)]) {
        t.view.physicalSize = size;
        await t.binding.setSurfaceSize(size);
        await t.pumpAndSettle();
        await t.runAsync(
          () => precacheImage(
            backgroundProvider(size.width <= 700 ? pattern : solid),
            t.element(find.byType(FlexBackground).first),
          ),
        );
        await capture(t, key, 'settings-cards-${size.width.round()}');
        for (final symbol in ['social', 'orga']) {
          await click(t, find.byKey(ValueKey('shortcut-alpha-$symbol')));
          await capture(t, key, 'settings-$symbol-${size.width.round()}');
          expect(t.takeException(), isNull);
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
        }
      }
      await finish(t);
    },
  );
  testWidgets(
    'actual pixels change at minimum midpoint maximum for all seven surfaces',
    (t) async {
      final key = GlobalKey();
      await c.saveAppearance(
        c.appearance.patch({
          'desktopImage': solid,
          'backgroundOpacity': 1.0,
          for (final name in Appearance.surfaceColors) name: 0xffeeeeee,
          for (final name in Appearance.surfaceOpacities) name: 0.0,
        }),
      );
      await app(t, boundary: key);
      await t.runAsync(
        () => precacheImage(
          backgroundProvider(solid),
          t.element(find.byType(FlexBackground).first),
        ),
      );
      await t.tap(find.byKey(const ValueKey('page-1')));
      await t.pumpAndSettle();
      Future<int> pixel(Offset point) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await t.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final offset =
              (point.dy.floor() * image.width + point.dx.floor()) * 4;
          final value = bytes!.getUint32(offset);
          image.dispose();
          return value;
        }))!;
      }

      final targets = <String, Offset Function()>{
        'workspaceOpacity': () {
          final r = t.getRect(find.byKey(const ValueKey('page-pills')));
          return Offset(r.left + 10, r.top + 28);
        },
        'cardOpacity': () {
          final r = t.getRect(find.byType(PupilCard));
          return Offset(r.right - 12, r.bottom - 12);
        },
      };
      for (final name in Appearance.surfaceOpacities) {
        if (name == 'buttonOpacity') {
          await click(t, find.byKey(const ValueKey('shortcut-alpha-social')));
          await click(t, find.byKey(const ValueKey('tone-positive')));
        }
        final colors = <int>[];
        for (final alpha in [0.0, .5, 1.0]) {
          await c.saveAppearance(c.appearance.change({name: alpha}));
          await t.pumpAndSettle();
          Offset point;
          if (targets.containsKey(name)) {
            point = targets[name]!();
          } else if (name == 'buttonOpacity') {
            final r = t.getRect(
              find.byKey(const ValueKey('observation-option-Hilft anderen')),
            );
            point = Offset(r.left + 25, r.top + 5);
            // Text and star share one backing paint, including translucent states.
            expect(
              await pixel(point),
              await pixel(Offset(r.right - 25, r.top + 5)),
            );
          } else if (name == 'fieldOpacity') {
            final r = t.getRect(
              find.byKey(ValueKey("tag-frame-[<'record-body'>]")),
            );
            point = Offset(r.left + 20, r.top + 6);
          } else if (name == 'modalOpacity') {
            final r = t.getRect(find.byKey(const ValueKey('modal-header')));
            point = Offset(r.left + 6, r.bottom + 10);
          } else {
            final r = t.getRect(
              find.byKey(
                ValueKey(
                  name == 'headerOpacity' ? 'modal-header' : 'modal-footer',
                ),
              ),
            );
            point = Offset(r.left + 12, r.top + 8);
          }
          colors.add(await pixel(point));
        }
        expect(colors.toSet(), hasLength(3), reason: name);
        await c.saveAppearance(c.appearance.change({name: 0.0}));
        await t.pumpAndSettle();
      }
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await finish(t);
    },
  );
  testWidgets(
    'five image modes use distinct fit, centered bounds and tile repetition',
    (t) async {
      final key = GlobalKey();
      final base = c.appearance.patch({
        'desktopImage': pattern,
        'mobileImage': pattern,
        'backgroundOpacity': 1.0,
        'backgroundColor': 0xff123456,
      });
      final samples = <String, List<int>>{};
      for (final mode in ['cover', 'contain', 'fill', 'none', 'tile']) {
        await t.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: FlexBackground(
                    appearance: base.patch({
                      'desktopFit': mode,
                      'mobileFit': mode,
                    }),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.runAsync(
          () => precacheImage(
            backgroundProvider(pattern),
            t.element(find.byType(FlexBackground)),
          ),
        );
        await t.pumpAndSettle();
        final widget = t.widget<Image>(find.byType(Image));
        expect(widget.fit, backgroundFit(mode));
        expect(
          widget.repeat,
          mode == 'tile' ? ImageRepeat.repeat : ImageRepeat.noRepeat,
        );
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        samples[mode] = (await t.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final values = [
            for (final p in [
              const Offset(4, 4),
              const Offset(4, 40),
              const Offset(60, 60),
              const Offset(4, 100),
            ])
              bytes!.getUint32((p.dy.toInt() * image.width + p.dx.toInt()) * 4),
          ];
          image.dispose();
          return values;
        }))!;
      }
      expect(samples['contain']!.first, 0x123456ff);
      expect(samples['none']!.first, 0x123456ff);
      expect(samples['cover']!.first, isNot(0x123456ff));
      expect(samples['fill']!.first, isNot(0x123456ff));
      expect(samples['tile'], isNot(samples['none']));
      expect(samples['contain'], isNot(samples['fill']));
      await finish(t);
    },
  );
  testWidgets(
    'settings remain scrollable with double system text and keyboard',
    (t) async {
      final key = GlobalKey();
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await app(t, size: const Size(320, 740), boundary: key);
      await settings(t);
      await capture(t, key, 'settings-system-text-200');

      final field = find.byKey(const ValueKey('hex-Dialogkopf und -fuß'));
      await t.ensureVisible(field);
      await t.enterText(field, '#x');
      t.view.viewInsets = const FakeViewPadding(bottom: 260);
      await t.pumpAndSettle();
      await t.ensureVisible(field);
      await capture(t, key, 'settings-system-text-200-keyboard');
      expect(find.textContaining('Bitte einen gültigen HEX'), findsOneWidget);
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  testWidgets(
    'failed pending settings write stays visible after leaving settings',
    (t) async {
      await app(t);
      await settings(t);
      final before = c.appearance.cardColor;
      repo.fail = true;
      c.previewAppearance({'cardColor': 0xffabcdef});
      await click(t, find.byKey(const ValueKey('page-1')));
      await t.runAsync(c.flushAppearance);
      await t.pumpAndSettle();
      expect(c.appearance.cardColor, before);
      expect(
        find.text('Nicht gespeichert. Bitte erneut versuchen.'),
        findsOneWidget,
      );
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(t.takeException(), isNull);
      repo.fail = false;
      await finish(t);
    },
  );
}
