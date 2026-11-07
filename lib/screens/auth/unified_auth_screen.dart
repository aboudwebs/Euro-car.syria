import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/firebase_identity.dart';
import '../../core/models.dart';
import '../../core/referral.dart';
import '../../core/text_utils.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/inputs.dart';
import '../../widgets/part_plate.dart';
import '../../widgets/tx.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';

class UnifiedAuthScreen extends StatefulWidget {
  const UnifiedAuthScreen({super.key, this.initialReferral});
  final ReferralInput? initialReferral;

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

enum _Mode { welcome, login, register }

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> {
  late final FirebaseIdentityService _firebase = FirebaseIdentityService();
  final _phone = TextEditingController();
  final _oldPassword = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _license = TextEditingController();
  final _city = TextEditingController(text: defaultGovernorate);
  final _spec = TextEditingController(text: 'Mercedes-Benz');
  final _referral = TextEditingController();
  final _sms = TextEditingController();

  _Mode _mode = _Mode.welcome;
  String _role = 'workshop';
  String? _otpToken;
  String? _verifiedOtpCode;
  String? _error;
  String? _notice;
  String? _pending;
  bool _busy = false;
  bool _identityReady = false;
  bool _firebaseAttemptStarted = false;
  bool _registrationFromLogin = false;
  ReferralInput? _signedReferral;

  @override
  void initState() {
    super.initState();
    final referral = widget.initialReferral;
    if (referral?.isSigned == true) {
      _signedReferral = referral;
      _referral.text = referral!.code;
      _mode = _Mode.register;
    }
  }

  @override
  void dispose() {
    for (final controller in [_phone, _oldPassword, _email, _password, _name, _license, _city, _spec, _referral, _sms]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _modeTo(_Mode mode) async {
    if (_busy) return;
    final bool hasFirebaseIdentity = _firebase.currentUser != null;
    if (hasFirebaseIdentity) {
      setState(() => _busy = true);
      try {
        await _firebase.signOut();
      } catch (_) {
        // A stale Firebase session must not be reused across a different auth flow.
      }
      if (!mounted) return;
    }
    setState(() {
      _busy = false;
      _mode = mode;
      _error = null;
      _notice = null;
      _pending = null;
      _registrationFromLogin = false;
      _identityReady = false;
      _firebaseAttemptStarted = false;
      _otpToken = null;
      _verifiedOtpCode = null;
      _sms.clear();
    });
  }

  String _firebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'بيانات الدخول غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد مسجل مسبقاً. انتقل إلى تسجيل الدخول.';
      case 'weak-password':
        return 'كلمة المرور يجب أن تتكون من 6 أحرف على الأقل.';
      case 'credential-already-in-use':
        return 'رقم الهاتف مرتبط بهوية أخرى. تواصل مع الدعم لربط الحساب بأمان.';
      case 'invalid-phone-number':
        return 'أدخل رقم هاتف سوري صحيحاً مع رمز الدولة.';
      case 'too-many-requests':
        return 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.';
      case 'operation-not-allowed':
        return error.message?.trim().isNotEmpty == true ? error.message! : 'طريقة الدخول غير مفعّلة في إعدادات Firebase.';
      default:
        return error.message?.trim().isNotEmpty == true ? error.message! : 'تعذر إكمال التحقق من الهوية.';
    }
  }

  Future<void> _forgotOldPassword() async {
    final String? message = await openForgotPassword(context, phone: _phone.text.trim());
    if (message != null && mounted) setState(() { _notice = message; _error = null; });
  }

  Future<void> _legacyLogin() async {
    if (_phone.text.trim().isEmpty || _oldPassword.text.length < 4 || _busy) {
      setState(() => _error = 'أدخل رقم الهاتف وكلمة المرور القديمة.');
      return;
    }
    setState(() { _busy = true; _error = null; _pending = null; });
    final result = await AppScope.read(context).login(phone: _phone.text.trim(), password: _oldPassword.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _identityReady = result.isPending || result.isSignedIn;
      if (result.isPending) {
        _pending = result.message;
      } else if (!result.isSignedIn) {
        _error = result.message;
      }
    });
  }

  Future<void> _authenticate(String provider) async {
    if (_busy) return;
    if (_mode == _Mode.register && _name.text.trim().length < 2) {
      setState(() => _error = 'أدخل الاسم الكامل قبل إنشاء الحساب.');
      return;
    }
    if (provider == 'email' && (_email.text.trim().isEmpty || _password.text.length < 6)) {
      setState(() => _error = 'أدخل البريد وكلمة مرور من 6 أحرف على الأقل.');
      return;
    }
    if (_mode == _Mode.register && _role == 'workshop' && _spec.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اختصاص الورشة.');
      return;
    }

    setState(() { _busy = true; _error = null; _pending = null; });
    try {
      if (!_identityReady && !_firebaseAttemptStarted) {
        if (_firebase.currentUser != null) await _firebase.signOut();
        if (provider == 'email') {
          if (_mode == _Mode.register) {
            await _firebase.createEmailAccount(_email.text, _password.text);
          } else {
            await _firebase.signInWithEmail(_email.text, _password.text);
          }
        } else if (provider == 'google') {
          await _firebase.signInWithGoogle();
        } else {
          await _firebase.signInWithApple();
        }
        _firebaseAttemptStarted = true;
      }

      final user = _firebase.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'no-current-user');
      if (_identityReady && _verifiedOtpCode != null && _otpToken != null) {
        await _submitIdentity(otpCode: _verifiedOtpCode!, otpToken: _otpToken!);
        return;
      }
      if (_phone.text.trim().isEmpty) {
        if (mounted) setState(() { _busy = false; _error = 'أدخل رقم الهاتف الذي تريد توثيقه عبر واتساب.'; });
        return;
      }
      final otpToken = await AppScope.read(context).requestRegistrationOtp(phone: _phone.text);
      if (!mounted) return;
      setState(() {
        _otpToken = otpToken;
        _busy = false;
        _notice = 'أرسلنا رمز التحقق إلى واتساب. أدخله لإكمال توثيق الهاتف.';
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() { _busy = false; _error = _firebaseError(error); });
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = error is ApiException ? error.message : unexpectedMessage; });
    }
  }

  Future<void> _confirmPhone() async {
    final otpToken = _otpToken;
    if (_busy || otpToken == null) return;
    if (toWesternDigits(_sms.text).trim().length != 6) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _submitIdentity(otpCode: _sms.text, otpToken: otpToken);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() { _busy = false; _error = _firebaseError(error); });
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = error is ApiException ? error.message : unexpectedMessage; });
    }
  }

  Future<void> _submitIdentity({required String otpCode, required String otpToken}) async {
    final AppState state = AppScope.read(context);
    final String token = await _firebase.freshIdToken();
    final AuthResult result;
    if (_mode == _Mode.register || _registrationFromLogin) {
      final referral = _signedReferral ?? parseReferral(_referral.text);
      result = await state.registerFirebase(
        idToken: token,
        role: _role,
        name: _name.text,
        phone: _phone.text,
        otpCode: otpCode,
        otpToken: otpToken,
        license: _license.text,
        manualVerification: _role == 'workshop' && _license.text.trim().isEmpty,
        city: _city.text,
        specs: _spec.text,
        refCode: referral.code,
        refSignature: referral.signature,
      );
    } else {
      final login = await state.exchangeFirebaseIdentity(idToken: token, phone: _phone.text, otpCode: otpCode, otpToken: otpToken);
      if (login.needsRegistration) {
        if (mounted) {
          setState(() {
            _mode = _Mode.register;
            _registrationFromLogin = true;
            _identityReady = true;
            _verifiedOtpCode = otpCode;
            _busy = false;
            _notice = 'تم توثيق هويتك ورقم هاتفك. أكمل البيانات لإنشاء حساب EURO.';
          });
        }
        return;
      }
      result = login;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isPending) {
        _pending = result.message;
      } else if (!result.isSignedIn) {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const BrandMark(size: 54),
          const SizedBox(height: 5),
          Text('قطع غيار السيارات الأوروبية', textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 22),
          if (_mode == _Mode.welcome) _welcome(),
          if (_mode == _Mode.login) _login(),
          if (_mode == _Mode.register) _register(p),
          if (_otpToken != null && !_identityReady) _otp(p),
          if (_pending != null) ...[
            const SizedBox(height: 12),
            PendingApprovalCard(message: _pending!, onBack: () => _modeTo(_Mode.login)),
          ],
          if (_notice != null) ...[const SizedBox(height: 10), AuthMessage(text: _notice!, success: true)],
          if (_error != null) ...[const SizedBox(height: 10), AuthMessage(text: _error!)],
          if (_busy) ...[
            const SizedBox(height: 14),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            Text('جارٍ التحقق من الحساب...', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          ],
          if (_mode != _Mode.welcome)
            TextButton(onPressed: _busy ? null : () => _modeTo(_Mode.welcome), child: const Text('العودة للبداية')),
          const SizedBox(height: 8),
          Text('EURO CARS • قطع غيار السيارات الأوروبية', textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _welcome() => AuthFormCard(
    title: 'أهلاً بك في اليورو',
    children: [
      const Text('اختر طريقة المتابعة', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      PrimaryButton(label: 'تسجيل الدخول', icon: Icons.login_rounded, onPressed: () => _modeTo(_Mode.login)),
      const SizedBox(height: 10),
      SecondaryButton(label: 'إنشاء حساب جديد', icon: Icons.person_add_alt_1_rounded, onPressed: () => _modeTo(_Mode.register)),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: AppScope.read(context).startGuestSession,
        icon: const Icon(Icons.storefront_outlined),
        label: const Text('متابعة كضيف — تصفح الكتالوج فقط'),
      ),
    ],
  );

  Widget _login() => AuthFormCard(
    title: 'أهلاً بعودتك',
    children: [
      AppTextField(controller: _phone, label: 'رقم الهاتف',
          hint: '+963 9XXXXXXXX', keyboardType: TextInputType.phone, ltr: true, radius: 10),
      const SizedBox(height: 8),
      PasswordField(controller: _oldPassword, label: 'كلمة المرور', radius: 10),
      const SizedBox(height: 10),
      PrimaryButton(label: 'تسجيل الدخول', busy: _busy, onPressed: _legacyLogin),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(onPressed: _busy ? null : _forgotOldPassword, child: const Text('نسيت كلمة المرور؟')),
      ),
      const Divider(height: 22),
      AppTextField(controller: _email, label: 'البريد الإلكتروني', keyboardType: TextInputType.emailAddress,
          ltr: true, radius: 10),
      const SizedBox(height: 8),
      PasswordField(controller: _password, label: 'كلمة المرور', radius: 10),
      const SizedBox(height: 10),
      const SizedBox(height: 8),
      _providers(),
      TextButton(onPressed: _busy ? null : () => _modeTo(_Mode.register),
          child: const Text('ليس لديك حساب؟ إنشاء حساب جديد')),
    ],
  );

  Widget _register(Palette p) => AuthFormCard(
    title: _registrationFromLogin ? 'أكمل بياناتك' : 'حساب جديد',
    children: [
      RoleSelector(role: _role, registering: true,
          onChanged: (value) { if (!_busy) setState(() { _role = value; _error = null; }); }),
      const SizedBox(height: 12),
      AppTextField(controller: _name, label: _role == 'workshop' ? 'اسم الورشة أو الشركة' : 'الاسم الكامل',
          maxLength: 100, radius: 10),
      const SizedBox(height: 8),
      AppTextField(controller: _phone, label: 'رقم الهاتف', hint: '+963 9XXXXXXXX',
          keyboardType: TextInputType.phone, ltr: true, readOnly: _otpToken != null, radius: 10),
      const SizedBox(height: 8),
      AppTextField(controller: _email, label: 'البريد الإلكتروني (اختياري مع Google / Apple)',
          keyboardType: TextInputType.emailAddress, ltr: true, radius: 10),
      const SizedBox(height: 8),
      PasswordField(controller: _password, label: 'كلمة مرور البريد (للدخول بالبريد فقط)', radius: 10),
      if (_role == 'workshop') ...[
        const SizedBox(height: 8),
        AppTextField(controller: _license, label: 'السجل التجاري / ترخيص الورشة (اختياري)', radius: 10),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _city.text,
          decoration: const InputDecoration(labelText: 'المحافظة'),
          items: governorates.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
          onChanged: (value) { if (!_busy && value != null) setState(() => _city.text = value); },
        ),
        const SizedBox(height: 8),
        AppTextField(controller: _spec, label: 'اختصاص الورشة / الماركات', hint: 'Mercedes-Benz, BMW', radius: 10),
        const SizedBox(height: 8),
        Text('إذا لم يتوفر الترخيص، يبقى الطلب قيد المراجعة حتى تتحقق الإدارة من الهوية.',
            style: TextStyle(color: p.muted, fontSize: 12)),
        const SizedBox(height: 8),
        AppTextField(controller: _referral, label: 'كود المسوّق (اختياري)',
            readOnly: _signedReferral?.isSigned == true, ltr: true, radius: 10),
      ],
      const SizedBox(height: 14),
      _providers(),
      TextButton(onPressed: _busy ? null : () => _modeTo(_Mode.login), child: const Text('لديك حساب؟ تسجيل الدخول')),
    ],
  );

  Widget _otp(Palette p) => AuthFormCard(
    title: 'توثيق رقم الهاتف',
    children: [
      Text('أدخل رمز واتساب الذي وصل إلى رقمك. لن نطلب الرمز في كل تسجيل دخول لاحق.',
          textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
      const SizedBox(height: 10),
      AppTextField(controller: _sms, label: 'رمز واتساب', hint: '000000',
          keyboardType: TextInputType.number, ltr: true, maxLength: 6, radius: 10),
      const SizedBox(height: 10),
      PrimaryButton(label: 'تأكيد الهاتف والمتابعة', busy: _busy, onPressed: _confirmPhone),
    ],
  );

  Widget _providers() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SecondaryButton(label: _mode == _Mode.register ? 'المتابعة بالبريد الإلكتروني' : 'الدخول بالبريد الإلكتروني',
          icon: Icons.email_outlined, onPressed: _busy ? null : () => _authenticate('email')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _busy ? null : () => _authenticate('google'),
          icon: const Icon(Icons.g_mobiledata_rounded, size: 25), label: const Text('المتابعة باستخدام Google')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _busy ? null : () => _authenticate('apple'),
          icon: const Icon(Icons.apple_rounded, size: 21), label: const Text('المتابعة باستخدام Apple')),
    ],
  );
}
