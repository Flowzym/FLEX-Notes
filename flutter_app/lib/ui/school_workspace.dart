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
    required this.onKind,
  });
  final NotebookController controller;
  final Pupil pupil;
  final SchoolKind kind;
  final ValueChanged<SchoolKind?> onKind;
  @override
  State<SchoolWorkspace> createState() => _SchoolWorkspaceState();
}

class _SchoolWorkspaceState extends State<SchoolWorkspace> {
  String query = '';
  bool onlyOpen = false;
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Aktuell / Orga'),
              onPressed: () => widget.onKind(null),
            ),
            for (final kind in SchoolKind.values)
              ChoiceChip(
                avatar: FlexIcon(FlexIcon.forKind(kind), size: 20),
                label: Text(kind.label),
                selected: widget.kind == kind,
                onSelected: (_) => widget.onKind(kind),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              widget.kind.label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (!widget.pupil.archived)
              FilledButton.icon(
                onPressed: () => editSchool(
                  context,
                  widget.controller,
                  SchoolRecord.empty(widget.kind, widget.pupil.id),
                ),
                icon: const Icon(Icons.add),
                label: Text(
                  widget.kind == SchoolKind.homework
                      ? 'Hausübung aufgeben'
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
            child: FilterChip(
              label: const Text('Nur offen'),
              selected: onlyOpen,
              onSelected: (v) => setState(() => onlyOpen = v),
            ),
          ),
        const SizedBox(height: 16),
        if (values.isEmpty) const EmptyState('Noch keine passenden Einträge.'),
        for (final r in values)
          SchoolRecordCard(
            key: ValueKey(r.id),
            controller: widget.controller,
            record: r,
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
  });
  final NotebookController controller;
  final SchoolRecord record;
  @override
  State<SchoolRecordCard> createState() => _SchoolRecordCardState();
}

class _SchoolRecordCardState extends State<SchoolRecordCard> {
  bool busy = false;
  SchoolRecord get r => widget.record;
  NotebookController get c => widget.controller;
  Future<void> mutate(SchoolRecord value) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(context, () => c.saveRecord(value));
    if (mounted) setState(() => busy = false);
  }

  Future<void> setTask(HomeworkTask task, TaskState state) async {
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

  @override
  Widget build(BuildContext context) {
    final owner = c.pupils.where((p) => p.id == r.pupilId).firstOrNull;
    final heading = r.kind == SchoolKind.homework
        ? (r.subject.isEmpty ? 'Hausübung' : r.subject)
        : r.title.isEmpty
        ? r.kind.label
        : r.title;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FlexIcon(
                  FlexIcon.forKind(r.kind),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${owner?.name ?? 'Unbekannt'} · ${displayDate(r.observedOn)} ${r.observedTime}',
                      ),
                    ],
                  ),
                ),
                if (!r.deleted)
                  IconButton(
                    tooltip: 'Eintrag bearbeiten',
                    onPressed: busy ? null : () => editSchool(context, c, r),
                    icon: const Icon(Icons.edit),
                  ),
              ],
            ),
            if (r.kind == SchoolKind.homework) ...[
              if (r.dueDate != null) Text('Fällig: ${displayDate(r.dueDate)}'),
              for (final task in r.tasks)
                Padding(
                  padding: EdgeInsets.only(
                    left: task.parentId == null ? 0 : 16,
                    top: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.text,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            key: ValueKey('comment-${task.id}'),
                            tooltip: 'Kommentar zu ${task.text}',
                            onPressed: busy || r.deleted
                                ? null
                                : () => editSchool(
                                    context,
                                    c,
                                    r,
                                    mode: 'comment',
                                    taskId: task.id,
                                  ),
                            icon: const Icon(Icons.chat_bubble),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final state in TaskState.values)
                            ChoiceChip(
                              key: ValueKey('status-${task.id}-${state.name}'),
                              showCheckmark: false,
                              label: Text(state.label),
                              selected: r.taskState(task) == state,
                              onSelected: busy || r.deleted
                                  ? null
                                  : (_) => setTask(task, state),
                            ),
                        ],
                      ),
                      if (r.liveFeedback
                          .where(
                            (f) => f.taskId == task.id && f.note.isNotEmpty,
                          )
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            r.liveFeedback
                                .lastWhere(
                                  (f) =>
                                      f.taskId == task.id && f.note.isNotEmpty,
                                )
                                .note,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (!r.deleted)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => editSchool(context, c, r, mode: 'comment'),
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('Notiz & Abgabe'),
                  ),
                ),
              Text(
                'Abgabe: ${const {'unknown': 'Nicht überprüft', 'submitted': 'Vorgelegt', 'missing': 'Nicht vorgelegt', 'absent': 'Abwesend'}[r.delivery]}',
              ),
              if (r.feedback.isNotEmpty)
                ExpansionTile(
                  key: PageStorageKey('feedback-${r.id}'),
                  title: Text('Rückmeldungsverlauf · ${r.liveFeedback.length}'),
                  children: [
                    for (final f in r.liveFeedback.reversed)
                      ListTile(
                        title: Text(
                          [
                            f.taskText,
                            f.state?.label ?? '',
                            f.note,
                          ].where((v) => v.isNotEmpty).join(' · '),
                        ),
                        subtitle: Text(
                          '${displayDate(f.observedOn)} ${f.observedTime}',
                        ),
                        trailing: r.deleted
                            ? null
                            : PopupMenuButton<String>(
                                tooltip: 'Rückmeldung bearbeiten oder löschen',
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    await editSchool(
                                      context,
                                      c,
                                      r,
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
                                    await mutate(
                                      r.patch({
                                        'feedback': r.feedback
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
            ] else ...[
              if (r.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(r.body),
                ),
              Wrap(
                spacing: 6,
                children: [
                  for (final text in r.positive) Chip(label: Text('+ $text')),
                  for (final text in r.negative) Chip(label: Text('− $text')),
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
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
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
                  icon: Icon(r.deleted ? Icons.restore : Icons.delete),
                  label: Text(r.deleted ? 'Wiederherstellen' : 'Papierkorb'),
                ),
                TextButton(
                  onPressed: () => showJournal(context, c, r.id),
                  child: const Text('Änderungen'),
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
        children: [
          for (final row in values)
            ListTile(
              title: Text('Fassung ${row['revision']}'),
              subtitle: Text(displayDate(row['captured_at_utc'] as String)),
            ),
        ],
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
          const Text('Papierkorb · wiederherstellbare Einträge'),
          for (final r in controller.records.where((v) => v.deleted))
            SchoolRecordCard(controller: controller, record: r),
          if (!controller.records.any((v) => v.deleted))
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
              Card(
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
  Pupil pupil,
) async {
  var query = '';
  SchoolKind? kind;
  String? from, to;
  final selection = <String>{};
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final records =
            c.records
                .where(
                  (r) =>
                      r.pupilId == pupil.id &&
                      !r.deleted &&
                      (kind == null || r.kind == kind) &&
                      (from == null || r.observedOn.compareTo(from!) >= 0) &&
                      (to == null || r.observedOn.compareTo(to!) <= 0) &&
                      r.searchText.toLowerCase().contains(query.toLowerCase()),
                )
                .toList()
              ..sort((a, b) => a.observedOn.compareTo(b.observedOn));
        return FlexModal(
          title: Text('Gesprächsvorbereitung · ${pupil.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Suchen'),
                onChanged: (v) => update(() => query = v),
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Alle'),
                    selected: kind == null,
                    onSelected: (_) => update(() => kind = null),
                  ),
                  for (final k in SchoolKind.values)
                    ChoiceChip(
                      label: Text(k.label),
                      selected: kind == k,
                      onSelected: (_) => update(() => kind = k),
                    ),
                  TextButton(
                    onPressed: () async {
                      final d = await pickFlexDate(
                        context,
                        date: from ?? dateOnly(DateTime.now()),
                        allowTime: false,
                      );
                      if (d != null) update(() => from = d.$1);
                    },
                    child: Text('Von: ${displayDate(from)}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await pickFlexDate(
                        context,
                        date: to ?? dateOnly(DateTime.now()),
                        allowTime: false,
                      );
                      if (d != null) update(() => to = d.$1);
                    },
                    child: Text('Bis: ${displayDate(to)}'),
                  ),
                ],
              ),
              for (final r in records)
                CheckboxListTile(
                  title: Text(r.title.isEmpty ? r.kind.label : r.title),
                  subtitle: Text('${displayDate(r.observedOn)} · ${r.body}'),
                  value: selection.contains(r.id),
                  onChanged: (v) => update(() {
                    if (v == true) {
                      selection.add(r.id);
                    } else {
                      selection.remove(r.id);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
            FilledButton(
              onPressed: selection.isEmpty
                  ? null
                  : () async {
                      final selected = records.where(
                        (r) => selection.contains(r.id),
                      );
                      final text =
                          'Gesprächsvorbereitung – ${pupil.name}\n\n${selected.map((r) => '${displayDate(r.observedOn)} · ${r.kind.label}\n${r.searchText}').join('\n\n')}\n\nNächste Schritte\n';
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gesprächsunterlage kopiert'),
                          ),
                        );
                      }
                    },
              child: const Text('Auswahl kopieren'),
            ),
          ],
        );
      },
    ),
  );
}
