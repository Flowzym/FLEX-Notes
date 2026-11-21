part of 'workspace.dart';

extension _CalendarView on _DesktopWorkspaceState {
  Widget calendar() {
    final days = calendarView == 'Tag'
        ? [calendarDay(c.date, 0)]
        : weekOf(c.date).take(weekends ? 7 : 5).toList();
    final items = calendarItems(
      c.notebook.currentSnapshot,
      dateOnly(days.first),
      dateOnly(days.last),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 0),
          child: SectionHeading(
            'Kalender',
            subtitle: 'Unterricht, Termine und Fristen an einem Ort.',
            actions: [
              IconButton(
                tooltip: 'Unterricht anlegen',
                onPressed: () => run(() => newDesktopEntry(EntryKind.lesson)),
                icon: const Icon(Icons.school_outlined),
              ),
              IconButton(
                tooltip: 'Termin anlegen',
                onPressed: () =>
                    run(() => newDesktopEntry(EntryKind.appointment)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final label in ['Tag', 'Woche', 'Monat'])
                    ButtonSegment(
                      value: label,
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                    ),
                ],
                selected: {calendarView},
                onSelectionChanged: (v) => redraw(() => calendarView = v.first),
              ),
              IconButton(
                tooltip: 'Vorheriger Zeitraum',
                onPressed: () => stepCalendar(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                calendarView == 'Monat'
                    ? '${monthName(c.date)} ${c.date.year}'
                    : calendarView == 'Tag'
                    ? '${dayName(c.date)}, ${c.date.day}. ${monthName(c.date)}'
                    : weekRange(days.first, days.last),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              IconButton(
                tooltip: 'Nächster Zeitraum',
                onPressed: () => stepCalendar(1),
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: () => c.setDate(DateTime.now()),
                child: const Text('Heute'),
              ),
              if (calendarView == 'Woche')
                FilterChip(
                  label: const Text('Sa / So', style: TextStyle(fontSize: 10)),
                  selected: weekends,
                  onSelected: (v) => redraw(() => weekends = v),
                ),
            ],
          ),
        ),
        Expanded(
          child: calendarView == 'Monat'
              ? monthGrid()
              : LayoutBuilder(
                  builder: (ctx, box) {
                    const hourHeight = 56.0;
                    return Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 56),
                            for (final day in days)
                              Expanded(
                                child: Container(
                                  height: 64,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color:
                                        dateOnly(day) ==
                                            dateOnly(DateTime.now())
                                        ? wash
                                        : white,
                                    border: const Border(
                                      left: BorderSide(color: line),
                                      bottom: BorderSide(color: line),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        dayName(
                                          day,
                                        ).substring(0, 2).toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: muted,
                                        ),
                                      ),
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              dateOnly(day) ==
                                                  dateOnly(DateTime.now())
                                              ? olive
                                              : ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (items.any((i) => i.time.isEmpty))
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            color: wash.withValues(alpha: .4),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 56,
                                  child: Center(
                                    child: Text(
                                      'Fristen',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                ),
                                for (final day in days)
                                  Expanded(
                                    child: Column(
                                      children: [
                                        for (final item in items.where(
                                          (i) =>
                                              i.date == dateOnly(day) &&
                                              i.time.isEmpty,
                                        ))
                                          InkWell(
                                            onTap: () => viewCalendarItem(item),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3),
                                              child: Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: item.done
                                                      ? muted
                                                      : olive,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: calendarScroll,
                            child: SizedBox(
                              height: hourHeight * 24,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 56,
                                    child: Stack(
                                      children: [
                                        for (var hour = 0; hour <= 23; hour++)
                                          Positioned(
                                            top: hour * hourHeight + 3,
                                            left: 12,
                                            child: Text(
                                              '${hour.toString().padLeft(2, '0')}:00',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: muted,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  for (final day in days)
                                    Expanded(
                                      child: dayColumn(
                                        day,
                                        items
                                            .where(
                                              (i) =>
                                                  i.date == dateOnly(day) &&
                                                  i.time.isNotEmpty,
                                            )
                                            .toList(),
                                        hourHeight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  void stepCalendar(int direction) => c.setDate(
    calendarView == 'Monat'
        ? DateTime(c.date.year, c.date.month + direction, 1)
        : calendarDay(c.date, direction * (calendarView == 'Woche' ? 7 : 1)),
  );
  Widget dayColumn(DateTime day, List<CalendarItem> items, double hourHeight) {
    final positioned = calendarLanes(items);
    return LayoutBuilder(
      builder: (ctx, box) => Stack(
        children: [
          Column(
            children: [
              for (var slot = 0; slot < 48; slot++)
                DragTarget<CalendarItem>(
                  onWillAcceptWithDetails: (detail) =>
                      detail.data.entry?.isAppointment == true,
                  onAcceptWithDetails: (detail) => run(
                    () => c.moveAppointment(
                      detail.data,
                      day,
                      minutesClock(slot * 30),
                    ),
                  ),
                  builder: (ctx, candidate, rejected) => InkWell(
                    onTap: () => run(() async {
                      await newDesktopEntry(
                        EntryKind.appointment,
                        onDate: day,
                        fields: {
                          'appointmentTime': minutesClock(slot * 30),
                          'appointmentEndTime': minutesClock(
                            (60 + slot * 30).clamp(0, 1440),
                          ),
                        },
                      );
                    }),
                    child: Container(
                      height: hourHeight / 2,
                      decoration: BoxDecoration(
                        color: candidate.isNotEmpty
                            ? wash
                            : dateOnly(day) == dateOnly(DateTime.now())
                            ? white
                            : paper,
                        border: Border(
                          left: const BorderSide(color: line),
                          top: BorderSide(
                            color: slot.isEven
                                ? line
                                : line.withValues(alpha: .35),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final (:item, :lane, :columns) in positioned)
            Positioned(
              top: ((clockMinutes(item.time)) * hourHeight / 60).clamp(
                0,
                hourHeight * 24,
              ),
              left: 3 + lane * box.maxWidth / columns,
              width: (box.maxWidth / columns - 6).clamp(1.0, double.infinity),
              height:
                  (((item.end.isEmpty
                                  ? clockMinutes(item.time) + 45
                                  : clockMinutes(item.end)) -
                              clockMinutes(item.time)) *
                          hourHeight /
                          60)
                      .clamp(24.0, hourHeight * 24),
              child: _CalendarEvent(
                item: item,
                onOpen: () => viewCalendarItem(item),
                onResize: (delta) => run(() async {
                  final e = item.entry;
                  if (e == null) return;
                  final end =
                      (calendarEnd(item) +
                              (delta / hourHeight * 60 / 15).round() * 15)
                          .clamp(clockMinutes(e.appointmentTime) + 15, 1440);
                  await c.notebook.saveEntry(
                    e.copyWith(appointmentEndTime: minutesClock(end)),
                  );
                }),
              ),
            ),
          if (dateOnly(day) == dateOnly(DateTime.now()) &&
              DateTime.now().hour >= 0 &&
              DateTime.now().hour < 24)
            Positioned(
              top:
                  (DateTime.now().hour * 60 + DateTime.now().minute) *
                  hourHeight /
                  60,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(height: 1.5, color: const Color(0xffac7264)),
              ),
            ),
        ],
      ),
    );
  }

  Widget monthGrid() {
    final start = DateTime(c.date.year, c.date.month, 1);
    final first = calendarDay(start, 1 - start.weekday);
    final all = calendarItems(
      c.notebook.currentSnapshot,
      dateOnly(first),
      dateOnly(calendarDay(first, 41)),
    );
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['MO', 'DI', 'MI', 'DO', 'FR', 'SA', 'SO'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, box) => SingleChildScrollView(
              child: SizedBox(
                height: box.maxHeight.clamp(540, double.infinity),
                child: Column(
                  children: [
                    for (var week = 0; week < 6; week++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var weekday = 0; weekday < 7; weekday++)
                              Expanded(
                                child: Builder(
                                  builder: (ctx) {
                                    final day = calendarDay(
                                      first,
                                      week * 7 + weekday,
                                    );
                                    final events = all
                                        .where((e) => e.date == dateOnly(day))
                                        .toList();
                                    return InkWell(
                                      onTap: () => run(
                                        () => newDesktopEntry(
                                          EntryKind.appointment,
                                          onDate: day,
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color:
                                              dateOnly(day) ==
                                                  dateOnly(DateTime.now())
                                              ? wash
                                              : day.month == c.date.month
                                              ? white
                                              : paper,
                                          border: const Border(
                                            top: BorderSide(color: line),
                                            left: BorderSide(color: line),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              '${day.day}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: day.month == c.date.month
                                                    ? ink
                                                    : muted,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            for (final item in events.take(2))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 3,
                                                ),
                                                child: InkWell(
                                                  onTap: () =>
                                                      viewCalendarItem(item),
                                                  child: Text(
                                                    '${item.time} ${item.title}'
                                                        .trim(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      color: olive,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (events.length > 2)
                                              InkWell(
                                                onTap: () {
                                                  c.setDate(day);
                                                  redraw(
                                                    () => calendarView = 'Tag',
                                                  );
                                                },
                                                child: Text(
                                                  '+ ${events.length - 2} weitere',
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: muted,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarEvent extends StatefulWidget {
  const _CalendarEvent({
    required this.item,
    required this.onOpen,
    required this.onResize,
  });
  final CalendarItem item;
  final VoidCallback onOpen;
  final ValueChanged<double> onResize;
  @override
  State<_CalendarEvent> createState() => _CalendarEventState();
}

class _CalendarEventState extends State<_CalendarEvent> {
  double delta = 0;
  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final color = i.category == 'lesson' ? olive : const Color(0xff7a8695);
    final body = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Color.lerp(white, color, .15),
        borderRadius: BorderRadius.circular(7),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: widget.onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 4, 5),
                child: Text(
                  '${i.title}\n${i.time}${i.end.isEmpty ? '' : ' – ${i.end}'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          if (i.entry?.isAppointment == true)
            Positioned(
              left: 8,
              right: 8,
              bottom: 0,
              height: 10,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => delta = 0,
                  onVerticalDragUpdate: (d) => delta += d.delta.dy,
                  onVerticalDragEnd: (_) => widget.onResize(delta),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 2,
                      color: color.withValues(alpha: .6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return i.entry?.isAppointment == true
        ? Draggable<CalendarItem>(
            data: i,
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 160, height: 55, child: body),
            ),
            childWhenDragging: Opacity(opacity: .3, child: body),
            child: body,
          )
        : body;
  }
}
