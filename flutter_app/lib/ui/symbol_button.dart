import 'package:flutter/material.dart';

/// Compact symbol control with a full touch target and a spoken/tooltip label.
class FlexSymbolButton extends StatelessWidget {
  const FlexSymbolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected,
    this.exclusive = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool? selected;
  final bool exclusive;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: exclusive,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.all(10),
          foregroundColor: selected == true ? scheme.primary : scheme.onSurface,
          backgroundColor: selected == true
              ? scheme.primary.withValues(alpha: .15)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: selected == true
                ? BorderSide(color: scheme.primary)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
