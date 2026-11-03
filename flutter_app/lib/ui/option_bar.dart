import 'package:flutter/material.dart';

/// Equal, directly visible options. Large text can use one option per row.
class OptionBar extends StatelessWidget {
  const OptionBar({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'option',
    this.colors = const {},
    this.minButtonHeight = 30,
    this.fontSize = 13,
  });
  final Map<String, String> options;
  final String value, keyPrefix;
  final ValueChanged<String>? onChanged;
  final Map<String, Color> colors;
  final double minButtonHeight, fontSize;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scheme = Theme.of(context).colorScheme;
      Widget button(MapEntry<String, String> entry) {
        final selected = entry.key == value;
        final color = colors[entry.key] ?? scheme.primary;
        return Semantics(
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: TextButton(
            key: ValueKey('$keyPrefix-${entry.key}'),
            onPressed: onChanged == null ? null : () => onChanged!(entry.key),
            style: TextButton.styleFrom(
              backgroundColor: selected ? color : Colors.transparent,
              foregroundColor: selected
                  ? (ThemeData.estimateBrightnessForColor(color) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black)
                  : scheme.onSurface,
              minimumSize: Size(0, minButtonHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              textStyle: TextStyle(
                fontFamily: 'FlexSans',
                fontSize: fontSize,
                height: 1.2,
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(entry.value, textAlign: TextAlign.center),
          ),
        );
      }

      final vertical =
          constraints.maxWidth < 400 &&
          MediaQuery.textScalerOf(context).scale(fontSize) > 24;
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(vertical ? 18 : 99),
        ),
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
