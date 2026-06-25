import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/mora_model.dart';

/// Repositorio de cobranza (M10): mora diaria y registro de gestiones.
class CobranzaRepository {
  final ApiClient _api;
  CobranzaRepository(this._api);

  Future<List<MoraItem>> obtenerMora() async {
    final data = await _api.get('/cobranza/mora');
    return (data as List)
        .map((e) => MoraItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> registrarAccion({
    required String clienteId,
    String? codCuentaCredito,
    required String tipoGestion,
    required String resultado,
    double? montoPagado,
    String? fechaCompromiso,
    double? montoCompromiso,
    String observaciones = '',
    double? lat,
    double? lng,
  }) async {
    await _api.post('/cobranza/accion', {
      'cliente_id': clienteId,
      'cod_cuenta_credito': codCuentaCredito,
      'tipo_gestion': tipoGestion,
      'resultado': resultado,
      'monto_pagado': montoPagado,
      'fecha_compromiso': fechaCompromiso,
      'monto_compromiso': montoCompromiso,
      'observaciones': observaciones,
      'lat': lat,
      'lng': lng,
    });
  }
}

final cobranzaRepositoryProvider = Provider<CobranzaRepository>((ref) {
  return CobranzaRepository(ref.watch(apiClientProvider));
});
