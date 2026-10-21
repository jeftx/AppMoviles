import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthMode { login, register }
enum AuthStatus { initial, submitting, googleSubmitting, success, error }

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
    bool clearErrorMessage = false,
  }) {
    return LoginState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginState());

  static final Future<void> _googleSignInInitialization =
      GoogleSignIn.instance.initialize();

  void toggleMode() {
    final newMode =
        state.mode == AuthMode.login ? AuthMode.register : AuthMode.login;
    emit(
      state.copyWith(
        mode: newMode,
        status: AuthStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> submit(String email, String password, [String? name]) async {
    emit(
      state.copyWith(
        status: AuthStatus.submitting,
        clearErrorMessage: true,
      ),
    );

    try {
      if (name == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } else {
        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await userCredential.user?.updateDisplayName(name.trim());
      }

      emit(
        state.copyWith(
          status: AuthStatus.success,
          clearErrorMessage: true,
        ),
      );
    } on FirebaseAuthException catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: _emailAuthErrorMessage(error),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'No fue posible iniciar sesión. Inténtalo de nuevo.',
        ),
      );
    }
  }

  String _emailAuthErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'El correo electrónico no es válido.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'Correo o contraseña incorrectos.',
      'user-disabled' => 'Esta cuenta ha sido deshabilitada.',
      'email-already-in-use' => 'Ya existe una cuenta con este correo.',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
      'operation-not-allowed' =>
        'El acceso con correo y contraseña no está habilitado.',
      _ => error.message ?? 'No fue posible iniciar sesión. Inténtalo de nuevo.',
    };
  }

  Future<void> signInWithGoogle() async {
    emit(
      state.copyWith(
        status: AuthStatus.googleSubmitting,
        clearErrorMessage: true,
      ),
    );

    try {
      await _googleSignInInitialization;

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw UnsupportedError(
          'El inicio de sesión con Google no está disponible en esta plataforma.',
        );
      }

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw StateError('No se pudo obtener el token de Google.');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      emit(
        state.copyWith(
          status: AuthStatus.success,
          clearErrorMessage: true,
        ),
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        emit(state.copyWith(status: AuthStatus.initial));
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                error.description ?? 'No fue posible iniciar sesión con Google.',
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              error.message ?? 'No fue posible iniciar sesión con Google.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'No fue posible iniciar sesión con Google.',
        ),
      );
    }
  }
}
