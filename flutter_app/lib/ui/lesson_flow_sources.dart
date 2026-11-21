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
    final decisions = saved
        ? await comparePlan(TeachingFlowChanges(flow, incoming))
        : (<String, String>{}, <String>{});
    if (decisions == null || !mounted) return;
    await run(() async {
      final latest = c.classroom
          .where((m) => m.id == source.id && !m.deleted)
          .firstOrNull;
      if (latest == null ||
          teachingFlowVersion(sourceFlow(latest)) !=
              teachingFlowVersion(incoming)) {
        throw const DomainError(
          'Die Planung hat sich inzwischen geändert. Bitte den Vergleich erneut öffnen.',
        );
      }
      final result = saved
          ? reconcileTeachingFlow(
              flow,
              incoming,
              decisions: decisions.$1,
              restore: decisions.$2,
            )
          : withLessonPhases(
              flow.patch({
                'flow': {...flow.map('flow'), ...teachingFlowOrigin(incoming)},
              }),
              incoming.phases,
            );
      await c.saveClassroom(result);
    });
  }

  Future<void> reviewPhaseSource(ClassroomDocument flow, LessonPhase p) async {
    final id = p.sourceId.isEmpty ? flow.map('flow')['sourceId'] : p.sourceId;
    final m = c.classroom.where((d) => d.id == id && !d.deleted).firstOrNull;
    if (m == null) return;
    var row = p.sourceRow;
    if (!teachingRows(m).any((r) => r['id'] == row)) {
      final f = sourceFlow(m), changes = TeachingFlowChanges(flow, f);
      row =
          f.phases
              .where((n) => changes.matches[n.id] == p.id)
              .firstOrNull
              ?.sourceRow ??
          '';
    }
    if (row.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Die frühere Quellzeile lässt sich nicht mehr eindeutig zuordnen.',
          ),
        ),
      );
    }
    await openTeachingReview(
      context,
      c,
      m,
      original: widget.openFile,
      initialRow: row.isEmpty ? null : row,
    );
  }

  Future<void> takeWeekRow(
    ClassroomDocument value,
    ClassroomDocument m,
    Json row,
  ) async {
    final draft = weekPhaseDraft(
      m,
      row,
      TeachingLinks(m, c.classroom, c.pupils),
    );
    await showDialog<void>(
      context: context,
      builder: (_) => _LessonPhaseEditor(
        controller: c,
        individual: lessonFlowPupil(value).isNotEmpty,
        phase: draft,
        heading: 'Wochenauftrag übernehmen',
        contextLabel: [
          displayDate(date),
          lesson?.title ?? 'Freier Tagesablauf',
          m.title,
          if (isSuggestedLessonFlow(value))
            'Beginnt einen eigenen Ablauf für diese Stunde.',
        ].join(' · '),
        onSave: (p) async {
          final latest = c.classroom
              .where((d) => d.id == m.id && !d.deleted)
              .firstOrNull;
          if (latest == null ||
              !sheetUsable(latest) ||
              teachingVersion(latest) != teachingVersion(m)) {
            throw const DomainError(
              'Der Wochenplan hat sich geändert. Bitte die Zeile erneut auswählen.',
            );
          }
          await c.saveClassroom(addWeekPhase(value, p));
        },
      ),
    );
  }

  Widget weekRow(ClassroomDocument value, ClassroomDocument m, Json row) {
    final covered = coveredWeekPhase(value, m, row);
    final taken =
        covered != null &&
        covered.sourceId == m.id &&
        covered.sourceRow == row['id'];
    return ListTile(
      dense: true,
      title: Text(weekPhaseTitle(row)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sheetText(row, 'prep').isNotEmpty) Text(sheetText(row, 'prep')),
          if (row['type'] == 'goal') Text(sheetText(row, 'subject')),
          if (covered != null) Text('Im Ablauf · ${covered.title}'),
          if (!taken)
            TextButton.icon(
              onPressed: busy || !sheetUsable(m)
                  ? null
                  : () => takeWeekRow(value, m, row),
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(
                covered == null
                    ? 'Für diese Stunde übernehmen'
                    : 'Als zusätzliche Phase übernehmen',
              ),
            ),
        ],
      ),
    );
  }

  Widget sourceIssues(ClassroomDocument m) {
    if (!sheetUsable(m)) return const SizedBox.shrink();
    final issues = sourceFlow(m).issues;
    if (issues.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.rule, size: 18),
        onPressed: () => reviewSource(m),
        label: Text(
          '${issues.length} ${issues.length == 1 ? 'Hinweis' : 'Hinweise'} zur Zuordnung prüfen',
        ),
      ),
    );
  }

  List<Widget> sourcePanel(ClassroomDocument value) {
    final daily = teachingSources(c.classroom, date),
        weekly = teachingSources(c.classroom, date, week: true);
    final flow = value.map('flow'), origin = flow['sourceId'];
    final phaseIds = lessonPhases(value).map((p) => p.id).toSet();
    final missing = (flow['sourceBase'] as Map? ?? {}).keys.any(
      (id) => !phaseIds.contains(id),
    );
    final legacy = flow['sourceRows'] == null;

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
            sourceIssues(m),
            if (sheetUsable(m) &&
                (origin != m.id ||
                    value.revision > 0 &&
                        (missing ||
                            legacy ||
                            teachingFlowVersion(sourceFlow(m)) !=
                                flow['sourceVersion'])))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : () => adopt(m),
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text(
                    origin == m.id
                        ? (missing
                              ? 'Fehlende Planphasen prüfen'
                              : legacy
                              ? 'Planabgleich prüfen'
                              : 'Änderungen für offene Phasen')
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
            for (final r in weeklyContext(m, date)) weekRow(value, m, r),
            TextButton(
              onPressed: () => reviewSource(m),
              child: const Text('Wochenplanung öffnen'),
            ),
          ],
        ),
    ];
  }
}
