import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../cartera/domain/cartera_model.dart';
import '../domain/geo_point.dart';

// ── Paleta de colores por estado (alineada con la versión Web) ────────────────

double _hueByTipoGestion(CarteraItem c) {
  if (c.visitado) return BitmapDescriptor.hueAzure; // Azul → Visitado
  switch (c.tipoGestion.toUpperCase()) {
    case 'RENOVACION':
      return BitmapDescriptor.hueGreen; // Verde → Vigente
    case 'RECUPERACION_MORA':
      return BitmapDescriptor.hueRed; // Rojo → Mora
    case 'AMPLIACION':
    case 'NUEVA_SOLICITUD':
      return BitmapDescriptor.hueYellow; // Amarillo → Vencido / Nuevo
    default:
      return BitmapDescriptor.hueViolet; // Violeta → Otros
  }
}

String _etiquetaEstado(CarteraItem c) {
  if (c.visitado) return 'Visitado ✓';
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

// ─────────────────────────────────────────────────────────────────────────────

/// Mapa Google Maps para Android/iOS/desktop nativo.
class RutaMapPanel extends StatefulWidget {
  final List<CarteraItem> items;
  final List<CarteraItem> rutaOrdenada;
  final GeoPoint? miUbicacion;
  final void Function(GoogleMapController controller)? onControllerReady;

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
  GoogleMapController? _controller;

  /// Calcula la posición inicial del mapa: asesor → primer cliente → Lima.
  CameraPosition get _posicionInicial {
    if (widget.miUbicacion != null) {
      return CameraPosition(
        target: LatLng(widget.miUbicacion!.lat, widget.miUbicacion!.lng),
        zoom: 14,
      );
    }
    final primero = widget.items.firstWhere(
      (e) => e.tieneUbicacion,
      orElse: () => widget.items.isNotEmpty ? widget.items.first : _dummy,
    );
    if (primero.tieneUbicacion) {
      return CameraPosition(
        target: LatLng(primero.lat!, primero.lng!),
        zoom: 13,
      );
    }
    return CameraPosition(
      target: LatLng(GeoPoint.lima.lat, GeoPoint.lima.lng),
      zoom: 12,
    );
  }

  // Dummy usado solo si items está vacío (no debería ocurrir).
  static final _dummy = CarteraItem(
    id: '', asesorId: '', clienteId: '', clienteNombre: '', documento: '',
    tipoGestion: '', prioridad: '', scorePrioridad: 0, montoCredito: 0,
    estadoVisita: '', ordenManual: 0, fechaAsignacion: '',
  );

  Set<Marker> _marcadores() {
    return {
      for (final c in widget.items.where((e) => e.tieneUbicacion))
        Marker(
          markerId: MarkerId(c.id),
          position: LatLng(c.lat!, c.lng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(_hueByTipoGestion(c)),
          infoWindow: InfoWindow(
            title: c.clienteNombre,
            snippet: '${_etiquetaEstado(c)} · S/ ${c.montoCredito.toStringAsFixed(0)}'
                ' · ${c.prioridad.toUpperCase()}',
          ),
        ),
    };
  }

  Set<Polyline> _polilineas() {
    if (widget.rutaOrdenada.isEmpty) return {};
    final inicio = widget.miUbicacion != null
        ? LatLng(widget.miUbicacion!.lat, widget.miUbicacion!.lng)
        : LatLng(
            widget.rutaOrdenada.first.lat!,
            widget.rutaOrdenada.first.lng!,
          );
    return {
      Polyline(
        polylineId: const PolylineId('ruta'),
        color: AppColors.primary,
        width: 4,
        points: [
          inicio,
          ...widget.rutaOrdenada.map((c) => LatLng(c.lat!, c.lng!)),
        ],
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: _posicionInicial,
      markers: _marcadores(),
      polylines: _polilineas(),
      myLocationEnabled: widget.miUbicacion != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        widget.onControllerReady?.call(c);
      },
    );
  }

  /// Anima la cámara a un punto específico (llamado desde RutaScreen).
  void animateTo(GeoPoint p, {double zoom = 15.0}) {
    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lng), zoom),
    );
  }
}
