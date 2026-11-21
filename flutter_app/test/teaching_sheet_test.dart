import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/lesson_flow.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/planning_import.dart';
import 'package:flex_notizbuch/domain/teaching_sheet.dart';
import 'package:flex_notizbuch/services/material_sync.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/services/teaching_exchange.dart';
import 'package:flex_notizbuch/services/teaching_sheet_reader.dart';
import 'classroom_test.dart' show classroomMemory, lesson;
import 'material_workspace_test.dart' show docx, word, MemoryMaterialFiles;

String table(List<List<String>> rows) =>
    '<w:tbl>${rows.map((r) => '<w:tr>${r.map((v) => '<w:tc><w:p><w:r><w:t>${v.replaceAll('&', '&amp;')}</w:t></w:r></w:p></w:tc>').join()}</w:tr>').join()}</w:tbl>';
Uint8List example({
  String goal = 'Begründen',
  String assignment = 'Muster ordnen',
}) => docx(
  word(
    table([
          [
            'Phase',
            'Zeit',
            'Auftrag',
            'Ziel',
            'Fach & Dauer',
            'Material',
            'Zuständig',
          ],
          [
            'Beginn',
            '08:00–08:10',
            'Fragen sammeln',
            'Einstimmen',
            '10 Min.',
            '',
            '',
          ],
          [
            'Lernen 1',
            '08:10–08:35',
            assignment,
            goal,
            'Mathematik 25 Min.',
            'Q01',
            '',
          ],
          ['Pause', '08:35–08:40', 'Durchatmen', '', '5 Min.', '', ''],
          [
            'Lernen 2',
            '08:40–08:50',
            'Muster legen',
            goal,
            'Mathematik 10 Min.',
            '',
            '',
          ],
        ]) +
        table([
          ['Phase', 'Schüler', 'Aufgabe oder Hilfe', 'Material'],
          ['Lernen', 'Q/R', 'Beispielkarten nehmen', 'Q01–Q03'],
          ['Alle Phasen', 'Alle', 'Bei Bedarf Sitzplatz wechseln', ''],
          ['Lernen', 'Unbekannt', 'Hilfe für eine Person', ''],
        ]),
  ),
);
final sheetDate = '2026-11-23';
final folder = ClassroomDocument.create(ClassroomKind.folder, 'Planung', {
  'driveId': 'drive',
  'itemId': 'folder',
  'accountDrive': 'drive',
  'incoming': true,
  'planningFolder': true,
  'folderPath': 'Planung/2026-27/KW48',
}, id: 'rule');
ClassroomDocument source(
  String id,
  String name, {
  String day = '',
  bool weekly = false,
  Uint8List? bytes,
}) {
  final path = 'Planung/2026-27/KW48/$name';
  final m = ClassroomDocument.create(ClassroomKind.material, name, {
    'extension': name.split('.').last.toLowerCase(),
    'driveId': 'drive',
    'itemId': id,
    'cloudRule': folder.id,
    'name': name,
    'remoteName': name,
    'sourcePath': path,
    'remoteEtag': 'v1',
    'planning': {
      ...classifyPlanningFile(path),
      if (day.isNotEmpty) 'day': day,
      if (weekly) 'use': 'weekPlan',
    },
  }, id: id);
  return bytes == null
      ? m
      : m.patch({
          'planSheet': {
            'stamp': sourceStamp(m),
            'drive': 'drive',
            'item': id,
            'rows': readTeachingRows(bytes),
          },
        });
}

class _Drive extends OneDriveClient {
  final items = <String, Json>{}, blobs = <String, Uint8List>{};
  int reads = 0;
  void set(String id, String name, Uint8List bytes, String etag) {
    blobs[id] = bytes;
    items[id] = {'id': id, 'name': name, 'size': bytes.length, 'eTag': etag};
  }

  @override
  Future<Json> graph(String path, {bool retried = false}) async {
    if (path == '/me/drive') return {'id': 'drive'};
    if (path == '/me/drive/special/approot') {
      return {
        'id': 'app',
        'parentReference': {'driveId': 'drive'},
      };
    }
    for (final r in items.values) {
      if (path == childPath('drive', 'app', r['name'])) return r;
    }
    throw const OneDriveResponseError(404, 'fehlt');
  }

  @override
  Future<List<Json>> children({String? drive, String? folder}) async =>
      items.values.where((r) => r['id'] != 'published').toList();
  @override
  Future<Json> item(String drive, String id) async => items[id]!;
  @override
  Future<Uint8List> download(Json item, {int maxBytes = 20000000}) async {
    reads++;
    return blobs[item['id']]!;
  }

  @override
  Future<Json> uploadNew(
    String drive,
    String parent,
    String name,
    Uint8List bytes,
  ) async {
    if (items.containsKey('published')) {
      throw const OneDriveResponseError(409, 'Konflikt');
    }
    set('published', name, bytes, 'shared-v1');
    return items['published']!;
  }

  @override
  Future<Json> replaceVersion(
    String drive,
    String id,
    String etag,
    Uint8List bytes,
  ) async {
    if (items[id]?['eTag'] != etag) {
      throw const OneDriveResponseError(412, 'Konflikt');
    }
    set(id, items[id]!['name'], bytes, 'shared-v2');
    return items[id]!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Tagesphasen, Gruppenhilfen und nummerierte Dateien bleiben getrennt und offline ausführbar',
    () {
      final m = source(
        'daily',
        'Tagesplanung $sheetDate.docx',
        day: sheetDate,
        bytes: example(),
      );
      const pupils = [
        Pupil(id: 'p', name: 'Kind Eins'),
        Pupil(id: 'r', name: 'Kind Zwei'),
      ];
      final year = teachingPlan(m)['year'] as String;
      final docs = [
        m,
        folder,
        for (final p in pupils)
          buildMaterialProfile([], p.id, year, p.id == 'p' ? 'Q' : 'R', []),
        for (final code in ['Q01', 'Q02', 'Q03', 'Q01L'])
          source(code, 'Karten $code.pdf', day: sheetDate),
      ];
      final imported = buildTeachingFlow(m, docs, pupils);
      expect(imported.phases.map((p) => p.minutes), [10, 25, 5, 10]);
      expect(imported.issues, contains('Schülerzuordnung prüfen · Unbekannt'));
      final shared = lessonFlowFor(docs, sheetDate, pupils: pupils);
      expect(shared.map('flow')['sourceId'], m.id);
      final phases = lessonPhases(shared);
      expect(phases[1].body, contains('Ziel · Begründen'));
      expect(phases[1].materialIds, ['Q01']);
      expect(
        phases.every((p) => p.body.contains('Sitzplatz wechseln')),
        isTrue,
      );
      final individual = lessonPhases(
        lessonFlowFor(
          docs,
          sheetDate,
          pupilId: 'p',
          pupils: pupils,
          sharedFlow: shared,
        ),
      );
      expect(individual[1].body, contains('Beispielkarten'));
      expect(individual[3].body, contains('Beispielkarten'));
      expect(individual[1].materialIds.toSet(), {'Q01', 'Q02', 'Q03'});
      expect(individual.first.body, isNot(contains('Beispielkarten')));
      final second = source(
        'other',
        'Andere Tagesplanung $sheetDate.docx',
        day: sheetDate,
        bytes: example(),
      );
      expect(
        lessonPhases(lessonFlowFor([...docs, second], sheetDate)),
        isEmpty,
      );
      final block = lesson(
        date: sheetDate,
      ).patch({'start': '08:35', 'end': '08:50'});
      final occurrence = lessonOccurrences(
        [block],
        sheetDate,
        sheetDate,
      ).single;
      expect(
        lessonPhases(
          lessonFlowFor([...docs, block], sheetDate, lesson: occurrence),
        ).map((p) => p.title),
        ['Pause', 'Lernen 2'],
      );
      final parallel = lesson(date: sheetDate);
      expect(
        lessonPhases(
          lessonFlowFor(
            [...docs, block, parallel],
            sheetDate,
            lesson: occurrence,
          ),
        ),
        isEmpty,
      );
    },
  );
  test(
    'Wochenziele und Tagesvorbereitung richten sich nach Wochentag, Substanz ohne Zeit bleibt prüfbar',
    () {
      final m = source(
        'week',
        'Wochenübersicht 2026 KW48.docx',
        weekly: true,
        bytes: docx(
          word(
            table([
                  [
                    'Fachbereiche',
                    'Wochenziele',
                    'Geplante Einheiten und Fachzeiten',
                  ],
                  ['Sachunterricht', 'Beobachtungen beschreiben', 'Mo–Fr'],
                ]) +
                table([
                  ['Tag', 'Schwerpunkte', 'Vorbereitung'],
                  ['Mo/Mi', 'Wetter messen', 'Skalen'],
                  ['Di', 'Daten auswerten', 'Tabelle'],
                ]) +
                table([
                  ['Offene Frage', 'Wind?'],
                ]),
          ),
        ),
      );
      expect(weeklyContext(m, sheetDate).map((r) => r['type']), [
        'goal',
        'week',
      ]);
      expect(weeklyContext(m, '2026-11-24').last['task'], 'Daten auswerten');
      expect(teachingRows(m).last['type'], 'review');
      expect(lessonFlowFor([m], sheetDate).map('flow')['sourceId'], isNull);
      expect(sheetTime('25:00–26:00'), isNull);
    },
  );
  test(
    'Neue Wordversion bewahrt eigene Bearbeitung, Timer und erledigte Phasen',
    () {
      final m = source(
        'daily',
        'Tagesplanung $sheetDate.docx',
        day: sheetDate,
        bytes: example(),
      );
      final saved = lessonFlowFor([m], sheetDate);
      final old = lessonPhases(saved);
      var run = withLessonPhases(saved, [
        old[0].patch({'status': 'done'}),
        old[1],
        old[2].patch({'body': 'Eigener Hinweis'}),
        old[3],
      ]);
      run = activateLessonPhase(
        run,
        old[1].id,
        DateTime.utc(2026, 11, 23, 8, 10),
      );
      final other = source(
        'daily',
        'Tagesplanung $sheetDate.docx',
        day: sheetDate,
        bytes: example(goal: 'Neues Ziel', assignment: 'Geänderter Auftrag'),
      );
      final next = lessonPhases(
        reconcileTeachingFlow(run, buildTeachingFlow(other, [other], [])),
      );
      expect(next.map((p) => p.id), old.map((p) => p.id));
      expect(next.first.status, 'done');
      expect(next[1].running, isTrue);
      expect(next[1].body, isNot(contains('Geänderter Auftrag')));
      expect(next[2].body, 'Eigener Hinweis');
      expect(next[3].body, contains('Neues Ziel'));
    },
  );
  test(
    'OneDrive-Abgleich liest DOCX einmal, bewahrt Quelle und synchronisiert ausschließlich Planfelder mit Versionsprüfung',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final drive = _Drive(), files = MemoryMaterialFiles();
      await repo.saveClassroomDocument(folder);
      drive.set('word', 'FLEX Tagesplanung $sheetDate.docx', example(), 'v1');
      final sync = MaterialSync(repo, drive, files);
      expect((await sync.run()).errors, isEmpty);
      final all = await repo.classroomDocuments(),
          m = all.firstWhere((d) => d.kind == ClassroomKind.material);
      expect(teachingRows(m).where((r) => r['type'] == 'phase'), hasLength(4));
      expect(await files.exists(m.text('localKey')), isTrue);
      final reads = drive.reads;
      expect((await sync.run()).errors, isEmpty);
      expect(drive.reads, reads);
      final change = teachingRows(m).first;
      final edited = await repo.saveClassroomDocument(
        m.patch({
          'planEdits': {
            'dirty': true,
            'changes': [
              {'id': change['id'], 'duration': '15'},
            ],
          },
        }),
      );
      final exchange = await TeachingExchange.open(drive, 'drive');
      final published = await exchange.publish(repo, edited, folder);
      final remote = jsonDecode(utf8.decode(drive.blobs['published']!)) as Map;
      expect(remote.keys.toSet(), {'format', 'version', 'binding', 'edits'});
      expect(remote['edits']['changes'], [
        {'id': change['id'], 'duration': '15'},
      ]);
      final replica = published.patch({
        'planEdits': {'changes': <Json>[]},
      });
      final preview = await exchange.preview(replica, folder);
      expect(teachingRows(preview).first['duration'], '15');
      drive.items['published']!['eTag'] = 'other-device';
      expect(
        () => exchange.publish(repo, published, folder),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => TeachingExchange.open(drive, 'other-account'),
        throwsA(isA<DomainError>()),
      );
      final changed = example(goal: 'Anderes Lernziel');
      drive.set('word', m.text('remoteName'), changed, 'v2');
      final result = await sync.run();
      expect(result.errors, isEmpty);
      final after = (await repo.classroomDocuments()).singleWhere(
        (d) => d.id == m.id,
      );
      expect(teachingRows(after).first['duration'], '15');
      expect(after.text('etag'), 'v2');
      expect(
        teachingRows(after).any((r) => r['goal'] == 'Anderes Lernziel'),
        isTrue,
      );
    },
  );
}
