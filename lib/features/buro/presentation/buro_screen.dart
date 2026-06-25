import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/semaforo_riesgo.dart';
import '../../../shared/widgets/signature_pad.dart';
import '../data/buro_repository.dart';
import 'buro_viewmodel.dart';

/// M7 — Consulta de buro y listas negras (HU-23/24).
class BuroScreen extends ConsumerStatefulWidget {
  const BuroScreen({super.key});
  @override
  ConsumerState<BuroScreen> createState() => _BuroScreenState();
}

class _BuroScreenState extends ConsumerState<BuroScreen> {
  final _dni = TextEditingController();
  final _firma = SignatureController();
  bool _consiente = false;

  @override
  void initState() {
    super.initState();
    // La firma habilita el boton; al dibujar se refresca la pantalla.
    _firma.addListener(_onFirma);
  }

  void _onFirma() => setState(() {});

  @override
  void dispose() {
    _firma.removeListener(_onFirma);
    _firma.dispose();
    _dni.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buroViewModelProvider);
    return Scaffold(
      appBar: const GradientAppBar(title: 'Consulta de buro'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _dni,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 8,
            decoration: const InputDecoration(
                labelText: 'DNI del cliente', counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          // Consentimiento (RF-57, Ley 29733)
          CheckboxListTile(
            value: _consiente,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'El cliente autoriza la consulta en centrales de riesgo '
              '(Ley 29733 de Proteccion de Datos Personales).',
              style: TextStyle(fontSize: 13),
            ),
            onChanged: (v) => setState(() => _consiente = v ?? false),
          ),
          // Firma digital de consentimiento (RF-57, Ley 29733).
          if (_consiente) ...[
            const SizedBox(height: 8),
            const Text('Firma del cliente autorizando la consulta:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            SignaturePad(controller: _firma, height: 150),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: (!_consiente ||
                    _firma.isEmpty ||
                    state.cargando ||
                    _dni.text.trim().length != 8)
                ? null
                : () => ref
                    .read(buroViewModelProvider.notifier)
                    .consultar(_dni.text.trim()),
            icon: state.cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: const Text('Consultar buro'),
          ),
          if (!_consiente || _firma.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Se requiere el consentimiento y la firma del cliente para '
                  'consultar (Ley 29733).',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(state.error!,
                  style: const TextStyle(color: AppColors.danger)),
            ),
          if (state.resultado != null) ...[
            const SizedBox(height: 16),
            _ResultadoBuroCard(r: state.resultado!),
          ],
        ],
      ),
    );
  }
}

class _ResultadoBuroCard extends StatelessWidget {
  final ResultadoBuro r;
  const _ResultadoBuroCard({required this.r});

  @override
  Widget build(BuildContext context) {
    if (r.enListaNegra) {
      return Card(
        color: AppColors.danger.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.danger),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.block, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text('Cliente bloqueado',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text(r.motivoBloqueo ?? 'Aparece en lista de restriccion.'),
              const SizedBox(height: 4),
              const Text('No es posible iniciar la solicitud para este cliente.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SemaforoRiesgo(calificacionSbs: r.calificacionSbs),
            const Divider(height: 20),
            _fila('Entidades con deuda', '${r.entidadesConDeuda}'),
            _fila('Deuda total', Formatters.soles(r.deudaTotal)),
            _fila('Mayor deuda', Formatters.soles(r.mayorDeuda)),
            _fila('Dias mayor mora', '${r.diasMayorMora}'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.interpretacion,
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: AppColors.textSecondary)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
