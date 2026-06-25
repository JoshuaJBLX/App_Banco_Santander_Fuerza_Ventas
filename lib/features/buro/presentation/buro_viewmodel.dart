import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/buro_repository.dart';

class BuroState {
  final bool cargando;
  final ResultadoBuro? resultado;
  final String? error;
  const BuroState({this.cargando = false, this.resultado, this.error});
}

class BuroViewModel extends StateNotifier<BuroState> {
  final BuroRepository _repo;
  BuroViewModel(this._repo) : super(const BuroState());

  Future<void> consultar(String dni) async {
    state = const BuroState(cargando: true);
    try {
      final r = await _repo.consultar(dni);
      state = BuroState(resultado: r);
    } catch (_) {
      state = const BuroState(error: 'No se pudo consultar el buro.');
    }
  }
}

final buroViewModelProvider =
    StateNotifierProvider<BuroViewModel, BuroState>((ref) {
  return BuroViewModel(ref.watch(buroRepositoryProvider));
});
