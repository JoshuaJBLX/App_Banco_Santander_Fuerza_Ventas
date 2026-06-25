import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/logo_santander_consumer.dart';
import '../../auth/presentation/login_viewmodel.dart';

/// Splash + pantalla de carga de Banco Santander Consumer Perú.
/// El logo gira mientras un anillo de progreso avanza de 0 a 100%.
/// Al completar, navega al dashboard (si hay sesion) o al login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _giro; // rotacion continua del logo
  late final AnimationController _carga; // progreso 0 -> 1

  @override
  void initState() {
    super.initState();
    _giro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _carga = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _continuar();
      });
    _carga.forward();
  }

  void _continuar() {
    if (!mounted) return;
    final autenticado =
        ref.read(loginViewModelProvider).status == AuthStatus.authenticated;
    context.go(autenticado ? '/cartera' : '/login');
  }

  @override
  void dispose() {
    _giro.dispose();
    _carga.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.brandGradient,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo girando dentro del anillo de progreso
              AnimatedBuilder(
                animation: Listenable.merge([_giro, _carga]),
                builder: (context, _) {
                  return SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: _carga.value,
                            strokeWidth: 5,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                        Transform.rotate(
                          angle: _giro.value * 6.28318, // 2*pi
                          child: const LogoSantanderConsumerPeru(size: 88),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              const Text(
                AppStrings.entidad,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fuerza de Ventas',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _carga,
                builder: (context, _) => Text(
                  '${(_carga.value * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cargando...',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
