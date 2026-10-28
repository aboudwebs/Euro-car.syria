// The signed-in area: five tabs behind a bottom navigation bar, under the web app's glass top bar (wordmark, the
// signed-in user and the light / dark switch).
//
// Tabs are built the first time they are opened, so the orders and dashboard requests are only made when the
// user actually looks at them. The tab index lives in AppState, so any screen can switch tabs.

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/inputs.dart';
import '../../widgets/part_plate.dart';
import '../account/account_screen.dart';
import '../cart/cart_screen.dart';
import '../catalog/catalog_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../orders/orders_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const List<Widget> _screens = <Widget>[
    CatalogScreen(),
    CartScreen(),
    OrdersScreen(),
    DashboardScreen(),
    AccountScreen(),
  ];

  /// Tabs that were opened at least once; the others are not built until they are needed.
  final Set<int> _opened = <int>{tabCatalog};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      AppScope.read(context).refreshOnResume();
    }
  }

  void _selectTab(AppState state, int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    state.selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Palette p = Palette.of(context);
    final int tab = state.selectedTab;
    _opened.add(tab);
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final int cartCount = state.cartItemCount;

    return PopScope(
      canPop: tab == tabCatalog,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          state.selectTab(tabCatalog);
        }
      },
      child: AppBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: <Widget>[
              _TopBar(onOpenAccount: () => _selectTab(state, tabAccount)),
              Expanded(
                child: IndexedStack(
                  index: tab,
                  children: <Widget>[
                    for (int i = 0; i < _screens.length; i++)
                      TickerMode(
                        enabled: i == tab,
                        child: _opened.contains(i) ? _screens[i] : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: keyboardOpen
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: p.barLine))),
                  child: NavigationBar(
                    selectedIndex: tab,
                    onDestinationSelected: (int index) => _selectTab(state, index),
                    destinations: <Widget>[
                      const NavigationDestination(
                        icon: Icon(Icons.storefront_outlined),
                        selectedIcon: Icon(Icons.storefront_rounded),
                        label: 'الكتالوج',
                      ),
                      NavigationDestination(
                        icon: _CartIcon(count: cartCount, selected: false),
                        selectedIcon: _CartIcon(count: cartCount, selected: true),
                        label: 'السلة',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded),
                        label: 'طلباتي',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.insights_outlined),
                        selectedIcon: Icon(Icons.insights_rounded),
                        label: 'لوحتي',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'حسابي',
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The glass header of the web app: the wordmark at the start; the signed-in user (opens the account tab) and the
/// light / dark switch at the end.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onOpenAccount});

  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final AppUser? user = state.user;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String who = user == null
        ? ''
        : '${user.name} (${user.isWorkshop ? 'ورشة' : 'عميل/مسوّق'})';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.barBg,
        border: Border(bottom: BorderSide(color: p.barLine)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
          child: Row(
            children: <Widget>[
              const BrandMark(size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (who.isNotEmpty)
                        Flexible(
                          child: _UserChip(label: who, onTap: onOpenAccount),
                        ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        tooltip: 'تبديل الوضع',
                        onTap: () => state.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Material(
      color: p.btn2Bg,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.how_to_reg_outlined, size: 16, color: p.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cart icon with the number of units in the cart, on the web app's blue gradient badge.
class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Icon icon = Icon(selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined);
    if (count <= 0) {
      return icon;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        icon,
        PositionedDirectional(
          top: -6,
          end: -10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[accentGradientTop, accentGradientBottom],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x73007AFF), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
