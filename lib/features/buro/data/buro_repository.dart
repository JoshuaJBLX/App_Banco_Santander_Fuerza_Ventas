import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Resultado de consulta de buro (M7 / RF-58/60).
class ResultadoBuro {
  final String calificacionSbs;
  final int entidadesConDeuda;
  final double deudaTotal;
  final double mayorDeuda;
  final int diasMayorMora;
  final bool enListaNegra;
  final String? motivoBloqueo;
  final String interpretacion;

  const ResultadoBuro({
    required this.calificacionSbs,
    required this.entidadesConDeuda,
    required this.deudaTotal,
    required this.mayorDeuda,
    required this.diasMayorMora,
    required this.enListaNegra,
    this.motivoBloqueo,
    required this.interpretacion,
  });

  factory ResultadoBuro.fromJson(Map<String, dynamic> j) => ResultadoBuro(
        calificacionSbs: j['calificacion_sbs'] as String? ?? 'NORMAL',
        entidadesConDeuda: (j['entidades_con_deuda'] as num?)?.toInt() ?? 0,
        deudaTotal: (j['deuda_total'] as num?)?.toDouble() ?? 0,
        mayorDeuda: (j['mayor_deuda'] as num?)?.toDouble() ?? 0,
        diasMayorMora: (j['dias_mayor_mora'] as num?)?.toInt() ?? 0,
        enListaNegra: j['en_lista_negra'] as bool? ?? false,
        motivoBloqueo: j['motivo_bloqueo'] as String?,
        interpretacion: j['interpretacion'] as String? ?? '',
      );
}

class BuroRepository {
  final ApiClient _api;
  BuroRepository(this._api);

  Future<ResultadoBuro> consultar(String dni, {String? clienteId}) async {
    final data = await _api.post('/buro/consulta', {
      'dni': dni,
      'cliente_id': clienteId,
    });
    return ResultadoBuro.fromJson(data as Map<String, dynamic>);
  }
}

final buroRepositoryProvider = Provider<BuroRepository>((ref) {
  return BuroRepository(ref.watch(apiClientProvider));
});
