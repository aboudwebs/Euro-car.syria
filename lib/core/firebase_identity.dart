import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'config.dart';

/// Firebase identity-provider and phone-verification operations used by the EURO sign-in flow.
class FirebaseIdentityService {
  static Future<void>? _googleInitialization;
  FirebaseIdentityService({FirebaseAuth? auth}) : _providedAuth = auth;

  final FirebaseAuth? _providedAuth;

  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty && _providedAuth == null) {
      throw FirebaseAuthException(
        code: 'no-app',
        message: 'إعداد Firebase غير مكتمل على هذا الجهاز.',
      );
    }
    return _providedAuth ?? FirebaseAuth.instance;
  }

  User? get currentUser {
    if (Firebase.apps.isEmpty && _providedAuth == null) return null;
    return _auth.currentUser;
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> createEmailAccount(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (googleServerClientId.isEmpty) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'إعداد Google OAuth غير مكتمل. يلزم إضافة Web client ID إلى إعدادات البناء.',
      );
    }
    _googleInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId,
    );
    await _googleInitialization;
    final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential', message: 'لم يرجع Google رمز هوية صالحاً.');
    }
    final OAuthCredential credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() {
    final OAuthProvider provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithProvider(provider);
  }

  Future<String> freshIdToken() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'تعذر استكمال تسجيل الدخول.');
    }
    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-user-token', message: 'تعذر التحقق من الهوية.');
    }
    return token;
  }

  Future<void> signOut() => _auth.signOut();

}
