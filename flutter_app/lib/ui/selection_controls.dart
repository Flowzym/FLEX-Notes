import 'package:flutter/material.dart';

class SelectionControls extends StatelessWidget {
  const SelectionControls({
    super.key,
    required this.count,
    required this.allVisibleSelected,
    required this.onToggleAll,
    required this.onFinish,
    this.actions = const [],
  });

  final int count;
  final bool allVisibleSelected;
  final VoidCallback? onToggleAll, onFinish;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(liveRegion: true, child: Text('$count ausgewählt')),
          IconButton(
            tooltip: allVisibleSelected
                ? 'Angezeigte abwählen'
                : 'Alle angezeigten auswählen',
            onPressed: onToggleAll,
            icon: Icon(allVisibleSelected ? Icons.deselect : Icons.select_all),
          ),
          ...actions,
          IconButton(
            tooltip: 'Auswahl beenden',
            onPressed: onFinish,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}

/// A normal row keeps its own tap actions. In selection mode the entire row
/// becomes a single labelled checkbox, including its former action targets.
class SelectableEntry extends StatelessWidget {
  const SelectableEntry({
    super.key,
    required this.child,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onSelect,
  });
  final Widget child;
  final String title;
  final String? subtitle;
  final bool? selected;
  final VoidCallback? onSelect;
  @override
  Widget build(BuildContext context) {
    if (selected == null) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onSelect,
        child: child,
      );
    }
    return CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: selected,
      selected: selected!,
      onChanged: onSelect == null ? null : (_) => onSelect!(),
    );
  }
}
