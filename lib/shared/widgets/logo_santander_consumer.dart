import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Isotipo rojo inspirado en Santander Consumer Perú para el branding interno.
class LogoSantanderConsumerPeru extends StatelessWidget {
  final double size;
  const LogoSantanderConsumerPeru({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SantanderMarkPainter(),
        size: Size(size, size),
      ),
    );
  }
}

class _SantanderMarkPainter extends CustomPainter {
  static const _design = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _design * 0.92;
    final dx = (size.width - _design * scale) / 2;
    final dy = (size.height - _design * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    const center = Offset(50, 52);

    canvas.drawCircle(
      center,
      46,
      Paint()
        ..color = Colors.white
        ..isAntiAlias = true,
    );

    canvas.drawCircle(
      center,
      46,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true,
    );

    final flame = Path()
      ..moveTo(50, 14)
      ..cubicTo(58, 22, 64, 32, 62, 44)
      ..cubicTo(72, 50, 78, 60, 74, 72)
      ..cubicTo(70, 84, 58, 90, 46, 88)
      ..cubicTo(34, 86, 26, 76, 26, 64)
      ..cubicTo(26, 52, 32, 42, 42, 36)
      ..cubicTo(40, 44, 44, 52, 52, 56)
      ..cubicTo(48, 46, 44, 38, 46, 28)
      ..cubicTo(47, 22, 48, 18, 50, 14)
      ..close();

    canvas.drawPath(
      flame,
      Paint()
        ..color = AppColors.primary
        ..isAntiAlias = true,
    );

    final highlight = Path()
      ..moveTo(42, 70)
      ..cubicTo(46, 58, 58, 54, 58, 44)
      ..cubicTo(66, 54, 64, 66, 56, 74)
      ..cubicTo(52, 78, 46, 78, 38, 74)
      ..close();

    canvas.drawPath(
      highlight,
      Paint()
        ..color = Colors.white
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
