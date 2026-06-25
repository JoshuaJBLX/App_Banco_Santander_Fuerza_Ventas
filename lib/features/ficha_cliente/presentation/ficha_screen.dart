import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/semaforo_riesgo.dart';
import '../../cartera/presentation/cartera_viewmodel.dart';
import '../data/ficha_repository.dart';
import '../domain/ficha_model.dart';
import 'ficha_viewmodel.dart';

/// Ficha completa del cliente (M3 / HU-11).
class FichaScreen extends ConsumerWidget {
  final String clienteId;
  final String? carteraId; // si viene de la cartera, permite registrar visita
  const FichaScreen({super.key, required this.clienteId, this.carteraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fichaViewModelProvider(clienteId));

    return Scaffold(
      appBar: const GradientAppBar(title: 'Ficha del cliente'),
      bottomNavigationBar: carteraId == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.assignment_turned_in),
                  label: const Text('Registrar resultado de visita'),
                  onPressed: () => _registrarVisita(context, ref),
                ),
              ),
            ),
      body: switch (state.status) {
        FichaStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        FichaStatus.error =>
          Center(child: Text(state.error ?? 'Error al cargar')),
        FichaStatus.ready => _Contenido(ficha: state.ficha!),
      },
    );
  }

  void _registrarVisita(BuildContext context, WidgetRef ref) {
    const opciones = {
      'visitado': 'Visitado',
      'no_encontrado': 'No encontrado',
      'reagendado': 'Reagendar',
      'negocio_cerrado': 'Negocio cerrado',
    };
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resultado de la visita',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: obsCtrl,
              maxLength: 200, // RF-07
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Observacion (opcional)'),
            ),
            ...opciones.entries.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(e.value),
                  onTap: () async {
                    final (lat, lng) = await ubicacionVisita(); // GPS RF-07
                    await ref
                        .read(carteraViewModelProvider.notifier)
                        .marcarVisita(carteraId!,
                            resultado: e.key,
                            observacion: obsCtrl.text.trim(),
                            lat: lat,
                            lng: lng);
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) context.pop(); // vuelve a cartera
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Captura GPS para registrar la visita (HU-07/RF-17). Best-effort.
Future<(double?, double?)> ubicacionVisita() async {
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

class _Contenido extends StatelessWidget {
  final FichaCliente ficha;
  const _Contenido({required this.ficha});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Encabezado(ficha: ficha),
        const SizedBox(height: 12),
        _SeccionContacto(ficha: ficha),
        const SizedBox(height: 8),
        _BotonUbicacionNegocio(clienteId: ficha.id),
        const SizedBox(height: 12),
        _SeccionPosicion(pos: ficha.posicion),
        const SizedBox(height: 12),
        if (ficha.comportamiento.isNotEmpty) ...[
          _SeccionComportamiento(
              datos: ficha.comportamiento, ind: ficha.indicadores),
          const SizedBox(height: 12),
        ],
        _SeccionHistorial(historial: ficha.historial),
        const SizedBox(height: 12),
        _SeccionOferta(ficha: ficha),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Tarjeta({required this.titulo, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final FichaCliente ficha;
  const _Encabezado({required this.ficha});

  String get _iniciales {
    final n = ficha.nombres.isNotEmpty ? ficha.nombres[0] : '';
    final a = ficha.apellidos.isNotEmpty ? ficha.apellidos[0] : '';
    return '$n$a'.toUpperCase();
  }

  Future<void> _llamar() async {
    final tel = ficha.telefono;
    if (tel == null || tel.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(_iniciales,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ficha.nombreCompleto,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Doc. ${ficha.numeroDocumento}',
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SemaforoRiesgo(calificacionSbs: ficha.calificacionSbs),
                const Spacer(),
                if ((ficha.telefono ?? '').isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _llamar,
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Llamar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// HU-10 / RF-25-26 — Captura GPS del negocio + geocodificacion inversa.
class _BotonUbicacionNegocio extends ConsumerStatefulWidget {
  final String clienteId;
  const _BotonUbicacionNegocio({required this.clienteId});
  @override
  ConsumerState<_BotonUbicacionNegocio> createState() =>
      _BotonUbicacionNegocioState();
}

class _BotonUbicacionNegocioState
    extends ConsumerState<_BotonUbicacionNegocio> {
  bool _cargando = false;

  Future<void> _actualizar() async {
    setState(() => _cargando = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _msg('Permiso de ubicacion denegado.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      // Geocodificacion inversa (RF-26): coordenadas -> direccion legible.
      String dir = '${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)}';
      try {
        final marks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final m = marks.first;
          dir = [m.thoroughfare, m.subLocality, m.locality, m.administrativeArea]
              .where((e) => e != null && e.isNotEmpty)
              .join(', ');
        }
      } catch (_) {/* sin geocoder: queda la coordenada */}

      if (!mounted) return;
      // El asesor puede confirmar o corregir la direccion antes de guardar.
      final ctrl = TextEditingController(text: dir);
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ubicacion del negocio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Lat ${pos.latitude.toStringAsFixed(5)}, '
                  'Lng ${pos.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Direccion aproximada'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Descartar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar')),
          ],
        ),
      );
      if (confirmar != true) return;

      final ok = await ref.read(fichaRepositoryProvider).actualizarUbicacion(
            clienteId: widget.clienteId,
            lat: pos.latitude,
            lng: pos.longitude,
            direccion: ctrl.text.trim(),
          );
      _msg(ok
          ? 'Ubicacion del negocio actualizada.'
          : 'Ubicacion capturada (se sincronizara luego).');
    } catch (_) {
      _msg('No se pudo obtener la ubicacion.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _msg(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: _cargando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location, size: 18),
        label: const Text('Actualizar ubicacion del negocio'),
        onPressed: _cargando ? null : _actualizar,
      ),
    );
  }
}

class _SeccionContacto extends StatelessWidget {
  final FichaCliente ficha;
  const _SeccionContacto({required this.ficha});
  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Contacto y negocio',
      child: Column(
        children: [
          _fila(Icons.phone, 'Telefono', ficha.telefono ?? '—'),
          _fila(Icons.location_on, 'Direccion', ficha.direccion ?? '—'),
          _fila(Icons.store, 'Negocio',
              '${ficha.nombreNegocio ?? '—'} (${ficha.tipoNegocio ?? '—'})'),
          _fila(Icons.schedule, 'Antiguedad',
              '${ficha.antiguedadNegocioMeses ?? 0} meses'),
        ],
      ),
    );
  }

  Widget _fila(IconData icon, String label, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text('$label: ',
                style: const TextStyle(color: AppColors.textSecondary)),
            Expanded(
              child: Text(valor,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _SeccionPosicion extends StatelessWidget {
  final PosicionCliente pos;
  const _SeccionPosicion({required this.pos});
  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Posicion en el sistema',
      child: Column(
        children: [
          Row(
            children: [
              _kpi('Deuda total', Formatters.soles(pos.deudaTotal),
                  AppColors.primary),
              _kpi('Cuentas vigentes', '${pos.cuentasVigentes}',
                  AppColors.success),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _kpi('Cuentas en mora', '${pos.cuentasMora}',
                  pos.cuentasMora > 0 ? AppColors.danger : AppColors.success),
              _kpi('Mayor mora', '${pos.diasMayorMora} d',
                  pos.diasMayorMora > 0 ? AppColors.danger : AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String valor, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text(valor,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
}

/// HU-12 — Grafico de comportamiento de pagos (12 meses) + indicadores.
class _SeccionComportamiento extends StatelessWidget {
  final List<int> datos; // 12 valores: 0=sin, 1=puntual, 2=mora
  final IndicadoresComportamiento? ind;
  const _SeccionComportamiento({required this.datos, this.ind});

  static const _meses = [
    'E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
  ];

  Color _color(int v) => switch (v) {
        1 => AppColors.success,
        2 => AppColors.danger,
        _ => AppColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Comportamiento de pagos (12 meses)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: 2,
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= _meses.length) return const SizedBox();
                        return Text(_meses[i],
                            style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(datos.length, (i) {
                  final v = datos[i];
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: v == 0 ? 0.4 : v.toDouble(),
                      color: _color(v),
                      width: 9,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ]);
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(spacing: 12, children: [
            _Leyenda(color: AppColors.success, texto: 'Puntual'),
            _Leyenda(color: AppColors.danger, texto: 'Con mora'),
            _Leyenda(color: AppColors.neutral, texto: 'Sin cuota'),
          ]),
          if (ind != null) ...[
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ind('% puntual', '${ind!.pctPuntual}%'),
                _ind('Mora prom.', '${ind!.diasPromMora} d'),
                _ind('Pagado', Formatters.soles(ind!.montoPagado)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ind(String label, String valor) => Column(
        children: [
          Text(valor,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  const _Leyenda({required this.color, required this.texto});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 11, height: 11, color: color),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ]);
}

class _SeccionHistorial extends StatelessWidget {
  final List<CreditoHistorial> historial;
  const _SeccionHistorial({required this.historial});
  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Historial crediticio (${historial.length})',
      child: historial.isEmpty
          ? const Text('Sin creditos registrados.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: historial.map((c) {
                final pct = c.cuotasTotal == 0
                    ? 0
                    : ((c.cuotasPagadas / c.cuotasTotal) * 100).round();
                final colorEstado =
                    c.estado == 'vencido' ? AppColors.danger : AppColors.success;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${c.producto} · ${Formatters.soles(c.montoDesembolsado)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${c.plazoMeses} cuotas · TEA ${c.tea}% · $pct% pagado',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(c.estado.toUpperCase(),
                            style: TextStyle(
                                color: colorEstado,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _SeccionOferta extends StatelessWidget {
  final FichaCliente ficha;
  const _SeccionOferta({required this.ficha});

  @override
  Widget build(BuildContext context) {
    final oferta = ficha.oferta;
    if (oferta == null) {
      return _Tarjeta(
        titulo: 'Oferta vigente',
        child: const Text('Sin oferta vigente. Puede iniciar solicitud nueva.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final o = oferta;
    return Card(
      color: AppColors.visitedTile,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.success),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified, color: AppColors.success),
                SizedBox(width: 8),
                Text('Oferta preaprobada',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 8),
            Text(Formatters.soles(o.montoMaximo),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            Text(
                'Plazo ${o.plazoSugeridoMeses} meses · TEA ${o.teaReferencial}% · '
                'confianza ${o.scoreConfianza}%',
                style: const TextStyle(color: AppColors.textSecondary)),
            if (o.fechaVencimiento != null)
              Text('Vigente hasta ${o.fechaVencimiento}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            // HU-13 / RF-34 — prellena la solicitud con la oferta preaprobada.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success),
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text('Usar esta oferta'),
                onPressed: () => context.push('/solicitud', extra: {
                  'monto': o.montoMaximo,
                  'plazo': o.plazoSugeridoMeses,
                  'datos': {
                    'numero_documento': ficha.numeroDocumento,
                    'nombres': ficha.nombres,
                    'apellidos': ficha.apellidos,
                    'telefono': ficha.telefono,
                    'tipo_negocio': ficha.tipoNegocio,
                    'nombre_negocio': ficha.nombreNegocio,
                    'monto_solicitado': o.montoMaximo,
                    'plazo_meses': o.plazoSugeridoMeses,
                  },
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
