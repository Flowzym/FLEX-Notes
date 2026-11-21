import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/core.dart';

enum EntryKind {
  social('Sozialverhalten'),
  work('Arbeitsverhalten'),
  goal('Ziel'),
  homework('Hausübung'),
  note('Notiz'),
  task('Aufgabe'),
  appointment('Termin'),
  returnList('Rücklauf'),
  plan('Unterrichtsplanung'),
  lesson('Unterricht');

  const EntryKind(this.label);
  final String label;
  bool get school => index <= homework.index;
  bool get orga => index >= note.index && index <= appointment.index;
}

/// A desktop editor can stay open while the central workspace changes.
/// Draft writes are serialized and committing removes that exact draft in the
/// same repository transaction. Revisions protect other windows/imports.
class EditorSession extends ChangeNotifier {
  EditorSession(
    this.repository,
    this.kind,
    this.data, {
    String? draftId,
    int draftRevision = 0,
  }) : draftId = draftId ?? newId(),
       draftRevision = draftRevision,
       persisted = draftRevision > 0,
       baseline = jsonEncode(data);
  final NotebookRepository repository;
  final EntryKind kind;
  final String draftId, baseline;
  Json data;
  int draftRevision, generation = 0;
  bool dirty = false, persisted, saving = false, closed = false;
  Object? error;
  Timer? _timer;
  Future<void> _pending = Future.value();
  bool get changed => jsonEncode(data) != baseline || persisted;
  String get status => error != null
      ? 'Entwurf konnte nicht gesichert werden'
      : saving
      ? 'Wird gespeichert …'
      : dirty
      ? 'Ungesicherte Änderung …'
      : persisted
      ? 'Entwurf gesichert'
      : 'Neue Eingabe';
  void patch(Json changes) {
    if (closed || saving) return;
    data = {...data, ...changes};
    generation++;
    dirty = true;
    error = null;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () async {
      try {
        await flush();
      } catch (_) {
        /* surfaced in the editor */
      }
    });
    notifyListeners();
  }

  Future<void> flush() {
    _timer?.cancel();
    final captured = Json.from(jsonDecode(jsonEncode(data)) as Map);
    final capturedGeneration = generation;
    _pending = _pending.catchError((Object _) {}).then((_) async {
      if (closed || !dirty) return;
      try {
        if (kind.school) {
          final saved = await repository.saveSchoolDraft(
            SchoolDraft(
              id: draftId,
              record: SchoolRecord.fromJson(captured),
              updatedAtUtc: utcNow(),
              editRevision: draftRevision,
            ),
          );
          draftRevision = saved.editRevision;
        } else if (kind.orga) {
          final saved = await repository.saveDraft(
            EditDraft(
              id: draftId,
              entry: OrgaEntry.fromJson(captured),
              updatedAtUtc: utcNow(),
              editRevision: draftRevision,
            ),
          );
          draftRevision = saved.editRevision;
        } else {
          final saved = await repository.saveDialogDraft(
            DialogDraft(
              id: draftId,
              type: 'classroom',
              ownerId: captured['id'] as String,
              data: captured,
              updatedAtUtc: utcNow(),
              revision: draftRevision,
            ),
          );
          draftRevision = saved.revision;
        }
        persisted = true;
        if (capturedGeneration == generation) dirty = false;
        error = null;
      } catch (e) {
        error = e;
        rethrow;
      } finally {
        if (!closed) notifyListeners();
      }
    });
    return _pending;
  }

  Future<void> commit() async {
    if (saving || closed) return;
    saving = true;
    notifyListeners();
    try {
      await flush();
      if (kind.school) {
        await repository.saveSchoolRecord(
          SchoolRecord.fromJson(data),
          draftId: persisted ? draftId : null,
          draftRevision: persisted ? draftRevision : null,
        );
      } else if (kind.orga) {
        await repository.saveEntry(
          OrgaEntry.fromJson(data),
          draftId: persisted ? draftId : null,
          draftRevision: persisted ? draftRevision : null,
        );
      } else {
        await repository.saveClassroomDocument(
          ClassroomDocument.fromJson(data),
          draft: persisted
              ? DialogDraft(
                  id: draftId,
                  type: 'classroom',
                  ownerId: data['id'] as String,
                  data: data,
                  updatedAtUtc: utcNow(),
                  revision: draftRevision,
                )
              : null,
        );
      }
      closed = true;
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> discard() async {
    _timer?.cancel();
    await _pending.catchError((Object _) {});
    if (persisted) {
      if (kind.school) {
        await repository.discardSchoolDraft(
          draftId,
          expectedRevision: draftRevision,
        );
      } else if (kind.orga) {
        await repository.discardDraft(draftId, expectedRevision: draftRevision);
      } else {
        await repository.discardDialogDraft(draftId, draftRevision);
      }
    }
    closed = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

Json newEntry(EntryKind kind, {String? pupilId, DateTime? date}) {
  final day = dateOnly(date ?? DateTime.now());
  if (kind.school) {
    return SchoolRecord.empty(
      SchoolKind.values.byName(kind.name),
      pupilId ?? '',
    ).patch({'observedOn': day}).toJson();
  }
  if (kind.orga) {
    return OrgaEntry.empty(pupilId: pupilId)
        .copyWith(
          isTask: kind == EntryKind.task,
          appointmentDate: kind == EntryKind.appointment ? day : null,
          appointmentTime: kind == EntryKind.appointment ? '09:00' : '',
          appointmentEndTime: kind == EntryKind.appointment ? '10:00' : '',
        )
        .toJson();
  }
  return {
    'format': 'flex-classroom-1',
    'id': newId(),
    'kind': kind.name,
    'title': '',
    'revision': 0,
    'deleted': false,
    'createdAtUtc': utcNow(),
    'updatedAtUtc': utcNow(),
    'note': '',
    'materialIds': <String>[],
    if (pupilId != null) 'pupilIds': [pupilId],
    if (kind == EntryKind.returnList) ...{
      'type': 'form',
      'dueDate': '',
      'participants': <Json>[],
      'closed': false,
      'remindDays': 0,
      'amountDue': 0,
    },
    if (kind == EntryKind.plan) ...{
      'date': day,
      'status': 'planned',
      'subject': '',
      'topic': '',
      'followUp': '',
      'lessonIds': <String>[],
    },
    if (kind == EntryKind.lesson) ...{
      'date': day,
      'start': '08:00',
      'end': '08:50',
      'repeat': const RepeatRule().toJson(),
      'exceptions': <Json>[],
    },
  };
}
