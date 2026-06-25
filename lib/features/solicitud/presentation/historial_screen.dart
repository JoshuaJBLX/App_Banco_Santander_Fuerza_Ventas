import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../domain/solicitud_model.dart';
import 'solicitud_viewmodel.dart';

/// M5 / HU-20 — Historial de mis solicitudes del mes con indicadores.
class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(solicitudesHistorialProvider);
    return Scaffold(
      appBar: const GradientAppBar(title: 'Mis solicitudes'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error al cargar.')),
        data: (lista) {
          final enviadas = lista.length;
          final aprobadas = lista
              .where((s) => s.estado == 'aprobado' || s.estado == 'desembolsado')
              .length;
          final desembolsadas =
              lista.where((s) => s.estado == 'desembolsado').length;
          final montoMes =
              lista.fold<double>(0, (a, s) => a + s.montoSolicitado);
          return Column(
            children: [
              _Indicadores(
                enviadas: enviadas,
                aprobadas: aprobadas,
                desembolsadas: desembolsadas,
                monto: montoMes,
              ),
              Expanded(
                child: lista.isEmpty
                    ? const Center(
                        child: Text('Sin solicitudes este mes.'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(solicitudesHistorialProvider),
                        child: ListView.builder(
                          itemCount: lista.length,
                          itemBuilder: (_, i) => _Item(s: lista[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Indicadores extends StatelessWidget {
  final int enviadas, aprobadas, desembolsadas;
  final double monto;
  const _Indicadores({
    required this.enviadas,
    required this.aprobadas,
    required this.desembolsadas,
    required this.monto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _kpi('Enviadas', '$enviadas', AppColors.info),
              _kpi('Aprobadas', '$aprobadas', AppColors.success),
              _kpi('Desembolsadas', '$desembolsadas', AppColors.secondary),
            ],
          ),
          const SizedBox(height: 8),
          Text('Monto del mes: ${Formatters.soles(monto)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _kpi(String label, String valor, Color color) => Expanded(
        child: Column(
          children: [
            Text(valor,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _Item extends StatelessWidget {
  final SolicitudResumen s;
  const _Item({required this.s});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        title: Text(s.clienteNombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${s.numeroExpediente} · ${Formatters.soles(s.montoSolicitado)}'),
        trailing: Text(s.estado.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.info)),
      ),
    );
  }
}
