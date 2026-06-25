import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Isotipo de Banco Andino: flor de 6 petalos en rojo y blanco.
class LogoAndino extends StatelessWidget {
  final double size;
  const LogoAndino({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FlorPainter(),
        size: Size(size, size),
      ),
    );
  }
}

class _FlorPainter extends CustomPainter {
  static const _petalos = [
    AppColors.primary,
    Colors.white,
    AppColors.primaryDark,
    Colors.white,
    AppColors.primary,
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 100 * 0.88;
    final dx = (size.width - 100 * scale) / 2;
    final dy = (size.height - 100 * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    const c = Offset(50, 50);
    const r = 50.0;
    const petalW = r * 0.52;
    const petalH = r * 0.72;

    for (var i = 0; i < _petalos.length; i++) {
      final paint = Paint()
        ..color = _petalos[i]
        ..isAntiAlias = true;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * math.pi / 3);
      final rect = Rect.fromCenter(
        center: const Offset(0, -r * 0.38),
        width: petalW,
        height: petalH,
      );
      canvas.drawOval(rect, paint);
      if (_petalos[i] == Colors.white) {
        canvas.drawOval(
          rect,
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      canvas.restore();
    }

    canvas.drawCircle(c, r * 0.22, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.14, Paint()..color = AppColors.primary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
