import 'document_attachments.dart';
import 'observation_tone_colors.dart';
import 'compact_switch.dart';
import 'option_bar.dart';
import 'draft_actions.dart';
import 'option_swipe.dart';
import 'pupil_history.dart';
import 'entry_navigation.dart';

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
        transparentChip(
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
    this.focusDelivery = false,
  });
  final NotebookController controller;
  final SchoolRecord record;
  final SchoolDraft? draft;
  final String mode;
  final String? taskId, feedbackId;
  final bool focusDelivery;
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
      participantsOpen = false,
      goalOpen = false,
      supportOpen = false,
      contextOpen = false,
      catalogBusy = true,
      deliveryOpen = false;
  String selectedTone = 'neutral';
  final catalogs = <String, ObservationCatalog>{};
  bool get isObservation =>
      mode == 'entry' &&
      (r.kind == SchoolKind.social || r.kind == SchoolKind.work);
  String get catalogKey => '${r.kind.name}-$selectedTone';
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
        if (mounted && !widget.focusDelivery) commentFocus.requestFocus();
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
    if (busy) return;
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

  Future<void> navigateEntry(Future<void> Function() open) async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (await persist() && mounted) {
        await open();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pop() async {
    setState(() => canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> deleteDraft() async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    try {
      if (!await confirmEditorDraftDeletion(context) || !mounted) return;
      await pending.catchError((Object _) {});
      if (draftRevision > 0) {
        await c.repository.discardSchoolDraft(
          draftId,
          expectedRevision: draftRevision,
        );
      }
      dirty = false;
      draftRevision = 0;
      draftStatus = '';
      await c.reload();
      if (mounted) await pop();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (dirty && !canPop) {
          debounce = Timer(const Duration(milliseconds: 400), persist);
        }
      }
    }
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

  Future<void> save({
    bool documents = false,
    bool scan = false,
    String? documentTaskId,
  }) async {
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
      final taskIndex = documentTaskId == null
          ? -1
          : r.tasks.indexWhere((t) => t.id == documentTaskId);
      if (documentTaskId != null && taskIndex < 0) {
        throw const DomainError(
          'Bitte die Aufgabe vor dem Hinzufügen eines Dokuments benennen.',
        );
      }
      var documentRecords = <SchoolRecord>[r];
      if (r.revision == 0 && r.kind == SchoolKind.homework) {
        documentRecords = await c.repository.saveSchoolGroup(
          r,
          recipients.toList(),
          draftId,
          draftRevision: draftRevision,
        );
        await c.reload();
      } else {
        await c.saveRecord(r, draftId: draftId, draftRevision: draftRevision);
      }
      if (mounted) {
        final host = Navigator.of(context).context;
        await pop();
        if ((documents || scan) && host.mounted) {
          final scope = schoolScanContext(
            c,
            documentRecords,
            taskIds: {
              if (taskIndex >= 0)
                for (final record in documentRecords)
                  record.id: record.tasks[taskIndex].id,
            },
          );
          if (scan) {
            await scanAndShow(host, c, scope);
          } else {
            await showContextDocuments(host, c, scope);
          }
        }
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
    final deliveryOptions = Column(
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
              transparentChip(
                ChoiceChip(
                  label: Text(option.value),
                  selected: (f.delivery ?? r.delivery) == option.key,
                  onSelected: (_) =>
                      changeFeedback(f.copyWith(delivery: option.key)),
                ),
              ),
          ],
        ),
      ],
    );
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
        if (widget.focusDelivery && taskId == null) ...[
          deliveryOptions,
          const SizedBox(height: 16),
        ],
        TextFormField(
          key: const ValueKey('homework-comment'),
          initialValue: f.note,
          focusNode: commentFocus,
          autofocus: !widget.focusDelivery,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: taskId == null ? 'Notiz' : 'Kommentar',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => changeFeedback(f.copyWith(note: v)),
        ),
        const SizedBox(height: 16),
        if (taskId == null && !widget.focusDelivery)
          optionalSection(
            'Abgabe & Zeitpunkt',
            deliveryOpen,
            (v) => deliveryOpen = v,
            deliveryOptions,
          ),
        if (taskId != null || deliveryOpen || widget.focusDelivery)
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

  Widget attachments({
    String? forTask,
    bool showActions = true,
    bool showFiles = true,
  }) {
    final current = c.records.where((v) => v.id == r.id).firstOrNull;
    final saveFirst =
        current == null ||
        forTask != null && !current.tasks.any((t) => t.id == forTask);
    final scope = schoolScanContext(
      c,
      [r],
      taskIds: {r.id: ?forTask},
      includeTasks: false,
    );
    return DocumentAttachmentSection(
      key: ValueKey(
        'editor-${showActions ? 'attachments' : 'files'}-${forTask ?? 'entry'}',
      ),
      controller: c,
      scope: scope,
      saveFirst: saveFirst,
      compact: forTask != null,
      showActions: showActions,
      showFiles: showFiles,
      onScan: () => saveFirst
          ? save(scan: true, documentTaskId: forTask)
          : navigateEntry(() => scanAndShow(context, c, scope)),
      onDocuments: () => saveFirst
          ? save(documents: true, documentTaskId: forTask)
          : navigateEntry(() => showContextDocuments(context, c, scope)),
    );
  }

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
        onChanged: (v) => setState(() => change(v)),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
          onChanged: (value) => setState(() {
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
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Beobachtung',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
        tooltip: r.revision == 0
            ? 'Speichern und Dokumente öffnen'
            : 'Dokumente',
        icon: const Icon(Icons.folder_open_outlined),
        onPressed: busy
            ? null
            : () => r.revision == 0
                  ? save(documents: true)
                  : navigateEntry(
                      () => showContextDocuments(
                        context,
                        c,
                        schoolScanContext(c, [
                          c.records.where((v) => v.id == r.id).firstOrNull ?? r,
                        ]),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final title = mode == 'review'
        ? 'Ziel überprüfen'
        : mode == 'comment'
        ? (widget.focusDelivery
              ? 'Abgabe prüfen'
              : taskId == null
              ? 'Notiz & Verlauf'
              : 'Kommentar')
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
                            onChanged: (value) => setState(() {
                              final tones = observationTones.keys.toList();
                              selectedTone =
                                  tones[(tones.indexOf(selectedTone) +
                                          (value ? -1 : 1))
                                      .clamp(0, tones.length - 1)];
                            }),
                            child: observation(),
                          ),
                  const SizedBox(height: 12),
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
                      ? widget.focusDelivery
                            ? 'Abgabe speichern'
                            : taskId == null
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
