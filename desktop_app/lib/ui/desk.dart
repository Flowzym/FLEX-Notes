part of 'workspace.dart';

extension _DeskViews on _DesktopWorkspaceState {
  Widget desk() => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      SectionHeading(
        'Arbeitsplatz',
        subtitle:
            '${dayName(c.date)}, ${c.date.day}. ${monthName(c.date)} ${c.date.year}',
        actions: [
          TextButton.icon(
            onPressed: () => c.navigate(WorkspaceSection.week),
            icon: const Icon(Icons.date_range_outlined, size: 17),
            label: const Text('Wochenmappe öffnen'),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (ctx, box) {
          final items = c
              .agenda(c.date)
              .where(
                (i) => i.category == 'lesson' || i.category == 'appointment',
              )
              .take(3)
              .toList();
          return Surface(
            padding: const EdgeInsets.all(18),
            color: const Color(0xffedf0e7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 16, top: 3),
                  child: Icon(Icons.wb_sunny_outlined, color: olive, size: 26),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEIN TAG',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                          color: olive,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        Text(
                          'Noch keine Stunden oder Termine geplant.',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      Wrap(
                        spacing: 28,
                        runSpacing: 12,
                        children: [
                          for (final item in items)
                            InkWell(
                              onTap: () =>
                                  run(() => openDeskCalendarItem(item)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.time.isEmpty
                                        ? 'Ganztägig'
                                        : '${item.time} – ${item.end}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Termin hinzufügen',
                  onPressed: () =>
                      run(() => newDesktopEntry(EntryKind.appointment)),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Die FLEX-Klasse',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${c.pupils.length} Schüler',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Schüler hinzufügen',
            onPressed: addPupil,
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Text(
          'Beobachten, festhalten, weiterarbeiten.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ),
      if (c.pupils.isEmpty)
        Surface(
          child: QuietEmpty(
            'Deine Klasse ist noch leer',
            'Übernimm eine FLEX-Sicherung oder lege den ersten Schüler an.',
            icon: Icons.people_outline,
            action: FilledButton.icon(
              onPressed: addPupil,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Schüler hinzufügen'),
            ),
          ),
        ),
      LayoutBuilder(
        builder: (ctx, box) {
          final columns = box.maxWidth >= 720
              ? 3
              : box.maxWidth >= 480
              ? 2
              : 1;
          final width = (box.maxWidth - (columns - 1) * 14) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final p in c.pupils)
                SizedBox(width: width, child: pupilCard(p)),
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(
              'Zuletzt festgehalten',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            onPressed: () => c.navigate(WorkspaceSection.journal),
            child: const Text('Journal öffnen'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Surface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (c.notebook.records.where((r) => !r.deleted).isEmpty)
              const QuietEmpty(
                'Platz für Beobachtungen',
                'Wähle bei einem Schüler Sozial, Arbeit, Ziele oder HÜ.',
              ),
            for (final r in recentRecords().take(4)) recordRow(r),
          ],
        ),
      ),
    ],
  );
  List<SchoolRecord> recentRecords({String? pupil}) =>
      c.notebook.records
          .where((r) => !r.deleted && (pupil == null || r.pupilId == pupil))
          .toList()
        ..sort(
          (a, b) => '${b.observedOn}${b.createdAtUtc}'.compareTo(
            '${a.observedOn}${a.createdAtUtc}',
          ),
        );
  Widget pupilCard(Pupil p) => Surface(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            c.selectPupil(p.id);
            c.navigate(WorkspaceSection.journal);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: olive.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    p.name
                        .split(' ')
                        .map((s) => s.isEmpty ? '' : s[0])
                        .take(2)
                        .join(),
                    style: const TextStyle(
                      color: olive,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            for (final kind in [
              EntryKind.goal,
              EntryKind.social,
              EntryKind.work,
              EntryKind.homework,
              EntryKind.note,
            ])
              Expanded(child: pupilAction(p, kind)),
          ],
        ),
      ],
    ),
  );
  Widget pupilAction(Pupil pupil, EntryKind kind) {
    final face = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Icon(entryIcons[kind.index], size: 21, color: olive),
          const SizedBox(height: 5),
          Text(switch (kind) {
            EntryKind.social => 'Sozial',
            EntryKind.work => 'Arbeit',
            EntryKind.goal => 'Ziele',
            EntryKind.homework => 'HÜ',
            _ => 'Orga',
          }, style: const TextStyle(fontSize: 10, color: muted)),
        ],
      ),
    );
    if (kind == EntryKind.note) {
      return PopupMenuButton<EntryKind>(
        tooltip: 'Organisation für ${pupil.name}',
        onSelected: (value) =>
            run(() => newDesktopEntry(value, pupil: pupil.id)),
        itemBuilder: (_) => [
          for (final value in [
            EntryKind.note,
            EntryKind.task,
            EntryKind.appointment,
            EntryKind.returnList,
          ])
            PopupMenuItem(value: value, child: Text(value.label)),
        ],
        child: face,
      );
    }
    return Tooltip(
      message: '${kind.label} für ${pupil.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => run(() => newDesktopEntry(kind, pupil: pupil.id)),
        child: face,
      ),
    );
  }

  Widget recordRow(SchoolRecord r) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        entryIcons[EntryKind.values.byName(r.kind.name).index],
        size: 19,
        color: olive,
      ),
    ),
    title: Text(
      r.title.isEmpty ? (r.body.isEmpty ? r.kind.label : r.body) : r.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    ),
    subtitle: Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${c.name(r.pupilId)} · ${r.kind.label} · ${shortDate(r.observedOn)}',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
        for (final tone in observationTones.entries)
          if (r.observations(tone.key).isNotEmpty)
            Pill(tone.value, color: observationToneColors[tone.key]!),
      ],
    ),
    trailing: MenuAnchor(
      builder: (_, menu, _) => IconButton(
        tooltip: 'Aktionen zum Schülereintrag',
        onPressed: menu.open,
        icon: const Icon(Icons.more_horiz),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => run(() => editSchool(context, c.notebook, r)),
          child: const Text('Eintrag bearbeiten'),
        ),
        if (r.kind == SchoolKind.goal)
          MenuItemButton(
            onPressed: () =>
                run(() => editSchool(context, c.notebook, r, mode: 'review')),
            child: const Text('Ziel überprüfen'),
          ),
        MenuItemButton(
          onPressed: () => run(
            () => showDialog<void>(
              context: context,
              builder: (ctx) => AnimatedBuilder(
                animation: c.notebook,
                builder: (ctx, _) {
                  final record = c.notebook.records
                      .where((v) => v.id == r.id && !v.deleted)
                      .firstOrNull;
                  return FlexModal(
                    title: Text(r.kind.label),
                    onClose: () => Navigator.pop(ctx),
                    content: record == null
                        ? const Text('Der Eintrag liegt im Papierkorb.')
                        : SchoolRecordCard(
                            controller: c.notebook,
                            record: record,
                            standalone: true,
                          ),
                  );
                },
              ),
            ),
          ),
          child: const Text('Details und Aktionen'),
        ),
        MenuItemButton(
          onPressed: () => run(() => showJournal(context, c.notebook, r.id)),
          child: const Text('Änderungsverlauf'),
        ),
      ],
    ),
    onTap: () => run(() => openDesktopValue(r)),
  );
  Widget todayInspector() => ListView(
    padding: const EdgeInsets.all(25),
    children: [
      const Row(
        children: [
          Icon(Icons.today_outlined, size: 18, color: olive),
          SizedBox(width: 9),
          Text(
            'Im Blick',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: 7),
      const Text(
        'Was heute zählt.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 28),
      const Text(
        'OFFENE AUFGABEN',
        style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: muted),
      ),
      const SizedBox(height: 12),
      if (!c.notebook.entries.any((e) => !e.deleted && e.isTask && !e.done))
        const Text('Alles erledigt.', style: TextStyle(color: muted)),
      for (final e
          in c.notebook.entries
              .where((e) => !e.deleted && e.isTask && !e.done)
              .take(6))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: e.done,
                  onChanged: (v) =>
                      run(() => c.notebook.saveEntry(e.complete())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => run(() => openDesktopValue(e)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: const TextStyle(fontSize: 12)),
                      if (e.dueDate != null)
                        Text(
                          e.dueDate!.compareTo(dateOnly(c.date)) < 0
                              ? 'Überfällig · ${shortDate(e.dueDate!)}'
                              : shortDate(e.dueDate!),
                          style: TextStyle(
                            fontSize: 10,
                            color: e.dueDate!.compareTo(dateOnly(c.date)) < 0
                                ? const Color(0xff95665c)
                                : muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      const Divider(height: 32),
      const Text(
        'MATERIAL FÜR HEUTE',
        style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: muted),
      ),
      const SizedBox(height: 14),
      for (final m
          in preparedMaterialsByDay(c.notebook.classroom)[dateOnly(c.date)] ??
              <ClassroomDocument>[])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: MaterialThumbnail(
            material: m,
            files: c.files,
            width: 30,
            height: 40,
          ),
          title: Text(m.title, style: const TextStyle(fontSize: 12)),
          subtitle: Text(
            m.text('subject'),
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          onTap: () => run(() => openDesktopValue(m)),
        ),
      TextButton.icon(
        onPressed: () => c.navigate(WorkspaceSection.materials),
        icon: const Icon(Icons.folder_open_outlined, size: 16),
        label: const Text('Materialien öffnen'),
      ),
      const Divider(height: 32),
      const Text(
        'SCHNELLER ARBEITEN',
        style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: muted),
      ),
      const SizedBox(height: 14),
      for (final pair in [
        ('Suchen & wechseln', 'Strg K'),
        ('Neue Notiz', 'Strg N'),
        ('Eintrag speichern', 'Strg ↵'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  pair.$1,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
              Pill(pair.$2),
            ],
          ),
        ),
    ],
  );
  Widget journal() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
        child: SectionHeading(
          'Klasse & Journal',
          subtitle: 'Verlauf, Aufgaben und Materialien pro Schüler.',
          actions: [
            IconButton(
              tooltip: 'Archivierte Schüler',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => openArchivedPupils(context, c.notebook),
            ),
            IconButton(
              tooltip: 'Schüler hinzufügen',
              onPressed: addPupil,
              icon: const Icon(Icons.person_add_alt),
            ),
          ],
        ),
      ),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 185,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
                children: [
                  ListTile(
                    selected: c.pupilId == null,
                    selectedTileColor: wash,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    title: const Text(
                      'Gesamte Klasse',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => c.selectPupil(null),
                  ),
                  for (final p in c.pupils)
                    ListTile(
                      selected: c.pupilId == p.id,
                      selectedTileColor: wash,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      title: Text(p.name, style: const TextStyle(fontSize: 12)),
                      onTap: () => c.selectPupil(p.id),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.pupil?.name ?? 'Die FLEX-Klasse',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (c.pupil != null)
                          IconButton(
                            tooltip: 'Schülerprofil und Dateikürzel bearbeiten',
                            icon: const Icon(Icons.manage_accounts_outlined),
                            onPressed: () => editPupil(pupil: c.pupil),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final kind in [
                          EntryKind.goal,
                          EntryKind.social,
                          EntryKind.work,
                          EntryKind.homework,
                          EntryKind.note,
                        ])
                          OutlinedButton.icon(
                            onPressed: () => run(
                              () => newDesktopEntry(kind, pupil: c.pupilId),
                            ),
                            icon: Icon(entryIcons[kind.index], size: 16),
                            label: Text(
                              kind.label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 7,
                      children: [
                        for (final label in [
                          'Alle',
                          'Beobachtungen',
                          'HÜ',
                          'Materialien',
                          'Rückläufe',
                        ])
                          ChoiceChip(
                            label: Text(
                              label,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: journalFilter == label,
                            onSelected: (_) =>
                                redraw(() => journalFilter = label),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (journalFilter == 'Materialien')
                      Expanded(
                        child: AssignedMaterialsExplorer(
                          key: ValueKey(c.pupilId),
                          controller: c.notebook,
                          pupil: c.pupil,
                          includeUnassigned: c.pupil == null,
                          files: c.files,
                          openFile: (m) => c.edit(m),
                          onImport: () =>
                              run(() => importLocal(stayInJournal: true)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          children: [
                            if (journalFilter == 'Rückläufe') ...[
                              for (final r in c.notebook.classroom.where(
                                (d) =>
                                    !d.deleted &&
                                    d.kind == ClassroomKind.returnList &&
                                    (c.pupilId == null ||
                                        d.returnParticipant(c.pupilId!) !=
                                            null),
                              ))
                                returnRow(r),
                            ] else ...[
                              for (final r
                                  in recentRecords(pupil: c.pupilId).where(
                                    (r) =>
                                        journalFilter == 'Alle' ||
                                        journalFilter == 'HÜ' &&
                                            r.kind == SchoolKind.homework ||
                                        journalFilter == 'Beobachtungen' &&
                                            (r.kind == SchoolKind.social ||
                                                r.kind == SchoolKind.work),
                                  ))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Surface(
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      children: [
                                        recordRow(r),
                                        if (r.kind == SchoolKind.homework)
                                          for (final t in r.tasks)
                                            CheckboxListTile(
                                              dense: true,
                                              title: Text(
                                                t.text,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              subtitle: Text(
                                                r.taskState(t).label,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                              value:
                                                  r.taskState(t) ==
                                                  TaskState.complete,
                                              onChanged: (v) => run(
                                                () => updateHomework(
                                                  r,
                                                  t,
                                                  v == true
                                                      ? TaskState.complete
                                                      : TaskState.open,
                                                ),
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (journalFilter == 'Alle')
                                for (final e in c.notebook.entries.where(
                                  (e) =>
                                      !e.deleted &&
                                      (c.pupilId == null ||
                                          e.pupilId == c.pupilId),
                                ))
                                  orgaRow(e),
                              if (recentRecords(pupil: c.pupilId).isEmpty)
                                const QuietEmpty(
                                  'Noch keine Beobachtungen',
                                  'Die Eintragsaktionen oben öffnen die Bearbeitung rechts.',
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> updateHomework(
    SchoolRecord r,
    HomeworkTask t,
    TaskState state,
  ) => c.notebook.saveRecord(
    r.patch({
      'feedback': [
        ...r.feedback.map((f) => f.toJson()),
        SchoolFeedback(
          id: newId(),
          observedOn: dateOnly(DateTime.now()),
          createdAtUtc: utcNow(),
          taskId: t.id,
          taskText: t.text,
          state: state,
        ).toJson(),
      ],
    }),
  );
}
