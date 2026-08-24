import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth? _auth = (!kIsWeb && Platform.isWindows)
      ? null
      : FirebaseAuth.instance;

  // Mantém o padrão Singleton obrigatório exigido pelo seu compilador
  final GoogleSignIn? _googleSignIn = (!kIsWeb && Platform.isWindows)
      ? null
      : GoogleSignIn.instance;

  Stream<User?> get userChanges {
    if (_auth == null) return Stream.value(null);
    return _auth!.authStateChanges();
  }

  User? get currentUser => _auth?.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    if (!kIsWeb && Platform.isWindows) {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint("🔐 Login simulado com sucesso no Windows!");
      return null;
    }

    try {
      if (_googleSignIn == null || _auth == null) return null;

      // SOLUÇÃO DO ERRO: Inicializa as configurações injetando o ID do servidor na instância global antes de abrir a tela de login
      _googleSignIn!.initialize(
        serverClientId: '685505535233-5om1bqoi70sr6bik0sag6bf78deuiho6.apps.googleusercontent.com',
      );

      // Abre a interface nativa de autenticação moderna da biblioteca
      final GoogleSignInAccount? googleUser = await _googleSignIn!
          .authenticate();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken!,
      );

      return await _auth!.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_googleSignIn != null) await _googleSignIn!.signOut();
    if (_auth != null) await _auth!.signOut();
  }
}
