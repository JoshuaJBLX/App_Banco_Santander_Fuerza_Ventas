import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../utils/formatters.dart';
import 'badge_tipo_gestion.dart';

/// Tarjeta de cliente en la lista de cartera (RF-04).
/// Decoplada del modelo: recibe campos primitivos para poder reutilizarse.
class ClienteCard extends StatelessWidget {
  final String nombre;
  final String documentoCensurado;
  final String tipoGestion;
  final double montoCredito;
  final String prioridad; // alta / media / normal
  final bool visitado;
  final VoidCallback? onTap;

  const ClienteCard({
    super.key,
    required this.nombre,
    required this.documentoCensurado,
    required this.tipoGestion,
    required this.montoCredito,
    required this.prioridad,
    this.visitado = false,
    this.onTap,
  });

  Color get _colorPrioridad {
    switch (prioridad.toLowerCase()) {
      case 'alta':
        return AppColors.prioridadAlta;
      case 'media':
        return AppColors.prioridadMedia;
      default:
        return AppColors.prioridadNormal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: visitado ? AppColors.visitedTile : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Franja de prioridad
              Container(
                width: 5,
                height: 48,
                decoration: BoxDecoration(
                  color: _colorPrioridad,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              decoration: visitado
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (visitado)
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Doc. $documentoCensurado',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        BadgeTipoGestion(tipo: tipoGestion),
                        const Spacer(),
                        Text(
                          Formatters.soles(montoCredito),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
