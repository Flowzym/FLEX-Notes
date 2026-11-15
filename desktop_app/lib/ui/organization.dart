part of 'workspace.dart';

extension _OrganizationViews on _DesktopWorkspaceState {
  Widget organization() => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      SectionHeading(
        'Organisation',
        subtitle: 'Aufgaben, Rückläufe und Absprachen gemeinsam im Blick.',
        actions: [
          IconButton(
            tooltip: 'Rücklauf anlegen',
            onPressed: () => run(() => c.start(EntryKind.returnList)),
            icon: const Icon(Icons.assignment_turned_in_outlined),
          ),
          IconButton(
            tooltip: 'Aufgabe anlegen',
            onPressed: () => run(() => c.start(EntryKind.task)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final label in [
            'Offen',
            'Alle',
            'Aufgaben',
            'Rückläufe',
            'Notizen',
            'Erledigt',
          ])
            ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: orgaFilter == label,
              onSelected: (_) => redraw(() => orgaFilter = label),
            ),
        ],
      ),
      const SizedBox(height: 22),
      if ([
        'Alle',
        'Offen',
        'Aufgaben',
        'Notizen',
        'Erledigt',
      ].contains(orgaFilter)) ...[
        for (final e in c.notebook.entries.where(
          (e) =>
              !e.deleted &&
              !e.isAppointment &&
              (orgaFilter == 'Alle' ||
                  orgaFilter == 'Offen' && e.isTask && !e.done ||
                  orgaFilter == 'Aufgaben' && e.isTask ||
                  orgaFilter == 'Notizen' && !e.isTask ||
                  orgaFilter == 'Erledigt' && e.done),
        ))
          orgaRow(e),
      ],
      if (['Alle', 'Offen', 'Rückläufe', 'Erledigt'].contains(orgaFilter)) ...[
        const SizedBox(height: 20),
        const Text(
          'RÜCKLÄUFE',
          style: TextStyle(fontSize: 10, letterSpacing: 1.3, color: muted),
        ),
        const SizedBox(height: 10),
        for (final r in c.notebook.classroom.where(
          (d) =>
              !d.deleted &&
              d.kind == ClassroomKind.returnList &&
              (orgaFilter != 'Offen' ||
                  d.rows('participants').any(returnPending)) &&
              (orgaFilter != 'Erledigt' ||
                  !d.rows('participants').any(returnPending)),
        ))
          returnRow(r),
      ],
      if (!c.notebook.entries.any((e) => !e.deleted) &&
          !c.notebook.classroom.any(
            (d) => !d.deleted && d.kind == ClassroomKind.returnList,
          ))
        QuietEmpty(
          'Platz für das Organisatorische',
          'Lege eine Aufgabe, Notiz oder Rücklaufliste an.',
          icon: Icons.fact_check_outlined,
          action: FilledButton(
            onPressed: () => run(() => c.start(EntryKind.task)),
            child: const Text('Erste Aufgabe anlegen'),
          ),
        ),
    ],
  );
  Widget orgaRow(OrgaEntry e) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          e.isTask
              ? Checkbox(
                  value: e.done,
                  onChanged: (v) => run(
                    () => c.notebook.saveEntry(
                      v == true ? e.complete() : e.copyWith(done: false),
                    ),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    size: 20,
                    color: olive,
                  ),
                ),
          Expanded(
            child: InkWell(
              onTap: () => run(() => c.edit(e)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        decoration: e.done ? TextDecoration.lineThrough : null,
                        color: e.done ? muted : ink,
                      ),
                    ),
                    Text(
                      [
                        c.name(e.pupilId),
                        if (e.dueDate != null) shortDate(e.dueDate!),
                        if (e.items.isNotEmpty)
                          '${e.items.where((i) => i.checked).length}/${e.items.length} Teilaufgaben',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (e.isTask &&
              !e.done &&
              e.dueDate != null &&
              e.dueDate!.compareTo(dateOnly(c.date)) < 0)
            const Pill('Überfällig', color: Color(0xff9a6e60)),
          IconButton(
            tooltip: 'Eintrag bearbeiten',
            onPressed: () => run(() => c.edit(e)),
            icon: const Icon(Icons.chevron_right, size: 18),
          ),
        ],
      ),
    ),
  );
  Widget returnRow(ClassroomDocument r) {
    final total = r.rows('participants').length,
        open = r.rows('participants').where(returnPending).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Surface(
        padding: const EdgeInsets.all(17),
        child: InkWell(
          onTap: () => run(() => c.edit(r)),
          child: Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                color: olive,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$open von $total offen${r.text('dueDate').isEmpty ? '' : ' · Frist ${shortDate(r.text('dueDate'))}'}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : (total - open) / total,
                      minHeight: 3,
                      backgroundColor: line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Pill('$open offen'),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget planning() {
    final plans = c.notebook.classroom
        .where((d) => !d.deleted && d.kind == ClassroomKind.plan)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
          child: SectionHeading(
            'Unterrichtsplanung',
            subtitle:
                'Vom Vorhaben zur Stunde – mit den passenden Materialien.',
            actions: [
              FilledButton.icon(
                onPressed: () => run(() => c.start(EntryKind.plan)),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Neue Planung'),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, box) {
              final width = ((box.maxWidth - 64) / 3).clamp(
                210.0,
                double.infinity,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width * 3 + 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 24),
                      for (final status in ['planned', 'started', 'done'])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: olive,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          planStatuses[status]!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${plans.where((p) => p.text('status', 'planned') == status).length}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      for (final p in plans.where(
                                        (p) =>
                                            p.text('status', 'planned') ==
                                                status ||
                                            status == 'planned' &&
                                                p.text('status') == 'moved',
                                      ))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: planCard(p),
                                        ),
                                      if (plans.isEmpty && status == 'planned')
                                        const QuietEmpty(
                                          'Eine Stunde vorbereiten',
                                          'Ziele, Ablauf und Materialien zusammenhalten.',
                                          icon: Icons.view_week_outlined,
                                        ),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget planCard(ClassroomDocument p) => DragTarget<String>(
    onWillAcceptWithDetails: (detail) =>
        c.materials.any((m) => m.id == detail.data),
    onAcceptWithDetails: (detail) => run(
      () => c.notebook.saveClassroom(
        p.patch({
          'materialIds': {...p.strings('materialIds'), detail.data}.toList(),
        }),
      ),
    ),
    builder: (ctx, accepted, rejected) => Surface(
      color: accepted.isEmpty ? white : wash,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => run(() => c.edit(p)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.text('subject').isNotEmpty) Pill(p.text('subject')),
                const SizedBox(height: 10),
                Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p.text('note'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 14),
                Text(
                  p.text('date').isEmpty
                      ? 'Noch nicht terminiert'
                      : shortDate(p.text('date')),
                  style: const TextStyle(fontSize: 10, color: olive),
                ),
              ],
            ),
          ),
          if (p.strings('pupilIds').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.strings('pupilIds').map(c.name).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ),
          for (final m in c.materials.where(
            (m) => p.strings('materialIds').contains(m.id),
          ))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                onTap: () => run(() => c.edit(m)),
                child: Row(
                  children: [
                    MaterialThumbnail(
                      material: m,
                      files: c.files,
                      width: 22,
                      height: 29,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: olive),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: p.text('status', 'planned'),
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    fontFamily: 'FlexSans',
                    fontSize: 10,
                    color: olive,
                  ),
                  items: [
                    for (final e in planStatuses.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => run(
                    () => c.notebook.saveClassroom(p.patch({'status': v})),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Planung duplizieren',
                onPressed: () => run(() async {
                  final copy = ClassroomDocument.fromJson({
                    ...p.toJson(),
                    'id': newId(),
                    'revision': 0,
                    'title': '${p.title} · Kopie',
                    'status': 'planned',
                    'createdAtUtc': utcNow(),
                    'updatedAtUtc': utcNow(),
                  });
                  await c.notebook.saveClassroom(copy);
                }),
                icon: const Icon(Icons.copy_outlined, size: 16),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
