part of 'school_editor.dart';

extension _SchoolObservationView on _SchoolEditorState {
  Widget optionalSection(
    String label,
    bool active,
    ValueChanged<bool> change,
    Widget content,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CompactSwitchListTile(
        key: ValueKey('section-$label'),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        leading: Icon(switch (label) {
          'Beteiligt' => Icons.people_outline,
          'Zielbezug' => Icons.track_changes,
          'Reaktion / Unterstützung' => Icons.handshake_outlined,
          _ => Icons.layers_outlined,
        }),
        value: active,
        contentPadding: EdgeInsets.zero,
        onChanged: (v) => updateEditor(() => change(v)),
      ),
      const Divider(height: 1),
      if (active)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: content,
        ),
    ],
  );

  void assignment(List<String> tags, String free) => edit({
    'taskTags': tags,
    'taskFree': free,
    'subject': [...tags, if (free.trim().isNotEmpty) free.trim()].join(' · '),
  });

  Widget observation() {
    final scheme = Theme.of(context).colorScheme;
    final catalog =
        catalogs[catalogKey] ?? ObservationCatalog.defaults(catalogKey);
    final selected = r.observations(selectedTone);
    final options = [
      ...catalog.favorites,
      ...catalog.options.where((s) => !catalog.favorites.contains(s)),
    ];
    options.removeWhere(selected.contains);
    final selectionColor = observationToneColors[selectedTone]!;
    Widget label(String title, String hint) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (hint.isNotEmpty)
              TextSpan(text: '  $hint', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionBar(
          key: const ValueKey('tone-pill'),
          keyPrefix: 'tone',
          options: observationTones,
          value: selectedTone,
          colors: observationToneColors,
          icons: const {
            'positive': Icons.thumb_up_outlined,
            'neutral': Icons.remove_circle_outline,
            'negative': Icons.thumb_down_outlined,
          },
          minButtonHeight: 38,
          fontSize: 14,
          onChanged: (value) => updateEditor(() {
            selectedTone = value;
          }),
        ),
        const Divider(height: 26),
        if (r.kind == SchoolKind.work) ...[
          label('Auftrag', 'optional'),
          TagTextField(
            fieldKey: const ValueKey('record-subject'),
            value: r.assignmentFree,
            hint: 'Auftrag …',
            minLines: 1,
            semanticLabel: 'Auftrag – eigener Text',
            tags: [
              for (final text in r.taskTags)
                (
                  id: 'assignment-$text',
                  label: text,
                  remove: () => assignment(
                    r.taskTags.where((t) => t != text).toList(),
                    r.assignmentFree,
                  ),
                ),
            ],
            onChanged: (v) => assignment(r.taskTags, v),
          ),
          WorkAssignmentSources(
            controller: c,
            date: r.observedOn,
            values: r.assignmentSources,
            onChanged: (v) =>
                edit({'assignmentSources': v.map((s) => s.toJson()).toList()}),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Beobachtung',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            IconButton(
              tooltip: 'Beobachtungen bearbeiten',
              onPressed: catalogBusy ? null : editOptions,
              icon: const Icon(Icons.edit_outlined, size: 21),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final text in options)
              Container(
                key: ValueKey('observation-option-$text'),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width,
                ),
                decoration: BoxDecoration(
                  color: selected.contains(text)
                      ? selectionColor
                      : Theme.of(
                              context,
                            ).extension<FlexSurfaces>()?.palette.button ??
                            scheme.onSurface.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: FlexDesign.shadows(context),
                  border: Border.all(color: scheme.outlineVariant, width: .8),
                ),
                child: IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: TextButton(
                          key: ValueKey('observation-$text'),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            textStyle: const TextStyle(
                              fontFamily: 'FlexSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                            foregroundColor: selected.contains(text)
                                ? legibleOn(selectionColor)
                                : Theme.of(context)
                                          .extension<FlexSurfaces>()
                                          ?.palette
                                          .ink ??
                                      scheme.onSurface,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 6,
                              bottom: 6,
                            ),
                          ),
                          onPressed: () => edit({
                            selectedTone: selected.contains(text)
                                ? selected.where((s) => s != text).toList()
                                : [...selected, text],
                          }),
                          child: Text(text, textAlign: TextAlign.center),
                        ),
                      ),
                      if (catalog.options.contains(text))
                        IconButton(
                          key: ValueKey('favorite-$text'),
                          tooltip: catalog.favorites.contains(text)
                              ? 'Favorit entfernen: $text'
                              : 'Als Favorit markieren: $text',
                          onPressed: catalogBusy ? null : () => favorite(text),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          iconSize: 16,
                          color: selected.contains(text)
                              ? legibleOn(selectionColor)
                              : Theme.of(
                                      context,
                                    ).extension<FlexSurfaces>()?.palette.ink ??
                                    scheme.onSurface,
                          icon: Icon(
                            catalog.favorites.contains(text)
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        label(
          r.kind == SchoolKind.social
              ? 'Was ist passiert?'
              : 'Konkrete Beobachtung',
          r.kind == SchoolKind.social ? 'optional bei Auswahl' : 'optional',
        ),
        if (r.kind == SchoolKind.social) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in const {
                'before': 'Vor Unterricht',
                'during': 'Unterricht',
                'after': 'Nach Unterricht',
                'break': 'Pause',
              }.entries.where((choice) => r.situation != choice.key))
                transparentChip(
                  ChoiceChip(
                    label: Text(choice.value),
                    labelStyle: const TextStyle(fontSize: 12, height: 1.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        Theme.of(
                          context,
                        ).extension<FlexSurfaces>()?.palette.button ??
                        scheme.onSurface.withValues(alpha: .07),
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? scheme.primary
                          : Theme.of(
                                  context,
                                ).extension<FlexSurfaces>()?.palette.button ??
                                scheme.onSurface.withValues(alpha: .07),
                    ),
                    selected: r.situation == choice.key,
                    showCheckmark: false,
                    onSelected: (active) =>
                        edit({'situation': active ? choice.key : ''}),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TagTextField(
          fieldKey: const ValueKey('record-body'),
          value: r.body,
          hint: 'Beobachtung …',
          tagColors: {
            for (final tone in observationTones.keys)
              for (final text in r.observations(tone))
                '$tone-$text': observationToneColors[tone]!,
          },
          tags: [
            for (final tone in observationTones.keys)
              for (final text in r.observations(tone))
                (
                  id: '$tone-$text',
                  label: '${observationSigns[tone]} $text',
                  remove: () => edit({
                    tone: (r.observations(
                      tone,
                    )).where((t) => t != text).toList(),
                  }),
                ),
            if (r.kind == SchoolKind.social && r.situation.isNotEmpty)
              (
                id: 'situation',
                label: const {
                  'before': 'Vor Unterricht',
                  'during': 'Unterricht',
                  'after': 'Nach Unterricht',
                  'break': 'Pause',
                }[r.situation]!,
                remove: () => edit({'situation': ''}),
              ),
          ],
          onChanged: (v) => edit({'body': v}),
        ),
        const SizedBox(height: 24),
        optionalSection(
          'Beteiligt',
          participantsOpen,
          (v) => participantsOpen = v,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PupilTags(
                pupils: c.pupils
                    .where((p) => !p.archived && p.id != r.pupilId)
                    .toList(),
                selected: r.participantIds.toSet(),
                onChanged: (v) => edit({'participantIds': v.toList()}),
              ),
              const SizedBox(height: 12),
              field('otherParticipants', 'Weitere Namen'),
            ],
          ),
        ),
        optionalSection(
          'Zielbezug',
          goalOpen,
          (v) => goalOpen = v,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!c.records.any(
                (v) =>
                    v.kind == SchoolKind.goal &&
                    v.pupilId == r.pupilId &&
                    !v.deleted,
              ))
                const Text('Noch keine Ziele für diesen Schüler.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in c.records.where(
                    (v) =>
                        v.kind == SchoolKind.goal &&
                        v.pupilId == r.pupilId &&
                        !v.deleted,
                  ))
                    transparentChip(
                      FilterChip(
                        label: Text(g.title),
                        selected: r.goalId == g.id,
                        onSelected: (active) => edit({
                          'goalId': active ? g.id : null,
                          'goalSnapshot': active ? g.title : '',
                        }),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        optionalSection(
          'Reaktion / Unterstützung',
          supportOpen,
          (v) => supportOpen = v,
          field(
            'support',
            'Reaktion / Unterstützung',
            lines: 2,
            maxLength: 300,
            hint: 'Unterstützung …',
          ),
        ),
        optionalSection(
          'Kontext / Quelle',
          contextOpen,
          (v) => contextOpen = v,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.situationId != null)
                TextButton(
                  onPressed: () => showSituation(context, c, r.situationId!),
                  child: const Text('Gemeinsamen Kontext bearbeiten'),
                ),
              const Text('Quelle'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in const {
                    'self': 'Selbst beobachtet',
                    'reported': 'Berichtet',
                    'interpretation': 'Eigene Einordnung',
                  }.entries)
                    transparentChip(
                      ChoiceChip(
                        label: Text(source.value),
                        selected: r.source == source.key,
                        onSelected: (_) => edit({'source': source.key}),
                      ),
                    ),
                ],
              ),
              field(
                'context',
                'Gemeinsamer Ablauf',
                lines: 2,
                maxLength: 3000,
                hint: 'Kontext …',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget observationEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Bereich'),
        Wrap(
          spacing: 8,
          children: [
            for (final kind in [SchoolKind.social, SchoolKind.work])
              transparentChip(
                ChoiceChip(
                  label: Text(kind.label),
                  selected: r.kind == kind,
                  onSelected: (_) => edit({
                    'kind': kind.name,
                    'situation': '',
                    'goalId': null,
                    'goalSnapshot': '',
                  }),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          r.kind == SchoolKind.social
              ? 'Was ist passiert? · optional bei Auswahl'
              : 'Notiz',
        ),
        if (r.kind == SchoolKind.social)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final choice in const {
                'before': 'Vor Unterricht',
                'during': 'Unterricht',
                'after': 'Nach Unterricht',
                'break': 'Pause',
              }.entries)
                if (r.situation != choice.key)
                  transparentChip(
                    ActionChip(
                      label: Text(choice.value),
                      labelStyle: const TextStyle(fontSize: 12, height: 1.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => edit({'situation': choice.key}),
                    ),
                  ),
            ],
          ),
        TagTextField(
          fieldKey: const ValueKey('record-body'),
          value: r.body,
          hint: 'Beobachtung …',
          tagColors: {
            for (final tone in observationTones.keys)
              for (final text in r.observations(tone))
                '$tone-$text': observationToneColors[tone]!,
          },
          tags: [
            for (final tone in observationTones.keys)
              for (final text in r.observations(tone))
                (
                  id: '$tone-$text',
                  label: '${observationSigns[tone]} $text',
                  remove: () => edit({
                    tone: (r.observations(
                      tone,
                    )).where((t) => t != text).toList(),
                  }),
                ),
            if (r.kind == SchoolKind.social && r.situation.isNotEmpty)
              (
                id: 'situation',
                label: const {
                  'before': 'Vor Unterricht',
                  'during': 'Unterricht',
                  'after': 'Nach Unterricht',
                  'break': 'Pause',
                }[r.situation]!,
                remove: () => edit({'situation': ''}),
              ),
          ],
          onChanged: (v) => edit({'body': v}),
        ),
        if (r.kind == SchoolKind.work) ...[
          const SizedBox(height: 12),
          const Text('Auftrag'),
          TagTextField(
            fieldKey: const ValueKey('record-subject'),
            value: r.assignmentFree,
            hint: 'Auftrag …',
            minLines: 1,
            tags: [
              for (final text in r.taskTags)
                (
                  id: 'assignment-$text',
                  label: text,
                  remove: () => assignment(
                    r.taskTags.where((t) => t != text).toList(),
                    r.assignmentFree,
                  ),
                ),
            ],
            onChanged: (v) => assignment(r.taskTags, v),
          ),
          WorkAssignmentSources(
            controller: c,
            date: r.observedOn,
            values: r.assignmentSources,
            onChanged: (v) =>
                edit({'assignmentSources': v.map((s) => s.toJson()).toList()}),
          ),
        ],
        optionalSection(
          'Beteiligt',
          participantsOpen,
          (v) => participantsOpen = v,
          Column(
            children: [
              PupilTags(
                pupils: c.pupils
                    .where(
                      (p) =>
                          p.id != r.pupilId &&
                          (!p.archived || r.participantIds.contains(p.id)),
                    )
                    .toList(),
                selected: r.participantIds.toSet(),
                onChanged: (v) => edit({'participantIds': v.toList()}),
              ),
              field('otherParticipants', 'Weitere Namen', hint: 'Name; Name …'),
            ],
          ),
        ),
        ExpansionTile(
          title: const Text('Auswahl bearbeiten'),
          children: [
            for (final tone in observationTones.keys)
              for (
                var index = 0;
                index < (r.observations(tone)).length;
                index++
              )
                Builder(
                  builder: (ctx) {
                    final list = r.observations(tone);
                    return Row(
                      children: [
                        Text(observationSigns[tone]!),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              'edit-selection-$tone-$index-${list.length}',
                            ),
                            initialValue: list[index],
                            maxLength: 300,
                            decoration: InputDecoration(
                              labelText: observationTones[tone],
                              counterText: '',
                            ),
                            onChanged: (v) {
                              final values = [...list];
                              values[index] = v;
                              edit({tone: values});
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Beobachtung entfernen',
                          onPressed: () {
                            final values = [...list]..removeAt(index);
                            edit({tone: values});
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    );
                  },
                ),
            Wrap(
              spacing: 8,
              children: [
                for (final tone in observationTones.keys)
                  TextButton(
                    onPressed: () => edit({
                      tone: [...(r.observations(tone)), ''],
                    }),
                    child: Text(
                      '${observationSigns[tone]} Beobachtung ergänzen',
                    ),
                  ),
              ],
            ),
          ],
        ),
        optionalSection(
          'Reaktion / Unterstützung',
          supportOpen,
          (v) => supportOpen = v,
          field(
            'support',
            'Reaktion / Unterstützung',
            lines: 2,
            hint: 'Unterstützung …',
          ),
        ),
        optionalSection(
          'Zielbezug',
          goalOpen,
          (v) => goalOpen = v,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              transparentChip(
                ChoiceChip(
                  label: const Text('Ohne Zielzuordnung'),
                  selected: r.goalId == null,
                  onSelected: (_) => edit({'goalId': null, 'goalSnapshot': ''}),
                ),
              ),
              for (final goal in c.records.where(
                (g) =>
                    g.kind == SchoolKind.goal &&
                    g.pupilId == r.pupilId &&
                    !g.deleted &&
                    (g.goalStatus == 'active' || g.id == r.goalId),
              ))
                transparentChip(
                  ChoiceChip(
                    label: Text(goal.title),
                    selected: r.goalId == goal.id,
                    onSelected: (_) =>
                        edit({'goalId': goal.id, 'goalSnapshot': goal.title}),
                  ),
                ),
            ],
          ),
        ),
        const Text('Schüler'),
        PupilTags(
          pupils: c.pupils
              .where((p) => !p.archived || p.id == r.pupilId)
              .toList(),
          selected: {r.pupilId},
          multiple: false,
          onChanged: (v) {
            if (v.isNotEmpty && v.single != r.pupilId) {
              edit({
                'pupilId': v.single,
                'goalId': null,
                'goalSnapshot': '',
                'situationId': null,
              });
            }
          },
        ),
        optionalSection(
          'Kontext / Quelle',
          contextOpen,
          (v) => contextOpen = v,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Quelle'),
              Wrap(
                spacing: 8,
                children: [
                  for (final source in const {
                    'self': 'Selbst beobachtet',
                    'reported': 'Berichtet',
                    'interpretation': 'Eigene Einordnung',
                  }.entries)
                    transparentChip(
                      ChoiceChip(
                        label: Text(source.value),
                        selected: r.source == source.key,
                        onSelected: (_) => edit({'source': source.key}),
                      ),
                    ),
                ],
              ),
              if (r.situationId != null)
                TextButton(
                  onPressed: () => showSituation(context, c, r.situationId!),
                  child: const Text('Gemeinsamen Kontext bearbeiten'),
                ),
              field(
                'context',
                'Gemeinsamer Ablauf',
                lines: 2,
                hint: 'Kontext …',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget observationHeader() {
    final pupil = c.pupils.firstWhere((p) => p.id == r.pupilId);
    final actions = <Widget>[
      IconButton(
        iconSize: 20,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(6),
        tooltip: 'Verlauf',
        onPressed: busy ? null : observationHistory,
        icon: const Icon(Icons.history),
      ),
      AnimatedBuilder(
        animation: c,
        builder: (_, _) => EntryHeaderButton(
          key: const ValueKey('entry-drafts'),
          label: 'Entwürfe',
          icon: Icons.edit_note,
          count: entryDraftCount(
            c,
            pupilId: r.pupilId,
            kind: r.kind,
            exclude: draftId,
          ),
          onPressed: busy
              ? null
              : () => navigateEntry(
                  () => showEntryDrafts(
                    context,
                    c,
                    pupilId: r.pupilId,
                    kind: r.kind,
                    exclude: draftId,
                  ),
                ),
        ),
      ),
      if (r.kind == SchoolKind.homework)
        AnimatedBuilder(
          animation: c,
          builder: (_, _) => EntryHeaderButton(
            key: const ValueKey('assigned-homework'),
            label: 'Aufgegebene Hausübungen',
            icon: Icons.home_work_outlined,
            count: c.records
                .where(
                  (v) =>
                      !v.deleted &&
                      v.pupilId == r.pupilId &&
                      v.kind == SchoolKind.homework,
                )
                .length,
            onPressed: busy
                ? null
                : () => navigateEntry(
                    () => showAssignedHomework(context, c, r.pupilId),
                  ),
          ),
        ),
    ];
    return EntryPageHeader(
      owner: pupil.name,
      title: r.revision > 0
          ? (r.kind == SchoolKind.homework
                ? 'Hausübung bearbeiten'
                : r.kind == SchoolKind.goal
                ? 'Ziel bearbeiten'
                : 'Eintrag bearbeiten')
          : r.kind.label,
      onClose: busy ? null : close,
      actions: actions,
      titleActions: [
        if (dirty || draftRevision > 0)
          EditorDraftDeleteButton(onPressed: busy ? null : deleteDraft),
      ],
    );
  }

  Widget observationFooter() => LayoutBuilder(
    builder: (context, constraints) {
      final date = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Beobachtet am', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            key: const ValueKey('observation-date'),
            onPressed: busy ? null : () => chooseDate('observedOn', time: true),
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            label: Text(
              '${displayDate(r.observedOn)}${r.observedTime.isEmpty ? '' : ' · ${r.observedTime}'}',
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      );
      final later = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompactSwitch(
            key: const ValueKey('observation-later'),
            value: r.needsCompletion,
            onChanged: busy ? null : (v) => edit({'needsCompletion': v}),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const Flexible(
            child: Text('Später ergänzen', style: TextStyle(fontSize: 13)),
          ),
        ],
      );
      final narrow =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (narrow) ...[
            date,
            const SizedBox(height: 4),
            later,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: date),
                const SizedBox(width: 8),
                Flexible(child: later),
              ],
            ),
          const Divider(height: 14),
          if (draftStatus.isNotEmpty || draftRevision > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  draftStatus.isEmpty ? 'Entwurf geöffnet' : draftStatus,
                  key: const ValueKey('school-draft-status'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const ValueKey('cancel-editor'),
                  onPressed: busy ? null : close,
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('save-school-record'),
                  onPressed: busy ? null : save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    busy
                        ? 'Speichern …'
                        : r.revision > 0
                        ? 'Änderungen speichern'
                        : 'Speichern',
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
