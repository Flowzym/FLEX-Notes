import 'dart:async';
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
  Appearance _savedAppearance = const Appearance();
  Timer? _appearanceTimer;
  Future<void> _appearanceWrites = Future.value();
  int _appearanceGeneration = 0, _appearancePending = 0;
  bool _disposed = false;
  String? appearanceError;
  bool get appearanceSaving =>
      _appearanceTimer != null || _appearancePending > 0;
  int stagedLegacyCount = 0;
  Future<void> initialize() async {
    await repository.initialize();
    await reload();
  }

  Future<void> reload() async {
    final generation = ++_loadGeneration;
    final appearanceGeneration = _appearanceGeneration;
    final next = await repository.snapshot();
    if (generation != _loadGeneration) return;
    pupils = next.pupils;
    entries = next.entries.where((e) => !e.deleted).toList();
    trashedEntries = next.entries.where((e) => e.deleted).toList();
    drafts = next.drafts;
    records = next.records;
    schoolDrafts = next.schoolDrafts;
    dialogDrafts = next.dialogDrafts;
    if (!appearanceSaving && appearanceGeneration == _appearanceGeneration) {
      appearance = next.appearance;
      _savedAppearance = appearance;
    }
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
    _appearanceTimer?.cancel();
    _appearanceTimer = null;
    final generation = ++_appearanceGeneration;
    appearance = value;
    appearanceError = null;
    final queued = _appearancePending > 0;
    _appearancePending++;
    notifyListeners();
    Future<void> performWrite() async {
      try {
        await repository.saveAppearance(value);
        _savedAppearance = value;
      } catch (_) {
        if (generation == _appearanceGeneration) {
          appearance = _savedAppearance;
          appearanceError = 'Nicht gespeichert. Bitte erneut versuchen.';
        }
        rethrow;
      } finally {
        _appearancePending--;
        if (!_disposed) notifyListeners();
      }
    }

    final write = queued
        ? _appearanceWrites.then((_) => performWrite())
        : performWrite();
    _appearanceWrites = write.catchError((Object _) {});
    await write;
  }

  void previewAppearance(Json changes) {
    appearance = appearance.change(changes);
    _appearanceGeneration++;
    appearanceError = null;
    _appearanceTimer?.cancel();
    _appearanceTimer = Timer(
      const Duration(milliseconds: 250),
      flushAppearance,
    );
    notifyListeners();
  }

  Future<void> flushAppearance() async {
    if (_appearanceTimer != null) {
      _appearanceTimer!.cancel();
      _appearanceTimer = null;
      try {
        await saveAppearance(appearance);
      } catch (_) {
        /* Visible status stays available. */
      }
    }
    await _appearanceWrites;
  }

  @override
  void dispose() {
    _appearanceTimer?.cancel();
    _disposed = true;
    super.dispose();
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
