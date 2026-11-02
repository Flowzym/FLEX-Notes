import 'pupil_history.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/drafts.dart';
import '../domain/school.dart';
import '../domain/observation_catalog.dart';
import 'common.dart';
import 'flex_icons.dart';
import 'flex_modal.dart';
import 'surfaces.dart';
import 'tag_text_field.dart';
import 'homework_task_editor.dart';
import 'draft_buffer.dart';
import 'dialog_workflows.dart';

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
  int draftRevision = 0, editGeneration = 0;
  late String baseline;
  String signature(SchoolRecord value, Iterable<String> targets) =>
      draftSignature({
        'record': value.toJson(),
        'recipients': targets.where((id) => id != value.pupilId).toList()
          ..sort(),
      });
  Timer? debounce;
  Future<void> pending = Future.value();
  final errorAnchor = GlobalKey();
  void revealError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = errorAnchor.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  bool busy = false,
      dirty = false,
      canPop = false,
      positive = true,
      participantsOpen = false,
      goalOpen = false,
      supportOpen = false,
      contextOpen = false,
      catalogBusy = true,
      allOptions = false,
      deliveryOpen = false;
  final catalogs = <String, ObservationCatalog>{};
  bool get isObservation =>
      mode == 'entry' &&
      (r.kind == SchoolKind.social || r.kind == SchoolKind.work);
  String get catalogKey =>
      '${r.kind.name}-${positive ? 'positive' : 'negative'}';
  String? error;
  bool stale = false;
  String draftStatus = '';
  final commentFocus = FocusNode();
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
    restoreSections();
    if (isObservation) loadCatalogs();
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
              nextStep: r.body,
              nextReviewDate: dateOnly(
                DateTime.now().add(const Duration(days: 7)),
              ),
            ).toJson(),
          ],
        });
      }
    } else if (r.kind == SchoolKind.homework && r.tasks.isEmpty) {
      r = r.patch({
        'tasks': [HomeworkTask(id: newId(), text: '').toJson()],
      });
    }
    final original =
        c.records.where((value) => value.id == r.id).firstOrNull ??
        SchoolRecord.empty(
          r.kind,
          r.pupilId,
        ).patch({'observedOn': r.observedOn});
    baseline =
        widget.draft?.baseline ??
        signature(widget.draft == null ? r : original, [r.pupilId]);
    dirty = widget.draft != null && signature(r, recipients) == baseline;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    commentFocus.dispose();
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
      editGeneration++;
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
    final snapshot = r,
        targets = recipients.toList(),
        generation = editGeneration;
    if (dirty) {
      pending = pending.catchError((Object _) {}).then((_) async {
        if (signature(snapshot, targets) == baseline) {
          if (draftRevision > 0) {
            await c.repository.discardSchoolDraft(
              draftId,
              expectedRevision: draftRevision,
            );
            draftRevision = 0;
          }
        } else {
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
              baseline: baseline,
            ),
          );
          draftRevision = saved.editRevision;
        }
        if (generation == editGeneration) dirty = false;
        await c.reload();
      });
    }
    try {
      await pending;
      if (mounted) {
        setState(
          () => draftStatus = dirty
              ? 'Entwurf wird gesichert …'
              : draftRevision > 0
              ? 'Entwurf gesichert'
              : '',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          draftStatus = 'Entwurf nicht gesichert';
        });
      }
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
      } else if (mounted &&
          await unsavedDraft(context, c.repository, {
            'type': 'school',
            'draft': SchoolDraft(
              id: draftId,
              record: r,
              updatedAtUtc: utcNow(),
              recipients: recipients.toList(),
              editRevision: draftRevision,
              mode: mode,
              taskId: taskId,
              feedbackId: feedbackId,
              baseline: baseline,
            ).toJson(),
          }) &&
          mounted) {
        await c.repository.discardSchoolDraft(
          draftId,
          expectedRevision: draftRevision,
        );
        await pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save({bool next = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    debounce?.cancel();
    try {
      await pending.catchError((Object _) {});
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
      if (mode == 'entry' && r.kind == SchoolKind.goal && r.revision > 0) {
        final previous = c.records.where((v) => v.id == r.id).firstOrNull;
        if (previous != null && previous.goalStatus != r.goalStatus) {
          final statusId = 'goal-status-$draftId';
          r = r.patch({
            if (r.goalStatus != 'active') 'nextReviewDate': null,
            'reviews': [
              ...r.reviews
                  .where((v) => v.id != statusId)
                  .map((v) => v.toJson()),
              GoalReview(
                id: statusId,
                observedOn: dateOnly(DateTime.now()),
                decision: r.goalStatus == 'active' ? 'reopen' : r.goalStatus,
                note: 'Stand bei Zielbearbeitung geändert.',
              ).toJson(),
            ],
          });
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
          'nextReviewDate': review.decision == 'continue'
              ? review.nextReviewDate
              : null,
          if (review.decision == 'continue') 'body': review.nextStep,
          'reviews': r.reviews.map((v) {
            final json = v.toJson();
            if (v.id == feedbackId && review.decision != 'continue') {
              json['nextReviewDate'] = null;
              json['nextStep'] = '';
            }
            return json;
          }).toList(),
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
      if (mounted && next && isObservation) {
        final pupils = c.pupils.where((p) => !p.archived).toList();
        final index = pupils.indexWhere((p) => p.id == r.pupilId);
        if (index >= 0 && index + 1 < pupils.length) {
          final pupil = pupils[index + 1];
          setState(() {
            r = SchoolRecord.empty(r.kind, pupil.id).patch({
              'observedOn': r.observedOn,
              'observedTime': r.observedTime,
            });
            draftId = newId();
            draftRevision = 0;
            recipients = {pupil.id};
            dirty = false;
            editGeneration = 0;
            baseline = signature(r, recipients);
            draftStatus = '';
            restoreSections();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gespeichert. Letzter Schüler erreicht.'),
            ),
          );
          setState(() {
            r = SchoolRecord.empty(r.kind, r.pupilId).patch({
              'observedOn': r.observedOn,
              'observedTime': r.observedTime,
            });
            draftId = newId();
            draftRevision = 0;
            dirty = false;
            editGeneration = 0;
            baseline = signature(r, recipients);
            draftStatus = 'Gespeichert. Letzter Schüler erreicht.';
            restoreSections();
          });
        }
      } else if (mounted) {
        await pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          stale = e is StaleRevision;
        });
        revealError();
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> rebaseComment() async {
    final records = await c.repository.schoolRecords();
    final current = records
        .where((v) => v.id == r.id && !v.deleted)
        .firstOrNull;
    if (current == null || !mounted) return;
    final edited = r.feedback.firstWhere((f) => f.id == feedbackId);
    if (taskId != null && !current.tasks.any((t) => t.id == taskId)) {
      setState(
        () => error =
            'Diese Aufgabe ist in der aktuellen Fassung nicht mehr vorhanden.',
      );
      return;
    }
    final accepted = await confirmFlex(
      context,
      'Änderungskonflikte',
      'Die aktuelle Fassung wird geladen. Nur dein Kommentar und die ausdrücklich bearbeitete Abgabe werden übertragen. Aufgabenstände bleiben erhalten.',
      accept: 'Aktuelle Fassung übernehmen',
    );
    if (!accepted || !mounted) return;
    final previous = current.feedback
        .where((f) => f.id == feedbackId)
        .firstOrNull;
    final merged = previous == null
        ? edited
        : previous.copyWith(note: edited.note, delivery: edited.delivery);
    edit({
      'revision': current.revision,
      'feedback': [
        ...current.feedback
            .where((f) => f.id != feedbackId)
            .map((f) => f.toJson()),
        merged.toJson(),
      ],
      'tasks': current.tasks.map((t) => t.toJson()).toList(),
    });
    // Retain all non-comment fields from the current version as well.
    setState(() {
      r = current.patch({
        'feedback': r.feedback.map((f) => f.toJson()).toList(),
      });
      stale = false;
      error = null;
    });
    schedule();
  }

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
        if (taskId == null)
          optionalSection(
            'Abgabe & Zeitpunkt',
            deliveryOpen,
            (v) => deliveryOpen = v,
            Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in const {
                      'unknown': 'Nicht überprüft',
                      'submitted': 'Vorgelegt',
                      'missing': 'Nicht vorgelegt',
                      'absent': 'Abwesend',
                    }.entries.where((choice) => r.situation != choice.key))
                      ChoiceChip(
                        label: Text(option.value),
                        selected: (f.delivery ?? r.delivery) == option.key,
                        onSelected: (_) =>
                            changeFeedback(f.copyWith(delivery: option.key)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (taskId != null || deliveryOpen)
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

  Widget homework() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HomeworkTaskEditor(
        tasks: r.tasks,
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
            setState(() => recipients = v);
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
                      DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month),
                    ),
                  ),
                };
                edit({'dueDate': dateOnly(target)});
              },
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
              ChoiceChip(
                label: Text(option.value),
                selected: r.goalStatus == option.key,
                onSelected: (_) => edit({'goalStatus': option.key}),
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
              '${displayDate(evidence.observedOn)} · ${evidence.body.isNotEmpty ? evidence.body : [...evidence.positive, ...evidence.negative].join(', ')}',
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
              ChoiceChip(
                label: Text(option.value),
                selected: value.decision == option.key,
                onSelected: (_) => change({'decision': option.key}),
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
    positive = r.negative.isEmpty || r.positive.isNotEmpty;
    participantsOpen =
        r.participantIds.isNotEmpty || r.otherParticipants.isNotEmpty;
    goalOpen = r.goalId != null;
    supportOpen = r.support.isNotEmpty;
    contextOpen = r.context.isNotEmpty || r.source != 'self';
  }

  Future<void> loadCatalogs() async {
    try {
      final keys = observationDefaults.keys.toList();
      final values = await Future.wait(
        keys.map(c.repository.observationCatalog),
      );
      if (!mounted) return;
      setState(() => catalogs.addAll(Map.fromIterables(keys, values)));
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => catalogBusy = false);
    }
  }

  Future<void> favorite(String text) async {
    if (catalogBusy) return;
    final key = catalogKey;
    setState(() => catalogBusy = true);
    try {
      final value = await c.repository.toggleObservationFavorite(key, text);
      if (mounted) setState(() => catalogs[key] = value);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => catalogBusy = false);
    }
  }

  Future<void> editOptions() async {
    await showCatalog(context, c, r.kind.name);
    await loadCatalogs();
  }

  Future<void> observationHistory() => showPupilHistory(context, c, r.pupilId);

  Widget optionalSection(
    String label,
    bool active,
    ValueChanged<bool> change,
    Widget content,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Switch(
            key: ValueKey('section-$label'),
            value: active,
            onChanged: (v) => setState(() => change(v)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
      if (active)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: content,
        ),
    ],
  );

  List<String> get recentAssignments {
    final records =
        c.records.where((v) => v.kind == SchoolKind.work && !v.deleted).toList()
          ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return {
      for (final v in records) ...[
        ...v.taskTags,
        if (v.assignmentFree.trim().isNotEmpty) v.assignmentFree.trim(),
      ],
    }.toList();
  }

  void assignment(List<String> tags, String free) => edit({
    'taskTags': tags,
    'taskFree': free,
    'subject': [...tags, if (free.trim().isNotEmpty) free.trim()].join(' · '),
  });

  Widget observation() {
    final scheme = Theme.of(context).colorScheme;
    final catalog =
        catalogs[catalogKey] ?? ObservationCatalog.defaults(catalogKey);
    final selected = positive ? r.positive : r.negative;
    final options = [
      ...catalog.favorites,
      ...catalog.options.where((s) => !catalog.favorites.contains(s)),
    ];
    options.removeWhere(selected.contains);
    final visibleOptions = allOptions ? options : options.take(6).toList();
    final selectionColor = positive ? scheme.primary : const Color(0xffefcbb9);
    Widget label(String title, String hint) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
        Row(
          children: [
            for (final value in [true, false])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: TextButton(
                    key: ValueKey('tone-$value'),
                    onPressed: () => setState(() => positive = value),
                    style: TextButton.styleFrom(
                      backgroundColor: positive == value
                          ? (value ? scheme.primary : const Color(0xffefcbb9))
                          : Colors.transparent,
                      foregroundColor: positive == value
                          ? const Color(0xff182014)
                          : scheme.onSurface,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: Text(value ? 'Positiv' : 'Negativ'),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (r.kind == SchoolKind.work) ...[
          label('Auftrag', 'optional'),
          if (recentAssignments.isNotEmpty) ...[
            const Text('Zuletzt verwendet', style: TextStyle(fontSize: 12)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final text
                    in recentAssignments
                        .where((s) => !r.taskTags.contains(s))
                        .take(6))
                  ActionChip(
                    label: Text(text),
                    onPressed: () =>
                        assignment([...r.taskTags, text], r.assignmentFree),
                  ),
              ],
            ),
          ],
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
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Beobachtung',
                style: TextStyle(fontWeight: FontWeight.w600),
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
            for (final text in visibleOptions)
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
                            ).extension<FlexSurfaces>()?.palette?.button ??
                            scheme.onSurface.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(24),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            foregroundColor: selected.contains(text)
                                ? legibleOn(selectionColor)
                                : Theme.of(context)
                                          .extension<FlexSurfaces>()
                                          ?.palette
                                          ?.buttonInk ??
                                      scheme.onSurface,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 6,
                              top: 8,
                              bottom: 8,
                            ),
                          ),
                          onPressed: () => edit({
                            positive
                                ? 'positive'
                                : 'negative': selected.contains(text)
                                ? selected.where((s) => s != text).toList()
                                : [...selected, text],
                          }),
                          child: Text(text),
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
                            minWidth: 36,
                            minHeight: 40,
                          ),
                          padding: const EdgeInsets.only(right: 8, left: 2),
                          iconSize: 19,
                          color: selected.contains(text)
                              ? legibleOn(selectionColor)
                              : Theme.of(context)
                                        .extension<FlexSurfaces>()
                                        ?.palette
                                        ?.buttonInk ??
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
        if (options.length > 6)
          TextButton(
            onPressed: () => setState(() => allOptions = !allOptions),
            child: Text(
              allOptions
                  ? 'Weniger anzeigen'
                  : 'Alle ${options.length} anzeigen',
            ),
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
                ChoiceChip(
                  label: Text(choice.value),
                  backgroundColor:
                      Theme.of(
                        context,
                      ).extension<FlexSurfaces>()?.palette?.button ??
                      scheme.onSurface.withValues(alpha: .07),
                  color: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? scheme.primary
                        : Theme.of(
                                context,
                              ).extension<FlexSurfaces>()?.palette?.button ??
                              scheme.onSurface.withValues(alpha: .07),
                  ),
                  selected: r.situation == choice.key,
                  showCheckmark: false,
                  onSelected: (active) =>
                      edit({'situation': active ? choice.key : ''}),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TagTextField(
          fieldKey: const ValueKey('record-body'),
          value: r.body,
          hint: 'Beobachtung …',
          tags: [
            for (final tone in [true, false])
              for (final text in tone ? r.positive : r.negative)
                (
                  id: '${tone ? 'positive' : 'negative'}-$text',
                  label: '${tone ? '+' : '−'} $text',
                  remove: () => edit({
                    tone
                        ? 'positive'
                        : 'negative': (tone ? r.positive : r.negative)
                        .where((t) => t != text)
                        .toList(),
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
                    ChoiceChip(
                      label: Text(source.value),
                      selected: r.source == source.key,
                      onSelected: (_) => edit({'source': source.key}),
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
                  ActionChip(
                    label: Text(choice.value),
                    onPressed: () => edit({'situation': choice.key}),
                  ),
            ],
          ),
        TagTextField(
          fieldKey: const ValueKey('record-body'),
          value: r.body,
          hint: 'Beobachtung …',
          tags: [
            for (final tone in [true, false])
              for (final text in tone ? r.positive : r.negative)
                (
                  id: '${tone ? 'positive' : 'negative'}-$text',
                  label: '${tone ? '+' : '−'} $text',
                  remove: () => edit({
                    tone
                        ? 'positive'
                        : 'negative': (tone ? r.positive : r.negative)
                        .where((t) => t != text)
                        .toList(),
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final text
                  in recentAssignments
                      .where((t) => !r.taskTags.contains(t))
                      .take(6))
                ActionChip(
                  label: Text(text),
                  onPressed: () =>
                      assignment([...r.taskTags, text], r.assignmentFree),
                ),
            ],
          ),
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
            for (final tone in [true, false])
              for (
                var index = 0;
                index < (tone ? r.positive : r.negative).length;
                index++
              )
                Builder(
                  builder: (ctx) {
                    final list = tone ? r.positive : r.negative;
                    return Row(
                      children: [
                        Text(tone ? '+' : '−'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              'edit-selection-$tone-$index-${list.length}',
                            ),
                            initialValue: list[index],
                            maxLength: 300,
                            decoration: InputDecoration(
                              labelText: tone ? 'Positiv' : 'Negativ',
                              counterText: '',
                            ),
                            onChanged: (v) {
                              final values = [...list];
                              values[index] = v;
                              edit({tone ? 'positive' : 'negative': values});
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Beobachtung entfernen',
                          onPressed: () {
                            final values = [...list]..removeAt(index);
                            edit({tone ? 'positive' : 'negative': values});
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
                for (final tone in [true, false])
                  TextButton(
                    onPressed: () => edit({
                      tone ? 'positive' : 'negative': [
                        ...(tone ? r.positive : r.negative),
                        '',
                      ],
                    }),
                    child: Text(
                      tone
                          ? '+ Beobachtung ergänzen'
                          : '− Beobachtung ergänzen',
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
              ChoiceChip(
                label: const Text('Ohne Zielzuordnung'),
                selected: r.goalId == null,
                onSelected: (_) => edit({'goalId': null, 'goalSnapshot': ''}),
              ),
              for (final goal in c.records.where(
                (g) =>
                    g.kind == SchoolKind.goal &&
                    g.pupilId == r.pupilId &&
                    !g.deleted &&
                    (g.goalStatus == 'active' || g.id == r.goalId),
              ))
                ChoiceChip(
                  label: Text(goal.title),
                  selected: r.goalId == goal.id,
                  onSelected: (_) =>
                      edit({'goalId': goal.id, 'goalSnapshot': goal.title}),
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
                    ChoiceChip(
                      label: Text(source.value),
                      selected: r.source == source.key,
                      onSelected: (_) => edit({'source': source.key}),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              iconSize: 20,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              tooltip: 'Zurück und Eingaben sichern',
              onPressed: busy ? null : close,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                pupil.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              iconSize: 20,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              tooltip: 'Verlauf',
              onPressed: busy ? null : observationHistory,
              icon: const Icon(Icons.history),
            ),
            IconButton(
              iconSize: 20,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              tooltip: 'Schließen und Eingaben sichern',
              onPressed: busy ? null : close,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 2),
          child: Text(
            r.revision > 0
                ? (r.kind == SchoolKind.homework
                      ? 'Hausübung bearbeiten'
                      : r.kind == SchoolKind.goal
                      ? 'Ziel bearbeiten'
                      : 'Eintrag bearbeiten')
                : r.kind.label,
            style: const TextStyle(
              fontFamily: 'FlexSerif',
              fontSize: 22,
              height: 1.15,
            ),
          ),
        ),
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
          Switch(
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
              if (r.revision == 0)
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : () => save(next: true),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      backgroundColor: Theme.of(
                        context,
                      ).extension<FlexSurfaces>()?.palette?.button,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Speichern & weiter',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              if (r.revision == 0) const SizedBox(width: 12),
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

  @override
  Widget build(BuildContext context) {
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
            key: ValueKey(draftId),
            maxWidth: mode == 'comment'
                ? 430
                : mode == 'review'
                ? 600
                : r.kind == SchoolKind.homework && r.revision > 0
                ? 1000
                : 640,
            appearance: isObservation ? c.appearance : null,
            accentColor: Color(
              c.pupils.firstWhere((p) => p.id == r.pupilId).color,
            ),
            headerContent: mode == 'entry' ? observationHeader() : null,
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
                    r.revision > 0 ? observationEdit() : observation(),
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
                          FilterChip(
                            label: const Text('Später ergänzen'),
                            selected: r.needsCompletion,
                            onSelected: busy
                                ? null
                                : (v) => edit({'needsCompletion': v}),
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
