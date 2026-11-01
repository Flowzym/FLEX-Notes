import 'models.dart';

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
}
class LegacyReport {
  const LegacyReport({required this.pupils, required this.entries, required this.classTasks, required this.drafts});
  final int pupils, entries, classTasks, drafts;
}
