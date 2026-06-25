import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/ficha_model.dart';

/// Repositorio de la ficha del cliente (GET /clientes/{id}/ficha).
class FichaRepository {
  final ApiClient _api;
  FichaRepository(this._api);

  Future<FichaCliente> obtenerFicha(String clienteId) async {
    final data = await _api.get('/clientes/$clienteId/ficha');
    return FichaCliente.fromJson(data as Map<String, dynamic>);
  }

  /// Actualiza las coordenadas del negocio del cliente (HU-10 / RF-25/26).
  /// Best-effort: si el backend aun no expone el endpoint, no rompe el flujo.
  Future<bool> actualizarUbicacion({
    required String clienteId,
    required double lat,
    required double lng,
    String? direccion,
  }) async {
    try {
      await _api.post('/clientes/$clienteId/ubicacion', {
        'lat': lat,
        'lng': lng,
        'direccion': direccion,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

final fichaRepositoryProvider = Provider<FichaRepository>((ref) {
  return FichaRepository(ref.watch(apiClientProvider));
});
