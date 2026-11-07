import 'package:flutter/material.dart' hide Text;

import '../../core/referral.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/part_plate.dart';
import 'unified_auth_screen.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key, this.initialReferral});
  final ReferralInput? initialReferral;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  static const String _seenKey = 'euro_intro_seen_v1';
  bool? _seen;
  int _page = 0;

  static const List<_IntroPage> _pages = <_IntroPage>[
    _IntroPage(Icons.search_rounded, 'كل القطع بمكان واحد', 'ابحث عن قطع غيار السيارات الأوروبية بسهولة عبر رقم القطعة أو رقم الهيكل VIN.'),
    _IntroPage(Icons.directions_car_filled_rounded, 'نتائج أدق لسيارتك', 'احفظ مركباتك وارجع لمعلوماتها وقت ما تحتاج، بدون إعادة إدخال البيانات.'),
    _IntroPage(Icons.local_shipping_rounded, 'تابع طلبك خطوة بخطوة', 'أرسل طلب القطعة وتابع مراحل التجهيز والشحن والتسليم من داخل التطبيق.'),
    _IntroPage(Icons.handshake_rounded, 'خدمات مخصصة لحسابك', 'أنشئ حساب ورشة أو مسوّق للوصول إلى خدمات EURO ومزايا الحساب.'),
  ];

  @override
  void initState() {
    super.initState();
    _loadIntroState();
  }

  Future<void> _loadIntroState() async {
    if (widget.initialReferral?.isSigned == true) {
      if (mounted) setState(() => _seen = true);
      return;
    }
    final value = await AppScope.read(context).store.read(_seenKey);
    if (mounted) setState(() => _seen = value == '1');
  }

  Future<void> _finishIntro() async {
    await AppScope.read(context).store.write(_seenKey, '1');
    if (mounted) setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_seen!) return UnifiedAuthScreen(initialReferral: widget.initialReferral);

    final Palette p = Palette.of(context);
    final item = _pages[_page];
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
            child: Column(
              children: [
                const Align(alignment: AlignmentDirectional.center, child: BrandMark(size: 42)),
                const SizedBox(height: 8),
                Text('EURO CARS', style: TextStyle(color: p.muted, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey<int>(_page),
                          width: 218,
                          height: 218,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.primary.withValues(alpha: 0.10),
                            border: Border.all(color: p.primary.withValues(alpha: 0.28), width: 1.5),
                          ),
                          child: Center(
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.panel,
                                boxShadow: [BoxShadow(color: p.primary.withValues(alpha: 0.12), blurRadius: 28)],
                              ),
                              child: Icon(item.icon, size: 68, color: p.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Column(
                          key: ValueKey<String>(item.title),
                          children: [
                            Text(item.title, textAlign: TextAlign.center,
                              style: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 14),
                            Text(item.description, textAlign: TextAlign.center,
                              style: TextStyle(color: p.muted, fontSize: 15, height: 1.8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _page ? 24 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index == _page ? p.primary : p.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  )),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_page == _pages.length - 1) {
                        _finishIntro();
                      } else {
                        setState(() => _page++);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: p.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_page == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
                TextButton(
                  onPressed: _finishIntro,
                  child: Text('تخطي', style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPage {
  const _IntroPage(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}
