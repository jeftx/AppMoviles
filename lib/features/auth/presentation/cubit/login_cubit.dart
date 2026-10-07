import 'package:flutter_bloc/flutter_bloc.dart';

enum AuthMode { login, register }
enum AuthStatus { initial, submitting, success, error }

class LoginState {
  final AuthMode mode;
  final AuthStatus status;
  final String? errorMessage;

  const LoginState({
    this.mode = AuthMode.login,
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  LoginState copyWith({
    AuthMode? mode,
    AuthStatus? status,
    String? errorMessage,
  }) {
    return LoginState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class LoginCubit extends Cubit<LoginState> {
  // Aquí inyectarías los Casos de Uso (ej: final SignInWithEmail signInWithEmail;)
  LoginCubit() : super(const LoginState());

  void toggleMode() {
    final newMode = state.mode == AuthMode.login ? AuthMode.register : AuthMode.login;
    emit(state.copyWith(mode: newMode, status: AuthStatus.initial));
  }

  Future<void> submit(String email, String password, [String? name]) async {
    emit(state.copyWith(status: AuthStatus.submitting));
    
    // Simulación de llamada al repositorio a través del caso de uso
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulación de éxito
    emit(state.copyWith(status: AuthStatus.success));
  }
}