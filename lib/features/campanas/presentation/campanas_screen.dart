import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/gradient_app_bar.dart';

class Campana {
  final String id, clienteId, clienteNombre, tipo;
  final double montoOfertado;
  final int diasRestantes;
  const Campana(this.id, this.clienteId, this.clienteNombre, this.tipo,
      this.montoOfertado, this.diasRestantes);

  factory Campana.fromJson(Map<String, dynamic> j) => Campana(
        j['id'] as String? ?? '',
        j['cliente_id'] as String? ?? '',
        j['cliente_nombre'] as String? ?? '',
        j['tipo'] as String? ?? '',
        (j['monto_ofertado'] as num?)?.toDouble() ?? 0,
        (j['dias_restantes'] as num?)?.toInt() ?? 0,
      );
}

final campanasProvider = FutureProvider.autoDispose<List<Campana>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/campanas');
  return (data as List)
      .map((e) => Campana.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// HU-16 — Campanas activas de renovaciones y ampliaciones.
class CampanasScreen extends ConsumerWidget {
  const CampanasScreen({super.key});

  Color _color(String tipo) {
    switch (tipo) {
      case 'renovacion':
        return AppColors.renovacion;
      case 'ampliacion':
        return AppColors.ampliacion;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(campanasProvider);
    return Scaffold(
      appBar: const GradientAppBar(title: 'Campanas activas'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error al cargar.')),
        data: (lista) => lista.isEmpty
            ? const Center(child: Text('Sin campanas activas.'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final c = lista[i];
                  final color = _color(c.tipo);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(c.tipo.toUpperCase(),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const Spacer(),
                              Text('${c.diasRestantes} dias',
                                  style: TextStyle(
                                      color: c.diasRestantes <= 7
                                          ? AppColors.danger
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(c.clienteNombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          Text('Oferta: ${Formatters.soles(c.montoOfertado)}',
                              style:
                                  const TextStyle(color: AppColors.primary)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () => context.push('/solicitud',
                                  extra: {'monto': c.montoOfertado}),
                              child: const Text('Gestionar ahora'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
