import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'text_utils.dart';

/// Firebase identity-provider and phone-verification operations used by the EURO sign-in flow.
class FirebaseIdentityService {
  FirebaseIdentityService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> createEmailAccount(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> signInWithGoogle() {
    return _auth.signInWithProvider(OAuthProvider('google.com'));
  }

  Future<UserCredential> signInWithApple() {
    final OAuthProvider provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithProvider(provider);
  }

  /// Returns the Firebase verification ID after requesting an SMS to an E.164 phone number.
  Future<String> requestPhoneCode(String rawPhone) async {
    final String phone = _toE164(rawPhone);
    if (phone.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-phone-number', message: 'أدخل رقم هاتف دولي صحيحاً.');
    }
    final Completer<String> completer = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        // Keep manual entry as the deterministic path; Android may still deliver codeSent.
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );
    return completer.future;
  }

  /// Links the verified phone to the currently authenticated email / Google / Apple identity.
  Future<UserCredential> linkVerifiedPhone({
    required String verificationId,
    required String smsCode,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'انتهت جلسة التحقق. أعد تسجيل الدخول.');
    }
    final String? existingPhone = user.phoneNumber;
    if (existingPhone != null && existingPhone.isNotEmpty) {
      return UserCredential(user: user, additionalUserInfo: null, credential: null);
    }
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: toWesternDigits(smsCode).trim(),
    );
    return user.linkWithCredential(credential);
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

  static String _toE164(String raw) {
    String digits = toWesternDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('963')) return '+$digits';
    if (digits.startsWith('0')) return '+963${digits.substring(1)}';
    if (digits.length == 9 && digits.startsWith('9')) return '+963$digits';
    return '';
  }
}
