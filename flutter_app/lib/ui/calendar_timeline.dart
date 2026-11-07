import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/calendar.dart';
import '../domain/calendar_layout.dart';
import '../domain/models.dart';
import 'flex_modal.dart';

IconData calendarIcon(String category) => switch (category) {
  'lesson' => Icons.school_outlined,
  'homework' => Icons.home_outlined,
  'goal' => Icons.flag_outlined,
  'return' => Icons.fact_check_outlined,
  'holiday' => Icons.beach_access_outlined,
  'task' => Icons.task_alt,
  _ => Icons.event_outlined,
};

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
    this.showDates = true,
    this.highlightNow = true,
    this.showBlockDetails = false,
  });
  final List<DateTime> days;
  final List<CalendarItem> items;
  final DateTime now;
  final String selectedDate;
  final bool week, showDates, highlightNow, showBlockDetails;
  final ValueChanged<CalendarItem> onOpen;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, constraints) {
      final scale = MediaQuery.textScalerOf(ctx).scale(1).clamp(1.0, 2.5);
      final pixels = week ? 1.35 * scale : 1.65 * scale;
      final minMinutes = week ? 36 : 38;
      final hours = calendarHours(items, minimumMinutes: minMinutes);
      final height = (hours.end - hours.start) * pixels;
      final axis = scale > 1.5 ? 66.0 : 46.0;
      final colWidth = week
          ? math.max(
              (constraints.maxWidth - axis) / days.length,
              scale > 1.5 ? 108.0 : 58.0,
            )
          : constraints.maxWidth - axis;
      final width = axis + colWidth * days.length;
      final readableColumns = math.max(
        1,
        (colWidth / ((week ? 90 : 140) * scale)).floor(),
      );
      final headHeight = week ? 64.0 * scale : 0.0;
      final scheme = Theme.of(ctx).colorScheme;
      final current = highlightNow ? currentCalendarItem(items, now) : null,
          next = highlightNow ? nextCalendarItem(items, now) : null;
      final body = SizedBox(
        width: width,
        height: height + headHeight + 20,
        child: Stack(
          children: [
            for (
              var minute = hours.start;
              minute <= hours.end;
              minute += 60
            ) ...[
              Positioned(
                top: headHeight + (minute - hours.start) * pixels,
                left: 0,
                width: axis - 6,
                child: Text(
                  minuteClock(minute),
                  textAlign: TextAlign.right,
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
              Positioned(
                top: headHeight + (minute - hours.start) * pixels,
                left: axis,
                right: 0,
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
            ],
            for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
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
                      color:
                          highlightNow &&
                              dateOnly(days[dayIndex]) == dateOnly(now)
                          ? scheme.primary.withValues(alpha: .14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => onDay(days[dayIndex]),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              calendarWeekday(days[dayIndex], short: true),
                              style: Theme.of(ctx).textTheme.labelLarge,
                            ),
                            if (showDates)
                              Text(
                                '${days[dayIndex].day}.${days[dayIndex].month}.',
                                style: Theme.of(ctx).textTheme.bodySmall,
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
                child: VerticalDivider(width: 1, color: scheme.outlineVariant),
              ),
              if (highlightNow &&
                  dateOnly(days[dayIndex]) == dateOnly(now) &&
                  now.hour * 60 + now.minute >= hours.start &&
                  now.hour * 60 + now.minute < hours.end)
                Positioned(
                  key: const ValueKey('calendar-now-line'),
                  top:
                      headHeight +
                      (now.hour * 60 + now.minute - hours.start) * pixels,
                  left: axis + dayIndex * colWidth,
                  right: width - (axis + (dayIndex + 1) * colWidth),
                  child: IgnorePointer(
                    child: Semantics(
                      label: 'Jetzt ${minuteClock(now.hour * 60 + now.minute)}',
                      child: Container(height: 2, color: scheme.error),
                    ),
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
                        onTap: () => showDialog<void>(
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
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${cluster.length}',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                              Text(
                                'Einträge',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(ctx).textTheme.bodySmall,
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
                      child: _TimeBlock(
                        item: placement.item,
                        compact: week,
                        details: showBlockDetails,
                        current: placement.item.id == current?.id,
                        next: placement.item.id == next?.id,
                        onTap: () => onOpen(placement.item),
                      ),
                    ),
            ],
          ],
        ),
      );
      return SingleChildScrollView(
        key: ValueKey('calendar-time-grid-${week ? 'week' : 'day'}'),
        scrollDirection: Axis.horizontal,
        physics: width > constraints.maxWidth + 1
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: body,
      );
    },
  );
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
    final tint = item.category == 'appointment'
        ? const Color(0xff829fb8)
        : scheme.primary;
    final time = '${item.time}${item.end.isEmpty ? '' : '–${item.end}'}';
    return Semantics(
      button: true,
      label:
          '${item.title}, $time${current ? ', jetzt' : ''}${next ? ', als Nächstes' : ''}',
      child: Material(
        color: Color.alphaBlend(
          tint.withValues(alpha: current ? .25 : .13),
          scheme.surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: current ? scheme.primary : tint.withValues(alpha: .6),
            width: current ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: LayoutBuilder(
            builder: (ctx, box) {
              final scale = MediaQuery.textScalerOf(ctx).scale(1);
              final narrow = box.maxWidth < 100;
              final titleStyle = Theme.of(ctx).textTheme.labelLarge?.copyWith(
                fontSize: compact && narrow ? 11 : 14,
                fontWeight: FontWeight.w600,
                height: 1.15,
              );
              return Padding(
                padding: EdgeInsets.all(narrow ? 4 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!compact &&
                        box.maxHeight > 90 * scale &&
                        (current || next))
                      Text(
                        current ? 'Jetzt' : 'Als Nächstes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    Text(
                      item.title,
                      maxLines:
                          (compact && box.maxHeight > 50 * scale) ||
                              (!compact && box.maxHeight > 85 * scale)
                          ? 2
                          : 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    if (box.maxHeight > 40 * scale)
                      Text(
                        compact && !details ? item.time : time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          fontSize: compact && narrow ? 10 : 12,
                          height: 1.2,
                        ),
                      ),
                    if ((!compact || details) &&
                        !narrow &&
                        box.maxHeight > 65 * scale &&
                        item.detail.isNotEmpty)
                      Text(
                        item.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
