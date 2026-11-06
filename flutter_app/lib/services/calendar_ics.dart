import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/calendar.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';

String _escape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('\n', '\\n')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r', '');
String _unescape(String s) => s.replaceAllMapped(
  RegExp(r'\\([nN,;\\])'),
  (m) => m[1]!.toLowerCase() == 'n' ? '\n' : m[1]!,
);
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}00Z';

String exportCalendarIcs(List<CalendarItem> items, {DateTime? now}) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//FLEX//FLEX-Klasse//DE',
    'CALSCALE:GREGORIAN',
  ];
  for (final e in items) {
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${base64Url.encode(utf8.encode(e.id)).replaceAll('=', '')}@flex-notizbuch',
      'DTSTAMP:${_stamp((now ?? DateTime.now()).toUtc())}',
    ]);
    if (e.time.isEmpty) {
      lines.add('DTSTART;VALUE=DATE:${e.date.replaceAll('-', '')}');
      lines.add(
        'DTEND;VALUE=DATE:${dateOnly(schoolDay(e.date).add(const Duration(days: 1))).replaceAll('-', '')}',
      );
    } else {
      lines.add(
        'DTSTART:${_stamp(DateTime.parse('${e.date}T${e.time}:00').toUtc())}',
      );
      final end = e.end.isEmpty
          ? DateTime.parse(
              '${e.date}T${e.time}:00',
            ).add(const Duration(minutes: 30))
          : DateTime.parse('${e.date}T${e.end}:00');
      lines.add('DTEND:${_stamp(end.toUtc())}');
    }
    lines.addAll([
      'SUMMARY:${_escape(e.title)}',
      'DESCRIPTION:${_escape(e.detail)}',
      'CATEGORIES:${_escape(calendarCategories[e.category]!)}',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  // RFC 5545 folds at 75 octets without splitting UTF-8 code points.
  return '${lines.map((line) {
    final parts = <String>[];
    var current = '', length = 0;
    for (final rune in line.runes) {
      final s = String.fromCharCode(rune), n = utf8.encode(s).length;
      if (length + n > 75) {
        parts.add(current);
        current = ' ';
        length = 1;
      }
      current += s;
      length += n;
    }
    parts.add(current);
    return parts.join('\r\n');
  }).join('\r\n')}\r\n';
}

class IcsImport {
  const IcsImport(this.documents, this.warnings);
  final List<ClassroomDocument> documents;
  final List<String> warnings;
}

const importedLessonFields = {
  'title',
  'date',
  'start',
  'end',
  'repeat',
  'note',
  'room',
};

/// An external refresh may change its own fields, but never silently discard
/// local preparation. An incompatible series needs an explicit manual edit.
ClassroomDocument mergeImportedLesson(
  ClassroomDocument? existing,
  ClassroomDocument incoming,
) {
  if (existing == null) return incoming;
  for (final exception in existing.rows('exceptions')) {
    if (!incoming.rule.includes(
      incoming.text('date'),
      exception['date'] as String,
      [],
    )) {
      throw const DomainError(
        'Die importierte Serie würde angepasste Stunden entfernen. Bitte diese Serie über „Verwalten“ bearbeiten.',
      );
    }
  }
  return existing.patch({
    for (final key in importedLessonFields) key: incoming.toJson()[key],
    'icsStamp': incoming.text('icsStamp'),
    'deleted': false,
  });
}

/// Strict supported subset: unsupported recurrence is reported, never silently
/// interpreted as a one-off appointment. Imports remain a reviewable preview.
IcsImport parseCalendarIcs(String text, {String source = 'Kalender'}) {
  if (utf8.encode(text).length > 5000000) {
    throw const DomainError('Die Kalenderdatei überschreitet 5 MB.');
  }
  tzdata.initializeTimeZones();
  final unfolded = text.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  if (!unfolded.contains('BEGIN:VCALENDAR') ||
      !unfolded.contains('END:VCALENDAR')) {
    throw const DomainError('Keine gültige ICS-Kalenderdatei.');
  }
  final documents = <ClassroomDocument>[], warnings = <String>[];
  final ids = <String>{};
  // A detached override changes its master. Until overrides are supported,
  // reject that entire series rather than importing an incorrect original slot.
  final overridden = <String>{};
  final events = RegExp(
    r'BEGIN:VEVENT\r?\n([\s\S]*?)END:VEVENT',
  ).allMatches(unfolded).toList();
  if (events.length > 2000) {
    throw const DomainError(
      'Bitte höchstens 2000 Kalendereinträge importieren.',
    );
  }
  for (final event in events) {
    if (RegExp(r'^RECURRENCE-ID[;:]', multiLine: true).hasMatch(event[1]!)) {
      final uid = RegExp(
        r'^UID:([^\r\n]+)',
        multiLine: true,
      ).firstMatch(event[1]!)?[1];
      if (uid != null) overridden.add(uid);
    }
  }
  for (final match in RegExp(
    r'BEGIN:VEVENT\r?\n([\s\S]*?)END:VEVENT',
  ).allMatches(unfolded)) {
    if (documents.length >= 2000) {
      throw const DomainError(
        'Bitte höchstens 2000 Kalendereinträge importieren.',
      );
    }
    final fields = <String, List<({String params, String value})>>{};
    for (final line in match[1]!.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon < 1) continue;
      final key = line.substring(0, colon).split(';').first.toUpperCase();
      fields.putIfAbsent(key, () => []).add((
        params: line.substring(0, colon),
        value: line.substring(colon + 1),
      ));
    }
    final title = _unescape(fields['SUMMARY']?.first.value ?? 'Termin');
    try {
      if (fields.containsKey('RECURRENCE-ID')) {
        throw const DomainError(
          'Einzelne Serienausnahmen benötigen eine gesonderte Übernahme.',
        );
      }
      if (fields['STATUS']?.first.value == 'CANCELLED') {
        throw const DomainError('Abgesagter Termin wurde nicht übernommen.');
      }
      final uid = fields['UID']?.first.value;
      if (uid == null || uid.isEmpty) {
        throw const DomainError('Die stabile Kalender-ID fehlt.');
      }
      if (overridden.contains(uid)) {
        throw const DomainError(
          'Serie mit einzelnen Änderungen: bitte manuell übernehmen.',
        );
      }
      if (!ids.add(uid)) throw const DomainError('Doppelte Kalender-ID.');
      ({String date, String clock}) parse(
        ({String params, String value})? prop,
      ) {
        if (prop == null) throw const DomainError('Beginn fehlt.');
        final v = prop.value;
        if (!RegExp(r'^\d{8}(T\d{6}Z?)?$').hasMatch(v)) {
          throw const DomainError('Nicht unterstütztes Datumsformat.');
        }
        final date =
            '${v.substring(0, 4)}-${v.substring(4, 6)}-${v.substring(6, 8)}';
        schoolDay(date);
        if (v.length == 8) return (date: date, clock: '');
        final clock = '${v.substring(9, 11)}:${v.substring(11, 13)}';
        if (!validClock(clock) || int.parse(v.substring(13, 15)) > 59) {
          throw const DomainError('Ungültige Uhrzeit.');
        }
        var local = DateTime.parse(
          '${date}T$clock:${v.substring(13, 15)}${v.endsWith('Z') ? 'Z' : ''}',
        );
        final zone = RegExp(
          r'(?:^|;)TZID="?([^;"\r\n]+)',
        ).firstMatch(prop.params)?[1];
        if (zone != null) {
          final location = tz.getLocation(zone);
          local = tz.TZDateTime(
            location,
            int.parse(v.substring(0, 4)),
            int.parse(v.substring(4, 6)),
            int.parse(v.substring(6, 8)),
            int.parse(v.substring(9, 11)),
            int.parse(v.substring(11, 13)),
          ).toLocal();
        } else {
          local = local.toLocal();
        }
        return (
          date: dateOnly(local),
          clock:
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
        );
      }

      final begin = parse(fields['DTSTART']?.first);
      final finish = fields.containsKey('DTEND')
          ? parse(fields['DTEND']!.first)
          : begin;
      if (begin.clock.isNotEmpty &&
          (finish.date != begin.date ||
              finish.clock.compareTo(begin.clock) <= 0)) {
        throw const DomainError(
          'Mehrtagestermin oder fehlendes Ende: bitte manuell übernehmen.',
        );
      }
      if (begin.clock.isEmpty &&
          schoolDay(finish.date).difference(schoolDay(begin.date)).inDays > 1) {
        throw const DomainError(
          'Mehrtagestermin: bitte als Ferienzeitraum übernehmen.',
        );
      }
      var rule = const RepeatRule();
      if (fields.containsKey('RRULE')) {
        final values = <String, String>{};
        for (final part in fields['RRULE']!.first.value.split(';')) {
          final pieces = part.split('=');
          if (pieces.length != 2) {
            throw const DomainError('Ungültige Serienregel.');
          }
          values[pieces[0]] = pieces[1];
        }
        if (values.keys.any(
              (k) =>
                  !{'FREQ', 'INTERVAL', 'BYDAY', 'UNTIL', 'WKST'}.contains(k),
            ) ||
            values['WKST'] != null && values['WKST'] != 'MO') {
          throw const DomainError(
            'Diese Serienregel wird noch nicht unterstützt.',
          );
        }
        final frequency = values['FREQ']?.toLowerCase() ?? '';
        if (!{'daily', 'weekly', 'monthly'}.contains(frequency) ||
            values.containsKey('BYDAY') && frequency != 'weekly') {
          throw const DomainError(
            'Diese Wiederholung wird noch nicht unterstützt.',
          );
        }
        if (frequency == 'monthly' && schoolDay(begin.date).day > 28) {
          throw const DomainError(
            'Monatliche Serie am Monatsende: bitte manuell übernehmen, da ICS fehlende Tage auslässt.',
          );
        }
        final weekdays =
            values['BYDAY']?.split(',').map((d) {
              final n = const [
                'MO',
                'TU',
                'WE',
                'TH',
                'FR',
                'SA',
                'SU',
              ].indexOf(d);
              if (n < 0) {
                throw const DomainError('Nicht unterstützter Wochentag.');
              }
              return n + 1;
            }).toList() ??
            <int>[];
        final excluded = <String>[];
        for (final e
            in fields['EXDATE'] ?? <({String params, String value})>[]) {
          for (final value in e.value.split(',')) {
            excluded.add(parse((params: e.params, value: value)).date);
          }
        }
        rule = RepeatRule.fromJson({
          'frequency': frequency,
          'interval': int.parse(values['INTERVAL'] ?? '1'),
          'weekdays': weekdays,
          'until': values['UNTIL'] == null
              ? null
              : parse((params: 'UNTIL', value: values['UNTIL']!)).date,
          'excluded': excluded,
        });
      }
      documents.add(
        ClassroomDocument.create(ClassroomKind.lesson, title, {
          'date': begin.date,
          'start': begin.clock,
          'end': finish.clock,
          'subject': '',
          'room': _unescape(fields['LOCATION']?.first.value ?? ''),
          'note': _unescape(fields['DESCRIPTION']?.first.value ?? ''),
          'materialIds': <String>[],
          'repeat': rule.toJson(),
          'exceptions': <Json>[],
          'icsUid': uid,
          'icsSource': source,
          'icsStamp':
              fields['LAST-MODIFIED']?.first.value ??
              fields['DTSTAMP']?.first.value ??
              '',
        }, id: const Uuid().v5(Namespace.url.value, 'flex-ics:$uid')),
      );
    } catch (e) {
      warnings.add(
        '$title: ${e is DomainError ? e.message : 'Unbekannte Zeitzone oder ungültige Kalenderdaten.'}',
      );
    }
  }
  return IcsImport(documents, warnings);
}
