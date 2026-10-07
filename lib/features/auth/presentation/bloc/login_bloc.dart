import 'package:flutter_bloc/flutter_bloc.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(LoginInitialState()) {
    on<LoginSubmittedEvent>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmittedEvent event,
    Emitter<LoginState> emit,
  ) async {
    // 1. Validaciones básicas de ejemplo
    if (event.email.isEmpty || event.password.isEmpty) {
      emit(LoginErrorState(message: 'Por favor completa todos los campos'));
      return;
    }

    // 2. Emitimos el estado de carga
    emit(LoginLoadingState());

    try {
      // Simulamos una petición de red (reemplaza esto con tu caso de uso / repositorio)
      await Future.delayed(const Duration(seconds: 2));

      // Ejemplo de validación simulada
      if (event.email == 'test@test.com' && event.password == '123456') {
        emit(LoginSuccessState());
      } else {
        emit(LoginErrorState(message: 'Correo o contraseña incorrectos'));
      }
    } catch (e) {
      emit(LoginErrorState(message: 'Ocurrió un error inesperado: ${e.toString()}'));
    }
  }
}