part of 'material_library.dart';

String _planningPreview(
  List<ClassroomDocument> items,
  NotebookController c,
  ClassroomDocument rule,
) {
  final uses = <String, int>{};
  var withDates = 0, clear = 0, review = 0;
  final roster = PlanningRoster(c.classroom, c.pupils);
  for (final item in items) {
    if (!planningSource(rule, item.text('sourcePath'))) continue;
    final plan = classifyPlanningFile(item.text('sourcePath'));
    final use = planningUses[plan['use']]!;
    uses.update(use, (n) => n + 1, ifAbsent: () => 1);
    if ((plan['day'] as String).isNotEmpty) withDates++;
    final candidate = item.patch({'planning': plan});
    if (roster.automaticOwners(candidate).isNotEmpty) {
      clear++;
    } else if (roster.match(candidate).needsReview) {
      review++;
    }
  }
  return [
    '${items.length} Dateien · $withDates mit Unterrichtstag',
    for (final e in uses.entries) '${e.value} · ${e.key}',
    if (clear > 0) '$clear Dateien mit eindeutiger Schülerzuordnung',
    if (review > 0) '$review Dateien zur Prüfung',
  ].join('\n');
}

class _PlanningInbox extends StatelessWidget {
  const _PlanningInbox(this.c);
  final NotebookController c;
  @override
  Widget build(BuildContext context) {
    final roster = PlanningRoster(c.classroom, c.pupils);
    var open = 0, earlier = false;
    for (final source in c.classroom.where(
      (d) => d.kind == ClassroomKind.material,
    )) {
      final d = roster.prepare(source);
      if (roster.match(d).needsReview) {
        open++;
      } else if (!earlier &&
          roster.match(d, includeDecided: true).needsReview) {
        earlier = true;
      }
    }
    if (open == 0 && !earlier) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _PlanningQueue(c, includeEarlier: open == 0),
        ),
        icon: const Icon(Icons.person_search_outlined, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                open == 0
                    ? 'Frühere Entscheidungen prüfen'
                    : 'Zuordnung prüfen',
              ),
            ),
            if (open > 0) Text(' · $open'),
          ],
        ),
      ),
    );
  }
}

class _PlanningQueue extends StatefulWidget {
  const _PlanningQueue(this.c, {required this.includeEarlier});
  final NotebookController c;
  final bool includeEarlier;
  @override
  State<_PlanningQueue> createState() => _PlanningQueueState();
}

class _PlanningQueueState extends State<_PlanningQueue> {
  NotebookController get c => widget.c;
  late bool earlier = widget.includeEarlier;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) {
      final roster = PlanningRoster(c.classroom, c.pupils);
      final items =
          [
            for (final d
                in c.classroom
                    .where((d) => d.kind == ClassroomKind.material)
                    .map(roster.prepare))
              if (roster.match(d, includeDecided: earlier) case final m
                  when m.needsReview)
                (d, m),
          ]..sort(
            (a, b) =>
                a.$1.text('sourcePath').compareTo(b.$1.text('sourcePath')),
          );
      return FlexModal(
        title: const Text('Zuordnung prüfen'),
        onClose: () => Navigator.pop(ctx),
        headerActions: [
          IconButton(
            tooltip: earlier
                ? 'Nur offene Zuordnungen'
                : 'Frühere Entscheidungen prüfen',
            isSelected: earlier,
            icon: const Icon(Icons.history),
            onPressed: () => setState(() => earlier = !earlier),
          ),
        ],
        scrollable: false,
        content: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .55,
          child: items.isEmpty
              ? const Center(child: Text('Alle Zuordnungen sind geprüft.'))
              : ListView.builder(
                  itemCount: items.length + 1,
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.group_outlined),
                        title: const Text('Nach Kürzel oder Schüler prüfen'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => guarded(
                          ctx,
                          () => _reviewPlanningGroups(ctx, c, items),
                        ),
                      );
                    }
                    final (file, match) = items[index - 1];
                    return ListTile(
                      title: Text(
                        file.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          for (final p in c.pupils.where(
                            (p) => match.owners.contains(p.id),
                          ))
                            p.name,
                          if (match.unknown.isNotEmpty)
                            'Kürzel offen · ${match.unknown.join(', ')}',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => guarded(
                        ctx,
                        () => _resolvePlanningFile(ctx, c, file, match),
                      ),
                    );
                  },
                ),
        ),
      );
    },
  );
}

Future<void> _reviewPlanningGroups(
  BuildContext context,
  NotebookController c,
  List<(ClassroomDocument, PlanningMatch)> items,
) async {
  final groups = <(String, String, bool), List<ClassroomDocument>>{};
  for (final (d, m) in items) {
    final year = d.map('planning')['year'] as String? ?? '';
    if (year.isEmpty) continue;
    for (final id in m.owners) {
      (groups[(year, id, true)] ??= []).add(d);
    }
    for (final code in m.unknown) {
      (groups[(year, code, false)] ??= []).add(d);
    }
  }
  final revisions = planningRosterRevisions(c.classroom, c.pupils);
  final choice = await showDialog<(String, String, bool)>(
    context: context,
    builder: (ctx) => FlexModal(
      title: const Text('Sammelzuordnung'),
      onClose: () => Navigator.pop(ctx),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (groups.isEmpty)
            const Text('Hier ist eine Prüfung pro Datei nötig.'),
          for (final e in groups.entries)
            ListTile(
              title: Text(
                e.key.$3
                    ? (c.pupils
                              .where((p) => p.id == e.key.$2)
                              .firstOrNull
                              ?.name ??
                          'Schüler nicht verfügbar')
                    : 'Kürzel ${e.key.$2}',
              ),
              subtitle: Text('${e.key.$1} · ${e.value.length} Dateien'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final (year, key, known) = choice;
  ClassroomDocument? profile;
  String id = key;
  if (!known) {
    final profiles = materialProfiles(c.classroom, year).toList();
    final reserved = profiles.any((d) => d.strings('reserved').contains(key));
    final eligible = c.pupils.where((p) => !p.archived && !p.deleted).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => FlexModal(
        title: Text('Wem gehört das Kürzel $key?'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in eligible)
              ListTile(
                title: Text(p.name),
                subtitle: Text(
                  reserved ||
                          (pupilProfile(profiles, p.id, year)?.text('code') ??
                                  '')
                              .isNotEmpty
                      ? 'Nur diesen Dateien zuordnen'
                      : 'Kürzel $key für $year übernehmen',
                ),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
            if (!reserved)
              ListTile(
                leading: const Icon(Icons.person_add_alt_outlined),
                title: const Text('Neuen Schüler anlegen'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
            if (reserved && eligible.isEmpty)
              const Text(
                'Für diese Dateien ist kein aktiver Schüler verfügbar.',
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => PupilEditor(
          controller: c,
          initialSchoolYear: year,
          initialMaterialCode: key,
        ),
      );
      return;
    }
    id = picked;
    final old = pupilProfile(c.classroom, id, year);
    if (!reserved && (old?.text('code') ?? '').isEmpty) {
      profile = buildMaterialProfile(
        c.classroom,
        id,
        year,
        key,
        old?.strings('aliases') ?? [],
      );
    }
  }
  final pupil = c.pupils
      .where((p) => p.id == id && !p.archived && !p.deleted)
      .firstOrNull;
  if (pupil == null) throw const StaleRevision();
  final updates = await reviewPupilBacklog(
    context,
    id,
    pupil.name,
    groups[choice]!,
    PlanningRoster([
      for (final d in c.classroom)
        if (d.id != profile?.id) d,
      ?profile,
    ], c.pupils),
    reviewedCode: !known && profile == null ? key : null,
  );
  if (updates == null) return;
  if (profile != null || updates.isNotEmpty) {
    await c.repository.savePlanningSync([?profile, ...updates], revisions);
    await c.reload();
  }
}

Future<void> _resolvePlanningFile(
  BuildContext context,
  NotebookController c,
  ClassroomDocument d,
  PlanningMatch match,
) async {
  final ids = <String>{
    ...PlanningRoster(c.classroom, c.pupils).automaticOwners(d),
  };
  final next = await showDialog<ClassroomDocument>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: Text(d.title),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(d.text('sourcePath')),
            if (match.unknown.isNotEmpty)
              Text(
                'Noch ohne aktives Kürzel im Schuljahr ${d.map('planning')['year']} · ${match.unknown.join(', ')}',
              ),
            if (match.ambiguous)
              const Text(
                'Wem gehört diese Datei? Bitte prüfe die vorgeschlagene Zuordnung.',
              ),
            for (final p in c.pupils.where((p) => !p.archived && !p.deleted))
              CheckboxListTile(
                title: Text(p.name),
                contentPadding: EdgeInsets.zero,
                subtitle: match.owners.contains(p.id)
                    ? const Text('Treffer im Dateinamen')
                    : null,
                value:
                    ids.contains(p.id) || d.strings('pupilIds').contains(p.id),
                onChanged: d.strings('pupilIds').contains(p.id)
                    ? null
                    : (v) => update(() {
                        if (v == true) {
                          ids.add(p.id);
                        } else {
                          ids.remove(p.id);
                        }
                      }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, d.patch({'planningDismissed': true})),
            child: const Text('Zuordnung belassen'),
          ),
          FilledButton(
            onPressed: ids.isEmpty
                ? null
                : () => Navigator.pop(
                    ctx,
                    decidePlanningPupils(d, {
                      ...match.owners,
                      ...ids,
                    }, ids).patch({'planningDismissed': true}),
                  ),
            child: const Text('Zuordnen'),
          ),
        ],
      ),
    ),
  );
  if (next != null) await c.saveClassroom(next);
}

String _weekLabel(String date) {
  final monday = schoolDay(weekOfDay(date)),
      thursday = monday.add(const Duration(days: 3));
  final number =
      (thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays ~/ 7) + 1;
  return 'KW $number · ${displayDate(dateOnly(monday))}';
}

class _PlanningWeeks extends StatelessWidget {
  const _PlanningWeeks(this.c, this.query);
  final NotebookController c;
  final String query;
  @override
  Widget build(BuildContext context) {
    final weeks = <String, List<ClassroomDocument>>{};
    for (final d in c.classroom.where(
      (d) => d.kind == ClassroomKind.material && !d.deleted,
    )) {
      final week = teachingWeek(d);
      if (week.isNotEmpty &&
          teachingDay(d).isEmpty &&
          materialMatches(d, query, pupils: c.pupils)) {
        (weeks[week] ??= []).add(d);
      }
    }
    if (weeks.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      key: const PageStorageKey('planning-weeks'),
      title: const Text('Wochenmaterial'),
      subtitle: Text(
        weeks.length == 1
            ? '1 Kalenderwoche'
            : '${weeks.length} Kalenderwochen',
      ),
      children: [
        for (final week in weeks.keys.toList()..sort((a, b) => b.compareTo(a)))
          ExpansionTile(
            key: PageStorageKey('planning-week-$week'),
            title: Text(_weekLabel(week)),
            children: [_PlanningFiles(c, '', weeks[week]!)],
          ),
      ],
    );
  }
}

class _PlanningFiles extends StatelessWidget {
  const _PlanningFiles(this.c, this.title, this.files);
  final NotebookController c;
  final String title;
  final List<ClassroomDocument> files;
  @override
  Widget build(BuildContext context) {
    final groups = <(String, String), List<ClassroomDocument>>{};
    for (final d in files) {
      final path = d.text('sourcePath'), dot = path.lastIndexOf('.');
      final variants = {'pdf', 'docx'}.contains(d.text('extension')) && dot > 0;
      (groups[(
                d.text('driveId'),
                variants ? path.substring(0, dot).toLowerCase() : d.id,
              )] ??=
              [])
          .add(d);
    }
    Widget row(ClassroomDocument d) => MaterialRow(
      material: d,
      onOpen: () => guarded(context, () => openMaterial(context, c, d)),
      onEdit: () => showMaterialDetails(context, c, d),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
        for (final group in groups.values)
          if (group.length == 1)
            row(group.single)
          else
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                group.first.title.replaceFirst(
                  RegExp(r'\.(pdf|docx)$', caseSensitive: false),
                  '',
                ),
              ),
              subtitle: Text(
                group.map((d) => d.text('extension').toUpperCase()).join(' · '),
              ),
              children: group.map(row).toList(),
            ),
      ],
    );
  }
}

class _PlanningDetails extends StatelessWidget {
  const _PlanningDetails(this.c, this.d);
  final NotebookController c;
  final ClassroomDocument d;
  @override
  Widget build(BuildContext context) {
    final day = teachingDay(d), week = teachingWeek(d);
    final related = relatedPlanningFiles(d, c.classroom);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_note_outlined),
          title: Text(planningUses[teachingUse(d)] ?? 'Unterrichtseinsatz'),
          subtitle: Text(
            [
              if (day.isNotEmpty)
                displayDate(day)
              else if (week.isNotEmpty)
                _weekLabel(week)
              else
                'Ohne Unterrichtstermin',
              if (hasTeachingUse(d, 'substitute') &&
                  teachingUse(d) != 'substitute')
                'Supplierung',
              if (d.map('planningOverride').isNotEmpty) 'Manuell festgelegt',
            ].join(' · '),
          ),
          trailing: d.deleted ? null : const Icon(Icons.edit_outlined),
          onTap: d.deleted
              ? null
              : () => guarded(context, () => _editTeachingPlan(context, c, d)),
        ),
        if (related.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Passende Fassungen und Lösungen'),
            children: [
              for (final other in related)
                MaterialRow(
                  material: other,
                  onOpen: () =>
                      guarded(context, () => openMaterial(context, c, other)),
                ),
            ],
          ),
      ],
    );
  }
}

Future<void> _editTeachingPlan(
  BuildContext context,
  NotebookController c,
  ClassroomDocument d,
) async {
  var use = teachingUse(d), day = teachingDay(d), week = teachingWeek(d);
  final result = await showDialog<Json>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: const Text('Unterrichtseinsatz'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: use,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Verwendung'),
              items: [
                for (final e in planningUses.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => update(() => use = v!),
            ),
            ListTile(
              title: const Text('Unterrichtstag'),
              subtitle: Text(day.isEmpty ? 'Ohne Datum' : displayDate(day)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await pickFlexDate(
                  ctx,
                  date: day.isEmpty
                      ? (week.isEmpty ? dateOnly(DateTime.now()) : week)
                      : day,
                  allowTime: false,
                  allowDateClear: true,
                );
                if (picked != null && ctx.mounted) {
                  update(() {
                    day = picked.$1;
                    if (day.isNotEmpty) week = weekOfDay(day);
                  });
                }
              },
            ),
            if (day.isEmpty)
              ListTile(
                title: const Text('Unterrichtswoche'),
                subtitle: Text(week.isEmpty ? 'Ohne Woche' : _weekLabel(week)),
                trailing: const Icon(Icons.date_range_outlined),
                onTap: () async {
                  final picked = await pickFlexDate(
                    ctx,
                    date: week.isEmpty ? dateOnly(DateTime.now()) : week,
                    allowTime: false,
                    allowDateClear: true,
                  );
                  if (picked != null && ctx.mounted) {
                    update(
                      () =>
                          week = picked.$1.isEmpty ? '' : weekOfDay(picked.$1),
                    );
                  }
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, <String, dynamic>{}),
            child: const Text('Ordnerangaben verwenden'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, <String, dynamic>{
              'use': use,
              'day': day,
              'week': week,
            }),
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
  if (result != null) {
    await c.saveClassroom(updateTeachingPlan(d, {'planningOverride': result}));
  }
}
