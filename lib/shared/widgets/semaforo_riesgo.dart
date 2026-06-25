import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Semaforo de riesgo crediticio segun calificacion SBS (RF-28).
/// Reutilizado en la ficha del cliente y en el resultado de buro.
class SemaforoRiesgo extends StatelessWidget {
  final String calificacionSbs;
  const SemaforoRiesgo({super.key, required this.calificacionSbs});

  _Sbs get _data {
    switch (calificacionSbs.toUpperCase()) {
      case 'NORMAL':
        return const _Sbs(AppColors.success, 'Normal', 'Sin observaciones');
      case 'CPP':
        return const _Sbs(AppColors.warning, 'CPP', 'Requiere atencion');
      case 'DEFICIENTE':
        return const _Sbs(
            AppColors.accent, 'Deficiente', 'Requiere comite especial');
      case 'DUDOSO':
        return const _Sbs(AppColors.danger, 'Dudoso', 'Alto riesgo');
      case 'PERDIDA':
        return const _Sbs(
            AppColors.primaryDark, 'Perdida', 'No procede evaluacion');
      default:
        return _Sbs(AppColors.neutral, calificacionSbs, 'Sin dato');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(d.label,
                style: TextStyle(
                    color: d.color, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(d.descripcion,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _Sbs {
  final Color color;
  final String label;
  final String descripcion;
  const _Sbs(this.color, this.label, this.descripcion);
}
