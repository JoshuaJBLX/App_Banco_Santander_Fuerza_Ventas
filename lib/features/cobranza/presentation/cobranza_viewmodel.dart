import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cobranza_repository.dart';
import '../domain/mora_model.dart';

enum CobranzaStatus { loading, ready, error }

class CobranzaState {
  final CobranzaStatus status;
  final List<MoraItem> items;
  final String? error;

  const CobranzaState(
      {this.status = CobranzaStatus.loading,
      this.items = const [],
      this.error});

  double get totalVencido =>
      items.fold(0, (s, e) => s + e.montoVencido);

  CobranzaState copyWith(
          {CobranzaStatus? status, List<MoraItem>? items, String? error}) =>
      CobranzaState(
        status: status ?? this.status,
        items: items ?? this.items,
        error: error ?? this.error,
      );
}

class CobranzaViewModel extends StateNotifier<CobranzaState> {
  final CobranzaRepository _repo;
  CobranzaViewModel(this._repo) : super(const CobranzaState()) {
    cargar();
  }

  Future<void> cargar() async {
    state = state.copyWith(status: CobranzaStatus.loading);
    try {
      final items = await _repo.obtenerMora();
      state = state.copyWith(status: CobranzaStatus.ready, items: items);
    } catch (_) {
      state = state.copyWith(
          status: CobranzaStatus.error, error: 'No se pudo cargar la mora.');
    }
  }

  Future<void> registrarAccion({
    required String clienteId,
    String? codCuentaCredito,
    required String tipoGestion,
    required String resultado,
    double? montoCompromiso,
    String? fechaCompromiso,
    String observaciones = '',
    double? lat,
    double? lng,
  }) async {
    await _repo.registrarAccion(
      clienteId: clienteId,
      codCuentaCredito: codCuentaCredito,
      tipoGestion: tipoGestion,
      resultado: resultado,
      montoCompromiso: montoCompromiso,
      fechaCompromiso: fechaCompromiso,
      observaciones: observaciones,
      lat: lat,
      lng: lng,
    );
    await cargar();
  }
}

final cobranzaViewModelProvider =
    StateNotifierProvider<CobranzaViewModel, CobranzaState>((ref) {
  return CobranzaViewModel(ref.watch(cobranzaRepositoryProvider));
});
