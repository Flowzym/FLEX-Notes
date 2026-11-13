import 'document_attachments.dart';
import 'compact_switch.dart';
import 'draft_actions.dart';
import 'surfaces.dart';
import 'tag_text_field.dart';
import 'observation_tone_colors.dart';
import 'homework_task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/notebook_controller.dart';
import '../domain/models.dart';
import '../domain/drafts.dart';
import '../domain/school.dart';
import '../domain/observation_catalog.dart';
import 'common.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'school_editor.dart';
import 'school_workspace.dart';
import 'entry_navigation.dart';

typedef DraftBody = Widget Function(BuildContext, Json, ValueChanged<Json>);
typedef DraftNavigation =
    Widget Function(
      Widget content,
      Future<void> Function(ValueChanged<DialogDraft>) navigate,
    );

class ProtectedDialog extends StatefulWidget {
  const ProtectedDialog({
    super.key,
    required this.controller,
    required this.type,
    required this.ownerId,
    required this.title,
    required this.initial,
    required this.body,
    required this.save,
    this.draft,
    this.accept = 'Speichern',
    this.maxWidth = 760,
    this.navigation,
    this.entryOwner,
  });
  final NotebookController controller;
  final String type, ownerId, title, accept;
  final Json initial;
  final DraftBody body;
  final Future<void> Function(Json, DialogDraft) save;
  final DialogDraft? draft;
  final double maxWidth;
  final DraftNavigation? navigation;
  final String? entryOwner;
  static ProtectedDialogState of(BuildContext context) =>
      context.findAncestorStateOfType<ProtectedDialogState>()!;

  @override
  State<ProtectedDialog> createState() => ProtectedDialogState();
}

class ProtectedDialogState extends State<ProtectedDialog>
    with WidgetsBindingObserver {
  late DraftBuffer buffer;
  late Json data;
  bool busy = false, canPop = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    data = widget.draft?.data ?? widget.initial;
    buffer = DraftBuffer(
      widget.controller.repository,
      type: widget.type,
      ownerId: widget.ownerId,
      data: data,
      baseline: dialogDraftSignature(widget.type, widget.initial),
      onPersisted: widget.controller.reload,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
      initial: widget.draft,
      retainEmpty: (draft) {
        if (!{'bulk', 'classroom'}.contains(draft.type)) return false;
        final scope = draft.type == 'bulk'
            ? bulkDraftScanContext(draft.id)
            : classroomDraftScanContext(draft);
        return widget.controller.classroom.any(scope.matchesMaterial) ||
            widget.controller.dialogDrafts.any(scope.matchesDraft);
      },
    );
  }

  void change(Json next) {
    if (busy) return;
    setState(() => data = {...data, ...next});
    buffer.change(data);
  }

  @override
  void dispose() {
    buffer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !busy) {
      buffer.flush().catchError((Object e) {
        buffer.error = e;
      });
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
    buffer.timer?.cancel();
    try {
      if (!await confirmEditorDraftDeletion(context) || !mounted) {
        await buffer.flush();
        return;
      }
      await buffer.discard();
      await widget.controller.reload();
      if (mounted) await pop();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> close() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await buffer.flush();
      await widget.controller.reload();
      if (mounted) await pop();
    } catch (e) {
      if (mounted &&
          await unsavedDraft(context, widget.controller.repository, {
            'type': 'dialog',
            'draft': buffer.draft.toJson(),
          }) &&
          mounted) {
        try {
          await widget.controller.repository.discardDialogDraft(
            buffer.draft.id,
            buffer.draft.revision,
          );
          await pop();
        } catch (discardError) {
          if (mounted) setState(() => error = friendlyError(discardError));
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Persist the owner before capture/import can leave the app. Keep attachment
  /// links on the draft until its record is successfully published.
  Future<void> withSavedDraft(Future<void> Function(DialogDraft) action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await buffer.flush(force: true);
      if (!mounted) return;
      await action(buffer.draft);
      await widget.controller.reload();
      if (mounted) {
        buffer.change(data);
        await buffer.flush();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openAttachment(bool scan, {String? taskId}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await buffer.flush(force: true);
      if (!mounted) return;
      final scope = bulkDraftScanContext(buffer.draft.id, taskId: taskId);
      if (scan) {
        await scanAndShow(context, widget.controller, scope);
      } else {
        await showContextDocuments(context, widget.controller, scope);
      }
      if (mounted) {
        buffer.change(data);
        await buffer.flush();
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
    try {
      await buffer.flush();
      await widget.save(data, buffer.draft);
      await widget.controller.reload();
      if (mounted) {
        await pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> navigate(ValueChanged<DialogDraft> changePage) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await buffer.flush();
      await widget.controller.reload();
      if (mounted) changePage(buffer.draft);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
          maxWidth: widget.maxWidth,
          title: Text(widget.title),
          headerContent: widget.entryOwner == null
              ? null
              : EntryPageHeader(
                  owner: widget.entryOwner!,
                  title: widget.title,
                  onClose: busy ? null : close,
                  titleActions: [
                    if (buffer.hasContent || buffer.draft.revision > 0)
                      EditorDraftDeleteButton(
                        onPressed: busy ? null : deleteDraft,
                      ),
                  ],
                ),
          headerActions: [
            if (buffer.hasContent || buffer.draft.revision > 0)
              EditorDraftDeleteButton(onPressed: busy ? null : deleteDraft),
          ],
          onClose: busy ? null : close,
          content: AbsorbPointer(
            absorbing: busy,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.navigation case final navigation?)
                  navigation(widget.body(context, data, change), navigate)
                else
                  widget.body(context, data, change),
                DraftStatus(buffer: buffer),
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
            TextButton(
              onPressed: busy ? null : close,
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(widget.accept),
            ),
          ],
        ),
      ),
    ),
  );
}

void appendCatalogOption(
  Json data,
  String tone,
  List<String> list,
  ValueChanged<Json> change,
) {
  final text = (data['new-$tone'] as String? ?? '').trim();
  final error = text.isEmpty
      ? 'Bitte einen Text für den neuen Eintrag eingeben.'
      : list.length >= 200
      ? 'Diese Liste enthält bereits 200 Einträge.'
      : list.any((s) => s.trim().toLowerCase() == text.toLowerCase())
      ? 'Dieser Eintrag steht bereits in der Liste.'
      : '';
  if (error.isNotEmpty) {
    change({'addError': error});
  } else {
    change({
      tone: [...list, text],
      'new-$tone': '',
      'append-$tone': (data['append-$tone'] as int? ?? 0) + 1,
      'addError': '',
    });
  }
}

Future<void> showCatalog(
  BuildContext context,
  NotebookController c,
  String kind, {
  DialogDraft? draft,
}) async {
  final initial = <String, dynamic>{
    'tone': c.appearance.defaultObservationTone,
    'kind': kind,
  };
  for (final tone in observationTones.keys) {
    initial[tone] = (await c.repository.observationCatalog(
      '$kind-$tone',
    )).options.toList();
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProtectedDialog(
      controller: c,
      type: 'catalog',
      ownerId: kind,
      draft: draft,
      initial: initial,
      title:
          '${kind == 'social' ? 'Sozialverhalten' : 'Arbeitsverhalten'} · Auswahl',
      accept: 'Änderungen speichern',
      save: (data, saved) => c.repository.saveCatalogs({
        for (final tone in observationTones.keys)
          '$kind-$tone': [
            ...List<String>.from(data[tone] as List? ?? initial[tone] as List),
            if ((data['new-$tone'] as String? ?? '').trim().isNotEmpty)
              (data['new-$tone'] as String).trim(),
          ],
      }, saved),
      body: (ctx, data, change) {
        final tone = data['tone'] as String,
            list = List<String>.from(
              data[data['tone']] as List? ?? initial[data['tone']] as List,
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Diese Auswahllisten gelten für alle Schüler. Bereits gespeicherte Einträge behalten ihren ursprünglichen Text.',
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final t in observationTones.keys)
                  transparentChip(
                    ChoiceChip(
                      label: Text(
                        '${observationSigns[t]} ${observationTones[t]}',
                      ),
                      selected: tone == t,
                      onSelected: (_) => change({'tone': t}),
                    ),
                  ),
              ],
            ),
            if (list.isEmpty)
              const Text('Die Liste ist leer. Füge unten einen Eintrag hinzu.'),
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('$tone-$i-${list.length}'),
                        initialValue: list[i],
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Beobachtung',
                          counterText: '',
                        ),
                        onChanged: (v) {
                          final next = [...list];
                          next[i] = v;
                          change({tone: next});
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Auswahleintrag entfernen',
                      onPressed: () {
                        final next = [...list]..removeAt(i);
                        change({tone: next});
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('new-$tone-${data['append-$tone'] ?? 0}'),
              initialValue: data['new-$tone'] as String? ?? '',
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Neuer Auswahleintrag',
                hintText: 'Eigener Text …',
                counterText: '',
              ),
              onChanged: (v) => change({'new-$tone': v, 'addError': ''}),
              onFieldSubmitted: (_) =>
                  appendCatalogOption(data, tone, list, change),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => appendCatalogOption(data, tone, list, change),
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
            ),
            if ((data['addError'] as String? ?? '').isNotEmpty)
              Text(
                data['addError'] as String,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            const Text(
              'Die Änderungen werden erst mit „Änderungen speichern“ übernommen.',
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showSituation(
  BuildContext context,
  NotebookController c,
  String id, {
  DialogDraft? draft,
}) async {
  final source = await c.repository.situation(id);
  if (source == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProtectedDialog(
      controller: c,
      type: 'context',
      maxWidth: 1000,
      ownerId: id,
      initial: source,
      draft: draft,
      title: 'Gemeinsame Situation',
      accept: 'Kontext speichern',
      save: (data, saved) => c.repository.saveSituation(
        id,
        data['revision'] as int,
        data['text'] as String,
        saved,
      ),
      body: (ctx, data, change) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            c.pupils
                .where((p) => (data['participantIds'] as List).contains(p.id))
                .map((p) => p.name)
                .join(', '),
          ),
          TextFormField(
            initialValue: data['text'] as String,
            minLines: 3,
            maxLines: 10,
            maxLength: 12000,
            decoration: const InputDecoration(
              labelText: 'Gemeinsamer Ablauf',
              hintText: 'Kontext …',
              counterText: '',
            ),
            onChanged: (v) => change({'text': v}),
          ),
          for (final r in c.records.where(
            (r) => !r.deleted && r.situationId == id,
          ))
            ListTile(
              title: Text(c.pupils.firstWhere((p) => p.id == r.pupilId).name),
              subtitle: Text(
                [
                  r.body,
                  ...r.positive,
                  ...r.neutral,
                  ...r.negative,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Beobachtung bearbeiten',
                icon: const Icon(Icons.edit),
                onPressed: () => editSchool(ctx, c, r),
              ),
            ),
        ],
      ),
    ),
  );
}

Future<void> showBulk(
  BuildContext context,
  NotebookController c, {
  DialogDraft? draft,
  String initialKind = 'social',
  String initialSubject = '',
}) async {
  final editorKey = GlobalKey<ProtectedDialogState>();
  final catalogs = <String, List<String>>{};
  for (final key in observationDefaults.keys) {
    catalogs[key] = (await c.repository.observationCatalog(key)).options;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProtectedDialog(
      key: editorKey,
      controller: c,
      type: 'bulk',
      maxWidth: 640,
      ownerId: 'group',
      draft: draft,
      title: 'Für mehrere erfassen',
      accept: 'Für ausgewählte Schüler speichern',
      initial: {
        'kind': initialKind,
        'recipients': <String>[],
        'context': '',
        'subject': initialSubject,
        'body': '',
        'individual': <String, dynamic>{},
        'observedOn': dateOnly(DateTime.now()),
        'observedTime': '',
        'needsCompletion': false,
        'tasks': [HomeworkTask(id: newId(), text: '').toJson()],
      },
      save: (data, saved) => c.repository.saveBulkDialog(
        DialogDraft(
          id: saved.id,
          type: saved.type,
          ownerId: saved.ownerId,
          data: data,
          updatedAtUtc: utcNow(),
          revision: saved.revision,
        ),
      ),
      body: (ctx, data, change) {
        final kind = data['kind'] as String,
            ids = List<String>.from(data['recipients'] as List);
        final individuals = Json.from(data['individual'] as Map);
        Widget attachments({
          HomeworkTask? task,
          bool showActions = true,
        }) => DocumentAttachmentSection(
          controller: c,
          scope: bulkDraftScanContext(
            editorKey.currentState!.buffer.draft.id,
            taskId: task?.id,
          ),
          compact: task != null,
          showActions: showActions,
          showFiles: task == null || !showActions,
          onScan: () =>
              editorKey.currentState?.openAttachment(true, taskId: task?.id),
          onDocuments: () =>
              editorKey.currentState?.openAttachment(false, taskId: task?.id),
        );
        Widget text(String key, String label, {int lines = 1}) => TextFormField(
          key: ValueKey('bulk-$kind-$key'),
          initialValue: data[key] as String? ?? '',
          minLines: lines,
          maxLines: 8,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => change({key: v}),
        );
        Future<void> date(String key, {bool time = false}) async {
          final result = await pickFlexDate(
            ctx,
            date: data[key] as String? ?? '',
            time: time ? data['observedTime'] as String : '',
            allowTime: time,
          );
          if (result != null) {
            change({
              key: result.$1.isEmpty && key != 'observedOn' ? null : result.$1,
              if (time) 'observedTime': result.$2,
            });
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Für ${ids.length} Schüler: ${c.pupils.where((p) => ids.contains(p.id)).map((p) => p.name).join(', ')}',
            ),
            PupilTags(
              pupils: c.pupils.where((p) => !p.archived).toList(),
              selected: ids.toSet(),
              onChanged: (v) => change({'recipients': v.toList()}),
            ),
            const Text('Bereich'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in {
                  'social': 'Sozialverhalten',
                  'work': 'Arbeitsverhalten',
                  'homework': 'Hausübung',
                  'orga': 'Organisatorisches',
                }.entries)
                  transparentChip(
                    ChoiceChip(
                      label: Text(option.value),
                      selected: kind == option.key,
                      onSelected: (_) => change({'kind': option.key}),
                    ),
                  ),
              ],
            ),
            if (kind == 'work') ...[
              const Text('Auftrag'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final text
                      in {
                            for (final r in c.records.where(
                              (r) => r.kind == SchoolKind.work && !r.deleted,
                            )) ...[
                              ...r.taskTags,
                              if (r.assignmentFree.isNotEmpty) r.assignmentFree,
                            ],
                          }
                          .where(
                            (t) =>
                                !(data['taskTags'] as List? ?? []).contains(t),
                          )
                          .take(6))
                    transparentChip(
                      ActionChip(
                        label: Text(text),
                        onPressed: () {
                          final tags = [
                            ...data['taskTags'] as List? ?? [],
                            text,
                          ];
                          change({
                            'taskTags': tags,
                            'subject': [
                              ...tags,
                              if ((data['taskFree'] as String? ?? '')
                                  .isNotEmpty)
                                data['taskFree'],
                            ].join(' · '),
                          });
                        },
                      ),
                    ),
                ],
              ),
              TagTextField(
                fieldKey: const ValueKey('bulk-task-free'),
                value: data['taskFree'] as String? ?? '',
                hint: 'Auftrag …',
                minLines: 1,
                tags: [
                  for (final text in List<String>.from(
                    data['taskTags'] as List? ?? [],
                  ))
                    (
                      id: text,
                      label: text,
                      remove: () {
                        final tags = List<String>.from(data['taskTags'] as List)
                          ..remove(text);
                        change({
                          'taskTags': tags,
                          'subject': [
                            ...tags,
                            if ((data['taskFree'] as String? ?? '').isNotEmpty)
                              data['taskFree'],
                          ].join(' · '),
                        });
                      },
                    ),
                ],
                onChanged: (v) => change({
                  'taskFree': v,
                  'subject': [
                    ...data['taskTags'] as List? ?? [],
                    if (v.isNotEmpty) v,
                  ].join(' · '),
                }),
              ),
            ],
            text('otherParticipants', 'Andere Person / weitere Namen'),
            if (kind == 'social' || kind == 'work') ...[
              const Text('Gemeinsamer Ablauf'),
              if (kind == 'social')
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final time in const {
                      'before': 'Vor Unterricht',
                      'during': 'Unterricht',
                      'after': 'Nach Unterricht',
                      'break': 'Pause',
                    }.entries)
                      if (data['situation'] != time.key)
                        transparentChip(
                          ActionChip(
                            label: Text(time.value),
                            onPressed: () => change({'situation': time.key}),
                          ),
                        ),
                  ],
                ),
              TagTextField(
                fieldKey: ValueKey('bulk-$kind-context'),
                value: data['context'] as String? ?? '',
                hint: 'Kontext …',
                tags: [
                  if (kind == 'social' &&
                      (data['situation'] as String? ?? '').isNotEmpty)
                    (
                      id: 'time',
                      label: const {
                        'before': 'Vor Unterricht',
                        'during': 'Unterricht',
                        'after': 'Nach Unterricht',
                        'break': 'Pause',
                      }[data['situation']]!,
                      remove: () => change({'situation': ''}),
                    ),
                ],
                onChanged: (v) => change({'context': v}),
              ),
              for (final pupil in c.pupils.where((p) => ids.contains(p.id)))
                Builder(
                  builder: (ctx) {
                    final individual = Json.from(
                      individuals[pupil.id] as Map? ?? {},
                    );
                    void update(Json values) => change({
                      'individual': {
                        ...individuals,
                        pupil.id: {...individual, ...values},
                      },
                    });
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Beobachtung · ${pupil.name}',
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                          TagTextField(
                            fieldKey: ValueKey('bulk-$kind-${pupil.id}'),
                            value: individual['body'] as String? ?? '',
                            hint: 'Beobachtung …',
                            maxLength: 3000,
                            tagColors: {
                              for (final tone in observationTones.keys)
                                for (final value in List<String>.from(
                                  individual[tone] as List? ?? [],
                                ))
                                  '$tone-$value': observationToneColors[tone]!,
                            },
                            tags: [
                              for (final tone in observationTones.keys)
                                for (final value in List<String>.from(
                                  individual[tone] as List? ?? [],
                                ))
                                  (
                                    id: '$tone-$value',
                                    label: '${observationSigns[tone]} $value',
                                    remove: () => update({
                                      tone: List<String>.from(
                                        individual[tone] as List,
                                      )..remove(value),
                                    }),
                                  ),
                            ],
                            onChanged: (v) => update({'body': v}),
                          ),
                          for (final tone in observationTones.keys)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final option
                                    in catalogs['$kind-$tone']!.where(
                                      (v) => !(individual[tone] as List? ?? [])
                                          .contains(v),
                                    ))
                                  transparentChip(
                                    FilterChip(
                                      label: Text(
                                        '${observationSigns[tone]} $option',
                                      ),
                                      selected:
                                          (individual[tone] as List? ?? [])
                                              .contains(option),
                                      onSelected: (v) {
                                        final next = List<String>.from(
                                          individual[tone] as List? ?? [],
                                        );
                                        v
                                            ? next.add(option)
                                            : next.remove(option);
                                        update({tone: next});
                                      },
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
            if (kind == 'homework') ...[
              HomeworkTaskEditor(
                attachmentActionsBuilder: (task) => attachments(task: task),
                attachmentBuilder: (task) =>
                    attachments(task: task, showActions: false),
                tasks: (data['tasks'] as List)
                    .map((v) => HomeworkTask.fromJson(Json.from(v as Map)))
                    .toList(),
                onChanged: (tasks) =>
                    change({'tasks': tasks.map((t) => t.toJson()).toList()}),
              ),
              text('subject', 'Fach · optional'),
            ],
            if (kind == 'orga') ...[
              text('body', 'Eigene Notiz', lines: 4),
              CompactSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Als Aufgabe'),
                value: data['isTask'] == true,
                onChanged: (v) => change({'isTask': v}),
              ),
            ],
            if (kind == 'orga') ...[
              CompactSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Erinnern'),
                value: data['reminderOpen'] == true,
                onChanged: (v) => change({'reminderOpen': v}),
              ),
              if (data['reminderOpen'] == true) ...[
                TextButton(
                  onPressed: () async {
                    final result = await pickFlexDate(
                      ctx,
                      date: data['reminderDate'] as String? ?? '',
                      time: data['reminderTime'] as String? ?? '',
                    );
                    if (result != null) {
                      change({
                        'reminderDate': result.$1,
                        'reminderTime': result.$2,
                      });
                    }
                  },
                  child: Text(
                    'Erinnern am: ${displayDate(data['reminderDate'] as String?)} ${data['reminderTime'] ?? ''}',
                  ),
                ),
                text('reminderText', 'Erinnerungstext · optional'),
                const Text('Anzeige in der App'),
              ],
            ],
            if (kind == 'homework' || kind == 'orga' && data['isTask'] == true)
              TextButton(
                onPressed: () => date('dueDate'),
                child: Text(
                  'Fällig am · optional: ${displayDate(data['dueDate'] as String?)}',
                ),
              ),
            TextButton(
              onPressed: () => date('observedOn', time: true),
              child: Text(
                'Beobachtet am ${displayDate(data['observedOn'] as String)} ${data['observedTime']}',
              ),
            ),
            CompactSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Später ergänzen'),
              value: data['needsCompletion'] == true,
              onChanged: (v) => change({'needsCompletion': v}),
            ),
            const Text(
              'Individuelle Einträge · gemeinsamer Kontext',
              style: TextStyle(fontSize: 12),
            ),
            attachments(),
          ],
        );
      },
    ),
  );
}
