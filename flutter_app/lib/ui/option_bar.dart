import 'package:flutter/material.dart';
import 'surfaces.dart';

/// Equal, directly visible options. Large text can use one option per row.
class OptionBar extends StatelessWidget {
  const OptionBar({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'option',
    this.colors = const {},
    this.icons = const {},
    this.minButtonHeight = 30,
    this.fontSize = 13,
    this.horizontalPadding = 6,
  });
  final Map<String, String> options;
  final String value, keyPrefix;
  final ValueChanged<String>? onChanged;
  final Map<String, Color> colors;
  final Map<String, IconData> icons;
  final double minButtonHeight, fontSize, horizontalPadding;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scheme = Theme.of(context).colorScheme;
      Widget button(MapEntry<String, String> entry) {
        final selected = entry.key == value;
        final color = colors[entry.key] ?? scheme.primary;
        final foreground = selected ? legibleOn(color) : scheme.onSurface;
        return Semantics(
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: TextButton(
            key: ValueKey('$keyPrefix-${entry.key}'),
            onPressed: onChanged == null ? null : () => onChanged!(entry.key),
            style: TextButton.styleFrom(
              backgroundColor: selected ? color : Colors.transparent,
              foregroundColor: foreground,
              backgroundBuilder: (context, states, child) => DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: selected ? FlexDesign.wash(color) : null,
                ),
                child: child,
              ),
              minimumSize: Size(0, minButtonHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 5,
              ),
              textStyle: TextStyle(
                fontFamily: 'FlexSans',
                fontSize: fontSize,
                height: 1.2,
              ),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icons[entry.key] != null) ...[
                  Icon(
                    icons[entry.key],
                    size: 17,
                    color: selected ? foreground : color,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(child: Text(entry.value, textAlign: TextAlign.center)),
              ],
            ),
          ),
        );
      }

      final slotWidth = (constraints.maxWidth - 4) / options.length;
      final vertical = options.entries.any((entry) {
        final painter = TextPainter(
          text: TextSpan(
            text: entry.value,
            style: TextStyle(
              fontFamily: 'FlexSans',
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final tooWide =
            painter.width +
                horizontalPadding * 2 +
                4 +
                (icons.containsKey(entry.key) ? 23 : 0) >
            slotWidth;
        painter.dispose();
        return tooWide;
      });
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: FlexDesign.capsule(
          context,
        ).copyWith(borderRadius: BorderRadius.circular(vertical ? 18 : 99)),
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: options.entries.map(button).toList(),
              )
            : Row(
                children: [
                  for (final entry in options.entries)
                    Expanded(child: button(entry)),
                ],
              ),
      );
    },
  );
}
