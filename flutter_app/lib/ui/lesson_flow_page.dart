import 'planning_board.dart';
import 'material_grouping.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/lesson_flow.dart';
import '../domain/teaching_sheet.dart';
import 'teaching_review.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'material_thumbnail.dart';
import 'homework_control.dart';
part 'lesson_phase_editor.dart';
part 'lesson_flow_individual.dart';
part 'lesson_flow_materials.dart';
part 'lesson_flow_sources.dart';
part 'lesson_flow_compare.dart';
part 'lesson_flow_transfer.dart';

class LessonFlowPage extends StatefulWidget {
  const LessonFlowPage({
    super.key,
    required this.controller,
    this.initialDate,
    this.initialTarget,
    this.initialPupilId,
    this.onDateChanged,
    this.onSourceChanged,
    this.openFile,
  });
  final String? initialDate, initialTarget, initialPupilId;
  final ValueChanged<String>? onDateChanged;
  final ValueChanged<(String, String?)>? onSourceChanged;
  final Future<void> Function(ClassroomDocument)? openFile;
  final NotebookController controller;
  @override
  State<LessonFlowPage> createState() => _LessonFlowPageState();
}

class _LessonFlowPageState extends State<LessonFlowPage>
    with AutomaticKeepAliveClientMixin {
  NotebookController get c => widget.controller;
  late String date = widget.initialDate ?? dateOnly(DateTime.now());
  late String? target = widget.initialTarget;
  String? expanded;
  late String? pupilId = widget.initialPupilId;
  late bool individual = pupilId != null;
  final individualSeeds = <String, ClassroomDocument>{};
  bool editing = false, busy = false;
  ClassroomDocument? seed;
  String seedKey = '';
  (String, String?)? lastSource;
  void reportSource(ClassroomDocument flow) {
    final value = (flow.id, flow.map('flow')['sourceId'] as String?);
    if (widget.onSourceChanged == null || lastSource == value) return;
    lastSource = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && lastSource == value) widget.onSourceChanged?.call(value);
    });
  }

  @override
  bool get wantKeepAlive => true;
  List<LessonOccurrence> get lessons => lessonOccurrences(
    c.classroom,
    date,
    date,
  ).where((l) => l.document.isTeachingLesson).toList();
  List<ClassroomDocument> get savedFlows =>
      c.classroom
          .where(
            (d) =>
                !d.deleted &&
                hasLessonFlow(d) &&
                !isFlowTemplate(d) &&
                lessonFlowPupil(d).isEmpty &&
                d.text('date') == date,
          )
          .toList()
        ..sort(
          (a, b) => b.text('updatedAtUtc').compareTo(a.text('updatedAtUtc')),
        );
  LessonOccurrence? get lesson {
    if (target == '') return null;
    if (target != null) {
      return lessons.where((l) => l.target == target).firstOrNull;
    }
    final now = DateTime.now();
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return (date == dateOnly(now)
            ? lessons.where((l) => l.end.compareTo(clock) > 0).firstOrNull
            : null) ??
        lessons.firstOrNull;
  }

  ClassroomDocument get current =>
      pupilId == null ? shared : pupilFlow(pupilId!);

  ClassroomDocument get shared {
    if (target == null && savedFlows.isNotEmpty) {
      final saved =
          savedFlows
              .where((d) => lessonPhases(d).any((p) => p.status == 'active'))
              .firstOrNull ??
          savedFlows.first;
      target = saved.map('flow')['lessonTarget'] as String;
    }
    target ??= lesson?.target ?? '';
    final key =
        '$date|$target|${identityHashCode(c.classroom)}|${identityHashCode(c.pupils)}';
    if (seed == null || seedKey != key) {
      seedKey = key;
      individualSeeds.clear();
      seed = lessonFlowFor(
        c.classroom,
        date,
        lesson: lesson,
        lessonTarget: target,
        pupils: c.pupils,
      );
    }
    return c.classroom
            .where((d) => d.id == seed!.id && !d.deleted)
            .firstOrNull ??
        seed!;
  }

  void updateFlow(VoidCallback update) => setState(update);

  Future<bool> run(Future<void> Function() work) async {
    if (busy) return false;
    setState(() => busy = true);
    final ok = await guarded(context, work);
    if (mounted) setState(() => busy = false);
    return ok;
  }

  Future<void> save(ClassroomDocument value) async {
    await run(() => c.saveClassroom(value));
  }

  Future<void> day([int? step]) async {
    final value = step == null
        ? await pickFlexDate(
            context,
            date: date,
            allowTime: false,
            allowDateClear: false,
            title: 'Unterrichtstag',
          )
        : (dateOnly(schoolDay(date).add(Duration(days: step))), '');
    if (value != null && mounted) {
      setState(() {
        date = value.$1;
        widget.onDateChanged?.call(date);
        target = null;
        expanded = null;
      });
    }
  }

  Future<void> chooseLesson() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => FlexModal(
        title: const Text('Unterricht wählen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Freier Tagesablauf'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final l in lessons)
              ListTile(
                title: Text(l.title),
                subtitle: Text('${l.start}–${l.end}'),
                onTap: () => Navigator.pop(ctx, l.target),
              ),
            for (final saved in savedFlows.where(
              (d) =>
                  d.map('flow')['lessonTarget'] != '' &&
                  !lessons.any(
                    (l) => l.target == d.map('flow')['lessonTarget'],
                  ),
            ))
              ListTile(
                title: Text(saved.title),
                subtitle: const Text('Gespeicherter Ablauf'),
                onTap: () => Navigator.pop(
                  ctx,
                  saved.map('flow')['lessonTarget'] as String,
                ),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        target = chosen;
        expanded = null;
      });
    }
  }

  Future<void> editPhase([LessonPhase? phase]) async {
    final baseline = current;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LessonPhaseEditor(
        controller: c,
        individual: pupilId != null,
        phase: phase ?? LessonPhase(id: newId(), title: ''),
        onSave: (p) => c.saveClassroom(
          withLessonPhases(baseline, [
            for (final old in lessonPhases(baseline))
              if (old.id == p.id) p else old,
            if (phase == null) p,
          ]),
        ),
      ),
    );
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => FlexModal(
          title: Text(title),
          content: Text(message),
          onClose: () => Navigator.pop(ctx, false),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> reorder(LessonPhase p, int delta) async {
    final value = current,
        phases = lessonPhases(value),
        index = phases.indexWhere((v) => v.id == p.id);
    if (index + delta < 0 || index + delta >= phases.length) return;
    phases.removeAt(index);
    phases.insert(index + delta, p);
    await save(withLessonPhases(value, phases));
  }

  Future<void> remove(LessonPhase p) async {
    final value = current;
    if (await confirm(
      'Phase entfernen',
      '„${p.title}“ aus diesem Ablauf entfernen?',
    )) {
      await save(
        withLessonPhases(
          value,
          lessonPhases(value).where((v) => v.id != p.id).toList(),
        ),
      );
    }
  }

  Future<void> templates() async {
    final baseline = current;
    final picked = await showDialog<ClassroomDocument>(
      context: context,
      builder: (ctx) => FlexModal(
        title: const Text('Ablaufvorlagen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('FLEX-Grundablauf'),
              subtitle: const Text(
                'Ankommen · HÜ · Arbeiten · Austausch · Abschluss',
              ),
              onTap: () => Navigator.pop(ctx, lessonFlowFor([], date)),
            ),
            for (final d in c.classroom.where(
              (d) => !d.deleted && isFlowTemplate(d),
            ))
              ListTile(
                title: Text(d.title),
                subtitle: Text('${lessonPhases(d).length} Phasen'),
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Aktuellen Ablauf als Vorlage sichern'),
            onPressed: () {
              Navigator.pop(ctx);
              saveTemplate();
            },
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (await confirm(
      'Vorlage übernehmen',
      'Die Phasen dieses Tages werden durch „${picked.title}“ ersetzt. Die Vorlage selbst bleibt unverändert.',
    )) {
      await save(
        withLessonPhases(
          baseline,
          lessonPhases(picked)
              .map(
                (p) => pupilId == null
                    ? p.fresh()
                    : p.fresh().patch({'pupilIds': <String>[]}),
              )
              .toList(),
        ),
      );
    }
  }

  Future<void> saveTemplate() async {
    final baseline = current;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FlowTitleEditor(
        initial: baseline.title,
        title: 'Als Vorlage sichern',
        onSave: (name) => c.saveClassroom(flowTemplate(baseline, name)),
      ),
    );
  }

  Future<void> rename() async {
    final baseline = current;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FlowTitleEditor(
        initial: baseline.title,
        title: 'Unterrichtsthema',
        onSave: (name) => c.saveClassroom(baseline.patch({'title': name})),
      ),
    );
  }

  Future<void> fromPlan() async {
    final baseline = current;
    final values =
        c.classroom
            .where(
              (d) =>
                  !d.deleted &&
                  d.kind == ClassroomKind.plan &&
                  !hasLessonFlow(d),
            )
            .toList()
          ..sort(
            (a, b) => (planOnDay(b, date) ? 1 : 0).compareTo(
              planOnDay(a, date) ? 1 : 0,
            ),
          );
    final picked = await showDialog<ClassroomDocument>(
      context: context,
      builder: (ctx) => FlexModal(
        title: const Text('Planung übernehmen'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (values.isEmpty)
              const EmptyState('Noch keine Unterrichtsplanung vorhanden.'),
            for (final p in values)
              ListTile(
                title: Text(p.title),
                subtitle: Text(displayDate(p.text('date'))),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      await save(
        withLessonPhases(baseline, [
          ...lessonPhases(baseline),
          LessonPhase(
            id: newId(),
            title: picked.title,
            body: picked.text('note'),
            materialIds: picked.strings('materialIds'),
            pupilIds: pupilId == null ? picked.strings('pupilIds') : const [],
          ),
        ]),
      );
    }
  }

  Future<void> carry() async {
    final baseline = current;
    final chosen = await pickFlexDate(
      context,
      date: dateOnly(schoolDay(date).add(const Duration(days: 1))),
      allowTime: false,
      allowDateClear: false,
      title: 'Offene Phasen weiterführen',
    );
    if (chosen == null || !mounted) return;
    if (chosen.$1.compareTo(date) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte einen späteren Unterrichtstag wählen.'),
        ),
      );
      return;
    }
    await previewCarry(baseline, chosen.$1);
  }

  Future<void> continuePhase(LessonPhase phase) async {
    final baseline = current;
    final following = schoolDay(date).add(const Duration(days: 1));
    final lessons = lessonOccurrences(
      c.classroom,
      dateOnly(following),
      dateOnly(following.add(const Duration(days: 56))),
    ).where((l) => l.document.isTeachingLesson).toList();
    var day = lessons.firstOrNull?.date ?? dateOnly(following);
    LessonOccurrence? targetLesson = lessons.firstOrNull;
    var note = phase.resumeNote;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          final choices = lessonOccurrences(
            c.classroom,
            day,
            day,
          ).where((l) => l.document.isTeachingLesson);
          return FlexModal(
            title: const Text('Hier weitermachen'),
            onClose: () => Navigator.pop(ctx),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(phase.title, style: Theme.of(ctx).textTheme.titleMedium),
                TextFormField(
                  initialValue: note,
                  maxLength: 300,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Wo geht es weiter?',
                    hintText: 'Seite 12, bei Aufgabe 4',
                  ),
                  onChanged: (v) => note = v,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: Text(displayDate(day)),
                  onPressed: () async {
                    final result = await pickFlexDate(
                      ctx,
                      date: day,
                      allowTime: false,
                      allowDateClear: false,
                    );
                    if (result == null || !ctx.mounted) return;
                    refresh(() {
                      day = result.$1;
                      targetLesson = lessonOccurrences(
                        c.classroom,
                        day,
                        day,
                      ).where((l) => l.document.isTeachingLesson).firstOrNull;
                    });
                  },
                ),
                if (choices.isNotEmpty)
                  DropdownButton<String>(
                    isExpanded: true,
                    value: targetLesson?.target ?? '',
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Ohne feste Stunde'),
                      ),
                      for (final l in choices)
                        DropdownMenuItem(
                          value: l.target,
                          child: Text(
                            '${l.start} · ${l.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => refresh(
                      () => targetLesson = choices
                          .where((l) => l.target == v)
                          .firstOrNull,
                    ),
                  ),
                if (day.compareTo(baseline.text('date')) <= 0)
                  const Text('Bitte einen späteren Tag wählen.'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: day.compareTo(baseline.text('date')) <= 0
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Vormerken'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await run(() async {
      final next = lessonFlowFor(
        c.classroom,
        day,
        pupils: c.pupils,
        pupilId: lessonFlowPupil(baseline),
        lesson: targetLesson,
      );
      await c.saveClassroomBatch(
        carryLessonPhases(
          baseline,
          next,
          DateTime.now(),
          phaseId: phase.id,
          resumeNote: note,
        ),
      );
    });
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weiter am ${displayDate(day)} · ${phase.title}'),
          action: SnackBarAction(
            label: 'Öffnen',
            onPressed: () {
              if (!mounted) return;
              setState(() {
                date = day;
                target = targetLesson?.target ?? '';
                individual = true;
                pupilId = lessonFlowPupil(baseline);
                expanded = lessonPhases(current).firstOrNull?.id;
              });
              widget.onDateChanged?.call(day);
            },
          ),
        ),
      );
    }
  }

  void homework() => showHomeworkControl(context, c, date, pupilId: pupilId);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final value = current, phases = lessonPhases(value);
        reportSource(value);
        final materials = {
          for (final m in [
            ...?preparedMaterialsByDay(c.classroom)[date],
            ...suggestedMaterials(c.classroom, date),
          ])
            m.id: m,
        }.values.toList();
        return ListView(
          key: const PageStorageKey('lesson-flow'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Voriger Unterrichtstag',
                  onPressed: busy ? null : () => day(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : () => day(),
                    child: Text(displayDate(date)),
                  ),
                ),
                IconButton(
                  tooltip: 'Nächster Unterrichtstag',
                  onPressed: busy ? null : () => day(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                if (!individual || pupilId != null)
                  IconButton(
                    tooltip: 'Phase hinzufügen',
                    onPressed: busy ? null : () => editPhase(),
                    icon: const Icon(Icons.add),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Ablaufoptionen',
                  icon: const Icon(Icons.tune),
                  enabled: !busy,
                  onSelected: (command) {
                    switch (command) {
                      case 'today':
                        setState(() {
                          date = dateOnly(DateTime.now());
                          target = null;
                          expanded = null;
                          widget.onDateChanged?.call(date);
                        });
                      case 'edit':
                        setState(() => editing = !editing);
                      case 'templates':
                        templates();
                      case 'materials':
                        showMaterials(current);
                      case 'sources':
                        _showPlanSources();
                      case 'import':
                        fromPlan();
                      case 'live':
                        _showLiveControls();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'today', child: Text('Heute')),
                    if (!individual || pupilId != null) ...[
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          editing ? 'Bearbeiten beenden' : 'Ablauf bearbeiten',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'materials',
                        child: Text('Materialien'),
                      ),
                      const PopupMenuItem(
                        value: 'templates',
                        child: Text('Vorlagen'),
                      ),
                      const PopupMenuItem(
                        value: 'sources',
                        child: Text('Planungsdokumente'),
                      ),
                      const PopupMenuItem(
                        value: 'import',
                        child: Text('Aus Planung'),
                      ),
                      if (phases.isNotEmpty)
                        const PopupMenuItem(
                          value: 'live',
                          child: Text('Live-Steuerung'),
                        ),
                    ],
                  ],
                ),
              ],
            ),
            _scopeSelector(),
            if (individual && pupilId == null) ...[
              ..._pupilRows(),
            ] else ...[
              if (pupilId != null) _pupilHeading(),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : chooseLesson,
                    icon: const Icon(Icons.schedule, size: 17),
                    label: Text(
                      lesson == null
                          ? target == ''
                                ? 'Freier Tagesablauf'
                                : 'Gespeicherter Unterricht · wechseln'
                          : '${lesson!.start}–${lesson!.end} · ${lesson!.title}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: homework,
                    icon: const Icon(Icons.fact_check_outlined, size: 17),
                    label: const Text('HÜ-Kontrolle'),
                  ),
                ],
              ),
              if (value.title != 'FLEX-Klasse' || editing)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (editing)
                      IconButton(
                        tooltip: 'Unterrichtsthema ändern',
                        onPressed: busy ? null : rename,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
              if (isSuggestedLessonFlow(value))
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      'Vorgeschlagener Grundablauf',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    TextButton(
                      onPressed: _showPlanSources,
                      child: const Text('Planung suchen'),
                    ),
                  ],
                )
              else if (value.map('flow')['sourceId'] case final String id
                  when id.isNotEmpty)
                if (c.classroom
                        .where((m) => m.id == id && !m.deleted)
                        .firstOrNull
                    case final doc?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => reviewSource(doc),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: Text(doc.title),
                    ),
                  ),
              if (phases.isEmpty) ...sourcePanel(value),
              for (final (i, p) in phases.indexed) _phase(value, p, i),
              if (phases.isEmpty)
                const EmptyState(
                  'Noch keine Phasen. Füge eine Phase hinzu oder wähle eine Vorlage.',
                  icon: Icons.route_outlined,
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    key: const ValueKey('flow-materials'),
                    onPressed: () => showMaterials(current),
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: const Text('Materialien'),
                  ),
                  if (phases.isNotEmpty)
                    TextButton.icon(
                      key: const ValueKey('flow-live-controls'),
                      onPressed: _showLiveControls,
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Live-Steuerung'),
                    ),
                ],
              ),
              if (phases.isNotEmpty) ...sourcePanel(value),
              if (phases.any((p) => p.pending))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : carry,
                    icon: const Icon(Icons.event_repeat, size: 19),
                    label: const Text('Offenes weiterführen'),
                  ),
                ),
              if (materials.isNotEmpty && pupilId == null) ...[
                const Divider(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Unterlagen für diesen Tag',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    MaterialGroupingButton(c),
                  ],
                ),
                ...groupedMaterialRows(
                  c,
                  materials,
                  (group) => [
                    for (final m in group) _material(m, individual: true),
                  ],
                  day: date,
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _showPlanSources() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        final sources = sourcePanel(current);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Planung für ${displayDate(date)}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              if (sources.isEmpty)
                const Text(
                  'Für diesen Tag ist keine Tages- oder Wochenplanung zugeordnet.',
                ),
              ...sources,
              TextButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Alle Planungsdokumente durchsuchen'),
                onPressed: () {
                  Navigator.pop(ctx);
                  openPlanningBoard(context, c, documents: true);
                },
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _showLiveControls({
    String? forPupil,
  }) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        final flow = forPupil == null ? current : pupilFlow(forPupil);
        final phases = lessonPhases(flow),
            active = phases.where((p) => p.status == 'active').firstOrNull,
            pending = phases.where((p) => p.pending).toList(),
            colors = Theme.of(ctx).colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Live-Steuerung',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '${phases.where((p) => p.status == 'done').length} von ${phases.length} Phasen durchgeführt · ${phases.fold<int>(0, (sum, p) => sum + p.minutes)} Min.',
              ),
              if ((active ?? pending.firstOrNull) case final p?)
                Text(p.title, style: Theme.of(ctx).textTheme.titleMedium),
              if (phases.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<String>(
                    tooltip: 'Bestimmte Phase starten',
                    onSelected: (id) =>
                        save(activateLessonPhase(flow, id, DateTime.now())),
                    itemBuilder: (_) => [
                      for (final (i, p) in phases.indexed)
                        PopupMenuItem(
                          value: p.id,
                          child: Text('${i + 1}. ${p.title}'),
                        ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Andere Phase starten'),
                    ),
                  ),
                ),
              if (active != null && active.minutes > 0)
                _PhaseClock(phase: active),
              if (active != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('flow-next'),
                      onPressed: busy
                          ? null
                          : () => save(
                              finishLessonPhase(
                                flow,
                                active.id,
                                DateTime.now(),
                              ),
                            ),
                      icon: const Icon(Icons.check),
                      label: Text(
                        pending.length > 1
                            ? 'Nächste Phase'
                            : 'Unterricht abschließen',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => save(
                              withLessonPhases(flow, [
                                for (final p in lessonPhases(flow))
                                  if (p.id == active.id)
                                    p.running
                                        ? p.pause(DateTime.now())
                                        : p.patch({'startedAt': utcNow()})
                                  else
                                    p,
                              ]),
                            ),
                      icon: Icon(
                        active.running ? Icons.pause : Icons.play_arrow,
                      ),
                      label: Text(active.running ? 'Pause' : 'Fortsetzen'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => save(
                              finishLessonPhase(
                                flow,
                                active.id,
                                DateTime.now(),
                                skip: true,
                              ),
                            ),
                      child: const Text('Überspringen'),
                    ),
                  ],
                )
              else if (pending.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const ValueKey('flow-start'),
                    onPressed: busy
                        ? null
                        : () => save(
                            activateLessonPhase(
                              flow,
                              pending.first.id,
                              DateTime.now(),
                            ),
                          ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ablauf starten'),
                  ),
                )
              else if (phases.isNotEmpty)
                Text(
                  'Ablauf abgeschlossen',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
  Widget _phase(ClassroomDocument value, LessonPhase p, int index) {
    final show = expanded == p.id || editing;
    final color = Theme.of(context).colorScheme;
    final lines = p.body.trim().split('\n');
    final time =
        RegExp(
          r'^\d{1,2}[:.]\d{2}\s*[–—-]\s*\d{1,2}[:.]\d{2}$',
        ).hasMatch(lines.first.trim())
        ? lines.removeAt(0).trim()
        : '';
    final instruction = lines.join('\n').trim();
    final suggested =
        instruction.isEmpty &&
            p.guidance.isEmpty &&
            p.sourceId.isEmpty &&
            value.map('flow')['sourceId'] == null
        ? basicPhaseInstructions[p.title]
        : null;
    final status = switch (p.status) {
      'done' => 'Durchgeführt',
      'skipped' => 'Übersprungen',
      'active' => p.running ? 'Jetzt' : 'Pausiert',
      _ => 'Offen',
    };
    return Container(
      key: ValueKey('phase-${p.id}'),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.outlineVariant.withValues(alpha: .75)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                setState(() => expanded = expanded == p.id ? null : p.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${index + 1}.',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: color.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          p.carriedTo.isNotEmpty
                              ? 'Weitergeführt · ${displayDate(p.carriedTo)}'
                              : [
                                  if (time.isNotEmpty) time,
                                  if (p.minutes > 0) '${p.minutes} Min.',
                                  if (p.status != 'open' || p.minutes == 0)
                                    status,
                                ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(show ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
          if (p.resumeNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 6),
              child: Text(p.resumeNote),
            ),
          if (instruction.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                instruction,
                key: ValueKey('phase-instruction-${p.id}'),
              ),
            )
          else if (suggested != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vorschlag',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(suggested),
                if (show)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => editPhase(p.patch({'body': suggested})),
                    child: const Text('Vorschlag bearbeiten und übernehmen'),
                  ),
              ],
            )
          else if (p.guidance.isEmpty && !busy)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => editPhase(p),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Arbeitsauftrag ergänzen'),
              ),
            ),
          for (final (i, guide) in p.guidance.indexed)
            Container(
              key: ValueKey('phase-guidance-${p.id}-$i'),
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      c.pupils
                          .where(
                            (s) => (guide['pupilIds'] as List).contains(s.id),
                          )
                          .map((s) => s.name)
                          .join(', '),
                      if (guide['minutes'] > 0) "${guide['minutes']} Min.",
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: color.primary),
                  ),
                  if ((guide['body'] as String).trim().isNotEmpty)
                    Text(guide['body'] as String),
                  for (final m in resolveMaterials(
                    c.classroom,
                    List<String>.from(guide['materialIds']),
                  ))
                    _material(m),
                ],
              ),
            ),
          if (p.pupilIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 8),
              child: Text(
                c.pupils
                    .where((s) => p.pupilIds.contains(s.id))
                    .map((s) => s.name)
                    .join(' · '),
                style: TextStyle(color: color.primary),
              ),
            ),
          if (p.materialIds.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: MaterialGroupingButton(c),
            ),
            ...groupedMaterialRows(
              c,
              resolveMaterials(c.classroom, p.materialIds),
              (group) => [for (final m in group) _material(m)],
              day: date,
            ),
          ],
          if (p.kind == 'homework')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: homework,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Hausübungen kontrollieren'),
              ),
            ),
          if (show) ...[
            Wrap(
              spacing: 2,
              children: [
                if (c.classroom.any(
                      (d) =>
                          d.id ==
                              (p.sourceId.isEmpty
                                  ? value.map('flow')['sourceId']
                                  : p.sourceId) &&
                          !d.deleted,
                    ) &&
                    (p.sourceRow.isNotEmpty ||
                        (value.map('flow')['sourceBase'] as Map?)?.containsKey(
                              p.id,
                            ) ==
                            true))
                  TextButton.icon(
                    onPressed: () => reviewPhaseSource(value, p),
                    icon: const Icon(Icons.find_in_page_outlined, size: 18),
                    label: const Text('Planzeile öffnen'),
                  ),
                IconButton(
                  tooltip: 'Materialien für ${p.title}',
                  onPressed: () => showMaterials(current, phaseId: p.id),
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Phase bearbeiten: ${p.title}',
                  onPressed: busy ? null : () => editPhase(p),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                if (editing) ...[
                  IconButton(
                    tooltip: 'Phase nach oben',
                    onPressed: busy || index == 0 ? null : () => reorder(p, -1),
                    icon: const Icon(Icons.arrow_upward, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Phase nach unten',
                    onPressed: busy || index == lessonPhases(value).length - 1
                        ? null
                        : () => reorder(p, 1),
                    icon: const Icon(Icons.arrow_downward, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Phase duplizieren',
                    onPressed: busy
                        ? null
                        : () => save(
                            withLessonPhases(current, [
                              for (final old in lessonPhases(current)) ...[
                                old,
                                if (old.id == p.id) p.fresh(),
                              ],
                            ]),
                          ),
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Phase entfernen',
                    onPressed: busy ? null : () => remove(p),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
                if (pupilId != null && p.pending)
                  TextButton.icon(
                    onPressed: busy ? null : () => continuePhase(p),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('Hier weitermachen'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _material(ClassroomDocument m, {bool individual = false}) {
    final names = individual
        ? c.pupils
              .where((p) => pupilMaterialDates(m, p.id).contains(date))
              .map((p) => p.name)
              .join(' · ')
        : '';
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: MaterialThumbnail(material: m, width: 36, height: 48),
        title: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: names.isEmpty ? null : Text(names),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => guarded(context, () => openFile(m)),
      ),
    );
  }
}

class _PhaseClock extends StatefulWidget {
  const _PhaseClock({required this.phase});
  final LessonPhase phase;
  @override
  State<_PhaseClock> createState() => _PhaseClockState();
}

class _PhaseClockState extends State<_PhaseClock> {
  Timer? ticker;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.phase.elapsedAt(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(left: 34, bottom: 6),
      child: Text(
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} / ${widget.phase.minutes} Min.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
