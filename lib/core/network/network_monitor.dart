import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monitor de conectividad. Expone el estado de red como stream para que
/// el Repositorio decida entre fuente remota (Supabase) y cache local
/// (SQLite), y para disparar la sincronizacion al reconectar (RF-18).
class NetworkMonitor {
  final Connectivity _connectivity;
  NetworkMonitor([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  /// `true` si hay al menos una interfaz de red disponible.
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  /// Emite `true`/`false` cada vez que cambia la conectividad.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}

/// Provider del monitor (singleton).
final networkMonitorProvider = Provider<NetworkMonitor>((ref) {
  return NetworkMonitor();
});

/// Estado de conexion observable por la UI (p. ej. banner "Modo offline").
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  return ref.watch(networkMonitorProvider).onStatusChange;
});
