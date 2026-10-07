import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/login_bloc.dart';
import '../widgets/login_form.dart'; // Importamos el widget separado

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is LoginLoadingState;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: SingleChildScrollView(
                child: LoginForm(
                  emailController: emailController,
                  passwordController: passwordController,
                  isLoading: isLoading,
                  onLoginPressed: () {
                    // Disparamos el evento hacia el BLoC
                    BlocProvider.of<LoginBloc>(context).add(
                      LoginSubmittedEvent(
                        email: emailController.text,
                        password: passwordController.text,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}