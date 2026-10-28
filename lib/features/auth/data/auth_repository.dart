import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  static final Future<void> _googleSignInInitialization =
      GoogleSignIn.instance.initialize();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    }
  }

  Future<User> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();

      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('No se pudo obtener la sesión creada.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return _requireUser(
          await _firebaseAuth.signInWithPopup(GoogleAuthProvider()),
        );
      }

      await _googleSignInInitialization;
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthException(
          'El inicio de sesión con Google no está disponible en esta plataforma.',
        );
      }
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Google no devolvió un token válido. Revisa la configuración OAuth.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      return _requireUser(await _firebaseAuth.signInWithCredential(credential));
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthException(
        e.description ??
            'No se pudo iniciar sesión con Google. Verifica la configuración OAuth.',
      );
    } on PlatformException catch (e) {
      throw AuthException(
        e.message ??
            'No se pudo iniciar sesión con Google. Verifica la configuración OAuth.',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignInInitialization;
    await GoogleSignIn.instance.signOut();
  }

  User _requireUser(UserCredential credential) {
    final user = credential.user;
    if (user == null) {
      throw const AuthException('Firebase no devolvió una sesión válida.');
    }
    return user;
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'invalid-email':
        return 'El formato del correo electrónico es inválido.';
      case 'user-disabled':
        return 'Esta cuenta se encuentra deshabilitada.';
      case 'operation-not-allowed':
        return 'Este método de inicio de sesión no está habilitado.';
      case 'network-request-failed':
        return 'No se pudo conectar. Revisa tu conexión a Internet.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      default:
        return e.message ?? 'Ocurrió un error de autenticación.';
    }
  }
}
