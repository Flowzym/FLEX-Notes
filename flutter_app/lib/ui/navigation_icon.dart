import 'package:flutter/material.dart';

/// Navigation glyphs share one optical grid and stroke weight.
class FlexNavigationIcon extends StatelessWidget {
  const FlexNavigationIcon({
    super.key,
    required this.destination,
    required this.color,
  });
  final int destination;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 26,
    child: CustomPaint(painter: _NavigationGlyph(destination, color)),
  );
}

class _NavigationGlyph extends CustomPainter {
  const _NavigationGlyph(this.destination, this.color);
  final int destination;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (destination) {
      case 0:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(3, 5, 21, 22),
            const Radius.circular(2),
          ),
          pen,
        );
        path
          ..moveTo(7, 2)
          ..lineTo(7, 7)
          ..moveTo(17, 2)
          ..lineTo(17, 7)
          ..moveTo(3, 10)
          ..lineTo(21, 10);
      case 1:
        canvas.drawCircle(const Offset(8, 6), 3, pen);
        path
          ..moveTo(2, 21)
          ..lineTo(2, 18)
          ..cubicTo(2, 11, 14, 11, 14, 18)
          ..lineTo(14, 21)
          ..moveTo(16, 3)
          ..cubicTo(21, 3, 21, 10, 16, 10)
          ..moveTo(17, 13)
          ..cubicTo(21, 13, 22, 15, 22, 18)
          ..lineTo(22, 21);
      case 2:
        path
          ..moveTo(2, 8)
          ..lineTo(12, 2)
          ..lineTo(22, 8)
          ..lineTo(12, 14)
          ..close()
          ..moveTo(2, 12)
          ..lineTo(12, 18)
          ..lineTo(22, 12)
          ..moveTo(2, 16)
          ..lineTo(12, 22)
          ..lineTo(22, 16);
      case 3:
        path
          ..moveTo(4, 4)
          ..lineTo(9, 4)
          ..lineTo(12, 7)
          ..lineTo(20, 7)
          ..quadraticBezierTo(22, 7, 22, 9)
          ..lineTo(22, 19)
          ..quadraticBezierTo(22, 21, 20, 21)
          ..lineTo(4, 21)
          ..quadraticBezierTo(2, 21, 2, 19)
          ..lineTo(2, 6)
          ..quadraticBezierTo(2, 4, 4, 4)
          ..close();
      case 4:
        final dot = Paint()..color = color;
        for (final x in [3.5, 12.0, 20.5]) {
          canvas.drawCircle(Offset(x, 12), 1.7, dot);
        }
    }
    canvas.drawPath(path, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NavigationGlyph oldDelegate) =>
      destination != oldDelegate.destination || color != oldDelegate.color;
}
