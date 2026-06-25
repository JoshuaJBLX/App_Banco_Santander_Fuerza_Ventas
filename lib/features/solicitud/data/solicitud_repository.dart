import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/solicitud_model.dart';

/// Repositorio del modulo Solicitud (M5).
class SolicitudRepository {
  final ApiClient _api;
  SolicitudRepository(this._api);

  Future<SolicitudCreada> crear(Map<String, dynamic> datos) async {
    final data = await _api.post('/solicitudes', datos);
    return SolicitudCreada.fromJson(data as Map<String, dynamic>);
  }

  Future<List<SolicitudResumen>> listar() async {
    final data = await _api.get('/solicitudes');
    return (data as List)
        .map((e) => SolicitudResumen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Notas internas de una solicitud (RF-72).
  Future<List<String>> listarNotas(String solicitudId) async {
    final data = await _api.get('/solicitudes/$solicitudId/notas');
    return (data as List)
        .map((e) => (e as Map<String, dynamic>)['contenido'] as String? ?? '')
        .toList();
  }

  Future<void> agregarNota(String solicitudId, String contenido) async {
    await _api.post('/solicitudes/$solicitudId/notas', {'contenido': contenido});
  }
}

final solicitudRepositoryProvider = Provider<SolicitudRepository>((ref) {
  return SolicitudRepository(ref.watch(apiClientProvider));
});
