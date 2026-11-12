import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'surfaces.dart';

const livePages = {0: 'Aktuell', 1: 'Notizen', 2: 'Ablauf'};
const calendarPages = {0: 'Kalender', 1: 'Aufgaben'};

/// A quiet shared capsule. Destinations wrap instead of disappearing at large text.
class FlexPagePills extends StatelessWidget {
  const FlexPagePills({
    super.key,
    required this.selected,
    required this.onSelected,
    this.pages = livePages,
    this.keyPrefix = 'page',
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final Map<int, String> pages;
  final String keyPrefix;
  static const _icons = {
    'Aktuell': Icons.calendar_today_outlined,
    'Notizen': Icons.sticky_note_2_outlined,
    'Ablauf': Icons.account_tree_outlined,
    'Kalender': Icons.calendar_today_outlined,
    'Stundenplan': Icons.school_outlined,
    'Aufgaben': Icons.check_box_outlined,
  };
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.5,
    child: Builder(
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scheme = Theme.of(context).colorScheme;
              final showIcons =
                  pages.length <= 3 &&
                  constraints.maxWidth >= 350 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.2;
              final style = TextStyle(
                fontFamily: 'FlexSans',
                fontSize: pages.length >= 4 ? 12 : 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
              );
              if (pages.isEmpty) return const SizedBox.shrink();
              final available = math.max(48.0, constraints.maxWidth - 8);
              final horizontalPadding = pages.length >= 4 ? 4.0 : 8.0;
              var minWidth = 48.0;
              for (final label in pages.values) {
                final text = TextPainter(
                  text: TextSpan(text: label, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                minWidth = math.max(
                  minWidth,
                  text.width + horizontalPadding * 2,
                );
                text.dispose();
              }
              final maxColumns = math.min(
                pages.length <= 4 ? pages.length : 3,
                math.max(1, ((available - 6) / minWidth).floor()),
              );
              // Balance wrapped rows while retaining the same width in every row.
              final rowCount = (pages.length / maxColumns).ceil();
              final columns = (pages.length / rowCount).ceil();
              final width = (available - 6) / columns;
              var height = 44.0;
              final entries = pages.entries.toList();
              final rows = <List<MapEntry<int, String>>>[
                for (var i = 0; i < entries.length; i += columns)
                  entries.sublist(i, math.min(i + columns, entries.length)),
              ];
              final iconsFit =
                  showIcons &&
                  entries.every((entry) {
                    final text = TextPainter(
                      text: TextSpan(text: entry.value, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final fits =
                        text.width + horizontalPadding * 2 + 25 <= width;
                    text.dispose();
                    return fits;
                  });
              for (final entry in entries) {
                final text =
                    TextPainter(
                      text: TextSpan(text: entry.value, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(
                      maxWidth: math.max(
                        1,
                        width - horizontalPadding * 2 - (iconsFit ? 25 : 0),
                      ),
                    );
                height = math.max(height, text.height + 16);
                text.dispose();
              }
              return Column(
                key: ValueKey('$keyPrefix-pills'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: DecoratedBox(
                        key: ValueKey('$keyPrefix-track-${row.first.key}'),
                        decoration: FlexDesign.capsule(context),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: SizedBox(
                            width: width * row.length,
                            child: Row(
                              children: [
                                for (final e in row)
                                  Expanded(
                                    child: Semantics(
                                      selected: selected == e.key,
                                      inMutuallyExclusiveGroup: true,
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(24),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            gradient: selected == e.key
                                                ? FlexDesign.wash(
                                                    scheme.primaryContainer,
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                          child: InkWell(
                                            key: ValueKey(
                                              '$keyPrefix-${e.key}',
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            onTap: () => onSelected(e.key),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minHeight: height,
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: horizontalPadding,
                                                  vertical: 8,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    if (iconsFit &&
                                                        _icons.containsKey(
                                                          e.value,
                                                        )) ...[
                                                      Icon(
                                                        _icons[e.value],
                                                        size: 18,
                                                        color: selected == e.key
                                                            ? scheme
                                                                  .onPrimaryContainer
                                                            : scheme.primary,
                                                      ),
                                                      const SizedBox(width: 7),
                                                    ],
                                                    Flexible(
                                                      child: Text(
                                                        e.value,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: style.copyWith(
                                                          fontWeight:
                                                              selected == e.key
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                          color:
                                                              selected == e.key
                                                              ? scheme
                                                                    .onPrimaryContainer
                                                              : scheme
                                                                    .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
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
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class FlexBottomNavigation extends StatelessWidget {
  const FlexBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.3,
    child: Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Material(
          key: const ValueKey('bottom-navigation-surface'),
          color: scheme.surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.outlineVariant, width: .8),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in const [
                      (0, 'Kalender', Icons.calendar_today_outlined),
                      (2, 'Organisation', Icons.layers_outlined),
                      (1, 'Live', Icons.people_outline_rounded),
                      (3, 'Material', Icons.folder_outlined),
                      (4, 'Mehr', Icons.more_horiz),
                    ])
                      Expanded(
                        child: Semantics(
                          selected: selected == e.$1,
                          button: true,
                          child: Tooltip(
                            message: e.$1 == 4 ? 'Weitere Bereiche' : e.$2,
                            excludeFromSemantics: e.$1 != 4,
                            child: InkWell(
                              key: ValueKey('bottom-${e.$1}'),
                              onTap: () => onSelected(e.$1),
                              borderRadius: BorderRadius.circular(18),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: selected == e.$1
                                      ? FlexDesign.wash(scheme.primaryContainer)
                                      : null,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      e.$3,
                                      size: 25,
                                      color: selected == e.$1
                                          ? scheme.onPrimaryContainer
                                          : scheme.primary,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      e.$2,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: selected == e.$1
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurface,
                                        fontSize: 11,
                                        height: 1.2,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// A short, critically damped snap without elastic overscroll.
class FlexPageScrollPhysics extends PageScrollPhysics {
  const FlexPageScrollPhysics({super.parent});
  @override
  FlexPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      FlexPageScrollPhysics(parent: buildParent(ancestor));
  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: .5, stiffness: 900, ratio: 1);
}
