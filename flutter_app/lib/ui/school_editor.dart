import 'work_assignment_sources.dart';
import 'document_attachments.dart';
import 'observation_tone_colors.dart';
import 'compact_switch.dart';
import 'option_bar.dart';
import 'draft_actions.dart';
import 'option_swipe.dart';
import 'pupil_history.dart';
import 'entry_navigation.dart';
import 'person_assignment.dart';

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

part 'school_editor_forms.dart';

part 'school_observation_view.dart';

part 'school_editor_view.dart';

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
      goalOpen = false,
      supportOpen = false,
      contextOpen = false,
      catalogBusy = true;
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

  bool get hasDraftAttachments {
    final scope = schoolDraftScanContext(c, draftId, r, includeTasks: true);
    return c.classroom.any(scope.matchesMaterial) ||
        c.dialogDrafts.any(scope.matchesDraft);
  }

  Future<bool> persist({bool force = false}) async {
    final snapshot = r,
        targets = recipients.toList(),
        generation = editGeneration;
    if (dirty || force || draftRevision > 0) {
      pending = pending.catchError((Object _) {}).then((_) async {
        if (!force &&
            signature(snapshot, targets) == baseline &&
            !hasDraftAttachments) {
          if (draftRevision > 0) {
            await c.repository.discardSchoolDraft(
              draftId,
              expectedRevision: draftRevision,
            );
            draftRevision = 0;
          }
        } else if (dirty || force && draftRevision == 0) {
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

  Future<void> save() async {
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
      if (mounted) await pop();
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

  void updateEditor(VoidCallback work) => setState(work);
  @override
  Widget build(BuildContext context) => editorView(context);
}
