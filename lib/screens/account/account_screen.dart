// Account tab (the profile): photo and details, display settings (currency, language, theme), pages for account data,
// addresses, vehicles and About EURO, the customer's active and previous orders, support, sign-out and account
// deletion (30-day grace period that can be cancelled).
//
// The profile card, stat cards, support button and red sign-out button follow the web account page.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/display.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/pickers.dart';
import '../../widgets/pressable.dart';
import '../../widgets/segmented.dart';
import '../home/tab_header.dart';
import '../orders/order_card.dart';
import '../../widgets/tx.dart';
import 'about_screen.dart';
import 'account_data_screen.dart';
import 'addresses_screen.dart';
import 'vehicles_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _avatarBusy = false;
  String? _notice;
  String? _error;

  /// Previous orders shown on the profile before "show all".
  static const int _previewCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      final AppState state = AppScope.read(context);
      state.loadOrders(silent: true);
      state.loadDeletion(silent: true);
    });
  }

  Future<void> _changePhoto() async {
    if (_avatarBusy) {
      return;
    }
    final AppState state = AppScope.read(context);
    final ImagePickResult result = await pickPhoto(context, maxSide: 800);
    if (!mounted) {
      return;
    }
    final Uint8List? bytes = result.bytes;
    if (bytes == null) {
      final String? failure = result.error;
      if (failure != null) {
        setState(() {
          _error = failure;
          _notice = null;
        });
      }
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('معاينة صورة الحساب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            UserAvatar(name: '', bytes: bytes, size: 160),
            const SizedBox(height: 14),
            const Text(
              'ستظهر الصورة بهذا الشكل في حسابك.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          PrimaryButton(
            label: 'اعتماد الصورة',
            compact: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _avatarBusy = true;
      _error = null;
      _notice = null;
    });
    try {
      await state.uploadAvatar(bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarBusy = false;
        _notice = 'تم تحديث صورة الحساب.';
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarBusy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarBusy = false;
        _error = unexpectedMessage;
      });
    }
  }

  Future<void> _openAccountOrders({required bool active}) async {
    await AppScope.read(context).loadOrders(silent: true);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => AccountOrdersScreen(active: active),
      ),
    );
  }

  Future<void> _openSupport() async {
    final bool opened = await openExternalUrl(supportUrl());
    if (!opened && mounted) {
      showSnack(context, 'تعذر فتح واتساب. تأكد من تثبيته على الجهاز.');
    }
  }

  Future<void> _openDeveloper() async {
    final bool opened = await openExternalUrl(developerUrl);
    if (!opened && mounted) {
      showSnack(context, 'تعذر فتح الرابط.');
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      showSnack(context, 'تم نسخ كود المسوّق');
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Palette p = Palette.of(dialogContext);
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text(
            'هل تريد تسجيل الخروج من حسابك؟ سيتم تفريغ السلة المحفوظة على هذا الجهاز.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: p.errText),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await AppScope.read(context).logout();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final bool? requested = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => const _DeleteAccountDialog(),
    );
    if (requested == true && mounted) {
      setState(() {
        _error = null;
        _notice = 'تم تسجيل طلب حذف الحساب. يمكنك إلغاؤه في أي وقت خلال $accountDeletionGraceDays يوماً.';
      });
    }
  }

  Future<void> _cancelDeletion() async {
    final AppState state = AppScope.read(context);
    try {
      await state.cancelAccountDeletion();
      if (mounted) {
        setState(() {
          _error = null;
          _notice = 'تم إلغاء طلب حذف الحساب. حسابك مفعّل كالمعتاد.';
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _notice = null;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notice = null;
          _error = unexpectedMessage;
        });
      }
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
    final String? notice = _notice;
    final String? error = _error;
    final DeletionRequest? deletion = state.deletion;

    return Column(
      children: <Widget>[
        const TabHeader(
          title: 'حسابي',
          subtitle: 'إدارة بيانات حسابك وإعدادات التطبيق',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              if (notice != null) ...<Widget>[
                NoticeBanner(
                  message: notice,
                  kind: NoticeKind.success,
                  onDismiss: () => setState(() => _notice = null),
                ),
                const SizedBox(height: 12),
              ],
              if (error != null) ...<Widget>[
                NoticeBanner(
                  message: error,
                  kind: NoticeKind.error,
                  onDismiss: () => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
              ],
              if (deletion != null) ...<Widget>[
                _DeletionBanner(deletion: deletion, onCancel: _cancelDeletion),
                const SizedBox(height: 12),
              ],
              _profileCard(p, state, user),
              const SizedBox(height: 12),
              _statTiles(p, user),
              const SectionTitle('إعدادات العرض'),
              _settingsPanel(p, state),
              const SectionTitle('الحساب والخدمات'),
              _linksPanel(p, state),
              const SectionTitle('الطلبات'),
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: Icon(Icons.local_shipping_outlined, color: p.primary),
                      title: const Text('طلباتي النشطة'),
                      subtitle: Text('متابعة الطلبات قيد التنفيذ', style: TextStyle(color: p.muted, fontSize: 12)),
                      trailing: Icon(Icons.chevron_left_rounded, color: p.muted),
                      onTap: () => _openAccountOrders(active: true),
                    ),
                    Divider(height: 1, color: p.line),
                    ListTile(
                      leading: Icon(Icons.history_rounded, color: p.primary),
                      title: const Text('طلباتي السابقة'),
                      subtitle: Text('عرض الطلبات المكتملة والملغاة', style: TextStyle(color: p.muted, fontSize: 12)),
                      trailing: Icon(Icons.chevron_left_rounded, color: p.muted),
                      onTap: () => _openAccountOrders(active: false),
                    ),
                  ],
                ),
              ),
              const SectionTitle('المساعدة'),
              SecondaryButton(
                label: 'التواصل مع الدعم عبر واتساب',
                icon: Icons.support_agent_rounded,
                iconColor: p.ok,
                onPressed: _openSupport,
              ),
              const SizedBox(height: 10),
              _LogoutButton(onPressed: _confirmLogout),
              const SizedBox(height: 10),
              if (deletion == null)
                Center(
                  child: TextButton.icon(
                    onPressed: _confirmDeleteAccount,
                    style: TextButton.styleFrom(foregroundColor: p.errText),
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('حذف الحساب'),
                  ),
                ),
              Center(
                child: TextButton.icon(
                  onPressed: _openDeveloper,
                  icon: Icon(Icons.open_in_new_rounded, size: 15, color: p.muted),
                  label: Text(
                    'تطوير $developerName',
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Currency, language and theme.
  Widget _settingsPanel(Palette p, AppState state) {
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('العملة', style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedTrack<String>(
            selected: DisplayPrefs.showSyp ? currencySyp : currencyUsd,
            onChanged: (String code) {
              if (!state.setCurrency(code)) {
                showSnack(context, 'سعر صرف الليرة السورية غير متاح حالياً. الأسعار تبقى بالدولار.');
              }
            },
            options: <SegmentOption<String>>[
              const SegmentOption<String>(value: currencyUsd, label: 'دولار (USD)'),
              SegmentOption<String>(
                value: currencySyp,
                label: 'ليرة سورية (SYP)',
                enabled: state.canShowSyp,
              ),
            ],
          ),
          if (!state.canShowSyp) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'الليرة السورية تُفعَّل عندما تنشر الإدارة سعر الصرف.',
              style: TextStyle(color: p.placeholder, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Text('اللغة', style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedTrack<String>(
            selected: state.language,
            onChanged: state.setLanguage,
            options: const <SegmentOption<String>>[
              SegmentOption<String>(value: languageArabic, label: 'العربية'),
              SegmentOption<String>(value: languageEnglish, label: 'English'),
            ],
          ),
          const SizedBox(height: 16),
          Text('المظهر', style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 8),
          _themeSelector(state),
        ],
      ),
    );
  }

  /// Account data, addresses, vehicles and About EURO.
  Widget _linksPanel(Palette p, AppState state) {
    final int addresses = state.addresses.length;
    final int vehicles = state.vehicles.length;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: <Widget>[
          _NavTile(
            icon: Icons.manage_accounts_outlined,
            title: 'بيانات الحساب',
            subtitle: 'الاسم، المحافظة، رقم الموبايل، كلمة المرور',
            onTap: () => openAccountData(context),
          ),
          Divider(height: 1, color: p.line),
          _NavTile(
            icon: Icons.location_on_outlined,
            title: 'عناويني',
            subtitle: addresses == 0 ? 'احفظ عناوين التسليم' : '$addresses عنوان محفوظ',
            onTap: () => openAddresses(context),
          ),
          Divider(height: 1, color: p.line),
          _NavTile(
            icon: Icons.directions_car_outlined,
            title: 'مركباتي',
            subtitle: vehicles == 0 ? 'سجّل مركباتك مع رقم الشاصي' : '$vehicles مركبة مسجلة',
            onTap: () => openVehicles(context),
          ),
          Divider(height: 1, color: p.line),
          _NavTile(
            icon: Icons.info_outline_rounded,
            title: 'عن EURO',
            subtitle: 'من نحن، العنوان، التواصل',
            onTap: () => openAbout(context),
          ),
        ],
      ),
    );
  }

  /// The profile card: a blue wash fading to glass, the photo with its change badge, and the account details.
  Widget _profileCard(Palette p, AppState state, AppUser user) {
    final DateTime? since = user.createdAt;
    final String? city = user.city;
    final List<Color> wash = p.isDark
        ? const <Color>[Color(0x330A84FF), Color(0x0FFFFFFF), Color(0x05FFFFFF)]
        : const <Color>[Color(0xFFDDEBFF), Color(0xFFFFFFFF), Color(0xFFF8FAFC)];
    return Panel(
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: wash,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    UserAvatar(name: user.name, bytes: state.avatarBytes, size: 80),
                    PositionedDirectional(
                      bottom: -6,
                      end: -6,
                      child: Material(
                        color: p.accent,
                        shape: CircleBorder(side: BorderSide(color: p.bg, width: 2)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _avatarBusy ? null : _changePhoto,
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: _avatarBusy
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_rounded, size: 17, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusChip(
                      label: user.isWorkshop ? 'حساب ورشة معتمد' : 'حساب مسوّق',
                      tone: StatusTone.success,
                    ),
                    const SizedBox(height: 8),
                    _ProfileLine(icon: Icons.phone_outlined, text: user.phone, ltr: true),
                    if (city != null && city.isNotEmpty)
                      _ProfileLine(icon: Icons.location_on_outlined, text: city),
                    if (since != null)
                      _ProfileLine(
                        icon: Icons.schedule_rounded,
                        text: 'عضو منذ ${formatDate(since)}',
                        small: true,
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

  Widget _statTiles(Palette p, AppUser user) {
    if (user.isMarketer) {
      final String? code = user.myRefCode;
      return Panel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.verified_user_outlined, color: p.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('كود المسوّق', style: TextStyle(color: p.muted, fontSize: 13.5)),
                  Text(
                    code ?? 'غير متوفر',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: p.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'يُستخدم هذا الكود عند تسجيل ورشة جديدة.',
                    style: TextStyle(color: p.placeholder, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (code != null)
              RoundIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'نسخ الكود',
                onTap: () => _copyCode(code),
              ),
          ],
        ),
      );
    }

    final double? limit = user.debtLimit;
    final double? used = user.debtBalance;
    final String? tier = user.tier;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _StatTile(
              label: 'سقف دفتر الدين',
              value: limit == null ? 'غير محدد' : formatUsd(limit),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'الرصيد المستخدم',
              value: used == null ? 'غير متوفر' : formatUsd(used),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'تصنيف الحساب',
              value: tier == null ? '—' : tierLabel(tier),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeSelector(AppState state) {
    return SegmentedTrack<ThemeMode>(
      selected: state.themeMode,
      onChanged: state.setThemeMode,
      options: const <SegmentOption<ThemeMode>>[
        SegmentOption<ThemeMode>(value: ThemeMode.dark, label: 'داكن'),
        SegmentOption<ThemeMode>(value: ThemeMode.light, label: 'فاتح'),
        SegmentOption<ThemeMode>(value: ThemeMode.system, label: 'النظام'),
      ],
    );
  }
}

/// One line of the profile card: a small icon and a muted text (phone numbers stay left-to-right).
class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.icon, required this.text, this.ltr = false, this.small = false});

  final IconData icon;
  final String text;
  final bool ltr;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Color ink = small ? p.placeholder : p.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: small ? 13 : 15, color: ink),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: TextAlign.start,
              style: TextStyle(color: ink, fontSize: small ? 12.5 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// The web account page's sign-out button: a full-width rounded box tinted red.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return PressScale(
      child: Material(
        color: p.err.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.err.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.logout_rounded, color: p.errText, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: p.errText, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.primary, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// One row of the account links list: icon, title, a muted line and a chevron.
class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, color: p.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: p.muted, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: p.placeholder),
          ],
        ),
      ),
    );
  }
}

/// Shown while an account deletion is pending: how many days are left and a button to cancel.
class _DeletionBanner extends StatelessWidget {
  const _DeletionBanner({required this.deletion, required this.onCancel});

  final DeletionRequest deletion;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final int days = deletion.daysLeft;
    return Panel(
      color: p.err.withValues(alpha: 0.10),
      borderColor: p.err.withValues(alpha: 0.30),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.hourglass_bottom_rounded, color: p.errText, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حسابك مجدول للحذف',
                  style: TextStyle(color: p.errText, fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            days <= 0
                ? 'ينتهي الاسترجاع اليوم. بعدها يُحذف الحساب نهائياً.'
                : 'سيُحذف حسابك نهائياً بعد $days يوم. يمكنك إلغاء الطلب قبل ذلك.',
            style: TextStyle(color: p.text, fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 12),
          SecondaryButton(label: 'إلغاء حذف الحساب', icon: Icons.undo_rounded, onPressed: onCancel),
        ],
      ),
    );
  }
}

/// Asks for the password again and starts the 30-day deletion countdown.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور لتأكيد الحذف.');
      return;
    }
    final AppState state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.requestAccountDeletion(_password.text);
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
    return AlertDialog(
      title: const Text('حذف الحساب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'سيُحذف حسابك بعد $accountDeletionGraceDays يوماً من الآن، ويمكنك إلغاء الطلب خلال هذه المدة من صفحة حسابي. '
              'بعد انتهاء المدة تُزال بياناتك الشخصية، وتبقى سجلات الطلبات والمبالغ لأغراض المحاسبة دون بياناتك.',
              style: TextStyle(color: p.text, fontSize: 13.5, height: 1.6),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              label: 'كلمة المرور',
              radius: 12,
              textInputAction: TextInputAction.done,
              onSubmitted: (String value) => _submit(),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 10),
              NoticeBanner(message: error, kind: NoticeKind.error),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          style: TextButton.styleFrom(foregroundColor: p.errText),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
              : const Text('تأكيد حذف الحساب'),
        ),
      ],
    );
  }
}


/// Orders opened from the profile as dedicated screens, keeping the profile uncluttered.
class AccountOrdersScreen extends StatelessWidget {
  const AccountOrdersScreen({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final List<Order> orders = active ? state.activeOrders : state.previousOrders;
    final String? error = state.ordersError;

    Widget content;
    if (!state.ordersLoaded && state.ordersLoading) {
      content = const Center(child: LoadingBlock(message: 'جارٍ تحميل الطلبات...'));
    } else if (!state.ordersLoaded && error != null) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          NoticeBanner(message: error, kind: NoticeKind.error, onRetry: () => state.loadOrders()),
        ],
      );
    } else if (orders.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Panel(
            padding: EdgeInsets.zero,
            child: EmptyState(
              icon: active ? Icons.local_shipping_outlined : Icons.history_rounded,
              title: active ? 'لا توجد طلبات نشطة' : 'لا توجد طلبات سابقة',
              message: active
                  ? 'ستظهر هنا طلباتك التي ما زالت قيد التنفيذ.'
                  : 'ستظهر هنا طلباتك المكتملة أو الملغاة.',
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(message: error, kind: NoticeKind.error, onRetry: () => state.loadOrders()),
          ],
        ],
      );
    } else {
      content = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: orders.length + (error == null ? 0 : 1),
        itemBuilder: (BuildContext context, int index) {
          if (error != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NoticeBanner(message: error, kind: NoticeKind.error, onRetry: () => state.loadOrders()),
            );
          }
          final Order order = orders[index - (error == null ? 0 : 1)];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrderCard(key: ValueKey<String>(order.id), order: order),
          );
        },
      );
    }

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(active ? 'طلباتي النشطة' : 'طلباتي السابقة'),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: p.primary,
            backgroundColor: p.panel,
            onRefresh: () => state.loadOrders(),
            child: content,
          ),
        ),
      ),
    );
  }
}
