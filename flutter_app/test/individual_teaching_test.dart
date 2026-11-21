import 'dart:typed_data';
import 'dart:convert';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/services/scan_store.dart';
import 'package:flex_notizbuch/ui/lesson_question.dart';
import 'package:flex_notizbuch/ui/material_library.dart';
import 'package:flex_notizbuch/ui/submission_collection.dart';
import 'classroom_test.dart' show classroomMemory, returns;
import 'material_workspace_test.dart' show material, MemoryMaterialFiles;
import 'document_scanner_test.dart' show scannerImage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late NotebookController c;
  setUp(() async {
    c = NotebookController(classroomMemory());
    await c.initialize();
    await c.savePupil(const Pupil(id: 'a', name: 'Alex'));
    await c.savePupil(const Pupil(id: 'b', name: 'Bea'));
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  test(
    'continue one phase preserves its material, sibling, destination and template privacy',
    () async {
      final sheet = await c.repository.saveClassroomDocument(
        material('Brüche'),
      );
      final source = await c.repository.saveClassroomDocument(
        withLessonPhases(lessonFlowFor([], '2026-11-18', pupilId: 'a'), [
          LessonPhase(id: 'br', title: 'Brüche', materialIds: [sheet.id]),
          const LessonPhase(id: 'h', title: 'HÜ-Kontrolle'),
        ]),
      );
      final dest = await c.repository.saveClassroomDocument(
        withLessonPhases(
          lessonFlowFor([], '2026-11-19', pupilId: 'a', lessonTarget: 'morgen'),
          [const LessonPhase(id: 'x', title: 'Lesen')],
        ),
      );
      final pair = carryLessonPhases(
        source,
        dest,
        DateTime.utc(2026, 11, 18),
        phaseId: 'br',
        resumeNote: 'Bei Aufgabe 4',
      );
      await c.saveClassroomBatch(pair);
      final old = lessonPhases(
        c.classroom.singleWhere((d) => d.id == source.id),
      );
      expect(old.first.carriedTo, '2026-11-19');
      expect(old.last.status, 'open');
      final tomorrow = c.classroom.singleWhere((d) => d.id == dest.id);
      expect(lessonPhases(tomorrow).map((p) => p.title), ['Brüche', 'Lesen']);
      expect(lessonPhases(tomorrow).first.materialIds, [sheet.id]);
      expect(lessonPhases(tomorrow).first.resumeNote, 'Bei Aufgabe 4');
      expect(
        lessonPhases(flowTemplate(tomorrow, 'Mathe')).first.resumeNote,
        '',
      );
      expect(
        () => carryLessonPhases(
          source,
          lessonFlowFor([], '2026-11-19', pupilId: 'b'),
          DateTime.now(),
          phaseId: 'br',
        ),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        c.saveClassroomBatch(pair),
        throwsA(isA<StaleRevision>()),
      );
    },
  );

  testWidgets(
    'goal question stays within one pupil and lesson, answer persists as dated evidence',
    (t) async {
      const day = '2026-11-18', question = 'Beginnt ohne Aufforderung?';
      final goal = await c.repository.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.goal, 'a').patch({
          'title': 'Arbeitsbeginn',
          'lessonQuestion': const LessonQuestion(
            question,
            day,
            start: '09:00',
            end: '10:00',
          ).toJson(),
        }),
      );
      await c.reload();
      SchoolRecord work(String id, String time) => SchoolRecord.empty(
        SchoolKind.work,
        id,
      ).patch({'observedOn': day, 'observedTime': time});
      var r = work('b', '09:30');
      Future<void> render() async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LessonQuestionPrompt(
                controller: c,
                record: r,
                onChanged: (v) => r = r.patch(v),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await render();
      expect(find.text(question), findsNothing);
      r = work('a', '10:00');
      await render();
      expect(find.text(question), findsNothing);
      r = work('a', '09:15');
      await render();
      expect(find.text(question), findsOneWidget);
      expect(r.lessonQuestion, isNull);
      await t.tap(find.text('Nach einem Hinweis'));
      await t.pump();
      await c.saveRecord(r);
      expect(c.records.singleWhere((v) => v.id == r.id).goalId, goal.id);
      final captured = r;
      r = work('a', '09:45');
      await render();
      expect(find.text(question), findsNothing);
      r = captured;
      await c.saveRecord(goal.patch({'lessonQuestion': null}));
      final restored = classroomMemory();
      await restored.initialize();
      addTearDown(restored.close);
      await restored.restoreBackup(await c.repository.exportBackup());
      final result = (await restored.schoolRecords()).singleWhere(
        (v) => v.id == r.id,
      );
      expect(result.lessonQuestion!.summary, '$question · Nach einem Hinweis');
      expect(result.observedOn, day);
    },
  );

  test(
    'collection commits separate multipage PDFs and retains the draft when a return closes',
    () async {
      final files = MemoryMaterialFiles();
      final hw = SchoolRecord.empty(SchoolKind.homework, 'a').patch({
        'tasks': [const HomeworkTask(id: 'task', text: 'Seite 12').toJson()],
      });
      final group = await c.repository.saveSchoolGroup(hw, [
        'a',
        'b',
      ], 'gruppe');
      expect(group.every((r) => r.homeworkGroup == 'gruppe'), true);
      Future<DialogDraft> draft(String person, DocumentLink link) async {
        final pages = <Json>[];
        for (var i = 0; i < 2; i++) {
          final key = newId();
          await files.write(key, scannerImage());
          pages.add(ScanPage(key, 100, 160).toJson());
        }
        return c.repository.saveDialogDraft(
          DialogDraft(
            id: newId(),
            ownerId: newId(),
            type: 'scan',
            updatedAtUtc: utcNow(),
            data: {
              ...ScanContext(
                collection: true,
                pupilIds: [person],
                links: [link],
                title: 'Blatt',
                category: link.kind == 'school' ? 'pupilWork' : 'form',
              ).initial(),
              'pages': pages,
            },
          ),
        );
      }

      for (final r in group) {
        final link = DocumentLink('school', r.id);
        final doc = await saveScan(
          c.repository,
          files,
          await draft(r.pupilId, link),
        );
        expect(doc.strings('pupilIds'), [r.pupilId]);
        expect(doc.number('pageCount'), 2);
        expect(doc.flag('collected'), true);
        expect(doc.text('extension'), 'pdf');
        expect(doc.rows('links').single, link.toJson());
      }
      expect(
        (await c.repository.classroomDocuments())
            .where((d) => d.flag('collected'))
            .length,
        2,
      );
      final list = await c.repository.saveClassroomDocument(
        returns('a', type: 'form'),
      );
      final session = await draft('a', DocumentLink('classroom', list.id));
      await c.repository.saveClassroomDocument(list.patch({'closed': true}));
      await expectLater(
        saveScan(c.repository, files, session),
        throwsA(isA<DomainError>()),
      );
      expect(
        (await c.repository.dialogDrafts()).any((d) => d.id == session.id),
        true,
      );
      expect(
        (await c.repository.classroomDocuments())
            .where((d) => d.flag('collected'))
            .length,
        2,
      );
    },
  );

  testWidgets(
    'offline count deduplicates planned files and distinguishes a stale local key and a link',
    (t) async {
      const day = '2026-11-19';
      final files = MemoryMaterialFiles();
      await files.write('present', Uint8List.fromList([1]));
      final first = planPupilMaterial(
        material('Lesen', fields: {'localKey': 'present'}),
        'a',
        day,
      );
      final second = planPupilMaterial(
        material(
          'Schreiben',
          fields: {
            'localKey': 'missing',
            'driveId': 'drive',
            'itemId': 'item',
            'extension': 'docx',
          },
        ),
        'b',
        day,
      );
      final link = material('Website', fields: {'extension': 'link'});
      final docs = [
        first,
        second,
        link,
        prepareMaterials([first, second, link], day, [first.id, link.id]),
      ];
      final combined = preparedDayMaterials(docs, day);
      expect(combined.length, 3);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparedOfflineStatus(
              controller: c,
              files: files,
              details: true,
              materials: combined,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('1 von 3 auf diesem Gerät'));
      await t.pumpAndSettle();
      expect(find.text('Online-Link'), findsOneWidget);
      expect(find.byTooltip('Schreiben offline laden'), findsOneWidget);
      expect(find.byTooltip('Website offline laden'), findsNothing);
      await files.write('missing', Uint8List.fromList([2]));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.text('2 von 3 auf diesem Gerät'), findsOneWidget);
    },
  );
  testWidgets(
    'a reopened return collection counts saved PDFs, offers the next pupil and marks receipt explicitly',
    (t) async {
      final list = await c.repository.saveClassroomDocument(
        returns('a', type: 'form').patch({
          'participants': [
            for (final id in ['a', 'b'])
              {
                'pupilId': id,
                'name': id == 'a' ? 'Alex' : 'Bea',
                'status': 'open',
                'paid': 0,
                'note': '',
              },
          ],
        }),
      );
      final scope = ScanContext(
        collection: true,
        pupilIds: ['a'],
        links: [DocumentLink('classroom', list.id)],
        category: 'form',
        title: 'Alex',
      );
      await c.repository.saveClassroomDocument(
        material(
          'Alex · Abgabe',
          fields: {
            'links': scope.links.map((l) => l.toJson()).toList(),
            'pupilIds': ['a'],
            'collected': true,
          },
        ),
      );
      await c.repository.saveClassroomDocument(
        material(
          'Vorlage',
          fields: {
            'links': scope.links.map((l) => l.toJson()).toList(),
            'pupilIds': ['b'],
          },
        ),
      );
      await c.reload();
      Future<void> open() async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SubmissionCollection(
                controller: c,
                title: list.title,
                returnId: list.id,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await open();
      expect(find.text('1 von 2 eingesammelt'), findsOneWidget);
      expect(find.text('Nächster Schüler · Bea'), findsOneWidget);
      final receive = find.text('Als Erhalten markieren');
      await t.ensureVisible(receive);
      await t.tap(receive);
      await t.pumpAndSettle();
      expect(
        c.classroom
            .singleWhere((d) => d.id == list.id)
            .returnParticipant('a')!['status'],
        'received',
      );
      await t.pumpWidget(const SizedBox());
      await c.reload();
      await open();
      expect(find.text('1 von 2 eingesammelt'), findsOneWidget);
      expect(find.text('Als Erhalten markieren'), findsNothing);
    },
  );

  test(
    'merging an older notebook retains the original homework group for collection',
    () async {
      final homework = SchoolRecord.empty(SchoolKind.homework, 'a').patch({
        'tasks': [const HomeworkTask(id: 't', text: 'Rechnen').toJson()],
      });
      await c.repository.saveSchoolGroup(homework, [
        'a',
        'b',
      ], 'teaching-group');
      final legacy = jsonDecode(await c.repository.exportBackup()) as Map;
      for (final row in legacy['tables']['school_records'] as List) {
        final value = jsonDecode(row['payload'] as String) as Map;
        value.remove('homeworkGroup');
        row['payload'] = jsonEncode(value);
      }
      final target = classroomMemory();
      await target.initialize();
      addTearDown(target.close);
      final incoming = jsonEncode(legacy);
      final plan = await target.prepareBackupMerge(incoming);
      await target.applyBackupMerge(plan, {});
      expect((await target.schoolRecords()).map((r) => r.homeworkGroup), [
        'teaching-group',
        'teaching-group',
      ]);
      final second = await target.prepareBackupMerge(incoming);
      expect(
        second.items
            .where((i) => i.kind == 'school')
            .every(
              (i) => i.incoming['homeworkGroup'] == i.local?['homeworkGroup'],
            ),
        true,
      );
    },
  );

  test('legacy groups respect explicit assignment and undone groups', () {
    expect(
      legacyHomeworkGroup('a', [
        {'request': '{"ids":["a","b"]}', 'undone_at_utc': 'old'},
      ]),
      {'a'},
    );
    expect(
      legacyHomeworkGroup('a', [
        {
          'request':
              '{"type":"dialog-bulk","school":[{"kind":"homework","id":"a"},{"kind":"homework","id":"b"},{"kind":"social","id":"c"}]}',
        },
      ]),
      {'a', 'b'},
    );
  });
}
