import 'package:flutter/material.dart';
import 'surfaces.dart';

/// Centered navigation from the final pill-navigation.css reference.
class FlexPagePills extends StatelessWidget {
  const FlexPagePills({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.more,
    this.classroomPages = false,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget more;
  final bool classroomPages;

  @override
  Widget build(BuildContext context) {
    final pages = {
      0: 'Übersicht',
      1: 'Schüler',
      if (classroomPages) 2: 'Kalender',
      if (classroomPages) 3: 'Materialien',
    };
    final colors = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<FlexSurfaces>()?.palette;
    if ((classroomPages || MediaQuery.textScalerOf(context).scale(1) > 1.5) &&
        MediaQuery.sizeOf(context).width < 600) {
      return Center(
        child: Wrap(
          key: const ValueKey('page-pills'),
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final item in pages.entries)
              TextButton(
                key: ValueKey('page-${item.key}'),
                onPressed: () => onSelected(item.key),
                style: TextButton.styleFrom(
                  backgroundColor: selected == item.key
                      ? colors.primary
                      : palette?.workspace ?? colors.surfaceContainerHigh,
                  foregroundColor: selected == item.key
                      ? colors.onPrimary
                      : palette?.workspaceInk ?? colors.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Text(item.value, textAlign: TextAlign.center),
              ),
            Material(
              color: selected == pages.length
                  ? colors.primary
                  : palette?.workspace ?? colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: 64,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: selected == pages.length
                        ? colors.onPrimary
                        : colors.onSurface,
                  ),
                  child: more,
                ),
              ),
            ),
          ],
        ),
      );
    }
    Widget segment(int index, Widget child) => Expanded(
      child: OverflowBox(
        minHeight: index == selected ? 50 : 42,
        maxHeight: index == selected ? 50 : 42,
        child: Material(
          color: index == selected ? colors.primary : Colors.transparent,
          elevation: index == selected ? 4 : 0,
          shadowColor: const Color(0x250c180c),
          borderRadius: BorderRadius.circular(999),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: 'FlexSans',
              fontSize: index == selected ? 17 : 14,
              fontWeight: index == selected ? FontWeight.w700 : FontWeight.w600,
              color: index == selected
                  ? colors.onPrimary
                  : Theme.of(
                          context,
                        ).extension<FlexSurfaces>()?.palette?.workspaceInk ??
                        colors.onSurface,
            ),
            child: child,
          ),
        ),
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: classroomPages ? 650 : 380),
        child: SizedBox(
          key: const ValueKey('page-pills'),
          height: 64,
          child: Center(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color:
                    Theme.of(
                      context,
                    ).extension<FlexSurfaces>()?.palette?.workspace ??
                    colors.surfaceContainerHigh,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  for (final item in pages.entries)
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
                            child: Center(
                              child: Text(
                                item.value,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  segment(pages.length, more),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
