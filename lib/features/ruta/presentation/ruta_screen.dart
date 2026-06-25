import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart'
    show GoogleMapController, CameraUpdate, LatLng;

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../auth/domain/asesor_model.dart';
import '../../auth/presentation/login_viewmodel.dart';
import '../../cartera/domain/cartera_model.dart';
import '../../cartera/presentation/cartera_viewmodel.dart';
import '../domain/geo_point.dart';
import 'ruta_map_view.dart';

/// M2 — Planificacion de ruta (HU-08 / RF-19..22).
class RutaScreen extends ConsumerStatefulWidget {
  const RutaScreen({super.key});
  @override
  ConsumerState<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends ConsumerState<RutaScreen> {
  /// Controller de Google Maps (solo mobile/nativo).
  GoogleMapController? _map;
  GeoPoint? _miUbicacion;
  List<CarteraItem> _orden = [];

  String _asesorKey(AsesorModel a) =>
      a.id.isNotEmpty ? a.id : a.codigoEmpleado;

  void _asegurarCarteraCargada() {
    final asesor = ref.read(loginViewModelProvider).asesor;
    if (asesor == null) return;
    final state = ref.read(carteraViewModelProvider);
    if (state.items.isEmpty && state.status != CarteraStatus.loading) {
      ref.read(carteraViewModelProvider.notifier).cargar(_asesorKey(asesor));
    }
  }

  List<CarteraItem> get _clientes => ref
      .read(carteraViewModelProvider)
      .items
      .where((c) => c.tieneUbicacion && !c.visitado)
      .toList();

  /// Obtiene la posición del asesor.
  /// En Web: usa Geolocator (funciona con permiso del navegador).
  /// En Mobile: usa Geolocator nativo y mueve la cámara de Google Maps.
  Future<void> _miPosicion() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() => _miUbicacion = GeoPoint(p.latitude, p.longitude));
      // En mobile, mover la cámara de Google Maps
      if (!kIsWeb) {
        _map?.animateCamera(
          CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
        );
      }
    } catch (_) {/* sin ubicacion */}
  }

  /// Algoritmo del vecino mas cercano (RF-21).
  void _optimizar() {
    final pend = _clientes;
    if (pend.isEmpty) return;
    final inicio = _miUbicacion ??
        (pend.first.tieneUbicacion
            ? GeoPoint(pend.first.lat!, pend.first.lng!)
            : GeoPoint.lima);
    final restantes = [...pend];
    final orden = <CarteraItem>[];
    var actual = inicio;
    while (restantes.isNotEmpty) {
      restantes.sort((a, b) => _dist(actual, GeoPoint(a.lat!, a.lng!))
          .compareTo(_dist(actual, GeoPoint(b.lat!, b.lng!))));
      final sig = restantes.removeAt(0);
      orden.add(sig);
      actual = GeoPoint(sig.lat!, sig.lng!);
    }
    setState(() => _orden = orden);
  }

  double _dist(GeoPoint a, GeoPoint b) {
    final dx = a.lat - b.lat;
    final dy = a.lng - b.lng;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Lanza Waze; si no esta, Google Maps; si no, navegador (RF-22).
  Future<void> _navegar() async {
    final destino =
        _orden.isNotEmpty ? _orden.first : (_clientes.isNotEmpty ? _clientes.first : null);
    if (destino == null) return;
    final lat = destino.lat!, lng = destino.lng!;
    final waze = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    final gmaps = Uri.parse('google.navigation:q=$lat,$lng');
    final web = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (!kIsWeb && await canLaunchUrl(waze)) {
      await launchUrl(waze);
    } else if (!kIsWeb && await canLaunchUrl(gmaps)) {
      await launchUrl(gmaps);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _asegurarCarteraCargada();
      _miPosicion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final carteraState = ref.watch(carteraViewModelProvider);
    final items = carteraState.items;
    final conUbic = items.where((e) => e.tieneUbicacion).length;
    final cargando = carteraState.status == CarteraStatus.loading ||
        (carteraState.status == CarteraStatus.idle && items.isEmpty);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Planificación de ruta',
        actions: [
          // Botón "Mi ubicación" disponible en todas las plataformas
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mi ubicación',
            onPressed: _miPosicion,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar cartera',
            onPressed: () {
              final asesor = ref.read(loginViewModelProvider).asesor;
              if (asesor != null) {
                ref
                    .read(carteraViewModelProvider.notifier)
                    .cargar(_asesorKey(asesor));
              }
            },
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      RutaMapPanel(
                        items: items,
                        rutaOrdenada: _orden,
                        miUbicacion: _miUbicacion,
                        onControllerReady: kIsWeb
                            ? null
                            : (c) => _map = c as GoogleMapController?,
                      ),
                      // Aviso "sin clientes" solo en mobile (Web lo maneja internamente)
                      if (conUbic == 0 && !kIsWeb)
                        const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Sin clientes con ubicación.\n'
                                'Pulsa recargar para obtener coordenadas.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Banner de ruta optimizada (mobile)
                if (_orden.isNotEmpty && !kIsWeb)
                  Container(
                    color: AppColors.surface,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    width: double.infinity,
                    child: Text(
                      'Ruta optimizada: ${_orden.length} visitas · '
                      'primero ${_orden.first.clienteNombre}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                // Botones de acción
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: conUbic == 0 ? null : _optimizar,
                            icon: const Icon(Icons.route),
                            label: const Text('Optimizar ruta'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: conUbic == 0 ? null : _navegar,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Navegar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
