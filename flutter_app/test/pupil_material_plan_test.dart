import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flex_notizbuch/domain/classroom.dart';
import 'package:flex_notizbuch/domain/material_workspace.dart';
import 'package:flex_notizbuch/domain/models.dart';
import 'classroom_test.dart' show classroomMemory;

ClassroomDocument worksheet() => ClassroomDocument.create(
  ClassroomKind.material,
  'Brüche',
  {'extension': 'pdf', 'url': 'https://example.org/brueche.pdf'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test(
    'individual dates remain independent; removing assignment keeps file and other pupil',
    () {
      var doc = planPupilMaterial(worksheet(), 'p', '2026-11-13');
      doc = planPupilMaterial(doc, 'q', '2026-11-14');
      doc = planPupilMaterial(
        doc,
        'p',
        '2026-11-16',
        replaceDate: '2026-11-13',
      );
      doc = planPupilMaterial(doc, 'p', '2026-11-16');
      expect(pupilMaterialDates(doc, 'p'), ['2026-11-16']);
      expect(pupilMaterialDates(doc, 'q'), ['2026-11-14']);
      expect(suggestedMaterials([doc], '2026-11-13'), isEmpty);
      expect(pupilMaterialsOnDay([doc], '2026-11-14').single.id, doc.id);
      final unlinked = doc.patch({
        'pupilIds': ['q'],
      });
      expect(pupilMaterialDates(unlinked, 'p'), isEmpty);
      expect(pupilMaterialDates(unlinked, 'q'), ['2026-11-14']);
      expect(unlinked.text('url'), doc.text('url'));
      expect(unlinked.deleted, isFalse);
      expect(
        pupilMaterialsOnDay([
          unlinked.patch({'deleted': true}),
        ], '2026-11-14'),
        isEmpty,
      );
    },
  );

  test(
    'invalid dates, duplicate dates and missing assignments are rejected',
    () {
      final doc = worksheet();
      for (final fields in <Json>[
        {
          'pupilIds': ['p'],
          'pupilDates': [
            {'pupilId': 'p', 'date': '2026-02-30'},
          ],
        },
        {
          'pupilIds': [],
          'pupilDates': [
            {'pupilId': 'p', 'date': '2026-11-13'},
          ],
        },
        {
          'pupilIds': ['p'],
          'pupilDates': [
            for (var i = 0; i < 2; i++) {'pupilId': 'p', 'date': '2026-11-13'},
          ],
        },
      ]) {
        expect(
          () => ClassroomDocument.fromJson({...doc.toJson(), ...fields}),
          throwsA(isA<DomainError>()),
        );
      }
    },
  );

  test(
    'backup roundtrip and pupil mapping preserve independent teaching dates',
    () async {
      final source = classroomMemory(),
          local = classroomMemory(),
          restored = classroomMemory();
      addTearDown(() async {
        await source.close();
        await local.close();
        await restored.close();
      });
      await source.initialize();
      await local.initialize();
      await restored.initialize();
      await source.savePupil(const Pupil(id: 'p', name: 'Anna'));
      await source.savePupil(const Pupil(id: 'q', name: 'Anna doppelt'));
      await local.savePupil(const Pupil(id: 'local', name: 'Anna lokal'));
      var doc = planPupilMaterial(worksheet(), 'p', '2026-11-13');
      doc = planPupilMaterial(doc, 'q', '2026-11-13');
      doc = planPupilMaterial(doc, 'q', '2026-11-16');
      await source.saveClassroomDocument(doc);
      final backup = await source.exportBackup();
      await restored.restoreBackup(backup);
      expect(
        (await restored.classroomDocuments()).single.rows('pupilDates'),
        doc.rows('pupilDates'),
      );
      final merge = await local.prepareBackupMerge(
        backup,
        pupilLinks: {'p': 'local'},
      );
      await local.applyBackupMerge(merge, {});
      final result = (await local.classroomDocuments()).single;
      expect(result.strings('pupilIds'), containsAll(['local', 'q']));
      expect(pupilMaterialDates(result, 'local'), ['2026-11-13']);
      expect(pupilMaterialDates(result, 'q'), ['2026-11-13', '2026-11-16']);
    },
  );
}
