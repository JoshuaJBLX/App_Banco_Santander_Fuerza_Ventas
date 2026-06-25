import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../solicitud/data/solicitud_repository.dart';
import '../../solicitud/domain/solicitud_model.dart';

/// M8 — Transmision electronica al sistema central (HU-25 / RF-62..65).
/// Muestra el progreso por pasos; si falla, permite reanudar desde el ultimo
/// paso completado. El registro real ocurre en el paso "Registrando".
class TransmisionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> datos;
  const TransmisionScreen({super.key, required this.datos});

  @override
  ConsumerState<TransmisionScreen> createState() => _TransmisionScreenState();
}

enum _Estado { pendiente, enProceso, completado, error }

class _TransmisionScreenState extends ConsumerState<TransmisionScreen> {
  static const _pasos = [
    'Validando datos',
    'Subiendo documentos',
    'Registrando en sistema central',
    'Asignando expediente',
    'Solicitud enviada',
  ];

  late List<_Estado> _estados;
  int _desde = 0; // primer paso no completado (reanudacion, RF-64)
  SolicitudCreada? _creada;
  String? _error;

  @override
  void initState() {
    super.initState();
    _estados = List.filled(_pasos.length, _Estado.pendiente);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ejecutar());
  }

  Future<void> _ejecutar() async {
    setState(() => _error = null);
    try {
      for (var i = _desde; i < _pasos.length; i++) {
        setState(() => _estados[i] = _Estado.enProceso);

        if (i == 2) {
          // Registro real en el backend.
          _creada ??= await ref
              .read(solicitudRepositoryProvider)
              .crear(widget.datos);
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }

        setState(() {
          _estados[i] = _Estado.completado;
          _desde = i + 1; // guarda el avance para reanudar
        });
      }
    } catch (e) {
      setState(() {
        _estados[_desde] = _Estado.error;
        _error = 'Fallo en "${_pasos[_desde]}". Puedes reintentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminado = _estados.last == _Estado.completado;
    return PopScope(
      canPop: terminado, // no permitir salir a mitad del envio
      child: Scaffold(
        appBar: const GradientAppBar(title: 'Transmision al comite'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ...List.generate(_pasos.length, (i) => _fila(i)),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _ejecutar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
            if (terminado && _creada != null)
              Card(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.success),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 40),
                      const SizedBox(height: 8),
                      Text('Expediente ${_creada!.numeroExpediente}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Tiempo estimado de respuesta: 24 h',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/cartera'),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fila(int i) {
    final estado = _estados[i];
    final (icon, color) = switch (estado) {
      _Estado.completado => (Icons.check_circle, AppColors.success),
      _Estado.error => (Icons.error, AppColors.danger),
      _Estado.enProceso => (Icons.autorenew, AppColors.primary),
      _Estado.pendiente => (Icons.radio_button_unchecked, AppColors.neutral),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          estado == _Estado.enProceso
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Icon(icon, color: color),
          const SizedBox(width: 14),
          Text(
            i == 1 && estado == _Estado.completado
                ? 'Subiendo documentos (4 de 4)'
                : _pasos[i],
            style: TextStyle(
              fontWeight:
                  estado == _Estado.enProceso ? FontWeight.w700 : FontWeight.w500,
              color: estado == _Estado.pendiente
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
