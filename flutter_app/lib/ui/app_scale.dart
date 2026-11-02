import 'package:flutter/material.dart';

/// Scale layout, painting and hit testing together. The navigator stays mounted
/// while changing scale; keyboard and safe-area insets use the same coordinates.
class FlexAppScale extends StatelessWidget {
  const FlexAppScale({
    super.key,
    required this.scale,
    required this.textScale,
    required this.child,
  });
  final double scale, textScale;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final size = constraints.biggest / scale;
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: MediaQuery(
                data: media.copyWith(
                  size: size,
                  devicePixelRatio: media.devicePixelRatio * scale,
                  padding: media.padding / scale,
                  viewPadding: media.viewPadding / scale,
                  viewInsets: media.viewInsets / scale,
                  systemGestureInsets: media.systemGestureInsets / scale,
                  textScaler: _TextScale(media.textScaler, textScale),
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TextScale extends TextScaler {
  const _TextScale(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(1);
  @override
  bool operator ==(Object other) =>
      other is _TextScale && other.system == system && other.factor == factor;
  @override
  int get hashCode => Object.hash(system, factor);
}
