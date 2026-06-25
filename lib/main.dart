import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notificaciones/notificacion_service.dart';
import 'core/storage/database_init.dart';
import 'core/sync/sync_nocturna.dart';
import 'features/auth/presentation/login_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initLocalDatabase();

  if (!kIsWeb) {
    try {
      await NotificacionService.init();
    } catch (_) {/* notificaciones opcionales */}
    try {
      await SyncNocturna.init();
    } catch (_) {/* background opcional */}
  }

  final container = ProviderContainer();
  // Restaura sesion persistente (token + asesor) antes de pintar (RF-03).
  await container.read(loginViewModelProvider.notifier).restaurarSesion();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
