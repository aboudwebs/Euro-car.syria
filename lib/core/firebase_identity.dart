import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'config.dart';

/// Firebase identity-provider operations used by the EURO sign-in flow.
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

  Future<UserCredential> signInWithGoogle() async {
    if (googleServerClientId.isEmpty) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'إعداد Google OAuth غير مكتمل. يلزم إضافة Web client ID إلى إعدادات البناء.',
      );
    }
    developer.log('stage=google_initialize_start', name: 'EURO_AUTH_DIAG');
    try {
      _googleInitialization ??= GoogleSignIn.instance.initialize(
        serverClientId: googleServerClientId,
      );
      await _googleInitialization;
      developer.log('stage=google_initialize_success', name: 'EURO_AUTH_DIAG');
    } catch (error) {
      developer.log('stage=google_initialize_failed type=${error.runtimeType}'
          '${error is FirebaseAuthException ? ' code=${error.code}' : ''}',
          name: 'EURO_AUTH_DIAG');
      rethrow;
    }

    developer.log('stage=google_authenticate_start', name: 'EURO_AUTH_DIAG');
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
      developer.log('stage=google_authenticate_success', name: 'EURO_AUTH_DIAG');
    } catch (error) {
      developer.log('stage=google_authenticate_failed type=${error.runtimeType}',
          name: 'EURO_AUTH_DIAG');
      rethrow;
    }
    final String? idToken = account.authentication.idToken;
    developer.log('stage=google_id_token_received present=${idToken != null && idToken.isNotEmpty}',
        name: 'EURO_AUTH_DIAG');
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential', message: 'لم يرجع Google رمز هوية صالحاً.');
    }
    final OAuthCredential credential = GoogleAuthProvider.credential(idToken: idToken);
    developer.log('stage=firebase_credential_signin_start', name: 'EURO_AUTH_DIAG');
    try {
      final UserCredential result = await _auth.signInWithCredential(credential);
      developer.log('stage=firebase_credential_signin_success', name: 'EURO_AUTH_DIAG');
      return result;
    } catch (error) {
      developer.log('stage=firebase_credential_signin_failed type=${error.runtimeType}'
          '${error is FirebaseAuthException ? ' code=${error.code}' : ''}',
          name: 'EURO_AUTH_DIAG');
      rethrow;
    }
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
    developer.log('stage=firebase_id_token_refresh_start', name: 'EURO_AUTH_DIAG');
    final String? token;
    try {
      token = await user.getIdToken(true);
      developer.log('stage=firebase_id_token_refresh_success present=${token != null && token.isNotEmpty}',
          name: 'EURO_AUTH_DIAG');
    } catch (error) {
      developer.log('stage=firebase_id_token_refresh_failed type=${error.runtimeType}'
          '${error is FirebaseAuthException ? ' code=${error.code}' : ''}',
          name: 'EURO_AUTH_DIAG');
      rethrow;
    }
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-user-token', message: 'تعذر التحقق من الهوية.');
    }
    return token;
  }

  Future<void> signOut() => _auth.signOut();

}
