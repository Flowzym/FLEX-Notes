import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/school.dart';

class NotebookController extends ChangeNotifier {
  NotebookController(this.repository);
  final NotebookRepository repository;
  List<Pupil> pupils = [];
  List<OrgaEntry> entries = [];
  List<OrgaEntry> trashedEntries = [];
  List<EditDraft> drafts = [];
  List<SchoolRecord> records = [];
  List<SchoolDraft> schoolDrafts = [];
  List<DialogDraft> dialogDrafts = [];
  int get draftCount =>
      drafts.length + schoolDrafts.length + dialogDrafts.length;
  int _loadGeneration = 0;
  Appearance appearance = const Appearance();
  int stagedLegacyCount = 0;
  Future<void> initialize() async {
    await repository.initialize();
    await reload();
  }

  Future<void> reload() async {
    final generation = ++_loadGeneration;
    final next = await repository.snapshot();
    if (generation != _loadGeneration) return;
    pupils = next.pupils;
    entries = next.entries.where((e) => !e.deleted).toList();
    trashedEntries = next.entries.where((e) => e.deleted).toList();
    drafts = next.drafts;
    records = next.records;
    schoolDrafts = next.schoolDrafts;
    dialogDrafts = next.dialogDrafts;
    appearance = next.appearance;
    stagedLegacyCount = next.legacyCount;
    notifyListeners();
  }

  Future<void> savePupil(Pupil pupil) async {
    await repository.savePupil(pupil);
    await reload();
  }

  Future<void> saveEntry(
    OrgaEntry entry, {
    String? draftId,
    int? draftRevision,
  }) async {
    await repository.saveEntry(
      entry,
      draftId: draftId,
      draftRevision: draftRevision,
    );
    await reload();
  }

  Future<void> saveRecord(
    SchoolRecord record, {
    String? draftId,
    int? draftRevision,
  }) async {
    await repository.saveSchoolRecord(
      record,
      draftId: draftId,
      draftRevision: draftRevision,
    );
    await reload();
  }

  Future<void> saveAppearance(Appearance value) async {
    await repository.saveAppearance(value);
    appearance = value;
    notifyListeners();
  }

  String owner(OrgaEntry e) {
    if (e.pupilId == null) return 'Klasse';
    final matching = pupils.where((p) => p.id == e.pupilId);
    if (matching.isEmpty) return 'Unbekannte Zuordnung';
    return '${matching.first.name}${matching.first.archived ? ' · Archiv' : ''}';
  }

  List<OrgaEntry> upcoming(Iterable<OrgaEntry> values) =>
      values.where((e) => e.pending).toList()..sort((a, b) {
        final compared = (a.nextDate ?? '9999').compareTo(b.nextDate ?? '9999');
        return compared != 0 ? compared : a.id.compareTo(b.id);
      });
}
