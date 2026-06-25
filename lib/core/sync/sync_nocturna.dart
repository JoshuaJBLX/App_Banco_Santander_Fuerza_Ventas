import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import '../network/api_client.dart';
import '../notificaciones/notificacion_service.dart';
import '../../features/cartera/data/cartera_local_datasource.dart';
import '../../features/cartera/data/cartera_remote_datasource.dart';

const _kTarea = 'sync_cartera_nocturna';
const _kUltimaSync = 'ultima_sync_cartera';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) => SyncNocturna.ejecutarSync());
}

/// HU-05 — Descarga automatica nocturna de la cartera (solo Android/iOS).
class SyncNocturna {
  SyncNocturna._();
  static const _storage = FlutterSecureStorage();

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e) {
      debugPrint('[sync] WorkManager init: $e');
    }
  }

  static Future<void> programar() async {
    if (kIsWeb) return;
    try {
      final ahora = DateTime.now();
      var prox = DateTime(ahora.year, ahora.month, ahora.day, 22);
      if (!prox.isAfter(ahora)) prox = prox.add(const Duration(days: 1));
      await Workmanager().registerPeriodicTask(
        _kTarea,
        _kTarea,
        frequency: const Duration(days: 1),
        initialDelay: prox.difference(ahora),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 30),
      );
    } catch (e) {
      debugPrint('[sync] programar: $e');
    }
  }

  static Future<bool> ejecutarSync() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final token = await _storage.read(key: 'auth_token');
      final asesorJson = await _storage.read(key: 'auth_asesor');
      if (token == null || asesorJson == null) return true;
      final asesorId =
          (jsonDecode(asesorJson) as Map<String, dynamic>)['id'] as String? ??
              '';

      final api = ApiClient()..setToken(token);
      final manana = DateTime.now().add(const Duration(days: 1));
      final items = await CarteraRemoteDataSource(api)
          .obtenerCartera(asesorId: asesorId, fecha: manana);

      await CarteraLocalDataSource().guardarCache(asesorId, items);
      await guardarUltimaSync();

      try {
        await NotificacionService.init();
        await NotificacionService.carteraLista(items.length);
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> guardarUltimaSync() async {
    await _storage.write(
        key: _kUltimaSync, value: DateTime.now().toIso8601String());
  }

  static Future<DateTime?> ultimaSync() async {
    final v = await _storage.read(key: _kUltimaSync);
    return v == null ? null : DateTime.tryParse(v);
  }
}

final ultimaSyncProvider =
    FutureProvider.autoDispose<DateTime?>((ref) => SyncNocturna.ultimaSync());
