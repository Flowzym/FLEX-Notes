import 'package:flutter/material.dart';

/// Keeps titles readable when larger text leaves too little room for actions.
class ActionHeading extends StatelessWidget {
  const ActionHeading({
    super.key,
    required this.leading,
    required this.actions,
  });
  final Widget leading;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, constraints) {
      if (constraints.maxWidth < 480 &&
          (MediaQuery.textScalerOf(ctx).scale(16) > 22 ||
              constraints.maxWidth - actions.length * 48 < 140)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leading,
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(alignment: WrapAlignment.end, children: actions),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: leading),
          ...actions,
        ],
      );
    },
  );
}
