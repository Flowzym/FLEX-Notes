import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'surfaces.dart';

const livePages = {0: 'Aktuell', 1: 'Notizen', 2: 'Ablauf'};
const calendarPages = {0: 'Kalender', 1: 'Stundenplan', 2: 'Aufgaben'};

/// Compact tracks with a raised selection. All destinations wrap at large text.
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
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.5,
    child: Builder(builder: _content),
  );
  Widget _content(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scheme = Theme.of(context).colorScheme;
          final palette = Theme.of(context).extension<FlexSurfaces>()?.palette;
          final scale = MediaQuery.textScalerOf(context);
          final dense = pages.length > 4;
          final style = TextStyle(
            fontFamily: 'FlexSans',
            fontSize: dense ? 12 : 14,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
          );
          final available = math.max(48.0, constraints.maxWidth - 12);
          final rows = <List<(int, String, double)>>[[]];
          var used = 0.0, height = dense ? 44.0 : 48.0;
          for (final e in pages.entries) {
            final text = TextPainter(
              text: TextSpan(text: e.value, style: style),
              textDirection: Directionality.of(context),
              textScaler: scale,
            )..layout(maxWidth: available - 24);
            final width = (text.width + (dense ? 26 : 24)).clamp(
              48.0,
              available,
            );
            height = math.max(height, text.height + (dense ? 18 : 22));
            text.dispose();
            if (used + width > available && rows.last.isNotEmpty) {
              rows.add([]);
              used = 0;
            }
            rows.last.add((e.key, e.value, width));
            used += width;
          }
          return Column(
            key: ValueKey('$keyPrefix-pills'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Builder(
                  builder: (ctx) {
                    final natural = row.fold(0.0, (sum, e) => sum + e.$3);
                    final width = math.min(
                      available,
                      math.max(natural, pages.length == 1 ? 160.0 : 0.0),
                    );
                    final extra = (width - natural) / row.length;
                    var left = 0.0;
                    final positions = <(int, String, double, double)>[];
                    for (final e in row) {
                      positions.add((e.$1, e.$2, left, e.$3 + extra));
                      left += e.$3 + extra;
                    }
                    return SizedBox(
                      width: width + 12,
                      height: height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 3,
                            right: 3,
                            top: 5,
                            bottom: 5,
                            child: DecoratedBox(
                              key: ValueKey('$keyPrefix-track-${row.first.$1}'),
                              decoration: BoxDecoration(
                                color:
                                    palette?.workspace ??
                                    scheme.surfaceContainerHigh,
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          for (final e in [
                            ...positions.where((e) => e.$1 != selected),
                            ...positions.where((e) => e.$1 == selected),
                          ])
                            Positioned(
                              left: e.$3 + (e.$1 == selected ? 2 : 6),
                              top: 2,
                              bottom: 2,
                              width: e.$4 + (e.$1 == selected ? 8 : 0),
                              child: Semantics(
                                selected: selected == e.$1,
                                inMutuallyExclusiveGroup: true,
                                child: Material(
                                  color: selected == e.$1
                                      ? scheme.primary
                                      : Colors.transparent,
                                  elevation: selected == e.$1 ? 2 : 0,
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    key: ValueKey('$keyPrefix-${e.$1}'),
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => onSelected(e.$1),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Center(
                                        child: Text(
                                          e.$2,
                                          textAlign: TextAlign.center,
                                          style: style.copyWith(
                                            fontSize: dense
                                                ? 12
                                                : selected == e.$1
                                                ? 14
                                                : 13,
                                            fontWeight: selected == e.$1
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: selected == e.$1
                                                ? scheme.onPrimary
                                                : palette?.workspaceInk ??
                                                      scheme.onSurface,
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
                    );
                  },
                ),
            ],
          );
        },
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
    child: Builder(builder: _content),
  );
  Widget _content(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('bottom-navigation-surface'),
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in const [
                (0, 'Kalender', Icons.calendar_month_outlined),
                (1, 'Live', Icons.bolt_outlined),
                (2, 'Organisation', Icons.assignment_outlined),
                (3, 'Material', Icons.folder_outlined),
                (4, 'Mehr', Icons.more_horiz),
              ])
                Expanded(
                  child: Semantics(
                    selected: selected == e.$1,
                    button: true,
                    child: Tooltip(
                      excludeFromSemantics: e.$1 != 4,
                      message: e.$1 == 4 ? 'Weitere Bereiche' : e.$2,
                      child: InkWell(
                        key: ValueKey('bottom-${e.$1}'),
                        onTap: () => onSelected(e.$1),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: selected == e.$1
                                      ? scheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  e.$3,
                                  size: 23,
                                  color: selected == e.$1
                                      ? scheme.onPrimaryContainer
                                      : Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.$2,
                                textAlign: TextAlign.center,
                                softWrap: true,
                                style: TextStyle(
                                  color: selected == e.$1
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 11,
                                  height: 1.1,
                                  fontWeight: selected == e.$1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
    );
  }
}
