// About EURO: who we are, where we are, how to reach us, and the two social links (original Instagram and TikTok
// icons from the Font Awesome library; the icons are the only content of that row).

import 'package:flutter/material.dart' hide Text;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/config.dart';
import '../../core/display.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/part_plate.dart';
import '../../widgets/pickers.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tx.dart';

/// Opens the About page.
void openAbout(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext routeContext) => const AboutScreen()),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url, String failure) async {
    final bool opened = await openExternalUrl(url);
    if (!opened && context.mounted) {
      showSnack(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String address = DisplayPrefs.isEnglish ? companyAddressEn : companyAddressAr;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'عن EURO'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                child: Column(
                  children: <Widget>[
                    const BrandMark(size: 40),
                    const SizedBox(height: 6),
                    Text(
                      'EURO CARS',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: p.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      companyNameAr,
                      style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'قطع غيار السيارات للورش والمسوّقين',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 14, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  children: <Widget>[
                    _ContactRow(
                      icon: Icons.location_on_outlined,
                      label: 'العنوان',
                      value: address,
                    ),
                    Divider(height: 1, color: p.line),
                    _ContactRow(
                      icon: Icons.chat_outlined,
                      iconColor: p.ok,
                      label: 'الدعم عبر واتساب',
                      value: '+$supportWhatsApp',
                      ltr: true,
                      onTap: () => _open(context, supportUrl(), 'تعذر فتح واتساب. تأكد من تثبيته على الجهاز.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'تواصل معنا عبر واتساب',
                icon: Icons.support_agent_rounded,
                onPressed: () => _open(context, supportUrl(), 'تعذر فتح واتساب. تأكد من تثبيته على الجهاز.'),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _SocialIcon(
                    icon: FontAwesomeIcons.instagram,
                    color: const Color(0xFFE4405F),
                    onTap: () => _open(context, instagramUrl, 'تعذر فتح الرابط.'),
                  ),
                  const SizedBox(width: 22),
                  _SocialIcon(
                    icon: FontAwesomeIcons.tiktok,
                    color: p.text,
                    onTap: () => _open(context, tiktokUrl, 'تعذر فتح الرابط.'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.ltr = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool ltr;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: iconColor ?? p.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: TextStyle(color: p.muted, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    textDirection: ltr ? TextDirection.ltr : null,
                    textAlign: TextAlign.start,
                    style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_left_rounded, color: p.placeholder),
          ],
        ),
      ),
    );
  }
}

/// A round button that holds only the brand icon (no name, no caption).
class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.icon, required this.color, required this.onTap});

  final FaIconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return PressScale(
      child: Material(
        color: p.btn2Bg,
        shape: CircleBorder(side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 58,
            height: 58,
            child: Center(child: FaIcon(icon, color: color, size: 26)),
          ),
        ),
      ),
    );
  }
}
