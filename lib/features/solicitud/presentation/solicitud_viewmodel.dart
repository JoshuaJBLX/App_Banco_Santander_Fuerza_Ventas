import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/login_viewmodel.dart';
import '../data/solicitud_local_datasource.dart';
import '../data/solicitud_repository.dart';
import '../domain/borrador_model.dart';
import '../domain/solicitud_model.dart';

class SolicitudState {
  final bool enviando;
  final SolicitudCreada? creada;
  final String? error;
  const SolicitudState({this.enviando = false, this.creada, this.error});
}

class SolicitudViewModel extends StateNotifier<SolicitudState> {
  final SolicitudRepository _repo;
  SolicitudViewModel(this._repo) : super(const SolicitudState());

  Future<void> enviar(Map<String, dynamic> datos) async {
    state = const SolicitudState(enviando: true);
    try {
      final creada = await _repo.crear(datos);
      state = SolicitudState(creada: creada);
    } catch (_) {
      state = const SolicitudState(error: 'No se pudo enviar la solicitud.');
    }
  }
}

final solicitudViewModelProvider =
    StateNotifierProvider<SolicitudViewModel, SolicitudState>((ref) {
  return SolicitudViewModel(ref.watch(solicitudRepositoryProvider));
});

/// Historial de solicitudes del mes (HU-20).
final solicitudesHistorialProvider =
    FutureProvider<List<SolicitudResumen>>((ref) {
  return ref.watch(solicitudRepositoryProvider).listar();
});

/// Notas internas de una solicitud (RF-72), por id de solicitud.
final notasProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, id) {
  return ref.watch(solicitudRepositoryProvider).listarNotas(id);
});

/// Fuente local de borradores (HU-18).
final solicitudLocalProvider =
    Provider<SolicitudLocalDataSource>((ref) => SolicitudLocalDataSource());

/// Lista de borradores del asesor autenticado.
final borradoresProvider =
    FutureProvider.autoDispose<List<BorradorSolicitud>>((ref) {
  final asesor = ref.watch(loginViewModelProvider).asesor;
  if (asesor == null) return Future.value(const []);
  return ref.watch(solicitudLocalProvider).listar(asesor.id);
});
