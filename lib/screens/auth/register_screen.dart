// Registration for workshops (needs admin approval) and marketers (active immediately).
// Same fields and rules as the web sign-up: POST /api/auth with mode "register".

import 'package:flutter/material.dart' hide Text;

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/referral.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pickers.dart';
import '../../widgets/segmented.dart';
import '../../widgets/select_field.dart';
import 'auth_widgets.dart';
import '../../widgets/tx.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _license = TextEditingController();
  final TextEditingController _otherBrand = TextEditingController();
  final TextEditingController _referral = TextEditingController();
  final TextEditingController _otpCode = TextEditingController();

  String _role = 'workshop';
  String _city = defaultGovernorate;
  final List<String> _specs = <String>['Mercedes-Benz'];
  ReferralInput? _signedReferral;
  bool _busy = false;
  bool _otpSent = false;
  String? _otpToken;
  String? _error;
  String? _pendingMessage;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _license.dispose();
    _otherBrand.dispose();
    _referral.dispose();
    _otpCode.dispose();
    super.dispose();
  }

  bool get _isWorkshop => _role == 'workshop';

  void _onReferralChanged(String value) {
    final ReferralInput parsed = parseReferral(value);
    if (parsed.isSigned) {
      // A pasted invitation link: lock the code so it cannot be edited (the server checks the signature).
      setState(() {
        _signedReferral = parsed;
        _referral.text = parsed.code;
      });
    }
  }

  void _clearReferral() {
    setState(() {
      _signedReferral = null;
      _referral.clear();
      _otpSent = false;
      _otpToken = null;
      _otpCode.clear();
    });
  }

  Future<void> _pickCity() async {
    final String? picked = await showChoiceSheet<String>(
      context: context,
      title: 'اختر المحافظة',
      options: governorates,
      labelOf: (String value) => value,
      selected: _city,
    );
    if (picked != null && mounted) {
      setState(() => _city = picked);
    }
  }

  String _specsText() {
    final List<String> items = <String>[];
    for (final String brand in _specs) {
      items.add(brand == otherLabel ? '$otherLabel (${_otherBrand.text.trim()})' : brand);
    }
    return items.join(', ');
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) {
      return 'الاسم مطلوب لإنشاء الحساب';
    }
    if (_phone.text.trim().isEmpty || _password.text.length < 4) {
      return 'يرجى إدخال رقم الموبايل وكلمة مرور من 4 أحرف على الأقل';
    }
    if (_isWorkshop) {
      if (_license.text.trim().isEmpty) {
        return 'يرجى إدخال رقم الترخيص أو السجل التجاري للورشة';
      }
      if (_specs.isEmpty) {
        return 'يرجى اختيار ماركة واحدة على الأقل لاختصاص الورشة';
      }
      if (_specs.contains(otherLabel) && _otherBrand.text.trim().isEmpty) {
        return 'يرجى كتابة اسم الماركة الإضافية في حقل (أخرى)';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final String? problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_otpSent && _otpCode.text.trim().length != 6) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }

    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });

    if (!_otpSent) {
      try {
        final String token = await state.requestRegistrationOtp(phone: _phone.text);
        if (!mounted) return;
        setState(() {
          _otpToken = token;
          _otpSent = true;
          _busy = false;
        });
      } on ApiException catch (error) {
        if (mounted) setState(() { _busy = false; _error = error.message; });
      } catch (_) {
        if (mounted) setState(() { _busy = false; _error = unexpectedMessage; });
      }
      return;
    }

    final ReferralInput referral = _signedReferral ?? parseReferral(_referral.text);
    final AuthResult result = await state.register(
      role: _role,
      name: _name.text,
      phone: _phone.text,
      password: _password.text,
      license: _license.text,
      city: _city,
      specs: _specsText(),
      refCode: referral.code,
      refSignature: referral.signature,
      otpCode: _otpCode.text,
      otpToken: _otpToken ?? '',
    );
    if (!mounted) return;
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
    final String? pending = _pendingMessage;
    final String? error = _error;
    final ReferralInput? signed = _signedReferral;

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AuthHeader(),
          const SizedBox(height: 20),
          AuthModeSwitch(
            registering: true,
            onLogin: _busy ? null : widget.onBack,
            onRegister: null,
          ),
          const SizedBox(height: 18),
          if (pending != null)
            PendingApprovalCard(
              title: 'تم إرسال طلبك للمراجعة بنجاح!',
              message: pending,
              onBack: widget.onBack,
            )
          else ...<Widget>[
            RoleSelector(
              role: _role,
              registering: true,
              onChanged: (String value) => setState(() {
                _role = value;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            AuthFormCard(
              title: _isWorkshop ? 'بيانات اعتماد الورشة الجديدة' : 'بيانات حساب المسوّق الجديد',
              children: _form(p, error, signed),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _form(Palette p, String? error, ReferralInput? signed) {
    return <Widget>[
      AppTextField(
        controller: _name,
        label: _isWorkshop ? 'اسم الورشة أو الشركة الرسمي' : 'الاسم الكامل',
        icon: Icons.badge_outlined,
        textInputAction: TextInputAction.next,
        maxLength: 100,
        radius: 10,
      ),
      const SizedBox(height: 12),
      AppTextField(
        controller: _phone,
        label: 'رقم الموبايل',
        hint: '09XXXXXXXX',
        icon: Icons.phone_iphone_rounded,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        ltr: true,
        radius: 10,
      ),
      const SizedBox(height: 12),
      PasswordField(
        controller: _password,
        label: 'كلمة المرور (4 أحرف على الأقل)',
        textInputAction: _isWorkshop ? TextInputAction.next : TextInputAction.done,
        radius: 10,
        onSubmitted: (String _) {
          if (!_isWorkshop) {
            _submit();
          }
        },
      ),
      if (_isWorkshop) ...<Widget>[
        const SizedBox(height: 12),
        AppTextField(
          controller: _license,
          label: 'رقم السجل التجاري / ترخيص الورشة',
          icon: Icons.verified_outlined,
          textInputAction: TextInputAction.next,
          maxLength: 80,
          radius: 10,
        ),
        const SizedBox(height: 12),
        SelectField(
          label: 'المحافظة',
          value: _city,
          icon: Icons.location_on_outlined,
          radius: 10,
          onTap: _pickCity,
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'اختصاص الورشة (الماركات)',
                  style: TextStyle(color: p.muted, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String brand in specialtyBrands)
                      ToggleChip(
                        label: brand,
                        selected: _specs.contains(brand),
                        onTap: () => setState(() {
                          if (_specs.contains(brand)) {
                            _specs.remove(brand);
                          } else {
                            _specs.add(brand);
                          }
                        }),
                      ),
                  ],
                ),
                if (_specs.contains(otherLabel)) ...<Widget>[
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _otherBrand,
                    label: 'اسم الماركة الإضافية',
                    textInputAction: TextInputAction.next,
                    maxLength: 60,
                    radius: 8,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (signed != null) ...<Widget>[
          AppTextField(
            controller: _referral,
            label: 'كود المسوّق',
            icon: Icons.link_rounded,
            ltr: true,
            readOnly: true,
            radius: 10,
            suffix: IconButton(
              onPressed: _busy ? null : _clearReferral,
              tooltip: 'إزالة رابط الدعوة',
              icon: Icon(Icons.link_off_rounded, color: p.muted),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'كود الإحالة مثبت من رابط المسوّق ولا يمكن تغييره.',
            style: TextStyle(color: p.ok, fontSize: 12.5),
          ),
        ] else
          AppTextField(
            controller: _referral,
            label: 'كود المسوّق أو رابط الدعوة (اختياري)',
            hint: 'MK-XXXXXX',
            icon: Icons.link_rounded,
            ltr: true,
            radius: 10,
            textInputAction: TextInputAction.done,
            onChanged: _onReferralChanged,
          ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(Icons.verified_user_outlined, color: p.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حسابات الورشات تتطلب مراجعة وموافقة الإدارة قبل التفعيل.',
                    style: TextStyle(color: p.primary, fontSize: 12.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      if (_otpSent) ...<Widget>[
        const SizedBox(height: 12),
        AppTextField(
          controller: _otpCode,
          label: 'رمز التحقق المرسل إلى واتساب',
          hint: '000000',
          icon: Icons.password_rounded,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          ltr: true,
          radius: 10,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => setState(() {
            _otpSent = false;
            _otpToken = null;
            _otpCode.clear();
            _error = null;
          }),
          child: const Text('تغيير الرقم أو إعادة طلب الرمز'),
        ),
      ],
      const SizedBox(height: 16),
      PrimaryButton(
        flat: true,
        color: !_isWorkshop ? const Color(0xFFF59E0B) : null,
        label: _otpSent ? 'تأكيد الرمز وإنشاء الحساب' : 'إرسال رمز التحقق إلى واتساب',
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
    ];
  }
}
