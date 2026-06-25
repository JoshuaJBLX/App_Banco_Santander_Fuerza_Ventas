import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Estado de un documento en el checklist de captura (RF-21).
enum EstadoDocumento { listo, pendiente, obligatorio }

/// Listado visual del estado de documentos de una solicitud (RF-21).
///
/// SCAFFOLD: se integrara en M6 (captura de documentos).
class DocumentoChecklist extends StatelessWidget {
  final Map<String, EstadoDocumento> documentos;
  const DocumentoChecklist({super.key, required this.documentos});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: documentos.entries.map((e) {
        final (icon, color, label) = switch (e.value) {
          EstadoDocumento.listo => (
              Icons.check_circle,
              AppColors.success,
              'LISTO'
            ),
          EstadoDocumento.pendiente => (
              Icons.schedule,
              AppColors.warning,
              'PENDIENTE'
            ),
          EstadoDocumento.obligatorio => (
              Icons.error,
              AppColors.danger,
              'OBLIGATORIO'
            ),
        };
        return ListTile(
          dense: true,
          leading: Icon(icon, color: color),
          title: Text(e.key),
          trailing: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        );
      }).toList(),
    );
  }
}
