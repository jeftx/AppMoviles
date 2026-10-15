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
  AuthRepository({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

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

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthCancelledException();
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw const AuthException(
          'Google no devolvió un token válido. Revisa la configuración OAuth.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return _requireUser(await _firebaseAuth.signInWithCredential(credential));
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
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
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
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
