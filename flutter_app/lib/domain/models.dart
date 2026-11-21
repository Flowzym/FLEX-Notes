import 'document_scanner.dart' show validateScanData;

import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;
String newId() => const Uuid().v4();
String utcNow() => DateTime.now().toUtc().toIso8601String();
String dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
bool validDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && dateOnly(parsed) == value;
}

class DomainError implements Exception {
  const DomainError(this.message);
  final String message;
  @override
  String toString() => message;
}

class StaleRevision extends DomainError {
  const StaleRevision()
    : super(
        'Dieser Eintrag wurde inzwischen geändert. Dein Entwurf bleibt erhalten. Öffne die aktuelle Version, bevor du die Änderungen übernimmst.',
      );
}

class Pupil {
  const Pupil({
    required this.id,
    required this.name,
    this.color = 0xffa8bb80,
    this.archived = false,
    this.deleted = false,
    this.createdAtUtc,
    this.updatedAtUtc,
    this.deletedAtUtc,
    this.revision = 0,
  });
  final String id, name;
  final int color, revision;
  final bool archived, deleted;
  final String? createdAtUtc, updatedAtUtc, deletedAtUtc;
  Pupil copyWith({
    String? name,
    int? color,
    bool? archived,
    bool? deleted,
    int? revision,
    String? createdAtUtc,
    String? updatedAtUtc,
    Object? deletedAtUtc = _unset,
  }) => Pupil(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    archived: archived ?? this.archived,
    revision: revision ?? this.revision,
    deleted: deleted ?? this.deleted,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    deletedAtUtc: identical(deletedAtUtc, _unset)
        ? this.deletedAtUtc
        : deletedAtUtc as String?,
  );
  void validate() {
    if (id.isEmpty || name.trim().isEmpty || name.trim().length > 80) {
      throw const DomainError('Bitte einen Namen mit 1–80 Zeichen eingeben.');
    }
    if (deleted && !archived ||
        [createdAtUtc, updatedAtUtc, deletedAtUtc].whereType<String>().any(
          (s) => !s.endsWith('Z') || DateTime.tryParse(s) == null,
        )) {
      throw const DomainError('Ungültiger Schülerstatus oder Zeitpunkt.');
    }
    if (color < 0 || color > 0xffffffff || revision < 0) {
      throw const DomainError('Ungültige Schülerdaten.');
    }
  }

  Json toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'archived': archived,
    'deleted': deleted,
    'createdAtUtc': createdAtUtc,
    'updatedAtUtc': updatedAtUtc,
    'deletedAtUtc': deletedAtUtc,
    'revision': revision,
  };
  factory Pupil.fromJson(Json j) => Pupil(
    id: j['id'] as String,
    name: j['name'] as String,
    color: j['color'] as int,
    archived: j['archived'] as bool,
    deleted: j['deleted'] as bool? ?? false,
    createdAtUtc: j['createdAtUtc'] as String?,
    updatedAtUtc: j['updatedAtUtc'] as String?,
    deletedAtUtc: j['deletedAtUtc'] as String?,
    revision: j['revision'] as int,
  );
}

class CheckItem {
  const CheckItem({required this.id, required this.text, this.checked = false});
  final String id, text;
  final bool checked;
  CheckItem copyWith({String? text, bool? checked}) => CheckItem(
    id: id,
    text: text ?? this.text,
    checked: checked ?? this.checked,
  );
  Json toJson() => {'id': id, 'text': text, 'checked': checked};
  factory CheckItem.fromJson(Json j) => CheckItem(
    id: j['id'] as String,
    text: j['text'] as String,
    checked: j['checked'] as bool,
  );
}

enum ReminderState { none, planned, acknowledged, cancelled }

const _unset = Object();

void validateOrgaTags(List<String> tags) {
  if (tags.length > 30 ||
      tags.any(
        (tag) => tag.trim().isEmpty || tag.length > 64 || tag.contains(','),
      ) ||
      tags.map((tag) => tag.trim().toLowerCase()).toSet().length !=
          tags.length) {
    throw const DomainError(
      'Bitte bis zu 30 unterschiedliche Tags mit je 1–64 Zeichen ohne Komma verwenden.',
    );
  }
}

class OrgaEntry {
  OrgaEntry({
    required this.id,
    this.pupilId,
    required this.title,
    this.body = '',
    this.otherParticipants = '',
    this.isTask = false,
    this.done = false,
    this.deleted = false,
    this.observedOn = '',
    this.observedTime = '',
    this.reminderText = '',
    this.reminderHasTime = true,
    this.appointmentDate,
    this.appointmentTime = '',
    this.appointmentEndTime = '',
    this.dueDate,
    this.reminderAtUtc,
    this.reminderZone = 'UTC',
    this.reminderState = ReminderState.none,
    this.needsCompletion = false,
    this.revision = 0,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    List<CheckItem> items = const [],
    List<String> tags = const [],
  }) : items = List.unmodifiable(items),
       tags = List.unmodifiable(tags);
  factory OrgaEntry.empty({String? pupilId}) {
    final now = utcNow();
    return OrgaEntry(
      id: newId(),
      pupilId: pupilId,
      title: '',
      observedOn: dateOnly(DateTime.now()),
      createdAtUtc: now,
      updatedAtUtc: now,
    );
  }
  final String id, title, body, reminderZone, createdAtUtc, updatedAtUtc;
  final String otherParticipants;
  final String? pupilId, dueDate, reminderAtUtc, appointmentDate;
  final String appointmentTime, appointmentEndTime;
  final bool isTask, done, needsCompletion, deleted, reminderHasTime;
  final String observedOn, observedTime, reminderText;
  final int revision;
  final ReminderState reminderState;
  final List<CheckItem> items;
  final List<String> tags;
  bool get isAppointment => appointmentDate != null;
  bool appointmentIsUpcoming(DateTime now) {
    if (appointmentDate == null) return false;
    final day = dateOnly(now);
    final compared = appointmentDate!.compareTo(day);
    return compared > 0 ||
        (compared == 0 &&
            (appointmentTime.isEmpty ||
                appointmentTime.compareTo(
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                    ) >=
                    0));
  }

  bool get pending =>
      !deleted &&
      ((isTask && !done) ||
          appointmentIsUpcoming(DateTime.now()) ||
          reminderState == ReminderState.planned);
  String? get nextDate {
    final dates = [
      if (appointmentIsUpcoming(DateTime.now())) appointmentDate!,
      if (isTask && !done && dueDate != null) dueDate!,
      if (reminderState == ReminderState.planned && reminderAtUtc != null)
        dateOnly(DateTime.parse(reminderAtUtc!).toLocal()),
    ]..sort();
    return dates.isEmpty ? null : dates.first;
  }

  OrgaEntry copyWith({
    Object? pupilId = _unset,
    String? title,
    String? body,
    String? otherParticipants,
    bool? isTask,
    bool? done,
    bool? deleted,
    String? observedOn,
    String? observedTime,
    String? reminderText,
    bool? reminderHasTime,
    Object? appointmentDate = _unset,
    String? appointmentTime,
    String? appointmentEndTime,
    Object? dueDate = _unset,
    Object? reminderAtUtc = _unset,
    String? reminderZone,
    ReminderState? reminderState,
    bool? needsCompletion,
    int? revision,
    String? updatedAtUtc,
    List<CheckItem>? items,
    List<String>? tags,
  }) => OrgaEntry(
    id: id,
    pupilId: identical(pupilId, _unset) ? this.pupilId : pupilId as String?,
    title: title ?? this.title,
    body: body ?? this.body,
    otherParticipants: otherParticipants ?? this.otherParticipants,
    isTask: isTask ?? this.isTask,
    done: done ?? this.done,
    deleted: deleted ?? this.deleted,
    observedOn: observedOn ?? this.observedOn,
    observedTime: observedTime ?? this.observedTime,
    reminderText: reminderText ?? this.reminderText,
    reminderHasTime: reminderHasTime ?? this.reminderHasTime,
    appointmentDate: identical(appointmentDate, _unset)
        ? this.appointmentDate
        : appointmentDate as String?,
    appointmentTime: appointmentTime ?? this.appointmentTime,
    appointmentEndTime: appointmentEndTime ?? this.appointmentEndTime,
    dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as String?,
    reminderAtUtc: identical(reminderAtUtc, _unset)
        ? this.reminderAtUtc
        : reminderAtUtc as String?,
    reminderZone: reminderZone ?? this.reminderZone,
    reminderState: reminderState ?? this.reminderState,
    needsCompletion: needsCompletion ?? this.needsCompletion,
    revision: revision ?? this.revision,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    items: items ?? this.items,
    tags: tags ?? this.tags,
  );
  OrgaEntry complete() {
    if (!isTask) throw const DomainError('Eine Notiz ist keine Aufgabe.');
    return copyWith(
      done: true,
      items: items.map((i) => i.copyWith(checked: true)).toList(),
      reminderState: reminderState == ReminderState.planned
          ? ReminderState.cancelled
          : reminderState,
    );
  }

  OrgaEntry withTaskItems(List<CheckItem> next) {
    final changed = copyWith(items: next);
    if (!isTask) return changed;
    if (next.isNotEmpty && next.every((i) => i.checked)) {
      return changed.complete();
    }
    return next.any((i) => !i.checked) ? changed.reopen() : changed;
  }

  OrgaEntry reopen() => copyWith(done: false);
  OrgaEntry acknowledge() {
    if (reminderState != ReminderState.planned) {
      throw const DomainError('Keine aktive Erinnerung vorhanden.');
    }
    return copyWith(reminderState: ReminderState.acknowledged);
  }

  void validate() {
    validateOrgaTags(tags);
    if (observedOn.isNotEmpty && !validDate(observedOn) ||
        observedTime.isNotEmpty &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(observedTime)) {
      throw const DomainError('Ungültiges Beobachtungsdatum.');
    }
    if (id.isEmpty || title.trim().isEmpty || title.trim().length > 160) {
      throw const DomainError('Bitte einen Titel mit 1–160 Zeichen eingeben.');
    }
    if (otherParticipants.length > 2000) {
      throw const DomainError('Bitte Namen auf 2000 Zeichen begrenzen.');
    }
    if ((appointmentDate != null && !validDate(appointmentDate!)) ||
        (appointmentTime.isNotEmpty &&
            (appointmentDate == null ||
                !RegExp(
                  r'^([01]\d|2[0-3]):[0-5]\d$',
                ).hasMatch(appointmentTime))) ||
        (isAppointment && isTask)) {
      throw const DomainError('Bitte einen gültigen Termin wählen.');
    }
    if (appointmentEndTime.isNotEmpty &&
        (appointmentTime.isEmpty ||
            !RegExp(
              r'^(?:([01]\d|2[0-3]):[0-5]\d|24:00)$',
            ).hasMatch(appointmentEndTime) ||
            appointmentEndTime.compareTo(appointmentTime) <= 0)) {
      throw const DomainError('Das Terminende muss nach dem Beginn liegen.');
    }
    if (!isTask && (done || dueDate != null)) {
      throw const DomainError(
        'Nur Aufgaben haben einen Aufgabentermin oder Erledigtstatus.',
      );
    }
    if (dueDate != null && !validDate(dueDate!)) {
      throw const DomainError('Ungültiger Aufgabentermin.');
    }
    if ((reminderAtUtc == null) != (reminderState == ReminderState.none)) {
      throw const DomainError('Erinnerung benötigt einen gültigen Zeitpunkt.');
    }
    if (reminderAtUtc != null &&
        (!reminderAtUtc!.endsWith('Z') ||
            DateTime.tryParse(reminderAtUtc!) == null ||
            reminderZone.trim().isEmpty)) {
      throw const DomainError(
        'Erinnerungszeit muss UTC und eine Zeitzone enthalten.',
      );
    }
    if ((done || deleted) && reminderState == ReminderState.planned) {
      throw const DomainError(
        'Erledigte Aufgaben haben keine aktive Erinnerung.',
      );
    }
    if (items.any((i) => i.id.isEmpty || i.text.trim().isEmpty) ||
        items.map((i) => i.id).toSet().length != items.length) {
      throw const DomainError(
        'Checklistenpunkte benötigen eindeutige IDs und einen Text.',
      );
    }
    if (revision < 0 ||
        DateTime.tryParse(createdAtUtc) == null ||
        DateTime.tryParse(updatedAtUtc) == null) {
      throw const DomainError('Ungültige Versionsdaten.');
    }
  }

  Json toJson() => {
    'id': id,
    'pupilId': pupilId,
    'title': title,
    'body': body,
    'otherParticipants': otherParticipants,
    'isTask': isTask,
    'done': done,
    'deleted': deleted,
    'observedOn': observedOn,
    'observedTime': observedTime,
    'reminderText': reminderText,
    'reminderHasTime': reminderHasTime,
    'appointmentDate': appointmentDate,
    'appointmentTime': appointmentTime,
    'appointmentEndTime': appointmentEndTime,
    'dueDate': dueDate,
    'reminderAtUtc': reminderAtUtc,
    'reminderZone': reminderZone,
    'reminderState': reminderState.name,
    'needsCompletion': needsCompletion,
    'revision': revision,
    'createdAtUtc': createdAtUtc,
    'updatedAtUtc': updatedAtUtc,
    'items': items.map((i) => i.toJson()).toList(),
    'tags': tags,
  };
  factory OrgaEntry.fromJson(Json j) => OrgaEntry(
    id: j['id'] as String,
    pupilId: j['pupilId'] as String?,
    title: j['title'] as String,
    body: j['body'] as String,
    otherParticipants: j['otherParticipants'] as String? ?? '',
    tags: List<String>.from(j['tags'] as List? ?? const []),
    isTask: j['isTask'] as bool,
    done: j['done'] as bool,
    deleted: j['deleted'] as bool? ?? false,
    observedOn: j['observedOn'] as String? ?? '',
    observedTime: j['observedTime'] as String? ?? '',
    reminderText: j['reminderText'] as String? ?? '',
    reminderHasTime: j['reminderHasTime'] as bool? ?? true,
    appointmentDate: j['appointmentDate'] as String?,
    appointmentTime: j['appointmentTime'] as String? ?? '',
    appointmentEndTime: j['appointmentEndTime'] as String? ?? '',
    dueDate: j['dueDate'] as String?,
    reminderAtUtc: j['reminderAtUtc'] as String?,
    reminderZone: j['reminderZone'] as String,
    reminderState: ReminderState.values.byName(j['reminderState'] as String),
    needsCompletion: j['needsCompletion'] as bool,
    revision: j['revision'] as int,
    createdAtUtc: j['createdAtUtc'] as String,
    updatedAtUtc: j['updatedAtUtc'] as String,
    items: (j['items'] as List)
        .map((e) => CheckItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

/// Retains type-specific inputs while an Orga draft changes its active type.
/// Published entries contain only the values belonging to their final type.
class OrgaTypeDraft {
  const OrgaTypeDraft({
    this.dueDate,
    this.done = false,
    this.appointmentDate,
    this.appointmentTime = '',
    this.appointmentEndTime = '',
    this.appointmentTags = const [],
  });
  final String? dueDate, appointmentDate;
  final bool done;
  final String appointmentTime, appointmentEndTime;
  final List<String> appointmentTags;

  OrgaTypeDraft remember(OrgaEntry entry) => OrgaTypeDraft(
    dueDate: entry.isTask ? entry.dueDate : dueDate,
    done: entry.isTask ? entry.done : done,
    appointmentDate: entry.isAppointment
        ? entry.appointmentDate
        : appointmentDate,
    appointmentTime: entry.isAppointment
        ? entry.appointmentTime
        : appointmentTime,
    appointmentEndTime: entry.isAppointment
        ? entry.appointmentEndTime
        : appointmentEndTime,
    appointmentTags: entry.isAppointment ? entry.tags : appointmentTags,
  );

  OrgaEntry select(OrgaEntry entry, String kind) {
    if (!const {'note', 'task', 'appointment'}.contains(kind)) {
      throw const DomainError('Unbekannter Orga-Typ.');
    }
    return entry.copyWith(
      isTask: kind == 'task',
      done: kind == 'task' && done,
      dueDate: kind == 'task' ? dueDate : null,
      appointmentDate: kind == 'appointment'
          ? appointmentDate ?? dateOnly(DateTime.now())
          : null,
      appointmentTime: kind == 'appointment' ? appointmentTime : '',
      appointmentEndTime: kind == 'appointment' ? appointmentEndTime : '',
      tags: kind == 'appointment' ? appointmentTags : const [],
      reminderState:
          kind == 'task' && done && entry.reminderState == ReminderState.planned
          ? ReminderState.cancelled
          : entry.reminderState,
    );
  }

  Json toJson({OrgaEntry? excluding}) => {
    if (excluding?.isTask != true) ...{'dueDate': dueDate, 'done': done},
    if (excluding?.isAppointment != true) ...{
      'appointmentDate': appointmentDate,
      'appointmentTime': appointmentTime,
      'appointmentEndTime': appointmentEndTime,
      'appointmentTags': appointmentTags,
    },
  };

  factory OrgaTypeDraft.fromJson(Json json) {
    final result = OrgaTypeDraft(
      dueDate: json['dueDate'] as String?,
      done: json['done'] as bool? ?? false,
      appointmentDate: json['appointmentDate'] as String?,
      appointmentTime: json['appointmentTime'] as String? ?? '',
      appointmentEndTime: json['appointmentEndTime'] as String? ?? '',
      appointmentTags: List<String>.unmodifiable(
        json['appointmentTags'] as List? ?? const [],
      ),
    );
    validateOrgaTags(result.appointmentTags);
    if (result.dueDate != null && !validDate(result.dueDate!) ||
        result.appointmentDate != null && !validDate(result.appointmentDate!) ||
        result.appointmentTime.isNotEmpty &&
            (result.appointmentDate == null ||
                !RegExp(
                  r'^([01]\d|2[0-3]):[0-5]\d$',
                ).hasMatch(result.appointmentTime))) {
      throw const DomainError('Ungültige Datumsangaben im Orga-Entwurf.');
    }
    if (result.appointmentEndTime.isNotEmpty &&
        (result.appointmentTime.isEmpty ||
            !RegExp(
              r'^(?:([01]\d|2[0-3]):[0-5]\d|24:00)$',
            ).hasMatch(result.appointmentEndTime) ||
            result.appointmentEndTime.compareTo(result.appointmentTime) <= 0)) {
      throw const DomainError('Ungültiges Terminende im Entwurf.');
    }
    return result;
  }
}

class EditDraft {
  const EditDraft({
    required this.id,
    required this.entry,
    required this.updatedAtUtc,
    this.editRevision = 0,
    this.baseline,
    this.typeDraft = const OrgaTypeDraft(),
  });
  final String id, updatedAtUtc;
  final OrgaEntry entry;
  final int editRevision;
  final String? baseline;
  final OrgaTypeDraft typeDraft;
}

class DialogDraft {
  const DialogDraft({
    required this.id,
    required this.type,
    required this.ownerId,
    required this.data,
    required this.updatedAtUtc,
    this.revision = 0,
    this.baseline,
  });
  final String id, type, ownerId, updatedAtUtc;
  final Json data;
  final int revision;
  final String? baseline;
  Json toJson() => {
    'format': 'flex-dialog-draft-1',
    'id': id,
    'type': type,
    'ownerId': ownerId,
    'data': data,
    'revision': revision,
    'baseline': ?baseline,
    'updatedAtUtc': updatedAtUtc,
  };
  factory DialogDraft.fromJson(Json j) {
    if (j['format'] != 'flex-dialog-draft-1' ||
        ![
          'pupil',
          'context',
          'bulk',
          'catalog',
          'classroom',
          'scan',
        ].contains(j['type']) ||
        j['data'] is! Map ||
        j['revision'] is! int ||
        (j['revision'] as int) < 0 ||
        j['id'] is! String ||
        (j['id'] as String).isEmpty ||
        j['ownerId'] is! String ||
        DateTime.tryParse(j['updatedAtUtc'] as String? ?? '') == null) {
      throw const DomainError('Ungültiger Dialogentwurf.');
    }
    final data = Json.from(j['data'] as Map);
    if (j['type'] == 'scan') {
      validateScanData(data);
    } else if (j['type'] == 'pupil') {
      final pupil = Pupil.fromJson(data);
      final edit = data['_materialEdit'];
      if (edit != null &&
          (edit is! Map ||
              edit['year'] is! String ||
              !RegExp(r'^\d{4}-\d{2}$').hasMatch(edit['year'] as String) ||
              edit['code'] is! String ||
              edit['aliases'] is! String ||
              edit['revision'] is! int ||
              (edit['revision'] as int) < 0)) {
        throw const DomainError('Ungültiger Entwurf für das Materialkürzel.');
      }
      if (pupil.id != j['ownerId'] ||
          pupil.color < 0 ||
          pupil.color > 0xffffffff ||
          pupil.revision < 0) {
        throw const DomainError('Ungültiger Schülerentwurf.');
      }
    } else if (j['type'] == 'catalog') {
      if (!['social', 'work'].contains(data['kind']) ||
          !['positive', 'neutral', 'negative'].contains(data['tone']) ||
          (data.containsKey('neutral') &&
              (data['neutral'] is! List ||
                  !(data['neutral'] as List).every((v) => v is String))) ||
          !['positive', 'negative'].every(
            (tone) =>
                data[tone] is List &&
                (data[tone] as List).every((v) => v is String),
          )) {
        throw const DomainError('Ungültiger Auswahlentwurf.');
      }
    } else if (j['type'] == 'context') {
      if (data['revision'] is! int ||
          data['text'] is! String ||
          data['participantIds'] is! List) {
        throw const DomainError('Ungültiger Kontextentwurf.');
      }
    } else if (j['type'] == 'classroom') {
      if (data['format'] != 'flex-classroom-1' ||
          data['id'] != j['ownerId'] ||
          ![
            'lesson',
            'holiday',
            'material',
            'materialSet',
            'timetable',
            'plan',
            'returnList',
          ].contains(data['kind']) ||
          data['revision'] is! int ||
          (data['revision'] as int) < 0 ||
          data['title'] is! String ||
          data['deleted'] is! bool ||
          [
            'date',
            'start',
            'end',
            'subject',
            'teacher',
            'timetableId',
            'room',
            'note',
            'url',
            'topic',
            'week',
            'type',
            'dueDate',
            'endDate',
            'status',
            'followUp',
            'otherParticipants',
            'documentType',
            'audience',
          ].any((key) => data.containsKey(key) && data[key] is! String) ||
          [
            'materialIds',
            'pupilIds',
            'lessonIds',
            'tags',
            'participants',
            'exceptions',
            'slots',
            'slotIds',
          ].any((key) => data.containsKey(key) && data[key] is! List)) {
        throw const DomainError('Ungültiger Klassenentwurf.');
      }
    } else if (j['type'] == 'bulk') {
      if (!['social', 'work', 'homework', 'orga'].contains(data['kind']) ||
          (data.containsKey('otherParticipants') &&
              data['otherParticipants'] is! String) ||
          data['recipients'] is! List ||
          data['observedOn'] is! String ||
          !(data['recipients'] as List).every((v) => v is String) ||
          data['individual'] is! Map) {
        throw const DomainError('Ungültiger Gruppenentwurf.');
      }
    }
    return DialogDraft(
      id: j['id'] as String,
      type: j['type'] as String,
      ownerId: j['ownerId'] as String,
      data: Json.from(j['data'] as Map),
      baseline: j['baseline'] as String?,
      revision: j['revision'] as int,
      updatedAtUtc: j['updatedAtUtc'] as String,
    );
  }
}

/// User preferences independent from the fixed FLEX visual language.
/// Legacy appearance keys are intentionally not restored from databases/backups.
enum MaterialLayout { list, compact, grid }

class Appearance {
  const Appearance({
    this.mode = 'light',
    this.textScale = 1,
    this.defaultObservationTone = 'neutral',
    this.calendarDefaultView = 'day',
    this.navigationSwipeNext = 'left',
    this.liveDefaultPage = 1,
    this.organisationDefaultPage = 0,
    this.materialDefaultPage = 0,
    this.moreDefaultPage = 0,
    this.materialLayout = MaterialLayout.list,
    this.weekFolderWeekends = false,
    this.materialSort = 'recent',
    this.shortcutOrder = const ['goal', 'social', 'work', 'homework', 'orga'],
  });
  final String mode, defaultObservationTone, materialSort, calendarDefaultView;
  final String navigationSwipeNext;
  final int liveDefaultPage,
      organisationDefaultPage,
      materialDefaultPage,
      moreDefaultPage;
  final double textScale;
  final MaterialLayout materialLayout;
  final bool weekFolderWeekends;
  bool get materialGrid => materialLayout == MaterialLayout.grid;
  final List<String> shortcutOrder;

  Appearance copyWith({String? mode, double? textScale}) =>
      patch({'mode': ?mode, 'textScale': ?textScale});
  Appearance change(Json changes) => patch(changes);
  Appearance patch(Json changes) => Appearance.fromJson({
    ...toJson(),
    if (changes.containsKey('materialGrid')) 'materialLayout': null,
    ...changes,
  });
  Json toJson() => {
    'designVersion': 1,
    'mode': mode,
    'textScale': textScale,
    'defaultObservationTone': defaultObservationTone,
    'calendarDefaultView': calendarDefaultView,
    'navigationSwipeVersion': 1,
    'navigationSwipeNext': navigationSwipeNext,
    'liveDefaultPage': liveDefaultPage,
    'organisationDefaultPage': organisationDefaultPage,
    'materialDefaultPage': materialDefaultPage,
    'moreDefaultPage': moreDefaultPage,
    'materialGrid': materialGrid,
    'materialLayout': materialLayout.name,
    'weekFolderWeekends': weekFolderWeekends,
    'materialSort': materialSort,
    'shortcutOrder': shortcutOrder,
  };

  factory Appearance.fromJson(Json source) {
    final swipeNext = source['navigationSwipeNext'] as String? ?? 'left';
    if (!['left', 'right'].contains(swipeNext)) {
      throw const DomainError('Ungültige Wischrichtung.');
    }
    final a = Appearance(
      // The first opening after the redesign starts with the approved cream theme.
      // Subsequent choices round-trip normally, including through backups.
      mode: source['designVersion'] == 1
          ? source['mode'] as String? ?? 'light'
          : 'light',
      textScale: (source['textScale'] as num? ?? 1).toDouble(),
      defaultObservationTone:
          source['defaultObservationTone'] as String? ?? 'neutral',
      calendarDefaultView: source['calendarDefaultView'] as String? ?? 'day',
      // Build 80 persisted the reversed default with every appearance update.
      // Correct that once; subsequent explicit choices round-trip normally.
      navigationSwipeNext: source['navigationSwipeVersion'] == 1
          ? swipeNext
          : 'left',
      liveDefaultPage: source['liveDefaultPage'] as int? ?? 1,
      organisationDefaultPage: source['organisationDefaultPage'] as int? ?? 0,
      materialDefaultPage: source['materialDefaultPage'] as int? ?? 0,
      moreDefaultPage: source['moreDefaultPage'] as int? ?? 0,
      weekFolderWeekends: source['weekFolderWeekends'] == true,
      materialLayout:
          MaterialLayout.values
              .where((v) => v.name == source['materialLayout'])
              .firstOrNull ??
          (source['materialGrid'] == true
              ? MaterialLayout.grid
              : MaterialLayout.list),
      materialSort:
          const {
            'recent',
            'name',
            'format',
            'subject',
          }.contains(source['materialSort'])
          ? source['materialSort'] as String
          : 'recent',
      shortcutOrder: List<String>.unmodifiable(
        (source['shortcutOrder'] as List? ??
                const ['goal', 'social', 'work', 'homework', 'orga'])
            .cast<String>(),
      ),
    );
    if (!['day', 'week', 'month'].contains(a.calendarDefaultView) ||
        !['left', 'right'].contains(a.navigationSwipeNext) ||
        ![0, 1, 2].contains(a.liveDefaultPage) ||
        ![0, 3, 2, 4].contains(a.organisationDefaultPage) ||
        ![0, 1, 2, 3, 4].contains(a.materialDefaultPage) ||
        ![0, 1, 2, 3, 4].contains(a.moreDefaultPage) ||
        !['light', 'dark', 'system'].contains(a.mode) ||
        !a.textScale.isFinite ||
        a.textScale < .8 ||
        a.textScale > 1.6 ||
        ![
          'positive',
          'neutral',
          'negative',
        ].contains(a.defaultObservationTone) ||
        a.shortcutOrder.length != 5 ||
        a.shortcutOrder.toSet().length != 5 ||
        !a.shortcutOrder.toSet().containsAll(const [
          'goal',
          'social',
          'work',
          'homework',
          'orga',
        ])) {
      throw const DomainError('Ungültige Darstellung.');
    }
    return a;
  }
}
