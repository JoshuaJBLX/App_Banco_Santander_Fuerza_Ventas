import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preeval_repository.dart';

class PreEvalState {
  final bool cargando;
  final ResultadoPreEval? resultado;
  final String? error;
  const PreEvalState({this.cargando = false, this.resultado, this.error});
}

class PreEvalViewModel extends StateNotifier<PreEvalState> {
  final PreEvalRepository _repo;
  PreEvalViewModel(this._repo) : super(const PreEvalState());

  Future<void> evaluar({
    required String documento,
    required String nombres,
    String apellidos = '',
    String? fechaNacimiento,
    required String tipoNegocio,
    int antiguedadNegocioMeses = 0,
    required double ingresos,
    required double montoSolicitado,
    required String destino,
  }) async {
    state = const PreEvalState(cargando: true);
    try {
      final r = await _repo.preEvaluar(
        documento: documento,
        nombres: nombres,
        apellidos: apellidos,
        fechaNacimiento: fechaNacimiento,
        tipoNegocio: tipoNegocio,
        antiguedadNegocioMeses: antiguedadNegocioMeses,
        ingresos: ingresos,
        montoSolicitado: montoSolicitado,
        destino: destino,
      );
      state = PreEvalState(resultado: r);
    } catch (e) {
      state = PreEvalState(error: e.toString());
    }
  }
}

final preEvalViewModelProvider =
    StateNotifierProvider<PreEvalViewModel, PreEvalState>((ref) {
  return PreEvalViewModel(ref.watch(preEvalRepositoryProvider));
});
