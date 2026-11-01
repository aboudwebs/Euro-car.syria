// The root widget: owns the application state, applies the theme and decides which area to show
// (startup spinner, sign-in / registration, or the main app).

import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session_store.dart';
import 'core/referral.dart';
import 'screens/auth/auth_flow.dart';
import 'screens/home/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/palette.dart';
import 'widgets/backdrop.dart';
import 'widgets/part_plate.dart';
import 'widgets/tx.dart';

class EuroApp extends StatefulWidget {
  /// [store] and [httpClient] exist so tests can run the whole app without a device or a network.
  const EuroApp({super.key, this.store, this.httpClient});

  final SessionStore? store;
  final http.Client? httpClient;

  @override
  State<EuroApp> createState() => _EuroAppState();
}

class _EuroAppState extends State<EuroApp> with WidgetsBindingObserver {
  late final AppState _state;
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lightTheme = buildTheme(Brightness.light);
    _darkTheme = buildTheme(Brightness.dark);
    _state = AppState(
      api: ApiClient(baseUrl: apiBase, client: widget.httpClient),
      store: widget.store ?? SecureSessionStore(),
    );
    unawaited(_state.restore());
    unawaited(_initializeAppLinks());
  }

  Future<void> _initializeAppLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleAppLink, onError: (Object error) {
      debugPrint('EURO referral link stream error: $error');
    });
    try {
      final Uri? initial = await _appLinks.getInitialLink();
      if (initial != null) _handleAppLink(initial);
    } catch (error) {
      debugPrint('EURO initial referral link error: $error');
    }
  }

  void _handleAppLink(Uri uri) {
    if (uri.scheme != 'eurocars' || uri.host != 'referral') return;
    final ReferralInput referral = parseReferral(uri.toString());
    if (referral.isSigned) _state.setPendingReferral(referral);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _state.refreshOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_linkSubscription?.cancel());
    _state.dispose();
    _state.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp(
            // A new key rebuilds the whole tree when the language or the displayed currency changes, so every
            // screen (also the ones holding already formatted prices) shows the new choice.
            key: ValueKey<int>(_state.displayVersion),
            title: 'EURO CARS',
            debugShowCheckedModeBanner: false,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeMode: _state.themeMode,
            locale: Locale(_state.language),
            supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: _withSystemBars,
            home: const _Gate(),
          );
        },
      ),
    );
  }

  /// Keeps the status and navigation bars readable in both themes.
  Widget _withSystemBars(BuildContext context, Widget? child) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Palette p = dark ? Palette.dark : Palette.light;
    final SystemUiOverlayStyle style = (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: dark ? p.bg : p.panel,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: child ?? const SizedBox.shrink(),
    );
  }
}

/// Chooses the area to show from the session status.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    switch (state.status) {
      case SessionStatus.restoring:
        return const _Splash();
      case SessionStatus.signedOut:
        return AuthFlow(initialReferral: state.takePendingReferral());
      case SessionStatus.signedIn:
        return const HomeShell();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const BrandMark(size: 34),
              const SizedBox(height: 28),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 14),
              Text('جاري تحميل اليورو...', style: TextStyle(color: p.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
