part of 'school_editor.dart';

extension _SchoolEditorView on _SchoolEditorState {
  Widget editorView(BuildContext context) {
    final title = mode == 'review'
        ? 'Ziel überprüfen'
        : mode == 'comment'
        ? (taskId == null ? 'Notiz & Verlauf' : 'Kommentar')
        : r.kind == SchoolKind.homework && r.revision > 0
        ? 'Hausübung bearbeiten'
        : r.kind.label;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: Focus(
          autofocus: true,
          child: FlexModal(
            closeLabel: 'Schließen und Entwurf sichern',
            key: ValueKey(draftId),
            maxWidth: mode == 'comment'
                ? 430
                : mode == 'review'
                ? 600
                : r.kind == SchoolKind.homework && r.revision > 0
                ? 1000
                : 640,
            headerContent: mode == 'entry' ? observationHeader() : null,
            headerActions: [
              if (mode != 'entry' && (dirty || draftRevision > 0))
                EditorDraftDeleteButton(onPressed: busy ? null : deleteDraft),
            ],
            footerContent: isObservation ? observationFooter() : null,
            title: Row(
              children: [
                FlexIcon(FlexIcon.forKind(r.kind)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mode == 'entry')
                        Text(
                          c.pupils.firstWhere((p) => p.id == r.pupilId).name,
                          style: const TextStyle(
                            fontFamily: 'FlexSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(title),
                    ],
                  ),
                ),
              ],
            ),
            onClose: busy ? null : close,
            content: AbsorbPointer(
              absorbing: busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r.revision > 0 && mode != 'entry')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        c.pupils.firstWhere((p) => p.id == r.pupilId).name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  if (mode == 'comment')
                    comment()
                  else if (mode == 'review')
                    review()
                  else if (r.kind == SchoolKind.homework)
                    homework()
                  else if (r.kind == SchoolKind.goal)
                    goal()
                  else
                    r.revision > 0
                        ? observationEdit()
                        : OptionSwipe(
                            key: const ValueKey('observation-swipe'),
                            onChanged: (value) => updateEditor(() {
                              final tones = observationTones.keys.toList();
                              selectedTone =
                                  tones[(tones.indexOf(selectedTone) +
                                          (value ? -1 : 1))
                                      .clamp(0, tones.length - 1)];
                            }),
                            child: observation(),
                          ),
                  const SizedBox(height: 12),
                  if (mode == 'entry')
                    PersonAssignmentField(
                      pupils: c.pupils,
                      selected: {r.pupilId, ...r.participantIds},
                      locked: {r.pupilId},
                      otherNames: r.otherParticipants,
                      maxNameLength: null,
                      onChanged: (ids, names) => edit({
                        'participantIds': ids
                            .where((id) => id != r.pupilId)
                            .toList(),
                        'otherParticipants': names,
                      }),
                    ),
                  attachments(forTask: mode == 'comment' ? taskId : null),
                  if (stale && mode == 'comment')
                    TextButton(
                      onPressed: rebaseComment,
                      child: const Text('Aktuelle Fassung übernehmen'),
                    ),
                  if (error != null)
                    Padding(
                      key: errorAnchor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          key: const ValueKey('record-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (mode == 'entry')
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.kind == SchoolKind.goal
                            ? 'Vereinbart am'
                            : 'Aufgegeben am',
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => chooseDate('observedOn', time: true),
                            icon: const Icon(Icons.calendar_month, size: 18),
                            label: Text(
                              '${displayDate(r.observedOn)}${r.observedTime.isEmpty ? '' : ' · ${r.observedTime}'}',
                            ),
                            style: TextButton.styleFrom(
                              textStyle: const TextStyle(
                                fontFamily: 'FlexSans',
                                fontSize: 13,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                          transparentChip(
                            FilterChip(
                              label: const Text('Später ergänzen'),
                              selected: r.needsCompletion,
                              onSelected: busy
                                  ? null
                                  : (v) => edit({'needsCompletion': v}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (draftStatus.isNotEmpty || draftRevision > 0)
                Text(
                  draftStatus.isEmpty ? 'Entwurf geöffnet' : draftStatus,
                  key: const ValueKey('school-draft-status'),
                  style: const TextStyle(fontSize: 11),
                ),
              TextButton(
                key: const ValueKey('cancel-editor'),
                onPressed: busy ? null : close,
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                key: const ValueKey('save-school-record'),
                onPressed: busy ? null : save,
                child: Text(
                  busy
                      ? 'Speichern …'
                      : mode == 'review'
                      ? 'Überprüfung speichern'
                      : mode == 'comment'
                      ? taskId == null
                            ? 'Notiz speichern'
                            : 'Kommentar speichern'
                      : r.kind == SchoolKind.goal
                      ? 'Ziel speichern'
                      : r.revision > 0
                      ? 'Änderungen speichern'
                      : 'Hausübung aufgeben',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
