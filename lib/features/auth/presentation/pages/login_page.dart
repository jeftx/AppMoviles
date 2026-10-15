// lib/features/auth/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/login_cubit.dart';
import '../widgets/login_brand_header.dart';
import '../widgets/email_auth_divider.dart';
import '../widgets/google_sign_in_button.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(),
      child: const _LoginView(),
    );
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

  // Diálogo para solicitar el correo y recuperar la contraseña
  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailController = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Recuperar contraseña', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Correo electrónico'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  Navigator.pop(dialogContext);
                  final error =
                      await context.read<LoginCubit>().resetPassword(email);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error ??
                            'Si existe una cuenta con ese correo, recibirás un enlace de recuperación.',
                      ),
                      backgroundColor: error == null ? null : Colors.redAccent,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un correo válido'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state.status == AuthStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Ocurrió un error'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          final isRegister = state.mode == AuthMode.register;
          final isLoading = state.status == AuthStatus.submitting;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.primary.withOpacity(0.12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const LoginBrandHeader(),
                          const SizedBox(height: 24),
                          
                          // --- BOTÓN CONTINUAR CON GOOGLE ---
                          GestureDetector(
                            onTap: isLoading ? null : () => context.read<LoginCubit>().signInWithGoogle(),
                            child: const GoogleSignInButton(),
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
                                if (isRegister) ...[
                                  TextFormField(
                                    controller: _nameCtrl,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(hintText: 'Nombre completo'),
                                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(hintText: 'Correo electrónico'),
                                  validator: (v) => v!.contains('@') ? null : 'Correo inválido',
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    hintText: 'Contraseña',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                                ),

                                // --- RECUPERAR CONTRASEÑA ---
                                if (!isRegister)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: isLoading ? null : () => _showForgotPasswordDialog(context),
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

                                // --- BOTÓN PRINCIPAL (Iniciar sesión / Crear cuenta) ---
                                Container(
                                  height: 56,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    boxShadow: [AppTheme.globalShadow],
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.primaryDark,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    onPressed: isLoading ? null : () => _submitForm(context, state),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 24, width: 24,
                                            child: CircularProgressIndicator(
                                              color: AppColors.primaryDark,
                                              strokeWidth: 2,
                                            ))
                                        : Text(
                                            isRegister ? 'Crear cuenta' : 'Iniciar sesión',
                                            style: GoogleFonts.nunito(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // --- CAMBIAR MODO (Iniciar sesión / Crear una cuenta) ---
                          TextButton(
                            onPressed: isLoading ? null : () => context.read<LoginCubit>().toggleMode(),
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
