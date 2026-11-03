import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Horizontal swipes change options, including quick touch swipes over text.
/// Long presses, vertical scrolling and mouse text selection remain independent.
class OptionSwipe extends StatefulWidget {
  const OptionSwipe({super.key, required this.child, required this.onChanged});
  final Widget child;
  final ValueChanged<bool> onChanged;
  @override
  State<OptionSwipe> createState() => _OptionSwipeState();
}

class _OptionSwipeState extends State<OptionSwipe> {
  double distance = 0;
  bool editingText = false;
  final pointers = <int>{};
  PointerDownEvent? textStart;

  bool startsInText(Offset position) {
    final hit = HitTestResult();
    RendererBinding.instance.hitTestInView(
      hit,
      position,
      View.of(context).viewId,
    );
    return hit.path.any((entry) => entry.target is RenderEditable);
  }

  void textDown(PointerDownEvent event) {
    pointers.add(event.pointer);
    if (pointers.length != 1) {
      textStart = null;
    } else if (event.kind == PointerDeviceKind.touch &&
        startsInText(event.position)) {
      textStart = event;
    }
  }

  void textMove(PointerMoveEvent event) {
    final start = textStart;
    if (start == null || start.pointer != event.pointer) return;
    final delta = event.position - start.position;
    if (event.timeStamp - start.timeStamp >= kLongPressTimeout ||
        (delta.dy.abs() > kTouchSlop && delta.dy.abs() > delta.dx.abs())) {
      textStart = null;
    }
  }

  void textUp(PointerUpEvent event) {
    final start = textStart;
    pointers.remove(event.pointer);
    textStart = null;
    if (start == null ||
        start.pointer != event.pointer ||
        event.timeStamp - start.timeStamp >= kLongPressTimeout) {
      return;
    }
    final delta = event.position - start.position;
    if (delta.dx.abs() >= 48 && delta.dx.abs() > delta.dy.abs() * 1.5) {
      widget.onChanged(delta.dx > 0);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: textDown,
    onPointerMove: textMove,
    onPointerUp: textUp,
    onPointerCancel: (event) {
      pointers.remove(event.pointer);
      textStart = null;
    },
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragDown: (details) =>
          editingText = startsInText(details.globalPosition),
      onHorizontalDragStart: (_) => distance = 0,
      onHorizontalDragUpdate: (details) =>
          distance += details.primaryDelta ?? 0,
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
    ),
  );
}
