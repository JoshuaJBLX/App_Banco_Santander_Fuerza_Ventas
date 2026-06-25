import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/utils/simulador.dart';
import '../../../shared/widgets/gradient_app_bar.dart';

/// M5 / HU-19 — Simulador de credito rapido e independiente.
class SimuladorScreen extends ConsumerStatefulWidget {
  const SimuladorScreen({super.key});
  @override
  ConsumerState<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends ConsumerState<SimuladorScreen> {
  double _monto = 5000;
  int _plazo = 12;

  SimulacionCredito get _sim =>
      Simulador.calcular(monto: _monto, plazoMeses: _plazo);

  @override
  Widget build(BuildContext context) {
    final sim = _sim;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Simulador de credito'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Monto: ${Formatters.soles(_monto)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _monto,
            min: 500,
            max: 150000,
            divisions: 299,
            activeColor: AppColors.primary,
            label: Formatters.soles(_monto),
            onChanged: (v) => setState(() => _monto = v),
          ),
          DropdownButtonFormField<int>(
            initialValue: _plazo,
            decoration: const InputDecoration(labelText: 'Plazo (meses)'),
            items: const [3, 6, 12, 18, 24, 36, 48, 60]
                .map((m) => DropdownMenuItem(value: m, child: Text('$m meses')))
                .toList(),
            onChanged: (v) => setState(() => _plazo = v ?? 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _IndicadorCard(
                  titulo: 'Cuota mensual',
                  valor: Formatters.soles(sim.cuotaMensual),
                  color: AppColors.primary),
              _IndicadorCard(
                  titulo: 'Total a pagar',
                  valor: Formatters.soles(sim.totalPagar),
                  color: AppColors.info),
              _IndicadorCard(
                  titulo: 'Costo financiero',
                  valor: Formatters.soles(sim.costoFinanciero),
                  color: AppColors.secondary),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('TEA referencial ${sim.teaReferencial}%',
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.assignment),
            label: const Text('Crear solicitud con estos datos'),
            onPressed: () => context.push('/solicitud', extra: {
              'monto': _monto,
              'plazo': _plazo,
            }),
          ),
        ],
      ),
    );
  }
}

class _IndicadorCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color color;
  const _IndicadorCard(
      {required this.titulo, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text(valor,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
