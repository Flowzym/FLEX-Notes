part of 'workspace.dart';

extension _OrganizationViews on _DesktopWorkspaceState {
  Widget organization() {
    final rows = deskOrganization(
      c.notebook,
      type: orgaKind,
      status: orgaStatus,
      query: c.query,
      today: dateOnly(DateTime.now()),
    );
    return ListView.builder(
      padding: const EdgeInsets.all(28),
      itemCount: 1 + (rows.isEmpty ? 1 : rows.length),
      itemBuilder: (_, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                'Organisation',
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
              TextField(
                key: const ValueKey('orga-search'),
                decoration: const InputDecoration(
                  hintText: 'Eintrag, Person oder Unteraufgabe suchen',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: c.search,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 4,
                children: [
                  for (final kind in [
                    'Alle Arten',
                    ...DeskEntryKind.values.map((k) => k.plural),
                  ])
                    ChoiceChip(
                      label: Text(kind),
                      selected: orgaKind == kind,
                      onSelected: (_) => redraw(() => orgaKind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DropdownButton<String>(
                        value: orgaStatus,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.expand_more),
                        items: [
                          for (final s in [
                            'Alle',
                            'Offen',
                            'Überfällig',
                            'Erledigt',
                          ])
                            DropdownMenuItem(
                              value: s,
                              child: Text(s == 'Alle' ? 'Jeder Status' : s),
                            ),
                        ],
                        onChanged: (s) {
                          if (s != null) redraw(() => orgaStatus = s);
                        },
                      ),
                    ),
                  ),
                  Text(
                    '${rows.length} ${rows.length == 1 ? 'Eintrag' : 'Einträge'}',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          );
        }
        if (rows.isEmpty) {
          return const QuietEmpty(
            'Keine passenden Einträge',
            'Ändere die Filter oder lege oben einen Eintrag an.',
            icon: Icons.fact_check_outlined,
          );
        }
        return switch (rows[index - 1].target) {
          final OrgaEntry e => orgaRow(e),
          final ClassroomDocument r => returnRow(r),
          _ => throw StateError('Unbekannter Organisationseintrag'),
        };
      },
    );
  }

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
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    e.isAppointment
                        ? Icons.event_outlined
                        : Icons.sticky_note_2_outlined,
                    size: 22,
                    color: e.isAppointment
                        ? const Color(0xff536e85)
                        : const Color(0xff876c49),
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
                        e.isAppointment
                            ? 'Termin'
                            : e.isTask
                            ? 'Aufgabe'
                            : 'Notiz',
                        c.notebook.owner(e),
                        if (e.isAppointment) shortDate(e.appointmentDate!),
                        if (e.appointmentTime.isNotEmpty) e.appointmentTime,
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
              e.dueDate!.compareTo(dateOnly(DateTime.now())) < 0)
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
                      'Rücklauf · $open von $total offen${r.text('dueDate').isEmpty ? '' : ' · Frist ${shortDate(r.text('dueDate'))}'}',
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
              Pill(r.returnFinished ? r.returnState.label : '$open offen'),
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
