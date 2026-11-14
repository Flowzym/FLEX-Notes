part of 'timetable.dart';

class _TimetableManagement extends StatefulWidget {
  const _TimetableManagement({
    required this.controller,
    required this.tableId,
    this.date,
  });
  final NotebookController controller;
  final String tableId;
  final String? date;
  @override
  State<_TimetableManagement> createState() => _TimetableManagementState();
}

class _TimetableManagementState extends State<_TimetableManagement> {
  late DateTime reference = schoolDay(widget.date ?? dateOnly(DateTime.now()));
  String section = 'plan';
  NotebookController get c => widget.controller;

  String blockStart(ClassroomDocument table) {
    final monday = dateOnly(
      reference.subtract(Duration(days: reference.weekday - 1)),
    );
    return monday.compareTo(table.text('date')) < 0
        ? table.text('date')
        : monday;
  }

  bool canAdd(ClassroomDocument table, int day) =>
      table.text('endDate').isEmpty ||
      timetableDay(blockStart(table), day).compareTo(table.text('endDate')) <=
          0;

  Future<void> pickWeek() async {
    final result = await pickFlexDate(
      context,
      date: dateOnly(reference),
      allowTime: false,
    );
    if (result != null && mounted) {
      setState(() => reference = schoolDay(result.$1));
    }
  }

  Widget blockRow(
    ClassroomDocument table,
    ClassroomDocument block, {
    bool overlap = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            key: ValueKey('timetable-block-${block.id}'),
            onTap: () =>
                showTimetableBlockEditor(context, c, table, document: block),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.text('start'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          block.text('end'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            blockPeriodLabel(table, block),
                            block.text('teacher'),
                            block.text('room'),
                            if (block.rule.interval > 1)
                              'Alle ${block.rule.interval} Wochen',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (block.rule.until != null ||
                            block.text('date') !=
                                timetableDay(
                                  table.text('date'),
                                  schoolDay(block.text('date')).weekday,
                                ))
                          Text(
                            'Ab ${displayDate(block.text('date'))}${block.rule.until == null ? '' : ' · bis ${displayDate(block.rule.until!)}'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (overlap)
                          Text(
                            'Zeitliche Überschneidung',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: ValueKey('timetable-copy-${block.id}'),
          tooltip: 'Block kopieren',
          icon: const Icon(Icons.copy_outlined, size: 19),
          onPressed: () => showTimetableBlockEditor(
            context,
            c,
            table,
            copyFrom: block,
            weekday: schoolDay(block.text('date')).weekday,
            from: blockStart(table),
          ),
        ),
        IconButton(
          tooltip: 'Block bearbeiten',
          icon: const Icon(Icons.edit_outlined, size: 19),
          onPressed: () =>
              showTimetableBlockEditor(context, c, table, document: block),
        ),
      ],
    ),
  );

  Widget changes(List<ClassroomDocument> blocks, ClassroomDocument table) {
    final exceptions =
        [
          for (final block in blocks.where((b) => !b.deleted))
            for (final e in block.rows('exceptions')) (block: block, entry: e),
        ]..sort(
          (a, b) =>
              (b.entry['date'] as String).compareTo(a.entry['date'] as String),
        );
    final removed = blocks.where((b) => b.deleted).toList();
    final past = blocks
        .where(
          (b) =>
              !b.deleted &&
              b.rule.until != null &&
              b.rule.until!.compareTo(dateOnly(reference)) < 0,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Einzelne Durchführungen',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (exceptions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Keine einzelnen Stunden geändert.'),
          ),
        for (final item in exceptions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.block.title),
            subtitle: Text(
              '${displayDate(item.entry['date'] as String)} · ${item.entry['cancelled'] == true
                  ? 'Entfällt'
                  : item.entry.containsKey('movedTo') || item.entry.containsKey('start')
                  ? 'Zeit geändert'
                  : 'Vorbereitung angepasst'}',
            ),
            trailing:
                item.entry['cancelled'] == true ||
                    item.entry.containsKey('movedTo') ||
                    item.entry.containsKey('start')
                ? IconButton(
                    tooltip: 'Zeitänderung / Ausfall zurücknehmen',
                    icon: const Icon(Icons.undo),
                    onPressed: () => guarded(
                      context,
                      () => c.saveClassroom(
                        item.entry['cancelled'] == true
                            ? patchLessonOccurrence(
                                item.block,
                                item.entry['date'] as String,
                                {'cancelled': false},
                              )
                            : item.block.patch({
                                'exceptions': [
                                  for (final e in item.block.rows('exceptions'))
                                    if (e['date'] != item.entry['date'])
                                      e
                                    else
                                      {
                                        for (final field in e.entries)
                                          if (!{
                                            'movedTo',
                                            'start',
                                            'end',
                                          }.contains(field.key))
                                            field.key: field.value,
                                      },
                                ],
                              }),
                      ),
                    ),
                  )
                : null,
          ),
        if (past.isNotEmpty) ...[
          const Divider(),
          Text('Frühere Blöcke', style: Theme.of(context).textTheme.titleSmall),
          for (final block in past) blockRow(table, block),
        ],
        const Divider(),
        Text('Entfernte Blöcke', style: Theme.of(context).textTheme.titleSmall),
        if (removed.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Keine entfernten Blöcke.'),
          ),
        for (final block in removed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(block.title),
            subtitle: Text(
              '${calendarWeekday(schoolDay(block.text('date')))} · ${block.text('start')}–${block.text('end')}',
            ),
            trailing: IconButton(
              tooltip: 'Block wiederherstellen',
              icon: const Icon(Icons.restore),
              onPressed: () => guarded(
                context,
                () => c.saveClassroom(block.patch({'deleted': false})),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final table = c.classroom
          .where((d) => d.id == widget.tableId && !d.deleted)
          .firstOrNull;
      if (table == null) {
        return FlexModal(
          title: const Text('Stundenplan'),
          onClose: () => Navigator.pop(ctx),
          content: const Text('Dieser Stundenplan ist nicht mehr verfügbar.'),
        );
      }
      final all = c.classroom
          .where(
            (b) =>
                b.kind == ClassroomKind.lesson &&
                b.text('timetableId') == table.id,
          )
          .toList();
      final monday = reference.subtract(Duration(days: reference.weekday - 1));
      final blocks = timetableBlocks(all, table, at: reference).where((block) {
        final occurrence = timetableDay(
          dateOnly(monday),
          schoolDay(block.text('date')).weekday,
        );
        return block.rule.includes(block.text('date'), occurrence, []);
      }).toList();
      final occurrences = lessonOccurrences(
        c.classroom,
        dateOnly(monday),
        dateOnly(monday.add(const Duration(days: 6))),
      );
      final overlaps = <String>{};
      for (var i = 0; i < occurrences.length; i++) {
        for (var j = i + 1; j < occurrences.length; j++) {
          final a = occurrences[i], b = occurrences[j];
          if (a.date == b.date &&
              a.start.isNotEmpty &&
              b.start.isNotEmpty &&
              a.start.compareTo(b.end) < 0 &&
              b.start.compareTo(a.end) < 0) {
            overlaps.addAll([a.document.id, b.document.id]);
          }
        }
      }
      return FlexModal(
        title: const Text('Stundenplan verwalten'),
        maxWidth: 820,
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            OptionBar(
              keyPrefix: 'timetable-section',
              fontSize: 12,
              horizontalPadding: 4,
              value: section,
              options: const {
                'plan': 'Wochenplan',
                'hours': 'Zeiten',
                'changes': 'Änderungen',
              },
              onChanged: (value) => setState(() => section = value),
            ),
            const SizedBox(height: 12),
            if (section == 'plan') ...[
              Row(
                children: [
                  IconButton(
                    tooltip: 'Vorherige Planwoche',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(
                      () => reference = reference.subtract(
                        const Duration(days: 7),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('timetable-reference'),
                      onPressed: pickWeek,
                      child: Text(
                        calendarRangeLabel(
                          monday,
                          monday.add(const Duration(days: 6)),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nächste Planwoche',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(
                      () => reference = reference.add(const Duration(days: 7)),
                    ),
                  ),
                ],
              ),
              Text(
                'Grundplan · Einzelne Ausfälle und Verschiebungen stehen unter Änderungen.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              if (table.text('endDate').isNotEmpty &&
                  dateOnly(
                        monday.add(const Duration(days: 6)),
                      ).compareTo(table.text('endDate')) >
                      0)
                TextButton.icon(
                  onPressed: () => setState(() => section = 'hours'),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    'Plan endet am ${displayDate(table.text('endDate'))} · Gültigkeit anpassen',
                  ),
                ),
              for (var day = 1; day <= 7; day++) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        calendarWeekday(monday.add(Duration(days: day - 1))),
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('timetable-add-$day'),
                      tooltip:
                          'Block hinzufügen · ${calendarWeekday(monday.add(Duration(days: day - 1)))}',
                      icon: const Icon(Icons.add),
                      onPressed: !canAdd(table, day)
                          ? null
                          : () => showTimetableBlockEditor(
                              ctx,
                              c,
                              table,
                              weekday: day,
                              from: blockStart(table),
                            ),
                    ),
                  ],
                ),
                if (!blocks.any(
                  (b) => schoolDay(b.text('date')).weekday == day,
                ))
                  const Text('Kein Unterricht', style: TextStyle(fontSize: 12)),
                for (final block in blocks.where(
                  (b) => schoolDay(b.text('date')).weekday == day,
                ))
                  blockRow(table, block, overlap: overlaps.contains(block.id)),
              ],
            ] else if (section == 'hours') ...[
              Text(
                'Gültig ab ${displayDate(table.text('date'))}${table.text('endDate').isEmpty ? '' : ' bis ${displayDate(table.text('endDate'))}'}',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('timetable-edit-hours'),
                onPressed: () => showTimetableHours(ctx, c, table),
                icon: const Icon(Icons.schedule),
                label: const Text('Zeiten & Gültigkeit bearbeiten'),
              ),
              for (final slot in table.rows('slots'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${slot['label']}.'),
                  title: Text('${slot['start']}–${slot['end']}'),
                  subtitle: Text(
                    '${clockMinutes(slot['end'] as String) - clockMinutes(slot['start'] as String)} Minuten',
                  ),
                ),
            ] else
              changes(all, table),
          ],
        ),
      );
    },
  );
}
