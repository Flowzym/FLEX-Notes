import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../services/device_services.dart';
import '../domain/repository.dart';
import '../domain/school.dart';
import '../domain/classroom.dart';

class NotebookController extends ChangeNotifier {
  NotebookController(this.repository, {this.services});
  final DeviceServices? services;
  final NotebookRepository repository;
  List<Pupil> pupils = [];
  List<OrgaEntry> entries = [];
  List<OrgaEntry> trashedEntries = [];
  List<EditDraft> drafts = [];
  List<SchoolRecord> records = [];
  List<SchoolDraft> schoolDrafts = [];
  List<DialogDraft> dialogDrafts = [];
  List<ClassroomDocument> classroom = [];
  NotebookSnapshot get currentSnapshot => NotebookSnapshot(
    pupils: pupils,
    entries: [...entries, ...trashedEntries],
    drafts: drafts,
    records: records,
    schoolDrafts: schoolDrafts,
    dialogDrafts: dialogDrafts,
    appearance: appearance,
    legacyCount: stagedLegacyCount,
    classroom: classroom,
  );
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
    if (_disposed) return;
    final generation = ++_loadGeneration;
    final appearanceGeneration = _appearanceGeneration;
    final next = await repository.snapshot();
    if (_disposed || generation != _loadGeneration) return;
    pupils = next.pupils;
    entries = next.entries.where((e) => !e.deleted).toList();
    trashedEntries = next.entries.where((e) => e.deleted).toList();
    drafts = next.drafts;
    records = next.records;
    schoolDrafts = next.schoolDrafts;
    dialogDrafts = next.dialogDrafts;
    classroom = next.classroom;
    if (!appearanceSaving && appearanceGeneration == _appearanceGeneration) {
      appearance = next.appearance;
      _savedAppearance = appearance;
    }
    stagedLegacyCount = next.legacyCount;
    services?.updated(next);
    notifyListeners();
  }

  Future<void> savePupil(Pupil pupil) async {
    await repository.savePupil(pupil);
    await reload();
  }

  Future<void> saveClassroom(ClassroomDocument document) async {
    await repository.saveClassroomDocument(document);
    await reload();
  }

  Future<void> saveClassroomBatch(List<ClassroomDocument> documents) async {
    await repository.saveClassroomDocuments(documents);
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
    services?.dispose();
    super.dispose();
  }

  String owner(OrgaEntry e) {
    if (e.pupilId == null) {
      return e.otherParticipants.trim().isEmpty
          ? 'Klasse'
          : e.otherParticipants.trim();
    }
    final matching = pupils.where((p) => p.id == e.pupilId);
    if (matching.isEmpty) return 'Unbekannte Zuordnung';
    return [
      '${matching.first.name}${matching.first.archived ? ' · Archiv' : ''}',
      if (e.otherParticipants.trim().isNotEmpty) e.otherParticipants.trim(),
    ].join(' · ');
  }

  List<OrgaEntry> upcoming(Iterable<OrgaEntry> values) =>
      values.where((e) => e.pending).toList()..sort((a, b) {
        final compared = (a.nextDate ?? '9999').compareTo(b.nextDate ?? '9999');
        return compared != 0 ? compared : a.id.compareTo(b.id);
      });
}
