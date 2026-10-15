import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/auth_repository.dart';

enum AuthMode { login, register }
enum AuthStatus { initial, submitting, success, error }

class LoginState {
  const LoginState({
    this.mode = AuthMode.login,
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  final AuthMode mode;
  final AuthStatus status;
  final String? errorMessage;

  LoginState copyWith({
    AuthMode? mode,
    AuthStatus? status,
    Object? errorMessage = _notProvided,
  }) {
    return LoginState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _notProvided = Object();

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository(),
        super(const LoginState());

  final AuthRepository _authRepository;

  void toggleMode() {
    final newMode = state.mode == AuthMode.login
        ? AuthMode.register
        : AuthMode.login;
    emit(state.copyWith(
      mode: newMode,
      status: AuthStatus.initial,
      errorMessage: null,
    ));
  }

  Future<void> submit(String email, String password, [String? name]) async {
    emit(state.copyWith(status: AuthStatus.submitting, errorMessage: null));

    try {
      if (state.mode == AuthMode.login) {
        await _authRepository.signInWithEmailAndPassword(email, password);
      } else {
        await _authRepository.registerWithEmailAndPassword(
          email,
          password,
          name ?? '',
        );
      }
      if (!isClosed) {
        emit(state.copyWith(status: AuthStatus.success, errorMessage: null));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: _errorMessage(e),
        ));
      }
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(status: AuthStatus.submitting, errorMessage: null));

    try {
      await _authRepository.signInWithGoogle();
      if (!isClosed) {
        emit(state.copyWith(status: AuthStatus.success, errorMessage: null));
      }
    } on AuthCancelledException {
      if (!isClosed) {
        emit(state.copyWith(status: AuthStatus.initial, errorMessage: null));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: _errorMessage(e),
        ));
      }
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      return _errorMessage(e);
    }
  }

  String _errorMessage(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }
}

