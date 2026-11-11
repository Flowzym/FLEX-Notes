import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'surfaces.dart';

const livePages = {0: 'Aktuell', 1: 'Notizen', 2: 'Ablauf'};
const calendarPages = {0: 'Kalender', 1: 'Stundenplan', 2: 'Aufgaben'};

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
                fontSize: pages.length > 4 ? 12 : 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
              );
              final available = math.max(48.0, constraints.maxWidth - 8);
              final rows = <List<(int, String, double)>>[[]];
              var used = 0.0;
              var height = 44.0;
              for (final entry in pages.entries) {
                final iconWidth = showIcons && _icons.containsKey(entry.value)
                    ? 25.0
                    : 0.0;
                final text = TextPainter(
                  text: TextSpan(text: entry.value, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: available - 20 - iconWidth);
                final width = (text.width + 20 + iconWidth).clamp(
                  48.0,
                  available,
                );
                height = math.max(height, text.height + 20);
                text.dispose();
                if (used + width > available && rows.last.isNotEmpty) {
                  rows.add([]);
                  used = 0;
                }
                rows.last.add((entry.key, entry.value, width));
                used += width;
              }
              return Column(
                key: ValueKey('$keyPrefix-pills'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: DecoratedBox(
                        key: ValueKey('$keyPrefix-track-${row.first.$1}'),
                        decoration: FlexDesign.capsule(context),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: SizedBox(
                            width: rows.length == 1 && pages.length <= 4
                                ? available
                                : row.fold<double>(0.0, (sum, e) => sum + e.$3),
                            child: Row(
                              children: [
                                for (final e in row)
                                  Expanded(
                                    flex: (e.$3 * 100).round(),
                                    child: Semantics(
                                      selected: selected == e.$1,
                                      inMutuallyExclusiveGroup: true,
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(24),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            gradient: selected == e.$1
                                                ? FlexDesign.wash(
                                                    scheme.primaryContainer,
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                          child: InkWell(
                                            key: ValueKey('$keyPrefix-${e.$1}'),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            onTap: () => onSelected(e.$1),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minHeight: height,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    if (showIcons &&
                                                        _icons.containsKey(
                                                          e.$2,
                                                        )) ...[
                                                      Icon(
                                                        _icons[e.$2],
                                                        size: 18,
                                                        color: selected == e.$1
                                                            ? scheme
                                                                  .onPrimaryContainer
                                                            : scheme.primary,
                                                      ),
                                                      const SizedBox(width: 7),
                                                    ],
                                                    Flexible(
                                                      child: Text(
                                                        e.$2,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: style.copyWith(
                                                          fontWeight:
                                                              selected == e.$1
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                          color:
                                                              selected == e.$1
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
