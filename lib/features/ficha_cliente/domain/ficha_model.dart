// Modelos de dominio de la Ficha del Cliente (M3 / HU-11).

class PosicionCliente {
  final double deudaTotal;
  final int cuentasVigentes;
  final int cuentasMora;
  final int diasMayorMora;

  const PosicionCliente({
    required this.deudaTotal,
    required this.cuentasVigentes,
    required this.cuentasMora,
    required this.diasMayorMora,
  });

  factory PosicionCliente.fromJson(Map<String, dynamic> j) => PosicionCliente(
        deudaTotal: (j['deuda_total'] as num?)?.toDouble() ?? 0,
        cuentasVigentes: (j['cuentas_vigentes'] as num?)?.toInt() ?? 0,
        cuentasMora: (j['cuentas_mora'] as num?)?.toInt() ?? 0,
        diasMayorMora: (j['dias_mayor_mora'] as num?)?.toInt() ?? 0,
      );
}

class CreditoHistorial {
  final String producto;
  final double montoDesembolsado;
  final int plazoMeses;
  final double tea;
  final String estado;
  final int diasMora;
  final int cuotasTotal;
  final int cuotasPagadas;

  const CreditoHistorial({
    required this.producto,
    required this.montoDesembolsado,
    required this.plazoMeses,
    required this.tea,
    required this.estado,
    required this.diasMora,
    required this.cuotasTotal,
    required this.cuotasPagadas,
  });

  factory CreditoHistorial.fromJson(Map<String, dynamic> j) => CreditoHistorial(
        producto: j['producto'] as String? ?? '',
        montoDesembolsado: (j['monto_desembolsado'] as num?)?.toDouble() ?? 0,
        plazoMeses: (j['plazo_meses'] as num?)?.toInt() ?? 0,
        tea: (j['tea'] as num?)?.toDouble() ?? 0,
        estado: j['estado'] as String? ?? '',
        diasMora: (j['dias_mora'] as num?)?.toInt() ?? 0,
        cuotasTotal: (j['cuotas_total'] as num?)?.toInt() ?? 0,
        cuotasPagadas: (j['cuotas_pagadas'] as num?)?.toInt() ?? 0,
      );
}

class OfertaPreaprobada {
  final double montoMaximo;
  final int plazoSugeridoMeses;
  final double teaReferencial;
  final int scoreConfianza;
  final String? fechaVencimiento;

  const OfertaPreaprobada({
    required this.montoMaximo,
    required this.plazoSugeridoMeses,
    required this.teaReferencial,
    required this.scoreConfianza,
    this.fechaVencimiento,
  });

  factory OfertaPreaprobada.fromJson(Map<String, dynamic> j) => OfertaPreaprobada(
        montoMaximo: (j['monto_maximo'] as num?)?.toDouble() ?? 0,
        plazoSugeridoMeses: (j['plazo_sugerido_meses'] as num?)?.toInt() ?? 0,
        teaReferencial: (j['tea_referencial'] as num?)?.toDouble() ?? 0,
        scoreConfianza: (j['score_confianza'] as num?)?.toInt() ?? 0,
        fechaVencimiento: j['fecha_vencimiento'] as String?,
      );
}

/// Indicadores de comportamiento de pago (RF-32).
class IndicadoresComportamiento {
  final double pctPuntual;
  final int diasPromMora;
  final double montoPagado;
  const IndicadoresComportamiento(
      this.pctPuntual, this.diasPromMora, this.montoPagado);

  factory IndicadoresComportamiento.fromJson(Map<String, dynamic> j) =>
      IndicadoresComportamiento(
        (j['pct_puntual'] as num?)?.toDouble() ?? 0,
        (j['dias_prom_mora'] as num?)?.toInt() ?? 0,
        (j['monto_pagado'] as num?)?.toDouble() ?? 0,
      );
}

class FichaCliente {
  final String id;
  final String numeroDocumento;
  final String nombres;
  final String apellidos;
  final String? telefono;
  final String? direccion;
  final String? tipoNegocio;
  final String? nombreNegocio;
  final int? antiguedadNegocioMeses;
  final String calificacionSbs;
  final PosicionCliente posicion;
  final List<CreditoHistorial> historial;
  final OfertaPreaprobada? oferta;
  final List<int> comportamiento; // 12 meses: 0=sin, 1=puntual, 2=mora
  final IndicadoresComportamiento? indicadores;

  const FichaCliente({
    required this.id,
    required this.numeroDocumento,
    required this.nombres,
    required this.apellidos,
    this.telefono,
    this.direccion,
    this.tipoNegocio,
    this.nombreNegocio,
    this.antiguedadNegocioMeses,
    required this.calificacionSbs,
    required this.posicion,
    required this.historial,
    this.oferta,
    this.comportamiento = const [],
    this.indicadores,
  });

  String get nombreCompleto => '$nombres $apellidos';

  factory FichaCliente.fromJson(Map<String, dynamic> j) {
    final c = j['cliente'] as Map<String, dynamic>;
    return FichaCliente(
      id: c['id'] as String? ?? '',
      numeroDocumento: c['numero_documento'] as String? ?? '',
      nombres: c['nombres'] as String? ?? '',
      apellidos: c['apellidos'] as String? ?? '',
      telefono: c['telefono'] as String?,
      direccion: c['direccion'] as String?,
      tipoNegocio: c['tipo_negocio'] as String?,
      nombreNegocio: c['nombre_negocio'] as String?,
      antiguedadNegocioMeses: (c['antiguedad_negocio_meses'] as num?)?.toInt(),
      calificacionSbs: c['calificacion_sbs'] as String? ?? 'NORMAL',
      posicion:
          PosicionCliente.fromJson(j['posicion'] as Map<String, dynamic>),
      historial: ((j['historial'] as List?) ?? [])
          .map((e) => CreditoHistorial.fromJson(e as Map<String, dynamic>))
          .toList(),
      oferta: j['oferta'] == null
          ? null
          : OfertaPreaprobada.fromJson(j['oferta'] as Map<String, dynamic>),
      comportamiento:
          ((j['comportamiento'] as List?) ?? []).map((e) => e as int).toList(),
      indicadores: j['indicadores'] == null
          ? null
          : IndicadoresComportamiento.fromJson(
              j['indicadores'] as Map<String, dynamic>),
    );
  }
}
