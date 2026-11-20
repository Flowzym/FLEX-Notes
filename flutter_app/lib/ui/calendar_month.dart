part of 'calendar_page.dart';

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.selected,
    required this.today,
    required this.items,
    required this.onCreate,
    required this.onPreview,
  });
  final DateTime selected, today;
  final List<CalendarItem> items;
  final ValueChanged<DateTime> onCreate, onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final first = DateTime.utc(selected.year, selected.month, 1);
    final length = DateTime.utc(selected.year, selected.month + 1, 0).day;
    final offset = first.weekday - DateTime.monday;
    final marked = <String, List<CalendarItem>>{};
    for (final item in items.where((i) => i.category != 'lesson')) {
      (marked[item.date] ??= []).add(item);
    }
    final scale = MediaQuery.textScalerOf(context);
    final cellHeight = math.max(46.0, scale.scale(32) + 12);
    final line = BorderSide(
      color: colors.outlineVariant.withValues(alpha: .70),
      width: .6,
    );
    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: line,
      ),
      child: Column(
        children: [
          Container(
            color: colors.primary.withValues(alpha: .055),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                for (final weekday in const [
                  'Mo',
                  'Di',
                  'Mi',
                  'Do',
                  'Fr',
                  'Sa',
                  'So',
                ])
                  Expanded(
                    child: Text(
                      weekday,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: cellHeight,
            ),
            itemCount: ((offset + length + 6) ~/ 7) * 7,
            itemBuilder: (context, index) {
              final number = index - offset + 1;
              final inMonth = number >= 1 && number <= length;
              final day = DateTime.utc(first.year, first.month, number);
              final key = dateOnly(day);
              final active = key == dateOnly(selected);
              final isToday = key == dateOnly(today);
              final entries = marked[key] ?? const <CalendarItem>[];
              final weekend = index % 7 >= 5;
              final markers = <Color>[
                if (entries.any((i) => i.category == 'appointment'))
                  calendarAccent(colors, 'appointment'),
                if (entries.any(calendarDue)) calendarAccent(colors, 'due'),
              ];
              return DecoratedBox(
                key: ValueKey('calendar-month-cell-$index'),
                decoration: BoxDecoration(
                  color: weekend
                      ? colors.primary.withValues(alpha: .035)
                      : Colors.transparent,
                  border: Border(
                    top: line,
                    right: index % 7 == 6 ? BorderSide.none : line,
                  ),
                ),
                child: Semantics(
                  button: true,
                  selected: active,
                  label:
                      '${calendarWeekday(day)}, ${displayDate(key)}${isToday ? ', heute' : ''}${inMonth ? ', ${entries.length} Einträge' : ''}',
                  onTapHint: inMonth
                      ? 'Termin anlegen'
                      : '${calendarMonth(day)} öffnen',
                  onLongPressHint: 'Tagesübersicht anzeigen',
                  child: InkWell(
                    key: ValueKey('calendar-month-$key'),
                    onTap: () => inMonth ? onCreate(day) : onPreview(day),
                    onLongPress: () => onPreview(day),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: math.max(27.0, scale.scale(22)),
                          height: math.max(27.0, scale.scale(22)),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active ? colors.primary : null,
                            border: isToday && !active
                                ? Border.all(color: colors.primary, width: 1.4)
                                : null,
                          ),
                          child: Text(
                            '${day.day}',
                            maxLines: 1,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: active
                                  ? colors.onPrimary
                                  : inMonth
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                              fontSize: inMonth ? null : 12,
                              fontWeight: isToday || active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final color in markers)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (entries.any((i) => i.category == 'holiday'))
                                Container(
                                  width: 9,
                                  height: 2,
                                  color: colors.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({super.key, required this.item, required this.onOpen});
  final CalendarItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final detail = calendarDetails(item);
    return InkWell(
      onTap: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(42),
                child: Text(
                  item.time,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 27,
                margin: const EdgeInsetsDirectional.only(end: 10),
                decoration: BoxDecoration(
                  color: calendarAccent(colors, item.category),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
