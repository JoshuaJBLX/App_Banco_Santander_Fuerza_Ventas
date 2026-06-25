import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'gradient_app_bar.dart';

/// Placeholder reutilizable para modulos en scaffold (aun no implementados).
/// Mantiene la navegacion funcional mientras se desarrollan M2..M11.
class ModuloPlaceholder extends StatelessWidget {
  final String titulo;
  final String modulo; // p. ej. "M2"
  final IconData icono;
  const ModuloPlaceholder({
    super.key,
    required this.titulo,
    required this.modulo,
    this.icono = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: titulo),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 64, color: AppColors.neutral),
            const SizedBox(height: 16),
            Text('$modulo — $titulo',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Modulo en construccion.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
