import 'package:flutter/material.dart';

/// Centered navigation from the final pill-navigation.css reference.
class FlexPagePills extends StatelessWidget {
  const FlexPagePills({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.more,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget more;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget segment(int index, Widget child) => Expanded(
      child: OverflowBox(
        minHeight: index == selected ? 42 : 34,
        maxHeight: index == selected ? 42 : 34,
        child: Material(
          color: index == selected ? colors.primary : Colors.transparent,
          elevation: index == selected ? 4 : 0,
          shadowColor: const Color(0x250c180c),
          borderRadius: BorderRadius.circular(999),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: 'FlexSans',
              fontSize: index == selected ? 16 : 13,
              fontWeight: index == selected ? FontWeight.w700 : FontWeight.w600,
              color: index == selected ? colors.onPrimary : colors.onSurface,
            ),
            child: child,
          ),
        ),
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SizedBox(
          key: const ValueKey('page-pills'),
          height: 56,
          child: Center(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  for (final item in const {
                    0: 'Übersicht',
                    1: 'Schüler',
                  }.entries)
                    segment(
                      item.key,
                      Semantics(
                        button: true,
                        selected: selected == item.key,
                        child: InkWell(
                          key: ValueKey('page-${item.key}'),
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => onSelected(item.key),
                          child: SizedBox(
                            width: double.infinity,
                            child: Center(child: Text(item.value)),
                          ),
                        ),
                      ),
                    ),
                  segment(2, more),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
