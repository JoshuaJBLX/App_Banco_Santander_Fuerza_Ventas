import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../../../core/network/api_client.dart';
import '../domain/cartera_model.dart';

/// Fuente remota de la cartera desde el backend FastAPI (GET /cartera).
class CarteraRemoteDataSource {
  final ApiClient _api;
  CarteraRemoteDataSource(this._api);

  Future<List<CarteraItem>> obtenerCartera({
    required String asesorId, // el backend ya filtra por el token; se mantiene por firma
    required DateTime fecha,
  }) async {
    final fechaStr = _fechaLocal(fecha);
    if (kDebugMode) debugPrint('FECHA: $fechaStr');
    final data = await _api.get('/cartera?fecha=$fechaStr');
    if (data is! List) {
      throw FormatException('Respuesta inesperada de /cartera: $data');
    }
    return data
        .map((e) => CarteraItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fecha local YYYY-MM-DD (evita desfase por conversion a UTC).
  static String _fechaLocal(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> registrarVisita({
    required String carteraId,
    required String resultado,
    required String observacion,
    double? lat,
    double? lng,
  }) async {
    await _api.post('/cartera/$carteraId/visita', {
      'resultado': resultado,
      'observacion': observacion,
      'lat': lat,
      'lng': lng,
    });
  }
}
