import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../cartera/domain/cartera_model.dart';
import '../domain/geo_point.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Paleta de colores por estado de cartera
// ──────────────────────────────────────────────────────────────────────────────
Color _colorPorEstado(CarteraItem c) {
  if (c.visitado) return const Color(0xFF1565C0); // Azul → Visitado
  switch (c.tipoGestion.toUpperCase()) {
    case 'RENOVACION':
      return const Color(0xFF2E7D32); // Verde → Vigente / Renovación
    case 'RECUPERACION_MORA':
      return const Color(0xFFC62828); // Rojo → Mora
    case 'AMPLIACION':
    case 'NUEVA_SOLICITUD':
      return const Color(0xFFF9A825); // Amarillo → Vencido / Nuevo
    default:
      return const Color(0xFF6A1B9A); // Púrpura → Otros
  }
}

String _etiquetaEstado(CarteraItem c) {
  if (c.visitado) return 'Visitado';
  switch (c.tipoGestion.toUpperCase()) {
    case 'RENOVACION':
      return 'Vigente';
    case 'RECUPERACION_MORA':
      return 'En mora';
    case 'AMPLIACION':
      return 'Ampliación';
    case 'NUEVA_SOLICITUD':
      return 'Nueva solicitud';
    default:
      return c.tipoGestion.replaceAll('_', ' ');
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Widget principal exportado (mismo nombre que mobile para el export condicional)
// ──────────────────────────────────────────────────────────────────────────────

/// Vista de ruta para Web usando OpenStreetMap (flutter_map).
class RutaMapPanel extends StatefulWidget {
  final List<CarteraItem> items;
  final List<CarteraItem> rutaOrdenada;
  final GeoPoint? miUbicacion;
  final void Function(dynamic controller)? onControllerReady;

  const RutaMapPanel({
    super.key,
    required this.items,
    required this.rutaOrdenada,
    this.miUbicacion,
    this.onControllerReady,
  });

  @override
  State<RutaMapPanel> createState() => _RutaMapPanelState();
}

class _RutaMapPanelState extends State<RutaMapPanel> {
  final MapController _mapController = MapController();
  CarteraItem? _clienteSeleccionado;
  GeoPoint? _ubicacionActual;
  bool _buscandoUbicacion = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Notificar al padre que el controller está listo (compatibilidad con RutaScreen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControllerReady?.call(_mapController);
      _centrarMapa();
    });
    // Si ya viene ubicación del asesor, la usamos
    if (widget.miUbicacion != null) {
      _ubicacionActual = widget.miUbicacion;
    }
  }

  @override
  void didUpdateWidget(RutaMapPanel old) {
    super.didUpdateWidget(old);
    if (widget.miUbicacion != null && widget.miUbicacion != old.miUbicacion) {
      setState(() => _ubicacionActual = widget.miUbicacion);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ── Lógica de centrado ───────────────────────────────────────────────────────

  /// Centra el mapa: asesor → primer cliente → Lima.
  void _centrarMapa() {
    final puntos = _puntosConUbicacion();
    if (puntos.isEmpty) {
      _mapController.move(
        LatLng(GeoPoint.lima.lat, GeoPoint.lima.lng),
        12.0,
      );
      return;
    }
    if (_ubicacionActual != null) {
      _mapController.move(
        LatLng(_ubicacionActual!.lat, _ubicacionActual!.lng),
        14.0,
      );
    } else {
      _mapController.move(
        LatLng(puntos.first.lat!, puntos.first.lng!),
        14.0,
      );
    }
  }

  /// FitBounds: ajusta zoom para ver todos los marcadores.
  void _recentrarRuta() {
    final puntos = _puntosConUbicacion();
    if (puntos.isEmpty) return;

    double minLat = puntos.first.lat!;
    double maxLat = puntos.first.lat!;
    double minLng = puntos.first.lng!;
    double maxLng = puntos.first.lng!;

    for (final p in puntos) {
      if (p.lat! < minLat) minLat = p.lat!;
      if (p.lat! > maxLat) maxLat = p.lat!;
      if (p.lng! < minLng) minLng = p.lng!;
      if (p.lng! > maxLng) maxLng = p.lng!;
    }
    if (_ubicacionActual != null) {
      if (_ubicacionActual!.lat < minLat) minLat = _ubicacionActual!.lat;
      if (_ubicacionActual!.lat > maxLat) maxLat = _ubicacionActual!.lat;
      if (_ubicacionActual!.lng < minLng) minLng = _ubicacionActual!.lng;
      if (_ubicacionActual!.lng > maxLng) maxLng = _ubicacionActual!.lng;
    }

    final bounds = LatLngBounds(
      LatLng(minLat - 0.005, minLng - 0.005),
      LatLng(maxLat + 0.005, maxLng + 0.005),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  /// Obtiene la ubicación actual del asesor (funciona en Web con permiso del navegador).
  Future<void> _obtenerMiUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _mostrarSnack('Permiso de ubicación denegado');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() => _ubicacionActual = GeoPoint(pos.latitude, pos.longitude));
      _mapController.move(
        LatLng(pos.latitude, pos.longitude),
        15.0,
      );
    } catch (e) {
      _mostrarSnack('No se pudo obtener la ubicación: $e');
    } finally {
      setState(() => _buscandoUbicacion = false);
    }
  }

  void _mostrarSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<CarteraItem> _puntosConUbicacion() =>
      widget.items.where((e) => e.tieneUbicacion).toList();

  // ── Builders de capas del mapa ───────────────────────────────────────────────

  /// Polyline de la ruta optimizada (azul 4px).
  List<Polyline> _buildPolylines() {
    if (widget.rutaOrdenada.length < 2) return [];
    final puntos = <LatLng>[];
    if (_ubicacionActual != null) {
      puntos.add(LatLng(_ubicacionActual!.lat, _ubicacionActual!.lng));
    }
    for (final c in widget.rutaOrdenada) {
      if (c.tieneUbicacion) puntos.add(LatLng(c.lat!, c.lng!));
    }
    return [
      Polyline(
        points: puntos,
        color: const Color(0xFF1565C0),
        strokeWidth: 4.0,
        borderColor: Colors.white.withValues(alpha: 0.4),
        borderStrokeWidth: 1.5,
      ),
    ];
  }

  /// Marcadores de clientes + asesor.
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final puntos = _puntosConUbicacion();

    // Número de orden en la ruta
    final ordenMap = <String, int>{};
    for (var i = 0; i < widget.rutaOrdenada.length; i++) {
      ordenMap[widget.rutaOrdenada[i].id] = i + 1;
    }

    for (final c in puntos) {
      final color = _colorPorEstado(c);
      final orden = ordenMap[c.id];
      final isSelected = _clienteSeleccionado?.id == c.id;

      markers.add(
        Marker(
          point: LatLng(c.lat!, c.lng!),
          width: isSelected ? 52 : 44,
          height: isSelected ? 52 : 44,
          child: GestureDetector(
            onTap: () => setState(() {
              _clienteSeleccionado = (_clienteSeleccionado?.id == c.id) ? null : c;
            }),
            child: _ClienteMarker(
              color: color,
              orden: orden,
              isSelected: isSelected,
            ),
          ),
        ),
      );
    }

    // Marcador del asesor
    if (_ubicacionActual != null) {
      markers.add(
        Marker(
          point: LatLng(_ubicacionActual!.lat, _ubicacionActual!.lng),
          width: 48,
          height: 48,
          child: const _AsesorMarker(),
        ),
      );
    }

    return markers;
  }

  // ── Build principal ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final puntos = _puntosConUbicacion();

    if (puntos.isEmpty) {
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Sin clientes con ubicación.\nRecarga la cartera desde el menú.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // ── Mapa ────────────────────────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              // Mapa OpenStreetMap
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(GeoPoint.lima.lat, GeoPoint.lima.lng),
                  initialZoom: 13.0,
                  minZoom: 5.0,
                  maxZoom: 18.0,
                  onTap: (_, __) => setState(() => _clienteSeleccionado = null),
                ),
                children: [
                  // Capa de tiles OpenStreetMap
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 's11_app_flutter_fventas',
                    maxZoom: 18,
                    tileProvider: NetworkTileProvider(),
                  ),
                  // Ruta optimizada (polyline)
                  PolylineLayer(polylines: _buildPolylines()),
                  // Marcadores de clientes y asesor
                  MarkerLayer(markers: _buildMarkers()),
                  // Atribución OSM (requerida por la licencia)
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),

              // ── Popup del cliente seleccionado ───────────────────────────────
              if (_clienteSeleccionado != null)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _ClientePopup(
                    cliente: _clienteSeleccionado!,
                    onClose: () => setState(() => _clienteSeleccionado = null),
                  ),
                ),

              // ── Leyenda de colores ───────────────────────────────────────────
              Positioned(
                bottom: 36,
                left: 12,
                child: _Leyenda(),
              ),

              // ── FABs: Mi ubicación + Recentrar ──────────────────────────────
              Positioned(
                bottom: 36,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recentrar ruta
                    if (puntos.isNotEmpty)
                      FloatingActionButton.small(
                        heroTag: 'fab_recentrar',
                        tooltip: 'Recentrar ruta',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        onPressed: _recentrarRuta,
                        child: const Icon(Icons.fit_screen),
                      ),
                    const SizedBox(height: 8),
                    // Mi ubicación
                    FloatingActionButton.small(
                      heroTag: 'fab_ubicacion',
                      tooltip: 'Mi ubicación',
                      backgroundColor: _ubicacionActual != null
                          ? const Color(0xFF1565C0)
                          : Colors.white,
                      foregroundColor: _ubicacionActual != null
                          ? Colors.white
                          : AppColors.primary,
                      onPressed: _buscandoUbicacion ? null : _obtenerMiUbicacion,
                      child: _buscandoUbicacion
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Panel lateral — Orden de visita ─────────────────────────────────────
        Expanded(
          flex: 2,
          child: _PanelOrdenVisita(
            rutaOrdenada: widget.rutaOrdenada,
            onTapCliente: (c) {
              setState(() => _clienteSeleccionado = c);
              _mapController.move(LatLng(c.lat!, c.lng!), 16.0);
            },
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

/// Pin de cliente con número de orden opcional.
class _ClienteMarker extends StatelessWidget {
  final Color color;
  final int? orden;
  final bool isSelected;

  const _ClienteMarker({
    required this.color,
    this.orden,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 52.0 : 44.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: isSelected ? 3.0 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: orden != null
            ? Text(
                '$orden',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Icon(Icons.person_pin_circle, color: Colors.white, size: 22),
      ),
    );
  }
}

/// Marcador especial para la posición del asesor.
class _AsesorMarker extends StatelessWidget {
  const _AsesorMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x661565C0),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.navigation, color: Colors.white, size: 26),
    );
  }
}

/// Card de información del cliente seleccionado.
class _ClientePopup extends StatelessWidget {
  final CarteraItem cliente;
  final VoidCallback onClose;

  const _ClientePopup({required this.cliente, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final color = _colorPorEstado(cliente);
    final estado = _etiquetaEstado(cliente);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cliente.clienteNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _PopupRow(
              icon: Icons.badge_outlined,
              label: 'Código',
              value: cliente.clienteId,
            ),
            _PopupRow(
              icon: Icons.label_outline,
              label: 'Estado',
              value: estado,
              valueColor: color,
            ),
            _PopupRow(
              icon: Icons.flag_outlined,
              label: 'Prioridad',
              value: cliente.prioridad.toUpperCase(),
            ),
            _PopupRow(
              icon: Icons.attach_money,
              label: 'Monto crédito',
              value: 'S/ ${cliente.montoCredito.toStringAsFixed(2)}',
            ),
            _PopupRow(
              icon: Icons.checklist,
              label: 'Visita',
              value: cliente.visitado ? 'Completada ✓' : 'Pendiente',
              valueColor: cliente.visitado
                  ? const Color(0xFF2E7D32)
                  : Colors.orange.shade800,
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _PopupRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Leyenda de colores del mapa.
class _Leyenda extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (Color(0xFF2E7D32), 'Vigente'),
      (Color(0xFFF9A825), 'Vencido / Nuevo'),
      (Color(0xFFC62828), 'En mora'),
      (Color(0xFF1565C0), 'Visitado'),
    ];

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e.$1,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(e.$2, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Panel inferior — Lista de orden de visita.
class _PanelOrdenVisita extends StatelessWidget {
  final List<CarteraItem> rutaOrdenada;
  final void Function(CarteraItem) onTapCliente;

  const _PanelOrdenVisita({
    required this.rutaOrdenada,
    required this.onTapCliente,
  });

  @override
  Widget build(BuildContext context) {
    if (rutaOrdenada.isEmpty) {
      return Container(
        color: const Color(0xFFF5F5F5),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route, size: 36, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Presiona "Optimizar ruta" para\ncalcular el orden de visitas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.route, size: 18, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Text(
                  'Orden de visita — ${rutaOrdenada.length} clientes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: rutaOrdenada.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final c = rutaOrdenada[i];
                final color = _colorPorEstado(c);
                return InkWell(
                  onTap: () => onTapCliente(c),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Número de orden
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info del cliente
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.clienteNombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _etiquetaEstado(c),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Monto
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'S/ ${c.montoCredito.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
