// Account data: name, governorate, phone number and password. The company licence is shown but cannot be changed
// from the app (the server ignores it and a database trigger blocks it: see supabase/updates_2026_10.sql).
//
//   name + governorate   PUT /api/auth                         (existing endpoint)
//   password             POST /api/account/password            (current password required)
//   phone number         POST /api/account/phone               (WhatsApp code to the NEW number)

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/pickers.dart';
import '../../widgets/select_field.dart';
import '../../widgets/tx.dart';

/// Opens the account data page.
void openAccountData(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext routeContext) => const AccountDataScreen()),
  );
}

class AccountDataScreen extends StatefulWidget {
  const AccountDataScreen({super.key});

  @override
  State<AccountDataScreen> createState() => _AccountDataScreenState();
}

class _AccountDataScreenState extends State<AccountDataScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  String _city = '';

  bool _savingProfile = false;
  bool _savingPassword = false;
  String? _profileNotice;
  String? _profileError;
  String? _passwordNotice;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final AppUser? user = AppScope.read(context).user;
    if (user != null) {
      _name.text = user.name;
      _city = user.city ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final String? picked = await showChoiceSheet<String>(
      context: context,
      title: 'اختر المحافظة',
      options: governorates,
      labelOf: (String value) => value,
      selected: _city.isEmpty ? null : _city,
    );
    if (picked != null && mounted) {
      setState(() => _city = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) {
      return;
    }
    final String name = _name.text.trim();
    if (name.length < 2) {
      setState(() {
        _profileError = 'الاسم يجب أن يكون حرفين على الأقل.';
        _profileNotice = null;
      });
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _savingProfile = true;
      _profileError = null;
      _profileNotice = null;
    });
    try {
      await state.updateProfile(name: name, city: _city);
      if (!mounted) {
        return;
      }
      final AppUser? fresh = state.user;
      setState(() {
        _savingProfile = false;
        if (fresh != null) {
          _name.text = fresh.name;
          _city = fresh.city ?? _city;
        }
        _profileNotice = 'تم حفظ بيانات حسابك بنجاح.';
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _savingProfile = false;
          _profileError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingProfile = false;
          _profileError = unexpectedMessage;
        });
      }
    }
  }

  Future<void> _savePassword() async {
    if (_savingPassword) {
      return;
    }
    final String current = _currentPassword.text;
    final String next = _newPassword.text;
    String? problem;
    if (current.isEmpty) {
      problem = 'أدخل كلمة المرور الحالية.';
    } else if (next.length < minNewPasswordLength) {
      problem = 'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.';
    } else if (next != _confirmPassword.text) {
      problem = 'كلمتا المرور الجديدتان غير متطابقتين.';
    } else if (next == current) {
      problem = 'كلمة المرور الجديدة مطابقة للحالية.';
    }
    if (problem != null) {
      setState(() {
        _passwordError = problem;
        _passwordNotice = null;
      });
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _savingPassword = true;
      _passwordError = null;
      _passwordNotice = null;
    });
    try {
      await state.changePassword(currentPassword: current, newPassword: next);
      if (!mounted) {
        return;
      }
      setState(() {
        _savingPassword = false;
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        _passwordNotice = 'تم تغيير كلمة المرور. استخدم الجديدة في تسجيل الدخول القادم.';
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _savingPassword = false;
          _passwordError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingPassword = false;
          _passwordError = unexpectedMessage;
        });
      }
    }
  }

  Future<void> _changePhone() async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => const _PhoneChangeSheet(),
    );
    if (changed == true && mounted) {
      showSnack(context, 'تم تغيير رقم الموبايل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final AppUser? user = state.user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final String license = (user.license ?? '').trim();

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'بيانات الحساب'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              Panel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _CardTitle(icon: Icons.person_outline_rounded, title: 'البيانات الشخصية'),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _name,
                      label: 'الاسم',
                      icon: Icons.badge_outlined,
                      maxLength: 100,
                      radius: 12,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 14),
                    SelectField(
                      label: 'المحافظة',
                      value: _city,
                      placeholder: 'اختر المحافظة',
                      icon: Icons.location_on_outlined,
                      radius: 12,
                      onTap: _pickCity,
                    ),
                    if (_profileNotice != null) ...<Widget>[
                      const SizedBox(height: 14),
                      NoticeBanner(message: _profileNotice!, kind: NoticeKind.success),
                    ],
                    if (_profileError != null) ...<Widget>[
                      const SizedBox(height: 14),
                      NoticeBanner(message: _profileError!, kind: NoticeKind.error),
                    ],
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'حفظ التعديلات',
                      icon: Icons.save_outlined,
                      radius: 12,
                      busy: _savingProfile,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _CardTitle(icon: Icons.phone_iphone_rounded, title: 'رقم الموبايل'),
                    const SizedBox(height: 12),
                    InfoRow(label: 'الرقم الحالي', value: user.phone, ltr: true, bold: true),
                    const SizedBox(height: 6),
                    Text(
                      'رقم الموبايل هو اسم الدخول إلى حسابك. عند تغييره نرسل رمز تحقق إلى الرقم الجديد على واتساب.',
                      style: TextStyle(color: p.muted, fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    SecondaryButton(
                      label: 'تغيير رقم الموبايل',
                      icon: Icons.swap_horiz_rounded,
                      onPressed: _changePhone,
                    ),
                  ],
                ),
              ),
              if (user.isWorkshop) ...<Widget>[
                const SizedBox(height: 12),
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _CardTitle(icon: Icons.verified_outlined, title: 'ترخيص الشركة'),
                      const SizedBox(height: 12),
                      InfoRow(
                        label: 'الحالة',
                        value: license.isEmpty ? 'لم يُرفق ترخيص' : 'مرفق ومعتمد من الإدارة',
                        bold: true,
                      ),
                      const SizedBox(height: 10),
                      NoteBox(
                        text: 'ترخيص الشركة للقراءة فقط ولا يمكن تعديله من التطبيق. لتغييره تواصل مع إدارة EURO.',
                        color: p.accent,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _CardTitle(icon: Icons.lock_outline_rounded, title: 'تغيير كلمة المرور'),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _currentPassword,
                      label: 'كلمة المرور الحالية',
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      controller: _newPassword,
                      label: 'كلمة المرور الجديدة',
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      controller: _confirmPassword,
                      label: 'تأكيد كلمة المرور الجديدة',
                      radius: 12,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (String value) => _savePassword(),
                    ),
                    if (_passwordNotice != null) ...<Widget>[
                      const SizedBox(height: 14),
                      NoticeBanner(message: _passwordNotice!, kind: NoticeKind.success),
                    ],
                    if (_passwordError != null) ...<Widget>[
                      const SizedBox(height: 14),
                      NoticeBanner(message: _passwordError!, kind: NoticeKind.error),
                    ],
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'تغيير كلمة المرور',
                      icon: Icons.lock_reset_rounded,
                      radius: 12,
                      busy: _savingPassword,
                      onPressed: _savePassword,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, color: p.primary, size: 22),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// The two steps of a phone change in a bottom sheet: new number + current password, then the WhatsApp code.
class _PhoneChangeSheet extends StatefulWidget {
  const _PhoneChangeSheet();

  @override
  State<_PhoneChangeSheet> createState() => _PhoneChangeSheetState();
}

class _PhoneChangeSheetState extends State<_PhoneChangeSheet> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy) {
      return;
    }
    if (_phone.text.trim().length < 8) {
      setState(() => _error = 'أدخل الرقم الجديد بالصيغة الدولية (مثال 9639XXXXXXXX).');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور الحالية.');
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String message = await state.requestPhoneChange(
        newPhone: _phone.text,
        currentPassword: _password.text,
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _codeStep = true;
          _info = message;
        });
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

  Future<void> _confirm() async {
    if (_busy) {
      return;
    }
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.confirmPhoneChange(newPhone: _phone.text, code: _code.text);
      if (mounted) {
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String? error = _error;
    final String? info = _info;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'تغيير رقم الموبايل',
                style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (!_codeStep) ...<Widget>[
                AppTextField(
                  controller: _phone,
                  label: 'الرقم الجديد',
                  hint: '9639XXXXXXXX',
                  icon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  ltr: true,
                  radius: 12,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  label: 'كلمة المرور الحالية',
                  radius: 12,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (String value) => _request(),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  NoticeBanner(message: error, kind: NoticeKind.error),
                ],
                const SizedBox(height: 16),
                PrimaryButton(label: 'إرسال رمز التحقق', icon: Icons.send_rounded, radius: 12, busy: _busy, onPressed: _request),
              ] else ...<Widget>[
                if (info != null) ...<Widget>[
                  NoticeBanner(message: info, kind: NoticeKind.success),
                  const SizedBox(height: 12),
                ],
                AppTextField(
                  controller: _code,
                  label: 'رمز التحقق (6 أرقام)',
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  ltr: true,
                  radius: 12,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (String value) => _confirm(),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  NoticeBanner(message: error, kind: NoticeKind.error),
                ],
                const SizedBox(height: 16),
                PrimaryButton(label: 'تأكيد وتغيير الرقم', icon: Icons.check_rounded, radius: 12, busy: _busy, onPressed: _confirm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _codeStep = false;
                            _error = null;
                            _code.clear();
                          }),
                  child: const Text('تعديل الرقم أو إعادة الإرسال'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
