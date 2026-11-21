part of 'calendar_page.dart';

Future<void> showCalendarManagement(
  BuildContext context,
  NotebookController c, {
  VoidCallback? chooseFilter,
  VoidCallback? materials,
  Future<void> Function()? importCalendar,
  Future<void> Function()? exportCalendar,
  String? date,
  bool showWeekends = false,
  ValueChanged<bool>? onWeekendsChanged,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => StatefulBuilder(
    builder: (ctx, update) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) => FlexModal(
        maxWidth: 720,
        title: const Text('Kalender verwalten'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (chooseFilter != null)
              ListTile(
                key: const ValueKey('calendar-management-filter'),
                leading: const Icon(Icons.tune),
                title: const Text('Filter'),
                onTap: () {
                  Navigator.pop(ctx);
                  chooseFilter();
                },
              ),
            if (materials != null)
              ListTile(
                key: const ValueKey('calendar-management-materials'),
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Unterlagen'),
                onTap: () {
                  Navigator.pop(ctx);
                  materials();
                },
              ),
            if (onWeekendsChanged != null)
              SwitchListTile(
                key: const ValueKey('calendar-weekends'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Samstag und Sonntag'),
                subtitle: const Text('In der Wochenansicht anzeigen'),
                value: showWeekends,
                onChanged: (value) {
                  update(() => showWeekends = value);
                  onWeekendsChanged(value);
                },
              ),
            ListTile(
              key: const ValueKey('calendar-edit-timetable'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Stundenplan'),
              subtitle: const Text('Wochenplan, Stundenzeiten und Ausnahmen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showTimetableSettings(ctx, c, date: date),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.beach_access_outlined),
              title: const Text('Ferien / Ausfall hinzufügen'),
              trailing: const Icon(Icons.add),
              onTap: () => showClassroomEditor(
                ctx,
                c,
                ClassroomKind.holiday,
                date: date,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school_outlined),
              title: const Text('Weiteren Unterricht anlegen'),
              trailing: const Icon(Icons.add),
              onTap: () =>
                  showClassroomEditor(ctx, c, ClassroomKind.lesson, date: date),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (importCalendar != null)
                  TextButton.icon(
                    onPressed: importCalendar,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('ICS importieren'),
                  ),
                if (exportCalendar != null)
                  TextButton.icon(
                    onPressed: exportCalendar,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Ansicht exportieren'),
                  ),
              ],
            ),
            const Divider(),
            Text(
              'Weitere Stunden und Ferien',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            for (final d in c.classroom.where(
              (d) =>
                  (d.isTeachingLesson && d.text('timetableId').isEmpty) ||
                  d.kind == ClassroomKind.holiday,
            ))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(d.title, style: Theme.of(ctx).textTheme.titleMedium),
                      Text(
                        '${d.label} · ${displayDate(d.text('date'))}${d.deleted ? ' · Papierkorb' : ''}',
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (!d.deleted)
                            TextButton.icon(
                              onPressed: () => showClassroomEditor(
                                ctx,
                                c,
                                d.kind,
                                document: d,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Bearbeiten'),
                            ),
                          TextButton.icon(
                            onPressed: () => guarded(
                              ctx,
                              () => c.saveClassroom(
                                d.patch({'deleted': !d.deleted}),
                              ),
                            ),
                            icon: Icon(
                              d.deleted ? Icons.restore : Icons.delete_outline,
                            ),
                            label: Text(
                              d.deleted ? 'Wiederherstellen' : 'In Papierkorb',
                            ),
                          ),
                        ],
                      ),
                      if (!d.deleted)
                        for (final e in d.rows('exceptions'))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${displayDate(e['date'] as String)} · ${e['cancelled'] == true
                                  ? 'Entfällt'
                                  : e.containsKey('movedTo') || e.containsKey('start')
                                  ? 'Zeit geändert'
                                  : 'Vorbereitung angepasst'}',
                            ),
                            trailing:
                                e['cancelled'] != true &&
                                    !e.containsKey('movedTo') &&
                                    !e.containsKey('start')
                                ? null
                                : IconButton(
                                    tooltip: e['cancelled'] == true
                                        ? 'Stunde wieder einplanen'
                                        : 'Zeitänderung zurücknehmen',
                                    icon: const Icon(Icons.undo),
                                    onPressed: () => guarded(
                                      ctx,
                                      () => c.saveClassroom(
                                        e['cancelled'] == true
                                            ? patchLessonOccurrence(
                                                d,
                                                e['date'] as String,
                                                {'cancelled': false},
                                              )
                                            : d.patch({
                                                'exceptions': [
                                                  for (final item in d.rows(
                                                    'exceptions',
                                                  ))
                                                    if (item['date'] !=
                                                        e['date'])
                                                      item
                                                    else
                                                      {
                                                        for (final field
                                                            in item.entries)
                                                          if (!{
                                                            'movedTo',
                                                            'start',
                                                            'end',
                                                          }.contains(field.key))
                                                            field.key:
                                                                field.value,
                                                      },
                                                ],
                                              }),
                                      ),
                                    ),
                                  ),
                          ),
                    ],
                  ),
                ),
              ),
            if (!c.classroom.any(
              (d) =>
                  (d.isTeachingLesson && d.text('timetableId').isEmpty) ||
                  d.kind == ClassroomKind.holiday,
            ))
              const Text('Noch kein Unterricht und keine Ferien erfasst.'),
          ],
        ),
      ),
    ),
  ),
);
