import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/notificaciones/notificacion_service.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../domain/mora_model.dart';
import 'cobranza_viewmodel.dart';

/// Captura la ubicacion actual (best-effort). Devuelve (null,null) si se niega.
Future<(double?, double?)> _ubicacionActual() async {
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return (null, null);
    }
    final p = await Geolocator.getCurrentPosition();
    return (p.latitude, p.longitude);
  } catch (_) {
    return (null, null);
  }
}

/// M10 — Recuperacion de cartera vencida.
class CobranzaScreen extends ConsumerWidget {
  const CobranzaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cobranzaViewModelProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: 'Cobranza (mora)'),
      body: switch (state.status) {
        CobranzaStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        CobranzaStatus.error =>
          Center(child: Text(state.error ?? 'Error')),
        CobranzaStatus.ready => Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total vencido de tu cartera',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Text(Formatters.soles(state.totalVencido),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger)),
                    Text('${state.items.length} clientes en mora',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: state.items.isEmpty
                    ? const Center(child: Text('Sin clientes en mora.'))
                    : ListView.builder(
                        itemCount: state.items.length,
                        itemBuilder: (_, i) => _MoraTile(item: state.items[i]),
                      ),
              ),
            ],
          ),
      },
    );
  }
}

/// Color de semaforo por dias de mora (RF-76).
Color _colorMora(int dias) {
  if (dias <= 30) return AppColors.warning;
  if (dias <= 60) return AppColors.secondary; // naranja
  return AppColors.danger;
}

class _MoraTile extends ConsumerWidget {
  final MoraItem item;
  const _MoraTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorMora(item.diasMora);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        leading: Container(
          width: 6,
          height: 44,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(item.clienteNombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Doc. ${item.documento} · ${item.diasMora} dias de mora'),
        trailing: Text(Formatters.soles(item.montoVencido),
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        onTap: () => _formAccion(context, ref),
      ),
    );
  }

  void _formAccion(BuildContext context, WidgetRef ref) {
    String tipo = 'visita';
    String resultado = 'compromiso_pago';
    DateTime? fechaCompromiso;
    final montoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16),
        child: StatefulBuilder(
          builder: (context, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gestion de cobranza · ${item.clienteNombre}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo de gestion'),
                items: const [
                  DropdownMenuItem(value: 'visita', child: Text('Visita')),
                  DropdownMenuItem(value: 'llamada', child: Text('Llamada')),
                  DropdownMenuItem(value: 'mensaje', child: Text('Mensaje')),
                ],
                onChanged: (v) => tipo = v ?? 'visita',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: resultado,
                decoration: const InputDecoration(labelText: 'Resultado'),
                items: const [
                  DropdownMenuItem(
                      value: 'compromiso_pago',
                      child: Text('Compromiso de pago')),
                  DropdownMenuItem(
                      value: 'pago_parcial', child: Text('Pago parcial')),
                  DropdownMenuItem(
                      value: 'sin_contacto', child: Text('Sin contacto')),
                  DropdownMenuItem(value: 'se_niega', child: Text('Se niega')),
                ],
                onChanged: (v) => resultado = v ?? 'compromiso_pago',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Monto comprometido (S/)'),
              ),
              const SizedBox(height: 10),
              // Fecha de compromiso (RF-77)
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text(fechaCompromiso == null
                    ? 'Fecha de compromiso'
                    : 'Compromiso: ${Formatters.fecha(fechaCompromiso!)}'),
                onPressed: () async {
                  final hoy = DateTime.now();
                  final f = await showDatePicker(
                    context: context,
                    initialDate: hoy.add(const Duration(days: 3)),
                    firstDate: hoy,
                    lastDate: hoy.add(const Duration(days: 365)),
                    locale: const Locale('es', 'ES'),
                  );
                  if (f != null) setSt(() => fechaCompromiso = f);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Observaciones'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final (lat, lng) = await _ubicacionActual(); // GPS RF-77
                    final fechaStr = fechaCompromiso
                        ?.toIso8601String()
                        .substring(0, 10);
                    await ref
                        .read(cobranzaViewModelProvider.notifier)
                        .registrarAccion(
                          clienteId: item.clienteId,
                          codCuentaCredito: item.codCuentaCredito,
                          tipoGestion: tipo,
                          resultado: resultado,
                          montoCompromiso: double.tryParse(montoCtrl.text),
                          fechaCompromiso: fechaStr,
                          observaciones: obsCtrl.text,
                          lat: lat,
                          lng: lng,
                        );
                    // Alerta de compromiso (RF-78): si hay fecha futura, se
                    // programa para ese dia; si no, se muestra de inmediato.
                    if (resultado == 'compromiso_pago') {
                      final monto = double.tryParse(montoCtrl.text) ?? 0;
                      if (fechaCompromiso != null) {
                        await NotificacionService.programarCompromiso(
                          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          cliente: item.clienteNombre,
                          monto: monto,
                          fecha: fechaCompromiso!,
                        );
                      } else {
                        await NotificacionService.alertaCompromiso(
                          cliente: item.clienteNombre,
                          monto: monto,
                          fecha: fechaStr,
                        );
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Registrar gestion'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
