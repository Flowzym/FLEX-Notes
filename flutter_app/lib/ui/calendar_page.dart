import 'material_thumbnail.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/backup_merge.dart';
import '../domain/calendar.dart';
import '../domain/calendar_layout.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
import '../domain/models.dart';
import '../domain/school.dart';
import '../domain/timetable.dart';
import '../services/calendar_ics.dart';
import 'classroom_editor.dart';
import 'common.dart';
import 'dialog_workflows.dart';
import 'draft_buffer.dart';
import 'flex_modal.dart';
import 'material_library.dart';
import 'orga_editor.dart';
import 'reminder_actions.dart';
import 'return_lists.dart';
import 'school_workspace.dart';
import 'calendar_timeline.dart';
import 'document_attachments.dart';
import '../domain/document_scanner.dart';
import 'timetable.dart';

part 'calendar_detail.dart';

Future<void> showCalendarManagement(
  BuildContext context,
  NotebookController c, {
  Future<void> Function()? importCalendar,
  Future<void> Function()? exportCalendar,
  String? date,
  VoidCallback? openTimetable,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => AnimatedBuilder(
    animation: c,
    builder: (ctx, _) => FlexModal(
      maxWidth: 850,
      title: const Text('Kalender verwalten'),
      onClose: () => Navigator.pop(ctx),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (openTimetable != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openTimetable();
                  },
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Stundenplan'),
                ),
              OutlinedButton.icon(
                onPressed: () => showClassroomEditor(
                  ctx,
                  c,
                  ClassroomKind.lesson,
                  date: date,
                ),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Unterricht'),
              ),
              OutlinedButton.icon(
                onPressed: () => showClassroomEditor(
                  ctx,
                  c,
                  ClassroomKind.holiday,
                  date: date,
                ),
                icon: const Icon(Icons.beach_access_outlined),
                label: const Text('Ferien / Ausfall'),
              ),
              if (importCalendar != null)
                TextButton.icon(
                  onPressed: importCalendar,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('ICS importieren'),
                ),
              if (exportCalendar != null)
                TextButton.icon(
                  onPressed: exportCalendar,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Aktuelle Ansicht exportieren'),
                ),
            ],
          ),
          const Divider(),
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
                            '${displayDate(e['date'] as String)} · ${e['cancelled'] == true
                                ? 'Entfällt'
                                : e.containsKey('movedTo') || e.containsKey('start')
                                ? 'Zeit geändert'
                                : 'Vorbereitung angepasst'}',
                          ),
                          trailing:
                              e['cancelled'] != true &&
                                  !e.containsKey('movedTo') &&
                                  !e.containsKey('start')
                              ? null
                              : IconButton(
                                  tooltip: e['cancelled'] == true
                                      ? 'Stunde wieder einplanen'
                                      : 'Zeitänderung zurücknehmen',
                                  icon: const Icon(Icons.undo),
                                  onPressed: () => guarded(
                                    ctx,
                                    () => c.saveClassroom(
                                      e['cancelled'] == true
                                          ? patchLessonOccurrence(
                                              d,
                                              e['date'] as String,
                                              {'cancelled': false},
                                            )
                                          : d.patch({
                                              'exceptions': [
                                                for (final item in d.rows(
                                                  'exceptions',
                                                ))
                                                  if (item['date'] != e['date'])
                                                    item
                                                  else
                                                    {
                                                      for (final field
                                                          in item.entries)
                                                        if (!{
                                                          'movedTo',
                                                          'start',
                                                          'end',
                                                        }.contains(field.key))
                                                          field.key:
                                                              field.value,
                                                    },
                                              ],
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
  const CalendarPage({
    super.key,
    required this.controller,
    this.clock,
    this.initialTimetable = false,
    this.shortcutDate,
    this.shortcutRevision = 0,
    this.onSwitchSection,
  });
  final bool initialTimetable;
  final DateTime? shortcutDate;
  final int shortcutRevision;
  final void Function(bool, DateTime)? onSwitchSection;
  final DateTime Function()? clock;
  final NotebookController controller;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  DateTime get now => widget.clock?.call() ?? DateTime.now();
  late DateTime calendarDate = schoolDay(dateOnly(now));
  DateTime? timetableDate;
  bool timetableView = false;
  DateTime get selected => timetableView ? timetableDate! : calendarDate;
  set selected(DateTime date) {
    if (timetableView) {
      timetableDate = date;
    } else {
      calendarDate = date;
    }
  }

  String calendarMode = 'day', timetableMode = 'week';
  String get mode => timetableView ? timetableMode : calendarMode;
  set mode(String value) {
    if (timetableView) {
      timetableMode = value;
    } else {
      calendarMode = value;
    }
  }

  void selectSection(bool timetable) {
    if (timetable == timetableView) return;
    if (widget.onSwitchSection != null) {
      widget.onSwitchSection!(timetable, selected);
      return;
    }
    setState(() {
      if (timetable && timetableDate == null) {
        final table =
            c.classroom
                .where((d) => d.kind == ClassroomKind.timetable)
                .firstOrNull ??
            flexTimetableTemplate().first;
        timetableDate = calendarDate.isBefore(schoolDay(table.text('date')))
            ? schoolDay(table.text('date'))
            : calendarDate;
      }
      timetableView = timetable;
    });
  }

  Future<void> openItem(CalendarItem item) async {
    if (!timetableView) {
      await showCalendarItem(context, c, item);
      return;
    }
    final table = c.classroom
        .where((d) => d.kind == ClassroomKind.timetable)
        .firstOrNull;
    if (table == null || table.deleted) return;
    if (item.category == 'lesson') {
      await showTimetableBlockEditor(
        context,
        c,
        table,
        document: item.document,
      );
    } else if (item.document != null) {
      await showClassroomEditor(
        context,
        c,
        item.document!.kind,
        document: item.document,
      );
    }
  }

  Timer? ticker;
  bool weekends = false, showCompleted = false;
  final calendarScroll = ScrollController(),
      timetableScroll = ScrollController();
  ScrollController get scroll =>
      timetableView ? timetableScroll : calendarScroll;
  @override
  void initState() {
    super.initState();
    timetableView = widget.initialTimetable;
    if (timetableView) {
      final table =
          c.classroom
              .where((d) => d.kind == ClassroomKind.timetable)
              .firstOrNull ??
          flexTimetableTemplate().first;
      timetableDate = calendarDate.isBefore(schoolDay(table.text('date')))
          ? schoolDay(table.text('date'))
          : calendarDate;
    }
    if (widget.shortcutDate != null) selected = widget.shortcutDate!;
    WidgetsBinding.instance.addObserver(this);
    ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shortcutDate != null &&
        (widget.shortcutDate != oldWidget.shortcutDate ||
            widget.shortcutRevision != oldWidget.shortcutRevision)) {
      selected = widget.shortcutDate!;
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    calendarScroll.dispose();
    timetableScroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void navigate(VoidCallback update) {
    setState(update);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

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

  void step(int direction) => navigate(
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
    const fields = importedLessonFields;
    bool same(ClassroomDocument d) =>
        existing[d.id] != null &&
        !existing[d.id]!.deleted &&
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
        mergeImportedLesson(existing[d.id], d),
    ]);
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    await guarded(context, action);
    if (mounted) setState(() => busy = false);
  }

  Future<void> pickDay() async {
    final result = await pickFlexDate(
      context,
      date: dateOnly(selected),
      allowTime: false,
    );
    if (result != null && mounted) {
      navigate(() => selected = schoolDay(result.$1));
    }
  }

  void openDay(DateTime day) => navigate(() {
    selected = day;
    mode = 'day';
  });

  Future<void> chooseFilters() async {
    final next = filters.toSet();
    var completed = showCompleted;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FlexModal(
          title: const Text('Kalender filtern'),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in calendarCategories.entries)
                CheckboxListTile(
                  title: Text(e.value),
                  value: next.contains(e.key),
                  onChanged: (v) => update(() {
                    if (v == true) {
                      next.add(e.key);
                    } else {
                      next.remove(e.key);
                    }
                  }),
                ),
              const Divider(),
              CheckboxListTile(
                title: const Text('Erledigte Einträge anzeigen'),
                value: completed,
                onChanged: (v) => update(() => completed = v == true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => update(() {
                next.addAll(calendarCategories.keys);
                completed = false;
              }),
              child: const Text('Zurücksetzen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anwenden'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      navigate(() {
        filters
          ..clear()
          ..addAll(next);
        showCompleted = completed;
      });
    }
  }

  Future<void> addEntry() async {
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => FlexModal(
        title: Text('Anlegen · ${displayDate(dateOnly(selected))}'),
        onClose: () => Navigator.pop(ctx),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in const [
              ('lesson', 'Unterricht', Icons.school_outlined),
              ('appointment', 'Termin', Icons.event_outlined),
              ('task', 'Aufgabe', Icons.task_alt),
              ('return', 'Rücklauf', Icons.fact_check_outlined),
              ('holiday', 'Ferien / Ausfall', Icons.beach_access_outlined),
            ])
              ListTile(
                leading: Icon(e.$3),
                title: Text(e.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, e.$1),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final date = dateOnly(selected);
    if (kind == 'appointment' || kind == 'task') {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OrgaEditor(
          controller: c,
          entry: kind == 'appointment'
              ? OrgaEntry.empty().copyWith(appointmentDate: date)
              : OrgaEntry.empty().copyWith(isTask: true, dueDate: date),
        ),
      );
    } else {
      await showClassroomEditor(context, c, switch (kind) {
        'lesson' => ClassroomKind.lesson,
        'return' => ClassroomKind.returnList,
        _ => ClassroomKind.holiday,
      }, date: date);
    }
  }

  Future<void> showItems(String title, List<CalendarItem> items) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => FlexModal(
          title: Text(title),
          onClose: () => Navigator.pop(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(calendarIcon(item.category)),
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      if (item.time.isNotEmpty) item.time,
                      if (item.detail.isNotEmpty) item.detail,
                      displayDate(item.date),
                      if (item.done) 'Erledigt',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showCalendarItem(ctx, c, item),
                ),
            ],
          ),
        ),
      );

  Widget dueStrip(List<CalendarItem> items, {String? label}) {
    final due = items.where(calendarDue).toList();
    if (due.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label ??
                    (dateOnly(selected) == dateOnly(now)
                        ? 'Heute fällig'
                        : 'Fällig am ${displayDate(dateOnly(selected))}'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  for (final category in const [
                    'task',
                    'homework',
                    'goal',
                    'return',
                  ])
                    if (due.any((i) => i.category == category))
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(44, 40),
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () => showItems(
                          calendarCategories[category]!,
                          due.where((i) => i.category == category).toList(),
                        ),
                        icon: Icon(calendarIcon(category), size: 17),
                        label: Text(
                          '${due.where((i) => i.category == category).length} ${due.where((i) => i.category == category).length == 1 ? const {'task': 'Aufgabe', 'homework': 'HÜ', 'goal': 'Ziel', 'return': 'Rücklauf'}[category] : calendarCategories[category]}',
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget dayExtras(List<CalendarItem> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final item in items.where(
        (i) => !calendarTimed(i) && !calendarDue(i),
      ))
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(calendarIcon(item.category), size: 20),
          title: Text(item.title),
          subtitle: Text(
            item.category == 'holiday'
                ? 'Unterrichtsfrei / Ausfall'
                : 'Ohne Uhrzeit',
          ),
          onTap: () => showCalendarItem(context, c, item),
        ),
    ],
  );

  Widget dayBody(List<CalendarItem> items) {
    final timed = items.where(calendarTimed).toList();
    final active = currentCalendarItem(timed, now),
        next = nextCalendarItem(timed, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dueStrip(items),
        dayExtras(items),
        if (dateOnly(selected) == dateOnly(now) &&
            (active != null || next != null))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              active != null
                  ? 'Jetzt · ${active.title} bis ${active.end}'
                  : 'Als Nächstes · ${next!.time} ${next.title}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        if (timed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Text(
              timetableView
                  ? 'Kein Unterricht an diesem Tag.'
                  : filters.isEmpty
                  ? 'Keine Bereiche ausgewählt.'
                  : 'Keine Stunden oder Termine mit Uhrzeit.',
            ),
          ),
        CalendarTimeline(
          days: [selected],
          items: timed,
          now: now,
          selectedDate: dateOnly(selected),
          onOpen: openItem,
          showBlockDetails: timetableView,
          onDay: openDay,
        ),
      ],
    );
  }

  Widget weekBody(List<CalendarItem> items) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final weekendEvents = items
        .where((i) => schoolDay(i.date).weekday > 5)
        .toList();
    final showWeekend =
        weekends || selected.weekday > 5 || weekendEvents.isNotEmpty;
    final days = [
      for (var i = 0; i < (showWeekend ? 7 : 5); i++)
        monday.add(Duration(days: i)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dueStrip(items, label: 'Diese Woche fällig'),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              timetableView ? 'Unterricht' : 'Stunden & Termine',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton(
              onPressed: weekendEvents.isNotEmpty || selected.weekday > 5
                  ? null
                  : () => setState(() => weekends = !weekends),
              child: Text(showWeekend ? 'Sa/So sichtbar' : 'Sa/So anzeigen'),
            ),
          ],
        ),
        if (!items.any(calendarTimed))
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Noch kein Unterricht in dieser Woche.'),
          ),
        CalendarTimeline(
          week: true,
          days: days,
          items: items.where(calendarTimed).toList(),
          now: now,
          selectedDate: dateOnly(selected),
          onDay: openDay,
          onOpen: openItem,
          showBlockDetails: timetableView,
        ),
        for (final day in days) ...[
          if (items.any((i) => i.date == dateOnly(day) && !calendarTimed(i)))
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: InkWell(
                onTap: () => openDay(day),
                child: Text(
                  '${calendarWeekday(day)} · ${displayDate(dateOnly(day))}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          dueStrip(
            items.where((i) => i.date == dateOnly(day)).toList(),
            label: 'Fälligkeiten',
          ),
          dayExtras(items.where((i) => i.date == dateOnly(day)).toList()),
        ],
      ],
    );
  }

  Widget monthBody(List<CalendarItem> items) {
    final first = DateTime.utc(selected.year, selected.month, 1);
    final length = DateTime.utc(selected.year, selected.month + 1, 0).day;
    final dayItems = items.where((i) => i.date == dateOnly(selected)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final d in const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        LayoutBuilder(
          builder: (ctx, box) {
            final cellWidth = box.maxWidth / 7;
            final cellHeight = math.max(
              50.0,
              MediaQuery.textScalerOf(ctx).scale(34),
            );
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: cellWidth / cellHeight,
              ),
              itemCount: first.weekday - 1 + length,
              itemBuilder: (ctx, index) {
                if (index < first.weekday - 1) return const SizedBox.shrink();
                final day = DateTime.utc(
                  selected.year,
                  selected.month,
                  index - first.weekday + 2,
                );
                final entries = items
                    .where((i) => i.date == dateOnly(day))
                    .toList();
                final scheme = Theme.of(ctx).colorScheme;
                final today = dateOnly(day) == dateOnly(now);
                return Semantics(
                  label:
                      '${calendarWeekday(day)}, ${displayDate(dateOnly(day))}, ${entries.length} Einträge',
                  selected: day == selected,
                  button: true,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: day == selected
                          ? scheme.primary.withValues(alpha: .2)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: today ? scheme.primary : Colors.transparent,
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('calendar-month-${dateOnly(day)}'),
                        onTap: () => setState(() => selected = day),
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              maxLines: 1,
                              style: Theme.of(
                                ctx,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            if (entries.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final category in [
                                    'lesson',
                                    'appointment',
                                    'due',
                                  ])
                                    if (entries.any(
                                      (i) => category == 'due'
                                          ? calendarDue(i)
                                          : i.category == category,
                                    ))
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: category == 'lesson'
                                              ? scheme.primary
                                              : category == 'appointment'
                                              ? const Color(0xff829fb8)
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                  if (entries.every(
                                    (i) => i.category == 'holiday',
                                  ))
                                    const Icon(Icons.remove, size: 12),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final marker in [
              ('Unterricht', Theme.of(context).colorScheme.primary),
              ('Termine', const Color(0xff829fb8)),
              ('Fällig', Theme.of(context).colorScheme.onSurfaceVariant),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: marker.$2),
                  const SizedBox(width: 5),
                  Text(marker.$1, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${calendarWeekday(selected)} · ${displayDate(dateOnly(selected))}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Tagesansicht öffnen',
              onPressed: () => openDay(selected),
              icon: const Icon(Icons.open_in_full, size: 18),
            ),
          ],
        ),
        dueStrip(dayItems),
        dayExtras(dayItems),
        if (dayItems.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Keine Einträge an diesem Tag.'),
          ),
        for (final item in dayItems.where(calendarTimed))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(item.time),
            title: Text(item.title),
            subtitle: Text(item.detail),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showCalendarItem(context, c, item),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final bounds = range;
        final existingTable = c.classroom
            .where((d) => d.kind == ClassroomKind.timetable)
            .firstOrNull;
        final timetableDocuments = existingTable == null
            ? flexTimetableTemplate()
            : c.classroom;
        final table = existingTable ?? timetableDocuments.first;
        final items = timetableView
            ? <CalendarItem>[
                if (!table.deleted)
                  for (final lesson in lessonOccurrences(
                    timetableDocuments,
                    bounds.from,
                    bounds.to,
                  ).where((l) => l.document.text('timetableId') == table.id))
                    CalendarItem(
                      id: lesson.target,
                      date: lesson.date,
                      title: lesson.title,
                      category: 'lesson',
                      time: lesson.start,
                      end: lesson.end,
                      document: lesson.document,
                      lesson: lesson,
                      detail: [
                        blockPeriodLabel(table, lesson.document),
                        lesson.document.text('teacher'),
                        lesson.document.text('room'),
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                for (final holiday in timetableDocuments.where(
                  (d) =>
                      !d.deleted &&
                      d.kind == ClassroomKind.holiday &&
                      d.text('date').compareTo(bounds.to) <= 0 &&
                      d.text('endDate').compareTo(bounds.from) >= 0,
                ))
                  CalendarItem(
                    id: holiday.id,
                    date: holiday.text('date').compareTo(bounds.from) < 0
                        ? bounds.from
                        : holiday.text('date'),
                    title: holiday.title,
                    category: 'holiday',
                    document: holiday,
                  ),
              ]
            : calendarItems(c.currentSnapshot, bounds.from, bounds.to)
                  .where(
                    (i) =>
                        filters.contains(i.category) &&
                        (showCompleted || !i.done),
                  )
                  .toList();
        final filtered =
            filters.length != calendarCategories.length || showCompleted;
        final scheme = Theme.of(ctx).colorScheme;
        final largeText =
            MediaQuery.textScalerOf(ctx).scale(1) > 1.4 &&
            MediaQuery.sizeOf(ctx).width < 600;
        final content = Column(
          key: ValueKey(timetableView ? 'timetable-view' : 'calendar-view'),
          children: [
            if (widget.onSwitchSection == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                child: Material(
                  color: scheme.onSurface.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      for (final tab in const [
                        (false, 'Kalender'),
                        (true, 'Stundenplan'),
                      ])
                        Expanded(
                          child: Semantics(
                            selected: timetableView == tab.$1,
                            child: TextButton(
                              key: ValueKey(
                                'calendar-section-${tab.$1 ? 'timetable' : 'calendar'}',
                              ),
                              onPressed: () => selectSection(tab.$1),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                backgroundColor: timetableView == tab.$1
                                    ? scheme.primary.withValues(alpha: .2)
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(tab.$2, textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Vorheriger Zeitraum',
                    onPressed: () => step(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: pickDay,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 4,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mode == 'month'
                                ? '${calendarMonth(selected)} ${selected.year}'
                                : mode == 'week'
                                ? 'Woche'
                                : calendarWeekday(selected),
                            textAlign: TextAlign.center,
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                          if (mode != 'month')
                            Text(
                              mode == 'day'
                                  ? displayDate(dateOnly(selected))
                                  : '${displayDate(bounds.from)} – ${displayDate(bounds.to)}',
                              textAlign: TextAlign.center,
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nächster Zeitraum',
                    onPressed: () => step(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton(
                    onPressed: () =>
                        navigate(() => selected = schoolDay(dateOnly(now))),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text('Heute'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: scheme.onSurface.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          for (final e in {
                            'day': 'Tag',
                            'week': 'Woche',
                            if (!timetableView) 'month': 'Monat',
                          }.entries)
                            Expanded(
                              flex: largeText && !timetableView
                                  ? (e.key == 'day' ? 3 : 5)
                                  : 1,
                              child: Semantics(
                                selected: mode == e.key,
                                child: TextButton(
                                  key: ValueKey(
                                    '${timetableView ? 'timetable' : 'calendar'}-mode-${e.key}',
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    backgroundColor: mode == e.key
                                        ? scheme.primary.withValues(alpha: .2)
                                        : Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => navigate(() => mode = e.key),
                                  child: Text(
                                    e.value,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!timetableView) ...[
                    const SizedBox(width: 6),
                    if (largeText)
                      IconButton(
                        tooltip: filtered ? 'Filter aktiv' : 'Filter',
                        onPressed: chooseFilters,
                        icon: Icon(
                          filtered
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: chooseFilters,
                        icon: Icon(
                          filtered
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                          size: 18,
                        ),
                        label: Text(filtered ? 'Filter ·' : 'Filter'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                controller: scroll,
                key: PageStorageKey(
                  timetableView ? 'timetable-page' : 'calendar-page',
                ),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  if (timetableView) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Gültig ab ${displayDate(table.text('date'))}${table.text('endDate').isEmpty ? '' : ' bis ${displayDate(table.text('endDate'))}'}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    if (existingTable == null) ...[
                      const Text(
                        'Vorlage aus deinem PDF. Vorhandene Kalendereinträge bleiben erhalten.',
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Stundenplan übernehmen'),
                        onPressed: () =>
                            run(() => c.saveClassroomBatch(timetableDocuments)),
                      ),
                    ] else if (table.deleted)
                      FilledButton.icon(
                        icon: const Icon(Icons.restore),
                        label: const Text('Stundenplan wiederherstellen'),
                        onPressed: () => run(
                          () =>
                              c.saveClassroom(table.patch({'deleted': false})),
                        ),
                      ),
                  ],
                  if (mode == 'day')
                    dayBody(items)
                  else if (mode == 'week')
                    weekBody(items)
                  else
                    monthBody(items),
                  if (!timetableView)
                    for (final plan in c.classroom.where(
                      (p) => planOnDay(p, dateOnly(selected)),
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_note_outlined),
                        title: Text(plan.title),
                        subtitle: Text(
                          planStatuses[plan.text('status', 'planned')]!,
                        ),
                        onTap: () => showMaterialCollection(ctx, c, plan),
                      ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Material(
                color: scheme.surfaceContainerHigh.withValues(alpha: .7),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      for (final action
                          in timetableView
                              ? [
                                  (
                                    'Block hinzufügen',
                                    Icons.add,
                                    () => showTimetableBlockEditor(
                                      ctx,
                                      c,
                                      table,
                                      weekday: selected.weekday,
                                    ),
                                  ),
                                  (
                                    'Stundenzeiten',
                                    Icons.schedule,
                                    () => showTimetableHours(ctx, c, table),
                                  ),
                                  (
                                    'Verwalten',
                                    Icons.edit_calendar_outlined,
                                    () =>
                                        showTimetableManagement(ctx, c, table),
                                  ),
                                ]
                              : [
                                  ('Anlegen', Icons.add, addEntry),
                                  (
                                    'Unterlagen',
                                    Icons.folder_open_outlined,
                                    () => showPreparedMaterials(
                                      ctx,
                                      c,
                                      date: dateOnly(selected),
                                    ),
                                  ),
                                  (
                                    'Verwalten',
                                    Icons.edit_calendar_outlined,
                                    () => showCalendarManagement(
                                      ctx,
                                      c,
                                      date: dateOnly(selected),
                                      openTimetable: () => selectSection(true),
                                      importCalendar: () => run(importIcs),
                                      exportCalendar: () => run(() async {
                                        await saveTextFile(
                                          'FLEX-Kalender-${bounds.from}.ics',
                                          exportCalendarIcs(items),
                                          mime: 'text/calendar',
                                        );
                                      }),
                                    ),
                                  ),
                                ])
                        SizedBox(
                          width:
                              (MediaQuery.sizeOf(ctx).width - 16) /
                              (largeText ? 2 : 3),
                          child: TextButton(
                            onPressed:
                                busy ||
                                    (timetableView &&
                                        (existingTable == null ||
                                            table.deleted))
                                ? null
                                : action.$3,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!largeText) Icon(action.$2, size: 22),
                                Text(
                                  action.$1,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        return LayoutBuilder(
          builder: (_, constraints) {
            final minimum = 420 * MediaQuery.textScalerOf(ctx).scale(1);
            if (constraints.maxHeight >= minimum) return content;
            return SingleChildScrollView(
              child: SizedBox(height: minimum, child: content),
            );
          },
        );
      },
    );
  }
}
