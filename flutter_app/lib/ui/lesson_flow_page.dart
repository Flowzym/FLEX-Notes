import 'dart:async';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/classroom.dart';
import '../domain/lesson_flow.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'material_thumbnail.dart';
import 'homework_control.dart';
part 'lesson_phase_editor.dart';

class LessonFlowPage extends StatefulWidget {
  const LessonFlowPage({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<LessonFlowPage> createState() => _LessonFlowPageState();
}

class _LessonFlowPageState extends State<LessonFlowPage>
    with AutomaticKeepAliveClientMixin {
  NotebookController get c => widget.controller;
  String date = dateOnly(DateTime.now());
  String? target, expanded;
  bool editing = false, busy = false;
  ClassroomDocument? seed;
  String seedKey = '';
  @override
  bool get wantKeepAlive => true;
  List<LessonOccurrence> get lessons =>
      lessonOccurrences(c.classroom, date, date);
  List<ClassroomDocument> get savedFlows =>
      c.classroom
          .where(
            (d) =>
                !d.deleted &&
                hasLessonFlow(d) &&
                !isFlowTemplate(d) &&
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

  ClassroomDocument get current {
    if (target == null && savedFlows.isNotEmpty) {
      final saved =
          savedFlows
              .where((d) => lessonPhases(d).any((p) => p.status == 'active'))
              .firstOrNull ??
          savedFlows.first;
      target = saved.map('flow')['lessonTarget'] as String;
    }
    target ??= lesson?.target ?? '';
    final key = '$date|$target';
    if (seed == null || seedKey != key) {
      seedKey = key;
      seed = lessonFlowFor(
        c.classroom,
        date,
        lesson: lesson,
        lessonTarget: target,
      );
    }
    return c.classroom
            .where((d) => d.id == seed!.id && !d.deleted)
            .firstOrNull ??
        seed!;
  }

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
          lessonPhases(picked).map((p) => p.fresh()).toList(),
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
            pupilIds: picked.strings('pupilIds'),
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
    await run(() async {
      var next = lessonFlowFor(c.classroom, chosen.$1);
      if (next.revision == 0) next = withLessonPhases(next, []);
      await c.saveClassroomBatch(
        carryLessonPhases(baseline, next, DateTime.now()),
      );
    });
  }

  void homework() => showHomeworkControl(context, c, date);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final value = current,
            phases = lessonPhases(value),
            colors = Theme.of(context).colorScheme;
        final active = phases.where((p) => p.status == 'active').firstOrNull;
        final pending = phases.where((p) => p.pending).toList();
        final materials = {
          for (final m in [
            ...resolveMaterials(
              c.classroom,
              preparationFor(c.classroom, date).strings('materialIds'),
            ),
            ...suggestedMaterials(c.classroom, date),
          ])
            m.id: m,
        }.values.toList();
        return ListView(
          key: const PageStorageKey('lesson-flow'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ablauf',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: editing ? 'Bearbeiten beenden' : 'Ablauf bearbeiten',
                  icon: Icon(editing ? Icons.check : Icons.edit_outlined),
                  onPressed: busy
                      ? null
                      : () => setState(() => editing = !editing),
                ),
                IconButton(
                  tooltip: 'Phase hinzufügen',
                  onPressed: busy ? null : () => editPhase(),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
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
                if (date != dateOnly(DateTime.now()))
                  TextButton(
                    onPressed: () => setState(() {
                      date = dateOnly(DateTime.now());
                      target = null;
                    }),
                    child: const Text('Heute'),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (editing)
                  IconButton(
                    tooltip: 'Unterrichtsthema ändern',
                    onPressed: busy ? null : rename,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : chooseLesson,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  lesson == null
                      ? target == ''
                            ? 'Freier Tagesablauf'
                            : 'Gespeicherter Unterricht · wechseln'
                      : '${lesson!.start}–${lesson!.end} · Unterricht wählen',
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: homework,
                  icon: const Icon(Icons.fact_check_outlined, size: 19),
                  label: const Text('HÜ-Kontrolle'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : templates,
                  icon: const Icon(Icons.bookmarks_outlined, size: 19),
                  label: const Text('Vorlagen'),
                ),
                if (editing)
                  TextButton.icon(
                    onPressed: busy ? null : fromPlan,
                    icon: const Icon(Icons.post_add, size: 19),
                    label: const Text('Aus Planung'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${phases.where((p) => p.status == 'done').length} von ${phases.length} Phasen durchgeführt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '${phases.fold<int>(0, (sum, p) => sum + p.minutes)} Min.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                              current,
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
                            withLessonPhases(current, [
                              for (final p in lessonPhases(current))
                                if (p.id == active.id)
                                  p.running
                                      ? p.pause(DateTime.now())
                                      : p.patch({'startedAt': utcNow()})
                                else
                                  p,
                            ]),
                          ),
                    icon: Icon(active.running ? Icons.pause : Icons.play_arrow),
                    label: Text(active.running ? 'Pause' : 'Fortsetzen'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => save(
                            finishLessonPhase(
                              current,
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
                            current,
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
            const SizedBox(height: 10),
            for (final (i, p) in phases.indexed) _phase(value, p, i),
            if (phases.isEmpty)
              const EmptyState(
                'Noch keine Phasen. Füge eine Phase hinzu oder wähle eine Vorlage.',
                icon: Icons.route_outlined,
              ),
            const SizedBox(height: 12),
            if (pending.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : carry,
                  icon: const Icon(Icons.event_repeat, size: 19),
                  label: const Text('Offenes weiterführen'),
                ),
              ),
            if (materials.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Unterlagen für diesen Tag',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final m in materials) _material(m, individual: true),
            ],
          ],
        );
      },
    );
  }

  Widget _phase(ClassroomDocument value, LessonPhase p, int index) {
    final active = p.status == 'active',
        show = active || expanded == p.id || editing;
    final color = Theme.of(context).colorScheme;
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
        color: active ? color.primary.withValues(alpha: .08) : null,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          bottom: BorderSide(color: color.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  Icon(
                    p.status == 'done'
                        ? Icons.check_circle_outline
                        : active
                        ? Icons.play_circle_outline
                        : p.status == 'skipped'
                        ? Icons.skip_next_outlined
                        : Icons.radio_button_unchecked,
                    color: color.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
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
                              : '$status${p.minutes > 0 ? ' · ${p.minutes} Min.' : ''}',
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
          if (!show && p.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 6),
              child: Text(p.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          if (show) ...[
            if (p.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34, bottom: 8),
                child: Text(p.body),
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
            for (final m in resolveMaterials(c.classroom, p.materialIds))
              _material(m),
            if (p.kind == 'homework')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: homework,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Hausübungen kontrollieren'),
                ),
              ),
            if (active && p.minutes > 0) _PhaseClock(phase: p),
            Wrap(
              spacing: 2,
              children: [
                if (!active)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => save(
                            activateLessonPhase(current, p.id, DateTime.now()),
                          ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(p.pending ? 'Hier starten' : 'Wieder öffnen'),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: MaterialThumbnail(material: m, width: 36, height: 48),
      title: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: names.isEmpty ? null : Text(names),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => guarded(context, () => openMaterial(context, c, m)),
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
