import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/utils/simulador.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/signature_pad.dart';
import '../../../shared/widgets/stepper_solicitud.dart';
import '../../auth/presentation/login_viewmodel.dart';
import 'solicitud_viewmodel.dart';

/// M5 — Captura de solicitud de credito en 4 pasos (HU-17).
/// [args] permite prellenar al retomar un borrador (HU-18) o venir del
/// simulador (HU-19): {borradorId, datos:Map, paso:int, monto:double, plazo:int}.
class SolicitudScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;
  const SolicitudScreen({super.key, this.args});
  @override
  ConsumerState<SolicitudScreen> createState() => _SolicitudScreenState();
}

class _SolicitudScreenState extends ConsumerState<SolicitudScreen> {
  int _paso = 0; // 0..3
  String? _borradorId;

  // Paso 1
  final _doc = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  String _estadoCivil = 'Soltero';
  String _gradoInstruccion = 'Secundaria';
  final _conyugeNombre = TextEditingController();
  final _conyugeDoc = TextEditingController();
  // Paso 2
  String _tipoNegocio = 'Comercio';
  final _nombreNegocio = TextEditingController();
  final _ingresos = TextEditingController();
  final _gastos = TextEditingController();
  final _patrimonio = TextEditingController();
  // Paso 3
  double _monto = 5000;
  int _plazo = 12;
  // Paso 4
  final _firma = SignatureController();
  bool _veraz = false;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    if (a == null) return;
    _borradorId = a['borradorId'] as String?;
    if (a['paso'] is int) _paso = (a['paso'] as int).clamp(0, 3);
    if (a['monto'] is num) _monto = (a['monto'] as num).toDouble();
    if (a['plazo'] is num) _plazo = (a['plazo'] as num).toInt();
    final d = a['datos'] as Map<String, dynamic>?;
    if (d != null) {
      _doc.text = d['numero_documento']?.toString() ?? '';
      _nombres.text = d['nombres']?.toString() ?? '';
      _apellidos.text = d['apellidos']?.toString() ?? '';
      _telefono.text = d['telefono']?.toString() ?? '';
      _tipoNegocio = d['tipo_negocio']?.toString() ?? 'Comercio';
      _nombreNegocio.text = d['nombre_negocio']?.toString() ?? '';
      _ingresos.text = (d['ingresos_estimados'] ?? '').toString();
      if (d['monto_solicitado'] is num) {
        _monto = (d['monto_solicitado'] as num).toDouble();
      }
      if (d['plazo_meses'] is num) _plazo = (d['plazo_meses'] as num).toInt();
    }
  }

  bool get _requiereConyuge =>
      _estadoCivil == 'Casado' || _estadoCivil == 'Conviviente';

  @override
  void dispose() {
    for (final c in [
      _doc, _nombres, _apellidos, _telefono, _conyugeNombre, _conyugeDoc,
      _nombreNegocio, _ingresos, _gastos, _patrimonio
    ]) {
      c.dispose();
    }
    _firma.dispose();
    super.dispose();
  }

  Map<String, dynamic> _formData() => {
        'numero_documento': _doc.text.trim(),
        'nombres': _nombres.text.trim(),
        'apellidos': _apellidos.text.trim(),
        'telefono': _telefono.text.trim(),
        'estado_civil': _estadoCivil,
        'grado_instruccion': _gradoInstruccion,
        'tiene_conyuge': _requiereConyuge,
        if (_requiereConyuge)
          'conyuge_json': {
            'nombres': _conyugeNombre.text.trim(),
            'numero_documento': _conyugeDoc.text.trim(),
          },
        'tipo_negocio': _tipoNegocio,
        'nombre_negocio': _nombreNegocio.text.trim(),
        'ingresos_estimados': double.tryParse(_ingresos.text) ?? 0,
        'gastos_mensuales': double.tryParse(_gastos.text) ?? 0,
        'patrimonio_estimado': double.tryParse(_patrimonio.text),
        'monto_solicitado': _monto,
        'plazo_meses': _plazo,
      };

  bool get _tieneDatos =>
      _doc.text.isNotEmpty ||
      _nombres.text.isNotEmpty ||
      _nombreNegocio.text.isNotEmpty;

  Future<void> _guardarBorrador() async {
    final asesor = ref.read(loginViewModelProvider).asesor;
    if (asesor == null) return;
    _borradorId ??= 'draft-${DateTime.now().millisecondsSinceEpoch}';
    final nombre =
        '${_nombres.text.trim()} ${_apellidos.text.trim()}'.trim();
    await ref.read(solicitudLocalProvider).guardarBorrador(
          id: _borradorId!,
          asesorId: asesor.id,
          clienteNombre: nombre.isEmpty ? 'Sin nombre' : nombre,
          pasoActual: _paso + 1,
          datos: _formData(),
          montoSolicitado: _monto,
        );
  }

  /// Dialogo al salir: Guardar borrador / Descartar / Cancelar (HU-18).
  Future<void> _alSalir() async {
    if (!_tieneDatos) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final opcion = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Salir de la solicitud'),
        content: const Text('Tienes datos sin enviar. Que deseas hacer?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancelar'),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'descartar'),
              child: const Text('Descartar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'guardar'),
              child: const Text('Guardar borrador')),
        ],
      ),
    );
    if (opcion == 'guardar') {
      await _guardarBorrador();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Borrador guardado.')));
      }
    }
    if (opcion == 'guardar' || opcion == 'descartar') {
      if (mounted) Navigator.of(context).pop();
    }
  }

  SimulacionCredito get _sim =>
      Simulador.calcular(monto: _monto, plazoMeses: _plazo);

  bool _validarPaso(int paso) {
    switch (paso) {
      case 0:
        return _doc.text.trim().length == 8 &&
            _nombres.text.trim().isNotEmpty &&
            _apellidos.text.trim().isNotEmpty;
      case 1:
        return _nombreNegocio.text.trim().isNotEmpty &&
            (double.tryParse(_ingresos.text) ?? 0) > 0;
      case 2:
        return true;
      case 3:
        return _firma.isNotEmpty && _veraz;
      default:
        return true;
    }
  }

  void _continuar() {
    if (!_validarPaso(_paso)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Completa los campos obligatorios de este paso.')));
      return;
    }
    if (_paso < 3) {
      setState(() => _paso++);
    } else {
      _enviar();
    }
  }

  void _enviar() {
    // Pasa a la pantalla de transmision (M8), que muestra el progreso por
    // pasos y hace el registro real en el backend.
    final datos = {
      ..._formData(),
      'moneda': 'PEN',
      'tipo_cuota': 'mensual',
      'destino_credito': 'Capital de trabajo',
      'cuota_estimada': _sim.cuotaMensual,
      'tea_referencial': _sim.teaReferencial,
      'firma_cliente_base64':
          base64Encode(utf8.encode('firma:${_doc.text.trim()}')),
    };
    context.push('/transmision', extra: datos);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(solicitudViewModelProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _alSalir();
      },
      child: Scaffold(
      appBar: GradientAppBar(
        title: 'Solicitud de credito',
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Borradores',
            onPressed: () => context.push('/borradores'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de 4 pasos (no desborda: usa Expanded)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: StepperSolicitud(pasoActual: _paso + 1),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _contenidoPaso(),
            ),
          ),
          // Botonera Anterior / Siguiente|Enviar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_paso > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            state.enviando ? null : () => setState(() => _paso--),
                        child: const Text('Anterior'),
                      ),
                    ),
                  if (_paso > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: state.enviando ? null : _continuar,
                      child: Text(_paso == 3
                          ? (state.enviando ? 'Enviando...' : 'Enviar')
                          : 'Siguiente'),
                    ),
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

  Widget _contenidoPaso() {
    switch (_paso) {
      case 0:
        return Column(children: [
          _campo(_doc, 'Documento (DNI)', numerico: true, max: 8),
          _campo(_nombres, 'Nombres'),
          _campo(_apellidos, 'Apellidos'),
          _campo(_telefono, 'Telefono', numerico: true, max: 9),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DropdownButtonFormField<String>(
              initialValue: _estadoCivil,
              decoration: const InputDecoration(labelText: 'Estado civil'),
              items: const ['Soltero', 'Casado', 'Conviviente', 'Divorciado', 'Viudo']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _estadoCivil = v ?? 'Soltero'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DropdownButtonFormField<String>(
              initialValue: _gradoInstruccion,
              decoration:
                  const InputDecoration(labelText: 'Grado de instruccion'),
              items: const ['Primaria', 'Secundaria', 'Tecnico', 'Universitario']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _gradoInstruccion = v ?? 'Secundaria'),
            ),
          ),
          // Datos del conyuge segun estado civil (RF-44).
          if (_requiereConyuge) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Datos del conyuge',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            _campo(_conyugeNombre, 'Nombres del conyuge'),
            _campo(_conyugeDoc, 'Documento del conyuge',
                numerico: true, max: 8),
          ],
        ]);
      case 1:
        return Column(children: [
          DropdownButtonFormField<String>(
            initialValue: _tipoNegocio,
            decoration: const InputDecoration(labelText: 'Tipo de negocio'),
            items: const [
              DropdownMenuItem(value: 'Comercio', child: Text('Comercio')),
              DropdownMenuItem(value: 'Servicios', child: Text('Servicios')),
              DropdownMenuItem(value: 'Produccion', child: Text('Produccion')),
              DropdownMenuItem(
                  value: 'Agropecuario', child: Text('Agropecuario')),
            ],
            onChanged: (v) => _tipoNegocio = v ?? 'Comercio',
          ),
          _campo(_nombreNegocio, 'Nombre del negocio'),
          _campo(_ingresos, 'Ingresos mensuales (S/)', numerico: true),
          _campo(_gastos, 'Gastos mensuales (S/)', numerico: true),
          _campo(_patrimonio, 'Patrimonio estimado (S/, opcional)',
              numerico: true),
        ]);
      case 2:
        return _PasoCondiciones(
          monto: _monto,
          plazo: _plazo,
          sim: _sim,
          onMonto: (v) => setState(() => _monto = v),
          onPlazo: (v) => setState(() => _plazo = v),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
            _resumenFila('Cliente', '${_nombres.text} ${_apellidos.text}'),
            _resumenFila('Monto', Formatters.soles(_monto)),
            _resumenFila('Plazo', '$_plazo meses'),
            _resumenFila('Cuota', Formatters.soles(_sim.cuotaMensual)),
            const SizedBox(height: 12),
            const Text('Firma del cliente:'),
            const SizedBox(height: 6),
            SignaturePad(controller: _firma),
            CheckboxListTile(
              value: _veraz,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                  'El cliente declara que los datos son veraces.',
                  style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _veraz = v ?? false),
            ),
          ],
        );
    }
  }

  Widget _campo(TextEditingController c, String label,
      {bool numerico = false, int? max}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: numerico ? TextInputType.number : TextInputType.text,
        inputFormatters:
            numerico ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLength: max,
        decoration: InputDecoration(labelText: label, counterText: ''),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _resumenFila(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text('$k: ', style: const TextStyle(color: AppColors.textSecondary)),
          Expanded(
              child: Text(v,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _PasoCondiciones extends StatelessWidget {
  final double monto;
  final int plazo;
  final SimulacionCredito sim;
  final ValueChanged<double> onMonto;
  final ValueChanged<int> onPlazo;
  const _PasoCondiciones({
    required this.monto,
    required this.plazo,
    required this.sim,
    required this.onMonto,
    required this.onPlazo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monto: ${Formatters.soles(monto)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: monto,
          min: 500,
          max: 150000,
          divisions: 299,
          activeColor: AppColors.primary,
          label: Formatters.soles(monto),
          onChanged: onMonto,
        ),
        DropdownButtonFormField<int>(
          initialValue: plazo,
          decoration: const InputDecoration(labelText: 'Plazo (meses)'),
          items: const [3, 6, 12, 18, 24, 36, 48, 60]
              .map((m) => DropdownMenuItem(value: m, child: Text('$m meses')))
              .toList(),
          onChanged: (v) => onPlazo(v ?? 12),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppColors.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Simulacion',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.primary)),
                const Divider(),
                _fila('Cuota mensual', Formatters.soles(sim.cuotaMensual)),
                _fila('Total a pagar', Formatters.soles(sim.totalPagar)),
                _fila('Costo financiero', Formatters.soles(sim.costoFinanciero)),
                _fila('TEA referencial', '${sim.teaReferencial}%'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fila(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: AppColors.textSecondary)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
