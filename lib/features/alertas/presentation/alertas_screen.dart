import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../data/alertas_repository.dart';

/// HU-14 — Alertas de caida de cartera.
class AlertasScreen extends ConsumerWidget {
  const AlertasScreen({super.key});

  static (IconData, Color) _estilo(String tipo) {
    switch (tipo) {
      case 'primer_dia_mora':
        return (Icons.warning_amber, AppColors.warning);
      case 'mora_30d':
        return (Icons.error, AppColors.secondary);
      case 'mora_60d':
        return (Icons.dangerous, AppColors.danger);
      case 'pago_parcial':
        return (Icons.payments, AppColors.info);
      case 'pago_total':
        return (Icons.check_circle, AppColors.success);
      default:
        return (Icons.notifications, AppColors.neutral);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertasProvider);
    return Scaffold(
      appBar: const GradientAppBar(title: 'Alertas de cartera'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error al cargar alertas.')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('No tienes alertas.'))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(alertasProvider);
                  ref.invalidate(alertasNoLeidasProvider);
                },
                child: ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final a = lista[i];
                    final (icon, color) = _estilo(a.tipoAlerta);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      color: a.leida
                          ? AppColors.surface
                          : color.withValues(alpha: 0.06),
                      child: ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(a.clienteNombre,
                            style: TextStyle(
                                fontWeight: a.leida
                                    ? FontWeight.w500
                                    : FontWeight.w700)),
                        subtitle: Text(a.mensaje ?? a.tipoAlerta),
                        trailing: a.leida
                            ? null
                            : const Icon(Icons.circle,
                                color: AppColors.danger, size: 10),
                        onTap: () async {
                          await ref
                              .read(alertasRepositoryProvider)
                              .marcarLeida(a.id);
                          ref.invalidate(alertasProvider);
                          ref.invalidate(alertasNoLeidasProvider);
                          if (context.mounted) {
                            context.push('/ficha/${a.clienteId}');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
