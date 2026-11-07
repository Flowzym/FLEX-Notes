import 'package:uuid/uuid.dart';
import 'classroom.dart';
import 'models.dart';
import 'repository.dart';

String _id(String value) =>
    const Uuid().v5(Namespace.url.value, 'flex-timetable-2026-11-09:$value');

/// Transcribed from the supplied "Stundenplan Flex-Klasse.pdf". Abbreviations
/// and merged blocks are deliberately preserved, including the exact breaks.
List<ClassroomDocument> flexTimetableTemplate() {
  final table = ClassroomDocument.create(
    ClassroomKind.timetable,
    'FLEX-Klasse',
    {
      'date': '2026-11-09',
      'endDate': '',
      'slots': [
        for (final e in const [
          ('07:45', '08:35'),
          ('08:40', '09:30'),
          ('09:30', '10:20'),
          ('10:40', '11:30'),
          ('11:35', '12:25'),
          ('12:30', '13:20'),
          ('13:25', '14:15'),
          ('14:20', '15:10'),
          ('15:10', '16:00'),
          ('16:10', '17:00'),
        ].indexed)
          {
            'id': 'p${e.$1 + 1}',
            'label': '${e.$1 + 1}',
            'start': e.$2.$1,
            'end': e.$2.$2,
          },
      ],
    },
    id: _id('table'),
  );
  final blocks = <ClassroomDocument>[
    for (final b in const [
      (1, 1, 4, 'Flexk', 'ZiFl', ''),
      (1, 7, 7, 'PH', 'GöCh', ''),
      (1, 8, 8, 'BSPK', 'GöCh', ''),
      (2, 1, 5, 'Flexk', 'ZiFl', ''),
      (2, 9, 9, 'BUB', 'GöCh', ''),
      (3, 1, 4, 'Flexk', 'ZiFl', ''),
      (3, 5, 5, 'DG', 'GöCh', ''),
      (3, 7, 8, 'TDTE', 'GöCh', ''),
      (4, 1, 4, 'Flexk', 'ZiFl', ''),
      (4, 7, 7, 'BSPK', 'GöCh', 'TS 2'),
      (5, 1, 5, 'Flexk', 'ZiFl', ''),
      (5, 6, 6, 'BSPK', 'GöCh', 'TS 1'),
    ])
      timetableBlock(
        table,
        weekday: b.$1,
        firstSlot: b.$2 - 1,
        lastSlot: b.$3 - 1,
        title: b.$4,
        teacher: b.$5,
        room: b.$6,
        id: _id('${b.$1}-${b.$2}-${b.$4}'),
      ),
  ];
  return [table, ...blocks];
}

String timetableDay(String from, int weekday) {
  if (weekday < 1 || weekday > 7) {
    throw const DomainError('Bitte einen Wochentag wählen.');
  }
  final day = schoolDay(from);
  return dateOnly(day.add(Duration(days: (weekday - day.weekday + 7) % 7)));
}

ClassroomDocument timetableBlock(
  ClassroomDocument table, {
  required int weekday,
  required int firstSlot,
  required int lastSlot,
  required String title,
  String teacher = '',
  String room = '',
  String? id,
}) {
  final slots = table.rows('slots');
  if (firstSlot < 0 || lastSlot < firstSlot || lastSlot >= slots.length) {
    throw const DomainError(
      'Bitte Beginn und Ende des Unterrichtsblocks wählen.',
    );
  }
  return ClassroomDocument.create(ClassroomKind.lesson, title, {
    'date': timetableDay(table.text('date'), weekday),
    'start': slots[firstSlot]['start'],
    'end': slots[lastSlot]['end'],
    'subject': title,
    'teacher': teacher,
    'room': room,
    'note': '',
    'timetableId': table.id,
    'slotIds': [for (var i = firstSlot; i <= lastSlot; i++) slots[i]['id']],
    'repeat': RepeatRule(
      frequency: 'weekly',
      weekdays: [weekday],
      until: table.text('endDate').isEmpty ? null : table.text('endDate'),
      skipHolidays: true,
    ).toJson(),
    'materialIds': <String>[],
    'exceptions': <Json>[],
  }, id: id);
}

/// Fresh workspaces receive the requested plan once. Existing (even deleted)
/// lessons are never replaced or duplicated by an app update.
Future<void> initializeFlexTimetable(NotebookRepository repository) async {
  final docs = await repository.classroomDocuments();
  if (docs.any(
    (d) => d.kind == ClassroomKind.timetable || d.kind == ClassroomKind.lesson,
  )) {
    return;
  }
  try {
    await repository.saveClassroomDocuments(flexTimetableTemplate());
  } on StaleRevision {
    // Another window may have installed the same plan while this one opened.
    if (!(await repository.classroomDocuments()).any(
      (d) => d.kind == ClassroomKind.timetable,
    )) {
      rethrow;
    }
  }
}

List<ClassroomDocument> timetableBlocks(
  Iterable<ClassroomDocument> docs,
  ClassroomDocument table, {
  DateTime? at,
}) {
  var reference = dateOnly(at ?? DateTime.now());
  if (reference.compareTo(table.text('date')) < 0) {
    reference = table.text('date');
  }
  if (table.text('endDate').isNotEmpty &&
      reference.compareTo(table.text('endDate')) > 0) {
    reference = table.text('endDate');
  }
  final day = schoolDay(reference),
      monday = day.subtract(Duration(days: day.weekday - 1));
  final from = dateOnly(monday),
      to = dateOnly(monday.add(const Duration(days: 6)));
  return docs
      .where(
        (d) =>
            d.kind == ClassroomKind.lesson &&
            !d.deleted &&
            d.text('timetableId') == table.id &&
            d.text('date').compareTo(to) <= 0 &&
            (d.rule.until == null || d.rule.until!.compareTo(from) >= 0),
      )
      .toList()
    ..sort(
      (a, b) => '${schoolDay(a.text('date')).weekday} ${a.text('start')}'
          .compareTo('${schoolDay(b.text('date')).weekday} ${b.text('start')}'),
    );
}

/// Keep preparation attached when a weekly block moves to another weekday.
/// Explicit one-off movements retain their chosen date. The stable series ID
/// keeps all series planning links, while reminder occurrence IDs are rebased.
List<ClassroomDocument> changeTimetableBlock(
  Iterable<ClassroomDocument> docs,
  ClassroomDocument? old,
  ClassroomDocument edited,
) {
  if (old == null) return [edited];
  final delta =
      schoolDay(edited.text('date')).weekday -
      schoolDay(old.text('date')).weekday;
  final exceptions = [
    for (final e in old.rows('exceptions'))
      {
        ...e,
        'date': dateOnly(
          schoolDay(e['date'] as String).add(Duration(days: delta)),
        ),
      },
  ];
  final adjusted = delta == 0
      ? edited
      : edited.patch({
          'repeat': {
            ...edited.rule.toJson(),
            'excluded': [
              for (final date in old.rule.excluded)
                dateOnly(schoolDay(date).add(Duration(days: delta))),
            ],
          },
        });
  for (final e in exceptions) {
    if (!adjusted.rule.includes(
      adjusted.text('date'),
      e['date'] as String,
      [],
    )) {
      throw const DomainError(
        'Der neue Zeitraum würde angepasste Stunden ausschließen. Bitte die Gültigkeit beibehalten.',
      );
    }
  }
  return [
    adjusted.patch({'exceptions': exceptions}),
    if (delta != 0)
      for (final reminder in docs.where(
        (d) =>
            d.kind == ClassroomKind.reminder &&
            d.text('target').startsWith('lesson:${old.id}:'),
      ))
        reminder.patch({
          'target':
              'lesson:${old.id}:${dateOnly(schoolDay(reminder.text('target').split(':').last).add(Duration(days: delta)))}',
        }),
  ];
}

/// Update the period grid and its dependent blocks in one transaction. Custom
/// block times remain custom; unchanged edges still follow the period grid.
List<ClassroomDocument> changeTimetableHours(
  Iterable<ClassroomDocument> docs,
  ClassroomDocument before,
  ClassroomDocument after,
) {
  final oldSlots = {for (final s in before.rows('slots')) s['id']: s};
  final newSlots = {for (final s in after.rows('slots')) s['id']: s};
  final result = <ClassroomDocument>[after];
  for (final block in docs.where(
    (d) => d.kind == ClassroomKind.lesson && d.text('timetableId') == before.id,
  )) {
    final ids = block.strings('slotIds');
    if (ids.isEmpty || !newSlots.keys.toSet().containsAll(ids)) {
      throw const DomainError(
        'Eine verwendete Unterrichtsstunde kann nicht entfernt werden.',
      );
    }
    final weekday = schoolDay(block.text('date')).weekday;
    final anchored =
        block.text('date') == timetableDay(before.text('date'), weekday);
    var start = anchored
        ? timetableDay(after.text('date'), weekday)
        : block.text('date');
    if (start.compareTo(after.text('date')) < 0) {
      start = timetableDay(after.text('date'), weekday);
    }
    final oldEnd = before.text('endDate').isEmpty
        ? null
        : before.text('endDate');
    final newEnd = after.text('endDate').isEmpty ? null : after.text('endDate');
    var until = block.rule.until == oldEnd ? newEnd : block.rule.until;
    if (newEnd != null && (until == null || until.compareTo(newEnd) > 0)) {
      until = newEnd;
    }
    if (until != null && until.compareTo(start) < 0) {
      throw const DomainError(
        'Der Zeitraum muss die vorhandenen Unterrichtsblöcke einschließen.',
      );
    }
    final changed = block.patch({
      'date': start,
      'repeat': {...block.rule.toJson(), 'until': until},
      if (block.text('start') == oldSlots[ids.first]?['start'])
        'start': newSlots[ids.first]!['start'],
      if (block.text('end') == oldSlots[ids.last]?['end'])
        'end': newSlots[ids.last]!['end'],
    });
    result.addAll(changeTimetableBlock(docs, block, changed));
  }
  return result;
}
