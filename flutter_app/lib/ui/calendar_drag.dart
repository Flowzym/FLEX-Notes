import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../domain/calendar.dart';
import '../domain/calendar_edit.dart';
import '../domain/models.dart';

/// Long-press claims the gesture before moving a block, leaving ordinary scroll
/// and period swipes untouched. Changes are committed only on pointer release.
class CalendarDragBlock extends StatefulWidget {
  const CalendarDragBlock({
    super.key,
    required this.item,
    required this.child,
    required this.days,
    required this.dayWidth,
    required this.pixelsPerMinute,
    required this.onChange,
  });
  final CalendarItem item;
  final Widget child;
  final List<DateTime> days;
  final double dayWidth, pixelsPerMinute;
  final Future<void> Function(CalendarItem, CalendarEdit) onChange;
  @override
  State<CalendarDragBlock> createState() => _CalendarDragBlockState();
}

class _CalendarDragBlockState extends State<CalendarDragBlock> {
  CalendarEdit? origin, preview;
  bool selected = false, saving = false;
  int kind = 0; // 0 move, -1 start, 1 end
  Offset delta = Offset.zero;
  Offset? finger;
  ScrollPosition? scroll;
  double scrollStart = 0;
  Timer? ticker;

  @override
  void didUpdateWidget(covariant CalendarDragBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.time != widget.item.time ||
        oldWidget.item.end != widget.item.end ||
        oldWidget.item.date != widget.item.date) {
      cancel();
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  bool hintShown = false;
  void start(int handle, Offset point) {
    if (saving) return;
    HapticFeedback.selectionClick();
    scroll = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    scrollStart = scroll?.pixels ?? 0;
    setState(() {
      selected = true;
      kind = handle;
      origin = CalendarEdit.fromItem(widget.item);
      preview = origin;
      delta = Offset.zero;
      finger = point;
    });
    if (handle == 0 && !hintShown) {
      hintShown = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Termin ziehen · An den Enden die Dauer ändern'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    ticker?.cancel();
    ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final position = scroll, point = finger;
      if (!mounted || position == null || point == null || origin == null) {
        return;
      }
      final box = position.context.notificationContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final local = box.globalToLocal(point);
      final step = local.dy < 48
          ? -12.0
          : local.dy > box.size.height - 48
          ? 12.0
          : 0.0;
      if (step == 0) return;
      final next = (position.pixels + step).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) return;
      position.jumpTo(next);
      updatePreview();
    });
  }

  void update(Offset displacement, Offset point) {
    if (origin == null) return;
    delta = displacement;
    finger = point;
    updatePreview();
  }

  void updatePreview() {
    final initial = origin;
    if (initial == null) return;
    final minutes =
        ((delta.dy + (scroll?.pixels ?? scrollStart) - scrollStart) /
                widget.pixelsPerMinute)
            .round();
    final dayIndex = widget.days.indexWhere((d) => dateOnly(d) == initial.date);
    final day = (dayIndex + (delta.dx / widget.dayWidth).round()).clamp(
      0,
      widget.days.length - 1,
    );
    final next = kind == 0
        ? initial.move(minutes: minutes, day: dateOnly(widget.days[day]))
        : initial.resize(minutes, beginning: kind < 0);
    if (preview?.sameAs(next) == true) return;
    HapticFeedback.selectionClick();
    setState(() => preview = next);
  }

  void cancel() {
    ticker?.cancel();
    origin = null;
    preview = null;
    finger = null;
  }

  Future<void> finish() async {
    ticker?.cancel();
    finger = null;
    final initial = origin, changed = preview;
    if (initial == null || changed == null) return;
    if (initial.sameAs(changed)) {
      setState(cancel);
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onChange(widget.item, changed);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          cancel();
        });
      }
    }
  }

  Widget handle(bool top) => Semantics(
    label: top ? 'Terminbeginn anpassen' : 'Terminende anpassen',
    child: GestureDetector(
      key: ValueKey(
        'calendar-resize-${top ? 'start' : 'end'}-${widget.item.id}',
      ),
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: (d) => start(top ? -1 : 1, d.globalPosition),
      onVerticalDragUpdate: (d) =>
          update(delta + Offset(0, d.delta.dy), d.globalPosition),
      onVerticalDragEnd: (_) => finish(),
      onVerticalDragCancel: () => setState(cancel),
      child: SizedBox(
        height: 28,
        child: Center(
          child: Container(
            width: 26,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final original = CalendarEdit.fromItem(widget.item);
    final value = preview ?? original;
    final fromDay = widget.days.indexWhere((d) => dateOnly(d) == original.date);
    final toDay = widget.days.indexWhere((d) => dateOnly(d) == value.date);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, box) {
        final height = math.max(
          44.0,
          box.maxHeight +
              ((value.end - value.start) - (original.end - original.start)) *
                  widget.pixelsPerMinute,
        );
        return Transform.translate(
          offset: Offset(
            (toDay - fromDay) * widget.dayWidth,
            (value.start - original.start) * widget.pixelsPerMinute,
          ),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: height,
            maxHeight: height,
            child: TapRegion(
              onTapOutside: (_) {
                if (origin == null && selected) {
                  setState(() => selected = false);
                }
              },
              child: GestureDetector(
                key: ValueKey('calendar-drag-${widget.item.id}'),
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (d) => start(0, d.globalPosition),
                onLongPressMoveUpdate: (d) =>
                    update(d.offsetFromOrigin, d.globalPosition),
                onLongPressEnd: (_) => finish(),
                onLongPressCancel: () => setState(cancel),
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    widget.child,
                    if (selected)
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    if (selected && !saving) ...[
                      Positioned(
                        top: -12,
                        left: 0,
                        right: 0,
                        child: handle(true),
                      ),
                      Positioned(
                        bottom: -12,
                        left: 0,
                        right: 0,
                        child: handle(false),
                      ),
                    ],
                    if (origin != null || saving)
                      Positioned(
                        top: -30,
                        left: 0,
                        child: IgnorePointer(
                          child: Material(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(6),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                '${value.startTime}–${value.endTime}${saving ? ' …' : ''}',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
