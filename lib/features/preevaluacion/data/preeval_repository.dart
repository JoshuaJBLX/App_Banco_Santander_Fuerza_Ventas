import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Resultado de pre-evaluacion (M4 / RF-38).
class ResultadoPreEval {
  final String calificacion; // APTO / REVISAR / NO_PROCEDE
  final String motivo;
  final int puntaje;
  final bool apto;
  final double capacidadPago;
  final double cuota;
  final double ratio;
  final String recomendacion;

  const ResultadoPreEval({
    required this.calificacion,
    required this.motivo,
    required this.puntaje,
    this.apto = false,
    this.capacidadPago = 0,
    this.cuota = 0,
    this.ratio = 0,
    this.recomendacion = '',
  });

  factory ResultadoPreEval.fromJson(Map<String, dynamic> j) =>
      ResultadoPreEval(
        calificacion: j['calificacion'] as String? ?? 'REVISAR',
        motivo: j['motivo'] as String? ?? '',
        puntaje: (j['puntaje'] as num?)?.toInt() ?? 0,
        apto: j['apto'] as bool? ?? false,
        capacidadPago: (j['capacidad_pago'] as num?)?.toDouble() ?? 0,
        cuota: (j['cuota'] as num?)?.toDouble() ?? 0,
        ratio: (j['ratio'] as num?)?.toDouble() ?? 0,
        recomendacion: j['recomendacion'] as String? ?? '',
      );
}

class PreEvalRepository {
  final ApiClient _api;
  PreEvalRepository(this._api);

  Future<ResultadoPreEval> preEvaluar({
    required String documento,
    required String nombres,
    String apellidos = '',
    String? fechaNacimiento, // YYYY-MM-DD
    required String tipoNegocio,
    int antiguedadNegocioMeses = 0,
    required double ingresos,
    required double montoSolicitado,
    required String destino,
  }) async {
    final data = await _api.post('/pre-evaluar', {
      'numero_documento': documento,
      'nombres': nombres,
      'apellidos': apellidos,
      'fecha_nacimiento': fechaNacimiento,
      'tipo_negocio': tipoNegocio,
      'antiguedad_negocio_meses': antiguedadNegocioMeses,
      'ingresos_estimados': ingresos,
      'monto_solicitado': montoSolicitado,
      'destino_credito': destino,
    });
    return ResultadoPreEval.fromJson(data as Map<String, dynamic>);
  }
}

final preEvalRepositoryProvider = Provider<PreEvalRepository>((ref) {
  return PreEvalRepository(ref.watch(apiClientProvider));
});
