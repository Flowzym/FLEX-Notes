import 'package:flutter/material.dart';

/// A smaller switch drawing with an unscaled interaction area.
class CompactSwitch extends StatelessWidget {
  const CompactSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.materialTapTargetSize = MaterialTapTargetSize.padded,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final MaterialTapTargetSize materialTapTargetSize;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: materialTapTargetSize == MaterialTapTargetSize.padded ? 48 : 40,
    child: Transform.scale(
      scale: .86,
      transformHitTests: false,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: materialTapTargetSize,
        padding: EdgeInsets.zero,
      ),
    ),
  );
}

/// The entire labeled row remains tappable and has one switch semantic node.
class CompactSwitchListTile extends StatelessWidget {
  const CompactSwitchListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.contentPadding,
    this.leading,
  });
  final Widget title;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      title: title,
      leading: leading,
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      contentPadding: contentPadding,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: ExcludeFocus(
        child: CompactSwitch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ),
  );
}
