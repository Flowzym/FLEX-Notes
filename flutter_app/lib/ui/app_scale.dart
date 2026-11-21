import 'package:flutter/material.dart';

/// Compose the system reading size with the app preference. Layout, touch
/// coordinates and keyboard insets remain in their original logical pixels.
class FlexAppScale extends StatelessWidget {
  const FlexAppScale({super.key, required this.textScale, required this.child});
  final double textScale;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: _TextScale(media.textScaler, textScale)),
      child: child,
    );
  }
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
