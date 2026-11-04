import 'dart:convert';
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
        'Dieser Eintrag wurde inzwischen geändert. Dein Entwurf bleibt erhalten. Öffne die aktuelle Fassung, bevor du die Änderungen übernimmst.',
      );
}

class Pupil {
  const Pupil({
    required this.id,
    required this.name,
    this.color = 0xffa8bb80,
    this.archived = false,
    this.revision = 0,
  });
  final String id, name;
  final int color, revision;
  final bool archived;
  Pupil copyWith({String? name, int? color, bool? archived, int? revision}) =>
      Pupil(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        archived: archived ?? this.archived,
        revision: revision ?? this.revision,
      );
  void validate() {
    if (id.isEmpty || name.trim().isEmpty || name.trim().length > 80) {
      throw const DomainError('Bitte einen Namen mit 1–80 Zeichen eingeben.');
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
    'revision': revision,
  };
  factory Pupil.fromJson(Json j) => Pupil(
    id: j['id'] as String,
    name: j['name'] as String,
    color: j['color'] as int,
    archived: j['archived'] as bool,
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

class OrgaEntry {
  OrgaEntry({
    required this.id,
    this.pupilId,
    required this.title,
    this.body = '',
    this.isTask = false,
    this.done = false,
    this.deleted = false,
    this.observedOn = '',
    this.observedTime = '',
    this.reminderText = '',
    this.reminderHasTime = true,
    this.appointmentDate,
    this.appointmentTime = '',
    this.dueDate,
    this.reminderAtUtc,
    this.reminderZone = 'UTC',
    this.reminderState = ReminderState.none,
    this.needsCompletion = false,
    this.revision = 0,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    List<CheckItem> items = const [],
  }) : items = List.unmodifiable(items);
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
  final String? pupilId, dueDate, reminderAtUtc, appointmentDate;
  final String appointmentTime;
  final bool isTask, done, needsCompletion, deleted, reminderHasTime;
  final String observedOn, observedTime, reminderText;
  final int revision;
  final ReminderState reminderState;
  final List<CheckItem> items;
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
    String? title,
    String? body,
    bool? isTask,
    bool? done,
    bool? deleted,
    String? observedOn,
    String? observedTime,
    String? reminderText,
    bool? reminderHasTime,
    Object? appointmentDate = _unset,
    String? appointmentTime,
    Object? dueDate = _unset,
    Object? reminderAtUtc = _unset,
    String? reminderZone,
    ReminderState? reminderState,
    bool? needsCompletion,
    int? revision,
    String? updatedAtUtc,
    List<CheckItem>? items,
  }) => OrgaEntry(
    id: id,
    pupilId: pupilId,
    title: title ?? this.title,
    body: body ?? this.body,
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
  );
  OrgaEntry complete() {
    if (!isTask) throw const DomainError('Eine Notiz ist keine Aufgabe.');
    return copyWith(
      done: true,
      reminderState: reminderState == ReminderState.planned
          ? ReminderState.cancelled
          : reminderState,
    );
  }

  OrgaEntry reopen() => copyWith(done: false);
  OrgaEntry acknowledge() {
    if (reminderState != ReminderState.planned) {
      throw const DomainError('Keine aktive Erinnerung vorhanden.');
    }
    return copyWith(reminderState: ReminderState.acknowledged);
  }

  void validate() {
    if (observedOn.isNotEmpty && !validDate(observedOn) ||
        observedTime.isNotEmpty &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(observedTime)) {
      throw const DomainError('Ungültiges Beobachtungsdatum.');
    }
    if (id.isEmpty || title.trim().isEmpty || title.trim().length > 160) {
      throw const DomainError('Bitte einen Titel mit 1–160 Zeichen eingeben.');
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
    'isTask': isTask,
    'done': done,
    'deleted': deleted,
    'observedOn': observedOn,
    'observedTime': observedTime,
    'reminderText': reminderText,
    'reminderHasTime': reminderHasTime,
    'appointmentDate': appointmentDate,
    'appointmentTime': appointmentTime,
    'dueDate': dueDate,
    'reminderAtUtc': reminderAtUtc,
    'reminderZone': reminderZone,
    'reminderState': reminderState.name,
    'needsCompletion': needsCompletion,
    'revision': revision,
    'createdAtUtc': createdAtUtc,
    'updatedAtUtc': updatedAtUtc,
    'items': items.map((i) => i.toJson()).toList(),
  };
  factory OrgaEntry.fromJson(Json j) => OrgaEntry(
    id: j['id'] as String,
    pupilId: j['pupilId'] as String?,
    title: j['title'] as String,
    body: j['body'] as String,
    isTask: j['isTask'] as bool,
    done: j['done'] as bool,
    deleted: j['deleted'] as bool? ?? false,
    observedOn: j['observedOn'] as String? ?? '',
    observedTime: j['observedTime'] as String? ?? '',
    reminderText: j['reminderText'] as String? ?? '',
    reminderHasTime: j['reminderHasTime'] as bool? ?? true,
    appointmentDate: j['appointmentDate'] as String?,
    appointmentTime: j['appointmentTime'] as String? ?? '',
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
  });
  final String? dueDate, appointmentDate;
  final bool done;
  final String appointmentTime;

  OrgaTypeDraft remember(OrgaEntry entry) => OrgaTypeDraft(
    dueDate: entry.isTask ? entry.dueDate : dueDate,
    done: entry.isTask ? entry.done : done,
    appointmentDate: entry.isAppointment
        ? entry.appointmentDate
        : appointmentDate,
    appointmentTime: entry.isAppointment
        ? entry.appointmentTime
        : appointmentTime,
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
    },
  };

  factory OrgaTypeDraft.fromJson(Json json) {
    final result = OrgaTypeDraft(
      dueDate: json['dueDate'] as String?,
      done: json['done'] as bool? ?? false,
      appointmentDate: json['appointmentDate'] as String?,
      appointmentTime: json['appointmentTime'] as String? ?? '',
    );
    if (result.dueDate != null && !validDate(result.dueDate!) ||
        result.appointmentDate != null && !validDate(result.appointmentDate!) ||
        result.appointmentTime.isNotEmpty &&
            (result.appointmentDate == null ||
                !RegExp(
                  r'^([01]\d|2[0-3]):[0-5]\d$',
                ).hasMatch(result.appointmentTime))) {
      throw const DomainError('Ungültige Datumsangaben im Orga-Entwurf.');
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
        !['pupil', 'context', 'bulk', 'catalog'].contains(j['type']) ||
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
    if (j['type'] == 'pupil') {
      final pupil = Pupil.fromJson(data);
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
    } else if (j['type'] == 'bulk') {
      if (!['social', 'work', 'homework', 'orga'].contains(data['kind']) ||
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

class Appearance {
  const Appearance({
    this.defaultObservationTone = 'neutral',
    this.mode = 'dark',
    this.accent = 0xffdae9a6,
    this.textScale = 1,
    this.uiScale = 1,
    this.fieldRadius = 14,
    this.buttonRadius = 28,
    this.modalRadius = 24,
    this.compact = false,
    this.dialogColor = 0,
    this.cardColor = 0,
    this.buttonColor = 0,
    this.headerOpacity = .18,
    this.footerOpacity = .18,
    this.cardOpacity = .28,
    this.buttonOpacity = .20,
    this.desktopImage = '',
    this.mobileImage = '',
    this.desktopFit = 'cover',
    this.mobileFit = 'cover',
    this.backgroundOpacity = .35,
    this.coupleSurfaces = false,
    this.serifHeaders = false,
    this.backgroundColor = 0xff4f6038,
    this.workspaceColor = 0,
    this.fieldColor = 0,
    this.modalColor = 0,
    this.workspaceOpacity = .12,
    this.fieldOpacity = .22,
    this.modalOpacity = 0,
    this.backgroundTint = 0xff203a2d,
    this.backgroundTintStrength = 0,
    this.backgroundDim = 0,
    this.imageEnabled = true,
    this.defaultTexture = true,
    this.readabilityProtection = false,
    this.desktopImageName = '',
    this.mobileImageName = '',
    this.cardRadius = 22,
    this.shortcutOrder = const ['goal', 'social', 'work', 'homework', 'orga'],
  });
  final String defaultObservationTone;
  final String mode, desktopImage, mobileImage, desktopFit, mobileFit;
  final int accent, dialogColor, cardColor, buttonColor;
  final double uiScale, fieldRadius, buttonRadius, modalRadius;
  final double textScale,
      headerOpacity,
      footerOpacity,
      cardOpacity,
      buttonOpacity,
      backgroundOpacity;
  final bool compact, coupleSurfaces, serifHeaders;
  final int backgroundColor,
      workspaceColor,
      fieldColor,
      modalColor,
      backgroundTint;
  final double workspaceOpacity,
      fieldOpacity,
      modalOpacity,
      backgroundTintStrength,
      backgroundDim,
      cardRadius;
  final bool imageEnabled, defaultTexture, readabilityProtection;
  final String desktopImageName, mobileImageName;
  final List<String> shortcutOrder;
  bool get hasImage => desktopImage.isNotEmpty || mobileImage.isNotEmpty;
  bool get imageActive => imageEnabled && (hasImage || defaultTexture);
  String imageForWidth(double width) => width <= 700
      ? (mobileImage.isEmpty ? desktopImage : mobileImage)
      : (desktopImage.isEmpty ? mobileImage : desktopImage);
  String fitForWidth(double width) => width <= 700 ? mobileFit : desktopFit;
  static const surfaceColors = [
    'workspaceColor',
    'cardColor',
    'buttonColor',
    'fieldColor',
    'modalColor',
    'dialogColor',
  ];
  static const surfaceOpacities = [
    'workspaceOpacity',
    'cardOpacity',
    'buttonOpacity',
    'fieldOpacity',
    'modalOpacity',
    'headerOpacity',
    'footerOpacity',
  ];
  Appearance change(Json changes) {
    final next = {...toJson(), ...changes};
    if (next['coupleSurfaces'] == true) {
      final color = !coupleSurfaces
          ? 'buttonColor'
          : surfaceColors.where((k) => changes.containsKey(k)).firstOrNull;
      final opacity = !coupleSurfaces
          ? 'buttonOpacity'
          : surfaceOpacities.where((k) => changes.containsKey(k)).firstOrNull;
      if (color != null) {
        for (final key in surfaceColors) {
          next[key] = next[color];
        }
      }
      if (opacity != null) {
        for (final key in surfaceOpacities) {
          next[key] = next[opacity];
        }
      }
    }
    if (!changes.containsKey('readabilityProtection') &&
        surfaceOpacities.any(
          (key) =>
              changes.containsKey(key) &&
              (next['coupleSurfaces'] == true ||
                  !['buttonOpacity', 'fieldOpacity'].contains(key)),
        )) {
      next['readabilityProtection'] = false;
    }
    return Appearance.fromJson(next);
  }

  Appearance preset(String id) => change({
    'imageEnabled': id != 'calm',
    'defaultTexture': false,
    'backgroundColor': 0xff4f6038,
    'workspaceColor': 0,
    'cardColor': 0,
    if (id != 'calm') ...{
      'backgroundTint': 0xff203a2d,
      'backgroundTintStrength': id == 'image-soft' ? .25 : .1,
      'backgroundDim': id == 'image-soft' ? .45 : .3,
    },
    'workspaceOpacity': id == 'calm'
        ? .88
        : id == 'image-soft'
        ? .65
        : .2,
    'cardOpacity': id == 'calm'
        ? .82
        : id == 'image-soft'
        ? .6
        : .2,
    'headerOpacity': id == 'image-clear' ? .2 : .65,
    'footerOpacity': id == 'image-clear' ? .2 : .65,
    'readabilityProtection': id != 'image-clear',
  });
  Appearance copyWith({
    String? mode,
    int? accent,
    double? textScale,
    bool? compact,
  }) => patch({
    'mode': ?mode,
    'accent': ?accent,
    'textScale': ?textScale,
    'compact': ?compact,
  });
  Appearance patch(Json changes) =>
      Appearance.fromJson({...toJson(), ...changes});
  Json toJson() => {
    'surfaceDefaultsVersion': 2,
    'mode': mode,
    'accent': accent,
    'textScale': textScale,
    'uiScale': uiScale,
    'fieldRadius': fieldRadius,
    'buttonRadius': buttonRadius,
    'modalRadius': modalRadius,
    'compact': compact,
    'dialogColor': dialogColor,
    'cardColor': cardColor,
    'buttonColor': buttonColor,
    'headerOpacity': headerOpacity,
    'footerOpacity': footerOpacity,
    'cardOpacity': cardOpacity,
    'buttonOpacity': buttonOpacity,
    'desktopImage': desktopImage,
    'mobileImage': mobileImage,
    'desktopFit': desktopFit,
    'mobileFit': mobileFit,
    'backgroundOpacity': backgroundOpacity,
    'coupleSurfaces': coupleSurfaces,
    'serifHeaders': serifHeaders,
    'backgroundColor': backgroundColor,
    'workspaceColor': workspaceColor,
    'fieldColor': fieldColor,
    'modalColor': modalColor,
    'workspaceOpacity': workspaceOpacity,
    'fieldOpacity': fieldOpacity,
    'modalOpacity': modalOpacity,
    'backgroundTint': backgroundTint,
    'backgroundTintStrength': backgroundTintStrength,
    'backgroundDim': backgroundDim,
    'imageEnabled': imageEnabled,
    'defaultTexture': defaultTexture,
    'readabilityProtection': readabilityProtection,
    'desktopImageName': desktopImageName,
    'mobileImageName': mobileImageName,
    'cardRadius': cardRadius,
    'shortcutOrder': shortcutOrder,
    'defaultObservationTone': defaultObservationTone,
  };
  factory Appearance.fromJson(Json source) {
    final j = {...source};
    const old = {
      'headerOpacity': .65,
      'footerOpacity': .65,
      'cardOpacity': .82,
      'buttonOpacity': .94,
      'fieldOpacity': .94,
      'workspaceOpacity': .88,
    };
    // Only migrate the unchanged automatic palette; preserve custom colors and alpha values.
    if (!j.containsKey('surfaceDefaultsVersion') &&
        j['coupleSurfaces'] != true &&
        surfaceColors.every((key) => (j[key] ?? 0) == 0) &&
        old.entries.every(
          (entry) => (j[entry.key] ?? entry.value) == entry.value,
        )) {
      j.addAll({
        'headerOpacity': .18,
        'footerOpacity': .18,
        'cardOpacity': .28,
        'buttonOpacity': .20,
        'fieldOpacity': .22,
        'workspaceOpacity': .12,
      });
    }
    final a = Appearance(
      mode: j['mode'] as String? ?? 'dark',
      accent: j['accent'] as int? ?? 0xffdae9a6,
      textScale: (j['textScale'] as num? ?? 1).toDouble(),
      uiScale: (j['uiScale'] as num? ?? 1).toDouble(),
      fieldRadius: (j['fieldRadius'] as num? ?? 14).toDouble(),
      buttonRadius: (j['buttonRadius'] as num? ?? 28).toDouble(),
      modalRadius: (j['modalRadius'] as num? ?? 24).toDouble(),
      compact: j['compact'] as bool? ?? false,
      dialogColor: j['dialogColor'] as int? ?? 0,
      cardColor: j['cardColor'] as int? ?? 0,
      buttonColor: j['buttonColor'] as int? ?? 0,
      headerOpacity: (j['headerOpacity'] as num? ?? .18).toDouble(),
      footerOpacity: (j['footerOpacity'] as num? ?? .18).toDouble(),
      cardOpacity: (j['cardOpacity'] as num? ?? .28).toDouble(),
      buttonOpacity: (j['buttonOpacity'] as num? ?? .20).toDouble(),
      desktopImage: j['desktopImage'] as String? ?? '',
      mobileImage: j['mobileImage'] as String? ?? '',
      desktopFit: j['desktopFit'] as String? ?? 'cover',
      mobileFit: j['mobileFit'] as String? ?? 'cover',
      backgroundOpacity: (j['backgroundOpacity'] as num? ?? .35).toDouble(),
      coupleSurfaces: j['coupleSurfaces'] as bool? ?? false,
      serifHeaders: j['serifHeaders'] as bool? ?? false,
      backgroundColor: j['backgroundColor'] as int? ?? 0xff4f6038,
      workspaceColor: j['workspaceColor'] as int? ?? 0,
      fieldColor: j['fieldColor'] as int? ?? 0,
      modalColor: j['modalColor'] as int? ?? 0,
      workspaceOpacity: (j['workspaceOpacity'] as num? ?? .12).toDouble(),
      fieldOpacity: (j['fieldOpacity'] as num? ?? .22).toDouble(),
      modalOpacity: (j['modalOpacity'] as num? ?? 0).toDouble(),
      backgroundTint: j['backgroundTint'] as int? ?? 0xff203a2d,
      backgroundTintStrength: (j['backgroundTintStrength'] as num? ?? 0)
          .toDouble(),
      backgroundDim: (j['backgroundDim'] as num? ?? 0).toDouble(),
      imageEnabled: j['imageEnabled'] as bool? ?? true,
      defaultTexture: j['defaultTexture'] as bool? ?? true,
      readabilityProtection: j['readabilityProtection'] as bool? ?? false,
      desktopImageName: j['desktopImageName'] as String? ?? '',
      mobileImageName: j['mobileImageName'] as String? ?? '',
      cardRadius: (j['cardRadius'] as num? ?? 22).toDouble(),
      defaultObservationTone:
          j['defaultObservationTone'] as String? ?? 'neutral',
      shortcutOrder: List<String>.unmodifiable(
        (j['shortcutOrder'] as List? ??
                const ['goal', 'social', 'work', 'homework', 'orga'])
            .cast<String>(),
      ),
    );
    if (![
          'positive',
          'neutral',
          'negative',
        ].contains(a.defaultObservationTone) ||
        !a.cardRadius.isFinite ||
        a.cardRadius < 0 ||
        a.cardRadius > 32 ||
        !a.backgroundDim.isFinite ||
        a.backgroundDim < 0 ||
        a.backgroundDim > .8 ||
        !a.backgroundTintStrength.isFinite ||
        a.backgroundTintStrength < 0 ||
        a.backgroundTintStrength > .8 ||
        a.desktopImageName.length > 120 ||
        a.mobileImageName.length > 120 ||
        a.shortcutOrder.length != 5 ||
        a.shortcutOrder.toSet().length != 5 ||
        !a.shortcutOrder.toSet().containsAll(const [
          'goal',
          'social',
          'work',
          'homework',
          'orga',
        ]) ||
        !['system', 'dark', 'light'].contains(a.mode) ||
        !a.textScale.isFinite ||
        a.textScale < .8 ||
        a.textScale > 1.6 ||
        !a.uiScale.isFinite ||
        a.uiScale < .8 ||
        a.uiScale > 1.2 ||
        [
          a.fieldRadius,
          a.buttonRadius,
          a.modalRadius,
        ].any((v) => !v.isFinite || v < 0 || v > 32) ||
        [
          a.accent,
          a.backgroundColor,
          a.workspaceColor,
          a.fieldColor,
          a.modalColor,
          a.backgroundTint,
          a.dialogColor,
          a.cardColor,
          a.buttonColor,
        ].any((c) => c < 0 || c > 0xffffffff) ||
        [
          a.workspaceOpacity,
          a.fieldOpacity,
          a.modalOpacity,
          a.headerOpacity,
          a.footerOpacity,
          a.cardOpacity,
          a.buttonOpacity,
          a.backgroundOpacity,
        ].any((v) => !v.isFinite || v < 0 || v > 1) ||
        ![
          'cover',
          'contain',
          'fitWidth',
          'fitHeight',
          'fill',
          'none',
          'tile',
        ].contains(a.desktopFit) ||
        ![
          'cover',
          'contain',
          'fitWidth',
          'fitHeight',
          'fill',
          'none',
          'tile',
        ].contains(a.mobileFit) ||
        [a.desktopImage, a.mobileImage].any(
          (v) =>
              v.length > 6800000 ||
              !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(v),
        )) {
      throw const DomainError('Ungültige Darstellung.');
    }
    try {
      for (final image in [a.desktopImage, a.mobileImage]) {
        if (image.isNotEmpty) base64Decode(image);
      }
    } catch (_) {
      throw const DomainError('Ungültige Bilddaten.');
    }
    return a;
  }
}
