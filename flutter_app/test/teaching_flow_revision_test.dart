import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/ui/lesson_flow_page.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/planning_import.dart';
import 'package:flex_notizbuch/domain/teaching_sheet.dart';
import 'classroom_test.dart' show classroomMemory;
import 'teaching_sheet_test.dart' as fixtures;
import 'material_workspace_test.dart' show docx, word;

const day = '2026-11-23', tomorrow = '2026-11-24';
const head = ['Phase', 'Zeit', 'Auftrag'];
const rows = [
  head,
  ['Arbeitsphase', '08:00–08:15', 'Lesen'],
  ['Arbeitsphase', '08:15–08:30', 'Rechnen'],
];
ClassroomDocument plan(
  List<List<String>> rows, {
  String date = day,
  bool week = false,
}) => fixtures.source(
  week ? 'week' : 'plan-$date',
  week ? 'Wochenplanung KW48.docx' : 'Tagesplanung $date.docx',
  day: date,
  weekly: week,
  bytes: docx(word(fixtures.table(rows))),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Ein Schüler behält den angepassten Grundablauf beim Weiterführen und beim Wochenauftrag',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final suggested = lessonFlowFor([], day);
      expect(isSuggestedLessonFlow(suggested), isTrue);
      expect(
        lessonPhases(carryDestination([], day, pupils: [], pupilId: 'a')),
        isEmpty,
      );
      final phases = lessonPhases(suggested);
      phases[0] = phases[0].patch({
        'body': 'Den Lerntag zu zweit beginnen',
        'minutes': 25,
      });
      final shared = await repo.saveClassroomDocument(
        withLessonPhases(suggested, phases),
      );
      final pupil = lessonFlowFor([shared], day, pupilId: 'a');
      expect(isSuggestedLessonFlow(pupil), isFalse);
      final target = carryDestination([shared], day, pupilId: 'a', pupils: []);
      expect(lessonPhases(target).first.minutes, 25);
      final updated = addWeekPhase(
        pupil,
        LessonPhase(
          id: 'wo',
          title: 'Leseauftrag',
          sourceId: 'woche',
          sourceRow: 'zeile-2',
        ),
      );
      expect(lessonPhases(updated), hasLength(6));
      expect(lessonPhases(updated).first.body, 'Den Lerntag zu zweit beginnen');
    },
  );
  test(
    'Ein individueller Word-Abgleich erhält geerbte Handnotizen und lokal bearbeitete Klassenphasen',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final source = plan(rows);
      final draft = lessonFlowFor([source], day);
      final phases = lessonPhases(draft);
      final shared = await repo.saveClassroomDocument(
        withLessonPhases(draft, [
          phases.first.patch({'body': 'Den Auftrag gemeinsam besprechen'}),
          phases.last,
          LessonPhase(id: 'hand', title: 'Lesezeit', minutes: 20),
        ]),
      );
      final personal = lessonFlowFor([source, shared], day, pupilId: 'a');
      final update = plan([
        head,
        ...rows.skip(1),
        ['Abschluss', '08:30–08:35', 'Rückblick'],
      ]);
      final fresh = buildTeachingFlow(update, [update], []);
      final result = reconcileTeachingFlow(
        personal,
        ImportedTeachingFlow(update, [
          for (final p in fresh.phases) individualTeachingPhase(p, 'a'),
        ], {}),
      );
      expect(
        lessonPhases(result).first.body,
        'Den Auftrag gemeinsam besprechen',
      );
      expect(
        lessonPhases(result).map((p) => p.title),
        containsAll(['Abschluss', 'Lesezeit']),
      );
      expect(
        (result.map('flow')['sourceBase'] as Map).containsKey(
          lessonPhases(result).firstWhere((p) => p.title == 'Lesezeit').id,
        ),
        isFalse,
      );
    },
  );
  test(
    'Weiterführen erhält die noch ungespeicherte Zielplanung samt Quelle nach erneutem Laden',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final m = plan(rows),
          to = plan([
            head,
            ['Experiment', '09:00–09:30', 'Magnete'],
          ], date: tomorrow);
      await repo.saveClassroomDocuments([m, to]);
      final docs = await repo.classroomDocuments();
      final from = lessonFlowFor(docs, day),
          target = carryDestination(docs, tomorrow, pupils: []);
      await repo.saveClassroomDocuments(
        carryLessonPhases(from, target, DateTime(2026, 11, 23), insertAt: 0),
      );
      final restored = lessonFlowFor(await repo.classroomDocuments(), tomorrow);
      expect(lessonPhases(restored).map((p) => p.title), [
        'Arbeitsphase',
        'Arbeitsphase',
        'Experiment',
      ]);
      expect(restored.map('flow')['sourceId'], to.id);
      expect(
        lessonPhases(
          lessonFlowFor(await repo.classroomDocuments(), day),
        ).every((p) => p.carriedTo == tomorrow),
        isTrue,
      );
    },
  );
  test(
    'Eingefügte gleichnamige Phase bewahrt erledigten Auftrag, auch mit alten IDs und Löschungen',
    () {
      final source = plan(rows),
          updated = plan([
            head,
            ['Arbeitsphase', '07:45–08:00', 'Wörter'],
            ...rows.skip(1),
          ]);
      for (final legacy in [false, true]) {
        var f = lessonFlowFor([source], day);
        var old = lessonPhases(f);
        if (legacy) {
          final flow = f.map('flow')..remove('sourceRows');
          final base = flow['sourceBase'] as Map;
          final ids = [
            for (var i = 1; i <= 2; i++)
              sheetHash('${source.id}:arbeitsphase-$i'),
          ];
          flow['sourceBase'] = {
            for (final (i, p) in old.indexed) ids[i]: base[p.id],
          };
          old = [
            for (final (i, p) in old.indexed)
              p.patch({'id': ids[i], 'sourceRow': '', 'sourceId': ''}),
          ];
          f = f.patch({'flow': flow});
        }
        final saved = withLessonPhases(f, [
          old.first.patch({'status': 'done'}),
        ]);
        final r = reconcileTeachingFlow(
          saved,
          buildTeachingFlow(updated, [updated], []),
        );
        expect(lessonPhases(r).map((p) => p.body.split('\n').last), [
          'Wörter',
          'Lesen',
        ]);
        expect(lessonPhases(r).last.status, 'done');
        expect(lessonPhases(r).last.id, old.first.id);
        final again = reconcileTeachingFlow(
          r,
          buildTeachingFlow(updated, [updated], []),
        );
        expect(
          lessonPhases(again).map((p) => p.id),
          lessonPhases(r).map((p) => p.id),
        );
      }
    },
  );
  test(
    'Mehrdeutige Änderungen brauchen eine ausdrückliche Zuordnung und bewahren den Timer',
    () {
      final m = plan(rows);
      final f = lessonFlowFor([m], day);
      final active = activateLessonPhase(
        f,
        lessonPhases(f).first.id,
        DateTime.utc(2026, 11, 23, 8),
      );
      final edited = plan([
        head,
        ['Arbeitsphase', '09:00–09:10', 'Schreiben'],
        ['Arbeitsphase', '09:10–09:25', 'Zeichnen'],
      ]);
      final incoming = buildTeachingFlow(edited, [edited], []);
      final comparison = TeachingFlowChanges(active, incoming);
      expect(comparison.ambiguous.length, 2);
      expect(
        () => reconcileTeachingFlow(active, incoming),
        throwsA(isA<DomainError>()),
      );
      final updated = reconcileTeachingFlow(
        active,
        incoming,
        decisions: {
          incoming.phases.first.id: '',
          incoming.phases.last.id: lessonPhases(active).last.id,
        },
      );
      final result = lessonPhases(updated);
      expect(result.where((p) => p.running).single.body, contains('Lesen'));
      expect(result.any((p) => p.body.contains('Schreiben')), isTrue);
    },
  );
  test(
    'Manuelle Korrektur und Sortierung folgen einem eindeutigen Tippfehler',
    () {
      final old = teachingRows(plan(rows));
      final next = teachingRows(
        plan([
          head,
          ['Arbeitsphase', '08:00–08:15', 'Lesen üben'],
          rows.last,
        ]),
      );
      final edits = {
        'changes': [
          {'id': old.first['id'], 'goal': 'Eigenes Ziel'},
        ],
        'order': [old.last['id'], old.first['id']],
      };
      final rebased = rebaseTeachingEdits(old, next, edits);
      expect(
        effectiveSheetRows({'rows': next}, rebased).last['goal'],
        'Eigenes Ziel',
      );
      expect(sheetList(rebased, 'changes').single['id'], next.first['id']);
    },
  );
  test(
    'Eine Korrektur bleibt bei neu aufgetauchten identischen Zeilen zur manuellen Zuordnung erhalten',
    () {
      final old = teachingRows(plan([head, rows[1]]));
      final next = teachingRows(plan([head, rows[1], rows[1]]));
      final edits = {
        'changes': [
          {'id': old.first['id'], 'goal': 'Korrigiertes Ziel'},
        ],
      };
      final rebased = rebaseTeachingEdits(old, next, edits);
      expect(
        effectiveSheetRows({
          'rows': next,
        }, rebased).any((r) => r['goal'] == 'Korrigiertes Ziel'),
        isFalse,
      );
      expect(sheetList(rebased, 'changes').single['goal'], 'Korrigiertes Ziel');
    },
  );
  const pupils = [
    Pupil(id: 'a', name: 'Kind A'),
    Pupil(id: 'b', name: 'Kind B'),
    Pupil(id: 'm', name: 'Kind M'),
    Pupil(id: 'z', name: 'Kind Z'),
  ];
  List<ClassroomDocument> data(ClassroomDocument m) => [
    m,
    fixtures.folder,
    for (final p in pupils)
      buildMaterialProfile(
        [],
        p.id,
        teachingPlan(m)['year'] as String,
        p.id.toUpperCase(),
        [],
      ),
  ];
  test(
    'Zeit, Phase, Schüler und Auftrag ergeben gemeinsame und parallele individuelle Phasen',
    () {
      final m = plan([
        ['Zeit', 'Phase', 'Schüler', 'Auftrag', 'Dauer'],
        ['08:00–08:10', 'Beginn', 'Alle', 'Frage', '10 Min.'],
        ['08:10–08:30', 'Stationen', 'B', 'Vokabeln', '20'],
        ['08:10–08:40', 'Stationen', 'A/M', 'Rechnen', '30'],
      ]);
      final docs = data(m);
      final f = lessonFlowFor(docs, day, pupils: pupils);
      expect(lessonPhases(f).length, 3);
      for (final p in pupils) {
        final ps = lessonPhases(
          lessonFlowFor(
            docs,
            day,
            pupilId: p.id,
            sharedFlow: f,
            pupils: pupils,
          ),
        );
        expect(ps.first.title, 'Beginn');
        expect(ps.length, p.id == 'z' ? 1 : 2);
        if (p.id != 'z') expect(ps.last.minutes, p.id == 'b' ? 20 : 30);
        if (p.id == 'b') expect(ps.last.body, contains('Vokabeln'));
      }
    },
  );
  test(
    'Inline-Kürzel, Gruppen, unklare Codes und getrennte Dauer gelangen nur an die richtigen Schüler',
    () {
      final source = plan([
        head,
        [
          'Lernen',
          '08:00–08:50',
          'B: Englisch U1/2 (20 Min.); A/M: Mathe (35 Min.). X: Zusatzblatt.',
        ],
      ]);
      for (final separate in [false, true]) {
        final m = separate
            ? source.patch({
                'planEdits': {
                  'changes': [
                    {
                      'id': teachingRows(source).single['id'],
                      'groupMode': 'separate',
                    },
                  ],
                },
              })
            : source;
        final docs = data(m);
        final built = buildTeachingFlow(m, docs, pupils);
        expect(built.phases.length, separate ? 2 : 1);
        expect(built.issues.any((v) => v.contains('X')), isTrue);
        final f = lessonFlowFor(docs, day, pupils: pupils);
        for (final p in pupils) {
          final own = lessonPhases(
            lessonFlowFor(
              docs,
              day,
              pupilId: p.id,
              sharedFlow: f,
              pupils: pupils,
            ),
          );
          if (p.id == 'z') {
            expect(own, isEmpty);
            continue;
          }
          expect(own.single.body, contains(p.id == 'b' ? 'Englisch' : 'Mathe'));
          expect(
            own.single.body,
            isNot(contains(p.id == 'b' ? 'Mathe' : 'Englisch')),
          );
          expect(own.single.body, isNot(contains('Zusatzblatt')));
          expect(own.single.minutes, p.id == 'b' ? 20 : 35);
        }
      }
    },
  );
  test(
    'Ein bereits verlorener Zielauftrag wird nur auf ausdrücklichen Wunsch wiederhergestellt',
    () {
      final m = plan(rows), flow = lessonFlowFor([m], day);
      final [one, two] = lessonPhases(flow);
      final incomplete = withLessonPhases(flow, [one]);
      final incoming = buildTeachingFlow(m, [m], []);
      expect(
        lessonPhases(reconcileTeachingFlow(incomplete, incoming)).length,
        1,
      );
      expect(
        lessonPhases(
          reconcileTeachingFlow(incomplete, incoming, restore: {two.id}),
        ).map((p) => p.id),
        [one.id, two.id],
      );
    },
  );
  test(
    'Kürzel in der Materialspalte teilen die verknüpften Dateien pro Schüler auf',
    () {
      final m = plan([
        ['Phase', 'Zeit', 'Auftrag', 'Material'],
        [
          'Lernen',
          '08:00–08:30',
          'B: Englisch; A/M: Mathe',
          'B: E01; A/M: M01',
        ],
      ]);
      final docs = [
        ...data(m),
        for (final code in ['E01', 'M01'])
          fixtures.source(code, '$code Blatt.pdf', day: day),
      ];
      final f = lessonFlowFor(docs, day, pupils: pupils);
      for (final p in pupils.take(3)) {
        final own = lessonPhases(
          lessonFlowFor(
            docs,
            day,
            pupils: pupils,
            pupilId: p.id,
            sharedFlow: f,
          ),
        ).single;
        expect(own.materialIds, [p.id == 'b' ? 'E01' : 'M01']);
        expect(own.body, isNot(contains(p.id == 'b' ? 'M01' : 'E01')));
      }
    },
  );
  testWidgets(
    'Wochenzeile lässt sich im Ablauf öffnen, anpassen und nur einmal übernehmen',
    (t) async {
      final n = NotebookController(classroomMemory());
      final week = plan([
        ['Tag', 'Schwerpunkt', 'Vorbereitung'],
        ['Mo', 'Geometrie', 'Geobretter'],
      ], week: true);
      await t.runAsync(() async {
        await n.initialize();
        await n.saveClassroom(week);
      });
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonFlowPage(controller: n, initialDate: day),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Aus der Wochenplanung'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Aus der Wochenplanung'));
      await t.pumpAndSettle();
      final take = find.text('Für diese Stunde übernehmen');
      await t.ensureVisible(take);
      await t.tap(take);
      await t.pumpAndSettle();
      expect(find.text('Wochenauftrag übernehmen'), findsOneWidget);
      final save = find.text('Speichern');
      await t.ensureVisible(save);
      await t.tap(save);
      for (var i = 0; i < 80 && !n.classroom.any(hasLessonFlow); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 20));
      }
      await t.pumpAndSettle();
      expect(
        lessonPhases(n.classroom.firstWhere(hasLessonFlow)).single.title,
        'Geometrie',
      );
      expect(find.text('Im Ablauf · Geometrie'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      n.dispose();
      await t.runAsync(n.repository.close);
    },
  );
  test(
    'Wochenauftrag wird bewusst einmal in die gewählte Stunde übernommen',
    () {
      final week = plan([
        ['Tag', 'Schwerpunkt', 'Vorbereitung'],
        ['Mo', 'Geometrie', 'Geobretter'],
      ], week: true);
      final row = weeklyContext(week, day).single;
      final draft = weekPhaseDraft(week, row, TeachingLinks(week, [week], []))
          .patch({
            'minutes': 25,
            'pupilIds': ['a'],
          });
      final f = lessonFlowFor([week], day, lessonTarget: 'lesson-A');
      expect(isSuggestedLessonFlow(f), isTrue);
      final saved = addWeekPhase(f, draft);
      expect(lessonPhases(saved).single.body, contains('Geobretter'));
      expect(coveredWeekPhase(saved, week, row)?.minutes, 25);
      expect(() => addWeekPhase(saved, draft), throwsA(isA<DomainError>()));
      expect(weeklyContext(week, tomorrow), isEmpty);
      final daily = plan([
        head,
        ['Einstieg', '08:00–08:15', 'Geometrie'],
      ]);
      expect(
        coveredWeekPhase(lessonFlowFor([daily], day), week, row)?.title,
        'Einstieg',
      );
    },
  );
}
