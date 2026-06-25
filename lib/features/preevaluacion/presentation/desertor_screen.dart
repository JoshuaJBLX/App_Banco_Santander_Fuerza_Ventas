import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../auth/presentation/login_viewmodel.dart';
import '../data/desertor_local_datasource.dart';

/// M4 / RF-42 — Registro de cliente desertor.
/// Captura motivo de desercion, institucion a la que migro, probabilidad de
/// retorno y observaciones libres. Se guarda offline (pendiente de sync).
class DesertorScreen extends ConsumerStatefulWidget {
  const DesertorScreen({super.key});
  @override
  ConsumerState<DesertorScreen> createState() => _DesertorScreenState();
}

class _DesertorScreenState extends ConsumerState<DesertorScreen> {
  final _nombre = TextEditingController();
  final _doc = TextEditingController();
  final _institucion = TextEditingController();
  final _obs = TextEditingController();

  String _motivo = 'Mejor tasa en otra entidad';
  String _probabilidad = 'Media';
  bool _guardando = false;

  static const _motivos = [
    'Mejor tasa en otra entidad',
    'Mala experiencia de servicio',
    'Cierre del negocio',
    'Sobreendeudamiento',
    'Cambio de domicilio',
    'Otro',
  ];

  @override
  void dispose() {
    for (final c in [_nombre, _doc, _institucion, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valido =>
      _nombre.text.trim().isNotEmpty && _doc.text.trim().length == 8;

  Future<void> _guardar() async {
    final asesor = ref.read(loginViewModelProvider).asesor;
    if (asesor == null) return;
    setState(() => _guardando = true);
    try {
      await DesertorLocalDataSource().guardar(
        id: 'des-${DateTime.now().millisecondsSinceEpoch}',
        asesorId: asesor.id,
        clienteNombre: _nombre.text.trim(),
        documento: _doc.text.trim(),
        motivo: _motivo,
        institucionMigro: _institucion.text.trim(),
        probabilidadRetorno: _probabilidad,
        observaciones: _obs.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cliente desertor registrado.')));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo registrar.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Cliente desertor'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _campo(_nombre, 'Nombre del cliente'),
          _campo(_doc, 'Documento (DNI)', numerico: true, max: 8),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _motivo,
            decoration: const InputDecoration(labelText: 'Motivo de desercion'),
            items: _motivos
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _motivo = v ?? _motivos.first),
          ),
          const SizedBox(height: 12),
          _campo(_institucion, 'Institucion a la que migro (si se conoce)'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _probabilidad,
            decoration:
                const InputDecoration(labelText: 'Probabilidad de retorno'),
            items: const ['Alta', 'Media', 'Baja']
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _probabilidad = v ?? 'Media'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obs,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observaciones'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.desertor),
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_off),
            label: const Text('Registrar desercion'),
            onPressed: (!_valido || _guardando) ? null : _guardar,
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String label,
      {bool numerico = false, int? max}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: numerico ? TextInputType.number : TextInputType.text,
        maxLength: max,
        decoration: InputDecoration(labelText: label, counterText: ''),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
