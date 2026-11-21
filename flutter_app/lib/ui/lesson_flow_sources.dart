part of 'lesson_flow_page.dart';

extension _FlowSources on _LessonFlowPageState {
  Future<void> openFile(ClassroomDocument m) =>
      widget.openFile?.call(m) ?? openMaterial(context, c, m);
  Future<void> reviewSource(ClassroomDocument m) =>
      openTeachingReview(context, c, m, original: widget.openFile);
  ImportedTeachingFlow sourceFlow(ClassroomDocument source) {
    final f = buildTeachingFlow(
      source,
      c.classroom,
      c.pupils,
      lesson: lesson,
      explicit: true,
    );
    if (pupilId == null) return f;
    return ImportedTeachingFlow(source, [
      for (final p in f.phases)
        if (p.pupilIds.isEmpty || p.pupilIds.contains(pupilId))
          individualTeachingPhase(p, pupilId!),
    ], f.issues);
  }

  Future<void> adopt(ClassroomDocument source) async {
    final flow = current, incoming = sourceFlow(source);
    if (incoming.phases.isEmpty) {
      await reviewSource(source);
      return;
    }
    final saved = flow.revision > 0;
    if (saved) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Offene Planung aktualisieren?'),
          content: Text(
            '${incoming.phases.length} Quellphasen. Bereits begonnene, erledigte und selbst bearbeitete Phasen behalten ihren Stand.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zurück'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final result = saved
        ? reconcileTeachingFlow(flow, incoming)
        : withLessonPhases(
            flow.patch({
              'flow': {...flow.map('flow'), ...teachingFlowOrigin(incoming)},
            }),
            incoming.phases,
          );
    await save(result);
  }

  List<Widget> sourcePanel(ClassroomDocument value) {
    final daily = teachingSources(c.classroom, date),
        weekly = teachingSources(c.classroom, date, week: true);
    final origin = value.map('flow')['sourceId'];
    if (daily.isEmpty && weekly.isEmpty && origin == null) return [];
    return [
      if (origin != null && !daily.any((m) => m.id == origin))
        const ListTile(
          dense: true,
          leading: Icon(Icons.offline_pin_outlined),
          title: Text('Gespeicherter Ablauf'),
          subtitle: Text('Die Quelle ist für diesen Tag nicht mehr verfügbar.'),
        ),
      for (final m in daily)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(
                m.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                m.id == origin
                    ? 'Tagesplanung · ${lessonPhases(value).length} Phasen'
                    : sheetText(m.map('planSheet'), 'issue').isNotEmpty
                    ? 'Original zur Prüfung'
                    : sheetUsable(m)
                    ? 'Tagesplanung prüfen und zuordnen'
                    : 'Einlesen aus OneDrive ausstehend',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => reviewSource(m),
            ),
            if (sheetUsable(m) &&
                (origin != m.id ||
                    value.revision > 0 &&
                        teachingFlowVersion(sourceFlow(m)) !=
                            value.map('flow')['sourceVersion']))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : () => adopt(m),
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text(
                    origin == m.id
                        ? 'Änderungen für offene Phasen'
                        : 'Dieser Stunde zuordnen',
                  ),
                ),
              ),
          ],
        ),
      for (final m in weekly)
        ExpansionTile(
          key: PageStorageKey('flow-week-plan-${m.id}-$date'),
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.view_week_outlined),
          title: const Text('Aus der Wochenplanung'),
          subtitle: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          children: [
            for (final r in weeklyContext(m, date))
              ListTile(
                dense: true,
                title: Text(
                  r['type'] == 'week'
                      ? sheetText(r, 'task')
                      : sheetText(r, 'subject'),
                ),
                subtitle: Text(
                  r['type'] == 'week'
                      ? sheetText(r, 'prep')
                      : sheetText(r, 'goal'),
                ),
              ),
            TextButton(
              onPressed: () => reviewSource(m),
              child: const Text('Wochenplanung öffnen'),
            ),
          ],
        ),
    ];
  }
}
