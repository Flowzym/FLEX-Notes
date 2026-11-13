import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'surfaces.dart';
import 'navigation_icon.dart';

// IDs remain stable when the visual order changes.
const livePages = {1: 'Notizen', 0: 'Aktuell', 2: 'Ablauf'};
const calendarPages = {0: 'Kalender', 1: 'Aufgaben'};

/// Lets the header and pages without their own pager share tab swipes.
/// Child pagers, text selection and sliders keep their own horizontal gestures.
class FlexNavigationSwipe extends StatefulWidget {
  const FlexNavigationSwipe({
    super.key,
    required this.child,
    required this.onStep,
  });
  final Widget child;
  final ValueChanged<bool> onStep;
  @override
  State<FlexNavigationSwipe> createState() => _FlexNavigationSwipeState();
}

class _FlexNavigationSwipeState extends State<FlexNavigationSwipe> {
  double _distance = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _distance = 0,
    onHorizontalDragUpdate: (details) => _distance += details.primaryDelta ?? 0,
    onHorizontalDragCancel: () => _distance = 0,
    onHorizontalDragEnd: (details) {
      final distance = _distance;
      _distance = 0;
      if (distance.abs() >= 48 ||
          (distance.abs() >= 16 &&
              (details.primaryVelocity ?? 0).abs() > 450)) {
        final previous = Directionality.of(context) == TextDirection.ltr
            ? distance > 0
            : distance < 0;
        widget.onStep(previous);
      }
    },
    child: widget.child,
  );
}

/// One quick transition for every top-level tab, independent of its content.
/// The child stays mounted so searches, scroll positions and inputs survive.
class FlexTabTransition extends StatefulWidget {
  const FlexTabTransition({
    super.key,
    required this.section,
    required this.index,
    required this.child,
  });
  final int section, index;
  final Widget child;
  static const duration = Duration(milliseconds: 140);

  @override
  State<FlexTabTransition> createState() => _FlexTabTransitionState();
}

class _FlexTabTransitionState extends State<FlexTabTransition>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: FlexTabTransition.duration,
    value: 1,
  );
  double _direction = 1;

  @override
  void didUpdateWidget(covariant FlexTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section ||
        MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (oldWidget.index != widget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      if (Directionality.of(context) == TextDirection.rtl) _direction *= -1;
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (_, child) {
      final progress = Curves.easeOutCubic.transform(_animation.value);
      return IgnorePointer(
        ignoring: _animation.isAnimating,
        child: Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(16 * (1 - progress) * _direction, 0),
            child: child,
          ),
        ),
      );
    },
  );
}

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
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in const [
                      (0, 'Kalender'),
                      (2, 'Organisation'),
                      (1, 'Live'),
                      (3, 'Material'),
                      (4, 'Mehr'),
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                  vertical: 4,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FlexNavigationIcon(
                                      destination: e.$1,
                                      color: selected == e.$1
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.$2,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: selected == e.$1
                                            ? scheme.primary
                                            : scheme.onSurface,
                                        fontSize: 11,
                                        height: 1.2,
                                        fontWeight: selected == e.$1
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: 20,
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: selected == e.$1
                                            ? scheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(2),
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
