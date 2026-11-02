import 'models.dart';
import 'school.dart';
import 'observation_catalog.dart';

abstract interface class NotebookRepository {
  Future<NotebookSnapshot> snapshot();
  Future<void> initialize();
  Future<List<Pupil>> pupils();
  Future<Pupil> savePupil(Pupil pupil);
  Future<List<OrgaEntry>> entries();
  Future<OrgaEntry> saveEntry(
    OrgaEntry entry, {
    String? draftId,
    int? draftRevision,
  });
  Future<EditDraft> saveDraft(EditDraft draft);
  Future<List<EditDraft>> drafts();
  Future<void> discardDraft(String id, {int? expectedRevision});
  Future<List<Json>> history(String entityId);
  Future<Appearance> appearance();
  Future<void> saveAppearance(Appearance appearance);
  Future<ObservationCatalog> observationCatalog(String key);
  Future<ObservationCatalog> saveObservationOptions(
    String key,
    List<String> options,
  );
  Future<ObservationCatalog> toggleObservationFavorite(String key, String text);
  Future<String> exportBackup();
  Future<void> restoreBackup(String text);
  Future<LegacyReport> inspectLegacy(String text);
  Future<void> stageLegacy(String text);
  Future<int> legacyCount();
  Future<void> close();
  Future<void> maintainStorage(
    String capturedBackup, {
    required bool emptyTrash,
  });
  Future<void> resolveSchoolConflict(
    SchoolDraft draft, {
    required bool useOther,
  });
  Future<void> resolveOrgaConflict(EditDraft draft, {required bool useOther});
  Future<List<DialogDraft>> dialogDrafts();
  Future<Json?> situation(String id);
  Future<void> saveSituation(
    String id,
    int revision,
    String text,
    DialogDraft? draft,
  );
  Future<void> saveBulkDialog(DialogDraft draft);
  Future<DialogDraft> saveDialogDraft(DialogDraft draft);
  Future<void> discardDialogDraft(String id, int revision);
  Future<Pupil> savePupilDialog(Pupil pupil, DialogDraft? draft);
  Future<void> saveCatalogs(
    Map<String, List<String>> options,
    DialogDraft? draft,
  );
  Future<List<SchoolRecord>> schoolRecords();
  Future<SchoolRecord> saveSchoolRecord(
    SchoolRecord record, {
    String? draftId,
    int? draftRevision,
  });
  Future<List<SchoolRecord>> saveSchoolGroup(
    SchoolRecord record,
    List<String> recipients,
    String requestId, {
    int? draftRevision,
  });
  Future<List<Json>> schoolGroups();
  Future<void> undoSchoolGroup(String id);
  Future<List<SchoolDraft>> schoolDrafts();
  Future<SchoolDraft> saveSchoolDraft(SchoolDraft draft);
  Future<void> discardSchoolDraft(String id, {int? expectedRevision});
}

class NotebookSnapshot {
  const NotebookSnapshot({
    required this.pupils,
    required this.entries,
    required this.drafts,
    required this.records,
    required this.schoolDrafts,
    required this.appearance,
    required this.legacyCount,
    this.dialogDrafts = const [],
  });
  final List<Pupil> pupils;
  final List<OrgaEntry> entries;
  final List<EditDraft> drafts;
  final List<SchoolRecord> records;
  final List<SchoolDraft> schoolDrafts;
  final List<DialogDraft> dialogDrafts;
  final Appearance appearance;
  final int legacyCount;
}

class LegacyReport {
  const LegacyReport({
    required this.pupils,
    required this.entries,
    required this.classTasks,
    required this.drafts,
  });
  final int pupils, entries, classTasks, drafts;
}
