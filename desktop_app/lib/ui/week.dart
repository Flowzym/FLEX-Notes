part of 'workspace.dart';

extension _WeekDesk on _DesktopWorkspaceState {
  Widget weekDesk() {
    final week = buildWeekFolder(c.notebook.currentSnapshot, c.date);
    final day = week[c.date.weekday - 1];
    final calendar = day.agenda
        .where((i) => !_deadlineKinds.contains(i.category))
        .toList();
    final due = day.agenda
        .where((i) => _deadlineKinds.contains(i.category))
        .toList();
    final planned = day.materials.map((m) => m.id).toSet();
    final suggestions = suggestedMaterials(
      c.notebook.classroom,
      dateOnly(day.day),
    ).where((m) => !planned.contains(m.id)).toList();
    final sessions = weekPanel(
      'Unterricht & Termine',
      Icons.schedule_outlined,
      [for (final i in calendar) weekEntry(i)],
      'Für diesen Tag ist kein Unterricht oder Termin eingetragen.',
      action: IconButton(
        tooltip: 'Termin für diesen Tag anlegen',
        onPressed: () =>
            run(() => c.start(EntryKind.appointment, onDate: day.day)),
        icon: const Icon(Icons.add),
      ),
    );
    final deadlines = weekPanel(
      'Fristen & Abgaben',
      Icons.fact_check_outlined,
      [for (final i in due) weekEntry(i)],
      'Für diesen Tag sind keine Fristen eingetragen.',
    );
    final materials = weekPanel(
      'Unterlagen',
      Icons.folder_open_outlined,
      [
        for (final m in day.materials) weekFile(m, day.day),
        if (suggestions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Aus der Unterrichtsplanung',
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
          ),
          for (final m in suggestions) weekFile(m, day.day, suggestion: true),
        ],
      ],
      'Für diesen Tag sind keine Unterlagen bereitgelegt.',
      action: IconButton(
        tooltip: 'Unterlagen für diesen Tag auswählen',
        onPressed: () => run(() => pickDayMaterials(day.day)),
        icon: const Icon(Icons.add),
      ),
    );
    return ListView(
      key: const PageStorageKey('week-folder'),
      padding: const EdgeInsets.all(26),
      children: [
        SectionHeading(
          'Wochenmappe',
          subtitle: weekRange(week.first.day, week.last.day),
          actions: [
            IconButton(
              tooltip: 'Vorherige Woche',
              onPressed: () => c.setDate(calendarDay(c.date, -7)),
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton(
              onPressed: () => c.setDate(DateTime.now()),
              child: const Text('Heute'),
            ),
            IconButton(
              tooltip: 'Nächste Woche',
              onPressed: () => c.setDate(calendarDay(c.date, 7)),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Wochenmappe als PDF speichern',
              onPressed: () => run(() async {
                final bytes = await weekFolderPdf(week, c.name);
                if (await saveBytesFile(
                      'FLEX-Wochenmappe-${dateOnly(week.first.day)}.pdf',
                      bytes,
                      mime: 'application/pdf',
                    ) &&
                    mounted) {
                  message('Wochenmappe gespeichert');
                }
              }),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
        ),
        Material(
          color: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              for (final d in week)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final active = d == day;
                      final count = d.agenda.length + d.materials.length;
                      return Semantics(
                        selected: active,
                        button: true,
                        label:
                            '${dayName(d.day)}, ${d.day.day}. ${monthName(d.day)}, $count Einträge',
                        child: Ink(
                          color: active ? olive : null,
                          child: InkWell(
                            onTap: () => c.setDate(d.day),
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      dayName(d.day).substring(0, 2),
                                      style: TextStyle(
                                        color: active ? white : muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${d.day.day}',
                                      style: TextStyle(
                                        color: active ? white : ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 25,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 3,
                                      width: 16,
                                      child: ColoredBox(
                                        color: count == 0
                                            ? Colors.transparent
                                            : active
                                            ? white
                                            : olive,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                '${dayName(day.day)}, ${day.day.day}. ${monthName(day.day)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                redraw(() => calendarView = 'Tag');
                c.navigate(WorkspaceSection.calendar);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: const Text('Tagesraster'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, box) {
            final agenda = Column(
              children: [sessions, const SizedBox(height: 14), deadlines],
            );
            if (box.maxWidth < 760) {
              return Column(
                children: [agenda, const SizedBox(height: 14), materials],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: agenda),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: materials),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget weekPanel(
    String title,
    IconData icon,
    List<Widget> rows,
    String empty, {
    Widget? action,
  }) => Surface(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
          child: Row(
            children: [
              Icon(icon, size: 19, color: olive),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),
        ),
        const Divider(),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(empty, style: const TextStyle(color: muted)),
          )
        else
          ...rows,
      ],
    ),
  );

  Widget weekEntry(CalendarItem i) => ListTile(
    leading: i.time.isEmpty
        ? Icon(
            i.done ? Icons.task_alt : Icons.event_note_outlined,
            color: olive,
          )
        : Text(i.time, style: const TextStyle(fontWeight: FontWeight.w600)),
    title: Text(i.title),
    subtitle: Text(
      [
        calendarCategories[i.category] ?? i.category,
        if (i.end.isNotEmpty) 'bis ${i.end}',
        if (i.detail.isNotEmpty) i.detail,
        if (i.done) 'Erledigt',
      ].join(' · '),
    ),
    onTap: () => viewCalendarItem(i),
  );

  Future<void> viewCalendarItem(CalendarItem i) async {
    if (i.document?.kind == ClassroomKind.holiday) {
      final d = i.document!;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(d.title),
          content: Text(
            '${shortDate(d.text('date'))} – ${shortDate(d.text('endDate'))}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
      return;
    }
    await run(() => c.openCalendar(i));
  }

  Widget weekFile(
    ClassroomDocument m,
    DateTime day, {
    bool suggestion = false,
  }) {
    final owners = materialDayOwners(m, dateOnly(day), c.name);
    return ListTile(
      leading: MaterialThumbnail(
        material: m,
        files: c.files,
        width: 34,
        height: 42,
      ),
      title: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (owners.isNotEmpty) owners,
          if (m.text('subject').isNotEmpty) m.text('subject'),
          m.text('extension').toUpperCase(),
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: suggestion
          ? IconButton(
              tooltip: 'Für diesen Tag bereitlegen',
              icon: const Icon(Icons.playlist_add),
              onPressed: () => run(() => c.prepareForDay([m.id], day)),
            )
          : null,
      onTap: () => run(() => c.edit(m)),
    );
  }

  Future<void> pickDayMaterials(DateTime day) async {
    final available = c.materials;
    if (available.isEmpty) {
      c.navigate(WorkspaceSection.materials);
      return;
    }
    final already = preparedDayMaterials(
      c.notebook.classroom,
      dateOnly(day),
    ).map((m) => m.id).toSet();
    final selected = <String>{};
    var query = '';
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final matches = available
              .where((m) => materialMatches(m, query, pupils: c.pupils))
              .toList();
          return AlertDialog(
            title: Text('Unterlagen für ${shortDate(dateOnly(day))}'),
            content: SizedBox(
              width: 470,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Material suchen',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => update(() => query = value),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(
                            child: Text('Keine passenden Materialien'),
                          )
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (_, index) {
                              final m = matches[index];
                              return CheckboxListTile(
                                title: Text(m.title),
                                subtitle: already.contains(m.id)
                                    ? const Text('Schon bereitgelegt')
                                    : null,
                                value:
                                    already.contains(m.id) ||
                                    selected.contains(m.id),
                                onChanged: already.contains(m.id)
                                    ? null
                                    : (v) => update(() {
                                        if (v == true) {
                                          selected.add(m.id);
                                        } else {
                                          selected.remove(m.id);
                                        }
                                      }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, selected.toList()),
                child: Text('Bereitlegen (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
    if (ids != null) await c.prepareForDay(ids, day);
  }
}

const _deadlineKinds = {'task', 'homework', 'return', 'goal'};
