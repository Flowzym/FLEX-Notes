part of 'calendar_page.dart';

Future<void> showCalendarItem(
  BuildContext context,
  NotebookController c,
  CalendarItem item,
) async {
  if (item.entry != null) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrgaEditor(controller: c, entry: item.entry!),
    );
    return;
  }
  if (item.record != null) {
    await editSchool(context, c, item.record!);
    return;
  }
  if (item.category == 'return') {
    await showReturnDetail(context, c, item.document!.id);
    return;
  }
  if (item.category == 'holiday') {
    await showClassroomEditor(
      context,
      c,
      ClassroomKind.holiday,
      document: item.document,
    );
    return;
  }
  final lesson = item.lesson!;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final doc = c.classroom
            .where((d) => d.id == lesson.document.id && !d.deleted)
            .firstOrNull;
        final current = doc == null
            ? null
            : lessonOccurrences(
                [
                  doc,
                  ...c.classroom.where((d) => d.kind == ClassroomKind.holiday),
                ],
                dateOnly(
                  schoolDay(lesson.date).subtract(const Duration(days: 365)),
                ),
                dateOnly(schoolDay(lesson.date).add(const Duration(days: 365))),
              ).where((l) => l.target == lesson.target).firstOrNull;
        if (doc == null || current == null) {
          return FlexModal(
            title: const Text('Unterricht'),
            onClose: () => Navigator.pop(ctx),
            content: const Text(
              'Diese Durchführung wurde geändert oder abgesagt.',
            ),
          );
        }
        return FlexModal(
          maxWidth: 800,
          title: Text(current.title),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${displayDate(current.date)} · ${current.start.isEmpty ? 'Ganztägig' : '${current.start}–${current.end}'}',
              ),
              Text(
                [
                  doc.text('subject'),
                  'FLEX-Klasse',
                  doc.text('room'),
                ].where((v) => v.isNotEmpty).join(' · '),
              ),
              if (current.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(current.note),
                ),
              const SizedBox(height: 12),
              Text(
                'Planung & Dateien',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              for (final plan in lessonPlans(c.classroom, current))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(plan.title),
                  subtitle: Text(planStatuses[plan.text('status', 'planned')]!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showMaterialCollection(ctx, c, plan),
                ),
              for (final material in resolveMaterials(c.classroom, {
                ...current.materialIds,
                for (final p in lessonPlans(c.classroom, current))
                  ...p.strings('materialIds'),
              }))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(material.title),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () =>
                      guarded(ctx, () => openMaterial(ctx, c, material)),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Dateien dieser Stunde'),
                    onPressed: () async {
                      final ids = await chooseMaterials(
                        ctx,
                        c,
                        current.materialIds,
                      );
                      if (ids != null && ctx.mounted) {
                        await guarded(
                          ctx,
                          () => c.saveClassroom(
                            patchLessonOccurrence(doc, current.originalDate, {
                              'materialIds': ids,
                            }),
                          ),
                        );
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_note_outlined),
                    label: const Text('Planung zuordnen'),
                    onPressed: () => chooseLessonPlanning(ctx, c, current),
                  ),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showClassroomEditor(
                      ctx,
                      c,
                      ClassroomKind.lesson,
                      document: doc,
                      occurrenceDate: lesson.originalDate,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Diese Stunde bearbeiten'),
                  ),
                  if (doc.rule.repeats)
                    OutlinedButton.icon(
                      onPressed: () => showClassroomEditor(
                        ctx,
                        c,
                        ClassroomKind.lesson,
                        document: doc,
                        occurrenceDate: lesson.originalDate,
                        following: true,
                      ),
                      icon: const Icon(Icons.repeat),
                      label: const Text('Diese und folgende'),
                    ),
                  TextButton.icon(
                    onPressed: () => showReminderActions(
                      ctx,
                      c,
                      lesson.target,
                      current.title,
                    ),
                    icon: const Icon(Icons.snooze),
                    label: const Text('Erinnerung verschieben'),
                  ),
                  TextButton.icon(
                    onPressed: () => showBulk(
                      ctx,
                      c,
                      initialKind: 'homework',
                      initialSubject: doc.text('subject'),
                    ),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('HÜ vergeben'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final pupil = await showDialog<Pupil>(
                        context: ctx,
                        builder: (selectCtx) => FlexModal(
                          title: const Text('Beobachtung für …'),
                          onClose: () => Navigator.pop(selectCtx),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final p in c.pupils.where(
                                (p) => !p.archived,
                              ))
                                ListTile(
                                  title: Text(p.name),
                                  onTap: () => Navigator.pop(selectCtx, p),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (pupil != null && ctx.mounted) {
                        await editSchool(
                          ctx,
                          c,
                          SchoolRecord.empty(SchoolKind.work, pupil.id).patch({
                            'subject': doc.text('subject'),
                            'observedOn': current.date,
                            'observedTime': current.start,
                          }),
                        );
                      }
                    },
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Beobachtung'),
                  ),
                  TextButton.icon(
                    onPressed: () => guarded(
                      ctx,
                      () => c.saveClassroom(
                        patchLessonOccurrence(doc, lesson.originalDate, {
                          'cancelled': true,
                        }),
                      ),
                    ),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Diese Stunde entfällt'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> chooseLessonPlanning(
  BuildContext context,
  NotebookController c,
  LessonOccurrence lesson,
) async {
  final selected = lessonPlans(c.classroom, lesson).map((p) => p.id).toSet();
  final result = await showDialog<({bool create, List<String> ids})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => FlexModal(
        title: const Text('Planung dieser Stunde'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Neue Planung für diese Stunde'),
              onTap: () =>
                  Navigator.pop(ctx, (create: true, ids: selected.toList())),
            ),
            for (final p in c.classroom.where(
              (p) => !p.deleted && p.kind == ClassroomKind.plan,
            ))
              CheckboxListTile(
                title: Text(p.title),
                subtitle: Text(p.text('subject')),
                value: selected.contains(p.id),
                onChanged: (v) => update(() {
                  if (v == true) {
                    selected.add(p.id);
                  } else {
                    selected.remove(p.id);
                  }
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, (create: false, ids: selected.toList())),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  if (result.create) {
    await showClassroomEditor(
      context,
      c,
      ClassroomKind.plan,
      fields: {
        'title': lesson.title,
        'subject': lesson.document.text('subject'),
        'date': '',
        '_attachLessonId': lesson.document.id,
        '_attachOriginalDate': lesson.originalDate,
        '_attachLessonRevision': lesson.document.revision,
        '_attachPlanIds': result.ids,
        '_attachDate': lesson.date,
      },
    );
  } else {
    await guarded(
      context,
      () => c.saveClassroom(
        patchLessonOccurrence(lesson.document, lesson.originalDate, {
          'planIds': result.ids,
        }),
      ),
    );
  }
}
