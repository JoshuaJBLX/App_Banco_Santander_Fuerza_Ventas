import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../utils/formatters.dart';

/// Etiqueta de color para el tipo de gestion de cartera (RF-10).
class BadgeTipoGestion extends StatelessWidget {
  final String tipo;
  const BadgeTipoGestion({super.key, required this.tipo});

  Color get _color {
    switch (tipo) {
      case 'RENOVACION':
        return AppColors.renovacion;
      case 'AMPLIACION':
        return AppColors.ampliacion;
      case 'NUEVA_SOLICITUD':
        return AppColors.nuevaSolicitud;
      case 'SEGUIMIENTO':
        return AppColors.seguimiento;
      case 'RECUPERACION_MORA':
        return AppColors.recuperacionMora;
      case 'DESERTOR':
        return AppColors.desertor;
      default:
        return AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color, width: 1),
      ),
      child: Text(
        Formatters.tipoGestionLabel(tipo).toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
