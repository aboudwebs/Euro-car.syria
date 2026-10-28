// Pieces shared by the sign-in and registration screens, laid out like the web app's account page: a centred
// title, a sign-in / sign-up switch, two account-type tiles and a form card.

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';

/// The page frame of both auth screens: the glowing backdrop, a scrollable column no wider than 600 px.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page title and its muted subtitle.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Column(
      children: <Widget>[
        Text(
          'حسابي — اليورو',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'إدارة حسابك والوصول للخدمات الخاصة',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 13),
        ),
      ],
    );
  }
}

/// The two-way switch under the title: sign in / create account.
class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    super.key,
    required this.registering,
    required this.onLogin,
    required this.onRegister,
  });

  final bool registering;
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.glass2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _ModeButton(
                label: 'تسجيل الدخول',
                icon: Icons.login_rounded,
                active: !registering,
                onTap: onLogin,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _ModeButton(
                label: 'إنشاء حساب',
                icon: Icons.person_add_alt_1_rounded,
                active: registering,
                onTap: onRegister,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.icon, required this.active, required this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final BorderRadius shape = BorderRadius.circular(10);
    final Color ink = active ? p.primary : p.muted;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0x403B82F6) : Colors.transparent,
              borderRadius: shape,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 16, color: ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ink, fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two tiles that choose between a workshop account and a marketer account.
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.role,
    required this.onChanged,
    required this.registering,
  });

  final String role;
  final ValueChanged<String> onChanged;
  final bool registering;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: _RoleTile(
            icon: Icons.build_rounded,
            iconColor: p.primary,
            tone: const Color(0xFF3B82F6),
            title: 'حساب ورشة / شركة',
            subtitle: registering ? 'يتطلب موافقة الإدارة' : 'تسجيل دخول الورش',
            selected: role == 'workshop',
            onTap: () => onChanged('workshop'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleTile(
            icon: Icons.share_rounded,
            iconColor: p.warn,
            tone: const Color(0xFFF59E0B),
            title: 'حساب عميل / مسوّق',
            subtitle: registering ? 'تفعيل فوري' : 'تسجيل دخول المسوقين',
            selected: role == 'marketer',
            onTap: () => onChanged('marketer'),
          ),
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.iconColor,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color tone;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title، $subtitle',
      child: Material(
        color: selected ? tone.withValues(alpha: 0.15) : p.glass1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? tone : p.line, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              children: <Widget>[
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(height: 5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.text, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The form card: a bold title with a hairline under it, then the fields.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Panel(
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Divider(color: p.line),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// A short centred message under the submit button (errors in red, confirmations in green).
class AuthMessage extends StatelessWidget {
  const AuthMessage({super.key, required this.text, this.success = false});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Color ink = success ? p.ok : p.errText;
    final Color fill = success ? p.ok.withValues(alpha: 0.12) : p.err.withValues(alpha: 0.15);
    return Semantics(
      liveRegion: true,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700, height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown after a workshop signs in or registers before an admin approved the account.
class PendingApprovalCard extends StatelessWidget {
  const PendingApprovalCard({super.key, required this.message, this.title, this.onBack});

  final String message;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final VoidCallback? back = onBack;
    return Panel(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
      radius: 20,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            ),
            child: SizedBox(
              width: 70,
              height: 70,
              child: Icon(Icons.schedule_rounded, color: p.warn, size: 36),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title ?? 'حسابك قيد المراجعة',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.warn, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.text, fontSize: 14, height: 1.7),
          ),
          if (back != null) ...<Widget>[
            const SizedBox(height: 18),
            SecondaryButton(label: 'العودة لتسجيل الدخول', onPressed: back, compact: true),
          ],
        ],
      ),
    );
  }
}
