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
  final String? pupilId, dueDate, reminderAtUtc;
  final bool isTask, done, needsCompletion, deleted;
  final String observedOn, observedTime, reminderText;
  final int revision;
  final ReminderState reminderState;
  final List<CheckItem> items;
  bool get pending =>
      !deleted && ((isTask && !done) || reminderState == ReminderState.planned);
  String? get nextDate {
    final dates = [
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

class EditDraft {
  const EditDraft({
    required this.id,
    required this.entry,
    required this.updatedAtUtc,
  });
  final String id, updatedAtUtc;
  final OrgaEntry entry;
}

class Appearance {
  const Appearance({
    this.mode = 'dark',
    this.accent = 0xffdae9a6,
    this.textScale = 1,
    this.compact = false,
    this.dialogColor = 0,
    this.cardColor = 0,
    this.buttonColor = 0,
    this.headerOpacity = 1,
    this.footerOpacity = 1,
    this.cardOpacity = 1,
    this.buttonOpacity = 1,
    this.desktopImage = '',
    this.mobileImage = '',
    this.desktopFit = 'cover',
    this.mobileFit = 'cover',
    this.backgroundOpacity = .35,
    this.coupleSurfaces = false,
    this.serifHeaders = false,
  });
  final String mode, desktopImage, mobileImage, desktopFit, mobileFit;
  final int accent, dialogColor, cardColor, buttonColor;
  final double textScale,
      headerOpacity,
      footerOpacity,
      cardOpacity,
      buttonOpacity,
      backgroundOpacity;
  final bool compact, coupleSurfaces, serifHeaders;
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
    'mode': mode,
    'accent': accent,
    'textScale': textScale,
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
  };
  factory Appearance.fromJson(Json j) {
    final a = Appearance(
      mode: j['mode'] as String,
      accent: j['accent'] as int,
      textScale: (j['textScale'] as num).toDouble(),
      compact: j['compact'] as bool,
      dialogColor: j['dialogColor'] as int? ?? 0,
      cardColor: j['cardColor'] as int? ?? 0,
      buttonColor: j['buttonColor'] as int? ?? 0,
      headerOpacity: (j['headerOpacity'] as num? ?? 1).toDouble(),
      footerOpacity: (j['footerOpacity'] as num? ?? 1).toDouble(),
      cardOpacity: (j['cardOpacity'] as num? ?? 1).toDouble(),
      buttonOpacity: (j['buttonOpacity'] as num? ?? 1).toDouble(),
      desktopImage: j['desktopImage'] as String? ?? '',
      mobileImage: j['mobileImage'] as String? ?? '',
      desktopFit: j['desktopFit'] as String? ?? 'cover',
      mobileFit: j['mobileFit'] as String? ?? 'cover',
      backgroundOpacity: (j['backgroundOpacity'] as num? ?? .35).toDouble(),
      coupleSurfaces: j['coupleSurfaces'] as bool? ?? false,
      serifHeaders: j['serifHeaders'] as bool? ?? false,
    );
    if (!['system', 'dark', 'light'].contains(a.mode) ||
        !a.textScale.isFinite ||
        a.textScale < .9 ||
        a.textScale > 1.4 ||
        [
          a.accent,
          a.dialogColor,
          a.cardColor,
          a.buttonColor,
        ].any((c) => c < 0 || c > 0xffffffff) ||
        [
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
        ].contains(a.desktopFit) ||
        ![
          'cover',
          'contain',
          'fitWidth',
          'fitHeight',
          'fill',
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
