import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/services/material_files.dart';
import 'package:flex_notizbuch/ui/material_library.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/services/docx_preview.dart';
import 'package:flex_notizbuch/services/material_index.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'classroom_test.dart' show classroomMemory, lesson;

ClassroomDocument material(String title, {Json fields = const {}}) =>
    ClassroomDocument.create(ClassroomKind.material, title, {
      'extension': 'pdf',
      'url': 'https://example.org/document.pdf',
      ...fields,
    });

class FolderDrive extends OneDriveClient {
  FolderDrive(this.tree);
  final Map<String, List<Json>> tree;
  final requested = <String>[];
  @override
  Future<List<Json>> children({String? drive, String? folder}) async {
    requested.add(folder!);
    if (!tree.containsKey(folder)) throw StateError('Network interrupted');
    return tree[folder]!;
  }
}

class MemoryMaterialFiles implements MaterialFiles {
  final values = <String, Uint8List>{};
  @override
  Future<void> write(String key, Uint8List bytes) async {
    values[key] = bytes;
  }

  @override
  Future<Uint8List> read(String key) async => values[key]!;
  @override
  Future<bool> exists(String key) async => values.containsKey(key);
  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class DownloadDrive extends OneDriveClient {
  @override
  Future<Json> item(String drive, String id) async => {
    'eTag': 'new',
    'webUrl': 'https://example.org/file',
    'lastModifiedDateTime': '2026-11-06T10:00:00Z',
  };
  @override
  Future<Uint8List> download(Json item, {int maxBytes = 20000000}) async =>
      Uint8List.fromList(utf8.encode('%PDF-1.4 new'));
}

Uint8List docx(String body) {
  final zip = Archive();
  for (final entry in {
    '[Content_Types].xml': '<Types/>',
    'word/document.xml': body,
  }.entries) {
    final bytes = utf8.encode(entry.value);
    zip.add(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

String word(String body) =>
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  setUp(() async {
    repo = classroomMemory();
    await repo.initialize();
  });
  tearDown(() => repo.close());

  test(
    'preparing files preserves order, deduplicates and isolates dates',
    () async {
      final a = material('A'), b = material('B');
      await repo.saveClassroomDocuments([a, b]);
      final first = await repo.saveClassroomDocument(
        prepareMaterials(await repo.classroomDocuments(), '2026-11-09', [
          b.id,
          a.id,
          b.id,
        ]),
      );
      await repo.saveClassroomDocument(
        prepareMaterials(await repo.classroomDocuments(), '2026-11-09', [a.id]),
      );
      final next = await repo.saveClassroomDocument(
        prepareMaterials(await repo.classroomDocuments(), '2026-11-10', [a.id]),
      );
      expect(next.id, isNot(first.id));
      final docs = await repo.classroomDocuments();
      expect(preparationFor(docs, '2026-11-09').strings('materialIds'), [
        b.id,
        a.id,
      ]);
      expect(resolveMaterials(docs, [b.id, a.id]).map((m) => m.title), [
        'B',
        'A',
      ]);
      expect(docs.where((d) => d.kind == ClassroomKind.material).length, 2);
    },
  );

  test(
    'unlinking package/day/pupil never deletes its files; trash restore retains references',
    () async {
      await repo.savePupil(const Pupil(id: 'p', name: 'Kind'));
      final m = await repo.saveClassroomDocument(
        material(
          'Plan',
          fields: {
            'pupilIds': ['p'],
          },
        ),
      );
      final package = await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.materialSet, 'Set', {
          'materialIds': [m.id],
        }),
      );
      final day = await repo.saveClassroomDocument(
        prepareMaterials(await repo.classroomDocuments(), '2026-11-09', [m.id]),
      );
      await repo.saveClassroomDocuments([
        package.patch({'deleted': true}),
        day.patch({'materialIds': <String>[]}),
        m.patch({'pupilIds': <String>[]}),
      ]);
      final current = (await repo.classroomDocuments()).firstWhere(
        (d) => d.id == m.id,
      );
      expect(current.deleted, isFalse);
      final trashed = await repo.saveClassroomDocument(
        current.patch({'deleted': true}),
      );
      expect(
        resolveMaterials(
          await repo.classroomDocuments(),
          package.strings('materialIds'),
        ),
        isEmpty,
      );
      await repo.saveClassroomDocument(trashed.patch({'deleted': false}));
      expect(
        resolveMaterials(
          await repo.classroomDocuments(),
          package.strings('materialIds'),
        ).single.id,
        m.id,
      );
    },
  );

  test(
    'plan links, metadata, day order and revisions survive backup and mapped merge',
    () async {
      await repo.savePupil(const Pupil(id: 'remote', name: 'Kind'));
      final m = material(
        'Wochenplan',
        fields: {
          'pupilIds': ['remote'],
          'tags': ['Brüche', 'Üben'],
          'favorite': true,
          'documentType': 'weekPlan',
          'audience': 'pupils',
        },
      );
      final l = lesson(materials: [m.id]);
      final p = ClassroomDocument.create(ClassroomKind.plan, 'Brüche', {
        'materialIds': [m.id],
        'lessonIds': [l.id],
        'pupilIds': ['remote'],
        'date': '2026-11-02',
        'endDate': '2026-11-06',
        'status': 'started',
        'followUp': 'Weiter üben',
      });
      await repo.saveClassroomDocuments([
        m,
        l,
        p,
        prepareMaterials([], '2026-11-02', [m.id]),
      ]);
      final backup = await repo.exportBackup();
      final restored = classroomMemory();
      await restored.initialize();
      addTearDown(restored.close);
      await restored.restoreBackup(backup);
      expect(
        (await restored.classroomDocuments())
            .firstWhere((d) => d.id == p.id)
            .text('followUp'),
        'Weiter üben',
      );
      final target = classroomMemory();
      await target.initialize();
      addTearDown(target.close);
      await target.savePupil(const Pupil(id: 'local', name: 'Kind'));
      await target.applyBackupMerge(
        await target.prepareBackupMerge(
          backup,
          pupilLinks: {'remote': 'local'},
          catalogs: false,
        ),
        {},
      );
      final docs = await target.classroomDocuments();
      expect(docs.firstWhere((d) => d.id == m.id).strings('pupilIds'), [
        'local',
      ]);
      expect(docs.firstWhere((d) => d.id == p.id).strings('pupilIds'), [
        'local',
      ]);
      expect(docs.firstWhere((d) => d.id == p.id).strings('lessonIds'), [l.id]);
      expect(
        (await target.prepareBackupMerge(
          backup,
          pupilLinks: {'remote': 'local'},
          catalogs: false,
        )).conflicts,
        0,
      );
    },
  );

  test(
    'invalid references and stale batch roll back the whole selection',
    () async {
      final a = await repo.saveClassroomDocument(material('A'));
      final b = await repo.saveClassroomDocument(material('B'));
      await expectLater(
        repo.saveClassroomDocuments([
          a.patch({'favorite': true}),
          b.patch({
            'pupilIds': ['missing'],
          }),
        ]),
        throwsA(isA<DomainError>()),
      );
      expect(
        (await repo.classroomDocuments()).every((d) => !d.flag('favorite')),
        isTrue,
      );
      await repo.saveClassroomDocument(b.patch({'favorite': true}));
      await expectLater(
        repo.saveClassroomDocuments([
          a.patch({'favorite': true}),
          b.patch({'topic': 'Stale'}),
        ]),
        throwsA(isA<StaleRevision>()),
      );
      expect(
        (await repo.classroomDocuments())
            .firstWhere((d) => d.id == a.id)
            .flag('favorite'),
        isFalse,
      );
      await expectLater(
        repo.saveClassroomDocument(
          ClassroomDocument.create(ClassroomKind.plan, 'Plan', {
            'lessonIds': ['missing'],
          }),
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );

  test('plan and package drafts survive restore and save atomically', () async {
    for (final kind in [ClassroomKind.plan, ClassroomKind.materialSet]) {
      final doc = ClassroomDocument.create(kind, 'Entwurf', {
        'materialIds': <String>[],
      });
      final draft = await repo.saveDialogDraft(
        DialogDraft(
          id: newId(),
          type: 'classroom',
          ownerId: doc.id,
          data: doc.toJson(),
          updatedAtUtc: utcNow(),
        ),
      );
      final copy = classroomMemory();
      await copy.initialize();
      addTearDown(copy.close);
      await copy.restoreBackup(await repo.exportBackup());
      expect((await copy.dialogDrafts()).any((d) => d.id == draft.id), isTrue);
      await repo.saveClassroomDocument(doc, draft: draft);
      expect((await repo.dialogDrafts()).any((d) => d.id == draft.id), isFalse);
    }
  });

  test(
    'suggestions use actual moved lessons, plans and week but exclude prepared/trash',
    () {
      final a = material('A'),
          b = material('B'),
          c = material('Week', fields: {'week': '2026-11-04'}),
          gone = material('Gone').patch({'deleted': true});
      final l = lesson(
        materials: [a.id],
        exceptions: [
          {'date': '2026-11-02', 'cancelled': false, 'movedTo': '2026-11-03'},
        ],
      );
      final p = ClassroomDocument.create(ClassroomKind.plan, 'Plan', {
        'lessonIds': [l.id],
        'materialIds': [b.id, gone.id],
      });
      final docs = [
        a,
        b,
        c,
        gone,
        l,
        p,
        prepareMaterials([], '2026-11-03', [c.id]),
      ];
      expect(suggestedMaterials(docs, '2026-11-02').map((d) => d.id), [c.id]);
      expect(suggestedMaterials(docs, '2026-11-03').map((d) => d.id), [
        a.id,
        b.id,
      ]);
    },
  );

  test(
    'dated plans apply only inside their period and only to linked lesson details',
    () {
      final p = ClassroomDocument.create(ClassroomKind.plan, 'Plan', {
        'date': '2026-11-02',
        'endDate': '2026-11-06',
        'lessonIds': ['lesson'],
      });
      expect(planOnDay(p, '2026-11-03'), isTrue);
      expect(planOnDay(p, '2026-11-03', lessonId: 'lesson'), isTrue);
      expect(planOnDay(p, '2026-11-10', lessonId: 'lesson'), isFalse);
      expect(planOnDay(p, '2026-11-03', lessonId: 'other'), isFalse);
    },
  );

  test('metadata validation and multiword pupil-aware search', () {
    final d = material(
      'English',
      fields: {
        'tags': ['Past tense'],
        'pupilIds': ['p'],
        'documentType': 'worksheet',
      },
    );
    expect(
      materialMatches(
        d,
        'kind past',
        pupils: [const Pupil(id: 'p', name: 'Kind')],
      ),
      isTrue,
    );
    expect(
      materialMatches(
        d,
        'kind fractions',
        pupils: [const Pupil(id: 'p', name: 'Kind')],
      ),
      isFalse,
    );
    expect(
      () => d.patch({
        'pupilIds': ['p', 'p'],
      }),
      throwsA(isA<DomainError>()),
    );
    expect(
      () => d.patch({'documentType': 'invented'}),
      throwsA(isA<DomainError>()),
    );
    expect(
      () => ClassroomDocument.create(ClassroomKind.plan, 'Plan', {
        'date': '2026-11-06',
        'endDate': '2026-11-05',
      }),
      throwsA(isA<DomainError>()),
    );
    expect(suggestMaterialMetadata('Name Lösung.docx')['audience'], 'teacher');
  });

  final folder = ClassroomDocument.create(ClassroomKind.folder, 'FLEX', {
    'driveId': 'd',
    'itemId': 'root',
  });
  Json file(String id, String name) => {
    'id': id,
    'name': name,
    'webUrl': 'https://example.org/$id',
    'size': 20,
    'lastModifiedDateTime': '2026-11-06T10:00:00Z',
  };
  test(
    'folder scan is recursive, stable on rename, preserves edits/trash/cache timestamp',
    () async {
      final drive = FolderDrive({
        'root': [
          {'id': 'sub', 'name': 'Unterricht', 'folder': {}},
          file('ignored', 'image.png'),
        ],
        'sub': [
          file('f', 'Arbeitsblatt.pdf'),
          {'id': 'root', 'name': 'cycle', 'folder': {}},
        ],
      });
      addTearDown(drive.dispose);
      final first = (await scanMaterialFolder(drive, folder, [])).single;
      final saved = await repo.saveClassroomDocument(
        first.patch({
          'title': 'Eigener Titel',
          'subject': 'Mathe',
          'favorite': true,
          'localKey': 'cache',
          'etag': 'old',
          'sourceModifiedAt': '2026-10-01T00:00:00Z',
          'deleted': true,
        }),
      );
      drive.tree['sub'] = [file('f', 'Umbenannt.pdf')];
      final second = (await scanMaterialFolder(drive, folder, [saved])).single;
      expect(second.id, saved.id);
      expect(second.title, 'Eigener Titel');
      expect(second.text('name'), 'Umbenannt.pdf');
      expect(second.flag('favorite'), isTrue);
      expect(second.deleted, isTrue);
      expect(second.text('etag'), 'old');
      expect(second.text('sourceModifiedAt'), '2026-10-01T00:00:00Z');
      expect(second.text('sourcePath'), 'FLEX/Unterricht/Umbenannt.pdf');
    },
  );
  test(
    'folder scan cancellation, limits and network failures never save partial index',
    () async {
      final drive = FolderDrive({
        'root': [file('a', 'a.pdf'), file('b', 'b.docx')],
      });
      addTearDown(drive.dispose);
      await expectLater(
        scanMaterialFolder(drive, folder, [], maxFiles: 1),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        scanMaterialFolder(drive, folder, [], cancelled: () => true),
        throwsA(isA<DomainError>()),
      );
      drive.tree['root'] = [
        {'id': 'missing', 'name': 'Missing', 'folder': {}},
      ];
      await expectLater(
        scanMaterialFolder(drive, folder, []),
        throwsStateError,
      );
      expect(await repo.classroomDocuments(), isEmpty);
    },
  );

  test(
    'stale offline refresh removes only newly staged bytes and preserves old copy',
    () async {
      final c = NotebookController(repo);
      await c.initialize();
      addTearDown(c.dispose);
      final old = await repo.saveClassroomDocument(
        material(
          'File',
          fields: {
            'driveId': 'd',
            'itemId': 'i',
            'localKey': 'old',
            'etag': 'old',
          },
        ),
      );
      await repo.saveClassroomDocument(old.patch({'favorite': true}));
      final files = MemoryMaterialFiles()
        ..values['old'] = Uint8List.fromList(utf8.encode('%PDF-1.4 old'));
      final drive = DownloadDrive();
      addTearDown(drive.dispose);
      await expectLater(
        cacheMaterial(c, old, drive, files),
        throwsA(isA<StaleRevision>()),
      );
      expect(files.values.keys, ['old']);
      final current = (await repo.classroomDocuments()).single;
      expect(current.flag('favorite'), isTrue);
      expect(current.text('localKey'), 'old');
    },
  );

  test(
    'day documents reject an inconsistent identity instead of becoming unreachable',
    () {
      final day = prepareMaterials([], '2026-11-06', []);
      expect(
        () => day.patch({'date': '2026-11-07'}),
        throwsA(isA<DomainError>()),
      );
    },
  );

  test(
    'DOCX preview extracts unicode headings, lists, breaks and tables; no deleted text',
    () {
      final result = readDocxPreview(
        docx(
          word(
            '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Üben &amp; Lernen</w:t></w:r></w:p>'
            '<w:p><w:pPr><w:numPr/></w:pPr><w:r><w:t>Eins</w:t><w:br/><w:t>Zwei</w:t></w:r><w:del><w:r><w:t>Gelöscht</w:t></w:r></w:del></w:p>'
            '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Zelle</w:t></w:r></w:p></w:tc></w:tr></w:tbl>',
          ),
        ),
      );
      expect(result[0], {'type': 'heading', 'text': 'Üben & Lernen'});
      expect(result[1]['text'], '• Eins\nZwei');
      expect(result[2]['rows'], [
        ['Zelle'],
      ]);
    },
  );
  test(
    'DOCX rejects malformed XML, entity declarations and oversized content',
    () {
      for (final source in [
        '<broken>',
        '<!DOCTYPE x [<!ENTITY y "secret">]>${word('<w:p/>')}',
        word('<w:p><w:r><w:t>${'x' * 2000001}</w:t></w:r></w:p>'),
      ]) {
        expect(
          () => readDocxPreview(docx(source)),
          throwsA(isA<DomainError>()),
        );
      }
    },
  );
}
