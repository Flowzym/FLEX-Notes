import 'models.dart';
import 'school.dart';

abstract interface class NotebookRepository {
  Future<void> initialize();
  Future<List<Pupil>> pupils();
  Future<Pupil> savePupil(Pupil pupil);
  Future<List<OrgaEntry>> entries();
  Future<OrgaEntry> saveEntry(OrgaEntry entry, {String? draftId});
  Future<void> saveDraft(EditDraft draft);
  Future<List<EditDraft>> drafts();
  Future<void> discardDraft(String id);
  Future<List<Json>> history(String entityId);
  Future<Appearance> appearance();
  Future<void> saveAppearance(Appearance appearance);
  Future<String> exportBackup();
  Future<void> restoreBackup(String text);
  Future<LegacyReport> inspectLegacy(String text);
  Future<void> stageLegacy(String text);
  Future<int> legacyCount();
  Future<void> close();
  Future<List<SchoolRecord>> schoolRecords();
  Future<SchoolRecord> saveSchoolRecord(SchoolRecord record, {String? draftId});
  Future<List<SchoolRecord>> saveSchoolGroup(
    SchoolRecord record,
    List<String> recipients,
    String requestId,
  );
  Future<List<Json>> schoolGroups();
  Future<void> undoSchoolGroup(String id);
  Future<List<SchoolDraft>> schoolDrafts();
  Future<SchoolDraft> saveSchoolDraft(SchoolDraft draft);
  Future<void> discardSchoolDraft(String id);
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
