import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ficha_repository.dart';
import '../domain/ficha_model.dart';

enum FichaStatus { loading, ready, error }

class FichaState {
  final FichaStatus status;
  final FichaCliente? ficha;
  final String? error;

  const FichaState({this.status = FichaStatus.loading, this.ficha, this.error});

  FichaState copyWith(
          {FichaStatus? status, FichaCliente? ficha, String? error}) =>
      FichaState(
        status: status ?? this.status,
        ficha: ficha ?? this.ficha,
        error: error ?? this.error,
      );
}

class FichaViewModel extends StateNotifier<FichaState> {
  final FichaRepository _repo;
  FichaViewModel(this._repo) : super(const FichaState());

  Future<void> cargar(String clienteId) async {
    state = const FichaState(status: FichaStatus.loading);
    try {
      final ficha = await _repo.obtenerFicha(clienteId);
      state = FichaState(status: FichaStatus.ready, ficha: ficha);
    } catch (e) {
      state = FichaState(
          status: FichaStatus.error, error: 'No se pudo cargar la ficha.');
    }
  }
}

/// Family por clienteId: cada cliente tiene su propio estado de ficha.
final fichaViewModelProvider = StateNotifierProvider.family<FichaViewModel,
    FichaState, String>((ref, clienteId) {
  final vm = FichaViewModel(ref.watch(fichaRepositoryProvider));
  vm.cargar(clienteId);
  return vm;
});
