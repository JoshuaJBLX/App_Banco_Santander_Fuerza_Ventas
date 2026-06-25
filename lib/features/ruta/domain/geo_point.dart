import '../../cartera/domain/cartera_model.dart';

/// Punto geografico simple (independiente de google_maps_flutter).
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  static const lima = GeoPoint(-12.0464, -77.0428);

  static GeoPoint? fromItem(CarteraItem c) =>
      c.tieneUbicacion ? GeoPoint(c.lat!, c.lng!) : null;
}
