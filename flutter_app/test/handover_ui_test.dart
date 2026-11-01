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
import 'package:flex_notizbuch/ui/flex_icons.dart';
import 'package:flex_notizbuch/ui/flex_modal.dart';
import 'package:flex_notizbuch/ui/pupil_card.dart';
import 'package:flex_notizbuch/ui/surfaces.dart';
import 'package:flex_notizbuch/ui/school_editor.dart';

class ControlledNotebook extends SqliteNotebook {
  ControlledNotebook(super.db);
  bool failNext = false;
  Completer<void>? hold;
  int attempts = 0;
  @override
  Future<SchoolRecord> saveSchoolRecord(
    SchoolRecord record, {
    String? draftId,
    int? draftRevision,
  }) async {
    attempts++;
    if (failNext) {
      failNext = false;
      throw const DomainError('Synthetischer Speicherfehler');
    }
    await hold?.future;
    return super.saveSchoolRecord(
      record,
      draftId: draftId,
      draftRevision: draftRevision,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final item in const {
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
      final loader = FontLoader(item.key);
      for (final asset in item.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });
  late ControlledNotebook repo;
  late NotebookController c;
  setUp(() async {
    repo = ControlledNotebook(
      NotebookDatabase(
        NativeDatabase.memory(),
        File('assets/schema.sql').readAsStringSync(),
      ),
    );
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(const Pupil(id: 'alpha', name: 'Testkind Alpha'));
    await c.savePupil(
      const Pupil(id: 'beta', name: 'Testkind Beta', color: 0xff9dc9d3),
    );
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });

  Future<void> app(
    WidgetTester tester,
    Size size, {
    GlobalKey? boundary,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      boundary == null
          ? FlexApp(controller: c)
          : RepaintBoundary(
              key: boundary,
              child: FlexApp(controller: c),
            ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(FlexBackground.defaultDarkImage),
        tester.element(find.byType(FlexBackground)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  }

  Future<void> pupils(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('page-1')));
    await tester.pumpAndSettle();
  }

  Future<void> closeModal(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byTooltip('Schließen und Eingaben sichern').last,
    );
    await tester.tap(find.byTooltip('Schließen und Eingaben sichern').last);
    await tester.pumpAndSettle();
  }

  void framed(WidgetTester tester, Size size, {double keyboard = 0}) {
    final frame = tester.getRect(
      find.byKey(const ValueKey('flex-modal-frame')).last,
    );
    final gap = size.width <= 700 ? 10.0 : 16.0;
    expect(frame.left, greaterThanOrEqualTo(gap - .01));
    expect(frame.right, lessThanOrEqualTo(size.width - gap + .01));
    expect(frame.top, greaterThanOrEqualTo(gap - .01));
    expect(frame.bottom, lessThanOrEqualTo(size.height - keyboard - gap + .01));
    expect(frame.width, lessThanOrEqualTo(640.01));
    final dialog = tester.widget<Dialog>(find.byType(Dialog).last);
    expect(
      (dialog.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(24),
    );
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    GlobalKey boundary,
    String name,
  ) async {
    final directory = Platform.environment['FLEX_RENDER_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await render.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      Directory(directory).createSync(recursive: true);
      File(
        '$directory/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets(
    'reference navigation, 3+2 pupil cards and search focus replace the old page layout',
    (tester) async {
      await app(tester, const Size(1100, 900));
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      final navigation = tester.getRect(
        find.byKey(const ValueKey('page-pills')),
      );
      expect(navigation.width, 340);
      expect(navigation.center.dx, 550);
      await pupils(tester);
      expect(find.byType(PupilCard), findsNWidgets(2));
      expect(find.byKey(const ValueKey('search-false')), findsNothing);
      Rect shortcut(FlexSymbol symbol) =>
          tester.getRect(find.byKey(ValueKey('shortcut-alpha-${symbol.name}')));
      expect(shortcut(FlexSymbol.goal).top, shortcut(FlexSymbol.social).top);
      expect(shortcut(FlexSymbol.goal).top, shortcut(FlexSymbol.work).top);
      expect(shortcut(FlexSymbol.homework).top, shortcut(FlexSymbol.orga).top);
      expect(
        shortcut(FlexSymbol.homework).top,
        greaterThan(shortcut(FlexSymbol.goal).bottom),
      );
      expect(
        shortcut(FlexSymbol.homework).left,
        shortcut(FlexSymbol.goal).left,
      );
      await tester.tap(find.byTooltip('Schüler suchen'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('search-false'));
      final input = tester.widget<EditableText>(
        find.descendant(of: search, matching: find.byType(EditableText)),
      );
      expect(input.focusNode.hasFocus, isTrue);
      await tester.enterText(search, 'Beta');
      await tester.pumpAndSettle();
      expect(find.byType(PupilCard), findsOneWidget);
      expect(find.byKey(const ValueKey('pupil-card-beta')), findsOneWidget);
      await tester.tap(find.byTooltip('Suchtext leeren'));
      await tester.pumpAndSettle();
      expect(input.focusNode.hasFocus, isTrue);
      expect(find.byType(PupilCard), findsNWidgets(2));
      await tester.tap(find.byTooltip('Suche schließen'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-false')), findsNothing);
      expect(await repo.pupils(), hasLength(2));
      await finish(tester);
    },
  );

  for (final size in [const Size(1100, 900), const Size(320, 700)]) {
    testWidgets(
      'all five pupil areas and editors remain framed modals at ${size.width}',
      (tester) async {
        if (size.width == 320) {
          await c.saveAppearance(c.appearance.copyWith(textScale: 1.35));
        }
        await app(tester, size);
        await pupils(tester);
        for (final symbol in FlexSymbol.values) {
          final shortcut = find.byKey(
            ValueKey('shortcut-alpha-${symbol.name}'),
          );
          await tester.ensureVisible(shortcut);
          await tester.tap(shortcut);
          await tester.pumpAndSettle();
          expect(find.byType(FlexModal), findsOneWidget);
          framed(tester, size);
          final add = find.text(
            symbol == FlexSymbol.orga
                ? 'Orga anlegen'
                : symbol == FlexSymbol.homework
                ? '+ Hausübung'
                : symbol == FlexSymbol.goal
                ? '+ Neues Ziel'
                : 'Eintrag anlegen',
          );
          await tester.ensureVisible(add);
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(find.byType(FlexModal), findsNWidgets(2));
          if (size.width == 320) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 240);
            await tester.pumpAndSettle();
          }
          framed(tester, size, keyboard: size.width == 320 ? 240 : 0);
          await tester.ensureVisible(find.byType(FilledButton).last);
          await tester.pumpAndSettle();
          final save = tester.getRect(find.byType(FilledButton).last);
          expect(
            save.bottom,
            lessThanOrEqualTo(size.height - (size.width == 320 ? 240 : 0)),
          );
          await closeModal(tester);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          await closeModal(tester);
        }
        await finish(tester);
      },
    );
  }

  testWidgets(
    'homework direct choices reject duplicates and preserve persisted state on a failed save',
    (tester) async {
      final record = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'alpha').patch({
          'tasks': [
            const HomeworkTask(
              id: 'task',
              text: 'Synthetische Aufgabe',
            ).toJson(),
            const HomeworkTask(id: 'sibling', text: 'Andere Aufgabe').toJson(),
          ],
          'feedback': [
            SchoolFeedback(
              id: 'note',
              observedOn: dateOnly(DateTime.now()),
              createdAtUtc: utcNow(),
              taskId: 'task',
              taskText: 'Synthetische Aufgabe',
              note: 'Vorhandener Testkommentar',
            ).toJson(),
          ],
        }),
      );
      await c.reload();
      repo.attempts = 0;
      await app(tester, const Size(1100, 1000));
      final button = find.byKey(const ValueKey('status-task-complete'));
      await tester.ensureVisible(button);
      repo.hold = Completer<void>();
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(repo.attempts, 1);
      repo.hold!.complete();
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.attempts, 1);
      expect((await repo.schoolRecords()).single.feedback, hasLength(2));
      final label = tester.widget<RichText>(
        find.descendant(of: button, matching: find.byType(RichText)).first,
      );
      final style = (label.text as TextSpan).style!;
      expect(style.fontFamily, 'FlexSans');
      expect(
        style.color,
        legibleOn(Theme.of(tester.element(button)).colorScheme.primary),
      );
      repo.failNext = true;
      final partial = find.byKey(const ValueKey('status-task-partial'));
      await tester.ensureVisible(partial);
      await tester.tap(partial);
      await tester.pumpAndSettle();
      expect(find.text('Synthetischer Speicherfehler'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(button).selected, isTrue);
      expect(
        (await repo.schoolRecords()).single.taskState(record.tasks.first),
        TaskState.complete,
      );
      await tester.tap(partial);
      await tester.pumpAndSettle();
      final saved = (await repo.schoolRecords()).single;
      expect(saved.taskState(saved.tasks.first), TaskState.partial);
      expect(saved.taskState(saved.tasks.last), TaskState.open);
      expect(saved.feedback.first.note, 'Vorhandener Testkommentar');
      expect(saved.feedback, hasLength(3));
      await finish(tester);
    },
  );

  testWidgets(
    'render reference-derived pupil pages, framed homework and focused comment using synthetic data',
    (tester) async {
      final homework = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.homework, 'alpha').patch({
          'subject': 'Mathematik',
          'dueDate': '2026-11-02',
          'tasks': [
            const HomeworkTask(
              id: 'task',
              text: 'Übungsaufgabe A',
              initialState: TaskState.partial,
            ).toJson(),
            const HomeworkTask(id: 'second', text: 'Übungsaufgabe B').toJson(),
          ],
        }),
      );
      await c.saveEntry(
        OrgaEntry.empty(
          pupilId: 'alpha',
        ).copyWith(title: 'Synthetische Orga-Aufgabe', isTask: true),
      );
      await c.reload();
      final boundary = GlobalKey();
      await app(tester, const Size(1100, 900), boundary: boundary);
      await pupils(tester);
      await capture(tester, boundary, 'handover-pupils-desktop');
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'handover-pupils-mobile');
      await tester.tap(find.byKey(const ValueKey('shortcut-alpha-homework')));
      await tester.pumpAndSettle();
      framed(tester, const Size(390, 844));
      await capture(tester, boundary, 'handover-homework-mobile');
      await tester.ensureVisible(find.byKey(const ValueKey('comment-task')));
      await tester.tap(find.byKey(const ValueKey('comment-task')));
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('homework-comment')),
          matching: find.byType(EditableText),
        ),
      );
      expect(input.focusNode.hasFocus, isTrue);
      expect(find.text('Stand: Teilweise'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('homework-comment')),
        'Synthetische Rückmeldung',
      );
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'handover-comment-mobile');
      await closeModal(tester);
      await closeModal(tester);
      expect((await repo.schoolRecords()).single.id, homework.id);
      await finish(tester);
    },
  );
  testWidgets(
    'save and next preserves errors and resumes the next pupil draft without copying observations',
    (tester) async {
      final beta = SchoolRecord.empty(SchoolKind.social, 'beta').patch({
        'body': 'Vorhandener Entwurf Beta',
        'support': 'Bestehende Hilfe',
      });
      await repo.saveSchoolDraft(
        SchoolDraft(id: 'beta-draft', record: beta, updatedAtUtc: utcNow()),
      );
      await c.reload();
      await app(tester, const Size(620, 1060));
      showDialog<void>(
        context: tester.element(find.byType(Scaffold).first),
        builder: (_) => SchoolEditor(
          controller: c,
          record: SchoolRecord.empty(SchoolKind.social, 'alpha'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-body')),
        'Beobachtung Alpha',
      );
      repo.failNext = true;
      await tester.tap(find.text('Speichern & weiter'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetischer Speicherfehler'), findsOneWidget);
      expect(await repo.schoolRecords(), isEmpty);
      expect(find.text('Beobachtung Alpha'), findsOneWidget);
      await tester.tap(find.text('Speichern & weiter'));
      await tester.pumpAndSettle();
      expect((await repo.schoolRecords()).single.pupilId, 'alpha');
      expect(find.text('Vorhandener Entwurf Beta'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SchoolEditor),
          matching: find.text('Beobachtung Alpha'),
        ),
        findsNothing,
      );
      final support = find.byKey(const ValueKey('record-support'));
      await tester.ensureVisible(support);
      expect(find.text('Bestehende Hilfe'), findsOneWidget);
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(await repo.schoolRecords(), hasLength(2));
      expect(await repo.schoolDrafts(), isEmpty);
      await finish(tester);
    },
  );

  testWidgets(
    'reference observation dialogs and optional calendar time render and preserve selections',
    (tester) async {
      final boundary = GlobalKey();
      await app(tester, const Size(620, 1060), boundary: boundary);
      Future<void> open(SchoolKind kind) async {
        showDialog<void>(
          context: tester.element(find.byType(Scaffold).first),
          builder: (_) => SchoolEditor(
            controller: c,
            record: SchoolRecord.empty(
              kind,
              'alpha',
            ).patch({'observedOn': '2026-11-01'}),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open(SchoolKind.social);
      await capture(tester, boundary, 'reference-social');
      await tester.tap(find.byKey(const ValueKey('favorite-Hilft anderen')));
      await tester.pumpAndSettle();
      expect((await repo.observationCatalog('social-positive')).favorites, [
        'Hilft anderen',
      ]);
      await tester.tap(find.byKey(const ValueKey('observation-Hilft anderen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('observation-date')));
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'reference-calendar-date');
      expect(find.byKey(const ValueKey('calendar-hour')), findsNothing);
      await tester.tap(find.text('Uhrzeit hinzufügen'));
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'reference-calendar-time');
      expect(find.byKey(const ValueKey('calendar-hour')), findsOneWidget);
      await tester.tap(find.byTooltip('Uhrzeit entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-02')));
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      await closeModal(tester);
      final social = (await repo.schoolDrafts()).single.record;
      expect(social.positive, ['Hilft anderen']);
      expect(social.observedOn, '2026-11-02');
      expect(social.observedTime, '');
      await open(SchoolKind.work);
      await tester.tap(find.byKey(const ValueKey('tone-false')));
      await tester.runAsync(() => repo.snapshot());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(
                const ValueKey(
                  'favorite-Beginnt erst nach mehreren Aufforderungen',
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await capture(tester, boundary, 'reference-work');
      final context = find.byKey(const ValueKey('section-Kontext / Quelle'));
      await tester.ensureVisible(context);
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'reference-work-bottom');
      await tester.tap(
        find.byKey(const ValueKey('section-Reaktion / Unterstützung')),
      );
      await tester.pumpAndSettle();
      final support = find.byKey(const ValueKey('record-support'));
      await tester.ensureVisible(support);
      await tester.enterText(support, 'Synthetische Unterstützung');
      await tester.tap(context);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record-support')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-context')), findsOneWidget);
      await closeModal(tester);
      final work = (await repo.schoolDrafts())
          .firstWhere((d) => d.record.kind == SchoolKind.work)
          .record;
      expect(work.support, 'Synthetische Unterstützung');
      await finish(tester);
    },
  );
  testWidgets(
    'calendar supports leap day, month and year choices and midnight on a narrow screen',
    (tester) async {
      await app(tester, const Size(320, 700));
      final result = pickFlexDate(
        tester.element(find.byType(Scaffold).first),
        date: '2026-11-01',
        time: '00:00',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-year')));
      await tester.pumpAndSettle();
      final year = find.text('2028').last;
      await tester.ensureVisible(year);
      await tester.tap(year);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Februar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-day-2028-02-29')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(await result, ('2028-02-29', '00:00'));
      await finish(tester);
    },
  );
}
