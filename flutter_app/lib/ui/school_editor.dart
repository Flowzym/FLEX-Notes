import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'flex_icons.dart';
import 'flex_modal.dart';

class PupilTags extends StatelessWidget {
  const PupilTags({
    super.key,
    required this.pupils,
    required this.selected,
    required this.onChanged,
    this.multiple = true,
  });
  final List<Pupil> pupils;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool multiple;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final p in pupils)
        FilterChip(
          key: ValueKey('pupil-tag-${p.id}'),
          showCheckmark: false,
          avatar: CircleAvatar(backgroundColor: Color(p.color), radius: 9),
          label: Text(p.name),
          selected: selected.contains(p.id),
          onSelected: (active) {
            final next = multiple ? {...selected} : <String>{};
            if (active) {
              next.add(p.id);
            } else {
              next.remove(p.id);
            }
            onChanged(next);
          },
        ),
    ],
  );
}

class SchoolEditor extends StatefulWidget {
  const SchoolEditor({
    super.key,
    required this.controller,
    required this.record,
    this.draft,
    this.mode = 'entry',
    this.taskId,
    this.feedbackId,
  });
  final NotebookController controller;
  final SchoolRecord record;
  final SchoolDraft? draft;
  final String mode;
  final String? taskId, feedbackId;
  @override
  State<SchoolEditor> createState() => _SchoolEditorState();
}

class _SchoolEditorState extends State<SchoolEditor>
    with WidgetsBindingObserver {
  late SchoolRecord r;
  late String draftId, mode;
  late Set<String> recipients;
  String? taskId, feedbackId;
  int draftRevision = 0;
  Timer? debounce;
  Future<void> pending = Future.value();
  bool busy = false,
      dirty = false,
      canPop = false,
      positive = true,
      extras = false;
  String? error;
  String draftStatus = '';
  final commentFocus = FocusNode();
  final taskFocus = <String, FocusNode>{};
  final freeTag = TextEditingController();
  NotebookController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    r = widget.draft?.record ?? widget.record;
    draftId = widget.draft?.id ?? newId();
    draftRevision = widget.draft?.editRevision ?? 0;
    mode = widget.draft?.mode ?? widget.mode;
    taskId = widget.draft?.taskId ?? widget.taskId;
    feedbackId = widget.draft?.feedbackId ?? widget.feedbackId;
    recipients = {
      ...(widget.draft?.recipients.isNotEmpty == true
          ? widget.draft!.recipients
          : [r.pupilId]),
    };
    extras =
        r.context.isNotEmpty ||
        r.support.isNotEmpty ||
        r.participantIds.isNotEmpty ||
        r.otherParticipants.isNotEmpty;
    if (mode == 'comment') {
      if (feedbackId == null) {
        feedbackId = newId();
        final task = r.tasks.where((t) => t.id == taskId).firstOrNull;
        final feedback = SchoolFeedback(
          id: feedbackId!,
          observedOn: dateOnly(DateTime.now()),
          createdAtUtc: utcNow(),
          taskId: taskId,
          taskText: task?.text ?? '',
        );
        r = r.patch({
          'feedback': [...r.feedback.map((f) => f.toJson()), feedback.toJson()],
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) commentFocus.requestFocus();
      });
    } else if (mode == 'review') {
      if (feedbackId == null) {
        feedbackId = newId();
        r = r.patch({
          'reviews': [
            ...r.reviews.map((v) => v.toJson()),
            GoalReview(
              id: feedbackId!,
              decision: 'continue',
              observedOn: dateOnly(DateTime.now()),
              nextReviewDate: r.nextReviewDate,
            ).toJson(),
          ],
        });
      }
    } else if (r.kind == SchoolKind.homework && r.tasks.isEmpty) {
      r = r.patch({
        'tasks': [HomeworkTask(id: newId(), text: '').toJson()],
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    commentFocus.dispose();
    freeTag.dispose();
    for (final f in taskFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !busy) {
      debounce?.cancel();
      persist();
    }
  }

  void edit(Json changes) {
    setState(() {
      r = r.patch(changes);
      dirty = true;
      draftStatus = 'Entwurf wird gesichert …';
    });
    schedule();
  }

  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      persist();
    });
  }

  Future<bool> persist() async {
    if (!dirty && widget.draft == null) return true;
    final snapshot = r, targets = recipients.toList();
    pending = pending.catchError((Object _) {}).then((_) async {
      final saved = await c.repository.saveSchoolDraft(
        SchoolDraft(
          id: draftId,
          record: snapshot,
          updatedAtUtc: utcNow(),
          recipients: targets,
          editRevision: draftRevision,
          mode: mode,
          taskId: taskId,
          feedbackId: feedbackId,
        ),
      );
      draftRevision = saved.editRevision;
    });
    try {
      await pending;
      if (mounted) setState(() => draftStatus = 'Entwurf gesichert');
      return true;
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
      return false;
    }
  }

  Future<void> pop() async {
    setState(() => canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> close() async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (await persist()) {
        await c.reload();
        if (mounted) await pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    debounce?.cancel();
    try {
      await pending;
      if (mode != 'comment' && r.kind == SchoolKind.homework) {
        final kept = r.tasks.where((t) => t.text.trim().isNotEmpty).toList();
        final ids = kept.map((t) => t.id).toSet();
        r = r.patch({
          'tasks': kept
              .map(
                (t) => t
                    .copyWith(
                      text: t.text.trim(),
                      clearParent:
                          t.parentId != null && !ids.contains(t.parentId),
                    )
                    .toJson(),
              )
              .toList(),
        });
      }
      if (mode == 'comment') {
        final f = r.feedback.firstWhere((f) => f.id == feedbackId);
        if (f.note.trim().isEmpty && f.state == null && f.delivery == null) {
          throw const DomainError(
            'Bitte einen Kommentar oder eine geänderte Abgabe eingeben.',
          );
        }
      }
      if (mode == 'review') {
        final review = r.reviews.firstWhere((v) => v.id == feedbackId);
        r = r.patch({
          'goalStatus': switch (review.decision) {
            'achieved' => 'achieved',
            'ended' => 'ended',
            _ => 'active',
          },
          'nextReviewDate': review.nextReviewDate,
        });
      }
      r.validate();
      if (r.revision == 0 && r.kind == SchoolKind.homework) {
        await c.repository.saveSchoolGroup(
          r,
          recipients.toList(),
          draftId,
          draftRevision: draftRevision,
        );
        await c.reload();
      } else {
        await c.saveRecord(r, draftId: draftId, draftRevision: draftRevision);
      }
      if (mounted) await pop();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Widget field(
    String name,
    String label, {
    int lines = 1,
    bool autofocus = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('record-$name'),
      initialValue: r.toJson()[name] as String? ?? '',
      autofocus: autofocus,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      onChanged: (v) => edit({name: v}),
    ),
  );
  Future<void> chooseDate(String name, {bool time = false}) async {
    final selected = await pickFlexDate(
      context,
      date: r.toJson()[name] as String? ?? dateOnly(DateTime.now()),
      time: time ? r.observedTime : '',
      allowTime: time,
      title: time ? 'Datum und Uhrzeit' : 'Termin wählen',
    );
    if (selected != null && mounted) {
      edit({name: selected.$1, if (time) 'observedTime': selected.$2});
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
          decoration: const InputDecoration(
            labelText: 'Kommentar',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => changeFeedback(f.copyWith(note: v)),
        ),
        const SizedBox(height: 16),
        if (taskId == null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const {
                'unknown': 'Nicht überprüft',
                'submitted': 'Vorgelegt',
                'missing': 'Nicht vorgelegt',
                'absent': 'Abwesend',
              }.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: (f.delivery ?? r.delivery) == option.key,
                  onSelected: (_) =>
                      changeFeedback(f.copyWith(delivery: option.key)),
                ),
            ],
          ),
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

  Widget homework() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field('subject', 'Fach'),
        const Text('Aufgaben & Teilaufgaben'),
        const SizedBox(height: 8),
        for (final task in r.tasks)
          Padding(
            padding: EdgeInsets.only(
              left: task.parentId == null ? 0 : 20,
              bottom: 12,
            ),
            child: Column(
              children: [
                TextFormField(
                  key: ValueKey('task-${task.id}'),
                  focusNode: taskFocus.putIfAbsent(task.id, () => FocusNode()),
                  initialValue: task.text,
                  decoration: InputDecoration(
                    labelText: task.parentId == null
                        ? 'Aufgabe'
                        : 'Teilaufgabe',
                  ),
                  onChanged: (v) => edit({
                    'tasks': r.tasks
                        .map(
                          (t) => (t.id == task.id ? t.copyWith(text: v) : t)
                              .toJson(),
                        )
                        .toList(),
                  }),
                  onFieldSubmitted: (_) => addTask(after: task),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Weitere Aufgabenzeile',
                      onPressed: () => addTask(after: task),
                      icon: const Icon(Icons.keyboard_return),
                    ),
                    IconButton(
                      tooltip: 'Teilaufgabe hinzufügen',
                      onPressed: () => addTask(
                        parent: task.parentId ?? task.id,
                        after: task,
                      ),
                      icon: const Icon(Icons.subdirectory_arrow_right),
                    ),
                    IconButton(
                      tooltip: 'Aufgabe entfernen',
                      onPressed: () => edit({
                        'tasks': r.tasks
                            .where((t) => t.id != task.id)
                            .map(
                              (t) => t
                                  .copyWith(clearParent: t.parentId == task.id)
                                  .toJson(),
                            )
                            .toList(),
                      }),
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => addTask(),
            icon: const Icon(Icons.add),
            label: const Text('Aufgabe hinzufügen'),
          ),
        ),
        dateField('dueDate', 'Fällig am'),
        if (r.revision == 0) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Für welche Schüler?'),
          ),
          PupilTags(
            pupils: c.pupils.where((p) => !p.archived).toList(),
            selected: recipients,
            onChanged: (v) {
              setState(() => recipients = v);
              edit({});
            },
          ),
        ],
      ],
    );
  }

  void addTask({String? parent, HomeworkTask? after}) {
    final tasks = [...r.tasks], id = newId();
    var index = after == null ? tasks.length : tasks.indexOf(after) + 1;
    if (after != null && parent == null) {
      while (index < tasks.length && tasks[index].parentId == after.id) {
        index++;
      }
    }
    tasks.insert(
      index,
      HomeworkTask(id: id, text: '', parentId: parent ?? after?.parentId),
    );
    edit({'tasks': tasks.map((t) => t.toJson()).toList()});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) taskFocus[id]?.requestFocus();
    });
  }

  Widget goal() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      field('title', 'Ziel', autofocus: true),
      field('criterion', 'Woran erkennen wir den Fortschritt?', lines: 2),
      field('body', 'Nächster Schritt', lines: 2),
      field('support', 'Unterstützung', lines: 2),
      field('pupilPerspective', 'Schülerperspektive', lines: 2),
      dateField('dueDate', 'Zieltermin'),
      Wrap(
        spacing: 8,
        children: [
          for (final days in [7, 14, 30])
            ActionChip(
              label: Text(days == 30 ? 'Ein Monat' : '$days Tage'),
              onPressed: () => edit({
                'dueDate': dateOnly(DateTime.now().add(Duration(days: days))),
              }),
            ),
        ],
      ),
      dateField('nextReviewDate', 'Nächste Überprüfung'),
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
        Text(r.criterion),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: value.note,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Was hat sich gezeigt?'),
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
              'ended': 'Beenden',
              'reopen': 'Wieder öffnen',
            }.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: value.decision == option.key,
                onSelected: (_) => change({'decision': option.key}),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: value.nextStep,
          decoration: const InputDecoration(labelText: 'Nächster Schritt'),
          onChanged: (v) => change({'nextStep': v}),
        ),
        TextButton.icon(
          onPressed: () async {
            final date = await pickFlexDate(
              context,
              date: value.nextReviewDate ?? dateOnly(DateTime.now()),
              allowTime: false,
            );
            if (date != null && mounted) change({'nextReviewDate': date.$1});
          },
          icon: const Icon(Icons.calendar_month),
          label: Text(
            'Nächste Überprüfung: ${displayDate(value.nextReviewDate)}',
          ),
        ),
        ExpansionTile(
          title: const Text('Zugeordnete Beobachtungen'),
          children: [
            for (final record in c.records.where(
              (v) => !v.deleted && v.goalId == r.id,
            ))
              ListTile(
                title: Text(record.body),
                subtitle: Text(
                  '${displayDate(record.observedOn)} · ${record.kind.label}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget observation() {
    final options = r.kind == SchoolKind.social
        ? (positive
              ? [
                  'Hilft anderen',
                  'Hört zu',
                  'Hält Regeln ein',
                  'Löst Konflikte friedlich',
                  'Geht respektvoll mit anderen um',
                  'Übernimmt Verantwortung',
                ]
              : [
                  'Unterbricht andere',
                  'Hält Regeln nicht ein',
                  'Grenzt andere aus',
                  'Reagiert impulsiv',
                  'Benötigt Unterstützung im Konflikt',
                ])
        : (positive
              ? [
                  'Arbeitet konzentriert',
                  'Beginnt selbstständig',
                  'Bleibt bei der Aufgabe',
                  'Arbeitet sorgfältig',
                  'Fragt gezielt nach',
                  'Nutzt die Arbeitszeit',
                ]
              : [
                  'Lässt sich ablenken',
                  'Beginnt verzögert',
                  'Benötigt wiederholte Anleitung',
                  'Gibt schnell auf',
                  'Material fehlt',
                ]);
    final selected = positive ? r.positive : r.negative;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r.kind == SchoolKind.work) field('subject', 'Auftrag', lines: 2),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in const {
              'before': 'Vor Unterricht',
              'during': 'Unterricht',
              'after': 'Nach Unterricht',
              'break': 'Pause',
            }.entries)
              ChoiceChip(
                label: Text(choice.value),
                selected: r.situation == choice.key,
                onSelected: (_) => edit({'situation': choice.key}),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Positiv'),
              selected: positive,
              onSelected: (_) => setState(() => positive = true),
            ),
            ChoiceChip(
              label: const Text('Negativ'),
              selected: !positive,
              onSelected: (_) => setState(() => positive = false),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final text in options.where((s) => !selected.contains(s)))
              ActionChip(
                label: Text(text),
                onPressed: () => edit({
                  positive ? 'positive' : 'negative': [...selected, text],
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final positiveValue in [true, false])
                    for (final text in positiveValue ? r.positive : r.negative)
                      InputChip(
                        label: Text('${positiveValue ? '+' : '−'} $text'),
                        onDeleted: () => edit({
                          positiveValue ? 'positive' : 'negative':
                              (positiveValue ? r.positive : r.negative)
                                  .where((v) => v != text)
                                  .toList(),
                        }),
                      ),
                ],
              ),
              const SizedBox(height: 8),
              field('body', 'Was ist passiert?', lines: 3),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: freeTag,
                decoration: const InputDecoration(labelText: 'Eigene Auswahl'),
              ),
            ),
            IconButton(
              tooltip: 'Auswahl hinzufügen',
              icon: const Icon(Icons.add),
              onPressed: () {
                final text = freeTag.text.trim();
                if (text.isNotEmpty && !selected.contains(text)) {
                  edit({
                    positive ? 'positive' : 'negative': [...selected, text],
                  });
                  freeTag.clear();
                }
              },
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kontext / Quelle'),
          value: extras,
          onChanged: (v) => setState(() => extras = v),
        ),
        if (extras) ...[
          field('context', 'Gemeinsamer Kontext', lines: 2),
          field('support', 'Reaktion / Unterstützung', lines: 2),
          Wrap(
            spacing: 8,
            children: [
              for (final source in const {
                'self': 'Selbst beobachtet',
                'reported': 'Berichtet',
                'interpretation': 'Eigene Einordnung',
              }.entries)
                ChoiceChip(
                  label: Text(source.value),
                  selected: r.source == source.key,
                  onSelected: (_) => edit({'source': source.key}),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Beteiligt · keine zusätzliche Einzelbewertung'),
          ),
          PupilTags(
            pupils: c.pupils
                .where((p) => !p.archived && p.id != r.pupilId)
                .toList(),
            selected: r.participantIds.toSet(),
            onChanged: (v) => edit({'participantIds': v.toList()}),
          ),
          field('otherParticipants', 'Weitere Namen'),
        ],
        if (c.records.any(
          (v) =>
              v.kind == SchoolKind.goal && v.pupilId == r.pupilId && !v.deleted,
        )) ...[
          const Text('Zielbezug'),
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
                FilterChip(
                  label: Text(g.title),
                  selected: r.goalId == g.id,
                  onSelected: (active) => edit({
                    'goalId': active ? g.id : null,
                    'goalSnapshot': active ? g.title : '',
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = mode == 'review'
        ? 'Ziel überprüfen'
        : mode == 'comment'
        ? (taskId == null ? 'Notiz & Abgabe' : 'Kommentar')
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
            maxWidth: mode == 'comment' ? 430 : 640,
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
                            fontFamily: 'FlexSerif',
                            fontSize: 21,
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
                  if (mode == 'entry' &&
                      r.revision == 0 &&
                      r.kind != SchoolKind.homework)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PupilTags(
                        pupils: c.pupils.where((p) => !p.archived).toList(),
                        selected: {r.pupilId},
                        multiple: false,
                        onChanged: (v) {
                          if (v.isNotEmpty) edit({'pupilId': v.single});
                        },
                      ),
                    ),
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
                    observation(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
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
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => chooseDate('observedOn', time: true),
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          '${displayDate(r.observedOn)} ${r.observedTime}',
                        ),
                      ),
                      FilterChip(
                        label: const Text('Später ergänzen'),
                        selected: r.needsCompletion,
                        onSelected: busy
                            ? null
                            : (v) => edit({'needsCompletion': v}),
                      ),
                    ],
                  ),
                ),
              if (draftStatus.isNotEmpty) Text(draftStatus),
              TextButton(
                onPressed: busy ? null : close,
                child: const Text('Als Entwurf schließen'),
              ),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Speichern …' : 'Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
