import 'entry_template.dart';
import 'reminder_action.dart';
import 'school_year.dart';
import 'models.dart';
import 'school.dart';
import 'observation_catalog.dart';
import 'classroom.dart';

abstract interface class NotebookRepository {
  Future<List<EntryTemplate>> entryTemplates();
  Future<void> saveEntryTemplate(EntryTemplate template);
  Future<void> deleteEntryTemplate(String id);
  Future<CatalogBundle> exportCatalogs();
  Future<void> importCatalogs(CatalogBundle bundle, {required bool replace});
  Future<bool> applyReminderAction(ReminderAction action, DateTime now);
  Future<void> removeUnreferencedFiles(
    Future<void> Function(String key) remove,
  );
  Future<List<SchoolYearArchive>> schoolYears();
  Future<void> archiveSchoolYear(
    SchoolYearArchive archive,
    String capturedBackup,
  );
  Future<void> reopenSchoolYear(String id);
  Future<RetentionPolicy> retentionPolicy();
  Future<void> saveRetentionPolicy(RetentionPolicy policy);
  Future<List<RetentionCandidate>> retentionReview(DateTime now);
  Future<void> purgeRetained(
    Set<String> keys,
    String capturedBackup, {
    DateTime? now,
  });
  Future<List<ClassroomDocument>> classroomDocuments();
  Future<void> renameMaterialTag(String oldTag, String? newTag);
  Future<ClassroomDocument> saveClassroomDocument(
    ClassroomDocument document, {
    DialogDraft? draft,
  });
  Future<void> saveClassroomDocuments(
    List<ClassroomDocument> documents, {
    DialogDraft? draft,
  });
  Future<void> configureRepeat(
    OrgaEntry entry,
    RepeatRule rule, {
    String? effectiveFrom,
  });
  Future<void> materializeRepeats(DateTime now);
  Future<NotebookSnapshot> snapshot();
  Future<void> initialize();
  Future<List<Pupil>> pupils();
  Future<Pupil> savePupil(Pupil pupil);
  Future<Set<String>> searchEntryKeys(String query, {String? pupilId});
  Future<List<OrgaEntry>> entries();
  Future<void> saveOrganisationSelection(
    List<OrgaEntry> entries,
    List<ClassroomDocument> returns,
  );
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
  Future<Pupil> savePupilDialog(
    Pupil pupil,
    DialogDraft? draft, {
    ClassroomDocument? materialProfile,
    List<ClassroomDocument> materialUpdates = const [],
  });
  Future<void> savePlanningSync(
    List<ClassroomDocument> changes,
    Map<String, int> rosterRevisions,
  );
  Future<void> saveCatalogs(
    Map<String, List<String>> options,
    DialogDraft? draft,
  );
  Future<List<SchoolRecord>> schoolRecords();
  Future<SchoolRecord> reassignHomeworkTask(
    SchoolRecord source,
    String taskId, {
    String? dueDate,
  });
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
    this.classroom = const [],
    this.schoolYears = const [],
  });
  final List<Pupil> pupils;
  final List<OrgaEntry> entries;
  final List<EditDraft> drafts;
  final List<SchoolRecord> records;
  final List<SchoolDraft> schoolDrafts;
  final List<DialogDraft> dialogDrafts;
  final List<ClassroomDocument> classroom;
  final List<SchoolYearArchive> schoolYears;
  final Appearance appearance;
  final int legacyCount;
  NotebookSnapshot active() {
    final entryIds = schoolYears.expand((y) => y.orgaIds).toSet();
    final recordIds = schoolYears.expand((y) => y.recordIds).toSet();
    final documentIds = schoolYears.expand((y) => y.documentIds).toSet();
    return NotebookSnapshot(
      pupils: pupils,
      entries: entries.where((e) => !entryIds.contains(e.id)).toList(),
      records: records.where((r) => !recordIds.contains(r.id)).toList(),
      classroom: classroom.where((d) => !documentIds.contains(d.id)).toList(),
      drafts: drafts,
      schoolDrafts: schoolDrafts,
      dialogDrafts: dialogDrafts,
      appearance: appearance,
      legacyCount: legacyCount,
      schoolYears: schoolYears,
    );
  }
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
