import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/calendar_layout.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/timetable.dart';
import 'common.dart';
import 'dialog_workflows.dart';
import 'flex_modal.dart';
import 'option_bar.dart';

part 'timetable_management.dart';

Future<void> showTimetableSettings(
  BuildContext context,
  NotebookController c, {
  String? date,
}) async {
  final table = c.classroom
      .where((d) => d.kind == ClassroomKind.timetable)
      .firstOrNull;
  if (table != null && !table.deleted) {
    await showTimetableManagement(context, c, table, date: date);
    return;
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => FlexModal(
      title: const Text('Stundenplan bearbeiten'),
      onClose: () => Navigator.pop(ctx),
      content: Text(
        table == null
            ? 'Die Vorlage aus deinem PDF übernehmen? Vorhandene Kalendereinträge bleiben erhalten.'
            : 'Der Stundenplan liegt im Papierkorb. Wiederherstellen?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            table == null ? 'Stundenplan übernehmen' : 'Wiederherstellen',
          ),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  await guarded(context, () async {
    await c.saveClassroomBatch(
      table == null
          ? flexTimetableTemplate()
          : [
              table.patch({'deleted': false}),
            ],
    );
    if (context.mounted) await showTimetableSettings(context, c, date: date);
  });
}

Future<void> showTimetableManagement(
  BuildContext context,
  NotebookController c,
  ClassroomDocument table, {
  String? date,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _TimetableManagement(controller: c, tableId: table.id, date: date),
);

String blockPeriodLabel(ClassroomDocument table, ClassroomDocument block) {
  final slots = table
      .rows('slots')
      .where((s) => block.strings('slotIds').contains(s['id']))
      .toList();
  if (slots.isEmpty) return '';
  return slots.length == 1
      ? '${slots.first['label']}. Stunde'
      : '${slots.first['label']}.–${slots.last['label']}. Stunde';
}

Future<void> showTimetableBlockEditor(
  BuildContext context,
  NotebookController c,
  ClassroomDocument table, {
  ClassroomDocument? document,
  ClassroomDocument? copyFrom,
  String? from,
  int weekday = 1,
  DialogDraft? draft,
}) async {
  final source =
      document ?? c.classroom.where((d) => d.id == draft?.ownerId).firstOrNull;
  final initial =
      draft?.data ??
      {
        ...(source ??
                timetableBlock(
                  from == null ? table : table.patch({'date': from}),
                  weekday: weekday,
                  firstSlot: 0,
                  lastSlot: 0,
                  title: 'Unterricht',
                ))
            .toJson(),
        if (copyFrom != null) ...{
          'title': copyFrom.title,
          'subject': copyFrom.text('subject'),
          'teacher': copyFrom.text('teacher'),
          'room': copyFrom.text('room'),
          'note': copyFrom.text('note'),
          'slotIds': copyFrom.strings('slotIds'),
          'start': copyFrom.text('start'),
          'end': copyFrom.text('end'),
          'repeat': {
            'frequency': 'weekly',
            'interval': copyFrom.rule.interval,
            'weekdays': [weekday],
            'until': table.text('endDate').isEmpty
                ? null
                : table.text('endDate'),
            'skipHolidays': copyFrom.rule.skipHolidays,
            'excluded': <String>[],
          },
        },
        '_timetableEditor': true,
        '_tableRevision': table.revision,
        '_weekday': source == null
            ? weekday
            : schoolDay(source.text('date')).weekday,
      };
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProtectedDialog(
      controller: c,
      type: 'classroom',
      ownerId: initial['id'] as String,
      title: 'Unterrichtsblock',
      initial: initial,
      draft: draft,
      save: (data, buffer) async {
        final current = c.classroom.where((d) => d.id == table.id).firstOrNull;
        if (current == null ||
            current.deleted ||
            current.revision != data['_tableRevision']) {
          throw const StaleRevision();
        }
        final old = c.classroom.where((d) => d.id == data['id']).firstOrNull;
        // Preserve a split series' own validity, exclusions and holiday policy.
        final original = schoolDay(data['date'] as String);
        final week = original.subtract(Duration(days: original.weekday - 1));
        final from = dateOnly(week).compareTo(current.text('date')) < 0
            ? current.text('date')
            : dateOnly(week);
        final changed = ClassroomDocument.fromJson({
          for (final e in data.entries)
            if (!e.key.startsWith('_')) e.key: e.value,
          'date': timetableDay(from, data['_weekday'] as int),
          'subject': data['title'],
          'repeat': {
            ...Json.from(data['repeat'] as Map),
            'weekdays': [data['_weekday'] as int],
          },
        });
        await c.repository.saveClassroomDocuments(
          changeTimetableBlock(c.classroom, old, changed),
          draft: buffer,
        );
      },
      body: (ctx, data, change) {
        final slots = table.rows('slots');
        final selected = List<String>.from(data['slotIds'] as List);
        Widget text(String field, String label, {int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            key: ValueKey('timetable-$field'),
            initialValue: data[field] as String? ?? '',
            maxLines: lines,
            decoration: InputDecoration(labelText: label),
            onChanged: (v) => change({field: v}),
          ),
        );
        void periods(String first, String last) {
          final a = slots.indexWhere((s) => s['id'] == first),
              b = slots.indexWhere((s) => s['id'] == last);
          if (a > b) return;
          change({
            'slotIds': [for (var i = a; i <= b; i++) slots[i]['id']],
            'start': slots[a]['start'],
            'end': slots[b]['end'],
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Wöchentlich · gesamte Unterrichtsserie'),
            const SizedBox(height: 12),
            text('title', 'Fach / Bezeichnung'),
            DropdownButtonFormField<int>(
              key: const ValueKey('timetable-weekday'),
              initialValue: data['_weekday'] as int,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Wochentag'),
              items: [
                for (var i = 1; i <= 7; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      calendarWeekday(
                        DateTime.utc(2026, 11, 9).add(Duration(days: i - 1)),
                      ),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) change({'_weekday': v});
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('timetable-first-${selected.first}'),
              initialValue: selected.first,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Von Stunde'),
              items: [
                for (final s in slots)
                  DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['label']}. · ${s['start']}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  final a = slots.indexWhere((s) => s['id'] == v),
                      b = slots.indexWhere((s) => s['id'] == selected.last);
                  periods(v, a > b ? v : selected.last);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('timetable-last-${selected.last}'),
              initialValue: selected.last,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bis Stunde'),
              items: [
                for (final s in slots.skip(
                  slots.indexWhere((s) => s['id'] == selected.first),
                ))
                  DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['label']}. · ${s['end']}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) periods(selected.first, v);
              },
            ),
            const SizedBox(height: 12),
            for (final field in ['start', 'end'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: ValueKey('timetable-clock-$field-${selected.join('-')}'),
                  initialValue: data[field] as String,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: field == 'start'
                        ? 'Beginn (HH:MM)'
                        : 'Ende (HH:MM)',
                  ),
                  onChanged: (v) => change({field: v.trim()}),
                ),
              ),
            text('teacher', 'Lehrkraft / Kürzel'),
            text('room', 'Raum'),
            text('note', 'Notiz', lines: 3),
            if (source != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  data['deleted'] == true
                      ? 'Block wird entfernt'
                      : 'Block entfernen',
                ),
                onPressed: () => change({'deleted': data['deleted'] != true}),
              ),
            if (data['deleted'] == true)
              const Text(
                'Mit Speichern wird der Block in den Papierkorb verschoben.',
              ),
          ],
        );
      },
    ),
  );
}

Future<void> showTimetableHours(
  BuildContext context,
  NotebookController c,
  ClassroomDocument table, {
  DialogDraft? draft,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ProtectedDialog(
    controller: c,
    type: 'classroom',
    ownerId: table.id,
    title: 'Stundenzeiten & Gültigkeit',
    initial: table.toJson(),
    draft: draft,
    maxWidth: 820,
    save: (data, buffer) async {
      final before = c.classroom.where((d) => d.id == table.id).firstOrNull;
      if (before == null || before.revision != data['revision']) {
        throw const StaleRevision();
      }
      final after = ClassroomDocument.fromJson(data);
      await c.repository.saveClassroomDocuments(
        changeTimetableHours(c.classroom, before, after),
        draft: buffer,
      );
    },
    body: (ctx, data, change) {
      final slots = (data['slots'] as List)
          .map((s) => Json.from(s as Map))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final field in ['date', 'endDate'])
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    '${field == 'date' ? 'Gültig ab' : 'Bis'}: ${data[field] == '' ? 'ohne Ende' : displayDate(data[field] as String)}',
                  ),
                  onPressed: () async {
                    final result = await pickFlexDate(
                      ctx,
                      date: data[field] == ''
                          ? data['date'] as String
                          : data[field] as String,
                      allowTime: false,
                    );
                    if (result != null) change({field: result.$1});
                  },
                ),
              if (data['endDate'] != '')
                TextButton(
                  onPressed: () => change({'endDate': ''}),
                  child: const Text('Ohne Enddatum'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in slots.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.$2['label']}. Stunde',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        key: ValueKey('period-remove-${entry.$2['id']}'),
                        tooltip:
                            c.classroom.any(
                              (d) =>
                                  d.kind == ClassroomKind.lesson &&
                                  d.text('timetableId') == table.id &&
                                  d.strings('slotIds').contains(entry.$2['id']),
                            )
                            ? 'Diese Stunde wird von Unterrichtsblöcken verwendet'
                            : 'Stunde entfernen',
                        onPressed:
                            slots.length <= 1 ||
                                c.classroom.any(
                                  (d) =>
                                      d.kind == ClassroomKind.lesson &&
                                      d.text('timetableId') == table.id &&
                                      d
                                          .strings('slotIds')
                                          .contains(entry.$2['id']),
                                )
                            ? null
                            : () => change({
                                'slots': [
                                  for (final slot in slots)
                                    if (slot['id'] != entry.$2['id']) slot,
                                ],
                              }),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final field in ['start', 'end'])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: field == 'start' ? 8 : 0,
                            ),
                            child: TextFormField(
                              key: ValueKey('period-${entry.$2['id']}-$field'),
                              initialValue: entry.$2[field] as String,
                              keyboardType: TextInputType.datetime,
                              decoration: InputDecoration(
                                labelText: field == 'start' ? 'Beginn' : 'Ende',
                              ),
                              onChanged: (v) => change({
                                'slots': [
                                  for (final e in slots.indexed)
                                    if (e.$1 == entry.$1)
                                      {...e.$2, field: v.trim()}
                                    else
                                      e.$2,
                                ],
                              }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            key: const ValueKey('period-add'),
            onPressed: slots.length >= 20
                ? null
                : () {
                    final last = slots.last['end'] as String;
                    final start = validClock(last) ? clockMinutes(last) + 5 : 0;
                    change({
                      'slots': [
                        ...slots,
                        {
                          'id': newId(),
                          'label': '${slots.length + 1}',
                          'start': start + 50 < 1440 ? minuteClock(start) : '',
                          'end': start + 50 < 1440
                              ? minuteClock(start + 50)
                              : '',
                        },
                      ],
                    });
                  },
            icon: const Icon(Icons.add),
            label: const Text('Stunde hinzufügen'),
          ),
        ],
      );
    },
  ),
);

Future<void> resumeTimetableDraft(
  BuildContext context,
  NotebookController c,
  DialogDraft draft,
) async {
  final tableId = draft.data['kind'] == 'timetable'
      ? draft.ownerId
      : draft.data['timetableId'];
  final table = c.classroom
      .where(
        (d) =>
            d.id == tableId && d.kind == ClassroomKind.timetable && !d.deleted,
      )
      .firstOrNull;
  if (table == null) {
    throw const DomainError(
      'Der zugehörige Stundenplan ist nicht mehr vorhanden.',
    );
  }
  if (draft.data['kind'] == 'timetable') {
    await showTimetableHours(context, c, table, draft: draft);
  } else {
    await showTimetableBlockEditor(context, c, table, draft: draft);
  }
}
