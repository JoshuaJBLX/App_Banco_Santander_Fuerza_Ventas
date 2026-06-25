// Modelos de dominio del modulo Solicitud (M5).

/// Resultado de crear una solicitud (numero de expediente).
class SolicitudCreada {
  final String id;
  final String numeroExpediente;
  final String estado;
  const SolicitudCreada(this.id, this.numeroExpediente, this.estado);

  factory SolicitudCreada.fromJson(Map<String, dynamic> j) => SolicitudCreada(
        j['id'] as String? ?? '',
        j['numero_expediente'] as String? ?? '',
        j['estado'] as String? ?? 'enviado',
      );
}

/// Resumen de una solicitud para historial y tablero de estado (HU-20 / M9).
class SolicitudResumen {
  final String id;
  final String numeroExpediente;
  final String clienteNombre;
  final double montoSolicitado;
  final double montoAprobado;
  final String estado;
  final String? createdAt;

  const SolicitudResumen({
    required this.id,
    required this.numeroExpediente,
    required this.clienteNombre,
    required this.montoSolicitado,
    required this.montoAprobado,
    required this.estado,
    this.createdAt,
  });

  factory SolicitudResumen.fromJson(Map<String, dynamic> j) => SolicitudResumen(
        id: j['id'] as String? ?? '',
        numeroExpediente: j['numero_expediente'] as String? ?? '',
        clienteNombre: j['cliente_nombre'] as String? ?? '',
        montoSolicitado: (j['monto_solicitado'] as num?)?.toDouble() ?? 0,
        montoAprobado: (j['monto_aprobado'] as num?)?.toDouble() ?? 0,
        estado: j['estado'] as String? ?? 'enviado',
        createdAt: j['created_at'] as String?,
      );
}
