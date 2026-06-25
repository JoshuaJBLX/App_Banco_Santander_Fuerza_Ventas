import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../data/cartera_repository.dart';
import '../domain/cartera_model.dart';

enum FiltroCartera { todos, renovaciones, nuevas, enMora, visitados }

enum CarteraStatus { idle, loading, ready, error }

/// Estado inmutable de la pantalla de cartera.
class CarteraState {
  final CarteraStatus status;
  final List<CarteraItem> items; // conjunto completo
  final FiltroCartera filtro;
  final String query;
  final bool desdeCache;
  final bool reordenManual; // RF-16: el asesor reordeno manualmente
  final String? error;

  const CarteraState({
    this.status = CarteraStatus.idle,
    this.items = const [],
    this.filtro = FiltroCartera.todos,
    this.query = '',
    this.desdeCache = false,
    this.reordenManual = false,
    this.error,
  });

  /// El reordenamiento manual solo se permite sobre la lista completa
  /// (sin filtro ni busqueda activos), donde visibles == items.
  bool get puedeReordenar =>
      filtro == FiltroCartera.todos && query.trim().isEmpty;

  /// Lista visible tras aplicar filtro (RF-11) y busqueda (RF-12).
  List<CarteraItem> get visibles {
    Iterable<CarteraItem> r = items;
    switch (filtro) {
      case FiltroCartera.renovaciones:
        r = r.where((e) => e.tipoGestion == 'RENOVACION');
        break;
      case FiltroCartera.nuevas:
        r = r.where((e) => e.tipoGestion == 'NUEVA_SOLICITUD');
        break;
      case FiltroCartera.enMora:
        r = r.where((e) => e.tipoGestion == 'RECUPERACION_MORA');
        break;
      case FiltroCartera.visitados:
        r = r.where((e) => e.visitado);
        break;
      case FiltroCartera.todos:
        break;
    }
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      r = r.where((e) =>
          e.clienteNombre.toLowerCase().contains(q) ||
          e.documento.toLowerCase().contains(q));
    }
    // Si el asesor reordeno manualmente (RF-16), se respeta su orden;
    // si no, visitados al fondo (RF-04) y luego por score (RF-06/15).
    final list = r.toList()
      ..sort((a, b) {
        if (reordenManual) return a.ordenManual.compareTo(b.ordenManual);
        if (a.visitado != b.visitado) return a.visitado ? 1 : -1;
        return b.scorePrioridad.compareTo(a.scorePrioridad);
      });
    return list;
  }

  int get total => items.length;
  int get visitados => items.where((e) => e.visitado).length;
  int get pendientes => total - visitados;
  double get progreso => total == 0 ? 0 : visitados / total;

  CarteraState copyWith({
    CarteraStatus? status,
    List<CarteraItem>? items,
    FiltroCartera? filtro,
    String? query,
    bool? desdeCache,
    bool? reordenManual,
    String? error,
    bool limpiarError = false,
  }) {
    return CarteraState(
      status: status ?? this.status,
      items: items ?? this.items,
      filtro: filtro ?? this.filtro,
      query: query ?? this.query,
      desdeCache: desdeCache ?? this.desdeCache,
      reordenManual: reordenManual ?? this.reordenManual,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

/// ViewModel de la cartera diaria (M1).
class CarteraViewModel extends StateNotifier<CarteraState> {
  final CarteraRepository _repo;
  final AuthRepository _auth;
  String? _asesorId;

  CarteraViewModel(this._repo, this._auth) : super(const CarteraState());

  Future<void> cargar(String asesorId) async {
    if (asesorId.isEmpty) {
      debugPrint('[cartera] cargar omitido: asesorId vacio');
      return;
    }
    _asesorId = asesorId;
    state = state.copyWith(status: CarteraStatus.loading, limpiarError: true);
    try {
      await _auth.ensureTokenEnMemoria();
      final res = await _repo.obtenerCartera(
        asesorId: asesorId,
        fecha: DateTime.now(),
      );
      debugPrint('[cartera] UI recibio ${res.items.length} items');
      state = state.copyWith(
        status: CarteraStatus.ready,
        items: res.items,
        desdeCache: res.desdeCache,
      );
    } catch (e) {
      debugPrint('[cartera] error en cargar: $e');
      state = state.copyWith(
        status: CarteraStatus.error,
        error: 'No se pudo cargar la cartera: $e',
      );
    }
  }

  void cambiarFiltro(FiltroCartera filtro) =>
      state = state.copyWith(filtro: filtro);

  void buscar(String query) => state = state.copyWith(query: query);

  Future<void> marcarVisita(
    String carteraId, {
    required String resultado,
    String observacion = '',
    double? lat,
    double? lng,
  }) async {
    await _repo.registrarVisita(
      carteraId: carteraId,
      resultado: resultado,
      observacion: observacion,
      lat: lat,
      lng: lng,
    );
    // Refleja el cambio localmente.
    final actualizados = state.items
        .map((e) =>
            e.id == carteraId ? e.copyWith(estadoVisita: 'visitado') : e)
        .toList();
    state = state.copyWith(items: actualizados);
  }

  /// Reordenamiento manual con arrastrar y soltar (RF-16). Reasigna
  /// orden_manual segun la nueva posicion y lo persiste localmente.
  /// [newIndex] ya viene ajustado por el callback onReorderItem.
  Future<void> reordenar(int oldIndex, int newIndex) async {
    if (!state.puedeReordenar) return;
    final lista = [...state.visibles];
    if (oldIndex < 0 || oldIndex >= lista.length) return;
    final movido = lista.removeAt(oldIndex);
    lista.insert(newIndex.clamp(0, lista.length), movido);
    final reindexado = [
      for (var i = 0; i < lista.length; i++) lista[i].copyWith(ordenManual: i)
    ];
    state = state.copyWith(items: reindexado, reordenManual: true);
    await _repo.guardarOrden(reindexado);
  }

  Future<void> refrescar([String? asesorId]) async {
    final id = (asesorId != null && asesorId.isNotEmpty) ? asesorId : _asesorId;
    if (id != null && id.isNotEmpty) await cargar(id);
  }
}

final carteraViewModelProvider =
    StateNotifierProvider<CarteraViewModel, CarteraState>((ref) {
  return CarteraViewModel(
    ref.watch(carteraRepositoryProvider),
    ref.watch(authRepositoryProvider),
  );
});
