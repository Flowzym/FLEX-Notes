import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../application/notebook_controller.dart';
import '../domain/backup_merge.dart';
import '../domain/calendar.dart';
import '../domain/classroom.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import '../services/calendar_ics.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'dialog_workflows.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'orga_editor.dart';
import 'reminder_actions.dart';
import 'repeat_editor.dart';
import 'return_lists.dart';
import 'school_workspace.dart';
import 'surfaces.dart';

Future<void> showCalendarItem(
  BuildContext context,
  NotebookController c,
  CalendarItem item,
) async {
  if (item.entry != null) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrgaEditor(controller: c, entry: item.entry!),
    );
    return;
  }
  if (item.record != null) {
    await editSchool(context, c, item.record!);
    return;
  }
  if (item.category == 'return') {
    await showReturnDetail(context, c, item.document!.id);
    return;
  }
  if (item.category == 'holiday') {
    await showClassroomEditor(
      context,
      c,
      ClassroomKind.holiday,
      document: item.document,
    );
    return;
  }
  final lesson = item.lesson!;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final doc = c.classroom
            .where((d) => d.id == lesson.document.id && !d.deleted)
            .firstOrNull;
        final current = doc == null
            ? null
            : lessonOccurrences(
                [
                  doc,
                  ...c.classroom.where((d) => d.kind == ClassroomKind.holiday),
                ],
                dateOnly(
                  schoolDay(lesson.date).subtract(const Duration(days: 365)),
                ),
                dateOnly(schoolDay(lesson.date).add(const Duration(days: 365))),
              ).where((l) => l.target == lesson.target).firstOrNull;
        if (doc == null || current == null) {
          return FlexModal(
            title: const Text('Unterricht'),
            onClose: () => Navigator.pop(ctx),
            content: const Text(
              'Diese Durchführung wurde geändert oder abgesagt.',
            ),
          );
        }
        return FlexModal(
          maxWidth: 800,
          title: Text(current.title),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${displayDate(current.date)} · ${current.start.isEmpty ? 'Ganztägig' : '${current.start}–${current.end}'}',
              ),
              Text(
                [
                  doc.text('subject'),
                  'FLEX-Klasse',
                  doc.text('room'),
                ].where((v) => v.isNotEmpty).join(' · '),
              ),
              if (current.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(current.note),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showClassroomEditor(
                      ctx,
                      c,
                      ClassroomKind.lesson,
                      document: doc,
                      occurrenceDate: lesson.originalDate,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Diese Stunde bearbeiten'),
                  ),
                  if (doc.rule.repeats)
                    OutlinedButton.icon(
                      onPressed: () => showClassroomEditor(
                        ctx,
                        c,
                        ClassroomKind.lesson,
                        document: doc,
                        occurrenceDate: lesson.originalDate,
                        following: true,
                      ),
                      icon: const Icon(Icons.repeat),
                      label: const Text('Diese und folgende'),
                    ),
                  TextButton.icon(
                    onPressed: () => showReminderActions(
                      ctx,
                      c,
                      lesson.target,
                      current.title,
                    ),
                    icon: const Icon(Icons.snooze),
                    label: const Text('Erinnerung verschieben'),
                  ),
                  TextButton.icon(
                    onPressed: () => showBulk(
                      ctx,
                      c,
                      initialKind: 'homework',
                      initialSubject: doc.text('subject'),
                    ),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('HÜ vergeben'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final pupil = await showDialog<Pupil>(
                        context: ctx,
                        builder: (selectCtx) => FlexModal(
                          title: const Text('Beobachtung für …'),
                          onClose: () => Navigator.pop(selectCtx),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final p in c.pupils.where(
                                (p) => !p.archived,
                              ))
                                ListTile(
                                  title: Text(p.name),
                                  onTap: () => Navigator.pop(selectCtx, p),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (pupil != null && ctx.mounted) {
                        await editSchool(
                          ctx,
                          c,
                          SchoolRecord.empty(SchoolKind.work, pupil.id).patch({
                            'subject': doc.text('subject'),
                            'observedOn': current.date,
                            'observedTime': current.start,
                          }),
                        );
                      }
                    },
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Beobachtung'),
                  ),
                  TextButton.icon(
                    onPressed: () => guarded(
                      ctx,
                      () => c.saveClassroom(
                        doc.patch({
                          'exceptions': [
                            for (final e in doc.rows('exceptions'))
                              if (e['date'] != lesson.originalDate) e,
                            {'date': lesson.originalDate, 'cancelled': true},
                          ],
                        }),
                      ),
                    ),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Diese Stunde entfällt'),
                  ),
                ],
              ),
              const Divider(),
              Text(
                'Planungen & Materialien',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              for (final key in doc.strings('materialIds'))
                if (c.classroom.any((d) => d.id == key && !d.deleted))
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      c.classroom.firstWhere((d) => d.id == key).title,
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => guarded(
                      ctx,
                      () => openMaterial(
                        ctx,
                        c,
                        c.classroom.firstWhere((d) => d.id == key),
                      ),
                    ),
                  ),
              if (doc.strings('materialIds').isEmpty)
                const Text('Noch keine Materialien zugeordnet.'),
              OutlinedButton.icon(
                onPressed: () async {
                  final ids = await chooseMaterials(
                    ctx,
                    c,
                    doc.strings('materialIds'),
                  );
                  if (ids != null && ctx.mounted) {
                    await guarded(
                      ctx,
                      () => c.saveClassroom(doc.patch({'materialIds': ids})),
                    );
                  }
                },
                icon: const Icon(Icons.attach_file),
                label: const Text('Materialien zuordnen'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> showCalendarManagement(
  BuildContext context,
  NotebookController c,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) => FlexModal(
      maxWidth: 850,
      title: const Text('Serien, Ferien & Ausfälle'),
      onClose: () => Navigator.pop(ctx),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in c.classroom.where(
            (d) =>
                d.kind == ClassroomKind.lesson ||
                d.kind == ClassroomKind.holiday,
          ))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(d.title, style: Theme.of(ctx).textTheme.titleMedium),
                    Text(
                      '${d.label} · ${displayDate(d.text('date'))}${d.deleted ? ' · Papierkorb' : ''}',
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (!d.deleted)
                          TextButton.icon(
                            onPressed: () => showClassroomEditor(
                              ctx,
                              c,
                              d.kind,
                              document: d,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Bearbeiten'),
                          ),
                        TextButton.icon(
                          onPressed: () => guarded(
                            ctx,
                            () => c.saveClassroom(
                              d.patch({'deleted': !d.deleted}),
                            ),
                          ),
                          icon: Icon(
                            d.deleted ? Icons.restore : Icons.delete_outline,
                          ),
                          label: Text(
                            d.deleted ? 'Wiederherstellen' : 'In Papierkorb',
                          ),
                        ),
                      ],
                    ),
                    if (!d.deleted)
                      for (final e in d.rows('exceptions'))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${displayDate(e['date'] as String)} · ${e['cancelled'] == true ? 'Entfällt' : 'Geändert'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Ausnahme zurücknehmen',
                            icon: const Icon(Icons.undo),
                            onPressed: () => guarded(
                              ctx,
                              () => c.saveClassroom(
                                d.patch({
                                  'exceptions': d
                                      .rows('exceptions')
                                      .where((x) => x['date'] != e['date'])
                                      .toList(),
                                }),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          if (!c.classroom.any(
            (d) =>
                d.kind == ClassroomKind.lesson ||
                d.kind == ClassroomKind.holiday,
          ))
            const Text('Noch kein Unterricht und keine Ferien erfasst.'),
        ],
      ),
    ),
  ),
);

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller});
  final NotebookController controller;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with AutomaticKeepAliveClientMixin {
  DateTime selected = schoolDay(dateOnly(DateTime.now()));
  String mode = 'day';
  bool busy = false;
  final filters = calendarCategories.keys.toSet();
  NotebookController get c => widget.controller;
  @override
  bool get wantKeepAlive => true;
  ({String from, String to}) get range {
    final first = mode == 'day'
        ? selected
        : mode == 'week'
        ? selected.subtract(Duration(days: selected.weekday - 1))
        : DateTime.utc(selected.year, selected.month, 1);
    final last = mode == 'day'
        ? first
        : mode == 'week'
        ? first.add(const Duration(days: 6))
        : DateTime.utc(selected.year, selected.month + 1, 0);
    return (from: dateOnly(first), to: dateOnly(last));
  }

  void step(int direction) => setState(
    () => selected = mode == 'month'
        ? DateTime.utc(selected.year, selected.month + direction, 1)
        : selected.add(Duration(days: direction * (mode == 'week' ? 7 : 1))),
  );
  Future<void> importIcs() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Kalender',
          extensions: ['ics'],
          mimeTypes: ['text/calendar', 'text/plain'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 5000000) {
      throw const DomainError('Bitte eine Kalenderdatei bis zu 5 MB wählen.');
    }
    final bytes = BytesBuilder();
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > 5000000) {
        throw const DomainError('Die Kalenderdatei ist zu groß.');
      }
      bytes.add(chunk);
    }
    final preview = parseCalendarIcs(
      utf8.decode(bytes.takeBytes()),
      source: file.name,
    );
    if (!mounted) return;
    final existing = {for (final d in c.classroom) d.id: d};
    final fields = {'title', 'date', 'start', 'end', 'repeat', 'note', 'room'};
    bool same(ClassroomDocument d) =>
        existing[d.id] != null &&
        fields.every(
          (k) =>
              canonical(d.toJson()[k]) ==
              canonical(existing[d.id]!.toJson()[k]),
        );
    final chosen = {
      for (final d in preview.documents)
        if (!existing.containsKey(d.id)) d.id,
    };
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FlexModal(
          maxWidth: 800,
          title: const Text('Kalenderimport prüfen'),
          onClose: () => Navigator.pop(ctx, false),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${preview.documents.where((d) => !existing.containsKey(d.id)).length} neu · ${preview.documents.where(same).length} unverändert',
              ),
              for (final warning in preview.warnings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    warning,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
              for (final d in preview.documents)
                CheckboxListTile(
                  title: Text(d.title),
                  value: chosen.contains(d.id),
                  onChanged: same(d)
                      ? null
                      : (v) => update(() {
                          if (v == true) {
                            chosen.add(d.id);
                          } else {
                            chosen.remove(d.id);
                          }
                        }),
                  subtitle: Text(
                    same(d)
                        ? 'Bereits vorhanden'
                        : existing.containsKey(d.id)
                        ? 'Bisher: ${existing[d.id]!.title} · ${displayDate(existing[d.id]!.text('date'))}\nImport: ${displayDate(d.text('date'))} ${d.text('start')} – ausgewählte Felder werden ersetzt'
                        : '${displayDate(d.text('date'))} ${d.text('start')}',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text('${chosen.length} übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (accept != true) return;
    await c.saveClassroomBatch([
      for (final d in preview.documents.where((d) => chosen.contains(d.id)))
        d.patch({
          'revision': existing[d.id]?.revision ?? 0,
          'createdAtUtc':
              existing[d.id]?.text('createdAtUtc') ?? d.text('createdAtUtc'),
          'materialIds': existing[d.id]?.strings('materialIds') ?? <String>[],
        }),
    ]);
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(context, action);
    if (mounted) setState(() => busy = false);
  }

  IconData icon(String category) => switch (category) {
    'lesson' => Icons.school_outlined,
    'homework' => Icons.home_outlined,
    'goal' => Icons.flag_outlined,
    'return' => Icons.fact_check_outlined,
    'holiday' => Icons.beach_access_outlined,
    'task' => Icons.check_circle_outline,
    _ => Icons.event_outlined,
  };
  Widget entry(CalendarItem item) => FlexCard(
    child: ListTile(
      leading: Icon(icon(item.category)),
      title: Text(
        item.title,
        style: item.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        [
          if (item.time.isNotEmpty)
            '${item.time}${item.end.isEmpty ? '' : '–${item.end}'}',
          calendarCategories[item.category]!,
          item.detail,
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
      onTap: () => showCalendarItem(context, c, item),
      trailing: item.entry?.isTask == true || item.entry?.isAppointment == true
          ? IconButton(
              tooltip: 'Wiederholung',
              icon: const Icon(Icons.repeat),
              onPressed: () => showOrgaRepeat(context, c, item.entry!),
            )
          : const Icon(Icons.chevron_right),
    ),
  );
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final bounds = range,
            items = calendarItems(
              c.currentSnapshot,
              range.from,
              range.to,
            ).where((e) => filters.contains(e.category)).toList();
        final days = <DateTime>[];
        for (
          var d = schoolDay(bounds.from);
          !d.isAfter(schoolDay(bounds.to));
          d = d.add(const Duration(days: 1))
        ) {
          days.add(d);
        }
        final monday = selected.subtract(Duration(days: selected.weekday - 1));
        return ListView(
          key: const PageStorageKey('calendar-page'),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Kalender · FLEX-Klasse',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final m in const {
                  'day': 'Tag',
                  'week': 'Woche',
                  'month': 'Monat',
                }.entries)
                  ChoiceChip(
                    label: Text(m.value),
                    selected: mode == m.key,
                    onSelected: (_) => setState(() => mode = m.key),
                  ),
                IconButton(
                  tooltip: 'Vorheriger Zeitraum',
                  onPressed: () => step(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: () async {
                    final d = await pickFlexDate(
                      ctx,
                      date: dateOnly(selected),
                      allowTime: false,
                    );
                    if (d != null && d.$1.isNotEmpty && mounted) {
                      setState(() => selected = schoolDay(d.$1));
                    }
                  },
                  child: Text(
                    mode == 'day'
                        ? displayDate(bounds.from)
                        : '${displayDate(bounds.from)} – ${displayDate(bounds.to)}',
                  ),
                ),
                IconButton(
                  tooltip: 'Nächster Zeitraum',
                  onPressed: () => step(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => selected = schoolDay(dateOnly(DateTime.now())),
                  ),
                  child: const Text('Heute'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in calendarCategories.entries)
                  FilterChip(
                    label: Text(f.value),
                    selected: filters.contains(f.key),
                    onSelected: (v) => setState(() {
                      if (v) {
                        filters.add(f.key);
                      } else {
                        filters.remove(f.key);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                IconButton(
                  onPressed: () => showCalendarManagement(ctx, c),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  tooltip: 'Serien, Ferien & Ausfälle verwalten',
                ),
                FilledButton.icon(
                  onPressed: () => showClassroomEditor(
                    ctx,
                    c,
                    ClassroomKind.lesson,
                    date: dateOnly(selected),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Unterricht'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    barrierDismissible: false,
                    builder: (_) => OrgaEditor(
                      controller: c,
                      entry: OrgaEntry.empty().copyWith(
                        appointmentDate: dateOnly(selected),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Termin'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    barrierDismissible: false,
                    builder: (_) => OrgaEditor(
                      controller: c,
                      entry: OrgaEntry.empty().copyWith(
                        isTask: true,
                        dueDate: dateOnly(selected),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Aufgabe'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showClassroomEditor(
                    ctx,
                    c,
                    ClassroomKind.returnList,
                    date: dateOnly(selected),
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Rücklauf'),
                ),
                TextButton.icon(
                  onPressed: () => showClassroomEditor(
                    ctx,
                    c,
                    ClassroomKind.holiday,
                    date: dateOnly(selected),
                  ),
                  icon: const Icon(Icons.beach_access_outlined),
                  label: const Text('Ferien / Ausfall'),
                ),
                IconButton(
                  onPressed: busy ? null : () => run(importIcs),
                  icon: const Icon(Icons.file_open_outlined),
                  tooltip: 'ICS importieren',
                ),
                IconButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await saveTextFile(
                            'FLEX-Kalender-${bounds.from}.ics',
                            exportCalendarIcs(items),
                            mime: 'text/calendar',
                          );
                        }),
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Zeitraum als ICS exportieren',
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            for (final m in c.classroom.where(
              (d) =>
                  !d.deleted &&
                  d.kind == ClassroomKind.material &&
                  d.text('week').isNotEmpty &&
                  schoolDay(d.text('week')).subtract(
                        Duration(days: schoolDay(d.text('week')).weekday - 1),
                      ) ==
                      monday,
            ))
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('Wochenplanung · ${m.title}'),
                onTap: () => guarded(ctx, () => openMaterial(ctx, c, m)),
              ),
            if (mode == 'month') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final label in const [
                    'Mo',
                    'Di',
                    'Mi',
                    'Do',
                    'Fr',
                    'Sa',
                    'So',
                  ])
                    Expanded(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: MediaQuery.textScalerOf(ctx).scale(1) > 1.5
                    ? .65
                    : .9,
                children: [
                  for (var i = 1; i < days.first.weekday; i++)
                    const SizedBox.shrink(),
                  for (final d in days)
                    Semantics(
                      label:
                          '${displayDate(dateOnly(d))}, ${items.where((e) => e.date == dateOnly(d)).length} Einträge',
                      button: true,
                      selected: d == selected,
                      child: InkWell(
                        onTap: () => setState(() => selected = d),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: d == selected
                                ? Theme.of(ctx).colorScheme.primaryContainer
                                : null,
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${d.day}'),
                              if (items.any((e) => e.date == dateOnly(d)))
                                Text(
                                  '${items.where((e) => e.date == dateOnly(d)).length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(ctx).colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            for (final day in mode == 'month' ? [selected] : days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 8),
                child: Text(
                  '${const ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'][day.weekday - 1]} · ${displayDate(dateOnly(day))}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              if (!items.any((e) => e.date == dateOnly(day)))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Keine Einträge.'),
                ),
              for (final item in items.where((e) => e.date == dateOnly(day)))
                entry(item),
            ],
          ],
        );
      },
    );
  }
}
