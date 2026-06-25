import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alertas/presentation/alertas_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/login_viewmodel.dart';
import '../features/campanas/presentation/campanas_screen.dart';
import '../features/buro/presentation/buro_screen.dart';
import '../features/cartera/presentation/cartera_screen.dart';
import '../features/cobranza/presentation/cobranza_screen.dart';
import '../features/documentos/presentation/documentos_screen.dart';
import '../features/estado_solicitudes/presentation/estado_screen.dart';
import '../features/ficha_cliente/presentation/ficha_screen.dart';
import '../features/reportes/presentation/reportes_screen.dart';
import '../features/preevaluacion/presentation/desertor_screen.dart';
import '../features/preevaluacion/presentation/preeval_screen.dart';
import '../features/ruta/presentation/ruta_screen.dart';
import '../features/solicitud/presentation/borradores_screen.dart';
import '../features/solicitud/presentation/documentos_solicitud_screen.dart';
import '../features/solicitud/presentation/historial_screen.dart';
import '../features/solicitud/presentation/simulador_screen.dart';
import '../features/solicitud/presentation/solicitud_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/transmision/presentation/transmision_screen.dart';

/// Navegacion declarativa con rutas nombradas (GoRouter).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') return null; // el splash decide su navegacion
      final autenticado =
          ref.read(loginViewModelProvider).status == AuthStatus.authenticated;
      final enLogin = loc == '/login';
      if (!autenticado && !enLogin) return '/login';
      if (autenticado && enLogin) return '/cartera';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/cartera', builder: (_, __) => const CarteraScreen()),
      GoRoute(path: '/ruta', builder: (_, __) => const RutaScreen()),
      GoRoute(path: '/alertas', builder: (_, __) => const AlertasScreen()),
      GoRoute(path: '/campanas', builder: (_, __) => const CampanasScreen()),
      GoRoute(
        path: '/ficha',
        builder: (_, __) => const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Selecciona un cliente desde Cartera para ver su ficha.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/ficha/:clienteId',
        builder: (_, state) => FichaScreen(
          clienteId: state.pathParameters['clienteId']!,
          carteraId: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/solicitud',
        builder: (_, state) =>
            SolicitudScreen(args: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
          path: '/borradores', builder: (_, __) => const BorradoresScreen()),
      GoRoute(path: '/simulador', builder: (_, __) => const SimuladorScreen()),
      GoRoute(path: '/historial', builder: (_, __) => const HistorialScreen()),
      GoRoute(
        path: '/transmision',
        builder: (_, state) =>
            TransmisionScreen(datos: state.extra as Map<String, dynamic>),
      ),
      GoRoute(
          path: '/documentos', builder: (_, __) => const DocumentosScreen()),
      GoRoute(path: '/buro', builder: (_, __) => const BuroScreen()),
      GoRoute(
          path: '/preevaluacion',
          builder: (_, __) => const PreEvalScreen()),
      GoRoute(path: '/desertor', builder: (_, __) => const DesertorScreen()),
      GoRoute(path: '/estado', builder: (_, __) => const EstadoScreen()),
      GoRoute(
        path: '/documentos-solicitud',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return DocumentosSolicitudScreen(
            solicitudId: args['solicitudId'] as String? ?? '',
            numeroExpediente: args['numeroExpediente'] as String? ?? '',
            clienteNombre: args['clienteNombre'] as String? ?? '',
          );
        },
      ),
      GoRoute(path: '/cobranza', builder: (_, __) => const CobranzaScreen()),
      GoRoute(path: '/reportes', builder: (_, __) => const ReportesScreen()),
    ],
  );
});
