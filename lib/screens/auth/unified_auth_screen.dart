import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/firebase_identity.dart';
import '../../core/models.dart';
import '../../core/referral.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/inputs.dart';
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
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _license = TextEditingController();
  final _city = TextEditingController(text: defaultGovernorate);
  final _spec = TextEditingController(text: 'Mercedes-Benz');
  final _referral = TextEditingController();
  final _otp = TextEditingController();
  String? _customerOtpToken;

  _Mode _mode = _Mode.welcome;
  String _role = 'workshop';
  String? _error;
  String? _notice;
  String? _pending;
  bool _busy = false;
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
    for (final controller in [_phone, _oldPassword, _password, _name, _license, _city, _spec, _referral, _otp]) {
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
      _firebaseAttemptStarted = false;
    });
  }

  String _firebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'بيانات الدخول غير صحيحة.';
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
    final String? message = await openForgotPassword(context, role: _role, phone: _phone.text.trim());
    if (message != null && mounted) setState(() { _notice = message; _error = null; });
  }

  Future<void> _legacyLogin() async {
    if (_phone.text.trim().isEmpty || _oldPassword.text.length < minLoginPasswordLength || _busy) {
      setState(() => _error = 'أدخل رقم الهاتف وكلمة المرور القديمة.');
      return;
    }
    setState(() { _busy = true; _error = null; _pending = null; });
    final result = await AppScope.read(context).login(role: _role, phone: _phone.text.trim(), password: _oldPassword.text);
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

  Future<void> _sendRegistrationOtp() async {
    if (_busy) return;
    if (_phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
      setState(() => _error = 'أدخل رقم هاتف صحيحاً لإرسال رمز التحقق.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      final token = await AppScope.read(context).requestRegistrationOtp(phone: _phone.text, role: _role);
      if (!mounted) return;
      if (token.isEmpty) {
        setState(() { _busy = false; _error = 'تعذر إرسال رمز التحقق. خدمة الرسائل غير مفعّلة حالياً.'; });
        return;
      }
      setState(() {
        _busy = false;
        _customerOtpToken = token;
        _notice = 'تم إرسال رمز التحقق إلى هاتفك. أدخله لإكمال إنشاء الحساب.';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() { _busy = false; _error = error.message; });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = unexpectedMessage; });
    }
  }

  Future<void> _registerPhoneAccount() async {
    if (_busy) return;
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'أدخل اسمك الكامل.');
      return;
    }
    if (_phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
      setState(() => _error = 'أدخل رقم هاتف صحيحاً.');
      return;
    }
    if (_password.text.length < minNewPasswordLength) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.');
      return;
    }
    if (_customerOtpToken == null || _otp.text.trim().length != 6) {
      setState(() => _error = 'أرسل رمز SMS وأدخل الرمز المكوّن من 6 أرقام.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    final AppState state = AppScope.read(context);
    final ReferralInput referral = _signedReferral ?? parseReferral(_referral.text);
    final AuthResult result;
    if (_registrationFromLogin) {
      try {
        result = await state.registerFirebase(
          idToken: await _firebase.freshIdToken(),
          role: _role,
          name: _name.text,
          phone: _phone.text,
          password: _password.text,
          otpCode: _otp.text,
          otpToken: _customerOtpToken!,
          license: _license.text,
          manualVerification: _role == 'workshop' && _license.text.trim().isEmpty,
          city: _city.text,
          specs: _spec.text,
          refCode: referral.code,
          refSignature: referral.signature,
        );
      } catch (error) {
        if (mounted) setState(() { _busy = false; _error = error is ApiException ? error.message : unexpectedMessage; });
        return;
      }
    } else {
      result = await state.register(
        role: _role,
        name: _name.text,
        phone: _phone.text,
        password: _password.text,
        otpCode: _otp.text,
        otpToken: _customerOtpToken!,
        license: _license.text,
        manualVerification: _role == 'workshop' && _license.text.trim().isEmpty,
        city: _city.text,
        specs: _spec.text,
        refCode: referral.code,
        refSignature: referral.signature,
      );
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

  Future<void> _authenticate(String provider) async {
    if (_busy) return;
    if (_mode == _Mode.register && (_role == 'workshop' || _role == 'marketer') &&
        _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
      setState(() => _error = _role == 'workshop' ? 'رقم هاتف الورشة إلزامي، أدخل رقماً صحيحاً للتواصل معك.' : 'رقم الهاتف إلزامي لإنشاء هذا الحساب.');
      return;
    }
    if (_mode == _Mode.register && _name.text.trim().length < 2) {
      setState(() => _error = 'أدخل اسمك الكامل.');
      return;
    }
    if (_mode == _Mode.register && _role != 'customer' && _password.text.length < minNewPasswordLength) {
      setState(() => _error = 'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.');
      return;
    }
    if (_mode == _Mode.register && _role != 'customer' &&
        (_customerOtpToken == null || _otp.text.trim().length != 6)) {
      setState(() => _error = 'أرسل رمز التحقق وأدخله قبل إكمال التسجيل.');
      return;
    }

    setState(() { _busy = true; _error = null; _pending = null; });
    try {
      if (!_firebaseAttemptStarted) {
        if (_firebase.currentUser != null) await _firebase.signOut();
        if (provider == 'google') {
          await _firebase.signInWithGoogle();
        } else {
          await _firebase.signInWithApple();
        }
        _firebaseAttemptStarted = true;
      }

      if (_firebase.currentUser == null) {
        throw FirebaseAuthException(code: 'no-current-user');
      }
      developer.log('stage=screen_firebase_id_token_start', name: 'EURO_AUTH_DIAG');
      final String idToken = await _firebase.freshIdToken();
      developer.log('stage=screen_firebase_id_token_success', name: 'EURO_AUTH_DIAG');
      if (!mounted) return;
      final AppState state = AppScope.read(context);
      final AuthResult result;

      if (_mode == _Mode.register || _registrationFromLogin) {
        final referral = _signedReferral ?? parseReferral(_referral.text);
        developer.log('stage=screen_register_firebase_start role=$_role',
            name: 'EURO_AUTH_DIAG');
        result = await state.registerFirebase(
          idToken: idToken,
          role: _role,
          name: _name.text,
          phone: (_role == 'workshop' || _role == 'customer' || _role == 'marketer') ? _phone.text : '',
          password: _password.text,
          otpCode: _otp.text,
          otpToken: _customerOtpToken ?? '',
          license: _license.text,
          manualVerification: _role == 'workshop' && _license.text.trim().isEmpty,
          city: _city.text,
          specs: _spec.text,
          refCode: referral.code,
          refSignature: referral.signature,
        );
        developer.log('stage=screen_register_firebase_returned kind=${result.kind.name}',
            name: 'EURO_AUTH_DIAG');
      } else {
        final login = await state.exchangeFirebaseIdentity(idToken: idToken);
        if (login.needsRegistration) {
          if (mounted) {
            _name.text = _firebase.currentUser?.displayName ?? _name.text;
            setState(() {
              _mode = _Mode.register;
              _registrationFromLogin = true;
              _busy = false;
              _notice = 'تم التحقق من هويتك. أكمل بيانات حساب EURO من النوع المحدد.';
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
    } on FirebaseAuthException catch (error) {
      developer.log('stage=screen_firebase_exception code=${error.code}',
          name: 'EURO_AUTH_DIAG');
      if (mounted) setState(() { _busy = false; _error = _firebaseError(error); });
    } catch (error) {
      developer.log('stage=screen_unexpected_exception type=${error.runtimeType}',
          name: 'EURO_AUTH_DIAG');
      if (mounted) setState(() { _busy = false; _error = error is ApiException ? error.message : unexpectedMessage; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Semantics(
            image: true,
            label: 'شعار Euro Parts',
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'branding/icon_1024.png',
                  width: 82,
                  height: 82,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text('Euro Parts', textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          if (_mode == _Mode.welcome)
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.16)
          else
            const SizedBox(height: 22),
          if (_mode == _Mode.welcome) _welcome(),
          if (_mode == _Mode.login) _login(),
          if (_mode == _Mode.register) _register(p),
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
          Text('Euro Parts • قطع غيار السيارات الأوروبية', textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 11)),
        ],
      ),
    );
  }

  void _selectAccountType(String role) {
    if (_busy) return;
    setState(() {
      _role = role;
      _mode = _Mode.login;
      _error = null;
      _notice = null;
      _pending = null;
    });
  }

  Widget _welcome() => AuthFormCard(
    title: 'أهلاً بك في Euro Parts',
    children: [
      const Text('اختر نوع حسابك للمتابعة', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _selectAccountType('workshop'),
        icon: const Icon(Icons.business_rounded),
        label: const Text('شركة / ورشة'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _selectAccountType('marketer'),
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('مسوّق'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _selectAccountType('customer'),
        icon: const Icon(Icons.person_rounded),
        label: const Text('عميل'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: AppScope.read(context).startGuestSession,
        icon: const Icon(Icons.storefront_outlined),
        label: const Text('متابعة كضيف — تصفح الكتالوج فقط'),
      ),
    ],
  );

  String get _accountTypeLabel => switch (_role) {
    'workshop' => 'شركة / ورشة',
    'marketer' => 'مسوّق',
    'customer' => 'عميل',
    _ => 'حساب',
  };

  Widget _accountTypeBadge() => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_outlined, size: 17, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 7),
        Text('نوع الحساب: $_accountTypeLabel',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    ),
  );

  Widget _login() => AuthFormCard(
    title: 'أهلاً بعودتك',
    children: [
      _accountTypeBadge(),
      const SizedBox(height: 12),
      const Text('سجّل الدخول برقم الهاتف وكلمة المرور، أو باستخدام Google.', textAlign: TextAlign.center),
      const SizedBox(height: 10),
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
      const SizedBox(height: 8),
      _socialProviders(),
      TextButton(onPressed: _busy ? null : () => _modeTo(_Mode.register),
          child: const Text('ليس لديك حساب؟ إنشاء حساب جديد')),
    ],
  );

  Widget _register(Palette p) => AuthFormCard(
    title: _registrationFromLogin ? 'إكمال إنشاء الحساب' : 'إنشاء حساب جديد',
    children: [
      _accountTypeBadge(),
      const SizedBox(height: 12),
      if (_role == 'customer') ...[
        const Text('أنشئ حساب العميل باستخدام Google. رقم الهاتف اختياري ويمكن إضافته لاحقاً من بيانات الحساب.', textAlign: TextAlign.center),
        const SizedBox(height: 14),
        AppTextField(controller: _name, label: 'الاسم الكامل', radius: 10),
        const SizedBox(height: 8),
        _socialProviders(),
      ] else ...[
        const Text('أدخل بيانات الحساب ورقم الهاتف، ثم تحقق من ملكية الرقم عبر رمز SMS.', textAlign: TextAlign.center),
        const SizedBox(height: 14),
        AppTextField(controller: _name, label: 'الاسم الكامل', radius: 10),
        const SizedBox(height: 8),
        AppTextField(controller: _phone, label: 'رقم الهاتف', hint: '+963 9XXXXXXXX',
            keyboardType: TextInputType.phone, ltr: true, radius: 10),
        const SizedBox(height: 8),
        PasswordField(controller: _password, label: 'كلمة المرور (8 أحرف على الأقل)', radius: 10),
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
          AppTextField(controller: _spec, label: 'اختصاص الورشة / الماركات', radius: 10),
          Text('يمكن إكمال بيانات الورشة لاحقاً بعد إرسال الطلب.', style: TextStyle(color: p.muted, fontSize: 12)),
          const SizedBox(height: 8),
          AppTextField(controller: _referral, label: 'كود المسوّق (اختياري)',
              readOnly: _signedReferral?.isSigned == true, ltr: true, radius: 10),
        ],
        const SizedBox(height: 8),
        AppTextField(controller: _otp, label: 'رمز التحقق SMS', hint: '6 أرقام',
            keyboardType: TextInputType.number, ltr: true, radius: 10),
        const SizedBox(height: 8),
        SecondaryButton(
          label: _customerOtpToken == null ? 'إرسال رمز التحقق' : 'إعادة إرسال رمز التحقق',
          icon: Icons.sms_outlined,
          onPressed: _busy ? null : _sendRegistrationOtp,
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'إنشاء حساب', icon: Icons.person_add_alt_1_rounded,
            busy: _busy, onPressed: _registerPhoneAccount),
        const SizedBox(height: 8),
        _socialProviders(),
      ],
      TextButton(onPressed: _busy ? null : () => _modeTo(_Mode.login), child: const Text('لديك حساب؟ تسجيل الدخول')),
    ],
  );

  Widget _socialProviders() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(onPressed: _busy ? null : () => _authenticate('google'),
          icon: const Icon(Icons.g_mobiledata_rounded, size: 25), label: Text(_mode == _Mode.register ? 'التسجيل باستخدام Google' : 'تسجيل الدخول باستخدام Google')),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 7),
            Text('هذه الخدمة ستتوفر قريباً',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      const SizedBox(height: 6),
      OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.apple_rounded, size: 21),
          label: const Text('المتابعة باستخدام Apple')),
    ],
  );
}
