import 'dart:convert';

/// Borrador de solicitud guardado localmente (HU-18 / RF-49).
class BorradorSolicitud {
  final String id;
  final String clienteNombre;
  final int pasoActual;
  final Map<String, dynamic> datos;
  final double montoSolicitado;
  final int updatedAt; // epoch ms

  const BorradorSolicitud({
    required this.id,
    required this.clienteNombre,
    required this.pasoActual,
    required this.datos,
    required this.montoSolicitado,
    required this.updatedAt,
  });

  factory BorradorSolicitud.fromMap(Map<String, Object?> m) => BorradorSolicitud(
        id: m['id'] as String? ?? '',
        clienteNombre: m['cliente_nombre'] as String? ?? 'Sin nombre',
        pasoActual: (m['paso_actual'] as num?)?.toInt() ?? 1,
        datos: m['datos_json'] == null
            ? <String, dynamic>{}
            : jsonDecode(m['datos_json'] as String) as Map<String, dynamic>,
        montoSolicitado: (m['monto_solicitado'] as num?)?.toDouble() ?? 0,
        updatedAt: (m['updated_at'] as num?)?.toInt() ?? 0,
      );
}
