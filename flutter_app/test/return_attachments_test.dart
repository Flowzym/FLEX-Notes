import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/application/notebook_controller.dart';
import 'package:flex_notizbuch/data/sqlite_notebook.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/ui/classroom_editor.dart';
import 'classroom_test.dart' show classroomMemory;
import 'material_workspace_test.dart' show material;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SqliteNotebook repo;
  late NotebookController c;
  setUp(() async {
    repo = classroomMemory();
    c = NotebookController(repo);
    await c.initialize();
    await c.savePupil(const Pupil(id: 'p', name: 'Alex'));
  });
  tearDown(() async {
    c.dispose();
    await repo.close();
  });

  Future<DialogDraft> owner() => repo.saveDialogDraft(
    DialogDraft(
      id: 'return-draft',
      type: 'classroom',
      ownerId: 'return',
      updatedAtUtc: utcNow(),
      data: {...classroomInitial(ClassroomKind.returnList, c), 'id': 'return'},
    ),
  );
  Future<ClassroomDocument> attachments(DialogDraft d) async {
    final scope = ScanContext(links: [DocumentLink('classroomDraft', d.id)]);
    final doc = await repo.saveClassroomDocument(
      material(
        'Formular',
        fields: {'links': scope.links.map((l) => l.toJson()).toList()},
      ),
    );
    await repo.saveDialogDraft(
      DialogDraft(
        id: 'scan',
        type: 'scan',
        ownerId: doc.id,
        updatedAtUtc: utcNow(),
        data: {
          ...scope.initial(),
          'sourceId': doc.id,
          'sourceRevision': doc.revision,
        },
      ),
    );
    return doc;
  }

  test('publishing return promotes files and scan edits atomically', () async {
    final d = await owner();
    final file = await attachments(d);
    await expectLater(
      repo.saveClassroomDocument(
        ClassroomDocument.fromJson({
          ...d.data,
          'title': 'Einverständnis',
          'materialIds': ['missing'],
        }),
        draft: d,
      ),
      throwsA(isA<DomainError>()),
    );
    expect(
      (await repo.classroomDocuments()).single.rows('links').single['kind'],
      'classroomDraft',
    );
    expect(
      (await repo.dialogDrafts()).where((d) => d.type == 'classroom'),
      hasLength(1),
    );
    final saved = await repo.saveClassroomDocument(
      ClassroomDocument.fromJson({...d.data, 'title': 'Einverständnis'}),
      draft: d,
    );
    final image = (await repo.classroomDocuments()).singleWhere(
      (d) => d.id == file.id,
    );
    expect(image.rows('links'), [DocumentLink('classroom', saved.id).toJson()]);
    expect(
      image.strings('pupilIds'),
      isEmpty,
    ); // General form, not a pupil's submission.
    final scan = (await repo.dialogDrafts()).single;
    expect(scan.data['links'], image.rows('links'));
    expect(scan.data['sourceRevision'], image.revision);
  });

  test(
    'discarding return draft detaches files without deleting them',
    () async {
      final d = await owner();
      await attachments(d);
      await expectLater(
        repo.discardDialogDraft(d.id, 0),
        throwsA(isA<StaleRevision>()),
      );
      await repo.discardDialogDraft(d.id, d.revision);
      expect((await repo.classroomDocuments()).single.rows('links'), isEmpty);
      expect((await repo.dialogDrafts()).single.data['links'], isEmpty);
      await repo.validateClassroomReferences();
    },
  );

  test(
    'return draft attachment survives backup and divergent merge without duplicates',
    () async {
      final d = await owner();
      await attachments(d);
      final source = classroomMemory();
      await source.initialize();
      addTearDown(source.close);
      await source.restoreBackup(await repo.exportBackup());
      await source.saveDialogDraft(
        DialogDraft.fromJson({
          ...d.toJson(),
          'data': {...d.data, 'title': 'Andere Fassung'},
        }),
      );
      final backup = await source.exportBackup();
      await repo.applyBackupMerge(await repo.prepareBackupMerge(backup), {});
      final drafts = (await repo.dialogDrafts())
          .where((d) => d.type == 'classroom')
          .toList();
      expect(drafts, hasLength(2));
      final ids = drafts.map((d) => d.id).toSet();
      expect(
        (await repo.classroomDocuments()).single
            .rows('links')
            .map((l) => l['id'])
            .toSet(),
        ids,
      );
      expect(
        (await repo.dialogDrafts())
            .where((d) => d.type == 'scan')
            .map((d) => (d.data['links'] as List).single['id'])
            .toSet(),
        ids,
      );
      final before = jsonDecode(await repo.exportBackup());
      await repo.applyBackupMerge(await repo.prepareBackupMerge(backup), {});
      expect(
        (await repo.dialogDrafts()).where((d) => d.type == 'classroom'),
        hasLength(2),
      );
      final restored = classroomMemory();
      await restored.initialize();
      addTearDown(restored.close);
      await restored.restoreBackup(jsonEncode(before));
      await restored.validateClassroomReferences();
    },
  );

  test('missing return draft links are rejected', () async {
    await expectLater(
      repo.saveClassroomDocument(
        material(
          'Datei',
          fields: {
            'links': [const DocumentLink('classroomDraft', 'missing').toJson()],
          },
        ),
      ),
      throwsA(isA<DomainError>()),
    );
    expect(await repo.classroomDocuments(), isEmpty);
  });
}
