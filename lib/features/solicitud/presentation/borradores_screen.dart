import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import 'solicitud_viewmodel.dart';

/// M5 / HU-18 — Lista de borradores de solicitud.
class BorradoresScreen extends ConsumerWidget {
  const BorradoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(borradoresProvider);
    return Scaffold(
      appBar: const GradientAppBar(title: 'Borradores'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error al cargar.')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('No tienes borradores guardados.'))
            : ListView.builder(
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final b = lista[i];
                  return Dismissible(
                    key: ValueKey(b.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.danger,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async => await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar borrador'),
                            content:
                                const Text('Esta accion no se puede deshacer.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Eliminar')),
                            ],
                          ),
                        ) ??
                        false,
                    onDismissed: (_) async {
                      await ref.read(solicitudLocalProvider).eliminar(b.id);
                      ref.invalidate(borradoresProvider);
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      child: ListTile(
                        leading: const Icon(Icons.edit_note,
                            color: AppColors.primary),
                        title: Text(b.clienteNombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Paso ${b.pasoActual}/4 · ${Formatters.soles(b.montoSolicitado)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Retoma el borrador en el paso donde se quedo.
                          context.push('/solicitud', extra: {
                            'borradorId': b.id,
                            'datos': b.datos,
                            'paso': (b.pasoActual - 1).clamp(0, 3),
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
