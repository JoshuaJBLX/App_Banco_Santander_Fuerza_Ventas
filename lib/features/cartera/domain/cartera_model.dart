/// Item de la cartera diaria (tabla `cartera_diaria`).
/// Modelo puro con (de)serializacion para Supabase y SQLite.
class CarteraItem {
  final String id;
  final String asesorId;
  final String clienteId;
  final String clienteNombre;
  final String documento;
  final String tipoGestion; // RENOVACION / AMPLIACION / ...
  final String prioridad; // alta / media / normal
  final int scorePrioridad; // 0-100
  final double montoCredito;
  final String estadoVisita; // pendiente / visitado / ...
  final int ordenManual;
  final String fechaAsignacion;
  final double? lat; // solo en memoria (no se cachea)
  final double? lng;

  const CarteraItem({
    required this.id,
    required this.asesorId,
    required this.clienteId,
    required this.clienteNombre,
    required this.documento,
    required this.tipoGestion,
    required this.prioridad,
    required this.scorePrioridad,
    required this.montoCredito,
    required this.estadoVisita,
    required this.ordenManual,
    required this.fechaAsignacion,
    this.lat,
    this.lng,
  });

  bool get tieneUbicacion => lat != null && lng != null;

  bool get visitado => estadoVisita == 'visitado';

  CarteraItem copyWith({String? estadoVisita, int? ordenManual}) {
    return CarteraItem(
      id: id,
      asesorId: asesorId,
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      documento: documento,
      tipoGestion: tipoGestion,
      prioridad: prioridad,
      scorePrioridad: scorePrioridad,
      montoCredito: montoCredito,
      estadoVisita: estadoVisita ?? this.estadoVisita,
      ordenManual: ordenManual ?? this.ordenManual,
      fechaAsignacion: fechaAsignacion,
      lat: lat,
      lng: lng,
    );
  }

  static String _str(dynamic v) => v?.toString() ?? '';

  /// Desde backend FastAPI (join cliente para nombre/documento).
  factory CarteraItem.fromJson(Map<String, dynamic> json) {
    final cliente = (json['clientes'] as Map<String, dynamic>?) ?? const {};
    final nombreJoin =
        '${cliente['nombres'] ?? ''} ${cliente['apellidos'] ?? ''}'.trim();
    final nombre = nombreJoin.isNotEmpty
        ? nombreJoin
        : _str(json['cliente_nombre']);
    final docJoin = _str(cliente['numero_documento']);
    return CarteraItem(
      id: _str(json['id']),
      asesorId: _str(json['asesor_id']),
      clienteId: _str(json['cliente_id']),
      clienteNombre: nombre,
      documento: docJoin.isNotEmpty ? docJoin : _str(json['documento']),
      tipoGestion: json['tipo_gestion'] as String? ?? 'SEGUIMIENTO',
      prioridad: json['prioridad'] as String? ?? 'normal',
      scorePrioridad: (json['score_prioridad'] as num?)?.toInt() ?? 0,
      montoCredito: (json['monto_credito'] as num?)?.toDouble() ?? 0,
      estadoVisita: json['estado_visita'] as String? ?? 'pendiente',
      ordenManual: (json['orden_manual'] as num?)?.toInt() ?? 0,
      fechaAsignacion: json['fecha_asignacion']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  /// Hacia/desde SQLite (cache local).
  Map<String, Object?> toMap() => {
        'id': id,
        'asesor_id': asesorId,
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'documento': documento,
        'tipo_gestion': tipoGestion,
        'prioridad': prioridad,
        'score_prioridad': scorePrioridad,
        'monto_credito': montoCredito,
        'estado_visita': estadoVisita,
        'orden_manual': ordenManual,
        'fecha_asignacion': fechaAsignacion,
      };

  factory CarteraItem.fromMap(Map<String, Object?> m) => CarteraItem(
        id: m['id'] as String? ?? '',
        asesorId: m['asesor_id'] as String? ?? '',
        clienteId: m['cliente_id'] as String? ?? '',
        clienteNombre: m['cliente_nombre'] as String? ?? '',
        documento: m['documento'] as String? ?? '',
        tipoGestion: m['tipo_gestion'] as String? ?? 'SEGUIMIENTO',
        prioridad: m['prioridad'] as String? ?? 'normal',
        scorePrioridad: (m['score_prioridad'] as num?)?.toInt() ?? 0,
        montoCredito: (m['monto_credito'] as num?)?.toDouble() ?? 0,
        estadoVisita: m['estado_visita'] as String? ?? 'pendiente',
        ordenManual: (m['orden_manual'] as num?)?.toInt() ?? 0,
        fechaAsignacion: m['fecha_asignacion'] as String? ?? '',
      );
}
