import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      errorMessage: errorMessage,
    );
  }
}

class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _authRepository = AuthRepository();

  LoginCubit() : super(const LoginState());

  void toggleMode() {
    final newMode = state.mode == AuthMode.login ? AuthMode.register : AuthMode.login;
    emit(state.copyWith(mode: newMode, status: AuthStatus.initial, errorMessage: null));
  }

  Future<void> submit(String email, String password, [String? name]) async {
    emit(state.copyWith(status: AuthStatus.submitting, errorMessage: null));

    try {
      if (state.mode == AuthMode.login) {
        await _authRepository.signInWithEmailAndPassword(email, password);
      } else {
        await _authRepository.registerWithEmailAndPassword(email, password, name ?? '');
      }
      
      emit(state.copyWith(status: AuthStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

Future<void> signInWithGoogle() async {
  try {
    emit(state.copyWith(status: AuthStatus.submitting));

    // 1. Dispara el flujo de inicio de sesión con Google
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    
    if (googleUser == null) {
      // El usuario canceló el inicio de sesión
      emit(state.copyWith(status: AuthStatus.initial));
      return;
    }

    // 2. Obtiene los detalles de autenticación de la solicitud de Google
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // 3. Crea una nueva credencial para Firebase
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Inicia sesión en Firebase con las credenciales de Google
    await FirebaseAuth.instance.signInWithCredential(credential);

    // 5. Si todo sale bien, cambia el estado a éxito para que navegue al HomeScreen
    emit(state.copyWith(status: AuthStatus.success));
    
  } catch (e) {
    emit(state.copyWith(
      status: AuthStatus.error,
      errorMessage: e.toString(),
    ));
  }
}

Future<void> resetPassword(String email) async {
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  } catch (e) {
    // Manejar error si es necesario
  }
}


}

