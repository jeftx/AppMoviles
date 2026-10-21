// lib/features/auth/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../home_screen.dart';
import '../cubit/login_cubit.dart';
// Asumiendo que exportas los widgets arriba
import '../widgets/login_brand_header.dart';
import '../widgets/email_auth_divider.dart';
import '../widgets/google_sign_in_button.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => LoginCubit(), child: const _LoginView());
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submitForm(BuildContext context, LoginState state) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoginCubit>().submit(
        _emailCtrl.text,
        _passCtrl.text,
        state.mode == AuthMode.register ? _nameCtrl.text : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state.status == AuthStatus.success) {
            PushNotificationService.requestPermissionAndRegister();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          } else if (state.status == AuthStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          final isRegister = state.mode == AuthMode.register;
          final isEmailLoading = state.status == AuthStatus.submitting;
          final isGoogleLoading = state.status == AuthStatus.googleSubmitting;
          final isLoading = isEmailLoading || isGoogleLoading;

          return Container(
            // Fondo degradado: 25% primary a background
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.background,
                  AppColors.background,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const LoginBrandHeader(),
                          const SizedBox(height: 24),

                          GoogleSignInButton(
                            isLoading: isGoogleLoading,
                            onPressed: () =>
                                context.read<LoginCubit>().signInWithGoogle(),
                          ),
                          const SizedBox(height: 24),

                          const EmailAuthDivider(),
                          const SizedBox(height: 24),

                          // --- FORMULARIO ---
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // CAMPO NOMBRE (Solo en Registro)
                                if (isRegister) ...[
                                  TextFormField(
                                    controller: _nameCtrl,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'Nombre completo',
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Requerido' : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // CAMPO CORREO
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    hintText: 'Correo electrónico',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (v) => v!.contains('@')
                                      ? null
                                      : 'Correo inválido',
                                ),
                                const SizedBox(height: 12),

                                // CAMPO CONTRASEÑA
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    hintText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => v!.length < 6
                                      ? 'Mínimo 6 caracteres'
                                      : null,
                                ),

                                // RECUPERAR CONTRASEÑA (Solo en Login)
                                if (!isRegister)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {},
                                      child: Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 24),

                                // --- BOTÓN PRINCIPAL ---
                                SizedBox(
                                  height: 58,
                                  width: double.infinity,
                                  child: Material(
                                    color: isLoading
                                        ? const Color(0xFFF0B5CC)
                                              .withValues(alpha: .55)
                                        : const Color(0xFFF0B5CC),
                                    borderRadius: BorderRadius.circular(30),
                                    child: InkWell(
                                      onTap: isLoading
                                          ? null
                                          : () => _submitForm(context, state),
                                      borderRadius: BorderRadius.circular(30),
                                      child: Center(
                                        child: isEmailLoading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color:
                                                          AppColors.primaryDark,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Text(
                                                isRegister
                                                    ? 'Crear cuenta'
                                                    : 'Iniciar sesión',
                                                style: GoogleFonts.quicksand(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // --- CAMBIAR MODO ---
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => context.read<LoginCubit>().toggleMode(),
                            child: Text(
                              isRegister
                                  ? '¿Ya tienes cuenta? Inicia sesión'
                                  : '¿No tienes cuenta? Crear una cuenta',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: AppColors.textMain,
                                fontWeight: FontWeight.w400,
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
        },
      ),
    );
  }
}
