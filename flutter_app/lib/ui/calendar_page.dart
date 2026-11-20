import 'material_thumbnail.dart';
import 'app_navigation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../application/notebook_controller.dart';
import '../domain/backup_merge.dart';
import '../domain/calendar.dart';
import '../domain/calendar_edit.dart';
import '../domain/calendar_layout.dart';
import '../domain/classroom.dart';
import '../domain/material_workspace.dart';
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
import 'return_lists.dart';
import 'school_workspace.dart';
import 'calendar_timeline.dart';
import 'calendar_toolbar.dart';
import 'document_attachments.dart';
import '../domain/document_scanner.dart';
import 'timetable.dart';

part 'calendar_detail.dart';
part 'calendar_management.dart';
part 'calendar_month.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.controller,
    this.clock,
    this.onDateChanged,
  });
  final DateTime Function()? clock;
  final NotebookController controller;
  final ValueChanged<String>? onDateChanged;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const _modes = ['day', 'week', 'month'];
  DateTime get now => widget.clock?.call() ?? DateTime.now();
  late DateTime selected = schoolDay(dateOnly(now));
  late String mode;
  late String _configuredDefault;
  int periodDirection = 1;
  int transitionSerial = 0;
  final nowMarker = GlobalKey();
  final agendaHeading = GlobalKey();
  final scroll = ScrollController();
  Timer? ticker;
  bool? weekends;
  bool showCompleted = false;

  bool showWeekends(List<CalendarItem> items) =>
      weekends ??
      (selected.weekday > DateTime.friday ||
          items.any((item) => schoolDay(item.date).weekday > DateTime.friday));

  Future<void> openItem(CalendarItem item) =>
      showCalendarItem(context, c, item);

  @override
  void initState() {
    super.initState();
    mode = _configuredDefault = c.appearance.calendarDefaultView;
    c.addListener(_defaultChanged);
    WidgetsBinding.instance.addObserver(this);
    ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    c.removeListener(_defaultChanged);
    ticker?.cancel();
    scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != c) {
      oldWidget.controller.removeListener(_defaultChanged);
      c.addListener(_defaultChanged);
      _defaultChanged();
    }
  }

  void _defaultChanged() {
    final next = c.appearance.calendarDefaultView;
    if (!mounted || next == _configuredDefault) return;
    _configuredDefault = next;
    changeMode(next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void goToNow() {
    setState(() => selected = schoolDay(dateOnly(now)));
    widget.onDateChanged?.call(dateOnly(selected));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = nowMarker.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .28,
          duration: const Duration(milliseconds: 250),
        );
      } else if (scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void navigate(VoidCallback update) {
    setState(() {
      update();
      transitionSerial++;
    });
    widget.onDateChanged?.call(dateOnly(selected));
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

  void step(int direction) {
    periodDirection = direction;
    navigate(
      () => selected = mode == 'month'
          ? DateTime.utc(selected.year, selected.month + direction, 1)
          : selected.add(Duration(days: direction * (mode == 'week' ? 7 : 1))),
    );
  }

  void changeMode(String value, {int? direction}) {
    periodDirection =
        direction ?? (_modes.indexOf(value) > _modes.indexOf(mode) ? 1 : -1);
    navigate(() => mode = value);
  }

  void swipeMode(bool towardEnd) {
    final direction = towardEnd ? 1 : -1;
    final step = c.appearance.navigationSwipeNext == 'right'
        ? direction
        : -direction;
    changeMode(
      _modes[(_modes.indexOf(mode) + step) % _modes.length],
      direction: -direction,
    );
  }

  Widget periodSurface(Widget child) => FlexNavigationSwipe(
    key: const ValueKey('calendar-period-swipe'),
    onStep: (previous) => step(previous ? -1 : 1),
    child: child,
  );

  Future<void> createAppointment(DateTime day, String time) async {
    navigate(() => selected = schoolDay(dateOnly(day)));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrgaEditor(
        controller: c,
        defaultToClassTask: false,
        entry: OrgaEntry.empty().copyWith(
          appointmentDate: dateOnly(day),
          appointmentTime: time,
        ),
      ),
    );
  }

  Future<void> editCalendarTime(CalendarItem item, CalendarEdit edit) async {
    if (busy) return;
    await run(() async {
      final entry = item.entry;
      final lesson = item.lesson;
      Future<void> Function()? undo;
      if (entry != null) {
        await c.saveEntry(edit.applyToEntry(entry));
        undo = () => c.saveEntry(entry.copyWith(revision: entry.revision + 1));
      } else if (lesson != null) {
        await c.saveClassroom(edit.applyToLesson(lesson));
        undo = () => c.saveClassroom(
          lesson.document.patch({'revision': lesson.document.revision + 1}),
        );
      }
      if (!mounted || undo == null) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${lesson == null ? 'Termin' : 'Diese Stunde'}: ${displayDate(edit.date)} · ${edit.startTime}–${edit.endTime}',
          ),
          action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: () => guarded(context, undo!),
          ),
        ),
      );
    });
  }

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
                  secondary: PopupMenuButton<String>(
                    tooltip: 'Eintragsart wählen',
                    icon: Icon(
                      d.calendarCategory == 'lesson'
                          ? Icons.school_outlined
                          : Icons.event_outlined,
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'appointment',
                        child: Text('Termin'),
                      ),
                      PopupMenuItem(value: 'lesson', child: Text('Unterricht')),
                    ],
                    onSelected: (kind) => update(() {
                      final index = preview.documents.indexOf(d);
                      preview.documents[index] = d.patch({
                        'calendarCategory': kind,
                      });
                      chosen.add(d.id);
                    }),
                  ),
                  subtitle: Text(
                    '${d.calendarCategory == 'lesson' ? 'Unterricht' : 'Termin'} · '
                    '${same(d)
                        ? 'Bereits vorhanden'
                        : existing.containsKey(d.id)
                        ? 'Bisher: ${existing[d.id]!.title} · ${displayDate(existing[d.id]!.text('date'))}\nImport: ${displayDate(d.text('date'))} ${d.text('start')} – ausgewählte Felder werden ersetzt'
                        : '${displayDate(d.text('date'))} ${d.text('start').isEmpty ? 'Ganztägig' : d.text('start')}'}',
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

  Widget dueStrip(List<CalendarItem> items, {String? label, Widget? trailing}) {
    final due = items.where(calendarDue).toList();
    if (due.isEmpty) return trailing ?? const SizedBox.shrink();
    if (label == null && due.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10, right: 10),
              child: Text('Fällig', style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in due)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => showCalendarItem(context, c, item),
                        icon: Icon(calendarIcon(item.category), size: 19),
                        label: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label ??
                (dateOnly(selected) == dateOnly(now)
                    ? 'Heute fällig'
                    : 'Fällig am ${displayDate(dateOnly(selected))}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final category in const ['task', 'homework', 'goal', 'return'])
            if (due.any((i) => i.category == category))
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(44, 40),
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () => showItems(
                  calendarCategories[category]!,
                  due.where((i) => i.category == category).toList(),
                ),
                icon: Icon(calendarIcon(category), size: 16),
                label: Text(
                  '${due.where((i) => i.category == category).length} ${due.where((i) => i.category == category).length == 1 ? const {'task': 'Aufgabe', 'homework': 'HÜ', 'goal': 'Ziel', 'return': 'Rücklauf'}[category] : calendarCategories[category]}',
                ),
              ),
          ?trailing,
        ],
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

  Widget dayBody(List<CalendarItem> items, double height) {
    final timed = items.where(calendarTimed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dueStrip(items),
        dayExtras(items),
        if (timed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              filters.isEmpty
                  ? 'Keine Bereiche ausgewählt.'
                  : 'Keine Stunden oder Termine mit Uhrzeit.',
            ),
          ),
        periodSurface(
          CalendarTimeline(
            days: [selected],
            items: timed,
            now: now,
            nowMarkerKey: nowMarker,
            selectedDate: dateOnly(selected),
            onOpen: openItem,
            showBlockDetails: true,
            onDay: openDay,
            onCreate: createAppointment,
            onChange: editCalendarTime,
            minimumHeight: height,
          ),
        ),
      ],
    );
  }

  Widget weekBody(List<CalendarItem> items, double height) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final weekendEvents = items
        .where((i) => schoolDay(i.date).weekday > 5)
        .toList();
    final showWeekend = showWeekends(items);
    final days = [
      for (var i = 0; i < (showWeekend ? 7 : 5); i++)
        monday.add(Duration(days: i)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dueStrip(
          items,
          label: 'Fällig',
          trailing: !showWeekend && weekendEvents.isNotEmpty
              ? TextButton.icon(
                  key: const ValueKey('calendar-hidden-weekend-entries'),
                  onPressed: () => setState(() => weekends = true),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text('Sa/So · ${weekendEvents.length}'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    minimumSize: const Size(44, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                )
              : null,
        ),
        periodSurface(
          CalendarTimeline(
            week: true,
            days: days,
            items: items.where(calendarTimed).toList(),
            now: now,
            nowMarkerKey: nowMarker,
            selectedDate: dateOnly(selected),
            onDay: openDay,
            onOpen: openItem,
            showBlockDetails: true,
            onCreate: createAppointment,
            onChange: editCalendarTime,
            minimumHeight: height,
          ),
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

  void previewMonthDay(DateTime day) {
    final sameMonth = day.month == selected.month && day.year == selected.year;
    if (!sameMonth) periodDirection = day.isBefore(selected) ? -1 : 1;
    navigate(() => selected = day);
    if (!sameMonth) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final heading = agendaHeading.currentContext;
      if (heading != null) {
        Scrollable.ensureVisible(
          heading,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: FlexTabTransition.duration,
        );
      }
    });
  }

  Widget monthBody(List<CalendarItem> items) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final dayItems = items.where((i) => i.date == dateOnly(selected)).toList();
    final timed = dayItems.where(calendarTimed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        periodSurface(
          _MonthGrid(
            selected: selected,
            today: now,
            items: items,
            onCreate: (day) => createAppointment(day, ''),
            onPreview: previewMonthDay,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Wrap(
            spacing: 14,
            children: [
              for (final marker in [
                ('Termine', calendarAccent(colors, 'appointment')),
                ('Fällig', calendarAccent(colors, 'due')),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: marker.$2),
                    const SizedBox(width: 5),
                    Text(
                      marker.$1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Material(
          color: colors.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .75),
              width: .7,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                key: agendaHeading,
                padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${calendarWeekday(selected)}, ${selected.day}. ${calendarMonth(selected)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tagesansicht öffnen',
                      onPressed: () => openDay(selected),
                      icon: const Icon(Icons.open_in_full, size: 17),
                    ),
                  ],
                ),
              ),
              if (dayItems.any((i) => !calendarTimed(i)))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [dueStrip(dayItems), dayExtras(dayItems)],
                  ),
                ),
              if (dayItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Text(
                    'Keine Einträge an diesem Tag.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              for (final item in timed) ...[
                Divider(
                  height: 1,
                  thickness: .6,
                  indent: 12,
                  endIndent: 12,
                  color: colors.outlineVariant.withValues(alpha: .7),
                ),
                _AgendaRow(
                  key: ValueKey('calendar-month-entry-${item.id}'),
                  item: item,
                  onOpen: () => openItem(item),
                ),
              ],
            ],
          ),
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
        final items = calendarItems(c.currentSnapshot, bounds.from, bounds.to)
            .where(
              (i) => filters.contains(i.category) && (showCompleted || !i.done),
            )
            .toList();
        final filtered =
            filters.length != calendarCategories.length || showCompleted;
        final content = Column(
          key: const ValueKey('calendar-view'),
          children: [
            Padding(
              padding: FlexPagePills.pagePadding,
              child: FlexPagePills(
                key: const ValueKey('calendar-mode-navigation'),
                keyPrefix: 'calendar-mode',
                pages: const {0: 'Tag', 1: 'Woche', 2: 'Monat'},
                selected: _modes.indexOf(mode),
                onSelected: (index) => changeMode(_modes[index]),
              ),
            ),
            Padding(
              key: const ValueKey('calendar-toolbar'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: CalendarToolbar(
                period: mode == 'month'
                    ? '${calendarMonth(selected)} ${selected.year}'
                    : mode == 'week'
                    ? '${schoolDay(bounds.from).day}.${schoolDay(bounds.from).month == schoolDay(bounds.to).month ? '' : '${schoolDay(bounds.from).month}.'}–${schoolDay(bounds.to).day}.${schoolDay(bounds.to).month}.'
                    : '${calendarWeekday(selected, short: true)}, ${selected.day}.${selected.month}.',
                compactPeriod: mode == 'week'
                    ? 'KW\n${isoCalendarWeek(selected)}'
                    : mode == 'month'
                    ? '${calendarMonth(selected).substring(0, 3)}\n${(selected.year % 100).toString().padLeft(2, '0')}'
                    : '${selected.day}.\n${calendarMonth(selected).substring(0, 3)}',
                periodLabel: mode == 'month'
                    ? '${calendarMonth(selected)} ${selected.year}'
                    : calendarRangeLabel(
                        schoolDay(bounds.from),
                        schoolDay(bounds.to),
                      ),
                previous: () => step(-1),
                next: () => step(1),
                chooseDate: pickDay,
                today: goToNow,
                lessons: filters.contains('lesson'),
                toggleLessons: () => setState(() {
                  filters.contains('lesson')
                      ? filters.remove('lesson')
                      : filters.add('lesson');
                }),
                filtered: filtered,
                filter: chooseFilters,
                materials: busy
                    ? null
                    : () => showPreparedMaterials(
                        ctx,
                        c,
                        date: dateOnly(selected),
                      ),
                manage: busy
                    ? null
                    : () => showCalendarManagement(
                        ctx,
                        c,
                        date: dateOnly(selected),
                        chooseFilter: chooseFilters,
                        materials: () => showPreparedMaterials(
                          ctx,
                          c,
                          date: dateOnly(selected),
                        ),
                        showWeekends: showWeekends(items),
                        onWeekendsChanged: (value) =>
                            setState(() => weekends = value),
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
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: LayoutBuilder(
                builder: (_, viewport) => FlexTabTransition(
                  section: 0,
                  index: transitionSerial,
                  direction: periodDirection,
                  child: ListView(
                    controller: scroll,
                    key: const PageStorageKey('calendar-page'),
                    padding: EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      mode == 'month' ? 80 : 0,
                    ),
                    children: [
                      if (mode == 'day')
                        dayBody(items, viewport.maxHeight)
                      else if (mode == 'week')
                        weekBody(items, viewport.maxHeight)
                      else
                        monthBody(items),
                      for (final plan in c.classroom.where(
                        (p) =>
                            planOnDay(p, dateOnly(selected)) &&
                            p.map('flow').isEmpty,
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
              ),
            ),
          ],
        );
        return FlexNavigationSwipe(
          key: const ValueKey('calendar-view-swipe'),
          onStep: swipeMode,
          child: LayoutBuilder(
            builder: (_, constraints) {
              final minimum = 420 * MediaQuery.textScalerOf(ctx).scale(1);
              if (constraints.maxHeight >= minimum) return content;
              return SingleChildScrollView(
                child: SizedBox(height: minimum, child: content),
              );
            },
          ),
        );
      },
    );
  }
}
