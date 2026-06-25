import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Alerta de cartera (HU-14).
class AlertaItem {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String tipoAlerta;
  final String? mensaje;
  final bool leida;

  const AlertaItem({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.tipoAlerta,
    this.mensaje,
    required this.leida,
  });

  factory AlertaItem.fromJson(Map<String, dynamic> j) => AlertaItem(
        id: j['id'] as String? ?? '',
        clienteId: j['cliente_id'] as String? ?? '',
        clienteNombre: j['cliente_nombre'] as String? ?? '',
        tipoAlerta: j['tipo_alerta'] as String? ?? '',
        mensaje: j['mensaje'] as String?,
        leida: j['leida'] as bool? ?? false,
      );
}

class AlertasRepository {
  final ApiClient _api;
  AlertasRepository(this._api);

  Future<List<AlertaItem>> listar() async {
    final data = await _api.get('/alertas');
    return (data as List)
        .map((e) => AlertaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> noLeidas() async {
    final data = await _api.get('/alertas/no-leidas');
    return (data['no_leidas'] as num?)?.toInt() ?? 0;
  }

  Future<void> marcarLeida(String id) async {
    await _api.post('/alertas/$id/leer', {});
  }
}

final alertasRepositoryProvider =
    Provider<AlertasRepository>((ref) => AlertasRepository(ref.watch(apiClientProvider)));

final alertasProvider =
    FutureProvider.autoDispose<List<AlertaItem>>((ref) {
  return ref.watch(alertasRepositoryProvider).listar();
});

/// Conteo de no leidas para la insignia del menu (RF-36).
final alertasNoLeidasProvider = FutureProvider<int>((ref) {
  return ref.watch(alertasRepositoryProvider).noLeidas();
});
