import 'package:flutter/material.dart';
import '../domain/school.dart';

enum FlexSymbol { goal, social, work, homework, orga }

/// Consistent, quiet outlines rather than heavy silhouettes.
class FlexIcon extends StatelessWidget {
  const FlexIcon(
    this.symbol, {
    super.key,
    this.size = 26,
    this.color,
    this.label,
  });
  final FlexSymbol symbol;
  final double size;
  final Color? color;
  final String? label;
  static FlexSymbol forKind(SchoolKind kind) => switch (kind) {
    SchoolKind.goal => FlexSymbol.goal,
    SchoolKind.social => FlexSymbol.social,
    SchoolKind.work => FlexSymbol.work,
    SchoolKind.homework => FlexSymbol.homework,
  };
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: label != null,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _Glyph(
          symbol,
          color ??
              IconTheme.of(context).color ??
              Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

class _Glyph extends CustomPainter {
  const _Glyph(this.symbol, this.color);
  final FlexSymbol symbol;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (symbol) {
      case FlexSymbol.goal:
        canvas.drawArc(
          const Rect.fromLTWH(2, 4, 18, 18),
          -.5,
          5.75,
          false,
          pen,
        );
        canvas.drawArc(
          const Rect.fromLTWH(6, 8, 10, 10),
          -.4,
          5.65,
          false,
          pen,
        );
        path
          ..moveTo(11, 13)
          ..lineTo(20, 4)
          ..lineTo(20, 1)
          ..lineTo(17, 4)
          ..lineTo(17, 7)
          ..moveTo(17, 7)
          ..lineTo(20, 7)
          ..lineTo(23, 4)
          ..lineTo(20, 4);
      case FlexSymbol.social:
        canvas.drawCircle(const Offset(8, 7), 3.2, pen);
        canvas.drawCircle(const Offset(17.5, 8), 2.5, pen);
        path
          ..moveTo(1.5, 21)
          ..lineTo(1.5, 18)
          ..cubicTo(1.5, 11, 14.5, 11, 14.5, 18)
          ..lineTo(14.5, 21)
          ..moveTo(16, 13)
          ..cubicTo(20, 12, 22.5, 15, 22.5, 18)
          ..lineTo(22.5, 21);
      case FlexSymbol.work:
        path
          ..moveTo(5, 2)
          ..lineTo(14, 2)
          ..lineTo(20, 8)
          ..lineTo(20, 22)
          ..lineTo(5, 22)
          ..close()
          ..moveTo(14, 2)
          ..lineTo(14, 8)
          ..lineTo(20, 8)
          ..moveTo(8, 12)
          ..lineTo(16, 12)
          ..moveTo(8, 15.5)
          ..lineTo(16, 15.5)
          ..moveTo(8, 19)
          ..lineTo(13, 19);
      case FlexSymbol.homework:
        path
          ..moveTo(1, 8)
          ..lineTo(12, 3)
          ..lineTo(23, 8)
          ..lineTo(12, 13)
          ..close()
          ..moveTo(5, 10)
          ..lineTo(5, 17)
          ..quadraticBezierTo(12, 22, 19, 17)
          ..lineTo(19, 10)
          ..moveTo(23, 8)
          ..lineTo(23, 17);
      case FlexSymbol.orga:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 5, 18, 17),
            const Radius.circular(1.5),
          ),
          pen,
        );
        path
          ..moveTo(7, 2)
          ..lineTo(7, 8)
          ..moveTo(17, 2)
          ..lineTo(17, 8)
          ..moveTo(3, 11)
          ..lineTo(21, 11);
    }
    canvas.drawPath(path, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Glyph old) =>
      old.symbol != symbol || old.color != color;
}
