import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/planning_import.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/services/material_sync.dart';
import 'package:flex_notizbuch/services/material_index.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/ui/pupil_editor.dart';
import 'package:flex_notizbuch/ui/material_library.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show MemoryMaterialFiles;

const mila = Pupil(id: 'p', name: 'Mila Beispiel'),
    mika = Pupil(id: 'q', name: 'Mika Muster');
const year = '2026-27', prefix = 'Planung/2026-27/KW48/Materialien';
ClassroomDocument file(String path, {String id = 'file'}) =>
    ClassroomDocument.create(ClassroomKind.material, path.split('/').last, {
      'extension': path.endsWith('.docx') ? 'docx' : 'pdf',
      'itemId': id,
      'driveId': 'drive',
      'remoteName': path.split('/').last,
      'sourcePath': path,
      'planning': classifyPlanningFile(path),
    }, id: id);

class _PlanningDrive extends OneDriveClient {
  final childrenById = <String, List<Json>>{
    'root': [
      {'name': '2026-11-24', 'id': 'day', 'folder': {}},
      {'name': '2026-11-25', 'id': 'next', 'folder': {}},
    ],
    'day': [
      {'name': 'Mathe MI01.pdf', 'id': 'a'},
    ],
    'next': [],
  };
  @override
  Future<Json> graph(String path, {bool retried = false}) async {
    expect(path, '/me/drive');
    return {'id': 'drive'};
  }

  @override
  Future<List<Json>> children({String? drive, String? folder}) async =>
      childrenById[folder]!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Einsatz aus Verzeichnis, ISO-Woche auch über den Jahreswechsel, Vorlagen und freie Dateien',
    () {
      Json parse(String path) => classifyPlanningFile(path);
      expect(parse('$prefix/2026-11-24/Brüche 2026-10-13 MI01.pdf'), {
        'use': 'lesson',
        'year': year,
        'day': '2026-11-24',
        'week': '2026-11-23',
      });
      expect(parse('$prefix/Thema 2026-11-25.pdf')['day'], '2026-11-25');
      expect(parse('$prefix/Thema 2026-08-12.pdf')['day'], '');
      expect(parse('$prefix/2026-02-31.pdf')['day'], '');
      expect(parse('Planung/2026-27/KW01/Idee.docx')['week'], '2027-01-04');
      expect(parse('Planung/2026-27/KW53/Idee.docx')['week'], '2026-12-28');
      expect(parse('Planung/2025-26/KW53/Idee.docx')['week'], '');
      expect(parse('Planung/Vorlagen/Tagesplanung 2026-11-24.docx')['day'], '');
      expect(parse('Vorlagen/2026-27/KW48/Thema.pdf')['week'], '');
      expect(
        parse('$prefix/FLEX Tagesplanung 2026-11-24.docx')['use'],
        'dayPlan',
      );
      expect(
        parse('$prefix/FLEX Wochenübersicht 2026 KW48.pdf')['use'],
        'weekPlan',
      );
      expect(
        parse('$prefix/2026-11-24/Englisch Supplierung (2b)/Text.docx')['use'],
        'substitute',
      );
      expect(parse('$prefix/Spiel.html')['use'], 'media');
      expect(parse('$prefix/Video.url')['use'], 'media');
      expect(parse('$prefix/Material A16L.pdf')['use'], 'solution');
      expect(parse('Pool/Material.pdf'), {
        'use': 'lesson',
        'year': '',
        'day': '',
        'week': '',
      });
    },
  );
  test(
    'Bestätigte Kürzel und ganze Aliasnamen, Gruppen, Kollisionen und Präfixe',
    () {
      final p = buildMaterialProfile([], mila.id, year, 'MI', [
        'Mila B.',
        'Pat',
      ]);
      final q = buildMaterialProfile([p], mika.id, year, 'M', ['Mika', 'Pat']);
      final roster = PlanningRoster([p, q], [mila, mika]);
      PlanningMatch match(String s) => roster.match(file('$prefix/$s.pdf'));
      expect(match('Mathe_MI01L').owners, {'p'});
      expect(match('M01 und MI01').owners, {'p', 'q'});
      expect(match('M und MI').ambiguous, true);
      expect(match('Arbeitsblätter A bis E').needsReview, false);
      expect(match('M Text').owners, {'q'});
      expect(match('M Text').ambiguous, true);
      expect(match('MI-01 Lösung').owners, {'p'});
      expect(match('Mathe M_09L').clear, true);
      expect(match('Text für Mila Beispiel').ambiguous, true);
      expect(match('Text für Mila Beispiel').owners, {'p'});
      expect(match('Material Teil M').needsReview, false);
      expect(match('TeamMI01').needsReview, false);
      expect(match('M010').needsReview, false);
      expect(match('Mathe mit Mika').owners, {'q'});
      expect(match('Mikado').needsReview, false);
      expect(match('Material Pat').ambiguous, true);
      expect(match('Mika MI01').ambiguous, true);
      expect(match('Z01 MI01').unknown, {'Z'});
      expect(
        PlanningRoster(
          [p, q],
          [mila.copyWith(archived: true), mika],
        ).match(file('$prefix/MI01.pdf')).owners,
        isEmpty,
      );
      expect(suggestMaterialCode('Mila', [q], mila.id, year), 'MI');
      expect(
        () => buildMaterialProfile([p, q], 'new', year, 'M', []),
        throwsA(isA<DomainError>()),
      );
      expect(
        buildMaterialProfile([p, q], 'new', '2027-28', 'M', []).text('code'),
        'M',
      );
      expect(
        roster.match(file('Planung/2027-28/KW48/M01.pdf')).owners,
        isEmpty,
      );
    },
  );
  test(
    'Frühere Ordnerverknüpfungen und Einzelimport erhalten den vollständigen Planungspfad aus Graph',
    () {
      final roster = PlanningRoster(
        [buildMaterialProfile([], mila.id, year, 'M', [])],
        [mila],
      );
      final entry = OneDriveMaterialIndex([]).material('drive', {
        'id': 'blatt',
        'name': 'M36.pdf',
        'parentReference': {
          'driveId': 'drive',
          'path':
              '/drives/drive/root:/FLEX-Klasse/Planung/2026-27/KW47/Materialien/2026-11-18',
        },
      }, path: 'Materialien/2026-11-18/M36.pdf');
      final planned = roster.suggestedImport(entry);
      expect(planned.text('sourcePath'), contains('Planung/2026-27/KW47'));
      expect(planned.strings('pupilIds'), [mila.id]);
      expect(pupilMaterialDates(planned, mila.id), ['2026-11-18']);
      final removed = assignMaterialPupils(planned, [], {});
      expect(roster.automaticOwners(removed), isEmpty);
      expect(roster.match(removed, includeDecided: true).owners, {mila.id});
    },
  );

  test(
    'Direkter Explorer-Import übernimmt die persönliche Ordnerregel und respektiert spätere Änderungen',
    () {
      final rule = ClassroomDocument.create(
        ClassroomKind.folder,
        'Persönlich',
        {
          'driveId': 'drive',
          'itemId': 'private',
          'accountDrive': 'drive',
          'personal': true,
          'incoming': true,
          'pupilIds': [mila.id],
        },
        id: 'personal',
      );
      final roster = PlanningRoster([rule], [mila, mika]);
      final d = OneDriveMaterialIndex([]).material('drive', {
        'id': 'one',
        'name': 'Klassenblatt.pdf',
      }, path: 'Persönlich/Klassenblatt.pdf');
      final suggested = roster.suggestedImport(d, rule: rule);
      expect(suggested.strings('pupilIds'), [mila.id]);
      expect(suggested.text('cloudRule'), rule.id);
      final removed = assignMaterialPupils(suggested, [], {});
      expect(
        roster.suggestedImport(removed, rule: rule).strings('pupilIds'),
        isEmpty,
      );
      expect(
        roster
            .suggestedImport(
              d.patch({
                'pupilIds': [mika.id],
              }),
              rule: rule,
            )
            .strings('pupilIds'),
        [mika.id],
      );
      expect(
        PlanningRoster(
          [rule],
          [mila.copyWith(archived: true)],
        ).suggestedImport(d, rule: rule).strings('pupilIds'),
        isEmpty,
      );
    },
  );

  test(
    'Abgleich behandelt Bestand, neue Dateien, Lösungen, persönliche Termine und geänderte Pfade',
    () async {
      final repo = classroomMemory(), drive = _PlanningDrive();
      addTearDown(repo.close);
      addTearDown(drive.dispose);
      await repo.initialize();
      await repo.savePupilDialog(
        mila,
        null,
        materialProfile: buildMaterialProfile([], mila.id, year, 'MI', []),
      );
      await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.folder, 'Materialien', {
          'driveId': 'drive',
          'itemId': 'root',
          'accountDrive': 'drive',
          'incoming': true,
          'planningFolder': true,
          'folderPath': prefix,
        }, id: 'rule'),
      );
      Future<void> sync() async => expect(
        (await MaterialSync(repo, drive, MemoryMaterialFiles()).run()).errors,
        isEmpty,
      );
      Future<ClassroomDocument> get(String id) async =>
          (await repo.classroomDocuments()).firstWhere(
            (d) => d.kind == ClassroomKind.material && d.text('itemId') == id,
          );
      await sync();
      expect((await get('a')).strings('pupilIds'), ['p']);
      final roster = PlanningRoster(
        await repo.classroomDocuments(),
        await repo.pupils(),
      );
      expect(roster.match(await get('a')).needsReview, false);
      await repo.saveClassroomDocument(
        (await get('a')).patch({'pupilIds': <String>[]}),
      );
      drive.childrenById['day']!.addAll([
        {'id': 'b', 'name': 'Mathe MI02.pdf'},
        {'id': 'solution', 'name': 'Mathe MI02L.pdf'},
        {
          'id': 'old',
          'name': 'Mathe MI03.pdf',
          'createdDateTime': '2025-01-01T00:00:00Z',
        },
        {
          'id': 'media',
          'name': 'Üben.HTML',
          'webUrl': 'https://example.org/drive/item',
        },
        {'id': 'shared', 'name': 'Experiment.pdf'},
        {'id': 'duplicate', 'name': 'Experiment.pdf'},
        {'id': 'weekly', 'name': 'FLEX Wochenübersicht KW48.docx'},
      ]);
      await sync();
      var documents = await repo.classroomDocuments();
      final b = await get('b');
      expect(b.strings('pupilIds'), ['p']);
      expect(pupilMaterialDates(b, 'p'), ['2026-11-24']);
      expect((await get('a')).strings('pupilIds'), isEmpty);
      expect((await get('old')).strings('pupilIds'), ['p']);
      expect((await get('solution')).text('audience'), 'teacher');
      expect(
        relatedPlanningFiles(b, documents).map((m) => m.text('itemId')),
        contains('solution'),
      );
      expect((await get('media')).text('extension'), 'link');
      expect((await get('shared')).strings('pupilIds'), isEmpty);
      expect(
        preparedMaterialsByDay(
          documents,
        )['2026-11-24']!.map((m) => m.text('itemId')),
        containsAll(['shared', 'duplicate', 'media']),
      );
      expect(
        preparedDayMaterials(
          documents,
          '2026-11-24',
        ).any((m) => m.text('itemId') == 'weekly'),
        false,
      );
      await repo.saveClassroomDocument(
        planPupilMaterial(
          await get('old'),
          'p',
          '2026-12-01',
          replaceDate: '2026-11-24',
        ),
      );
      for (final id in ['old', 'b']) {
        final item = drive.childrenById['day']!.firstWhere(
          (j) => j['id'] == id,
        );
        drive.childrenById['next']!.add(item);
        drive.childrenById['day']!.remove(item);
      }
      await sync();
      expect(pupilMaterialDates(await get('old'), 'p'), ['2026-12-01']);
      expect(pupilMaterialDates(await get('b'), 'p'), ['2026-11-25']);
      expect((await get('b')).id, b.id);
      await repo.saveClassroomDocument(
        (await get('b')).patch({'pupilIds': <String>[]}),
      );
      await repo.saveClassroomDocument(
        updateTeachingPlan(await get('shared'), {
          'planningOverride': {'day': '2026-11-30', 'week': '2026-11-30'},
        }),
      );
      await sync();
      expect(roster.match(await get('b')).needsReview, false);
      expect(teachingDay(await get('shared')), '2026-11-30');
      documents = await repo.classroomDocuments();
      final copy = classroomMemory();
      addTearDown(copy.close);
      await copy.initialize();
      await copy.restoreBackup(await repo.exportBackup());
      expect(
        pupilProfile(await copy.classroomDocuments(), 'p', year)!.text('code'),
        'MI',
      );
      expect(
        preparedMaterialsByDay(await copy.classroomDocuments()).keys,
        contains('2026-11-30'),
      );
      final before = await get('old');
      await sync();
      expect((await get('old')).revision, before.revision);
    },
  );

  test(
    'Klassenordner ordnet den Altbestand nach bestätigten Kürzeln nachträglich zu',
    () async {
      final repo = classroomMemory(), drive = _PlanningDrive();
      addTearDown(repo.close);
      addTearDown(drive.dispose);
      await repo.initialize();
      final counts = {'M': 50, 'B': 26, 'A': 29};
      final pupils = [
        for (final code in counts.keys)
          Pupil(id: 'p-$code', name: 'Schüler $code'),
      ];
      for (final p in pupils) {
        await repo.savePupil(p);
      }
      Json folder(String id, String name) => {
        'id': id,
        'name': name,
        'folder': {},
      };
      final fixtures = [
        for (final entry in counts.entries)
          for (var i = 1; i <= entry.value; i++)
            {
              'id': '${entry.key}$i',
              'name':
                  'Blatt ${entry.key}${i.toString().padLeft(2, '0')}${i == 1 ? 'L' : ''}.pdf',
              'createdDateTime': '2026-09-01T07:00:00Z',
            },
      ];
      drive.childrenById
        ..clear()
        ..addAll({
          'root': [folder('plan', 'Planung'), folder('class', 'Klasse')],
          'class': [
            {'id': 'general', 'name': 'M01.pdf'},
          ],
          'plan': [folder('year', year), folder('previous', '2025-26')],
          'previous': [
            {'id': 'previous-year', 'name': 'M01.pdf'},
          ],
          'year': [folder('week', 'KW47')],
          'week': [folder('materials', 'Materialien')],
          'materials': [
            folder('day', '2026-11-18'),
            folder('private', 'Persönlich'),
          ],
          'private': [
            {'id': 'personal', 'name': 'Blatt M01.pdf'},
          ],
          'day': [
            ...fixtures,
            {'id': 'group', 'name': 'Übung A und M.pdf'},
            {'id': 'deferred', 'name': 'Text M36.pdf'},
            {'id': 'denied', 'name': 'Text A09.pdf'},
            {'id': 'conflict', 'name': 'Test B13.pdf'},
            {'id': 'no-code', 'name': 'Gemeinsam.pdf'},
          ],
        });
      await repo.saveClassroomDocuments([
        ClassroomDocument.create(ClassroomKind.folder, 'FLEX-Klasse', {
          'accountDrive': 'drive',
          'driveId': 'drive',
          'itemId': 'root',
          'incoming': true,
        }, id: 'class-rule'),
        ClassroomDocument.create(ClassroomKind.folder, 'Persönlich', {
          'accountDrive': 'drive',
          'driveId': 'drive',
          'itemId': 'private',
          'incoming': true,
          'personal': true,
          'pupilIds': ['p-A'],
        }, id: 'personal-rule'),
      ]);
      final sync = MaterialSync(repo, drive, MemoryMaterialFiles());
      expect((await sync.run()).assigned, 0);
      Future<Map<String, ClassroomDocument>> files() async => {
        for (final d in (await repo.classroomDocuments()).where(
          (d) => d.kind == ClassroomKind.material,
        ))
          d.text('itemId'): d,
      };
      final before = await files();
      await repo.saveClassroomDocuments([
        before['M1']!.patch({
          'planning': <String, dynamic>{},
          'title': 'Eigene Bezeichnung',
        }),
        before['denied']!.patch({
          'planningDecisions': ['p-A'],
        }),
        before['deferred']!.patch({
          'planningDeferred': ['p-M'],
        }),
        before['conflict']!.patch({
          'pupilIds': ['p-A'],
          'pupilDates': [
            {'pupilId': 'p-A', 'date': '2026-12-01'},
          ],
        }),
        for (final p in pupils)
          buildMaterialProfile([], p.id, year, p.id.substring(2), []),
      ]);
      final result = await sync.run();
      expect(result.errors, isEmpty);
      expect(result.assigned, 105);
      final after = await files();
      for (final item in fixtures) {
        final id = item['id']!, owner = 'p-${id[0]}', doc = after[id]!;
        expect(doc.id, before[id]!.id);
        expect(doc.strings('pupilIds'), [owner]);
        expect(pupilMaterialDates(doc, owner), ['2026-11-18']);
      }
      expect(after['M1']!.title, 'Eigene Bezeichnung');
      expect(after['personal']!.strings('pupilIds'), ['p-A']);
      expect(after['conflict']!.strings('pupilIds'), ['p-A']);
      expect(pupilMaterialDates(after['conflict']!, 'p-A'), ['2026-12-01']);
      for (final id in [
        'previous-year',
        'general',
        'group',
        'denied',
        'deferred',
        'no-code',
      ]) {
        expect(after[id]!.strings('pupilIds'), isEmpty, reason: id);
      }
      expect((await sync.run()).imported, 0);
      expect((await files()).length, before.length);
      final roster = PlanningRoster(
        await repo.classroomDocuments(),
        await repo.pupils(),
      );
      expect(roster.match(after['denied']!).needsReview, false);
      expect(roster.match(after['denied']!, includeDecided: true).owners, {
        'p-A',
      });
      expect(roster.match(after['conflict']!).ambiguous, true);
      expect(roster.match(after['deferred']!).owners, {'p-M'});
      final restored = classroomMemory();
      addTearDown(restored.close);
      await restored.initialize();
      await restored.restoreBackup(await repo.exportBackup());
      expect(
        pupilMaterialsOnDay(
          await restored.classroomDocuments(),
          '2026-11-18',
        ).length,
        105,
      );
    },
  );

  test(
    'Kürzel bleibt nach Umbenennung, Wechsel und Archivierung reserviert, Konflikte sind atomar',
    () async {
      final repo = classroomMemory();
      addTearDown(repo.close);
      await repo.initialize();
      final first = await repo.savePupilDialog(
        mila,
        null,
        materialProfile: buildMaterialProfile([], mila.id, year, 'M', []),
      );
      final old = await repo.classroomDocuments();
      final next = buildMaterialProfile(old, mila.id, year, 'MI', []);
      await repo.savePupilDialog(
        first.copyWith(name: 'Neuer Name', archived: true),
        null,
        materialProfile: next,
      );
      final current = await repo.classroomDocuments();
      expect(pupilProfile(current, mila.id, year)!.strings('reserved'), [
        'M',
        'MI',
      ]);
      await expectLater(
        repo.savePupilDialog(
          mika,
          null,
          materialProfile: buildMaterialProfile([], mika.id, year, 'M', []),
        ),
        throwsA(isA<DomainError>()),
      );
      expect((await repo.pupils()).map((p) => p.id), ['p']);
      await expectLater(
        repo.savePlanningSync([], planningRosterRevisions(old, [first])),
        throwsA(isA<StaleRevision>()),
      );
      final added = await repo.savePupilDialog(mika, null);
      expect(added.name, 'Mika Muster');
    },
  );
  test(
    'Endgültiges Löschen anonymisiert die Kürzelreservierung und gemeinsamen Dateientscheidungen',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final saved = await repo.savePupilDialog(
        mila,
        null,
        materialProfile: buildMaterialProfile([], mila.id, year, 'MI', [
          'Früherer Name',
        ]),
      );
      await repo.savePupil(mika);
      final shared = decidePlanningPupils(
        file('$prefix/MI01.pdf'),
        [mila.id, mika.id],
        [mila.id, mika.id],
      );
      await repo.saveClassroomDocument(shared);
      await repo.savePupil(saved.copyWith(deleted: true, archived: true));
      await repo.purgeRetained(
        {'pupil:${mila.id}'},
        await repo.exportBackup(),
        now: DateTime.now().add(const Duration(days: 1000)),
      );
      final docs = await repo.classroomDocuments();
      final reserved = materialProfiles(docs, year).single;
      expect(reserved.strings('reserved'), ['MI']);
      expect(reserved.strings('pupilIds'), isEmpty);
      expect(reserved.strings('aliases'), isEmpty);
      final remaining = docs.firstWhere((d) => d.id == shared.id);
      expect(remaining.strings('pupilIds'), [mika.id]);
      expect(remaining.strings('planningDecisions'), [mika.id]);
      expect(
        () => buildMaterialProfile(docs, mika.id, year, 'MI', []),
        throwsA(isA<DomainError>()),
      );
    },
  );

  testWidgets(
    'Erstimport erlaubt auf schmalem Bildschirm die Sammelzuordnung eines neuen Kürzels',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = classroomMemory(), c = NotebookController(repo);
      await c.initialize();
      await c.savePupil(mila);
      await repo.saveClassroomDocuments([
        file('$prefix/2026-11-24/Mathe MI01.pdf', id: 'first'),
        file('$prefix/2026-11-24/Mathe MI02L.pdf', id: 'second'),
        file('$prefix/2026-11-24/Allgemein.pdf', id: 'shared'),
        file('$prefix/2026-11-24/Neues Blatt V01.pdf', id: 'new-pupil-file'),
      ]);
      await c.reload();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialLibraryPage(controller: c, externalView: 'files'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        final finder = find.text(label).last;
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap('Zuordnung prüfen');
      await tap('Nach Kürzel oder Schüler prüfen');
      await tap('Kürzel MI');
      await tap(mila.name);
      await tap('Mathe MI02L.pdf');
      await tap('Auswahl übernehmen (1)');
      expect(
        c.classroom.firstWhere((d) => d.id == 'first').strings('pupilIds'),
        [mila.id],
      );
      expect(
        c.classroom.firstWhere((d) => d.id == 'second').strings('pupilIds'),
        isEmpty,
      );
      expect(
        c.classroom.firstWhere((d) => d.id == 'shared').strings('pupilIds'),
        isEmpty,
      );
      expect(pupilProfile(c.classroom, mila.id, year)!.text('code'), 'MI');
      await tap('Nach Kürzel oder Schüler prüfen');
      await tap('Kürzel V');
      await tap('Neuen Schüler anlegen');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('pupil-material-code')),
            )
            .controller!
            .text,
        'V',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Val Beispiel',
      );
      await tester.pumpAndSettle();
      await tap('Hinzufügen');
      await tap('Auswahl übernehmen (1)');
      final added = c.pupils.firstWhere((p) => p.name == 'Val Beispiel');
      expect(pupilProfile(c.classroom, added.id, year)!.text('code'), 'V');
      expect(
        c.classroom
            .firstWhere((m) => m.id == 'new-pupil-file')
            .strings('pupilIds'),
        [added.id],
      );
      expect(find.text('Alle Zuordnungen sind geprüft.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
    },
  );

  testWidgets(
    'Frühere Entscheidungen und weitere Kürzel lassen sich einem bestehenden Schüler zuordnen',
    (tester) async {
      final repo = classroomMemory(), c = NotebookController(repo);
      await c.initialize();
      await repo.savePupilDialog(
        mila,
        null,
        materialProfile: buildMaterialProfile([], mila.id, year, 'M', []),
      );
      await repo.saveClassroomDocuments([
        decidePlanningPupils(file('$prefix/Material M08.pdf', id: 'skipped'), [
          mila.id,
        ], []),
        file('$prefix/Material V01.pdf', id: 'other-code'),
      ]);
      await c.reload();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialLibraryPage(controller: c, externalView: 'files'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String value) async {
        final f = find.text(value).last;
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tap('Zuordnung prüfen');
      await tap('Nach Kürzel oder Schüler prüfen');
      await tap('Kürzel V');
      await tap(mila.name);
      await tap('Material V01.pdf');
      await tap('Auswahl übernehmen (1)');
      expect(pupilProfile(c.classroom, mila.id, year)!.text('code'), 'M');
      expect(
        c.classroom.firstWhere((d) => d.id == 'other-code').strings('pupilIds'),
        [mila.id],
      );
      expect(find.text('Alle Zuordnungen sind geprüft.'), findsOneWidget);
      await tester.tap(find.byTooltip('Frühere Entscheidungen prüfen'));
      await tester.pumpAndSettle();
      await tap('Nach Kürzel oder Schüler prüfen');
      await tap(mila.name);
      expect(find.text('Auswahl übernehmen (0)'), findsOneWidget);
      await tap('Material M08.pdf');
      await tap('Auswahl übernehmen (1)');
      expect(
        c.classroom.firstWhere((d) => d.id == 'skipped').strings('pupilIds'),
        [mila.id],
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
    },
  );

  testWidgets(
    'Schülereditor behält Vorschlag optional und bestätigt ausschließlich ausgewählte Bestandsdateien',
    (tester) async {
      final repo = classroomMemory(), c = NotebookController(repo);
      await c.initialize();
      final y = yearOfDay(DateTime.now());
      await c.repository.saveClassroomDocument(
        file('Planung/$y/KW48/Material MI01.pdf'),
      );
      await c.repository.savePupilDialog(
        mika,
        null,
        materialProfile: buildMaterialProfile([], 'q', y, 'M', []),
      );
      await c.reload();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => PupilEditor(controller: c),
                ),
                child: const Text('Neu'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Neu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Mila Beispiel');
      await tester.pumpAndSettle();
      expect(find.text('Kürzel MI übernehmen'), findsOneWidget);
      await tester.tap(find.text('Kürzel MI übernehmen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.text('Vorhandene Dateien für Mila Beispiel'), findsOneWidget);
      await tester.tap(find.text('Auswahl übernehmen (1)'));
      await tester.pumpAndSettle();
      final pupil = c.pupils.firstWhere((p) => p.name == 'Mila Beispiel');
      expect(pupilProfile(c.classroom, pupil.id, y)!.text('code'), 'MI');
      expect(
        c.classroom.firstWhere((d) => d.id == 'file').strings('pupilIds'),
        [pupil.id],
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
    },
  );
  testWidgets('Bereitgelegt zeigt Wochenunterlagen auch ohne Unterrichtstag', (
    tester,
  ) async {
    final repo = classroomMemory(), c = NotebookController(repo);
    await c.initialize();
    await c.saveClassroom(file('$prefix/FLEX Wochenübersicht KW48.docx'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaterialLibraryPage(controller: c, externalView: 'prepared'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wochenmaterial'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('KW 48 ·'));
    await tester.pumpAndSettle();
    expect(find.text('FLEX Wochenübersicht KW48.docx'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await repo.close();
  });
}
