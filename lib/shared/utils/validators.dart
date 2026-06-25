/// Validaciones reutilizables de formularios (login, solicitud, etc.).
/// Cada metodo devuelve `null` si es valido o un mensaje de error.
class Validators {
  Validators._();

  static String? requerido(String? v, [String campo = 'Este campo']) {
    if (v == null || v.trim().isEmpty) return '$campo es obligatorio';
    return null;
  }

  /// Codigo de empleado: solo digitos, no vacio (RF-01).
  static String? codigoEmpleado(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu código de empleado';
    if (!RegExp(r'^\d+$').hasMatch(v.trim())) {
      return 'El código debe ser numérico';
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < 4) return 'Contraseña demasiado corta';
    return null;
  }

  /// DNI peruano: 8 digitos exactos (RF-44).
  static String? dni(String? v) {
    if (v == null || v.trim().isEmpty) return 'Documento obligatorio';
    if (!RegExp(r'^\d{8}$').hasMatch(v.trim())) {
      return 'El DNI debe tener 8 dígitos';
    }
    return null;
  }

  /// Telefono: 9 digitos (RF-44).
  static String? telefono(String? v) {
    if (v == null || v.trim().isEmpty) return 'Teléfono obligatorio';
    if (!RegExp(r'^\d{9}$').hasMatch(v.trim())) {
      return 'El teléfono debe tener 9 dígitos';
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return null; // opcional
    final ok = RegExp(r'^[\w.\-]+@[\w\-]+\.[\w\-.]+$').hasMatch(v.trim());
    return ok ? null : 'Correo inválido';
  }
}
