import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_monitor.dart';
import '../../../core/sync/sync_nocturna.dart';
import '../domain/cartera_model.dart';
import 'cartera_local_datasource.dart';
import 'cartera_remote_datasource.dart';

/// Resultado de cartera con bandera de origen (para banner "Modo offline").
class ResultadoCartera {
  final List<CarteraItem> items;
  final bool desdeCache;
  const ResultadoCartera(this.items, {this.desdeCache = false});
}

/// Repositorio offline-first de la cartera:
///  - Con red: consulta el backend, guarda en cache SQLite y devuelve.
///  - Sin red o ante error: lee del cache local.
class CarteraRepository {
  final CarteraRemoteDataSource _remote;
  final CarteraLocalDataSource _local;
  final NetworkMonitor _network;

  CarteraRepository(this._remote, this._local, this._network);

  /// Sincroniza la cola de visitas pendientes al reconectar (RF-18).
  /// Devuelve cuantas se sincronizaron.
  Future<int> sincronizarPendientes() async {
    if (!await _network.isOnline) return 0;
    final pendientes = await _local.visitasPendientes();
    var ok = 0;
    for (final v in pendientes) {
      try {
        await _remote.registrarVisita(
          carteraId: v['cartera_id'] as String,
          resultado: v['resultado'] as String? ?? 'visitado',
          observacion: v['observacion'] as String? ?? '',
          lat: (v['lat'] as num?)?.toDouble(),
          lng: (v['lng'] as num?)?.toDouble(),
        );
        await _local.eliminarPendiente(v['id'] as String);
        ok++;
      } catch (_) {
        // se reintentara en el siguiente ciclo
      }
    }
    return ok;
  }

  /// Persiste el orden manual de la cartera en el cache local (RF-16).
  Future<void> guardarOrden(List<CarteraItem> items) async {
    try {
      await _local.actualizarOrden(items);
    } catch (_) {/* el orden es local; si falla no rompe la UI */}
  }

  Future<ResultadoCartera> obtenerCartera({
    required String asesorId,
    required DateTime fecha,
  }) async {
    if (!kIsWeb) {
      try {
        await sincronizarPendientes();
      } catch (e) {
        debugPrint('[cartera] sync pendientes omitido: $e');
      }
    }

    try {
      final items =
          await _remote.obtenerCartera(asesorId: asesorId, fecha: fecha);
      debugPrint('[cartera] remoto OK: ${items.length} items');
      _persistirCacheEnBackground(asesorId, items);
      return ResultadoCartera(items);
    } catch (e, st) {
      debugPrint('[cartera] remoto fallo: $e\n$st');
      if (!kIsWeb) {
        try {
          final cache = await _local.leerCache(asesorId);
          if (cache.isNotEmpty) {
            debugPrint('[cartera] usando cache: ${cache.length} items');
            return ResultadoCartera(cache, desdeCache: true);
          }
        } catch (cacheErr) {
          debugPrint('[cartera] cache no disponible: $cacheErr');
        }
      }
      rethrow;
    }
  }

  /// Cache SQLite en background: no bloquea la UI si la BD tarda o falla.
  void _persistirCacheEnBackground(String asesorId, List<CarteraItem> items) {
    if (kIsWeb) return;
    Future(() async {
      try {
        await _local.guardarCache(asesorId, items);
        await SyncNocturna.guardarUltimaSync();
      } catch (e) {
        debugPrint('[cartera] cache no guardada: $e');
      }
    });
  }

  /// Marca visita: intenta remoto; si falla, refleja en cache y encola (RF-17/18).
  Future<void> registrarVisita({
    required String carteraId,
    required String resultado,
    required String observacion,
    double? lat,
    double? lng,
  }) async {
    try {
      await _local.actualizarEstadoVisita(carteraId, 'visitado');
    } catch (_) {}
    if (await _network.isOnline) {
      try {
        await _remote.registrarVisita(
          carteraId: carteraId,
          resultado: resultado,
          observacion: observacion,
          lat: lat,
          lng: lng,
        );
        return;
      } catch (_) {/* cae a cola offline */}
    }
    try {
      await _local.encolarVisita(
        carteraId: carteraId,
        resultado: resultado,
        observacion: observacion,
        lat: lat,
        lng: lng,
      );
    } catch (_) {}
  }
}

final carteraRepositoryProvider = Provider<CarteraRepository>((ref) {
  return CarteraRepository(
    CarteraRemoteDataSource(ref.watch(apiClientProvider)),
    CarteraLocalDataSource(),
    ref.watch(networkMonitorProvider),
  );
});
