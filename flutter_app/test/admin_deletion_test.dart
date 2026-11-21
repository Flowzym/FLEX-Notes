import 'package:flutter_test/flutter_test.dart';
import 'package:flex_notizbuch/domain/admin_deletion.dart';
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/drive_rules.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'package:flex_notizbuch/domain/school.dart';
import 'classroom_test.dart' show classroomMemory;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Vorschau ist reversibel, einzelne Schülerlöschung bewahrt geteilte Dateien und fremde Einträge',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final a = await repo.savePupil(
        const Pupil(id: 'p-archive', name: 'Archivkind'),
      );
      final b = await repo.savePupil(
        const Pupil(id: 'p-active', name: 'Aktivkind'),
      );
      final r = await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.work,
          a.id,
        ).patch({'body': 'Einzelhinweis'}),
      );
      await repo.saveSchoolRecord(
        SchoolRecord.empty(
          SchoolKind.work,
          b.id,
        ).patch({'body': 'Anderer Hinweis'}),
      );
      await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Gemeinsames Heft', {
          'localKey': 'sharedFile',
          'extension': 'pdf',
          'pupilIds': [a.id, b.id],
        }),
      );
      final own = await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Eigenes Blatt', {
          'localKey': 'personalFile',
          'extension': 'pdf',
          'driveId': 'drive',
          'itemId': 'word',
          'pupilIds': [a.id],
        }),
      );
      await repo.savePupil(a.copyWith(archived: true));
      final target = AdminTarget('pupil', a.id),
          p = await repo.previewAdminDeletion(target);
      expect(p.removed['Schüler'], 1);
      expect(p.removed['Materialien'], 1);
      expect(p.unlinked, 1);
      expect(await repo.pupils(), hasLength(2));
      expect(await repo.erasedDriveSources(), isEmpty);
      await repo.deleteAdminSelection(p);
      expect((await repo.pupils()).single.id, b.id);
      expect((await repo.schoolRecords()).single.pupilId, b.id);
      expect((await repo.classroomDocuments()).single.strings('pupilIds'), [
        b.id,
      ]);
      expect(await repo.history(r.id), isEmpty);
      expect(
        await repo.erasedDriveSources(),
        contains(erasedDriveSource('drive', own.text('itemId'))),
      );
      final keys = <String>[];
      await repo.removeUnreferencedFiles((key) async => keys.add(key));
      expect(keys, ['personalFile']);
    },
  );
  test(
    'Einzellöschung, veraltete Vorschau und vollständiges lokales Zurücksetzen',
    () async {
      final repo = classroomMemory();
      await repo.initialize();
      addTearDown(repo.close);
      final p = await repo.savePupil(const Pupil(id: 'p', name: 'Kind'));
      final a = await repo.saveEntry(
        OrgaEntry.empty(pupilId: p.id).copyWith(title: 'Notiz eins'),
      );
      final preview = await repo.previewAdminDeletion(
        AdminTarget('orga', a.id),
      );
      await repo.saveEntry(OrgaEntry.empty().copyWith(title: 'Notiz zwei'));
      expect(
        () => repo.deleteAdminSelection(preview),
        throwsA(isA<DomainError>()),
      );
      await repo.deleteAdminSelection(
        await repo.previewAdminDeletion(AdminTarget('orga', a.id)),
      );
      expect((await repo.entries()).single.title, 'Notiz zwei');
      expect(await repo.pupils(), hasLength(1));
      await repo.saveClassroomDocument(
        ClassroomDocument.create(ClassroomKind.material, 'Datei', {
          'extension': 'pdf',
          'localKey': 'key',
        }),
      );
      final all = await repo.previewAdminDeletion(const AdminTarget.all());
      expect(all.removed['Dateien auf diesem Gerät'], 1);
      await repo.deleteAdminSelection(all);
      expect(await repo.pupils(), isEmpty);
      expect(await repo.entries(), isEmpty);
      expect(await repo.classroomDocuments(), isEmpty);
      expect(await repo.searchEntryKeys('Notiz'), isEmpty);
      final keys = <String>[];
      await repo.removeUnreferencedFiles((key) async => keys.add(key));
      expect(keys, ['key']);
      await repo.savePupil(const Pupil(id: 'neu', name: 'Neustart'));
      expect((await repo.pupils()).single.id, 'neu');
    },
  );
}
