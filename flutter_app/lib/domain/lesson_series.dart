import 'classroom.dart';
import 'models.dart';

/// Split at an original occurrence date, preserving the earlier series and
/// moving dated attachments and reminder targets along with future occurrences.
/// The caller saves the complete result in one revision-checked transaction.
List<ClassroomDocument> splitLessonSeries(
  Iterable<ClassroomDocument> documents,
  ClassroomDocument source,
  ClassroomDocument following,
  String from,
) {
  if (source.kind != ClassroomKind.lesson ||
      following.kind != ClassroomKind.lesson ||
      following.id == source.id ||
      !validDate(from) ||
      from.compareTo(source.text('date')) <= 0 ||
      !source.rule.includes(source.text('date'), from, []) ||
      following.text('date') != from) {
    throw const DomainError(
      'Bitte den Beginn der Änderung beibehalten. Einzelne Termine lassen sich separat verschieben.',
    );
  }
  final future = source
      .rows('exceptions')
      .where((e) => (e['date'] as String).compareTo(from) >= 0)
      .toList();
  for (final e in future) {
    if (!following.rule.includes(from, e['date'] as String, [])) {
      throw const DomainError(
        'Die Änderung würde bereits angepasste Stunden ausschließen. Bitte deren Termine zuerst prüfen.',
      );
    }
  }
  bool belongsToFuture(String date) => lessonOccurrences(
    [source],
    date,
    date,
  ).any((l) => l.originalDate.compareTo(from) >= 0);
  bool belongsToPast(String date) => lessonOccurrences(
    [source],
    date,
    date,
  ).any((l) => l.originalDate.compareTo(from) < 0);
  final result = <ClassroomDocument>[
    source.patch({
      'repeat': {
        ...source.rule.toJson(),
        'until': dateOnly(schoolDay(from).subtract(const Duration(days: 1))),
      },
      'exceptions': source
          .rows('exceptions')
          .where((e) => (e['date'] as String).compareTo(from) < 0)
          .toList(),
    }),
    following.patch({'exceptions': future}),
  ];
  for (final doc in documents) {
    if (doc.id == source.id || doc.id == following.id) continue;
    final changes = <String, dynamic>{};
    if (doc.kind == ClassroomKind.plan &&
        doc.strings('lessonIds').contains(source.id)) {
      changes['lessonIds'] = {
        ...doc.strings('lessonIds'),
        following.id,
      }.toList();
    }
    final target = doc.text('target'), prefix = 'lesson:${source.id}:';
    if (doc.kind == ClassroomKind.reminder &&
        target.startsWith(prefix) &&
        target.substring(prefix.length).compareTo(from) >= 0) {
      if (!following.rule.includes(from, target.substring(prefix.length), [])) {
        throw const DomainError(
          'Die Änderung würde eine vorgemerkte Erinnerung ausschließen. Bitte deren Termin zuerst prüfen.',
        );
      }
      changes['target'] =
          'lesson:${following.id}:${target.substring(prefix.length)}';
    }
    if (doc.kind == ClassroomKind.material) {
      final links = <Json>[];
      var changed = false;
      for (final link in doc.rows('links')) {
        final date = link['date'] as String? ?? '';
        if (link['id'] == source.id && link['kind'] == 'classroom') {
          links.add(link);
          links.add({...link, 'id': following.id});
          changed = true;
        } else if (link['id'] == source.id &&
            link['kind'] == 'lesson' &&
            validDate(date) &&
            (belongsToFuture(date) ||
                // Cancelled occurrences may still have retained attachments.
                source
                    .rows('exceptions')
                    .any(
                      (e) =>
                          e['cancelled'] == true &&
                          (e['movedTo'] ?? e['date']) == date &&
                          (e['date'] as String).compareTo(from) >= 0,
                    ))) {
          for (final occurrence in lessonOccurrences(
            [source],
            date,
            date,
          ).where((l) => l.originalDate.compareTo(from) >= 0)) {
            if (!following.rule.includes(from, occurrence.originalDate, [])) {
              throw const DomainError(
                'Die Änderung würde eine Stunde mit zugeordneten Dateien ausschließen. Bitte deren Termin zuerst prüfen.',
              );
            }
          }
          if (belongsToPast(date)) links.add(link);
          links.add({...link, 'id': following.id});
          changed = true;
        } else {
          links.add(link);
        }
      }
      if (changed) changes['links'] = links;
    }
    if (changes.isNotEmpty) result.add(doc.patch(changes));
  }
  return result;
}
