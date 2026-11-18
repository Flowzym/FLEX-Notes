import 'package:flutter/material.dart';

/// One row on phones; full labels remain available through tooltips and semantics.
class CalendarToolbar extends StatelessWidget {
  const CalendarToolbar({
    super.key,
    required this.period,
    required this.periodLabel,
    required this.compactPeriod,
    required this.previous,
    required this.next,
    required this.chooseDate,
    required this.today,
    required this.lessons,
    required this.toggleLessons,
    required this.filtered,
    required this.filter,
    required this.materials,
    required this.manage,
  });
  final String period, periodLabel, compactPeriod;
  final bool lessons, filtered;
  final VoidCallback previous, next, chooseDate, today, toggleLessons, filter;
  final VoidCallback? materials, manage;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, box) {
      const size = 48.0;
      final inlineFilter =
          box.maxWidth >= 380 && MediaQuery.textScalerOf(ctx).scale(1) <= 1.4;
      final inlineMaterials =
          box.maxWidth >= 460 && MediaQuery.textScalerOf(ctx).scale(1) <= 1.4;
      Widget button(
        String key,
        String label,
        IconData icon,
        VoidCallback? action, {
        bool? checked,
      }) => Semantics(
        toggled: checked,
        child: SizedBox(
          width: size,
          height: size,
          child: IconButton(
            key: ValueKey(key),
            tooltip: label,
            onPressed: action,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 20,
            icon: Icon(icon),
          ),
        ),
      );
      return Row(
        key: const ValueKey('calendar-date-navigation'),
        children: [
          button(
            'calendar-previous',
            'Vorheriger Zeitraum',
            Icons.chevron_left,
            previous,
          ),
          Expanded(
            child: Tooltip(
              message: '$periodLabel · Datum wählen',
              child: TextButton(
                key: const ValueKey('calendar-period'),
                onPressed: chooseDate,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                ),
                child: SizedBox(
                  height: 48,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      box.maxWidth < 345 &&
                              MediaQuery.textScalerOf(ctx).scale(1) > 1.4
                          ? compactPeriod
                          : period,
                      semanticsLabel: periodLabel,
                      maxLines: 2,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          button(
            'calendar-next',
            'Nächster Zeitraum',
            Icons.chevron_right,
            next,
          ),
          Tooltip(
            message: 'Heute',
            child: TextButton(
              key: const ValueKey('calendar-today'),
              onPressed: today,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                backgroundColor: Colors.transparent,
                textStyle: const TextStyle(
                  fontFamily: 'FlexSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Heute'),
            ),
          ),
          button(
            'calendar-show-lessons',
            'Unterricht anzeigen',
            lessons ? Icons.check_box_outlined : Icons.check_box_outline_blank,
            toggleLessons,
            checked: lessons,
          ),
          if (inlineFilter)
            button(
              'calendar-filter',
              filtered ? 'Filter · aktiv' : 'Filter',
              filtered ? Icons.filter_alt : Icons.tune,
              filter,
            ),
          if (inlineMaterials)
            button(
              'calendar-materials',
              'Unterlagen',
              Icons.folder_open_outlined,
              materials,
            ),
          button(
            'calendar-manage',
            'Verwalten',
            Icons.settings_outlined,
            manage,
          ),
        ],
      );
    },
  );
}
