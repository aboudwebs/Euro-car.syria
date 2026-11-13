// Forgot password. The project has no e-mail addresses and no Supabase Auth: the account is the phone number, so the
// recovery message goes to WhatsApp (the channel that already delivers the sign-up code).
//
//   step 1: account type + phone  ->  POST /api/password-reset/user {mode: request}
//   step 2: 6-digit code + new password  ->  {mode: confirm}
//
// The first step answers with the same text whether or not the number is registered, so the screen never reveals
// who has an account.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/inputs.dart';
import 'auth_widgets.dart';
import '../../widgets/tx.dart';

/// Opens the recovery screen. Returns the success message when the password was changed (the sign-in screen shows
/// it), or null when the user left.
Future<String?> openForgotPassword(BuildContext context, {String role = 'workshop', String phone = ''}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (BuildContext routeContext) => ForgotPasswordScreen(initialRole: role, initialPhone: phone),
    ),
  );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialRole = 'workshop', this.initialPhone = ''});

  final String initialRole;
  final String initialPhone;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _phone = TextEditingController(text: widget.initialPhone);
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  late String _role = widget.initialRole;
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy) {
      return;
    }
    final String phone = _phone.text.trim();
    if (phone.length < 8) {
      setState(() => _error = 'أدخل رقم الموبايل المسجل في حسابك.');
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String message = await state.requestPasswordReset(role: _role, phone: phone);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _codeStep = true;
        _info = message;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = unexpectedMessage;
        });
      }
    }
  }

  Future<void> _confirmReset() async {
    if (_busy) {
      return;
    }
    final String code = _code.text.trim();
    final String password = _password.text;
    if (code.length != 6) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }
    if (password.length < minNewPasswordLength) {
      setState(() => _error = 'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String message = await state.confirmPasswordReset(
        role: _role,
        phone: _phone.text,
        code: code,
        newPassword: password,
      );
      if (mounted) {
        Navigator.of(context).pop(message);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = unexpectedMessage;
        });
      }
    }
  }

  void _backToPhone() {
    setState(() {
      _codeStep = false;
      _error = null;
      _info = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String? error = _error;
    final String? info = _info;
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'نسيت كلمة المرور؟'),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (!_codeStep) ...<Widget>[
                      RoleSelector(
                        role: _role,
                        registering: false,
                        onChanged: (String value) => setState(() {
                          _role = value;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AuthFormCard(
                      title: _codeStep ? 'أدخل الرمز وكلمة المرور الجديدة' : 'استعادة كلمة المرور عبر واتساب',
                      children: <Widget>[
                        if (!_codeStep) ...<Widget>[
                          Text(
                            'اكتب رقم الموبايل المسجل في حسابك. سنرسل رمز تحقق من 6 أرقام إلى واتساب على هذا الرقم.',
                            style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.6),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _phone,
                            label: 'رقم الموبايل',
                            hint: '09XXXXXXXX',
                            icon: Icons.phone_iphone_rounded,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            ltr: true,
                            radius: 10,
                            onSubmitted: (String _) => _sendCode(),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            flat: true,
                            label: 'إرسال رمز التحقق',
                            icon: Icons.send_rounded,
                            busy: _busy,
                            onPressed: _sendCode,
                          ),
                        ] else ...<Widget>[
                          if (info != null) ...<Widget>[
                            AuthMessage(text: info, success: true),
                            const SizedBox(height: 14),
                          ],
                          AppTextField(
                            controller: _code,
                            label: 'رمز التحقق (6 أرقام)',
                            icon: Icons.pin_outlined,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            maxLength: 6,
                            ltr: true,
                            radius: 10,
                            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            controller: _password,
                            label: 'كلمة المرور الجديدة',
                            textInputAction: TextInputAction.next,
                            radius: 10,
                            autofillHints: const <String>[AutofillHints.newPassword],
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            controller: _confirm,
                            label: 'تأكيد كلمة المرور',
                            textInputAction: TextInputAction.done,
                            radius: 10,
                            onSubmitted: (String _) => _confirmReset(),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            flat: true,
                            label: 'تغيير كلمة المرور',
                            icon: Icons.lock_reset_rounded,
                            busy: _busy,
                            onPressed: _confirmReset,
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _busy ? null : _backToPhone,
                            child: const Text('لم يصلني الرمز؟ أعد الإرسال أو غيّر الرقم'),
                          ),
                        ],
                        if (error != null) ...<Widget>[
                          const SizedBox(height: 12),
                          AuthMessage(text: error),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
