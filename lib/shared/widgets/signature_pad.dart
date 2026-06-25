import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Controlador del lienzo de firma: guarda los trazos y permite limpiarlos.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> trazos = [];

  bool get isEmpty => trazos.every((t) => t.isEmpty);
  bool get isNotEmpty => !isEmpty;

  void iniciarTrazo(Offset p) {
    trazos.add([p]);
    notifyListeners();
  }

  void agregarPunto(Offset p) {
    if (trazos.isEmpty) trazos.add([]);
    trazos.last.add(p);
    notifyListeners();
  }

  void limpiar() {
    trazos.clear();
    notifyListeners();
  }
}

/// Lienzo tactil para la firma del cliente (RF-48 / RF-57).
class SignaturePad extends StatelessWidget {
  final SignatureController controller;
  final double height;
  const SignaturePad({super.key, required this.controller, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.neutral),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onPanStart: (d) => controller.iniciarTrazo(d.localPosition),
            onPanUpdate: (d) => controller.agregarPunto(d.localPosition),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, __) => CustomPaint(
                  painter: _FirmaPainter(controller.trazos),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: controller.limpiar,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Limpiar firma'),
        ),
      ],
    );
  }
}

class _FirmaPainter extends CustomPainter {
  final List<List<Offset>> trazos;
  _FirmaPainter(this.trazos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final trazo in trazos) {
      for (var i = 0; i < trazo.length - 1; i++) {
        canvas.drawLine(trazo[i], trazo[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FirmaPainter old) => true;
}
