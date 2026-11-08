import 'document_attachments.dart';
import 'collapsible_search.dart';
import '../domain/document_scanner.dart';
import '../services/brief_pdf.dart';
import 'compact_switch.dart';
import 'homework_record_view.dart';
import 'pupil_history.dart';
import 'reminder_actions.dart';
import 'draft_buffer.dart';
import 'surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import 'common.dart';
import 'flex_icons.dart';
import 'flex_modal.dart';
import 'school_editor.dart';

Future<void> editSchool(
  BuildContext context,
  NotebookController c,
  SchoolRecord r, {
  SchoolDraft? draft,
  String mode = 'entry',
  String? taskId,
  String? feedbackId,
  bool focusDelivery = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SchoolEditor(
      controller: c,
      record: r,
      draft: draft,
      mode: mode,
      taskId: taskId,
      feedbackId: feedbackId,
      focusDelivery: focusDelivery,
    ),
  );
  await c.reload();
}

class SchoolWorkspace extends StatefulWidget {
  const SchoolWorkspace({
    super.key,
    required this.controller,
    required this.pupil,
    required this.kind,
  });
  final NotebookController controller;
  final Pupil pupil;
  final SchoolKind kind;
  @override
  State<SchoolWorkspace> createState() => _SchoolWorkspaceState();
}

class _SchoolWorkspaceState extends State<SchoolWorkspace> {
  String query = '';
  bool onlyOpen = false;
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values =
        widget.controller.records
            .where(
              (r) =>
                  r.pupilId == widget.pupil.id &&
                  r.kind == widget.kind &&
                  !r.deleted &&
                  (!onlyOpen || r.pending) &&
                  r.searchText.toLowerCase().contains(query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => '${b.observedOn} ${b.observedTime}'.compareTo(
              '${a.observedOn} ${a.observedTime}',
            ),
          );
    final grouped = [
      SchoolKind.goal,
      SchoolKind.homework,
    ].contains(widget.kind);
    if (grouped) {
      values.sort(
        (a, b) =>
            (a.kind == SchoolKind.goal
                    ? a.nextReviewDate ?? '9999'
                    : a.dueDate ?? '9999')
                .compareTo(
                  b.kind == SchoolKind.goal
                      ? b.nextReviewDate ?? '9999'
                      : b.dueDate ?? '9999',
                ),
      );
    }
    final open = values.where((r) => r.pending).toList(),
        closed = values.where((r) => !r.pending).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (widget.kind == SchoolKind.homework) ...[
          CollapsibleSearch(
            controller: search,
            onChanged: (value) => setState(() => query = value),
            label: 'Hausübungen durchsuchen',
            fieldKey: const ValueKey('homework-search-field'),
            buttonKey: const ValueKey('homework-search'),
            iconOnly: true,
            leading: Align(
              alignment: Alignment.centerLeft,
              child: transparentChip(
                FilterChip(
                  label: Text(
                    onlyOpen ? 'Nur offen · ${open.length}' : 'Nur offen',
                  ),
                  selected: onlyOpen,
                  onSelected: (value) => setState(() => onlyOpen = value),
                ),
              ),
            ),
            actions: [
              if (!widget.pupil.archived)
                IconButton(
                  tooltip: 'Hausübung hinzufügen',
                  onPressed: () => editSchool(
                    context,
                    widget.controller,
                    SchoolRecord.empty(SchoolKind.homework, widget.pupil.id),
                  ),
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ] else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                grouped
                    ? widget.kind == SchoolKind.goal
                          ? 'In Arbeit ${open.length}'
                          : open.isEmpty
                          ? 'Alles erledigt'
                          : '${open.length} offen'
                    : '${values.length} ${values.length == 1 ? 'Eintrag' : 'Einträge'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!widget.pupil.archived)
                FilledButton(
                  onPressed: () => editSchool(
                    context,
                    widget.controller,
                    SchoolRecord.empty(widget.kind, widget.pupil.id),
                  ),
                  child: Text(
                    widget.kind == SchoolKind.homework
                        ? '+ Hausübung'
                        : widget.kind == SchoolKind.goal
                        ? '+ Neues Ziel'
                        : 'Eintrag anlegen',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Einträge durchsuchen',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          if ([SchoolKind.homework, SchoolKind.goal].contains(widget.kind))
            Align(
              alignment: Alignment.centerLeft,
              child: transparentChip(
                FilterChip(
                  label: const Text('Nur offen'),
                  selected: onlyOpen,
                  onSelected: (v) => setState(() => onlyOpen = v),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (values.isEmpty)
          EmptyState(
            widget.kind == SchoolKind.goal
                ? 'Noch kein Ziel vereinbart.\nHalte fest, was als Nächstes gelingen soll.'
                : widget.kind == SchoolKind.homework
                ? query.isNotEmpty || onlyOpen
                      ? 'Keine passenden Hausübungen.'
                      : 'Noch keine Hausübung.\nMit + legst du eine Aufgabenliste an.'
                : 'Noch keine passenden Einträge.',
          ),
        for (final r in grouped ? open : values)
          SchoolRecordCard(
            key: ValueKey(r.id),
            controller: widget.controller,
            record: r,
          ),
        if (grouped && closed.isNotEmpty)
          ExpansionTile(
            title: Text(
              widget.kind == SchoolKind.goal
                  ? 'Abgeschlossene Ziele ${closed.length}'
                  : 'Erledigt (${closed.length})',
            ),
            children: [
              for (final r in closed)
                SchoolRecordCard(
                  key: ValueKey(r.id),
                  controller: widget.controller,
                  record: r,
                ),
            ],
          ),
      ],
    );
  }
}

class SchoolRecordCard extends StatefulWidget {
  const SchoolRecordCard({
    super.key,
    required this.controller,
    required this.record,
    this.standalone = false,
  });
  final NotebookController controller;
  final SchoolRecord record;
  final bool standalone;
  @override
  State<SchoolRecordCard> createState() => _SchoolRecordCardState();
}

class _SchoolRecordCardState extends State<SchoolRecordCard> {
  bool busy = false, homeworkExpanded = true;
  String? saveError;
  SchoolRecord? retryValue;
  SchoolRecord get r => widget.record;
  NotebookController get c => widget.controller;
  Future<void> mutate(SchoolRecord value) async {
    if (busy) return;
    setState(() {
      busy = true;
      saveError = null;
    });
    try {
      await c.saveRecord(value);
      retryValue = null;
    } catch (e) {
      if (mounted) {
        setState(() {
          saveError = friendlyError(e);
          retryValue = value;
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> setTask(HomeworkTask task, TaskState state) async {
    if (busy || r.taskState(task) == state) return;
    final now = DateTime.now();
    final f = SchoolFeedback(
      id: newId(),
      observedOn: dateOnly(now),
      observedTime:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      createdAtUtc: utcNow(),
      taskId: task.id,
      taskText: task.text,
      state: state,
    );
    final future = r.liveFeedback.where(
      (v) =>
          v.taskId == task.id &&
          v.state != null &&
          v.sortKey.compareTo(f.sortKey) > 0,
    );
    if (future.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => FlexModal(
          title: const Text('Spätere Rückmeldung vorhanden'),
          content: const Text(
            'Für diese Aufgabe gibt es bereits einen später datierten Stand. Bitte diese Rückmeldung im Verlauf bearbeiten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
      return;
    }
    await mutate(
      r.patch({
        'feedback': [...r.feedback.map((f) => f.toJson()), f.toJson()],
      }),
    );
  }

  Widget homeworkView(BuildContext context) => HomeworkRecordView(
    controller: c,
    record: r,
    expanded: homeworkExpanded,
    standalone: widget.standalone,
    busy: busy,
    onExpand: () => setState(() => homeworkExpanded = !homeworkExpanded),
    onEdit: () => editSchool(context, c, r),
    onTaskState: setTask,
    onDelivery: () =>
        editSchool(context, c, r, mode: 'comment', focusDelivery: true),
    onComment: (taskId) =>
        editSchool(context, c, r, mode: 'comment', taskId: taskId),
    onReminder: () => showReminderActions(
      context,
      c,
      'school:${r.id}',
      r.title.isEmpty ? 'Hausübung' : r.title,
    ),
    onHistory: showHomeworkHistory,
    onDelete: () async {
      if (r.deleted ||
          await confirmFlex(
            context,
            'Eintrag in den Papierkorb?',
            'Der Eintrag bleibt wiederherstellbar.',
            accept: 'In den Papierkorb',
          )) {
        await mutate(r.patch({'deleted': !r.deleted}));
      }
    },
    error: saveError == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: busy || retryValue == null
                    ? null
                    : () => mutate(retryValue!),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
  );

  Future<void> showHomeworkHistory() => showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) => AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final current = c.records.where((v) => v.id == r.id).firstOrNull ?? r;
          return FlexModal(
            title: const Text('Verlauf'),
            onClose: () => Navigator.pop(dialogContext),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showJournal(context, c, current.id),
                    icon: const Icon(Icons.history, size: 20),
                    label: const Text('Änderungen'),
                  ),
                ),
                if (saveError != null)
                  Text(
                    saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (current.liveFeedback.isEmpty)
                  const Text('Noch keine Rückmeldungen.'),
                for (final f in current.liveFeedback.reversed)
                  ListTile(
                    key: ValueKey('homework-feedback-${f.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      [
                        f.taskText,
                        f.state?.label ?? '',
                        if (f.delivery != null)
                          'Abgabe: ${homeworkDeliveryLabel(f.delivery!)}',
                        f.note,
                      ].where((v) => v.isNotEmpty).join(' · '),
                    ),
                    subtitle: Text(
                      '${displayDate(f.observedOn)} ${f.observedTime}',
                    ),
                    trailing: current.deleted
                        ? null
                        : PopupMenuButton<String>(
                            enabled: !busy,
                            tooltip: 'Rückmeldung bearbeiten oder löschen',
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await editSchool(
                                  context,
                                  c,
                                  current,
                                  mode: 'comment',
                                  taskId: f.taskId,
                                  feedbackId: f.id,
                                );
                              } else if (await confirmFlex(
                                context,
                                'Rückmeldung löschen?',
                                'Der vorherige Stand wird wieder wirksam.',
                                accept: 'Löschen',
                              )) {
                                final latest = c.records
                                    .where((v) => v.id == current.id)
                                    .firstOrNull;
                                if (latest == null ||
                                    latest.deleted ||
                                    !context.mounted ||
                                    !mounted) {
                                  return;
                                }
                                final saving = mutate(
                                  latest.patch({
                                    'feedback': latest.feedback
                                        .map(
                                          (v) =>
                                              (v.id == f.id
                                                      ? v.copyWith(
                                                          deleted: true,
                                                        )
                                                      : v)
                                                  .toJson(),
                                        )
                                        .toList(),
                                  }),
                                );
                                refresh(() {});
                                await saving;
                                if (context.mounted) refresh(() {});
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Bearbeiten'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Löschen'),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _observationTag(String text) => transparentChip(
    Chip(
      label: Text(text, textAlign: TextAlign.center),
      labelStyle: const TextStyle(
        fontFamily: 'FlexSans',
        fontSize: 12,
        height: 1.25,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (r.kind == SchoolKind.homework) {
      if (widget.standalone) return homeworkView(context);
      return FlexCard(
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: homeworkView(context),
        ),
      );
    }
    final owner = c.pupils.where((p) => p.id == r.pupilId).firstOrNull;
    final heading = r.title.isEmpty ? r.kind.label : r.title;
    return FlexCard(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (saveError != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: busy || retryValue == null
                        ? null
                        : () => mutate(retryValue!),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),

            LayoutBuilder(
              builder: (context, constraints) {
                final icon = FlexIcon(
                  FlexIcon.forKind(r.kind),
                  color: Theme.of(context).colorScheme.primary,
                );
                final headings = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${owner?.name ?? 'Unbekannt'} · ${displayDate(r.observedOn)} ${r.observedTime}'
                          .trim(),
                    ),
                  ],
                );
                final actions = [
                  if (!r.deleted)
                    IconButton(
                      tooltip: 'Eintrag bearbeiten',
                      onPressed: busy ? null : () => editSchool(context, c, r),
                      icon: const Icon(Icons.edit),
                    ),
                ];
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [icon, const Spacer(), ...actions]),
                      headings,
                    ],
                  );
                }
                return Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: headings),
                    ...actions,
                  ],
                );
              },
            ),
            ...[
              if (r.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(r.body),
                ),
              Wrap(
                spacing: 6,
                children: [
                  for (final text in r.positive) _observationTag('+ $text'),
                  for (final text in r.neutral) _observationTag('• $text'),
                  for (final text in r.negative) _observationTag('− $text'),
                ],
              ),
              if (r.context.isNotEmpty) Text('Kontext: ${r.context}'),
              if (r.support.isNotEmpty) Text('Unterstützung: ${r.support}'),
              if (r.goalSnapshot.isNotEmpty)
                Text('Zielbezug: ${r.goalSnapshot}'),
            ],
            if (r.kind == SchoolKind.goal) ...[
              if (r.criterion.isNotEmpty) Text('Kriterium: ${r.criterion}'),
              Text(
                'Stand: ${const {'active': 'Aktiv', 'achieved': 'Erreicht', 'ended': 'Beendet'}[r.goalStatus]}',
              ),
              if (r.dueDate != null)
                Text('Zieltermin: ${displayDate(r.dueDate)}'),
              if (r.nextReviewDate != null)
                Text('Nächste Überprüfung: ${displayDate(r.nextReviewDate)}'),
              if (!r.deleted)
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          final review = GoalReview(
                            id: newId(),
                            decision: r.goalStatus == 'active'
                                ? 'achieved'
                                : 'reopen',
                            observedOn: dateOnly(DateTime.now()),
                          );
                          mutate(
                            r.patch({
                              'goalStatus': r.goalStatus == 'active'
                                  ? 'achieved'
                                  : 'active',
                              'nextReviewDate': null,
                              'reviews': [
                                ...r.reviews.map((r) => r.toJson()),
                                review.toJson(),
                              ],
                            }),
                          );
                        },
                  child: Text(
                    r.goalStatus == 'active' ? 'Erreicht' : 'Wieder öffnen',
                  ),
                ),
              if (!r.deleted)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () => editSchool(context, c, r, mode: 'review'),
                    child: const Text('Ziel überprüfen'),
                  ),
                ),
              if (r.reviews.isNotEmpty)
                ExpansionTile(
                  title: Text('Überprüfungen · ${r.reviews.length}'),
                  children: [
                    for (final review in r.reviews.reversed)
                      ListTile(
                        title: Text(
                          '${const {'continue': 'Fortführen', 'achieved': 'Ziel erreicht', 'ended': 'Beendet', 'reopen': 'Wieder geöffnet'}[review.decision]} · ${displayDate(review.observedOn)}',
                        ),
                        subtitle: Text(
                          [
                            review.note,
                            review.nextStep,
                            if (review.nextReviewDate != null)
                              'Nächste Überprüfung: ${displayDate(review.nextReviewDate)}',
                          ].where((v) => v.isNotEmpty).join('\n'),
                        ),
                      ),
                  ],
                ),
            ],
            if (r.needsCompletion) const Text('Später ergänzen'),
            DocumentAttachmentSection(
              key: ValueKey('record-attachments-${r.id}'),
              controller: c,
              scope: schoolScanContext(c, [r], includeTasks: false),
              readOnly: r.deleted,
              compact: true,
              actions: [
                IconButton(
                  tooltip: r.deleted ? 'Wiederherstellen' : 'Papierkorb',
                  onPressed: busy
                      ? null
                      : () async {
                          if (r.deleted ||
                              await confirmFlex(
                                context,
                                'Eintrag in den Papierkorb?',
                                'Der Eintrag bleibt wiederherstellbar.',
                                accept: 'In den Papierkorb',
                              )) {
                            await mutate(r.patch({'deleted': !r.deleted}));
                          }
                        },
                  icon: Icon(r.deleted ? Icons.restore : Icons.delete_outline),
                ),
                IconButton(
                  tooltip: 'Änderungen',
                  onPressed: () => showJournal(context, c, r.id),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showJournal(
  BuildContext context,
  NotebookController c,
  String id,
) async {
  final values = await c.repository.history(id);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => FlexModal(
      title: const Text('Änderungsverlauf'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final row in values) readableRevision(row)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
}

class SchoolTools extends StatelessWidget {
  const SchoolTools({super.key, required this.controller, required this.mode});
  final NotebookController controller;
  final String mode;
  @override
  Widget build(BuildContext context) {
    if (mode == 'trash') {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Hier abgelegte Einträge sind ausgeblendet und weiterhin in Sicherungen enthalten.',
          ),
          for (final e in controller.trashedEntries)
            FlexCard(
              child: ListTile(
                leading: const FlexIcon(FlexSymbol.orga),
                title: Text(e.title),
                subtitle: Text(controller.owner(e)),
                trailing: TextButton(
                  onPressed: () => guarded(
                    context,
                    () => controller.saveEntry(e.copyWith(deleted: false)),
                  ),
                  child: const Text('Wiederherstellen'),
                ),
              ),
            ),
          for (final r in controller.records.where((v) => v.deleted))
            SchoolRecordCard(controller: controller, record: r),
          if (!controller.records.any((v) => v.deleted) &&
              controller.trashedEntries.isEmpty)
            const EmptyState('Der Papierkorb ist leer.'),
        ],
      );
    }
    return FutureBuilder<List<Json>>(
      future: controller.repository.schoolGroups(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            'Gruppenerfassungen konnten nicht geladen werden.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Gruppenerfassungen'),
            for (final group in snapshot.data!)
              FlexCard(
                child: ListTile(
                  title: Text(displayDate(group['saved_at_utc'] as String)),
                  subtitle: Text(
                    group['undone_at_utc'] == null
                        ? 'Gespeichert'
                        : 'Zurückgenommen · Entwurf verfügbar',
                  ),
                  trailing: group['undone_at_utc'] == null
                      ? TextButton(
                          onPressed: () async {
                            if (await confirmFlex(
                                  context,
                                  'Gruppenerfassung zurücknehmen?',
                                  'Alle unveränderten Einträge werden in den Papierkorb verschoben. Ein neuer Entwurf erhält die Eingaben.',
                                  accept: 'Rückgängig',
                                ) &&
                                context.mounted) {
                              await guarded(context, () async {
                                await controller.repository.undoSchoolGroup(
                                  group['id'] as String,
                                );
                                await controller.reload();
                              });
                            }
                          },
                          child: const Text('Rückgängig'),
                        )
                      : null,
                ),
              ),
            if (snapshot.data!.isEmpty)
              const EmptyState('Noch keine Gruppenerfassungen.'),
          ],
        );
      },
    );
  }
}

Future<void> showBrief(
  BuildContext context,
  NotebookController c,
  Pupil pupil, {
  String? initialFrom,
  String? initialTo,
  Set<String> initialSelection = const {},
}) async {
  String? from = initialFrom;
  String? to = initialTo ?? dateOnly(DateTime.now());
  var names = false;
  var preview = '', error = '';
  final selection = <String>{...initialSelection};
  final areas = <String>{'social', 'work', 'goal', 'homework', 'orga'};
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) {
        bool inRange(String date) =>
            (from == null || date.compareTo(from!) >= 0) &&
            (to == null || date.compareTo(to!) <= 0);
        final entries = <({String id, String date, String label, String text})>[
          for (final r in c.records.where(
            (r) =>
                r.pupilId == pupil.id &&
                !r.deleted &&
                areas.contains(r.kind.name) &&
                inRange(r.observedOn),
          ))
            (
              id: r.id,
              date: r.observedOn,
              label: r.kind.label,
              text: [
                r.title,
                r.subject,
                r.body,
                ...r.positive.map((s) => '+ $s'),
                ...r.neutral.map((s) => '• $s'),
                ...r.negative.map((s) => '− $s'),
                if (r.criterion.isNotEmpty) 'Zielkriterium: ${r.criterion}',
                if (r.support.isNotEmpty)
                  'Reaktion / Unterstützung: ${r.support}',
                if (r.context.isNotEmpty) 'Gemeinsamer Ablauf: ${r.context}',
                if (names && r.participantIds.isNotEmpty)
                  'Beteiligt: ${c.pupils.where((p) => r.participantIds.contains(p.id)).map((p) => p.name).join(', ')}',
                if (names && r.otherParticipants.isNotEmpty)
                  'Weitere Namen: ${r.otherParticipants}',
                for (final task in r.tasks)
                  '${task.text}: ${r.taskState(task).label}',
                ...r.liveFeedback
                    .where((f) => f.note.isNotEmpty)
                    .map((f) => '${displayDate(f.observedOn)} · ${f.note}'),
              ].where((s) => s.isNotEmpty).join('\n'),
            ),
          for (final e in c.entries.where(
            (e) =>
                e.pupilId == pupil.id &&
                areas.contains('orga') &&
                inRange(e.observedOn),
          ))
            (
              id: e.id,
              date: e.observedOn,
              label: 'Orga',
              text: [
                e.body.isEmpty ? e.title : e.body,
                if (e.isTask) e.done ? 'Aufgabe erledigt' : 'Aufgabe offen',
                if (e.dueDate != null) 'Fällig am: ${displayDate(e.dueDate)}',
                if (e.appointmentDate != null)
                  'Termin: ${displayDate(e.appointmentDate)} ${e.appointmentTime}',
                if (e.reminderState == ReminderState.planned)
                  'Erinnern am: ${displayReminder(e)}',
              ].join('\n'),
            ),
        ]..sort((a, b) => a.date.compareTo(b.date));
        Future<void> choose(bool start) async {
          final result = await pickFlexDate(
            ctx,
            date: (start ? from : to) ?? '',
            allowTime: false,
          );
          if (result != null && ctx.mounted) {
            update(() {
              if (start) {
                from = result.$1.isEmpty ? null : result.$1;
              } else {
                to = result.$1.isEmpty ? null : result.$1;
              }
              selection.clear();
              preview = '';
            });
          }
        }

        return FlexModal(
          maxWidth: 1000,
          title: const Text('Gespräch vorbereiten'),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DocumentAttachmentsButton(
                controller: c,
                scope: ScanContext(
                  pupilIds: [pupil.id],
                  title: '${pupil.name} · Gespräch',
                  category: 'protocol',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final area in const {
                    'social': 'Sozial',
                    'work': 'Arbeit',
                    'goal': 'Ziele',
                    'homework': 'Hausübungen',
                    'orga': 'Orga',
                  }.entries)
                    FilterChip(
                      label: Text(area.value),
                      selected: areas.contains(area.key),
                      onSelected: (v) => update(() {
                        if (v) {
                          areas.add(area.key);
                        } else {
                          areas.remove(area.key);
                        }
                        preview = '';
                        selection.clear();
                      }),
                    ),
                ],
              ),
              CompactSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Namen weiterer Beteiligter aufnehmen'),
                value: names,
                onChanged: (v) => update(() {
                  names = v;
                  preview = '';
                }),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => choose(true),
                    child: Text('Von: ${displayDate(from)}'),
                  ),
                  TextButton(
                    onPressed: () => choose(false),
                    child: Text('Bis: ${displayDate(to)}'),
                  ),
                  TextButton(
                    onPressed: () => update(() {
                      selection.addAll(entries.map((e) => e.id));
                      preview = '';
                    }),
                    child: const Text('Alle auswählen'),
                  ),
                  TextButton(
                    onPressed: () => update(() {
                      selection.clear();
                      preview = '';
                    }),
                    child: const Text('Auswahl leeren'),
                  ),
                ],
              ),
              for (final e in entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${displayDate(e.date)} · ${e.label}'),
                  subtitle: Text(e.text),
                  value: selection.contains(e.id),
                  onChanged: (v) => update(() {
                    preview = '';
                    if (v == true) {
                      selection.add(e.id);
                    } else {
                      selection.remove(e.id);
                    }
                  }),
                ),
              if (entries.isEmpty)
                const Text('Keine Einträge in diesem Zeitraum.'),
              FilledButton(
                onPressed: () => update(() {
                  if (selection.isEmpty) {
                    error = 'Bitte mindestens einen Eintrag auswählen.';
                    return;
                  }
                  error = '';
                  preview =
                      'Gesprächsvorbereitung · ${pupil.name}\nZeitraum: ${from == null ? 'Beginn' : displayDate(from)} bis ${to == null ? 'heute' : displayDate(to)}\n\n${entries.where((e) => selection.contains(e.id)).map((e) => '${displayDate(e.date)} · ${e.label}\n${e.text}').join('\n\n')}\n\nNächste Schritte\n';
                }),
                child: const Text('Auswahl zusammenstellen'),
              ),
              if (error.isNotEmpty) Text(error),
              if (preview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SelectableText(preview),
                ),
            ],
          ),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Als PDF sichern'),
              onPressed: preview.isEmpty
                  ? null
                  : () => guarded(ctx, () async {
                      final bytes = await briefPdf(
                        text: preview,
                        regularFont: await rootBundle.load(
                          'assets/fonts/Selawik-Regular.ttf',
                        ),
                        boldFont: await rootBundle.load(
                          'assets/fonts/Selawik-Bold.ttf',
                        ),
                      );
                      await saveBytesFile(
                        'FLEX-Gespraech-${dateOnly(DateTime.now())}.pdf',
                        bytes,
                        mime: 'application/pdf',
                      );
                    }),
            ),
            TextButton(
              onPressed: preview.isEmpty
                  ? null
                  : () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: preview));
                      } catch (_) {
                        if (ctx.mounted) {
                          update(
                            () => error =
                                'Kopieren nicht verfügbar. Bitte als Textdatei sichern.',
                          );
                        }
                      }
                    },
              child: const Text('Text kopieren'),
            ),
            TextButton(
              onPressed: preview.isEmpty
                  ? null
                  : () => guarded(ctx, () async {
                      await saveTextFile(
                        'FLEX-Gespraech-${dateOnly(DateTime.now())}.txt',
                        preview,
                      );
                    }),
              child: const Text('Als Textdatei sichern'),
            ),
          ],
        );
      },
    ),
  );
}
