import 'package:flutter/material.dart';
import '../domain/school.dart';

enum FlexSymbol { goal, social, work, homework, orga }

/// Filled, scalable silhouettes following the five-symbol user reference.
/// Drawn directly by Flutter; no embedded HTML or raster-image dependency.
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
              Theme.of(context).colorScheme.onSurface,
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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()..fillType = PathFillType.evenOdd;
    switch (symbol) {
      case FlexSymbol.goal:
        path.addOval(const Rect.fromLTWH(1, 3, 20, 20));
        path.addOval(const Rect.fromLTWH(4, 6, 14, 14));
        path.addOval(const Rect.fromLTWH(7, 9, 8, 8));
        path.addOval(const Rect.fromLTWH(9.5, 11.5, 3, 3));
        canvas.drawPath(path, paint);
        canvas.drawPath(
          Path()
            ..moveTo(10, 14)
            ..lineTo(12, 15)
            ..lineTo(20, 7)
            ..lineTo(22, 7)
            ..lineTo(24, 4)
            ..lineTo(21, 4)
            ..lineTo(20, 1)
            ..lineTo(17, 4)
            ..lineTo(17, 6)
            ..close(),
          paint,
        );
      case FlexSymbol.social:
        path.addOval(const Rect.fromLTWH(3, 2, 9, 9));
        path.addOval(const Rect.fromLTWH(14, 5, 7, 7));
        path.addRRect(
          RRect.fromRectAndCorners(
            const Rect.fromLTWH(1, 12, 14, 10),
            topLeft: const Radius.circular(7),
            topRight: const Radius.circular(7),
            bottomLeft: const Radius.circular(2),
            bottomRight: const Radius.circular(2),
          ),
        );
        path.addRRect(
          RRect.fromRectAndCorners(
            const Rect.fromLTWH(16, 13, 7, 9),
            topRight: const Radius.circular(7),
            bottomRight: const Radius.circular(2),
          ),
        );
        canvas.drawPath(path, paint);
      case FlexSymbol.work:
        path.moveTo(5, 1);
        path.lineTo(15, 1);
        path.lineTo(21, 7);
        path.lineTo(21, 20);
        path.quadraticBezierTo(21, 23, 18, 23);
        path.lineTo(5, 23);
        path.quadraticBezierTo(2, 23, 2, 20);
        path.lineTo(2, 4);
        path.quadraticBezierTo(2, 1, 5, 1);
        path.close();
        for (final y in [9.0, 13.0, 17.0]) {
          path.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(6, y, y == 17 ? 8 : 11, 1.8),
              const Radius.circular(.9),
            ),
          );
        }
        canvas.drawPath(path, paint);
      case FlexSymbol.homework:
        path.moveTo(1, 11);
        path.lineTo(11, 1);
        path.quadraticBezierTo(12, 0, 13, 1);
        path.lineTo(23, 11);
        path.quadraticBezierTo(24, 13, 21, 13);
        path.lineTo(21, 21);
        path.quadraticBezierTo(21, 23, 19, 23);
        path.lineTo(15, 23);
        path.lineTo(15, 16);
        path.quadraticBezierTo(15, 15, 14, 15);
        path.lineTo(10, 15);
        path.quadraticBezierTo(9, 15, 9, 16);
        path.lineTo(9, 23);
        path.lineTo(5, 23);
        path.quadraticBezierTo(3, 23, 3, 21);
        path.lineTo(3, 13);
        path.quadraticBezierTo(0, 13, 1, 11);
        path.close();
        canvas.drawPath(path, paint);
      case FlexSymbol.orga:
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 4, 22, 19),
            const Radius.circular(3),
          ),
        );
        path.addRect(const Rect.fromLTWH(2, 8, 20, 1));
        for (final y in [12.0, 17.0]) {
          for (final x in [5.0, 10.5, 16.0]) {
            path.addRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, 3, 3),
                const Radius.circular(.7),
              ),
            );
          }
        }
        canvas.drawPath(path, paint);
        for (final x in [6.0, 17.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 1, 2, 5),
              const Radius.circular(1),
            ),
            paint,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Glyph old) => old.symbol != symbol || old.color != color;
}
