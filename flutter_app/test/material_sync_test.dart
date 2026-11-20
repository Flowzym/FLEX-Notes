import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/drive_rules.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/services/material_sync.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show MemoryMaterialFiles;

class _Drive extends OneDriveClient {
  final tree = <String, List<Json>>{'a': [], 'b': [], 'sub': []};
  final blobs = <String, Uint8List>{};
  String account = 'drive';
  bool loseReply = false;
  @override
  Future<Json> graph(String path, {bool retried = false}) async {
    if (path == '/me/drive') return {'id': account};
    if (path == '/me/drive/special/approot') {
      return {
        'id': 'app',
        'parentReference': {'driveId': account},
      };
    }
    for (final list in tree.entries) {
      for (final item in list.value) {
        if (childPath('drive', list.key, item['name'] as String) == path) {
          return item;
        }
      }
    }
    throw const OneDriveResponseError(404, 'fehlt');
  }

  @override
  Future<List<Json>> children({String? drive, String? folder}) async =>
      tree[folder]!;
  @override
  Future<Json> item(String drive, String id) async => {
    'id': id,
    'parentReference': {'id': 'app', 'driveId': drive},
  };
  @override
  Future<Json> uploadNew(
    String drive,
    String parent,
    String name,
    Uint8List bytes,
  ) async {
    if (blobs.containsKey(name)) {
      throw const OneDriveResponseError(409, 'belegt');
    }
    blobs[name] = bytes;
    final item = <String, dynamic>{
      'id': 'scan',
      'name': name,
      'size': bytes.length,
      'url': '',
      'eTag': 'v1',
    };
    tree[parent]!.add(item);
    if (loseReply) {
      loseReply = false;
      throw const DomainError('Antwort unterbrochen');
    }
    return item;
  }

  @override
  Future<Uint8List> download(Json item, {int maxBytes = 20000000}) async =>
      blobs[item['name']]!;
}

ClassroomDocument rule(String id, String pupil, {String purpose = 'all'}) =>
    ClassroomDocument.create(ClassroomKind.folder, id, {
      'driveId': 'drive',
      'itemId': id,
      'accountDrive': 'drive',
      'personal': true,
      'pupilIds': [pupil],
      'incoming': true,
      'outgoing': true,
      'appRoot': 'app',
      'purpose': purpose,
      'subject': '',
    }, id: 'rule-$id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Ordnergrenzen, Kontowechsel, Umbenennung, Schülerwechsel und lokale Einsatzdaten',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      final drive = _Drive(), files = MemoryMaterialFiles();
      addTearDown(repo.close);
      addTearDown(drive.dispose);
      for (final id in ['p', 'q']) {
        await repo.savePupil(Pupil(id: id, name: id));
      }
      await repo.saveClassroomDocuments([rule('a', 'p'), rule('sub', 'q')]);
      drive.tree['a'] = [
        {'id': 'sub', 'name': 'Unterordner', 'folder': {}},
        {'id': 'doc', 'name': 'Arbeitsblatt.docx'},
      ];
      drive.tree['sub'] = [
        {'id': 'photo', 'name': 'Tafel.JPEG'},
      ];
      Future<MaterialSyncResult> sync() =>
          MaterialSync(repo, drive, files).run();
      final first = await sync();
      expect(first.errors, isEmpty);
      Future<List<ClassroomDocument>> materials() async =>
          (await repo.classroomDocuments())
              .where((d) => d.kind == ClassroomKind.material)
              .toList();
      var docs = await materials();
      expect(docs, hasLength(2));
      final doc = docs.singleWhere((d) => d.text('itemId') == 'doc');
      expect(doc.strings('pupilIds'), ['p']);
      expect(
        docs
            .singleWhere((d) => d.text('extension') == 'jpg')
            .strings('pupilIds'),
        ['q'],
      );
      await repo.saveClassroomDocument(
        planPupilMaterial(doc, 'p', '2026-11-23'),
      );
      drive.tree['a']![1]['name'] = 'Umbenannt.docx';
      await sync();
      var current = (await materials()).singleWhere((d) => d.id == doc.id);
      expect(current.title, 'Umbenannt.docx');
      expect(pupilMaterialDates(current, 'p'), ['2026-11-23']);
      drive.tree['sub']!.add(drive.tree['a']!.removeLast());
      await sync();
      current = (await materials()).singleWhere((d) => d.id == doc.id);
      expect(current.strings('pupilIds'), ['p']);
      expect(current.text('cloudReview'), 'rule-sub');
      expect(current.flag('sourceMissing'), isFalse);
      drive.account = 'other';
      expect((await sync()).paused, 2);
      expect((await materials()).length, 2);
      drive.account = 'drive';
      drive.tree['sub']!.clear();
      await sync();
      expect(
        (await materials())
            .singleWhere((d) => d.text('itemId') == 'photo')
            .flag('sourceMissing'),
        isTrue,
      );
    },
  );
  test(
    'Unterbrochene Scanbestätigung wird ohne zweites PDF und ohne zweiten Eintrag aufgelöst',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      final drive = _Drive(), files = MemoryMaterialFiles();
      addTearDown(repo.close);
      addTearDown(drive.dispose);
      await repo.savePupil(const Pupil(id: 'p', name: 'Beispiel'));
      final f = await repo.saveClassroomDocument(
        rule('a', 'p', purpose: 'homework'),
      );
      final data = <String, dynamic>{
        'pupilIds': ['p'],
        'tags': ['Hausübung'],
        'links': <Json>[],
      };
      final bytes = Uint8List.fromList(utf8.encode('%PDF-1.4 fertiger Scan'));
      await files.write('key1', bytes);
      final doc = await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Heft', {
          ...data,
          'scan': true,
          'localKey': 'key1',
          'extension': 'pdf',
          'name': 'Heft.pdf',
          'cloudUpload': scanUploadJob(data, 'key1', 'Heft.pdf', [f]),
        }),
      );
      drive.loseReply = true;
      expect((await MaterialSync(repo, drive, files).run()).errors, isNotEmpty);
      Future<ClassroomDocument> scan() async =>
          (await repo.classroomDocuments())
              .where((d) => d.kind == ClassroomKind.material)
              .single;
      expect((await scan()).map('cloudUpload')['state'], 'pending');
      expect((await scan()).id, doc.id);
      expect((await MaterialSync(repo, drive, files).run()).errors, isEmpty);
      expect((await MaterialSync(repo, drive, files).run()).errors, isEmpty);
      expect(drive.blobs.length, 1);
      expect((await scan()).map('cloudUpload')['state'], 'sent');
      expect((await scan()).strings('pupilIds'), ['p']);
      expect(await files.read('key1'), bytes);
    },
  );
  test(
    'Gleichnamige fremde Datei wird auch bei derselben Größe nicht überschrieben',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final drive = _Drive(), files = MemoryMaterialFiles();
      addTearDown(drive.dispose);
      await repo.savePupil(const Pupil(id: 'p', name: 'Beispiel'));
      final f = await repo.saveClassroomDocument(rule('a', 'p'));
      final data = <String, dynamic>{
        'pupilIds': ['p'],
      };
      final job = scanUploadJob(data, 'key2', 'Heft.pdf', [f]),
          name = job['name'] as String;
      final mine = Uint8List.fromList(utf8.encode('%PDF-1.4 eigene')),
          other = Uint8List.fromList(utf8.encode('%PDF-1.4 fremde'));
      await files.write('key2', mine);
      await drive.uploadNew('drive', 'a', name, other);
      await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Heft', {
          ...data,
          'scan': true,
          'localKey': 'key2',
          'extension': 'pdf',
          'cloudUpload': job,
        }),
      );
      final result = await MaterialSync(repo, drive, files).run();
      expect(result.errors, isNotEmpty);
      expect(drive.blobs[name], other);
      final saved = (await repo.classroomDocuments()).singleWhere(
        (m) => m.kind == ClassroomKind.material,
      );
      expect(saved.map('cloudUpload')['state'], 'review');
      expect(await files.read('key2'), mine);
    },
  );

  test(
    'Mehrere Personen, konkurrierende Regeln und reine Klassenordner benötigen eine Zielwahl',
    () {
      final f = rule('a', 'p'), g = rule('b', 'p');
      expect(
        scanUploadJob(
          {
            'pupilIds': ['p', 'q'],
          },
          'k',
          'A.pdf',
          [f],
        )['state'],
        'review',
      );
      expect(
        scanUploadJob(
          {
            'pupilIds': ['p'],
          },
          'k',
          'A.pdf',
          [f, g],
        )['state'],
        'review',
      );
      expect(
        scanUploadJob(
          {
            'pupilIds': ['p'],
          },
          'k',
          'A.pdf',
          [
            f.patch({'personal': false, 'pupilIds': []}),
          ],
        )['state'],
        'review',
      );
    },
  );
}
