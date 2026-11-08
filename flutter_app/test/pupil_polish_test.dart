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
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/ui/school_workspace.dart';
import 'material_workspace_test.dart' show material;
import 'package:flex_notizbuch/ui/app.dart';
import 'package:flex_notizbuch/ui/entry_navigation.dart';
import 'package:flex_notizbuch/ui/flex_icons.dart';
import 'package:flex_notizbuch/ui/pupil_workspace.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';

class DeleteStore extends SqliteNotebook {
  DeleteStore(super.db);
  bool fail = false;
  Completer<void>? hold;
  int deletes = 0;
  @override
  Future<void> discardSchoolDraft(String id, {int? expectedRevision}) async {
    deletes++;
    await hold?.future;
    if (fail) throw const DomainError('Löschen fehlgeschlagen – Test');
    await super.discardSchoolDraft(id, expectedRevision: expectedRevision);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DeleteStore repo;
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
    repo = DeleteStore(
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
    for (final kind in [SchoolKind.social, SchoolKind.work]) {
      await repo.saveSchoolRecord(
        SchoolRecord.empty(kind, 'a').patch({
          'body': kind == SchoolKind.social
              ? 'Hilft bei der Gruppenarbeit'
              : 'Liest konzentriert',
          'positive': [
            kind == SchoolKind.social
                ? 'Hält Gesprächsregeln ein'
                : 'Beginnt selbstständig',
          ],
        }),
      );
    }
    await c.saveEntry(
      OrgaEntry.empty(
        pupilId: 'a',
      ).copyWith(title: 'Material mitbringen', isTask: true),
    );
    final social = (await repo.schoolRecords()).firstWhere(
      (r) => r.kind == SchoolKind.social,
    );
    await repo.saveSchoolDraft(
      SchoolDraft(
        id: 'social',
        record: social.patch({'body': 'Entwurf sozial'}),
        updatedAtUtc: utcNow(),
      ),
    );
    await repo.saveDraft(
      EditDraft(
        id: 'orga',
        entry: OrgaEntry.empty(pupilId: 'a').copyWith(title: 'Entwurf Orga'),
        updatedAtUtc: utcNow(),
      ),
    );
    await repo.saveDialogDraft(
      DialogDraft(
        id: 'bulk',
        type: 'bulk',
        ownerId: 'group',
        updatedAtUtc: utcNow(),
        data: {
          'kind': 'work',
          'recipients': ['a'],
          'body': 'Entwurf Gruppe',
          'observedOn': dateOnly(DateTime.now()),
          'observedTime': '',
          'individual': {},
          'needsCompletion': false,
        },
      ),
    );
    await c.reload();
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });
  Future<void> app(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double font = 1,
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    t.platformDispatcher.textScaleFactorTestValue = font;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await c.saveAppearance(c.appearance.patch({'uiScale': scale}));
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

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f.last);
    await t.pumpAndSettle();
    await t.tap(f.last);
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) =>
      tap(t, find.byTooltip('Schließen und Eingaben sichern').last);
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  Future<void> hub(WidgetTester t) async {
    await tap(t, find.byKey(const ValueKey('page-1')));
    await tap(t, find.byKey(const ValueKey('pupil-open-a')));
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    final dir = Platform.environment['FLEX_RENDER_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final pic =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await pic.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      pic.dispose();
    });
  }

  for (final view in [
    (320.0, 1.0, 1.0),
    (390.0, 1.0, 1.0),
    (1200.0, 1.0, 1.0),
    (320.0, 2.0, 1.0),
    (320.0, 1.0, 1.2),
  ]) {
    testWidgets(
      'pupil cards, workspace and compact tags ${view.$1}/${view.$2}/${view.$3}',
      (t) async {
        final key = GlobalKey(),
            suffix =
                '${view.$1.toInt()}-${view.$2.toInt()}-${(view.$3 * 100).round()}';
        await app(
          t,
          size: Size(view.$1, 1000),
          font: view.$2,
          scale: view.$3,
          boundary: key,
        );
        await tap(t, find.byKey(const ValueKey('page-1')));
        for (final symbol in FlexSymbol.values) {
          final target = find.byKey(ValueKey('shortcut-a-${symbol.name}'));
          final icon = find.descendant(
            of: target,
            matching: find.byType(FlexIcon),
          );
          expect(t.getCenter(icon).dx, closeTo(t.getCenter(target).dx, .1));
          expect(t.widget<FlexIcon>(icon).size, 32);
          final labelFinder = find
              .descendant(of: target, matching: find.byType(Text))
              .last;
          final label = t.widget<Text>(labelFinder);
          expect(label.textAlign, TextAlign.center);
          expect(
            t.getCenter(labelFinder).dx,
            closeTo(t.getCenter(icon).dx, .1),
          );
        }
        final center = t
            .getCenter(find.byKey(const ValueKey('pupil-open-a')))
            .dx;
        final order = c.appearance.shortcutOrder;
        for (final row in [order.take(3), order.skip(3)]) {
          final centers = row
              .map(
                (name) =>
                    t.getCenter(find.byKey(ValueKey('shortcut-a-$name'))).dx,
              )
              .toList();
          expect((centers.first + centers.last) / 2, closeTo(center, .1));
        }
        if (view.$2 == 1) {
          expect(
            t.getSize(find.byKey(const ValueKey('pupil-open-a'))).height,
            lessThanOrEqualTo(48),
          );
        }
        await capture(t, key, 'cards-$suffix');
        await tap(t, find.byKey(const ValueKey('pupil-open-a')));
        expect(find.byType(PupilWorkspaceDialog), findsOneWidget);
        expect(find.text('Schüler bearbeiten'), findsNothing);
        expect(
          find.byKey(const ValueKey('pupil-search-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pupil-entry-filter')),
          findsOneWidget,
        );
        if (view.$1 <= 320 || view.$2 > 1) {
          final name = find.byKey(const ValueKey('pupil-workspace-title'));
          expect(t.getSize(name).width, greaterThan(175));
          expect(
            t.getRect(find.byTooltip('Schüleraktionen')).top,
            greaterThanOrEqualTo(t.getRect(name).bottom),
          );
        }
        await capture(t, key, 'pupil-workspace-$suffix');
        await tap(t, find.byTooltip('Schüleraktionen'));
        expect(find.text('Schüler bearbeiten'), findsOneWidget);
        expect(find.text('Gesprächsvorbereitung'), findsOneWidget);
        await t.tapAt(const Offset(1, 1));
        await t.pumpAndSettle();
        await close(t);
        for (final kind in [SchoolKind.social, SchoolKind.work]) {
          await tap(t, find.byKey(ValueKey('shortcut-a-${kind.name}')));
          await tap(t, find.byKey(const ValueKey('tone-positive')));
          final option = find.byKey(
            ValueKey(
              'observation-${kind == SchoolKind.social ? 'Hilft anderen' : 'Beginnt selbstständig'}',
            ),
          );
          await t.ensureVisible(option);
          await t.pumpAndSettle();
          final button = t.widget<TextButton>(option);
          expect(button.style!.textStyle!.resolve({})!.fontSize, 13);
          await capture(t, key, '${kind.name}-tags-$suffix');
          await tap(t, option);
          await close(t);
          expect(c.schoolDrafts.any((d) => d.record.kind == kind), isTrue);
        }
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  for (final type in ['school', 'orga', 'bulk']) {
    testWidgets('header draft list deletes $type only after confirmation', (
      t,
    ) async {
      await app(t);
      unawaited(
        showEntryDrafts(
          t.element(find.byType(Scaffold)),
          c,
          pupilId: 'a',
          kind: type == 'school'
              ? SchoolKind.social
              : type == 'bulk'
              ? SchoolKind.work
              : null,
          exclude: 'active',
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.byTooltip('Entwurf löschen'));
      await tap(t, find.text('Abbrechen'));
      expect(c.draftCount, 3);
      await tap(t, find.byTooltip('Entwurf löschen'));
      await tap(t, find.text('Löschen'));
      expect(c.draftCount, 2);
      expect(find.text('Keine weiteren gesicherten Entwürfe.'), findsOneWidget);
      expect(c.records.length, 2);
      expect(
        c.records.any((r) => r.body == 'Hilft bei der Gruppenarbeit'),
        isTrue,
      );
      expect(c.entries.single.title, 'Material mitbringen');
      await finish(t);
    });
  }
  testWidgets('failed delete is retryable and double taps issue one write', (
    t,
  ) async {
    await app(t);
    unawaited(
      showEntryDrafts(
        t.element(find.byType(Scaffold)),
        c,
        pupilId: 'a',
        kind: SchoolKind.social,
        exclude: 'active',
      ),
    );
    await t.pumpAndSettle();
    repo.fail = true;
    await tap(t, find.byTooltip('Entwurf löschen'));
    await tap(t, find.text('Löschen'));
    expect(find.text('Löschen fehlgeschlagen – Test'), findsOneWidget);
    expect(c.draftCount, 3);
    repo.fail = false;
    repo.hold = Completer<void>();
    await tap(t, find.byTooltip('Entwurf löschen'));
    await t.tap(find.text('Löschen'));
    await t.pumpAndSettle();
    final calls = repo.deletes;
    await t.tap(find.byTooltip('Entwurf löschen'));
    await t.pump();
    expect(repo.deletes, calls);
    repo.hold!.complete();
    await t.pumpAndSettle();
    expect(c.draftCount, 2);
    await finish(t);
  });
  testWidgets(
    'pupil header drafts show all areas and keep other pupils separate',
    (t) async {
      await repo.saveSchoolDraft(
        SchoolDraft(
          id: 'other',
          record: SchoolRecord.empty(
            SchoolKind.goal,
            'b',
          ).patch({'title': 'Ben privat'}),
          updatedAtUtc: utcNow(),
        ),
      );
      await c.reload();
      await app(t);
      await hub(t);
      await tap(t, find.byTooltip('Entwürfe (3)'));
      expect(find.textContaining('Entwurf sozial'), findsOneWidget);
      expect(find.text('Entwurf Orga'), findsOneWidget);
      expect(find.text('Entwurf Gruppe'), findsOneWidget);
      expect(find.textContaining('Ben privat'), findsNothing);
      await tap(
        t,
        find.descendant(
          of: find.byKey(const ValueKey('draft-row-dialog-bulk')),
          matching: find.byTooltip('Entwurf löschen'),
        ),
      );
      await tap(t, find.text('Löschen'));
      expect(c.dialogDrafts, isEmpty);
      expect(c.schoolDrafts.any((d) => d.id == 'other'), isTrue);
      await finish(t);
    },
  );
  testWidgets(
    'pupil summaries preserve task files and search when updating a detail',
    (t) async {
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'a').patch({
          'subject': 'Mathematik',
          'tasks': [const HomeworkTask(id: 'task', text: 'Rechnen').toJson()],
        }),
      );
      final file = await repo.saveClassroomDocument(
        material(
          'Arbeitsblatt',
          fields: {
            'pupilIds': ['a'],
            'links': [DocumentLink('school', r.id, taskId: 'task').toJson()],
          },
        ),
      );
      await c.reload();
      await app(t);
      await hub(t);
      expect(find.byType(SchoolRecordCard), findsNothing);
      final navTop = t
          .getTopLeft(find.byKey(const ValueKey('pupil-area-all')))
          .dy;
      expect(
        t.getTopLeft(find.byKey(const ValueKey('pupil-area-orga'))).dy,
        navTop,
      );
      expect(
        find.byKey(ValueKey('pupil-preview-file-${file.id}')),
        findsOneWidget,
      );
      await tap(t, find.byKey(const ValueKey('pupil-search-button')));
      await t.enterText(
        find.byKey(const ValueKey('pupil-entry-search')),
        'Mathematik',
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(ValueKey('pupil-open-entry-${r.id}')));
      expect(find.byType(SchoolRecordCard), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('status-task-complete')));
      expect(
        c.records.singleWhere((v) => v.id == r.id).taskState(r.tasks.single),
        TaskState.complete,
      );
      await close(t);
      expect(find.byType(SchoolRecordCard), findsNothing);
      expect(find.text('1 / 1 erledigt'), findsOneWidget);
      expect(find.textContaining('Hilft bei der Gruppenarbeit'), findsNothing);
      expect(
        find.byKey(ValueKey('pupil-preview-file-${file.id}')),
        findsOneWidget,
      );
      expect(
        (await repo.classroomDocuments()).single.rows('links').single['taskId'],
        'task',
      );
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  testWidgets(
    'pupil workspace search and open filter cover school and Orga records',
    (t) async {
      await app(t);
      await hub(t);
      await tap(t, find.byKey(const ValueKey('pupil-search-button')));
      await t.enterText(
        find.byKey(const ValueKey('pupil-entry-search')),
        'Gruppenarbeit',
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('Hilft bei der Gruppenarbeit'),
        findsOneWidget,
      );
      expect(find.text('Material mitbringen'), findsNothing);
      await t.enterText(find.byKey(const ValueKey('pupil-entry-search')), '');
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('pupil-filter-open')));
      expect(find.textContaining('Hilft bei der Gruppenarbeit'), findsNothing);
      expect(find.text('Material mitbringen'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('pupil-area-work')));
      expect(find.text('Keine passenden Einträge.'), findsOneWidget);
      await finish(t);
    },
  );
}
