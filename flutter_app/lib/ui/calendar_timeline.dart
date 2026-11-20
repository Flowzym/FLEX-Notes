import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/calendar.dart';
import '../domain/classroom.dart' show validEndClock;
import '../domain/calendar_layout.dart';
import '../domain/models.dart';
import 'flex_modal.dart';
import 'calendar_drag.dart';
import 'surfaces.dart';
import '../domain/calendar_edit.dart';

IconData calendarIcon(String category) => switch (category) {
  'lesson' => Icons.school_outlined,
  'homework' => Icons.home_outlined,
  'goal' => Icons.flag_outlined,
  'return' => Icons.fact_check_outlined,
  'holiday' => Icons.beach_access_outlined,
  'task' => Icons.task_alt,
  _ => Icons.event_outlined,
};

Color calendarAccent(ColorScheme colors, String category) {
  return switch (category) {
    'appointment' => FlexDesign.appointmentColor(colors),
    'due' => FlexDesign.dueColor(colors),
    _ => colors.primary,
  };
}

String calendarDetails(CalendarItem item) => item.detail
    .split(' · ')
    .where((value) => value.isNotEmpty && value != item.title)
    .join(' · ');

/// A shared time axis gives day and week the same vertical geometry. Large text
/// uses wider week columns with horizontal scrolling instead of shrinking text.
class CalendarTimeline extends StatelessWidget {
  const CalendarTimeline({
    super.key,
    required this.days,
    required this.items,
    required this.now,
    required this.onOpen,
    required this.onDay,
    required this.selectedDate,
    this.week = false,
    this.nowMarkerKey,
    this.showDates = true,
    this.highlightNow = true,
    this.showBlockDetails = false,
    this.onCreate,
    this.onChange,
    this.minimumHeight = 0,
  });
  final double minimumHeight;
  final Future<void> Function(CalendarItem, CalendarEdit)? onChange;
  final List<DateTime> days;
  final List<CalendarItem> items;
  final DateTime now;
  final Key? nowMarkerKey;
  final String selectedDate;
  final bool week, showDates, highlightNow, showBlockDetails;
  final ValueChanged<CalendarItem> onOpen;
  final ValueChanged<DateTime> onDay;
  final void Function(DateTime day, String time)? onCreate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, constraints) {
      final scale = MediaQuery.textScalerOf(ctx).scale(1).clamp(1.0, 2.5);
      // Keep the existing week overlap boundaries: making short blocks longer
      // would incorrectly pull a following lesson into the same group.
      final minMinutes = week ? 36 : 44;
      // Fit ordinary teaching days compactly, but retain touch-sized slots when
      // short appointments are present. Real overlap boundaries stay unchanged.
      final shortest = items.where(calendarTimed).fold<double>(
        double.infinity,
        (shortest, item) {
          final duration = validEndClock(item.end)
              ? clockMinutes(item.end) - clockMinutes(item.time)
              : 0;
          return math.min(shortest, math.max(minMinutes, duration).toDouble());
        },
      );
      final pixels =
          math.max(week ? .80 : .88, (week ? 36.0 : 48.0) / shortest) * scale;

      final baseHours = calendarHours(items, minimumMinutes: minMinutes);
      final todayIndex = highlightNow
          ? days.indexWhere((day) => dateOnly(day) == dateOnly(now))
          : -1;
      final nowMinutes = now.hour * 60 + now.minute;
      // Today's time must also be representable before/after teaching hours.
      final hours = (!week && todayIndex >= 0)
          ? (
              start: math.min(baseHours.start, (nowMinutes ~/ 60) * 60),
              end: math.max(
                baseHours.end,
                math.min(24 * 60, ((nowMinutes ~/ 60) + 1) * 60),
              ),
            )
          : baseHours;
      final headHeight = week ? (showDates ? 54.0 : 42.0) * scale : 0.0;
      final endMinute = math.min(
        1440,
        math.max(
          hours.end,
          hours.start +
              ((minimumHeight - headHeight - 20) / pixels / 60).ceil() * 60,
        ),
      );
      final height = (endMinute - hours.start) * pixels;
      final axis = scale > 1.5
          ? 66.0
          : week && days.length == 7
          ? 38.0
          : 46.0;
      final colWidth = week
          ? math.max(
              (constraints.maxWidth - axis) / days.length,
              scale > 1.5 ? 108.0 : 0.0,
            )
          : constraints.maxWidth - axis;
      final width = axis + colWidth * days.length;
      Widget editable(CalendarItem item, Widget child) =>
          onChange == null || item.entry == null && item.lesson == null
          ? child
          : CalendarDragBlock(
              key: ValueKey('calendar-edit-${item.id}'),
              item: item,
              days: days,
              dayWidth: colWidth,
              pixelsPerMinute: pixels,
              onChange: onChange!,
              child: child,
            );
      final readableColumns = math.max(
        1,
        (colWidth / ((week ? 90 : 140) * scale)).floor(),
      );
      void createAt(Offset point) {
        if (onCreate == null ||
            point.dx < axis ||
            point.dy < headHeight ||
            point.dy >= headHeight + height) {
          return;
        }
        final day = ((point.dx - axis) / colWidth).floor();
        if (day < 0 || day >= days.length) return;
        final minute =
            ((hours.start + (point.dy - headHeight) / pixels) ~/ 15 * 15).clamp(
              0,
              23 * 60 + 45,
            );
        onCreate!(days[day], minuteClock(minute));
      }

      final scheme = Theme.of(ctx).colorScheme;
      final nowColor = Theme.of(ctx).brightness == Brightness.dark
          ? const Color(0xffe0a08a)
          : const Color(0xffb46449);
      final current = highlightNow ? currentCalendarItem(items, now) : null,
          next = highlightNow ? nextCalendarItem(items, now) : null;
      void openCluster(List<CalendarPlacement> cluster) {
        showDialog<void>(
          context: ctx,
          builder: (dialog) => FlexModal(
            title: Text('${cluster.length} Einträge'),
            onClose: () => Navigator.pop(dialog),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in cluster)
                  ListTile(
                    title: Text(p.item.title),
                    subtitle: Text(
                      '${p.item.time}${p.item.end.isEmpty ? '' : '–${p.item.end}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(dialog);
                      onOpen(p.item);
                    },
                  ),
              ],
            ),
          ),
        );
      }

      final body = SizedBox(
        width: width,
        height: height + headHeight + 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; week && index < days.length; index++)
              if (days[index].weekday >= DateTime.saturday &&
                  index != todayIndex)
                Positioned(
                  top: headHeight,
                  bottom: 20,
                  left: axis + index * colWidth,
                  width: colWidth,
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: scheme.onSurface.withValues(alpha: .025),
                    ),
                  ),
                ),
            if (week && todayIndex >= 0)
              Positioned(
                top: headHeight,
                bottom: 20,
                left: axis + todayIndex * colWidth,
                width: colWidth,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: scheme.primary.withValues(alpha: .047),
                  ),
                ),
              ),
            for (
              var minute = hours.start;
              minute <= endMinute;
              minute += week ? 60 : 30
            ) ...[
              Positioned(
                key: ValueKey('calendar-hour-$minute'),
                top: headHeight + (minute - hours.start) * pixels,
                left: 0,
                width: axis - 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: Text(
                    minuteClock(minute),
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: minute % 60 == 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: headHeight + (minute - hours.start) * pixels,
                left: axis,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: minute % 60 == 0 ? .8 : .5,
                  color: scheme.outlineVariant.withValues(
                    alpha: minute % 60 == 0 ? .88 : .56,
                  ),
                ),
              ),
            ],
            for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
              if (onCreate != null)
                Positioned(
                  top: headHeight,
                  left: axis + dayIndex * colWidth,
                  width: colWidth,
                  height: height,
                  child: Semantics(
                    label: 'Termin am ${dateOnly(days[dayIndex])} hinzufügen',
                    button: true,
                    onTap: () =>
                        onCreate!(days[dayIndex], minuteClock(hours.start)),
                    child: GestureDetector(
                      key: ValueKey(
                        'calendar-create-${dateOnly(days[dayIndex])}',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => createAt(
                        details.localPosition +
                            Offset(axis + dayIndex * colWidth, headHeight),
                      ),
                    ),
                  ),
                ),
              if (week)
                Positioned(
                  top: 0,
                  left: axis + dayIndex * colWidth,
                  width: colWidth,
                  height: headHeight - 4,
                  child: Semantics(
                    selected: dateOnly(days[dayIndex]) == selectedDate,
                    label:
                        '${calendarWeekday(days[dayIndex])}${showDates ? ', ${dateOnly(days[dayIndex])}' : ''}, Tagesansicht öffnen',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => onDay(days[dayIndex]),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              calendarWeekday(days[dayIndex], short: true),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(ctx).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (showDates)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                height: 26 * scale,
                                width: 26 * scale,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: dayIndex == todayIndex
                                      ? scheme.primary
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${days[dayIndex].day}',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: Theme.of(ctx).textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                          color: dayIndex == todayIndex
                                              ? scheme.onPrimary
                                              : scheme.onSurface,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: headHeight,
                bottom: 20,
                left: axis + dayIndex * colWidth,
                child: VerticalDivider(
                  width: 1,
                  thickness: .7,
                  color: scheme.outlineVariant.withValues(alpha: .65),
                ),
              ),
              for (final cluster in calendarClusters(
                items.where((i) => i.date == dateOnly(days[dayIndex])),
                minimumMinutes: minMinutes,
              ))
                if (cluster.first.columns > readableColumns)
                  Positioned(
                    top:
                        headHeight +
                        (cluster.first.start - hours.start) * pixels +
                        2,
                    left: axis + dayIndex * colWidth + 3,
                    width: colWidth - 6,
                    height:
                        (cluster.map((p) => p.finish).reduce(math.max) -
                                cluster.first.start) *
                            pixels -
                        4,
                    child: Material(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        onTap: () => openCluster(cluster),
                        child:
                            cluster
                                        .where(
                                          (p) => p.item.category == 'lesson',
                                        )
                                        .length ==
                                    1 &&
                                cluster.any(
                                  (p) => p.item.category == 'appointment',
                                )
                            ? Stack(
                                children: [
                                  for (final p in [
                                    ...cluster.where(
                                      (p) => p.item.category == 'lesson',
                                    ),
                                    ...cluster.where(
                                      (p) => p.item.category != 'lesson',
                                    ),
                                  ])
                                    Positioned(
                                      key: ValueKey(
                                        'calendar-overlap-${p.item.id}',
                                      ),
                                      top:
                                          (p.start - cluster.first.start) *
                                          pixels,
                                      left: p.item.category == 'lesson' ? 0 : 4,
                                      right: 0,
                                      height: (p.finish - p.start) * pixels - 4,
                                      child: editable(
                                        p.item,
                                        _TimeBlock(
                                          item: p.item,
                                          compact: true,
                                          details: false,
                                          current: false,
                                          next: false,
                                          onTap: () => openCluster(cluster),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${cluster.length} Einträge',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(ctx).textTheme.labelSmall,
                                    ),
                                    Expanded(
                                      child: Text(
                                        cluster
                                            .map((p) => p.item.title)
                                            .join(' · '),
                                        overflow: TextOverflow.fade,
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  )
                else
                  for (final placement in cluster)
                    Positioned(
                      key: ValueKey('calendar-slot-${placement.item.id}'),
                      top:
                          headHeight +
                          (placement.start - hours.start) * pixels +
                          2,
                      left:
                          axis +
                          dayIndex * colWidth +
                          placement.column * colWidth / placement.columns +
                          3,
                      width: colWidth / placement.columns - 6,
                      height: (placement.finish - placement.start) * pixels - 4,
                      child: editable(
                        placement.item,
                        _TimeBlock(
                          item: placement.item,
                          compact: week,
                          details: showBlockDetails,
                          current: placement.item.id == current?.id,
                          next: placement.item.id == next?.id,
                          onTap: () => onOpen(placement.item),
                        ),
                      ),
                    ),
            ],
            // Paint last: an ongoing lesson must never cover the time marker.
            if (todayIndex >= 0 &&
                nowMinutes >= hours.start &&
                nowMinutes < hours.end) ...[
              Positioned(
                key: const ValueKey('calendar-now-line'),
                top: headHeight + (nowMinutes - hours.start) * pixels,
                left: axis + todayIndex * colWidth,
                width: colWidth,
                height: 2,
                child: IgnorePointer(
                  child: Semantics(
                    key: nowMarkerKey,
                    label: 'Jetzt ${minuteClock(nowMinutes)}',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: nowColor,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.surface,
                            blurRadius: 2,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: headHeight + (nowMinutes - hours.start) * pixels - 3,
                left: axis + todayIndex * colWidth - 4,
                child: IgnorePointer(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: nowColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                key: const ValueKey('calendar-now-label'),
                top: math.max(
                  0,
                  headHeight + (nowMinutes - hours.start) * pixels - 9 * scale,
                ),
                left: 0,
                width: axis - 6,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: nowColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          minuteClock(nowMinutes),
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: scheme.onError,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
      return _TimelineViewport(
        overflow: width > constraints.maxWidth + 1,
        gridKey: ValueKey('calendar-time-grid-${week ? 'week' : 'day'}'),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: onCreate == null
              ? null
              : (details) => createAt(details.localPosition),
          child: body,
        ),
      );
    },
  );
}

/// Large text retains readable columns and provides visible controls to reach
/// the weekend. At normal phone text size all seven days fit the viewport.
class _TimelineViewport extends StatefulWidget {
  const _TimelineViewport({
    required this.overflow,
    required this.gridKey,
    required this.child,
  });
  final bool overflow;
  final Key gridKey;
  final Widget child;
  @override
  State<_TimelineViewport> createState() => _TimelineViewportState();
}

class _TimelineViewportState extends State<_TimelineViewport> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void move(bool end) => scroll.animateTo(
    end ? scroll.position.maxScrollExtent : 0,
    duration: const Duration(milliseconds: 140),
    curve: Curves.easeOutCubic,
  );
  @override
  Widget build(BuildContext context) {
    final grid = SingleChildScrollView(
      key: widget.gridKey,
      controller: scroll,
      scrollDirection: Axis.horizontal,
      physics: widget.overflow
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: widget.child,
    );
    if (!widget.overflow) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Wochenanfang anzeigen',
              onPressed: () => move(false),
              icon: const Icon(Icons.chevron_left),
            ),
            const Expanded(
              child: Text('Weitere Tage', textAlign: TextAlign.center),
            ),
            IconButton(
              tooltip: 'Wochenende anzeigen',
              onPressed: () => move(true),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Scrollbar(
          controller: scroll,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.top,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: grid,
        ),
      ],
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.item,
    required this.compact,
    required this.details,
    required this.current,
    required this.next,
    required this.onTap,
  });
  final CalendarItem item;
  final bool compact, current, next, details;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = calendarAccent(scheme, item.category);
    final time = '${item.time}${item.end.isEmpty ? '' : '–${item.end}'}';
    final detail = calendarDetails(item);
    final radius = BorderRadius.circular(compact ? 7 : 12);
    final surface = Color.alphaBlend(
      accent.withValues(alpha: item.category == 'appointment' ? .14 : .065),
      scheme.surface,
    );
    return Semantics(
      button: true,
      label:
          '${item.title}, $time${current ? ', jetzt' : ''}${next ? ', als Nächstes' : ''}',
      child: Tooltip(
        message: '${item.title} · $time',
        triggerMode: TooltipTriggerMode.manual,
        child: Material(
          color: surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(
                  color: accent.withValues(alpha: current ? 1 : .82),
                  width: compact ? 2.5 : 3.5,
                ),
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(
                builder: (ctx, box) {
                  final scale = MediaQuery.textScalerOf(ctx).scale(1);
                  final narrow = box.maxWidth < 100;
                  final tight = box.maxHeight < 64 * scale;
                  final side = narrow
                      ? 4.0
                      : tight
                      ? 8.0
                      : 12.0;
                  final titleSize = compact && narrow
                      ? 11.0
                      : tight
                      ? 14.0
                      : 17.0;
                  final timeSize = compact && narrow ? 9.0 : 12.0;
                  final vertical = narrow || tight ? 2.0 : 8.0;
                  final usableHeight = box.maxHeight - 2 * vertical;
                  final showTime =
                      usableHeight >=
                      (titleSize * 1.2 + timeSize * 1.2 + 2) * scale;
                  final titleLines =
                      compact &&
                          usableHeight >=
                              (2 * titleSize * 1.2 + timeSize * 1.2 + 3) * scale
                      ? 2
                      : 1;
                  final split =
                      showTime &&
                      compact &&
                      box.maxWidth < 67 * scale &&
                      item.end.isNotEmpty &&
                      usableHeight >=
                          (titleLines * titleSize * 1.2 + timeSize * 2.4 + 2) *
                              scale;
                  final showDetail =
                      (!compact || details) &&
                      !narrow &&
                      detail.isNotEmpty &&
                      usableHeight >= 64 * scale;
                  final textTheme = Theme.of(ctx).textTheme;
                  return Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      side + 2,
                      vertical,
                      narrow ? 2 : side,
                      vertical,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: titleLines,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(
                                  fontSize: titleSize,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!compact &&
                                box.maxWidth > 180 * scale &&
                                !tight)
                              Icon(
                                calendarIcon(item.category),
                                size: 16,
                                color: accent,
                              ),
                          ],
                        ),
                        if (showTime)
                          Text(
                            split
                                ? '${item.time}–\n${item.end}'
                                : compact && box.maxWidth < 67 * scale
                                ? item.time
                                : time,
                            maxLines: split ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              fontSize: timeSize,
                              height: 1.15,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        if (showDetail)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
