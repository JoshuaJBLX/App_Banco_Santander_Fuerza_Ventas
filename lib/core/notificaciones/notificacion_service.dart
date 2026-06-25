import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Servicio de notificaciones locales (M10/RF-78).
class NotificacionService {
  NotificacionService._();
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _canal = AndroidNotificationDetails(
    'compromisos',
    'Compromisos de pago',
    channelDescription: 'Alertas de compromisos de pago de cobranza',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _canalCartera = AndroidNotificationDetails(
    'cartera',
    'Sincronizacion de cartera',
    channelDescription: 'Aviso al completar la descarga nocturna de cartera',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> init() async {
    if (kIsWeb) return;
    // Zona horaria para programar alertas con zonedSchedule (RF-78).
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Lima'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    // Permiso de notificaciones (Android 13+).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Notificacion local al completar la sincronizacion nocturna (RF-14).
  static Future<void> carteraLista(int clientes) async {
    if (kIsWeb) return;
    await _plugin.show(
      777001,
      'Tu cartera de manana esta lista',
      '$clientes cliente(s) cargados. Toca para abrir tu cartera.',
      const NotificationDetails(android: _canalCartera),
    );
  }

  /// Programa la alerta de un compromiso de pago para su fecha (RF-78).
  /// La notificacion se dispara a las 09:00 del dia acordado. Si la fecha ya
  /// paso o es hoy, se muestra de inmediato.
  static Future<void> programarCompromiso({
    required int id,
    required String cliente,
    required double monto,
    required DateTime fecha,
  }) async {
    final cuerpo =
        'Cobrar S/ ${monto.toStringAsFixed(2)} a $cliente (compromiso de hoy).';
    final cuando =
        tz.TZDateTime(tz.local, fecha.year, fecha.month, fecha.day, 9);
    if (!cuando.isAfter(tz.TZDateTime.now(tz.local))) {
      await alertaCompromiso(
          cliente: cliente,
          monto: monto,
          fecha: fecha.toIso8601String().substring(0, 10));
      return;
    }
    await _plugin.zonedSchedule(
      id,
      'Compromiso de pago hoy',
      cuerpo,
      cuando,
      const NotificationDetails(android: _canal),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Alerta de compromiso de pago. En produccion se programaria con
  /// zonedSchedule para la fecha acordada; aqui se muestra al registrar.
  static Future<void> alertaCompromiso({
    required String cliente,
    required double monto,
    String? fecha,
  }) async {
    final cuerpo = 'Compromiso de S/ ${monto.toStringAsFixed(2)}'
        '${fecha != null ? ' para el $fecha' : ''} — $cliente';
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Compromiso de pago registrado',
      cuerpo,
      const NotificationDetails(android: _canal),
    );
  }
}
