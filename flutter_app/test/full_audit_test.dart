import 'package:flex_notizbuch/ui/compact_switch.dart';
import 'package:flex_notizbuch/ui/observation_tone_colors.dart';
import 'dart:async';
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
import 'package:flex_notizbuch/ui/dialog_workflows.dart';
import 'package:flex_notizbuch/ui/orga_editor.dart';
import 'package:flex_notizbuch/domain/observation_catalog.dart';
import 'package:flex_notizbuch/ui/settings.dart';
import 'package:flex_notizbuch/ui/option_bar.dart';
import 'package:flex_notizbuch/ui/pupil_history.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteNotebook repo;
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
    if (finder.evaluate().isEmpty &&
        find.byKey(const PageStorageKey('settings')).evaluate().isNotEmpty) {
      await t.scrollUntilVisible(
        finder,
        -400,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('settings')),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 80,
      );
    }
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

  test(
    'legacy records/settings remain readable and new neutral-only records validate',
    () {
      final original = SchoolRecord.empty(SchoolKind.social, 'a').patch({
        'positive': ['Hilft anderen'],
      });
      final old = original.toJson()..remove('neutral');
      final restored = SchoolRecord.fromJson(old);
      restored.validate();
      expect(restored.positive, original.positive);
      expect(restored.neutral, isEmpty);
      final oldAppearance = const Appearance().toJson()
        ..remove('defaultObservationTone');
      expect(
        Appearance.fromJson(oldAppearance).defaultObservationTone,
        'neutral',
      );
      expect(
        () => Appearance.fromJson({
          ...oldAppearance,
          'defaultObservationTone': 'invalid',
        }),
        throwsA(isA<DomainError>()),
      );
      final neutral = SchoolRecord.empty(SchoolKind.work, 'a').patch({
        'neutral': ['Arbeitet an der Aufgabe'],
      });
      neutral.validate();
      expect(neutral.searchText, contains('Arbeitet an der Aufgabe'));
      expect(
        readableRecord(neutral.toJson()),
        contains('• Arbeitet an der Aufgabe'),
      );
      expect(
        () => neutral.patch({
          'neutral': ['doppelt', 'doppelt'],
        }).validate(),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => neutral.patch({
          'neutral': [' '],
        }).validate(),
        throwsA(isA<DomainError>()),
      );
    },
  );

  test(
    'neutral records, drafts, favorites and default survive database restart and complete restore',
    () async {
      final dir = Directory.systemTemp.createTempSync('flex-neutral-audit-');
      SqliteNotebook connect() => SqliteNotebook(
        NotebookDatabase(
          NativeDatabase(File('${dir.path}/data.sqlite')),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      var disk = connect();
      final restored = SqliteNotebook(
        NotebookDatabase(
          NativeDatabase.memory(),
          File('assets/schema.sql').readAsStringSync(),
        ),
      );
      await disk.initialize();
      await restored.initialize();
      try {
        await disk.savePupil(const Pupil(id: 'p', name: 'Test'));
        final record = SchoolRecord.empty(SchoolKind.social, 'p').patch({
          'neutral': ['Eigene sachliche Beobachtung'],
          'body': 'Freier Text',
        });
        await disk.saveSchoolRecord(record);
        await disk.saveSchoolDraft(
          SchoolDraft(
            id: 'draft-neutral',
            record: SchoolRecord.empty(SchoolKind.work, 'p').patch({
              'neutral': ['Nutzt Arbeitsmaterial'],
            }),
            updatedAtUtc: utcNow(),
          ),
        );
        await disk.saveObservationOptions('social-neutral', [
          'Eigene sachliche Beobachtung',
        ]);
        await disk.toggleObservationFavorite(
          'social-neutral',
          'Eigene sachliche Beobachtung',
        );
        await disk.saveAppearance(
          const Appearance().patch({'defaultObservationTone': 'negative'}),
        );
        await disk.close();
        disk = connect();
        await disk.initialize();
        expect((await disk.schoolRecords()).single.neutral, [
          'Eigene sachliche Beobachtung',
        ]);
        await restored.restoreBackup(await disk.exportBackup());
        expect(
          (await restored.schoolRecords()).single.toJson(),
          (await disk.schoolRecords()).single.toJson(),
        );
        expect(
          (await restored.schoolDrafts()).single.toJson(),
          (await disk.schoolDrafts()).single.toJson(),
        );
        expect(
          (await restored.observationCatalog('social-neutral')).favorites,
          ['Eigene sachliche Beobachtung'],
        );
        expect(
          (await restored.appearance()).defaultObservationTone,
          'negative',
        );
      } finally {
        await disk.close();
        await restored.close();
        dir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'group observations persist neutral selections for each recipient independently',
    () async {
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: 'group-neutral',
          type: 'bulk',
          ownerId: 'social',
          updatedAtUtc: utcNow(),
          data: {
            'kind': 'social',
            'recipients': ['a', 'b'],
            'observedOn': '2026-11-03',
            'individual': {
              'a': {
                'neutral': ['Stellt eine Frage'],
                'body': 'A',
              },
              'b': {
                'neutral': ['Beobachtet die Gruppe'],
                'body': 'B',
              },
            },
          },
        ),
      );
      await repo.saveBulkDialog(draft);
      final records = await repo.schoolRecords();
      expect(records, hasLength(2));
      expect(records.firstWhere((r) => r.pupilId == 'a').neutral, [
        'Stellt eine Frage',
      ]);
      expect(records.firstWhere((r) => r.pupilId == 'b').neutral, [
        'Beobachtet die Gruppe',
      ]);
      expect(await repo.dialogDrafts(), isEmpty);
    },
  );

  testWidgets(
    'old catalog draft can select and save neutral without losing customized options',
    (t) async {
      await repo.saveObservationOptions('social-neutral', [
        'Eigener neutraler Tag',
      ]);
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: 'old-catalog',
          type: 'catalog',
          ownerId: 'social',
          updatedAtUtc: utcNow(),
          data: {
            'kind': 'social',
            'tone': 'positive',
            'positive': ['Alt positiv'],
            'negative': ['Alt negativ'],
          },
        ),
      );
      await app(t);
      unawaited(
        showCatalog(
          t.element(find.byType(Scaffold)),
          c,
          'social',
          draft: draft,
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.text('• Neutral'));
      expect(find.text('Eigener neutraler Tag'), findsOneWidget);
      await tap(t, find.text('Änderungen speichern'));
      expect((await repo.observationCatalog('social-neutral')).options, [
        'Eigener neutraler Tag',
      ]);
      expect((await repo.observationCatalog('social-positive')).options, [
        'Alt positiv',
      ]);
      expect(await repo.dialogDrafts(), isEmpty);
      await finish(t);
    },
  );

  for (final kind in [SchoolKind.social, SchoolKind.work]) {
    testWidgets(
      '${kind.name}: neutral default, three-way swipe, bounded ends and mixed tags survive save',
      (t) async {
        await app(t);
        await open(
          t,
          SchoolEditor(controller: c, record: SchoolRecord.empty(kind, 'a')),
        );
        final bar = find.byKey(const ValueKey('tone-pill'));
        String tone() => t.widget<OptionBar>(bar).value;
        expect(tone(), 'neutral');
        expect(t.getSize(bar).height, inInclusiveRange(38, 40));
        final neutral = observationDefaults['${kind.name}-neutral']!.first;
        await tap(t, find.byKey(ValueKey('observation-$neutral')));
        for (final entry in [
          ('positive', 170.0),
          ('positive', 170.0),
          ('neutral', -170.0),
          ('negative', -170.0),
          ('negative', -170.0),
        ]) {
          await t.ensureVisible(bar);
          await t.pumpAndSettle();
          await t.drag(bar, Offset(entry.$2, 0));
          await t.pumpAndSettle();
          expect(tone(), entry.$1);
        }
        final negative = observationDefaults['${kind.name}-negative']!.first;
        await tap(t, find.byKey(ValueKey('observation-$negative')));
        await tap(t, find.byKey(const ValueKey('tone-positive')));
        final positive = observationDefaults['${kind.name}-positive']!.first;
        await tap(t, find.byKey(ValueKey('observation-$positive')));
        // A mixed selection keeps each tag's own tone, even after tab changes.
        for (final active in ['negative', 'neutral', 'positive']) {
          await tap(t, find.byKey(ValueKey('tone-$active')));
          for (final tag in [
            ('positive', positive),
            ('neutral', neutral),
            ('negative', negative),
          ]) {
            final chip = t.widget<InputChip>(
              find.byKey(ValueKey('selected-${tag.$1}-${tag.$2}')),
            );
            expect(chip.color?.resolve({}), observationToneColors[tag.$1]);
            expect((chip.label as Text).style?.color, Colors.white);
            expect(chip.deleteIconColor, Colors.white);
          }
        }
        final body = find.byKey(const ValueKey('record-body'));
        await t.ensureVisible(body);
        await t.enterText(body, 'Sachlicher Freitext');
        final state = t.state<EditableTextState>(
          find.descendant(of: body, matching: find.byType(EditableText)),
        );
        t.testTextInput.log.clear();
        t.view.viewInsets = const FakeViewPadding(bottom: 400);
        await t.pumpAndSettle();
        expect(
          t.state<EditableTextState>(
            find.descendant(of: body, matching: find.byType(EditableText)),
          ),
          same(state),
        );
        expect(state.widget.focusNode.hasFocus, isTrue);
        expect(
          t.testTextInput.log.where((e) => e.method == 'TextInput.hide'),
          isEmpty,
        );
        await tap(t, find.byKey(const ValueKey('save-school-record')));
        final saved = (await repo.schoolRecords()).single;
        expect(saved.neutral, [neutral]);
        expect(saved.positive, [positive]);
        expect(saved.negative, [negative]);
        expect(saved.body, 'Sachlicher Freitext');
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  testWidgets(
    'custom catalogs show every available option without a more button',
    (t) async {
      await repo.saveObservationOptions(
        'social-neutral',
        List.generate(12, (i) => 'Sachliche Auswahl ${i + 1}'),
      );
      await app(t);
      await open(
        t,
        SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'a'),
        ),
      );
      expect(
        find.byKey(const ValueKey('observation-Sachliche Auswahl 12')),
        findsOneWidget,
      );
      await tap(
        t,
        find.byKey(const ValueKey('observation-Sachliche Auswahl 12')),
      );
      await tap(t, find.byKey(const ValueKey('save-school-record')));
      expect((await repo.schoolRecords()).single.neutral, [
        'Sachliche Auswahl 12',
      ]);
      await finish(t);
    },
  );

  testWidgets('default choice persists and display reset preserves it', (
    t,
  ) async {
    await app(t);
    await tap(t, find.byTooltip('Weitere Bereiche'));
    await tap(t, find.text('Einstellungen'));
    await tap(t, find.byKey(const ValueKey('settings-tab-1')));
    expect(t.widget<OptionBar>(find.byType(OptionBar)).value, 'neutral');
    await tap(t, find.byKey(const ValueKey('default-tone-negative')));
    await t.runAsync(c.flushAppearance);
    expect((await repo.appearance()).defaultObservationTone, 'negative');
    await tap(t, find.byKey(const ValueKey('settings-tab-0')));
    await tap(t, find.text('Darstellung zurücksetzen'));
    await tap(t, find.widgetWithText(FilledButton, 'Zurücksetzen'));
    expect(c.appearance.defaultObservationTone, 'negative');
    await open(
      t,
      SchoolEditor(
        controller: c,
        record: SchoolRecord.empty(SchoolKind.social, 'a'),
      ),
    );
    expect(
      t.widget<OptionBar>(find.byKey(const ValueKey('tone-pill'))).value,
      'negative',
    );
    await tap(t, find.byKey(const ValueKey('cancel-editor')));
    await finish(t);
  });

  for (final owner in [null, 'a']) {
    testWidgets(
      'Orga $owner: visible kind buttons adapt fields and preserve text across types',
      (t) async {
        await app(t);
        await open(
          t,
          OrgaEditor(
            controller: c,
            entry: OrgaEntry.empty(pupilId: owner),
          ),
        );
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.textContaining('Beobachtet am'), findsNothing);
        final body = find.byKey(const ValueKey('orga-note'));
        await t.enterText(body, 'Planung mit Notizen');
        for (final kind in ['note', 'task', 'appointment', 'note']) {
          await tap(t, find.byKey(ValueKey('orga-kind-$kind')));
          expect(find.text('Planung mit Notizen'), findsOneWidget);
          expect(
            find.text('Aufgabe erledigt'),
            kind == 'task' ? findsOneWidget : findsNothing,
          );
          expect(
            find.textContaining('Fällig am'),
            kind == 'task' ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('orga-appointment-date')),
            kind == 'appointment' ? findsOneWidget : findsNothing,
          );
        }
        await tap(t, find.text('Speichern'));
        final entry = (await repo.entries()).single;
        expect(entry.isTask, isFalse);
        expect(entry.appointmentDate, isNull);
        expect(entry.dueDate, isNull);
        expect(entry.body, 'Planung mit Notizen');
        expect(entry.pupilId, owner);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  testWidgets(
    'Orga validation remains visible above the keyboard and can recover without losing the form',
    (t) async {
      await app(t, size: const Size(320, 740));
      await open(
        t,
        OrgaEditor(
          controller: c,
          entry: OrgaEntry.empty(
            pupilId: 'a',
          ).copyWith(appointmentDate: '2030-04-04'),
        ),
      );
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pumpAndSettle();
      await tap(t, find.text('Speichern'));
      final error = find.text('Bitte den Termin benennen.');
      expect(error, findsOneWidget);
      expect(t.getRect(error).top, greaterThanOrEqualTo(0));
      expect(t.getRect(error).bottom, lessThanOrEqualTo(440));
      expect(await repo.entries(), isEmpty);
      final field = find.byKey(const ValueKey('orga-note'));
      await t.ensureVisible(field);
      await t.enterText(field, 'Nachgereichter Termin');
      await tap(t, find.text('Speichern'));
      expect((await repo.entries()).single.appointmentDate, '2030-04-04');
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  testWidgets(
    'switching reminder off removes scheduled reminder and survives reopening',
    (t) async {
      await c.saveEntry(
        OrgaEntry.empty(pupilId: 'a').copyWith(
          title: 'Unterlagen',
          body: 'Unterlagen',
          reminderAtUtc: '2030-04-04T10:00:00Z',
          reminderState: ReminderState.planned,
        ),
      );
      await app(t);
      await open(
        t,
        OrgaEditor(controller: c, entry: (await repo.entries()).single),
      );
      await tap(t, find.widgetWithText(CompactSwitchListTile, 'Erinnern'));
      expect(find.textContaining('Erinnern am'), findsNothing);
      await tap(t, find.text('Speichern'));
      final saved = (await repo.entries()).single;
      expect(saved.reminderAtUtc, isNull);
      expect(saved.reminderState, ReminderState.none);
      await open(t, OrgaEditor(controller: c, entry: saved));
      expect(
        t
            .widget<CompactSwitchListTile>(
              find.widgetWithText(CompactSwitchListTile, 'Erinnern'),
            )
            .value,
        isFalse,
      );
      await tap(t, find.byKey(const ValueKey('cancel-editor')));
      await finish(t);
    },
  );

  testWidgets(
    'pupil search is icon-only directly beside add, keeps filter after collapse',
    (t) async {
      await app(t);
      await t.tap(find.byKey(const ValueKey('bottom-1')));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('page-1')));
      final search = find.byKey(const ValueKey('toggle-pupil-search'));
      final add = find.byTooltip('Neuer Schüler');
      expect(find.text('Schüler suchen'), findsNothing);
      expect((t.getCenter(search).dy - t.getCenter(add).dy).abs(), lessThan(1));
      expect(
        (t.getRect(add).left - t.getRect(search).right).abs(),
        lessThanOrEqualTo(8),
      );
      await tap(t, search);
      await t.enterText(find.byKey(const ValueKey('search-false')), 'Anna');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.text('Ben Beispiel'), findsNothing);
      expect(find.text('Suche: Anna'), findsNothing);
      expect(find.byTooltip('Schüler suchen: Anna'), findsOneWidget);
      await tap(t, search);
      await tap(t, find.byTooltip('Suchtext leeren'));
      expect(find.text('Ben Beispiel'), findsOneWidget);
      await finish(t);
    },
  );

  for (final view in [
    (320.0, 740.0, 1.0, 'dark', 1.0),
    (390.0, 844.0, 1.0, 'light', 1.0),
    (1200.0, 900.0, 1.0, 'dark', 1.0),
    (320.0, 740.0, 2.0, 'light', 1.2),
  ]) {
    testWidgets(
      'audit render and reachable controls ${view.$1}/${view.$3}/${view.$4}/${view.$5}',
      (t) async {
        await c.saveAppearance(
          c.appearance.patch({'mode': view.$4, 'uiScale': view.$5}),
        );
        final boundary = GlobalKey();
        final suffix = '${view.$1.toInt()}-${view.$3.toInt()}-${view.$4}';
        await app(
          t,
          size: Size(view.$1, view.$2),
          font: view.$3,
          boundary: boundary,
        );
        await capture(t, boundary, 'overview-$suffix');
        await t.tap(find.byKey(const ValueKey('bottom-1')));
        await t.pumpAndSettle();
        await tap(t, find.byKey(const ValueKey('page-1')));
        await capture(t, boundary, 'pupils-$suffix');
        for (final kind in ['note', 'task', 'appointment']) {
          await open(
            t,
            OrgaEditor(
              controller: c,
              entry: OrgaEntry.empty(pupilId: 'a'),
            ),
          );
          await tap(t, find.byKey(ValueKey('orga-kind-$kind')));
          await capture(t, boundary, 'orga-$kind-$suffix');
          final body = find.byKey(const ValueKey('orga-note'));
          await t.ensureVisible(body);
          await t.enterText(body, 'Audit $kind');
          t.view.viewInsets = const FakeViewPadding(bottom: 280);
          await t.pumpAndSettle();
          await t.ensureVisible(body);
          await capture(t, boundary, 'orga-$kind-keyboard-$suffix');
          await tap(t, find.byKey(const ValueKey('cancel-editor')));
          t.view.resetViewInsets();
          await t.pumpAndSettle();
        }
        await open(
          t,
          SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(SchoolKind.social, 'a'),
          ),
        );
        final dialogContext = t.element(find.byType(SchoolEditor));
        final theme = Theme.of(dialogContext);
        final background = theme
            .extension<FlexSurfaces>()!
            .palette!
            .modalPerceived
            .computeLuminance();
        expect(IconTheme.of(dialogContext).color, theme.colorScheme.onSurface);
        final ink = theme.colorScheme.onSurfaceVariant.computeLuminance();
        final contrast = ink > background
            ? (ink + .05) / (background + .05)
            : (background + .05) / (ink + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        await capture(t, boundary, 'neutral-$suffix');
        await tap(t, find.byKey(const ValueKey('cancel-editor')));
        await tap(t, find.byTooltip('Weitere Bereiche'));
        await tap(t, find.text('Einstellungen'));
        for (var tab = 0; tab < 3; tab++) {
          await tap(
            t,
            find.byKey(
              ValueKey(tab == 2 ? 'context-4-3' : 'settings-tab-$tab'),
            ),
          );
          await capture(t, boundary, 'settings-$tab-$suffix');
          if (tab == 0) {
            for (final name in [
              'uiScale',
              'textScale',
              'cardRadius',
              'buttonRadius',
              'fieldRadius',
              'modalRadius',
              'footerOpacity',
            ]) {
              final control = find.byKey(ValueKey('setting-$name'));
              expect(control, findsOneWidget);
              await t.ensureVisible(control);
              await t.pumpAndSettle();
            }
            expect(
              find.textContaining('App-Skalierung verändert'),
              findsNothing,
            );
          } else if (tab == 2) {
            for (final label in [
              'Exportieren',
              'Sicherung importieren',
              'HTML-Sicherung vormerken',
              'Speicherpflege öffnen',
            ]) {
              expect(find.text(label), findsOneWidget);
              await t.ensureVisible(find.text(label));
              await t.pumpAndSettle();
            }
            expect(find.byType(ExpansionTile), findsNothing);
          }
        }
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }
}
