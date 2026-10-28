// Sign-in: workshop or marketer, phone number and password (POST /api/auth, client "mobile").

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onRegister});

  final VoidCallback onRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  String _role = 'workshop';
  bool _busy = false;
  String? _error;
  String? _pendingMessage;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final AppState state = AppScope.read(context);
    final String phone = _phone.text.trim();
    final String password = _password.text;
    if (phone.isEmpty || password.length < 4) {
      setState(() {
        _error = 'يرجى إدخال رقم الموبايل وكلمة مرور من 4 أحرف على الأقل';
        _pendingMessage = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    state.dismissSessionNotice();
    setState(() {
      _busy = true;
      _error = null;
      _pendingMessage = null;
    });

    final AuthResult result = await state.login(role: _role, phone: phone, password: password);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (result.isPending) {
        _pendingMessage = result.message;
      } else if (!result.isSignedIn) {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final String? notice = state.sessionNotice;
    final String? error = _error;
    final String? pending = _pendingMessage;
    final bool workshop = _role == 'workshop';

    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthHeader(),
            const SizedBox(height: 20),
            AuthModeSwitch(
              registering: false,
              onLogin: null,
              onRegister: _busy ? null : widget.onRegister,
            ),
            const SizedBox(height: 18),
            if (notice != null) ...<Widget>[
              NoticeBanner(
                message: notice,
                kind: NoticeKind.warning,
                onDismiss: state.dismissSessionNotice,
              ),
              const SizedBox(height: 14),
            ],
            RoleSelector(
              role: _role,
              registering: false,
              onChanged: (String value) => setState(() {
                _role = value;
                _error = null;
                _pendingMessage = null;
              }),
            ),
            const SizedBox(height: 16),
            AuthFormCard(
              title: workshop ? 'تسجيل دخول ورشة / شركة' : 'تسجيل دخول عميل / مسوّق',
              children: <Widget>[
                AppTextField(
                  controller: _phone,
                  label: 'رقم الموبايل',
                  hint: '09XXXXXXXX',
                  icon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  ltr: true,
                  radius: 10,
                  autofillHints: const <String>[AutofillHints.telephoneNumber],
                  onSubmitted: (String _) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  label: 'كلمة المرور',
                  textInputAction: TextInputAction.done,
                  radius: 10,
                  autofillHints: const <String>[AutofillHints.password],
                  onSubmitted: (String _) => _submit(),
                  focusNode: _passwordFocus,
                ),
                if (pending != null) ...<Widget>[
                  const SizedBox(height: 16),
                  PendingApprovalCard(message: pending),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  flat: true,
                  label: workshop ? 'تسجيل دخول الورشة / الشركة' : 'تسجيل دخول المسوّق',
                  busy: _busy,
                  onPressed: _submit,
                ),
                if (_busy) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'قد يستغرق الاتصال الأول حتى دقيقة إذا كان الخادم في وضع السكون.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
                  ),
                ],
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  AuthMessage(text: error),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'ليس لديك حساب؟',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 14),
            ),
            TextButton(
              onPressed: _busy ? null : widget.onRegister,
              child: const Text(
                'إنشاء حساب جديد',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'يلزم حساب مسجّل ومفعّل من إدارة EURO CARS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
