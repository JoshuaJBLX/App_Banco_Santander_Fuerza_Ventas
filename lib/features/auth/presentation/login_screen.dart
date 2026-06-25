import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/logo_santander_consumer.dart';
import '../data/auth_repository.dart';
import 'login_viewmodel.dart';

/// Formulario de login del asesor (RF-01) con branding Banco Santander Consumer Perú.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _verPassword = false;
  bool _recordar = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _cargarUsuarioRecordado();
    // Carga el bloqueo persistido (RF-04) y arranca la cuenta regresiva visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loginViewModelProvider.notifier).cargarEstadoBloqueo();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _cargarUsuarioRecordado() async {
    final codigo = await ref.read(authRepositoryProvider).usuarioRecordado();
    if (codigo != null && mounted) {
      setState(() {
        _codigoCtrl.text = codigo;
        _recordar = true;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final codigo = _codigoCtrl.text.trim();
    await ref
        .read(authRepositoryProvider)
        .recordarUsuario(_recordar ? codigo : null);
    await ref
        .read(loginViewModelProvider.notifier)
        .login(codigo, _passCtrl.text);
  }

  /// Formatea una duracion como mm:ss para la cuenta regresiva (RF-04).
  String _mmss(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final m = total.inMinutes.toString().padLeft(2, '0');
    final s = (total.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _olvidoPassword() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.olvidoPassword),
        content: const Text(AppStrings.olvidoPasswordMensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.aceptar),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginViewModelProvider);

    ref.listen(loginViewModelProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) context.go('/cartera');
    });

    final cargando = state.status == AuthStatus.loading;
    final bloqueado = state.estaBloqueado;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.brandGradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const LogoSantanderConsumerPeru(size: 104),
                    const SizedBox(height: 12),
                    const Text(
                      AppStrings.entidad,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Fuerza de Ventas',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _Tarjeta(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              AppStrings.loginTitle,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              AppStrings.loginSubtitle,
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _codigoCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              enabled: !cargando && !bloqueado,
                              decoration: const InputDecoration(
                                labelText: AppStrings.codigoEmpleado,
                                hintText: 'Ej. 0001',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: Validators.codigoEmpleado,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: !_verPassword,
                              enabled: !cargando && !bloqueado,
                              decoration: InputDecoration(
                                labelText: AppStrings.password,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_verPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(
                                      () => _verPassword = !_verPassword),
                                ),
                              ),
                              validator: Validators.password,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _recordar,
                                        activeColor: AppColors.primary,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (v) => setState(
                                            () => _recordar = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(AppStrings.recordarme),
                                  ],
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _olvidoPassword,
                                  child: const Text(AppStrings.olvidoPassword),
                                ),
                              ],
                            ),
                            if (state.error != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Text(state.error!,
                                    style: const TextStyle(
                                        color: AppColors.danger)),
                              ),
                            if (bloqueado)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_clock,
                                        color: AppColors.danger, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${AppStrings.bloqueoIntentos} '
                                        '${_mmss(state.tiempoRestante)}',
                                        style: const TextStyle(
                                            color: AppColors.danger),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed:
                                  (cargando || bloqueado) ? null : _submit,
                              icon: cargando
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text(AppStrings.ingresar),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Widget child;
  const _Tarjeta({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
