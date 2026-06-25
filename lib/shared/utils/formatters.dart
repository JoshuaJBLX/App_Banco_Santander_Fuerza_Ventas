import 'package:intl/intl.dart';

/// Formato de moneda, fechas y documentos. Usado en toda la app para
/// presentar montos en soles, fechas legibles y documentos censurados.
class Formatters {
  Formatters._();

  static final NumberFormat _soles = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
  );

  static final DateFormat _fecha = DateFormat('dd/MM/yyyy', 'es');
  static final DateFormat _fechaHora = DateFormat('dd/MM/yyyy HH:mm', 'es');

  /// `S/ 12,000.00`
  static String soles(num monto) => _soles.format(monto);

  static String fecha(DateTime d) => _fecha.format(d);
  static String fechaHora(DateTime d) => _fechaHora.format(d);

  /// Censura un documento mostrando solo los ultimos 3 digitos: `***456`.
  static String documentoCensurado(String doc) {
    if (doc.length <= 3) return doc;
    return '***${doc.substring(doc.length - 3)}';
  }

  /// Etiqueta legible para un tipo de gestion de cartera.
  static String tipoGestionLabel(String tipo) {
    switch (tipo) {
      case 'RENOVACION':
        return 'Renovacion';
      case 'AMPLIACION':
        return 'Ampliacion';
      case 'NUEVA_SOLICITUD':
        return 'Nueva solicitud';
      case 'SEGUIMIENTO':
        return 'Seguimiento';
      case 'RECUPERACION_MORA':
        return 'Recuperacion mora';
      case 'DESERTOR':
        return 'Desertor';
      default:
        return tipo;
    }
  }
}
