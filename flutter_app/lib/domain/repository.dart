import 'models.dart';
import 'school.dart';

abstract interface class NotebookRepository {
  Future<NotebookSnapshot> snapshot();
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
  Future<void> discardSchoolDraft(String id);
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
  });
  final List<Pupil> pupils;
  final List<OrgaEntry> entries;
  final List<EditDraft> drafts;
  final List<SchoolRecord> records;
  final List<SchoolDraft> schoolDrafts;
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
