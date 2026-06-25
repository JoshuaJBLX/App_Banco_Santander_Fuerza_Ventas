/// Textos y etiquetas centralizados.
///
/// Mantener los literales aqui facilita el branding por entidad y futuras
/// traducciones. Agrupados por modulo.
class AppStrings {
  AppStrings._();

  // App / marca
  static const String appName =
      'Banco Santander Consumer Perú - Fuerza de Ventas';
  static const String entidad = 'Banco Santander Consumer Perú';

  // Auth (M0)
  static const String loginTitle = 'Iniciar sesión';
  static const String loginSubtitle =
      'Acceso del asesor · ingresa con tu código';
  static const String codigoEmpleado = 'Código de empleado';
  static const String password = 'Contraseña';
  static const String ingresar = 'Ingresar';
  static const String recordarme = 'Recordarme';
  static const String olvidoPassword = '¿Olvidó su contraseña?';
  static const String olvidoPasswordMensaje =
      'Las cuentas son administradas por tu agencia. Comunícate con el '
      'Administrador de tu agencia para restablecer tu contraseña.';
  static const String problemasIngresar = 'Problemas para ingresar';
  static const String cerrarSesion = 'Cerrar sesión';
  static const String cerrarSesionConfirmar = '¿Cerrar de todas formas?';
  static const String bloqueoIntentos =
      'Demasiados intentos fallidos. Intenta de nuevo en';

  // Cartera (M1)
  static const String carteraTitle = 'Mi cartera del día';
  static const String actualizar = 'Actualizar';
  static const String sinClientes = 'No hay clientes en tu cartera hoy.';
  static const String buscarCliente = 'Buscar por nombre o documento';
  static const String ultimaActualizacion = 'Última actualización';

  // Offline
  static const String modoOffline = 'Modo offline — mostrando datos en caché';
  static const String sinSincronizar = 'solicitudes sin sincronizar';

  // Generico
  static const String reintentar = 'Reintentar';
  static const String cancelar = 'Cancelar';
  static const String aceptar = 'Aceptar';
  static const String errorGenerico = 'Ocurrió un error. Intenta nuevamente.';
}
