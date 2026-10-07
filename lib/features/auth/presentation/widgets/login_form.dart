import 'package:flutter/material.dart';
import 'custom_text_field.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLoginPressed;
  final bool isLoading;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onLoginPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTextField(
          label: 'Correo electrónico',
          controller: emailController,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Contraseña',
          controller: passwordController,
          isPassword: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : onLoginPressed,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Iniciar Sesión'),
          ),
        ),
      ],
    );
  }
}