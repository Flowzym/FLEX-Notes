import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/domain/assignment_sources.dart';
import 'package:flex_notizbuch/domain/document_scanner.dart';
import 'package:flex_notizbuch/domain/material_versions.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'package:flex_notizbuch/security/backup_codec.dart';
import 'package:flex_notizbuch/services/assignment_text.dart';
import 'package:flex_notizbuch/services/complete_backup.dart';
import 'package:flex_notizbuch/services/material_versions.dart';
import 'package:flex_notizbuch/services/onedrive.dart';
import 'package:flex_notizbuch/services/scan_store.dart';
import 'classroom_test.dart' show classroomMemory;
import 'document_attachments_test.dart' show taskRecord;
import 'document_scanner_test.dart' show scannerImage;
import 'material_services_test.dart' show MaterialSecrets, clientId, tokenKey;
import 'material_workspace_test.dart' show MemoryMaterialFiles, material;

Uint8List pdf(String name) => Uint8List.fromList(utf8.encode('%PDF-1.4 $name'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'complete encrypted backup restores current files, versions and resumable scan undo together',
    () async {
      final repo = classroomMemory(), target = classroomMemory();
      addTearDown(repo.close);
      addTearDown(target.close);
      await repo.initialize();
      await target.initialize();
      final files = MemoryMaterialFiles(), restored = MemoryMaterialFiles();
      await files.write('current', pdf('current'));
      await files.write('previous', pdf('previous'));
      await files.write('page', scannerImage());
      await files.write('original', scannerImage(width: 200));
      final doc = await repo.saveClassroomDocument(
        material(
          'Arbeitsblatt',
          fields: {
            'localKey': 'current',
            'size': files.values['current']!.length,
            'name': 'Blatt.pdf',
            'versions': [
              materialVersionSnapshot({
                'localKey': 'previous',
                'size': files.values['previous']!.length,
                'name': 'Vorher.pdf',
                'extension': 'pdf',
              }),
            ],
            'deleted': true,
          },
        ),
      );
      await repo.saveDialogDraft(
        DialogDraft(
          id: 'scan',
          type: 'scan',
          ownerId: 'new-document',
          updatedAtUtc: utcNow(),
          data: {
            ...const ScanContext().initial(),
            'pages': [const ScanPage('page', 180, 240).toJson()],
            'filterUndo': {
              'page': const ScanPage('original', 200, 240).toJson(),
            },
          },
        ),
      );
      final plain = await CompleteBackup.capture(repo, files);
      final encoded = await BackupCodec.encrypt(
        plain,
        'long-safe-test-password',
      );
      expect(jsonDecode(encoded)['format'], 'FLEX-Complete-Encrypted');
      final bundle = await CompleteBackup.decode(
        Json.from(
          jsonDecode(
                await BackupCodec.decrypt(encoded, 'long-safe-test-password'),
              )
              as Map,
        ),
      );
      expect(bundle.files.keys.toSet(), {
        'current',
        'previous',
        'page',
        'original',
      });
      final prepared = await bundle.prepare(restored);
      expect(
        restored.values,
        isEmpty,
      ); // Review and cancellation cannot publish or write files.
      await prepared.commit(() => target.restoreBackup(prepared.notebook));
      final saved = (await target.classroomDocuments()).single;
      expect(saved.id, doc.id);
      expect(saved.deleted, true);
      expect(await restored.read(saved.text('localKey')), pdf('current'));
      expect(
        await restored.read(
          materialVersions(saved.toJson()).single['localKey'] as String,
        ),
        pdf('previous'),
      );
      final scan = (await target.dialogDrafts()).single;
      for (final key in scanFileKeys(scan.data)) {
        expect(await restored.exists(key), true);
      }
      final again = await bundle.prepare(restored);
      expect(again.files, isEmpty);
      expect(again.notebook, prepared.notebook);
    },
  );

  test(
    'missing and corrupt binary files refuse a complete backup or restore',
    () async {
      final repo = classroomMemory();
      addTearDown(repo.close);
      await repo.initialize();
      final files = MemoryMaterialFiles();
      await repo.saveClassroomDocument(
        material('Datei', fields: {'localKey': 'missing'}),
      );
      await expectLater(
        CompleteBackup.capture(repo, files),
        throwsA(isA<DomainError>()),
      );
      await files.write('missing', pdf('real'));
      final value = Json.from(
        jsonDecode(await CompleteBackup.capture(repo, files)) as Map,
      );
      value['files']['missing']['data'] = base64Encode(pdf('corrupt'));
      await expectLater(
        CompleteBackup.decode(value),
        throwsA(isA<DomainError>()),
      );
    },
  );

  test(
    'restore collision never overwrites existing bytes and database failure removes only staging files',
    () async {
      final repo = classroomMemory();
      addTearDown(repo.close);
      await repo.initialize();
      await repo.saveClassroomDocument(
        material('Datei', fields: {'localKey': 'collision'}),
      );
      final files = MemoryMaterialFiles();
      await files.write('collision', pdf('incoming'));
      final bundle = await CompleteBackup.decode(
        Json.from(jsonDecode(await CompleteBackup.capture(repo, files)) as Map),
      );
      final targetFiles = MemoryMaterialFiles();
      await targetFiles.write('collision', pdf('existing'));
      final restore = await bundle.prepare(targetFiles);
      await expectLater(
        restore.commit(() async => throw const StaleRevision()),
        throwsA(isA<StaleRevision>()),
      );
      expect(targetFiles.values.keys.toList(), ['collision']);
      expect(targetFiles.values['collision'], pdf('existing'));
    },
  );

  test(
    'reassignment preserves missing history and carries the selected subtree and attachments only',
    () async {
      final repo = classroomMemory();
      addTearDown(repo.close);
      await repo.initialize();
      await repo.savePupil(const Pupil(id: 'p', name: 'Alex'));
      final original = await repo.saveSchoolRecord(
        taskRecord('p').patch({
          'feedback': [
            SchoolFeedback(
              id: 'missing',
              observedOn: dateOnly(DateTime.now()),
              createdAtUtc: utcNow(),
              taskId: 'main',
              taskText: 'Gleicher Text',
              state: TaskState.missing,
            ).toJson(),
          ],
        }),
      );
      final shared = await repo.saveClassroomDocument(
        material(
          'Aufgabe',
          fields: {
            'links': [
              DocumentLink('school', original.id, taskId: 'child').toJson(),
            ],
          },
        ),
      );
      final other = await repo.saveClassroomDocument(
        material(
          'Andere',
          fields: {
            'links': [
              DocumentLink('school', original.id, taskId: 'other').toJson(),
            ],
          },
        ),
      );
      final next = await repo.reassignHomeworkTask(
        original,
        'main',
        dueDate: '2026-12-01',
      );
      expect(next.tasks.length, 2);
      expect(next.tasks.last.parentId, next.tasks.first.id);
      expect(next.tasks.map(next.taskState), everyElement(TaskState.open));
      expect(next.tasks.map((t) => t.id), isNot(contains('main')));
      final old = (await repo.schoolRecords()).firstWhere(
        (r) => r.id == original.id,
      );
      expect(old.taskState(old.tasks.first), TaskState.missing);
      final docs = await repo.classroomDocuments();
      expect(docs.firstWhere((d) => d.id == shared.id).rows('links').length, 2);
      expect(docs.firstWhere((d) => d.id == other.id).rows('links').length, 1);
      await expectLater(
        repo.reassignHomeworkTask(original, 'main'),
        throwsA(isA<StaleRevision>()),
      );
      expect((await repo.schoolRecords()).length, 2);
    },
  );

  test(
    'saved scanner replacements retain five restorable versions and clean evicted bytes',
    () async {
      final repo = classroomMemory();
      addTearDown(repo.close);
      await repo.initialize();
      final files = MemoryMaterialFiles();
      await files.write('initial', pdf('initial'));
      var doc = await repo.saveClassroomDocument(
        material(
          'Scan',
          fields: {
            'localKey': 'initial',
            'name': 'Scan.pdf',
            'size': files.values['initial']!.length,
          },
        ),
      );
      for (var i = 0; i < 6; i++) {
        final key = 'page-$i';
        await files.write(key, scannerImage(width: 180 + i));
        final draft = await repo.saveDialogDraft(
          DialogDraft(
            id: 'edit-$i',
            type: 'scan',
            ownerId: newId(),
            updatedAtUtc: utcNow(),
            data: {
              ...const ScanContext().initial(),
              'sourceId': doc.id,
              'sourceRevision': doc.revision,
              'pages': [ScanPage(key, 180 + i, 240).toJson()],
            },
          ),
        );
        doc = await saveScan(repo, files, draft, replace: true);
      }
      final versions = materialVersions(doc.toJson());
      expect(versions.length, 5);
      expect(await files.exists('initial'), false);
      final prior = await files.read(versions.first['localKey'] as String);
      await changeMaterialVersion(
        repo,
        files,
        doc,
        versions.first['id'] as String,
      );
      doc = (await repo.classroomDocuments()).single;
      expect(await files.read(doc.text('localKey')), prior);
      final remove = materialVersions(doc.toJson()).last;
      await changeMaterialVersion(
        repo,
        files,
        doc,
        remove['id'] as String,
        remove: true,
      );
      expect(await files.exists(remove['localKey'] as String), false);
    },
  );

  test(
    'assignment links survive save and backup, including original task excerpts',
    () async {
      final repo = classroomMemory(), target = classroomMemory();
      addTearDown(repo.close);
      addTearDown(target.close);
      await repo.initialize();
      await target.initialize();
      await repo.savePupil(const Pupil(id: 'p', name: 'Alex'));
      final source = const AssignmentSource(
        documentId: 'planning-doc',
        title: 'Tagesplanung',
        text: 'Seite 12, Aufgabe 3',
        page: 2,
      );
      final record = await repo.saveSchoolRecord(
        SchoolRecord.empty(SchoolKind.work, 'p').patch({
          'assignmentSources': [source.toJson()],
        }),
      );
      expect(record.searchText, contains('Seite 12'));
      await target.restoreBackup(await repo.exportBackup());
      expect(
        (await target.schoolRecords()).single.assignmentSources.single.identity,
        source.identity,
      );
    },
  );

  test(
    'DOCX assignment extraction includes tasks in paragraphs and table cells',
    () async {
      final xml = utf8.encode(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Seite 12 bearbeiten</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>Wörter üben</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>',
      );
      final types = utf8.encode('<Types/>');
      final archive = Archive()
        ..add(ArchiveFile('[Content_Types].xml', types.length, types))
        ..add(ArchiveFile('word/document.xml', xml.length, xml));
      final files = MemoryMaterialFiles();
      await files.write(
        'docx',
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );
      final doc = material(
        'Tagesplanung',
        fields: {'extension': 'docx', 'localKey': 'docx'},
      );
      final tasks = await readAssignmentText(doc, files);
      expect(
        tasks.map((t) => t.text),
        containsAll(['Seite 12 bearbeiten', 'Wörter üben']),
      );
      expect(tasks.every((t) => t.documentId == doc.id), true);
    },
  );

  test(
    'OneDrive public configuration persists without including credentials in notebook data',
    () async {
      final secrets = MaterialSecrets();
      final drive = OneDriveClient(store: secrets, clientId: '');
      addTearDown(drive.dispose);
      await expectLater(
        drive.configure('not-a-client-id'),
        throwsA(isA<DomainError>()),
      );
      await drive.configure(clientId);
      expect(drive.configured, true);
      expect(secrets.values[tokenKey], isNull);
      final reopened = OneDriveClient(store: secrets, clientId: '');
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.clientId, clientId);
      expect(reopened.connected, false);
    },
  );
}
