import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget de fondo compartido con iconos médicos sutiles.
/// Úsalo envolviendo el contenido de cada pantalla:
///
/// ```dart
/// body: MedicalBackground(
///   child: SafeArea(child: ...),
/// )
/// ```
class MedicalBackground extends StatelessWidget {
  final Widget child;
  const MedicalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          size: Size(
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height,
          ),
          painter: MedicalBackgroundPainter(),
        ),
        child,
      ],
    );
  }
}

/// CustomPainter que dibuja el fondo claro con iconos médicos decorativos.
class MedicalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF0F7FC);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    final iconPaint = Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    _drawMedicalIcons(canvas, size, iconPaint, fillPaint);
  }

  void _drawMedicalIcons(
    Canvas canvas,
    Size size,
    Paint strokePaint,
    Paint fillPaint,
  ) {
    final random = math.Random(42);
    final positions = [
      Offset(size.width * 0.1, size.height * 0.08),
      Offset(size.width * 0.85, size.height * 0.12),
      Offset(size.width * 0.05, size.height * 0.25),
      Offset(size.width * 0.92, size.height * 0.28),
      Offset(size.width * 0.15, size.height * 0.45),
      Offset(size.width * 0.88, size.height * 0.5),
      Offset(size.width * 0.08, size.height * 0.65),
      Offset(size.width * 0.9, size.height * 0.72),
      Offset(size.width * 0.12, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.9),
      Offset(size.width * 0.5, size.height * 0.05),
      Offset(size.width * 0.3, size.height * 0.18),
      Offset(size.width * 0.7, size.height * 0.35),
      Offset(size.width * 0.25, size.height * 0.7),
      Offset(size.width * 0.75, size.height * 0.82),
    ];

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final iconType = i % 4;
      final iconSize = 25.0 + random.nextDouble() * 15;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate((random.nextDouble() - 0.5) * 0.3);

      switch (iconType) {
        case 0:
          _drawCross(canvas, iconSize, strokePaint, fillPaint);
          break;
        case 1:
          _drawHeart(canvas, iconSize, strokePaint, fillPaint);
          break;
        case 2:
          _drawStethoscope(canvas, iconSize, strokePaint);
          break;
        case 3:
          _drawPlusSign(canvas, iconSize, strokePaint);
          break;
      }
      canvas.restore();
    }
  }

  void _drawCross(
    Canvas canvas,
    double size,
    Paint strokePaint,
    Paint fillPaint,
  ) {
    final path = Path();
    final armWidth = size * 0.35;
    final armLength = size;
    path.moveTo(-armWidth / 2, -armLength / 2);
    path.lineTo(armWidth / 2, -armLength / 2);
    path.lineTo(armWidth / 2, -armWidth / 2);
    path.lineTo(armLength / 2, -armWidth / 2);
    path.lineTo(armLength / 2, armWidth / 2);
    path.lineTo(armWidth / 2, armWidth / 2);
    path.lineTo(armWidth / 2, armLength / 2);
    path.lineTo(-armWidth / 2, armLength / 2);
    path.lineTo(-armWidth / 2, armWidth / 2);
    path.lineTo(-armLength / 2, armWidth / 2);
    path.lineTo(-armLength / 2, -armWidth / 2);
    path.lineTo(-armWidth / 2, -armWidth / 2);
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawHeart(
    Canvas canvas,
    double size,
    Paint strokePaint,
    Paint fillPaint,
  ) {
    final path = Path();
    final halfSize = size / 2;
    path.moveTo(0, halfSize * 0.8);
    path.cubicTo(
      -halfSize * 1.2, halfSize * 0.2,
      -halfSize * 1.2, -halfSize * 0.6,
      0, -halfSize * 0.2,
    );
    path.cubicTo(
      halfSize * 1.2, -halfSize * 0.6,
      halfSize * 1.2, halfSize * 0.2,
      0, halfSize * 0.8,
    );
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawStethoscope(Canvas canvas, double size, Paint strokePaint) {
    final path = Path();
    path.addOval(
      Rect.fromCircle(
        center: Offset(-size * 0.3, -size * 0.4),
        radius: size * 0.15,
      ),
    );
    path.addOval(
      Rect.fromCircle(
        center: Offset(size * 0.3, -size * 0.4),
        radius: size * 0.15,
      ),
    );
    canvas.drawPath(path, strokePaint);
    final tubePath = Path();
    tubePath.moveTo(-size * 0.2, -size * 0.3);
    tubePath.quadraticBezierTo(0, 0, 0, size * 0.3);
    tubePath.moveTo(size * 0.2, -size * 0.3);
    tubePath.quadraticBezierTo(0, 0, 0, size * 0.3);
    canvas.drawPath(tubePath, strokePaint);
    canvas.drawCircle(Offset(0, size * 0.4), size * 0.2, strokePaint);
  }

  void _drawPlusSign(Canvas canvas, double size, Paint strokePaint) {
    canvas.drawLine(
      Offset(-size / 2, 0),
      Offset(size / 2, 0),
      strokePaint..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(0, -size / 2),
      Offset(0, size / 2),
      strokePaint..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
