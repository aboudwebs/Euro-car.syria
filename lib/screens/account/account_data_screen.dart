// Account data: name, governorate, phone number and password. The company licence is shown but cannot be changed
// from the app (the server ignores it and a database trigger blocks it: see supabase/updates_2026_10.sql).
//
//   name + governorate   PUT /api/auth                         (existing endpoint)
//   password             POST /api/account/password            (current password required; an account made with
//                                                              e-mail has none and ADDS its first one without it;
//                                                              "forgot password" sends an SMS code to the account phone)
//   phone number         POST /api/account/phone               (SMS code to the NEW number; an account made with
//                                                              e-mail has no number yet and ADDS it the same way)

import 'dart:async';

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
    // The buttons depend on facts the server knows (has a password, phone confirmed): refresh them quietly.
    unawaited(AppScope.read(context).refreshProfile());
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
    // An account made with e-mail has no password yet: its first one is ADDED without asking for a current one.
    final bool first = !(AppScope.read(context).user?.hasPassword ?? true);
    final String current = _currentPassword.text;
    final String next = _newPassword.text;
    String? problem;
    if (!first && current.isEmpty) {
      problem = 'أدخل كلمة المرور الحالية.';
    } else if (next.length < minNewPasswordLength) {
      problem = first ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.' : 'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.';
    } else if (next != _confirmPassword.text) {
      problem = first ? 'كلمتا المرور غير متطابقتين.' : 'كلمتا المرور الجديدتان غير متطابقتين.';
    } else if (!first && next == current) {
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
      if (first) {
        await state.addPassword(newPassword: next);
      } else {
        await state.changePassword(currentPassword: current, newPassword: next);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _savingPassword = false;
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        _passwordNotice = first
            ? 'تمت إضافة كلمة المرور. تستخدمها مع رقم موبايلك في تسجيل الدخول.'
            : 'تم تغيير كلمة المرور. استخدم الجديدة في تسجيل الدخول القادم.';
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
    final AppUser? user = AppScope.read(context).user;
    if (user == null) {
      return;
    }
    if (user.hasPhone && !user.hasPassword) {
      // Nothing but the session would protect the change: the server asks for a password first.
      showSnack(context, 'أضف كلمة مرور لحسابك أولاً من قسم «إضافة كلمة مرور» أدناه، ثم غيّر رقم الموبايل.');
      return;
    }
    final bool adding = !user.hasPhone;
    final bool needsPassword = user.hasPassword;
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _PhoneChangeSheet(adding: adding, needsPassword: needsPassword),
    );
    if (changed == true && mounted) {
      showSnack(context, adding ? 'تمت إضافة رقم الموبايل' : 'تم تغيير رقم الموبايل');
    }
  }

  /// "Forgot my password" without signing out: an SMS code goes to the phone number of the account.
  Future<void> _forgotPassword() async {
    final AppUser? user = AppScope.read(context).user;
    if (user == null) {
      return;
    }
    if (!user.hasPhone) {
      showSnack(context, 'أضف رقم الموبايل إلى حسابك أولاً لنرسل لك رمز الاستعادة برسالة نصية.');
      return;
    }
    final String phone = user.phone;
    final bool? done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _PasswordRecoverySheet(phone: phone),
    );
    if (done == true && mounted) {
      setState(() {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        _passwordError = null;
        _passwordNotice = 'تم تعيين كلمة المرور الجديدة وبقيت مسجّلاً في هذا الجهاز.';
      });
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
                    if (user.hasPhone) ...<Widget>[
                      InfoRow(label: 'الرقم الحالي', value: user.phone, ltr: true, bold: true),
                      if (user.raw.containsKey('phone_verified')) ...<Widget>[
                        const SizedBox(height: 6),
                        InfoRow(label: 'حالة التوثيق', value: user.phoneVerified ? 'موثّق' : 'غير موثّق', bold: true),
                      ],
                      const SizedBox(height: 6),
                    ],
                    Text(
                      user.hasPhone
                          ? 'رقم الموبايل هو اسم الدخول إلى حسابك. عند تغييره نرسل رمز تحقق إلى الرقم الجديد برسالة نصية.'
                          : 'حسابك مسجّل بالبريد الإلكتروني ولا يحتوي على رقم موبايل. أضف رقمك لتوثيق حسابك وليكون اسم الدخول إليه؛ نرسل رمز تحقق إلى الرقم برسالة نصية.',
                      style: TextStyle(color: p.muted, fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    SecondaryButton(
                      label: user.hasPhone ? 'تغيير رقم الموبايل' : 'إضافة رقم الموبايل',
                      icon: user.hasPhone ? Icons.swap_horiz_rounded : Icons.add_call,
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
                    _CardTitle(
                      icon: Icons.lock_outline_rounded,
                      title: user.hasPassword ? 'تغيير كلمة المرور' : 'إضافة كلمة مرور',
                    ),
                    const SizedBox(height: 16),
                    if (!user.hasPassword) ...<Widget>[
                      Text(
                        'حسابك أُنشئ بالبريد الإلكتروني فلا توجد له كلمة مرور بعد. أضف كلمة مرور (8 أحرف على الأقل) لتسجّل بها الدخول برقم موبايلك.',
                        style: TextStyle(color: p.muted, fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 14),
                    ] else ...<Widget>[
                      PasswordField(
                        controller: _currentPassword,
                        label: 'كلمة المرور الحالية',
                        radius: 12,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                    ],
                    PasswordField(
                      controller: _newPassword,
                      label: user.hasPassword ? 'كلمة المرور الجديدة' : 'كلمة المرور',
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      controller: _confirmPassword,
                      label: user.hasPassword ? 'تأكيد كلمة المرور الجديدة' : 'تأكيد كلمة المرور',
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
                      label: user.hasPassword ? 'تغيير كلمة المرور' : 'إضافة كلمة المرور',
                      icon: user.hasPassword ? Icons.lock_reset_rounded : Icons.lock_outline_rounded,
                      radius: 12,
                      busy: _savingPassword,
                      onPressed: _savePassword,
                    ),
                    if (user.hasPassword)
                      TextButton(
                        onPressed: _savingPassword ? null : _forgotPassword,
                        child: const Text('نسيت كلمة المرور؟'),
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

/// The two steps of a phone change in a bottom sheet: new number + current password, then the SMS code.
class _PhoneChangeSheet extends StatefulWidget {
  const _PhoneChangeSheet({this.adding = false, this.needsPassword = true});

  /// The account has no phone yet (made with e-mail): the number is added, not changed.
  final bool adding;

  /// The account has a password to ask for. An account made with e-mail has none: the SMS code is the proof.
  final bool needsPassword;

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
    if (widget.needsPassword && _password.text.isEmpty) {
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
        currentPassword: widget.needsPassword ? _password.text : '',
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
                widget.adding ? 'إضافة رقم الموبايل' : 'تغيير رقم الموبايل',
                style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (!_codeStep) ...<Widget>[
                AppTextField(
                  controller: _phone,
                  label: widget.adding ? 'رقم الموبايل' : 'الرقم الجديد',
                  hint: '9639XXXXXXXX',
                  icon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  textInputAction: widget.needsPassword ? TextInputAction.next : TextInputAction.done,
                  ltr: true,
                  radius: 12,
                  onSubmitted: widget.needsPassword ? null : (String value) => _request(),
                ),
                if (widget.needsPassword) ...<Widget>[
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _password,
                    label: 'كلمة المرور الحالية',
                    radius: 12,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (String value) => _request(),
                  ),
                ],
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
                PrimaryButton(
                  label: widget.adding ? 'تأكيد وإضافة الرقم' : 'تأكيد وتغيير الرقم',
                  icon: Icons.check_rounded,
                  radius: 12,
                  busy: _busy,
                  onPressed: _confirm,
                ),
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

/// "Forgot my password" for a signed-in user, in two steps: an SMS code goes to the phone number of the account, then the
/// code and the new password are sent together. This device stays signed in (the server returns a new session token).
class _PasswordRecoverySheet extends StatefulWidget {
  const _PasswordRecoverySheet({required this.phone});

  final String phone;

  @override
  State<_PasswordRecoverySheet> createState() => _PasswordRecoverySheetState();
}

class _PasswordRecoverySheetState extends State<_PasswordRecoverySheet> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  /// The number with only its last digits readable, e.g. ••••••4567.
  String get _maskedPhone {
    final String digits = widget.phone.trim();
    if (digits.length <= 4) {
      return digits;
    }
    return '••••••${digits.substring(digits.length - 4)}';
  }

  Future<void> _send() async {
    if (_busy) {
      return;
    }
    final AppState state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String message = await state.requestPasswordRecovery();
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
    final String next = _newPassword.text;
    String? problem;
    if (_code.text.trim().length != 6) {
      problem = 'أدخل رمز التحقق المكوّن من 6 أرقام.';
    } else if (next.length < minNewPasswordLength) {
      problem = 'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.';
    } else if (next != _confirmPassword.text) {
      problem = 'كلمتا المرور الجديدتان غير متطابقتين.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.confirmPasswordRecovery(code: _code.text, newPassword: next);
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
                'استعادة كلمة المرور',
                style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (!_codeStep) ...<Widget>[
                Text(
                  'نرسل رمز تحقق برسالة نصية إلى رقم الموبايل المسجّل في حسابك، ثم تعيّن كلمة مرور جديدة دون أن تخرج من حسابك.',
                  style: TextStyle(color: p.muted, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 10),
                InfoRow(label: 'الرقم', value: _maskedPhone, ltr: true, bold: true),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  NoticeBanner(message: error, kind: NoticeKind.error),
                ],
                const SizedBox(height: 16),
                PrimaryButton(label: 'إرسال رمز التحقق', icon: Icons.send_rounded, radius: 12, busy: _busy, onPressed: _send),
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
                  textInputAction: TextInputAction.next,
                  maxLength: 6,
                  ltr: true,
                  radius: 12,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _newPassword,
                  label: 'كلمة المرور الجديدة',
                  radius: 12,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _confirmPassword,
                  label: 'تأكيد كلمة المرور الجديدة',
                  radius: 12,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (String value) => _confirm(),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  NoticeBanner(message: error, kind: NoticeKind.error),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'تأكيد وتعيين كلمة المرور',
                  icon: Icons.check_rounded,
                  radius: 12,
                  busy: _busy,
                  onPressed: _confirm,
                ),
                TextButton(
                  onPressed: _busy ? null : _send,
                  child: const Text('إعادة إرسال الرمز'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
