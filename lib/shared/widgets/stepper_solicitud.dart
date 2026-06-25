import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Indicador de progreso de los 4 pasos de la solicitud (RF-43).
///
/// SCAFFOLD: se integrara en M5. Ya funcional como indicador visual de pasos.
class StepperSolicitud extends StatelessWidget {
  final int pasoActual; // 1..4
  final List<String> titulos;
  const StepperSolicitud({
    super.key,
    required this.pasoActual,
    this.titulos = const ['Solicitante', 'Negocio', 'Condiciones', 'Firma'],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(titulos.length, (i) {
        final paso = i + 1;
        final completado = paso < pasoActual;
        final activo = paso == pasoActual;
        final color = completado || activo
            ? AppColors.primary
            : AppColors.neutral.withValues(alpha: 0.4);
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color,
                child: completado
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('$paso',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(height: 4),
              Text(titulos[i],
                  style: TextStyle(fontSize: 10, color: color),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      }),
    );
  }
}
