import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'models.dart';
import 'document_scanner.dart' show DocumentLink;

enum ClassroomKind {
  timetable,
  lesson,
  holiday,
  material,
  materialSet,
  preparation,
  plan,
  folder,
  returnList,
  repeat,
  reminder,
}

const materialTypes = {
  'other': 'Dokument',
  'pupilWork': 'Schülerarbeit',
  'form': 'Formular',
  'receipt': 'Beleg',
  'worksheet': 'Arbeitsblatt',
  'solution': 'Lösung',
  'weekPlan': 'Wochenplan',
  'learningPlan': 'Lernplan',
  'planning': 'Unterrichtsplanung',
  'protocol': 'Protokoll',
  'parentInfo': 'Elterninformation',
  'template': 'Vorlage',
};
const materialAudiences = {
  'all': 'Alle',
  'pupils': 'Schüler',
  'teacher': 'Lehrkraft',
  'parents': 'Eltern',
};
const planStatuses = {
  'planned': 'Geplant',
  'started': 'Begonnen',
  'done': 'Durchgeführt',
  'moved': 'Verschoben',
};

DateTime schoolDay(String value) {
  if (!validDate(value)) {
    throw const DomainError('Bitte ein gültiges Datum wählen.');
  }
  final d = DateTime.parse(value);
  return DateTime.utc(d.year, d.month, d.day);
}

bool validClock(String value) =>
    RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

/// Calendar arithmetic uses dates, never elapsed local hours across DST changes.
class RepeatRule {
  const RepeatRule({
    this.frequency = 'none',
    this.interval = 1,
    this.weekdays = const [],
    this.until,
    this.skipHolidays = false,
    this.excluded = const [],
  });
  final String frequency;
  final int interval;
  final List<int> weekdays;
  final String? until;
  final bool skipHolidays;
  final List<String> excluded;
  bool get repeats => frequency != 'none';
  Json toJson() => {
    'frequency': frequency,
    'interval': interval,
    'weekdays': weekdays,
    'until': until,
    'skipHolidays': skipHolidays,
    'excluded': excluded,
  };
  factory RepeatRule.fromJson(Json json) {
    final value = RepeatRule(
      frequency: json['frequency'] as String? ?? 'none',
      interval: json['interval'] as int? ?? 1,
      weekdays: List<int>.from(json['weekdays'] as List? ?? []),
      until: json['until'] as String?,
      skipHolidays: json['skipHolidays'] as bool? ?? false,
      excluded: List<String>.from(json['excluded'] as List? ?? []),
    );
    value.validate();
    return value;
  }
  void validate() {
    if (!{'none', 'daily', 'weekly', 'monthly'}.contains(frequency) ||
        interval < 1 ||
        interval > 52 ||
        weekdays.any((d) => d < 1 || d > 7) ||
        weekdays.toSet().length != weekdays.length ||
        until != null && !validDate(until!) ||
        excluded.length > 2000 ||
        excluded.any((d) => !validDate(d))) {
      throw const DomainError('Ungültige Wiederholung.');
    }
  }

  bool includes(
    String start,
    String date,
    Iterable<ClassroomDocument> holidays,
  ) {
    final first = schoolDay(start), day = schoolDay(date);
    if (day.isBefore(first) ||
        until != null && date.compareTo(until!) > 0 ||
        excluded.contains(date)) {
      return false;
    }
    if (skipHolidays &&
        holidays.any(
          (h) =>
              !h.deleted &&
              h.kind == ClassroomKind.holiday &&
              date.compareTo(h.text('date')) >= 0 &&
              date.compareTo(h.text('endDate')) <= 0,
        )) {
      return false;
    }
    return switch (frequency) {
      'none' => date == start,
      'daily' => day.difference(first).inDays % interval == 0,
      'weekly' =>
        day
                        .subtract(Duration(days: day.weekday - 1))
                        .difference(
                          first.subtract(Duration(days: first.weekday - 1)),
                        )
                        .inDays ~/
                    7 %
                    interval ==
                0 &&
            (weekdays.isEmpty ? [first.weekday] : weekdays).contains(
              day.weekday,
            ),
      'monthly' =>
        ((day.year - first.year) * 12 + day.month - first.month) % interval ==
                0 &&
            day.day ==
                first.day.clamp(
                  1,
                  DateTime.utc(day.year, day.month + 1, 0).day,
                ),
      _ => false,
    };
  }
}

ClassroomDocument? repeatForEntry(
  Iterable<ClassroomDocument> docs,
  String entryId,
) {
  for (final d in docs.where(
    (d) => d.kind == ClassroomKind.repeat && !d.deleted,
  )) {
    if (d.text('entryId') == entryId ||
        d
            .map('generated')
            .keys
            .any(
              (date) =>
                  const Uuid().v5(Namespace.url.value, '${d.id}:$date') ==
                  entryId,
            )) {
      return d;
    }
  }
  return null;
}

/// Versioned domain documents share SQLite's existing transactional JSON store.
/// Credentials and downloaded bytes are deliberately stored separately.
class ClassroomDocument {
  ClassroomDocument._(this._json);
  final Json _json;
  factory ClassroomDocument.fromJson(Json json) {
    final copy = Json.from(jsonDecode(jsonEncode(json)) as Map);
    final value = ClassroomDocument._(Map.unmodifiable(copy));
    value.validate();
    return value;
  }
  factory ClassroomDocument.create(
    ClassroomKind kind,
    String title,
    Json fields, {
    String? id,
  }) => ClassroomDocument.fromJson({
    'format': 'flex-classroom-1',
    'id': id ?? newId(),
    'kind': kind.name,
    'title': title,
    'revision': 0,
    'deleted': false,
    'createdAtUtc': utcNow(),
    'updatedAtUtc': utcNow(),
    ...fields,
  });
  String get id => text('id');
  ClassroomKind get kind => ClassroomKind.values.byName(text('kind'));
  String get title => text('title');
  int get revision => number('revision');
  bool get deleted => flag('deleted');
  String text(String key, [String fallback = '']) =>
      _json[key] as String? ?? fallback;
  int number(String key, [int fallback = 0]) => _json[key] as int? ?? fallback;
  bool flag(String key) => _json[key] as bool? ?? false;
  List<String> strings(String key) =>
      List<String>.from(_json[key] as List? ?? []);
  List<Json> rows(String key) =>
      (_json[key] as List? ?? []).map((r) => Json.from(r as Map)).toList();
  Json map(String key) => Json.from(_json[key] as Map? ?? {});
  Json toJson() => Json.from(jsonDecode(jsonEncode(_json)) as Map);
  ClassroomDocument patch(Json fields) =>
      ClassroomDocument.fromJson({...toJson(), ...fields});
  RepeatRule get rule => RepeatRule.fromJson(map('repeat'));
  String get label => switch (kind) {
    ClassroomKind.timetable => 'Stundenplan',
    ClassroomKind.lesson => 'Unterricht',
    ClassroomKind.holiday => 'Ferien / Ausfall',
    ClassroomKind.material => 'Material',
    ClassroomKind.materialSet => 'Unterrichtspaket',
    ClassroomKind.preparation => 'Bereitgelegt',
    ClassroomKind.plan => 'Planung',
    ClassroomKind.folder => 'OneDrive-Ordner',
    ClassroomKind.returnList => 'Rücklauf',
    ClassroomKind.repeat => 'Wiederholung',
    ClassroomKind.reminder => 'Erinnerung',
  };
  void validate() {
    if (_json['format'] != 'flex-classroom-1' ||
        id.isEmpty ||
        id.length > 250 ||
        !ClassroomKind.values.any((k) => k.name == text('kind')) ||
        title.trim().isEmpty ||
        title.length > 160 ||
        revision < 0 ||
        _json['deleted'] is! bool ||
        DateTime.tryParse(text('createdAtUtc')) == null ||
        DateTime.tryParse(text('updatedAtUtc')) == null ||
        jsonEncode(_json).length > 500000) {
      throw const DomainError('Ungültiger Klassen-Eintrag.');
    }
    final fields = switch (kind) {
      ClassroomKind.timetable => {'date', 'endDate', 'slots'},
      ClassroomKind.lesson => {
        'date',
        'start',
        'end',
        'subject',
        'room',
        'note',
        'materialIds',
        'repeat',
        'exceptions',
        'icsUid',
        'icsSource',
        'icsStamp',
        'remindMinutes',
        'timetableId',
        'slotIds',
        'teacher',
      },
      ClassroomKind.holiday => {'date', 'endDate'},
      ClassroomKind.material => {
        'url',
        'driveId',
        'itemId',
        'name',
        'extension',
        'subject',
        'topic',
        'note',
        'week',
        'localKey',
        'etag',
        'sourceModifiedAt',
        'size',
        'documentType',
        'audience',
        'pupilIds',
        'tags',
        'favorite',
        'sourcePath',
        'links',
        'scan',
        'scanner',
        'pageCount',
      },
      ClassroomKind.materialSet => {
        'materialIds',
        'pupilIds',
        'subject',
        'topic',
        'note',
      },
      ClassroomKind.preparation => {'date', 'materialIds'},
      ClassroomKind.plan => {
        'materialIds',
        'pupilIds',
        'lessonIds',
        'subject',
        'topic',
        'note',
        'date',
        'endDate',
        'status',
        'followUp',
      },
      ClassroomKind.folder => {'driveId', 'itemId', 'url'},
      ClassroomKind.returnList => {
        'type',
        'dueDate',
        'note',
        'participants',
        'materialIds',
        'amountDue',
        'closed',
        'remindDays',
      },
      ClassroomKind.repeat => {
        'entryId',
        'date',
        'repeat',
        'template',
        'stopped',
        'generated',
      },
      ClassroomKind.reminder => {'target', 'at', 'dismissed'},
    };
    if (_json.keys.any(
      (k) => !{
        'format',
        'id',
        'kind',
        'title',
        'revision',
        'deleted',
        'createdAtUtc',
        'updatedAtUtc',
        ...fields,
      }.contains(k),
    )) {
      throw const DomainError('Unbekannte Datenfelder im Klassen-Eintrag.');
    }
    for (final key in ['note', 'subject', 'topic', 'room', 'teacher']) {
      if (text(key).length > (key == 'note' ? 20000 : 200)) {
        throw const DomainError('Der Text ist zu lang.');
      }
    }
    for (final key in [
      'materialIds',
      'pupilIds',
      'lessonIds',
      'tags',
      'slotIds',
    ]) {
      final values = strings(key);
      if (values.length > 5000 ||
          values.toSet().length != values.length ||
          values.any((v) => v.trim().isEmpty || v.length > 250)) {
        throw const DomainError('Ungültige oder doppelte Zuordnung.');
      }
    }
    if (kind == ClassroomKind.timetable) {
      final slots = rows('slots');
      if (!validDate(text('date')) ||
          text('endDate').isNotEmpty &&
              (!validDate(text('endDate')) ||
                  text('endDate').compareTo(text('date')) < 0) ||
          slots.isEmpty ||
          slots.length > 20) {
        throw const DomainError('Bitte Gültigkeit und Stundenzeiten prüfen.');
      }
      var end = '';
      final ids = <String>{};
      for (final slot in slots) {
        final id = slot['id'],
            label = slot['label'],
            start = slot['start'],
            finish = slot['end'];
        if (slot.keys.any(
              (k) => !{'id', 'label', 'start', 'end'}.contains(k),
            ) ||
            id is! String ||
            id.isEmpty ||
            id.length > 250 ||
            !ids.add(id) ||
            label is! String ||
            label.trim().isEmpty ||
            label.length > 40 ||
            start is! String ||
            finish is! String ||
            !validClock(start) ||
            !validClock(finish) ||
            start.compareTo(finish) >= 0 ||
            start.compareTo(end) < 0) {
          throw const DomainError(
            'Stundenzeiten müssen gültig, aufsteigend und ohne Überschneidung sein.',
          );
        }
        end = finish;
      }
    }
    if (kind == ClassroomKind.lesson &&
        (text('timetableId').length > 250 ||
            text('timetableId').isEmpty != strings('slotIds').isEmpty)) {
      throw const DomainError('Ungültige Stundenplan-Zuordnung.');
    }
    if (kind == ClassroomKind.preparation &&
        (!validDate(text('date')) ||
            id !=
                const Uuid().v5(
                  Namespace.url.value,
                  'flex-preparation:${text('date')}',
                ))) {
      throw const DomainError('Bitte einen Tag zum Bereitlegen wählen.');
    }
    if (kind == ClassroomKind.plan &&
        (!planStatuses.containsKey(text('status', 'planned')) ||
            text('date').isNotEmpty && !validDate(text('date')) ||
            text('endDate').isNotEmpty &&
                (!validDate(text('endDate')) ||
                    text('date').isEmpty ||
                    text('endDate').compareTo(text('date')) < 0) ||
            text('followUp').length > 20000)) {
      throw const DomainError('Bitte Zeitraum und Stand der Planung prüfen.');
    }
    if (kind == ClassroomKind.material) {
      final links = rows('links').map(DocumentLink.fromJson).toList();
      if (links.length > 100 ||
          links.map((l) => l.identity).toSet().length != links.length ||
          _json.containsKey('scan') && _json['scan'] is! bool ||
          _json.containsKey('scanner') && _json['scanner'] is! bool ||
          _json.containsKey('pageCount') &&
              (_json['pageCount'] is! int ||
                  number('pageCount') < 1 ||
                  number('pageCount') > 25)) {
        throw const DomainError('Ungültige Scandaten.');
      }
    }
    if (kind == ClassroomKind.material &&
        (!materialTypes.containsKey(text('documentType', 'other')) ||
            !materialAudiences.containsKey(text('audience', 'all')) ||
            _json.containsKey('favorite') && _json['favorite'] is! bool ||
            text('sourcePath').length > 5000)) {
      throw const DomainError('Ungültige Materialangaben.');
    }
    if (kind == ClassroomKind.lesson ||
        kind == ClassroomKind.holiday ||
        kind == ClassroomKind.repeat) {
      if (!validDate(text('date'))) {
        throw const DomainError('Bitte ein Datum wählen.');
      }
    }
    if (kind == ClassroomKind.lesson || kind == ClassroomKind.repeat) {
      rule.validate();
      if (rule.until != null && rule.until!.compareTo(text('date')) < 0) {
        throw const DomainError('Das Ende liegt vor dem Beginn der Serie.');
      }
    }
    if (kind == ClassroomKind.lesson) {
      if ((text('start').isNotEmpty || text('end').isNotEmpty) &&
          (!validClock(text('start')) ||
              !validClock(text('end')) ||
              text('end').compareTo(text('start')) <= 0)) {
        throw const DomainError('Bitte Beginn und ein späteres Ende wählen.');
      }
      if (number('remindMinutes') < 0 || number('remindMinutes') > 10080) {
        throw const DomainError('Ungültiger Erinnerungsabstand.');
      }
      for (final exception in rows('exceptions')) {
        if (!validDate(exception['date'] as String? ?? '') ||
            exception['cancelled'] is! bool ||
            exception.keys.any(
              (k) => !{
                'date',
                'cancelled',
                'movedTo',
                'start',
                'end',
                'title',
                'note',
                'materialIds',
                'planIds',
              }.contains(k),
            )) {
          throw const DomainError('Ungültige Unterrichtsausnahme.');
        }
        if (exception['movedTo'] != null &&
            !validDate(exception['movedTo'] as String)) {
          throw const DomainError('Ungültiges Verschiebedatum.');
        }
        for (final key in ['materialIds', 'planIds']) {
          if (!exception.containsKey(key)) continue;
          final ids = exception[key];
          if (ids is! List ||
              ids.length > 5000 ||
              ids.any((id) => id is! String || id.isEmpty || id.length > 250) ||
              ids.toSet().length != ids.length) {
            throw const DomainError(
              'Ungültige Zuordnung zur Unterrichtsstunde.',
            );
          }
        }
        if (exception['start'] != null &&
            (!validClock(exception['start'] as String) ||
                !validClock(exception['end'] as String? ?? '') ||
                (exception['end'] as String).compareTo(
                      exception['start'] as String,
                    ) <=
                    0)) {
          throw const DomainError('Ungültige Uhrzeit der Unterrichtsausnahme.');
        }
      }
      if (rows('exceptions').map((e) => e['date']).toSet().length !=
          rows('exceptions').length) {
        throw const DomainError('Doppelte Unterrichtsausnahme.');
      }
    }
    if (kind == ClassroomKind.holiday &&
        (!validDate(text('endDate')) ||
            text('endDate').compareTo(text('date')) < 0)) {
      throw const DomainError('Bitte einen gültigen Ferienzeitraum wählen.');
    }
    if (kind == ClassroomKind.material || kind == ClassroomKind.folder) {
      final url = Uri.tryParse(text('url'));
      if (text('url').isNotEmpty &&
          (url == null ||
              url.scheme != 'https' ||
              url.host.isEmpty ||
              url.userInfo.isNotEmpty)) {
        throw const DomainError(
          'Bitte einen vollständigen HTTPS-Link eingeben.',
        );
      }
      if (kind == ClassroomKind.folder &&
          (text('driveId').isEmpty || text('itemId').isEmpty)) {
        throw const DomainError('Der OneDrive-Ordner fehlt.');
      }
      if (kind == ClassroomKind.material) {
        if (!{'pdf', 'jpg', 'docx', 'link'}.contains(text('extension')) ||
            number('size') < 0 ||
            text('localKey').contains(RegExp(r'[/\\.]')) ||
            (text('url').isEmpty &&
                text('localKey').isEmpty &&
                text('itemId').isEmpty)) {
          throw const DomainError(
            'Bitte PDF, DOCX oder einen gültigen Link auswählen.',
          );
        }
        if (text('week').isNotEmpty && !validDate(text('week'))) {
          throw const DomainError('Ungültige Kalenderwoche.');
        }
      }
    }
    if (kind == ClassroomKind.returnList) {
      if (!returnStatuses.containsKey(text('type')) ||
          text('dueDate').isNotEmpty && !validDate(text('dueDate')) ||
          number('amountDue') < 0 ||
          number('amountDue') > 10000000 ||
          number('remindDays') < 0 ||
          number('remindDays') > 365) {
        throw const DomainError('Ungültige Rücklaufliste.');
      }
      final participants = rows('participants');
      if (participants.isEmpty ||
          participants.length > 1000 ||
          participants.map((p) => p['pupilId']).toSet().length !=
              participants.length) {
        throw const DomainError('Bitte Schüler eindeutig auswählen.');
      }
      for (final p in participants) {
        if (p['pupilId'] is! String ||
            (p['pupilId'] as String).isEmpty ||
            p['name'] is! String ||
            !returnStatuses[text('type')]!.containsKey(p['status']) ||
            p['note'] is! String ||
            (p['note'] as String).length > 5000 ||
            p['paid'] is! int ||
            (p['paid'] as int) < 0 ||
            (p['paid'] as int) > 10000000) {
          throw const DomainError('Ungültige Rückmeldung.');
        }
      }
    }
    if (kind == ClassroomKind.repeat) {
      if (map('generated').entries.any(
        (e) => !validDate(e.key) || e.value is! int || (e.value as int) < 1,
      )) {
        throw const DomainError('Ungültige Serienzuordnung.');
      }
      final entry = OrgaEntry.fromJson(map('template'));
      entry.validate();
      if (entry.id != text('entryId') ||
          (!entry.isTask && !entry.isAppointment)) {
        throw const DomainError(
          'Nur Aufgaben und Termine können wiederholt werden.',
        );
      }
    }
    if (kind == ClassroomKind.reminder &&
        (!RegExp(
              r'^(orga|school|lesson|return):.+$',
            ).hasMatch(text('target')) ||
            !flag('dismissed') && DateTime.tryParse(text('at')) == null)) {
      throw const DomainError('Ungültige verschobene Erinnerung.');
    }
    if (strings('materialIds').toSet().length !=
        strings('materialIds').length) {
      throw const DomainError('Material ist doppelt zugeordnet.');
    }
  }
}

const returnStatuses = {
  'form': {
    'open': 'Offen',
    'received': 'Erhalten',
    'exempt': 'Nicht erforderlich',
  },
  'consent': {
    'open': 'Offen',
    'yes': 'Zugestimmt',
    'no': 'Abgelehnt',
    'exempt': 'Nicht erforderlich',
  },
  'material': {
    'open': 'Offen',
    'received': 'Mitgebracht',
    'exempt': 'Nicht erforderlich',
  },
  'payment': {
    'open': 'Offen',
    'partial': 'Teilbezahlt',
    'received': 'Bezahlt',
    'exempt': 'Befreit',
  },
};
const returnTypes = {
  'form': 'Formular / Abgabe',
  'consent': 'Zustimmung',
  'material': 'Material mitbringen',
  'payment': 'Beitrag',
};
bool returnPending(Json row) =>
    row['status'] == 'open' || row['status'] == 'partial';

class LessonOccurrence {
  const LessonOccurrence(
    this.document,
    this.originalDate,
    this.date,
    this.start,
    this.end,
    this.title,
    this.note,
  );
  final ClassroomDocument document;
  final String originalDate, date, start, end, title, note;
  String get target => 'lesson:${document.id}:$originalDate';
  Json get exception =>
      document
          .rows('exceptions')
          .where((e) => e['date'] == originalDate)
          .firstOrNull ??
      {};
  List<String> get materialIds => exception.containsKey('materialIds')
      ? List<String>.from(exception['materialIds'] as List)
      : document.strings('materialIds');
  List<String> get planIds =>
      List<String>.from(exception['planIds'] as List? ?? []);
}

/// Patch one stable occurrence, retaining movement, cancellation and preparation.
ClassroomDocument patchLessonOccurrence(
  ClassroomDocument document,
  String originalDate,
  Json fields,
) {
  if (document.kind != ClassroomKind.lesson ||
      !validDate(originalDate) ||
      !document.rule.includes(document.text('date'), originalDate, [])) {
    throw const DomainError('Diese Unterrichtsstunde gehört nicht zur Serie.');
  }
  final old = document
      .rows('exceptions')
      .where((e) => e['date'] == originalDate)
      .firstOrNull;
  return document.patch({
    'exceptions': [
      for (final e in document.rows('exceptions'))
        if (e['date'] != originalDate) e,
      {'date': originalDate, 'cancelled': false, ...?old, ...fields},
    ],
  });
}

List<LessonOccurrence> lessonOccurrences(
  Iterable<ClassroomDocument> documents,
  String from,
  String to,
) {
  final first = schoolDay(from), last = schoolDay(to);
  if (last.isBefore(first) || last.difference(first).inDays > 740) {
    throw const DomainError('Bitte einen Zeitraum bis zu zwei Jahren wählen.');
  }
  final all = documents.toList(), result = <LessonOccurrence>[];
  for (final doc in all.where(
    (d) => !d.deleted && d.kind == ClassroomKind.lesson,
  )) {
    final exceptions = {
      for (final e in doc.rows('exceptions')) e['date'] as String: e,
    };
    final candidates = <String>{...exceptions.keys};
    for (
      var day = first;
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      candidates.add(dateOnly(day));
    }
    for (final original in candidates) {
      if (!doc.rule.includes(doc.text('date'), original, all)) continue;
      final e = exceptions[original];
      if (e?['cancelled'] == true) continue;
      final date = e?['movedTo'] as String? ?? original;
      if (date.compareTo(from) < 0 || date.compareTo(to) > 0) continue;
      result.add(
        LessonOccurrence(
          doc,
          original,
          date,
          e?['start'] as String? ?? doc.text('start'),
          e?['end'] as String? ?? doc.text('end'),
          e?['title'] as String? ?? doc.title,
          e?['note'] as String? ?? doc.text('note'),
        ),
      );
    }
  }
  result.sort(
    (a, b) => '${a.date} ${a.start} ${a.document.id}'.compareTo(
      '${b.date} ${b.start} ${b.document.id}',
    ),
  );
  return result;
}
