part of 'school_editor.dart';

extension _SchoolEditorForms on _SchoolEditorState {
  Widget field(
    String name,
    String label, {
    int lines = 1,
    bool autofocus = false,
    int? maxLength,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('record-$name'),
      initialValue: r.toJson()[name] as String? ?? '',
      autofocus: autofocus,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        alignLabelWithHint: true,
      ),
      onChanged: (v) => edit({name: v}),
    ),
  );
  Future<void> chooseDate(String name, {bool time = false}) async {
    final selected = await pickFlexDate(
      context,
      date: r.toJson()[name] as String? ?? dateOnly(DateTime.now()),
      time: time ? r.observedTime : '',
      allowTime: time,
      title: time ? 'Datum & Uhrzeit' : 'Datum wählen',
    );
    if (selected != null && mounted) {
      edit({
        name: selected.$1.isEmpty && name != 'observedOn' ? null : selected.$1,
        if (time) 'observedTime': selected.$2,
      });
    }
  }

  Widget dateField(String name, String label) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      TextButton.icon(
        onPressed: () => chooseDate(name),
        icon: const Icon(Icons.calendar_month),
        label: Text('$label: ${displayDate(r.toJson()[name] as String?)}'),
      ),
      if (r.toJson()[name] != null)
        IconButton(
          tooltip: '$label entfernen',
          onPressed: () => edit({name: null}),
          icon: const Icon(Icons.close),
        ),
    ],
  );
  void changeFeedback(SchoolFeedback f) => edit({
    'feedback': r.feedback
        .map((old) => (old.id == f.id ? f : old).toJson())
        .toList(),
  });
  Widget comment() {
    final f = r.feedback.firstWhere((v) => v.id == feedbackId);
    final task = r.tasks.where((t) => t.id == f.taskId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Stand: ${r.taskState(task).label}'),
          ),
        if (f.taskText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              f.taskText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        TextFormField(
          key: const ValueKey('homework-comment'),
          initialValue: f.note,
          focusNode: commentFocus,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: taskId == null ? 'Notiz' : 'Kommentar',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => changeFeedback(f.copyWith(note: v)),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            final value = await pickFlexDate(
              context,
              date: f.observedOn,
              time: f.observedTime,
            );
            if (value != null && mounted) {
              final next = SchoolFeedback.fromJson({
                ...f.toJson(),
                'observedOn': value.$1,
                'observedTime': value.$2,
              });
              changeFeedback(next);
            }
          },
          icon: const Icon(Icons.calendar_month),
          label: Text(
            'Rückmeldung am ${displayDate(f.observedOn)} ${f.observedTime}',
          ),
        ),
        const Text('Ein Kommentar verändert den Aufgabenstand nicht.'),
      ],
    );
  }

  Future<void> openAttachments({String? forTask, bool scan = false}) async {
    if (busy) return;
    updateEditor(() => busy = true);
    debounce?.cancel();
    try {
      if (!await persist(force: true) || !mounted) return;
      final scope = schoolDraftScanContext(c, draftId, r, taskId: forTask);
      if (scan) {
        await scanAndShow(context, c, scope);
      } else {
        await showContextDocuments(
          context,
          c,
          scope,
          additionalScopes: [
            schoolScanContext(
              c,
              [r],
              taskIds: {r.id: ?forTask},
              includeTasks: false,
            ),
          ],
        );
      }
      if (mounted) await persist();
    } catch (e) {
      if (mounted) updateEditor(() => error = friendlyError(e));
    } finally {
      if (mounted) updateEditor(() => busy = false);
    }
  }

  Widget attachments({
    String? forTask,
    bool showActions = true,
    bool showFiles = true,
  }) => DocumentAttachmentSection(
    key: ValueKey(
      'editor-${showActions ? 'attachments' : 'files'}-${forTask ?? 'entry'}',
    ),
    controller: c,
    scope: schoolDraftScanContext(c, draftId, r, taskId: forTask),
    additionalScopes: [
      schoolScanContext(c, [r], taskIds: {r.id: ?forTask}, includeTasks: false),
    ],
    compact: forTask != null,
    showActions: showActions,
    showFiles: showFiles,
    onScan: () => openAttachments(forTask: forTask, scan: true),
    onDocuments: () => openAttachments(forTask: forTask),
  );

  Widget homework() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HomeworkTaskEditor(
        tasks: r.tasks,
        attachmentActionsBuilder: (task) =>
            attachments(forTask: task.id, showFiles: false),
        attachmentBuilder: (task) =>
            attachments(forTask: task.id, showActions: false),
        onChanged: (tasks) =>
            edit({'tasks': tasks.map((t) => t.toJson()).toList()}),
      ),
      const SizedBox(height: 12),
      field('subject', 'Fach · optional', maxLength: 100, hint: 'Fach …'),
      dateField('dueDate', 'Fällig am'),
      if (r.revision == 0) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('Für welche Schüler?'),
        ),
        PupilTags(
          pupils: c.pupils.where((p) => !p.archived).toList(),
          selected: recipients,
          onChanged: (v) {
            updateEditor(() => recipients = v);
            edit({});
          },
        ),
      ],
    ],
  );

  Widget goal() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      field(
        'title',
        'Was soll erreicht werden?',
        lines: 3,
        autofocus: true,
        maxLength: 3000,
        hint: 'Ziel …',
      ),
      field(
        'criterion',
        'Zielkriterium · optional',
        lines: 2,
        maxLength: 2000,
        hint: 'Zielkriterium …',
      ),
      field(
        'body',
        'Nächster Schritt · optional',
        lines: 2,
        maxLength: 2000,
        hint: 'Nächster Schritt …',
      ),
      const Text('Zieltermin · optional'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in [
            'Bis Freitag',
            'Eine Woche',
            'Zwei Wochen',
            'Ein Monat',
          ])
            transparentChip(
              ActionChip(
                label: Text(label),
                onPressed: () {
                  final now = DateUtils.dateOnly(DateTime.now());
                  final nextMonth = DateTime(now.year, now.month + 1);
                  final target = switch (label) {
                    'Bis Freitag' => now.add(
                      Duration(days: (DateTime.friday - now.weekday + 7) % 7),
                    ),
                    'Eine Woche' => now.add(const Duration(days: 7)),
                    'Zwei Wochen' => now.add(const Duration(days: 14)),
                    _ => DateTime(
                      nextMonth.year,
                      nextMonth.month,
                      now.day.clamp(
                        1,
                        DateUtils.getDaysInMonth(
                          nextMonth.year,
                          nextMonth.month,
                        ),
                      ),
                    ),
                  };
                  edit({'dueDate': dateOnly(target)});
                },
              ),
            ),
        ],
      ),
      dateField('dueDate', 'Zieltermin'),
      if (r.revision > 0) ...[
        const Text('Stand'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const {
              'active': 'In Arbeit',
              'achieved': 'Erreicht',
              'ended': 'Beendet',
            }.entries)
              transparentChip(
                ChoiceChip(
                  label: Text(option.value),
                  selected: r.goalStatus == option.key,
                  onSelected: (_) => edit({'goalStatus': option.key}),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        field(
          'pupilPerspective',
          'Schülerperspektive · optional',
          lines: 2,
          maxLength: 2000,
          hint: 'Eigene Sicht …',
        ),
      ],
      // Preserve the additional fields of this recovered Flutter version.
      if (r.support.isNotEmpty ||
          r.revision == 0 && r.pupilPerspective.isNotEmpty)
        ExpansionTile(
          title: const Text('Ergänzungen'),
          children: [
            field('support', 'Unterstützung', lines: 2),
            if (r.revision == 0)
              field('pupilPerspective', 'Schülerperspektive', lines: 2),
          ],
        ),
    ],
  );
  Widget review() {
    final value = r.reviews.firstWhere((v) => v.id == feedbackId);
    void change(Json values) => edit({
      'reviews': r.reviews
          .map(
            (v) => v.id == value.id ? {...v.toJson(), ...values} : v.toJson(),
          )
          .toList(),
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(r.title, style: Theme.of(context).textTheme.titleLarge),
        Text(
          r.criterion.isEmpty
              ? 'Noch kein Zielkriterium festgehalten.'
              : 'Zielkriterium: ${r.criterion}',
        ),
        if (!c.records.any((v) => !v.deleted && v.goalId == r.id))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Noch keine verknüpften Beobachtungen.'),
          ),
        for (final evidence in c.records.where(
          (v) => !v.deleted && v.goalId == r.id,
        ))
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => SchoolEditor(controller: c, record: evidence),
            ),
            child: Text(
              '${displayDate(evidence.observedOn)} · ${evidence.body.isNotEmpty ? evidence.body : [...evidence.positive, ...evidence.neutral, ...evidence.negative].join(', ')}',
            ),
          ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: value.note,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Was hat sich gezeigt? · optional',
            hintText: 'Beobachtung …',
            counterText: '',
          ),
          onChanged: (v) => change({'note': v}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const {
              'continue': 'Fortführen',
              'achieved': 'Ziel erreicht',
              'ended': 'Beenden, ohne es als erreicht zu markieren',
            }.entries)
              transparentChip(
                ChoiceChip(
                  label: Text(option.value),
                  selected: value.decision == option.key,
                  onSelected: (_) => change({'decision': option.key}),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (value.decision == 'continue') ...[
          TextFormField(
            initialValue: value.nextStep,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Nächster Schritt · optional',
              counterText: '',
            ),
            onChanged: (v) => change({'nextStep': v}),
          ),
          TextButton.icon(
            onPressed: () async {
              final date = await pickFlexDate(
                context,
                date: value.nextReviewDate ?? dateOnly(DateTime.now()),
                allowTime: false,
              );
              if (date != null && mounted) {
                change({'nextReviewDate': date.$1.isEmpty ? null : date.$1});
              }
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(
              'Nächste Überprüfung: ${displayDate(value.nextReviewDate)}',
            ),
          ),
        ],
      ],
    );
  }

  void restoreSections() {
    selectedTone = observationTones.keys.firstWhere(
      (tone) => r.observations(tone).isNotEmpty,
      orElse: () => c.appearance.defaultObservationTone,
    );
    participantsOpen =
        r.participantIds.isNotEmpty || r.otherParticipants.isNotEmpty;
    goalOpen = r.goalId != null;
    supportOpen = r.support.isNotEmpty;
    contextOpen = r.context.isNotEmpty || r.source != 'self';
  }
}
