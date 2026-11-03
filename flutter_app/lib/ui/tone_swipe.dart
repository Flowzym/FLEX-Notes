import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Horizontal gestures switch the tone; vertical scrolling remains independent.
class ToneSwipe extends StatefulWidget {
  const ToneSwipe({super.key, required this.child, required this.onChanged});
  final Widget child;
  final ValueChanged<bool> onChanged;
  @override
  State<ToneSwipe> createState() => _ToneSwipeState();
}

class _ToneSwipeState extends State<ToneSwipe> {
  double distance = 0;
  bool editingText = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragDown: (details) {
      final hit = HitTestResult();
      RendererBinding.instance.hitTestInView(
        hit,
        details.globalPosition,
        View.of(context).viewId,
      );
      editingText = hit.path.any((entry) => entry.target is RenderEditable);
    },
    onHorizontalDragStart: (_) => distance = 0,
    onHorizontalDragUpdate: (details) => distance += details.primaryDelta ?? 0,
    onHorizontalDragCancel: () => distance = 0,
    onHorizontalDragEnd: (details) {
      final velocity = details.primaryVelocity ?? 0;
      if (!editingText &&
          (distance.abs() >= 48 ||
              (distance.abs() >= 16 && velocity.abs() > 450))) {
        widget.onChanged(distance > 0);
      }
      distance = 0;
    },
    child: widget.child,
  );
}
