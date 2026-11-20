import 'package:flutter/foundation.dart';
import '../domain/core.dart';
import '../domain/desktop_calendar.dart';
export '../domain/desktop_calendar.dart';
import 'editor_session.dart';

enum WorkspaceSection {
  desk('Arbeitsplatz'),
  week('Wochenmappe'),
  journal('Klasse & Journal'),
  calendar('Kalender'),
  planning('Unterrichtsplanung'),
  materials('Materialien'),
  organization('Organisation'),
  data('Daten & Einstellungen');

  const WorkspaceSection(this.label);
  final String label;
}

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.notebook, {this.demo = false, MaterialFiles? files})
    : files = files ?? const LocalMaterialFiles() {
    notebook.addListener(notifyListeners);
  }
  final NotebookController notebook;
  final MaterialFiles files;
  final bool demo;
  WorkspaceSection section = WorkspaceSection.desk;
  String? pupilId, materialId;
  EditorSession? editor;
  DateTime date = DateTime.now();
  String query = '';
  final selectedMaterials = <String>{};
  bool busy = false;
  Future<void> _editorQueue = Future.value();
  Future<void> _sequence(Future<void> Function() action) {
    final next = _editorQueue.catchError((Object _) {}).then((_) => action());
    _editorQueue = next;
    return next;
  }

  NotebookRepository get repository => notebook.repository;
  List<Pupil> get pupils =>
      notebook.pupils.where((p) => !p.archived && !p.deleted).toList();
  List<ClassroomDocument> get materials => notebook.classroom
      .where((d) => !d.deleted && d.kind == ClassroomKind.material)
      .toList();
  Pupil? get pupil => pupils.where((p) => p.id == pupilId).firstOrNull;
  ClassroomDocument? get material =>
      materials.where((m) => m.id == materialId).firstOrNull;
  String name(String? id) => id == null
      ? 'FLEX-Klasse'
      : notebook.pupils.where((p) => p.id == id).firstOrNull?.name ??
            'Archivierter Schüler';
  int get draftCount =>
      notebook.drafts.length +
      notebook.schoolDrafts.length +
      notebook.dialogDrafts.length;
  List<CalendarItem> agenda(DateTime day) =>
      calendarItems(notebook.currentSnapshot, dateOnly(day), dateOnly(day));
  void navigate(WorkspaceSection value) {
    section = value;
    query = '';
    selectedMaterials.clear();
    notifyListeners();
  }

  void search(String value) {
    query = value;
    notifyListeners();
  }

  void selectPupil(String? id) {
    pupilId = id;
    notifyListeners();
  }

  void setDate(DateTime value) {
    date = value;
    notifyListeners();
  }

  Future<void> parkEditor() => _sequence(_parkEditor);
  Future<void> _parkEditor() async {
    final previous = editor;
    if (previous == null) return;
    await previous.flush(); // failure keeps the input open
    previous.dispose();
    editor = null;
    await notebook.reload();
    notifyListeners();
  }

  Future<void> start(EntryKind kind, {String? pupil, DateTime? onDate}) =>
      _sequence(() async {
        final owner =
            pupil ??
            (section == WorkspaceSection.journal ? pupilId : null) ??
            (kind.school ? pupils.firstOrNull?.id : null);
        if (kind.school && owner == null) {
          throw const DomainError(
            'Bitte zuerst einen Schüler zur Klasse hinzufügen.',
          );
        }
        await _parkEditor();
        materialId = null;
        editor = EditorSession(
          repository,
          kind,
          newEntry(kind, pupilId: owner, date: onDate ?? date),
        );
        if (kind == EntryKind.returnList && owner != null) {
          editor!.data['participants'] = [
            {
              'pupilId': owner,
              'name': name(owner),
              'status': 'open',
              'note': '',
              'paid': 0,
            },
          ];
        }
        notifyListeners();
      });

  Future<void> edit(Object value) => _sequence(() async {
    await _parkEditor();
    materialId = null;
    if (value is SchoolRecord) {
      editor = EditorSession(
        repository,
        EntryKind.values.byName(value.kind.name),
        value.toJson(),
      );
    } else if (value is OrgaEntry) {
      editor = EditorSession(
        repository,
        value.isAppointment
            ? EntryKind.appointment
            : value.isTask
            ? EntryKind.task
            : EntryKind.note,
        value.toJson(),
      );
    } else if (value is ClassroomDocument) {
      if (value.kind == ClassroomKind.material) {
        materialId = value.id;
      } else if (EntryKind.values.any((k) => k.name == value.kind.name)) {
        editor = EditorSession(
          repository,
          EntryKind.values.byName(value.kind.name),
          value.toJson(),
        );
      }
    } else if (value is SchoolDraft) {
      editor = EditorSession(
        repository,
        EntryKind.values.byName(value.record.kind.name),
        value.record.toJson(),
        draftId: value.id,
        draftRevision: value.editRevision,
      );
    } else if (value is EditDraft) {
      final e = value.entry;
      editor = EditorSession(
        repository,
        e.isAppointment
            ? EntryKind.appointment
            : e.isTask
            ? EntryKind.task
            : EntryKind.note,
        e.toJson(),
        draftId: value.id,
        draftRevision: value.editRevision,
      );
    } else if (value is DialogDraft &&
        value.type == 'classroom' &&
        EntryKind.values.any((k) => k.name == value.data['kind'])) {
      editor = EditorSession(
        repository,
        EntryKind.values.byName(value.data['kind'] as String),
        value.data,
        draftId: value.id,
        draftRevision: value.revision,
      );
    } else {
      throw const DomainError(
        'Dieser Entwurf wird im zugehörigen Android-Editor weiterbearbeitet. Er bleibt in Sicherungen enthalten.',
      );
    }
    notifyListeners();
  });

  Future<void> openCalendar(CalendarItem item) async {
    final value = item.entry ?? item.record ?? item.document;
    if (value != null) await edit(value);
  }

  Future<void> commitEditor() => _sequence(() async {
    if (editor == null || busy) return;
    busy = true;
    notifyListeners();
    try {
      await editor!.commit();
      editor!.dispose();
      editor = null;
      await notebook.reload();
    } finally {
      busy = false;
      notifyListeners();
    }
  });

  Future<void> discardEditor() => _sequence(() async {
    if (editor == null || busy) return;
    await editor!.discard();
    editor!.dispose();
    editor = null;
    await notebook.reload();
    notifyListeners();
  });

  Future<void> importFiles(
    List<({String name, Uint8List bytes})> selected, {
    String? assignTo,
  }) async {
    // Validate the whole batch before writing, then commit all references once.
    final docs = <ClassroomDocument>[], written = <String>[];
    for (final file in selected) {
      validateMaterialBytes(
        file.bytes,
        file.name.split('.').last.toLowerCase(),
      );
    }
    var committed = false;
    try {
      for (final file in selected) {
        final key = newId();
        await files.write(key, file.bytes);
        written.add(key);
        docs.add(
          ClassroomDocument.create(ClassroomKind.material, file.name, {
            'name': file.name,
            'extension': file.name.split('.').last.toLowerCase(),
            'localKey': key,
            'size': file.bytes.length,
            'documentType': 'other',
            if (assignTo != null) 'pupilIds': [assignTo],
          }),
        );
      }
      await repository.saveClassroomDocuments(docs);
      committed = true;
    } finally {
      if (!committed) {
        for (final key in written) {
          await files.remove(key);
        }
      }
    }
    await notebook.reload();
    if (docs.isNotEmpty) await edit(docs.first);
  }

  Future<void> assignMaterials(
    Iterable<String> ids,
    Iterable<String> pupils,
    String? date,
  ) async {
    final selected = pupils.toList();
    if (selected.isEmpty) {
      throw const DomainError('Bitte mindestens einen Schüler auswählen.');
    }
    await notebook.saveClassroomBatch([
      for (final m in materials.where((m) => ids.contains(m.id)))
        assignMaterialPupils(m, selected, {
          for (final id in selected) id: [?date],
        }, add: true),
    ]);
  }

  Future<void> prepareForDay(Iterable<String> ids, DateTime day) async {
    final available = materials.map((m) => m.id).toSet();
    final requested = ids.toSet();
    if (requested.isEmpty || !available.containsAll(requested)) {
      throw const DomainError(
        'Die Materialauswahl hat sich geändert. Bitte erneut auswählen.',
      );
    }
    await notebook.saveClassroom(
      prepareMaterials(notebook.classroom, dateOnly(day), requested),
    );
  }

  Future<void> moveAppointment(
    CalendarItem item,
    DateTime day,
    String time,
  ) async {
    final entry = item.entry;
    if (entry == null || !entry.isAppointment) return;
    final start = clockMinutes(entry.appointmentTime),
        end = clockMinutes(entry.appointmentEndTime);
    final next = clockMinutes(time);
    final duration = end > start ? end - start : 60;
    if (next + duration > 1440) {
      throw const DomainError('Der Termin würde über Mitternacht hinausgehen.');
    }
    await notebook.saveEntry(
      entry.copyWith(
        appointmentDate: dateOnly(day),
        appointmentTime: time,
        appointmentEndTime: minutesClock(next + duration),
      ),
    );
  }

  @override
  void dispose() {
    notebook.removeListener(notifyListeners);
    editor?.dispose();
    super.dispose();
  }
}
