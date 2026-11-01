// Application state: session, catalog, cart, orders, dashboards and profile.
//
// One ChangeNotifier keeps the screens simple. Every network call goes through ApiClient, every local value
// through SessionStore, so the whole class can be tested with a mock HTTP client and an in-memory store.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/cart.dart';
import '../core/config.dart';
import '../core/display.dart';
import '../core/images.dart';
import '../core/json_utils.dart';
import '../core/models.dart';
import '../core/push_notifications.dart';
import '../core/session_store.dart';
import '../core/text_utils.dart';

enum SessionStatus { restoring, signedOut, signedIn }

/// Positions of the main tabs in the bottom navigation bar.
const int tabCatalog = 0;
const int tabCart = 1;
const int tabOrders = 2;
const int tabDashboard = 3;
const int tabAccount = 4;

/// What the orders tab lists: the catalog orders or the special requests.
enum OrdersView { orders, requests }

class AppState extends ChangeNotifier {
  AppState({required this.api, required this.store}) {
    api.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient api;
  final SessionStore store;

  bool _disposed = false;

  /// Bumped whenever a session starts or ends, so answers to old requests are ignored.
  int _epoch = 0;

  SessionStatus _status = SessionStatus.restoring;
  AppUser? _user;
  String? _sessionNotice;
  ThemeMode _themeMode = ThemeMode.dark;

  List<Part> _parts = const <Part>[];
  bool _partsLoading = false;
  bool _partsLoaded = false;
  String? _partsError;

  final Map<String, int> _cart = <String, int>{};
  String? _cartNotice;
  Future<void> _cartWrites = Future<void>.value();

  List<Order> _orders = const <Order>[];
  List<UserNotification> _notifications = const <UserNotification>[];
  bool _notificationsLoading = false;
  String? _notificationsError;
  Timer? _notificationsTimer;
  bool _ordersLoading = false;
  bool _ordersLoaded = false;
  String? _ordersError;

  List<SpecialRequest> _requests = const <SpecialRequest>[];
  bool _requestsLoading = false;
  bool _requestsLoaded = false;
  String? _requestsError;

  WorkshopDashboard? _workshopDashboard;
  MarketerDashboard? _marketerDashboard;
  bool _dashboardLoading = false;
  String? _dashboardError;

  Uint8List? _avatarBytes;
  DateTime? _lastResumeRefresh;

  // Display preferences (device-wide, kept across sign-outs) and what makes the whole UI rebuild when they change.
  String _language = languageArabic;
  String _currency = currencyUsd;
  int _displayVersion = 0;
  bool _canUseSypInvoices = false;
  double? _invoiceRate;

  List<SavedAddress> _addresses = const <SavedAddress>[];
  bool _addressesLoaded = false;
  bool _addressesLoading = false;
  String? _addressesError;
  bool _addressesReady = true;
  String? _checkoutAddressId;

  List<SavedVehicle> _vehicles = const <SavedVehicle>[];
  bool _vehiclesLoaded = false;
  bool _vehiclesLoading = false;
  String? _vehiclesError;
  bool _vehiclesReady = true;

  DeletionRequest? _deletion;
  bool _deletionLoaded = false;

  /// A catalog search requested from another screen (a scanned or saved VIN); the catalog tab picks it up once.
  String? _pendingCatalogQuery;

  int _tab = tabCatalog;
  OrdersView _ordersView = OrdersView.orders;

  // ---------------------------------------------------------------- read-only view for the screens

  SessionStatus get status => _status;
  AppUser? get user => _user;
  bool get isSignedIn => _status == SessionStatus.signedIn && _user != null;
  String? get sessionNotice => _sessionNotice;
  ThemeMode get themeMode => _themeMode;

  List<Part> get parts => _parts;
  bool get partsLoading => _partsLoading;
  bool get partsLoaded => _partsLoaded;
  String? get partsError => _partsError;

  Map<String, int> get cartItems => Map<String, int>.unmodifiable(_cart);
  String? get cartNotice => _cartNotice;
  int qtyInCart(String partId) => _cart[partId] ?? 0;

  /// Cart entries joined with the catalog (entries whose part is not in the catalog are left out).
  List<CartLine> get cartLines {
    final List<CartLine> lines = <CartLine>[];
    for (final Part part in _parts) {
      final int qty = _cart[part.id] ?? 0;
      if (qty > 0) {
        lines.add(CartLine(part, qty));
      }
    }
    return lines;
  }

  double get cartTotalAmount => cartTotal(cartLines);

  /// Units in the cart, as shown on the badge.
  int get cartItemCount {
    if (!_partsLoaded) {
      return cartCount(_cart);
    }
    int count = 0;
    for (final CartLine line in cartLines) {
      count += line.qty;
    }
    return count;
  }

  List<Order> get orders => _orders;
  List<UserNotification> get notifications => _notifications;
  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;
  bool get notificationsLoading => _notificationsLoading;
  String? get notificationsError => _notificationsError;
  bool get ordersLoading => _ordersLoading;
  bool get ordersLoaded => _ordersLoaded;
  String? get ordersError => _ordersError;

  List<SpecialRequest> get requests => _requests;
  bool get requestsLoading => _requestsLoading;
  bool get requestsLoaded => _requestsLoaded;
  String? get requestsError => _requestsError;

  WorkshopDashboard? get workshopDashboard => _workshopDashboard;
  MarketerDashboard? get marketerDashboard => _marketerDashboard;
  bool get dashboardLoading => _dashboardLoading;
  bool get dashboardLoaded => _workshopDashboard != null || _marketerDashboard != null;
  String? get dashboardError => _dashboardError;

  Uint8List? get avatarBytes => _avatarBytes;

  int get selectedTab => _tab;
  OrdersView get ordersView => _ordersView;

  String get language => _language;
  String get currency => _currency;

  /// Changes whenever the language or the displayed currency changes; the app rebuilds its tree on it.
  int get displayVersion => _displayVersion;

  /// True once the admin has published a USD to SYP rate, so prices can be shown in Syrian pounds.
  bool get canShowSyp => (DisplayPrefs.sypRate ?? 0) > 0;
  bool get canUseSypInvoices => _canUseSypInvoices && (_invoiceRate ?? 0) > 0;
  double? get invoiceRate => canUseSypInvoices ? _invoiceRate : null;

  List<SavedAddress> get addresses => _addresses;
  bool get addressesLoaded => _addressesLoaded;
  bool get addressesLoading => _addressesLoading;
  String? get addressesError => _addressesError;

  /// False when the server answered that the saved-address feature is not installed yet (SQL update pending).
  bool get addressesReady => _addressesReady;

  /// The address that will be attached to the next order: the one picked in the cart, else the default one.
  SavedAddress? get checkoutAddress {
    if (_addresses.isEmpty) {
      return null;
    }
    final String? picked = _checkoutAddressId;
    for (final SavedAddress address in _addresses) {
      if (address.id == picked) {
        return address;
      }
    }
    for (final SavedAddress address in _addresses) {
      if (address.isDefault) {
        return address;
      }
    }
    return _addresses.first;
  }

  List<SavedVehicle> get vehicles => _vehicles;
  bool get vehiclesLoaded => _vehiclesLoaded;
  bool get vehiclesLoading => _vehiclesLoading;
  String? get vehiclesError => _vehiclesError;
  bool get vehiclesReady => _vehiclesReady;

  /// The pending account deletion, or null when none (or not loaded yet).
  DeletionRequest? get deletion => _deletion;
  bool get deletionLoaded => _deletionLoaded;

  List<Order> get activeOrders => _orders.where((Order o) => o.isActive).toList();
  List<Order> get previousOrders => _orders.where((Order o) => !o.isActive).toList();

  String? get pendingCatalogQuery => _pendingCatalogQuery;

  // ---------------------------------------------------------------- navigation

  /// Switches the main tab and quietly refreshes the data that tab shows.
  void selectTab(int index) {
    final AppUser? current = _user;
    if (current == null || index < tabCatalog || index > tabAccount) {
      return;
    }
    if (index != _tab) {
      _tab = index;
      notifyListeners();
    }
    if (index == tabCart) {
      unawaited(loadSettings());
      // Stock may have changed, and a workshop needs its current debt balance to offer the debt ledger.
      unawaited(loadParts(silent: true));
      if (current.isWorkshop) {
        unawaited(loadDashboard(silent: true));
      }
    } else if (index == tabOrders) {
      unawaited(loadOrders(silent: true));
      unawaited(loadRequests(silent: true));
    } else if (index == tabDashboard) {
      unawaited(loadDashboard(silent: true));
    } else if (index == tabAccount) {
      unawaited(loadNotifications(silent: true));
    }
  }

  void setOrdersView(OrdersView view) {
    if (view != _ordersView) {
      _ordersView = view;
      notifyListeners();
    }
  }

  /// Opens the orders tab on the list of special requests.
  void showSpecialRequests() {
    setOrdersView(OrdersView.requests);
    selectTab(tabOrders);
  }

  // ---------------------------------------------------------------- lifecycle

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _notificationsTimer?.cancel();
    _notificationsTimer = null;
    api.onUnauthorized = null;
    super.dispose();
  }

  /// Reads the saved theme and session. Never throws: a keystore error (for example after a device restore)
  /// simply leads to the sign-in screen instead of an endless spinner.
  Future<void> restore() async {
    _themeMode = _themeFromName(await _safeRead(themeKey));
    _language = (await _safeRead(languageKey)) == languageEnglish ? languageEnglish : languageArabic;
    _currency = (await _safeRead(currencyKey)) == currencySyp ? currencySyp : currencyUsd;
    _applyDisplayPrefs();

    final String? savedToken = await _safeRead(tokenKey);
    final String? savedUser = await _safeRead(userKey);
    final AppUser? restored = (savedToken != null && savedToken.isNotEmpty && savedUser != null)
        ? _parseStoredUser(savedUser)
        : null;

    if (savedToken == null || restored == null) {
      if (savedToken != null || savedUser != null) {
        // Unreadable or incomplete session: clean it up instead of failing later.
        await _safeDelete(tokenKey);
        await _safeDelete(userKey);
      }
      _status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }

    _beginSession(savedToken, restored);
    await _restoreCart();
    notifyListeners();
    _loadAfterSignIn();
  }

  AppUser? _parseStoredUser(String text) {
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final AppUser parsed = AppUser.fromJson(decoded);
      return parsed.id.isNotEmpty && parsed.isCustomer ? parsed : null;
    } on FormatException {
      return null;
    }
  }

  void _beginSession(String token, AppUser account) {
    _epoch++;
    api.token = token;
    _user = account;
    _status = SessionStatus.signedIn;
    _sessionNotice = null;
    _resetData();
  }

  void _resetData() {
    _canUseSypInvoices = false;
    _invoiceRate = null;
    _parts = const <Part>[];
    _partsLoading = false;
    _partsLoaded = false;
    _partsError = null;
    _cart.clear();
    _cartNotice = null;
    _orders = const <Order>[];
    _notifications = const <UserNotification>[];
    _notificationsLoading = false;
    _notificationsError = null;
    _ordersLoading = false;
    _ordersLoaded = false;
    _ordersError = null;
    _requests = const <SpecialRequest>[];
    _requestsLoading = false;
    _requestsLoaded = false;
    _requestsError = null;
    _workshopDashboard = null;
    _marketerDashboard = null;
    _dashboardLoading = false;
    _dashboardError = null;
    _avatarBytes = null;
    _lastResumeRefresh = null;
    _tab = tabCatalog;
    _ordersView = OrdersView.orders;
    _addresses = const <SavedAddress>[];
    _addressesLoaded = false;
    _addressesLoading = false;
    _addressesError = null;
    _addressesReady = true;
    _checkoutAddressId = null;
    _vehicles = const <SavedVehicle>[];
    _vehiclesLoaded = false;
    _vehiclesLoading = false;
    _vehiclesError = null;
    _vehiclesReady = true;
    _deletion = null;
    _deletionLoaded = false;
    _pendingCatalogQuery = null;
  }

  void _loadAfterSignIn() {
    unawaited(_registerPushToken());
    _notificationsTimer?.cancel();
    _notificationsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_user != null) unawaited(loadNotifications(silent: true));
    });
    unawaited(loadParts());
    unawaited(loadAvatar());
    unawaited(refreshProfile());
    unawaited(loadSettings());
    unawaited(loadAddresses(silent: true));
    unawaited(loadVehicles(silent: true));
    unawaited(loadDeletion(silent: true));
    unawaited(loadNotifications(silent: true));
  }

  Future<void> _registerPushToken() async {
    final int epoch = _epoch;
    final String? pushToken = await PushNotifications.requestPermissionAndGetToken();
    if (pushToken == null || pushToken.isEmpty || epoch != _epoch || !isSignedIn) return;
    try {
      await api.postJson('/api/push/register', <String, dynamic>{'token': pushToken});
    } catch (_) {
      // Push registration is best-effort; it must never block sign-in or app startup.
    }
  }

  // ---------------------------------------------------------------- sign in / register / sign out

  Future<AuthResult> login({
    required String role,
    required String phone,
    required String password,
  }) async {
    try {
      final Map<String, dynamic> data = await api.postJson(
        '/api/auth',
        <String, dynamic>{
          'mode': 'login',
          'client': 'mobile',
          'role': role,
          'phone': phone.trim(),
          'password': password,
        },
        auth: false,
      );
      return await _completeSignIn(data);
    } on ApiException catch (error) {
      if (error.pendingApproval) {
        return AuthResult(AuthResultKind.pendingApproval, error.message);
      }
      return AuthResult(AuthResultKind.failed, error.message);
    } catch (_) {
      return const AuthResult(AuthResultKind.failed, unexpectedMessage);
    }
  }

  /// Requests a WhatsApp verification code before account creation.
  Future<String> requestRegistrationOtp({required String phone}) async {
    final Map<String, dynamic> data = await api.postJson(
      '/api/auth',
      <String, dynamic>{
        'mode': 'send-otp',
        'client': 'mobile',
        'phone': canonicalPhone(phone),
      },
      auth: false,
    );
    final Object? token = data['otpToken'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('لم يرجع الخادم رمز تحقق صالحاً. حاول مجدداً.');
    }
    return token;
  }

  /// Creates an account. A workshop must be approved by an admin first (pending result); a marketer is signed in
  /// immediately. [refCode] / [refSignature] come from a marketer's signed invitation link.
  Future<AuthResult> register({
    required String role,
    required String name,
    required String phone,
    required String password,
    String license = '',
    String city = '',
    String specs = '',
    String refCode = '',
    String refSignature = '',
    required String otpCode,
    required String otpToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'mode': 'register',
      'client': 'mobile',
      'role': role,
      'name': name.trim(),
      'phone': canonicalPhone(phone),
      'password': password,
      'otpCode': toWesternDigits(otpCode).trim(),
      'otpToken': otpToken,
    };
    if (role == 'workshop') {
      body['license'] = license.trim();
      body['city'] = city.trim();
      body['spec'] = specs;
      if (refCode.trim().isNotEmpty) {
        body['refCode'] = refCode.trim();
      }
      if (refSignature.trim().isNotEmpty) {
        body['refSignature'] = refSignature.trim();
      }
    }
    try {
      final Map<String, dynamic> data = await api.postJson('/api/auth', body, auth: false);
      if (data['pendingApproval'] == true) {
        return AuthResult(
          AuthResultKind.pendingApproval,
          asString(
            data['message'],
            'تم إرسال طلب تسجيل الورشة للإدارة. سيتم تفعيل الحساب بعد مراجعة البيانات.',
          ),
        );
      }
      return await _completeSignIn(data);
    } on ApiException catch (error) {
      if (error.pendingApproval) {
        return AuthResult(AuthResultKind.pendingApproval, error.message);
      }
      return AuthResult(AuthResultKind.failed, error.message);
    } catch (_) {
      return const AuthResult(AuthResultKind.failed, unexpectedMessage);
    }
  }

  Future<AuthResult> _completeSignIn(Map<String, dynamic> data) async {
    final Object? tokenValue = data['accessToken'];
    final Object? userValue = data['user'];
    if (tokenValue is! String || tokenValue.isEmpty || userValue is! Map) {
      return const AuthResult(AuthResultKind.failed, 'الخادم لم يرجع جلسة تطبيق صالحة');
    }
    final AppUser account = AppUser.fromJson(asMap(userValue));
    if (account.id.isEmpty || !account.isCustomer) {
      return const AuthResult(AuthResultKind.failed, 'هذا النوع من الحسابات غير متاح في التطبيق.');
    }
    await _safeWrite(tokenKey, tokenValue);
    await _safeWrite(userKey, jsonEncode(account.toJson()));
    _beginSession(tokenValue, account);
    await _restoreCart();
    notifyListeners();
    _loadAfterSignIn();
    return const AuthResult(AuthResultKind.signedIn);
  }

  /// Signs out on purpose: the saved cart is cleared too.
  Future<void> logout() => _endSession(clearCart: true);

  void _handleUnauthorized() {
    if (_status != SessionStatus.signedIn) {
      return;
    }
    unawaited(
      _endSession(
        clearCart: false,
        notice: 'انتهت جلسة الدخول. سجّل الدخول مجدداً للمتابعة.',
      ),
    );
  }

  Future<void> _endSession({required bool clearCart, String? notice}) async {
    _notificationsTimer?.cancel();
    _notificationsTimer = null;
    _epoch++;
    api.token = null;
    _user = null;
    _status = SessionStatus.signedOut;
    _sessionNotice = notice;
    _resetData();
    notifyListeners();
    await _safeDelete(tokenKey);
    await _safeDelete(userKey);
    if (clearCart) {
      await _safeDelete(cartKey);
    }
  }

  void dismissSessionNotice() {
    if (_sessionNotice != null) {
      _sessionNotice = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- theme

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    unawaited(_safeWrite(themeKey, _themeName(mode)));
  }

  static String _themeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode _themeFromName(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  // ---------------------------------------------------------------- language and currency

  void _applyDisplayPrefs() {
    DisplayPrefs.language = _language;
    DisplayPrefs.currency = _currency;
  }

  /// Switches the interface between Arabic and English. The app rebuilds as a whole (see [displayVersion]).
  void setLanguage(String code) {
    final String next = code == languageEnglish ? languageEnglish : languageArabic;
    if (next == _language) {
      return;
    }
    _language = next;
    _applyDisplayPrefs();
    _displayVersion++;
    notifyListeners();
    unawaited(_safeWrite(languageKey, next));
  }

  /// Chooses the currency prices are shown in. Returns false when Syrian pounds were asked for but the admin has
  /// not published an exchange rate yet (the choice is then left unchanged).
  bool setCurrency(String code) {
    final String next = code == currencySyp ? currencySyp : currencyUsd;
    if (next == currencySyp && !canShowSyp) {
      return false;
    }
    if (next != _currency) {
      _currency = next;
      _applyDisplayPrefs();
      _displayVersion++;
      notifyListeners();
      unawaited(_safeWrite(currencyKey, next));
    }
    return true;
  }

  /// Reads the exchange rate the admin published (GET /api/settings). Quiet: without a rate prices stay in dollars.
  Future<void> loadSettings() async {
    if (_user == null) {
      return;
    }
    final int epoch = _epoch;
    try {
      final Map<String, dynamic> data = await api.getJson('/api/settings');
      if (epoch != _epoch) {
        return;
      }
      final double? rate = asDouble(data['usdToSyp']);
      final double? next = (rate != null && rate > 0) ? rate : null;
      final bool wasShowing = DisplayPrefs.showSyp;
      final double? previous = DisplayPrefs.sypRate;
      final bool previousInvoiceReady = _canUseSypInvoices;
      final double? previousInvoiceRate = _invoiceRate;
      _canUseSypInvoices = data['canUseSypInvoices'] == true && next != null;
      _invoiceRate = next;
      DisplayPrefs.sypRate = next;
      if (DisplayPrefs.showSyp != wasShowing || (DisplayPrefs.showSyp && previous != next) ||
          previousInvoiceReady != _canUseSypInvoices || previousInvoiceRate != _invoiceRate) {
        _displayVersion++;
      }
      notifyListeners();
    } catch (_) {
      // Invoice currency must fail closed when the current stability check cannot be reached.
      _canUseSypInvoices = false;
      _invoiceRate = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- loading helpers

  /// Runs one read request and reports its progress. Quiet refreshes ([silent]) of data already on screen
  /// do not flash a spinner or an error banner.
  Future<void> _runLoad<T>({
    required bool silent,
    required bool hasData,
    required Future<T> Function() fetch,
    required void Function(T value) apply,
    required void Function(bool loading, String? error) report,
  }) async {
    if (_user == null) {
      return;
    }
    final int epoch = _epoch;
    final bool visible = !silent || !hasData;
    if (visible) {
      report(true, null);
      notifyListeners();
    }
    try {
      final T value = await fetch();
      if (epoch != _epoch) {
        return;
      }
      apply(value);
      report(false, null);
    } on ApiException catch (error) {
      if (epoch != _epoch) {
        return;
      }
      report(false, visible ? error.message : null);
    } catch (_) {
      if (epoch != _epoch) {
        return;
      }
      report(false, visible ? unexpectedMessage : null);
    }
    notifyListeners();
  }

  /// Converts anything unexpected into a message that can be shown to the user.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(unexpectedMessage);
    }
  }

  // ---------------------------------------------------------------- catalog

  Future<void> loadParts({bool silent = false}) {
    return _runLoad<List<Part>>(
      silent: silent,
      hasData: _partsLoaded,
      fetch: () async {
        final Map<String, dynamic> data = await api.getJson('/api/parts');
        return asList(data['parts'])
            .map((Object? e) => Part.fromJson(asMap(e)))
            .where((Part p) => p.id.isNotEmpty)
            .toList();
      },
      apply: (List<Part> list) {
        _parts = list;
        _partsLoaded = true;
        _reconcileCart();
      },
      report: (bool loading, String? error) {
        _partsLoading = loading;
        _partsError = error;
      },
    );
  }

  // ---------------------------------------------------------------- cart

  /// Adds one unit. Returns a message when it cannot be added, otherwise null.
  String? addToCart(Part part) {
    if (!part.inStock) {
      return 'هذه القطعة غير متوفرة حالياً.';
    }
    final int current = _cart[part.id] ?? 0;
    if (current >= part.maxOrderQty) {
      return 'وصلت إلى أقصى كمية متاحة من هذه القطعة.';
    }
    if (current == 0 && _cart.length >= maxCartLines) {
      return 'لا يمكن إضافة أكثر من $maxCartLines صنفاً في الطلب الواحد.';
    }
    _cart[part.id] = current + 1;
    _cartNotice = null;
    _persistCart();
    notifyListeners();
    return null;
  }

  void decrementCart(String partId) {
    final int current = _cart[partId] ?? 0;
    if (current <= 1) {
      _cart.remove(partId);
    } else {
      _cart[partId] = current - 1;
    }
    _persistCart();
    notifyListeners();
  }

  void removeFromCart(String partId) {
    if (_cart.remove(partId) != null) {
      _persistCart();
      notifyListeners();
    }
  }

  void clearCart() {
    if (_cart.isEmpty && _cartNotice == null) {
      return;
    }
    _cart.clear();
    _cartNotice = null;
    _persistCart();
    notifyListeners();
  }

  void dismissCartNotice() {
    if (_cartNotice != null) {
      _cartNotice = null;
      notifyListeners();
    }
  }

  /// Drops cart entries whose part vanished or ran out, and lowers quantities to the stock on hand.
  void _reconcileCart() {
    if (_cart.isEmpty) {
      return;
    }
    final Map<String, Part> byId = <String, Part>{for (final Part p in _parts) p.id: p};
    bool changed = false;
    for (final String id in List<String>.from(_cart.keys)) {
      final Part? part = byId[id];
      final int qty = _cart[id] ?? 0;
      if (part == null || !part.inStock) {
        _cart.remove(id);
        changed = true;
      } else if (qty > part.maxOrderQty) {
        _cart[id] = part.maxOrderQty;
        changed = true;
      }
    }
    if (changed) {
      _cartNotice = 'تم تحديث السلة حسب القطع المتوفرة حالياً في المخزون.';
      _persistCart();
    }
  }

  void _persistCart() {
    final AppUser? current = _user;
    if (current == null) {
      return;
    }
    final String? payload = _cart.isEmpty
        ? null
        : jsonEncode(<String, dynamic>{'uid': current.id, 'items': _cart});
    _cartWrites = _cartWrites.then((_) async {
      try {
        if (payload == null) {
          await store.delete(cartKey);
        } else {
          await store.write(cartKey, payload);
        }
      } catch (_) {
        // Saving the cart is best effort; the in-memory cart is unaffected.
      }
    });
  }

  Future<void> _restoreCart() async {
    final AppUser? current = _user;
    if (current == null) {
      return;
    }
    final String? saved = await _safeRead(cartKey);
    if (saved == null || saved.isEmpty) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      if (asString(decoded['uid']) != current.id) {
        return; // this cart belongs to another account
      }
      final Map<String, dynamic> items = asMap(decoded['items']);
      _cart.clear();
      for (final MapEntry<String, dynamic> entry in items.entries) {
        final int? qty = asInt(entry.value);
        if (qty != null && qty > 0 && _cart.length < maxCartLines) {
          _cart[entry.key] = qty > maxLineQuantity ? maxLineQuantity : qty;
        }
      }
    } on FormatException {
      // A damaged saved cart is ignored.
    }
  }

  // ---------------------------------------------------------------- orders and special requests

  Future<void> loadOrders({bool silent = false}) {
    return _runLoad<List<Order>>(
      silent: silent,
      hasData: _ordersLoaded,
      fetch: () async {
        final Map<String, dynamic> data = await api.getJson('/api/orders');
        return asList(data['orders']).map((Object? e) => Order.fromJson(asMap(e))).toList();
      },
      apply: (List<Order> list) {
        _orders = list;
        _ordersLoaded = true;
      },
      report: (bool loading, String? error) {
        _ordersLoading = loading;
        _ordersError = error;
      },
    );
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (_user == null) return;
    final int epoch = _epoch;
    if (!silent) {
      _notificationsLoading = true;
      _notificationsError = null;
      notifyListeners();
    }
    try {
      final Map<String, dynamic> data = await api.getJson('/api/notifications');
      if (epoch != _epoch) return;
      _notifications = asList(data['notifications'])
          .map((Object? e) => UserNotification.fromJson(asMap(e))).toList();
      _notificationsError = null;
    } on ApiException catch (error) {
      if (epoch == _epoch && !silent) _notificationsError = error.message;
    } catch (_) {
      if (epoch == _epoch && !silent) _notificationsError = unexpectedMessage;
    }
    if (epoch == _epoch) {
      _notificationsLoading = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationsRead() async {
    await _guard(() => api.postJson('/api/notifications', <String, dynamic>{'action': 'read_all'}));
    await loadNotifications(silent: true);
  }

  Future<void> cancelOrder(String orderId) async {
    await _guard(() => api.postJson('/api/orders/$orderId/cancel', <String, dynamic>{}));
    await loadOrders(silent: true);
    unawaited(loadDashboard(silent: true));
    unawaited(refreshProfile());
  }

  Future<void> requestMarketerPayout(String payoutDetails) async {
    await _guard(() => api.postJson('/api/marketer/payout', <String, dynamic>{'payoutDetails': payoutDetails}));
    await loadDashboard(silent: true);
  }

  Future<void> loadRequests({bool silent = false}) {
    return _runLoad<List<SpecialRequest>>(
      silent: silent,
      hasData: _requestsLoaded,
      fetch: () async {
        final Map<String, dynamic> data = await api.getJson('/api/special-requests');
        return asList(data['requests'])
            .map((Object? e) => SpecialRequest.fromJson(asMap(e)))
            .toList();
      },
      apply: (List<SpecialRequest> list) {
        _requests = list;
        _requestsLoaded = true;
      },
      report: (bool loading, String? error) {
        _requestsLoading = loading;
        _requestsError = error;
      },
    );
  }

  /// Sends the cart as an order. Prices and totals are computed by the server; only part ids and quantities are
  /// sent. Throws [ApiException] with a message for the user when the order is refused.
  String _newIdempotencyKey() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<PlacedOrder> placeOrder({required String pay, String invoiceCurrency = 'USD', Uint8List? receipt, String? addressId, double cashbackUsed = 0}) async {
    final AppUser? current = _user;
    if (current == null) {
      throw const ApiException('يرجى تسجيل الدخول لإتمام الطلب');
    }
    final List<CartLine> lines = cartLines;
    if (lines.isEmpty) {
      throw const ApiException('السلة فارغة.');
    }
    if (cashbackUsed < 0 || cashbackUsed > cartTotalAmount || cashbackUsed > (current.cashbackBalance ?? 0)) {
      throw const ApiException('قيمة الكاش باك غير صالحة أو الرصيد غير كافٍ.');
    }
    // Normalize full redemption here too, so non-UI callers cannot accidentally send COD with a zero balance due.
    final bool fullyCoveredByCashback =
        cashbackUsed > 0 && (cartTotalAmount - cashbackUsed).abs() < 0.005;
    final String effectivePay = fullyCoveredByCashback ? 'cashback' : pay;
    if (!payMethodsFor(current).contains(effectivePay) &&
        !(effectivePay == 'cashback' && current.isWorkshop)) {
      throw const ApiException('طريقة الدفع هذه غير متاحة لحسابك.');
    }
    if (effectivePay == 'sham' && cartTotalAmount - cashbackUsed > 0 &&
        (receipt == null || receipt.isEmpty)) {
      throw const ApiException('يرجى إرفاق إشعار تحويل شام كاش.');
    }
    if (receipt != null && receipt.length > maxImageBytes) {
      throw const ApiException('حجم الصورة يجب ألا يتجاوز 5 ميغابايت.');
    }

    final Map<String, int> items = <String, int>{
      for (final CartLine line in lines) line.part.id: line.qty,
    };
    final List<UploadFile> files = <UploadFile>[];
    if (effectivePay == 'sham' && cartTotalAmount - cashbackUsed > 0 && receipt != null) {
      files.add(
        UploadFile(
          field: 'receipt',
          bytes: receipt,
          filename: 'receipt.${imageExtension(receipt) ?? 'jpg'}',
        ),
      );
    }

    final String keyName = 'pending_order_key_${current.id}';
    String? idempotencyKey = await _safeRead(keyName);
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      idempotencyKey = _newIdempotencyKey();
      try {
        await store.write(keyName, idempotencyKey);
      } catch (_) {
        throw const ApiException('تعذر حفظ معرّف التأكيد بأمان. تحقق من مساحة التخزين وحاول مجدداً.');
      }
    }

    try {
      final Map<String, dynamic> data = await _guard(
        () => api.postMultipart(
          '/api/orders',
          fields: <String, String>{
            'items': jsonEncode(items),
            'pay': effectivePay,
            'invoiceCurrency': invoiceCurrency,
            'cashbackUsed': cashbackUsed.toStringAsFixed(2),
            if (addressId != null && addressId.isNotEmpty) 'addressId': addressId,
          },
          files: files,
          idempotencyKey: idempotencyKey,
        ),
      );
      final PlacedOrder placed = PlacedOrder.fromJson(data);
      await _safeDelete(keyName);
      clearCart();
      unawaited(loadOrders(silent: true));
      unawaited(refreshProfile());
      unawaited(loadDashboard(silent: true));
      return placed;
    } on ApiException catch (error) {
      if (error.statusCode == 409 && error.message.contains('عملة الفاتورة إلى الدولار')) {
        await loadSettings();
        await _safeDelete(keyName);
      } else if (error.statusCode == 400) {
        // A definitive rejection did not create the order; a changed checkout may use a fresh key.
        await _safeDelete(keyName);
        // Stock or availability changed: refresh the catalog so the cart reflects it.
        unawaited(loadParts(silent: true));
      } else if (error.statusCode != null && error.statusCode! >= 400 && error.statusCode! < 500) {
        await _safeDelete(keyName);
      }
      if (error.network) {
        // The request may have reached the server before the connection dropped; never silently resend it.
        throw ApiException(
          '${error.message}\nقد يكون الطلب وصل رغم ذلك، راجع «طلباتي» قبل إعادة المحاولة لتجنّب تكراره.',
          network: true,
          timedOut: error.timedOut,
        );
      }
      rethrow;
    }
  }

  /// Sends a special request (a part that is not in the catalog) with an optional photo.
  Future<void> submitSpecialRequest({
    required String brand,
    required String partName,
    String otherBrand = '',
    String partNumber = '',
    String notes = '',
    Uint8List? image,
  }) async {
    if (image != null && image.length > maxImageBytes) {
      throw const ApiException('حجم الصورة يجب ألا يتجاوز 5 ميغابايت.');
    }
    final List<UploadFile> files = <UploadFile>[];
    if (image != null && image.isNotEmpty) {
      files.add(
        UploadFile(
          field: 'image',
          bytes: image,
          filename: 'part.${imageExtension(image) ?? 'jpg'}',
        ),
      );
    }
    final AppUser? current = _user;
    if (current == null) throw const ApiException('يرجى تسجيل الدخول أولاً.');
    final String keyName = 'pending_special_request_key_${current.id}';
    String? idempotencyKey = await _safeRead(keyName);
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      idempotencyKey = _newIdempotencyKey();
      try {
        await store.write(keyName, idempotencyKey);
      } catch (_) {
        throw const ApiException('تعذر حفظ معرّف التأكيد بأمان. تحقق من مساحة التخزين وحاول مجدداً.');
      }
    }
    try {
      await _guard(
        () => api.postMultipart(
          '/api/special-requests',
          fields: <String, String>{
            'brand': brand,
            'otherBrand': otherBrand.trim(),
            'partName': partName.trim(),
            'partNumber': partNumber.trim(),
            'notes': notes.trim(),
          },
          files: files,
          idempotencyKey: idempotencyKey,
        ),
      );
      await _safeDelete(keyName);
    } on ApiException catch (error) {
      // Preserve the key on network/server uncertainty; release it only for a definitive client rejection.
      if (error.statusCode != null && error.statusCode! >= 400 && error.statusCode! < 500) {
        await _safeDelete(keyName);
      }
      rethrow;
    }
    unawaited(loadRequests(silent: true));
  }

  // ---------------------------------------------------------------- dashboards

  Future<void> loadDashboard({bool silent = false}) {
    final AppUser? current = _user;
    if (current == null) {
      return Future<void>.value();
    }
    if (current.isMarketer) {
      return _runLoad<MarketerDashboard>(
        silent: silent,
        hasData: _marketerDashboard != null,
        fetch: () async =>
            MarketerDashboard.fromJson(await api.getJson('/api/marketer/dashboard')),
        apply: (MarketerDashboard value) {
          _marketerDashboard = value;
        },
        report: (bool loading, String? error) {
          _dashboardLoading = loading;
          _dashboardError = error;
        },
      );
    }
    return _runLoad<WorkshopDashboard>(
      silent: silent,
      hasData: _workshopDashboard != null,
      fetch: () async =>
          WorkshopDashboard.fromJson(await api.getJson('/api/workshop/dashboard')),
      apply: (WorkshopDashboard value) {
        _workshopDashboard = value;
        _mergeUser(value.userJson);
      },
      report: (bool loading, String? error) {
        _dashboardLoading = loading;
        _dashboardError = error;
      },
    );
  }

  // ---------------------------------------------------------------- profile

  /// Refreshes the saved account from GET /api/auth. Best effort: that endpoint answers "no user" for any
  /// problem, so an empty answer is ignored instead of being treated as a sign-out.
  Future<void> refreshProfile() async {
    final AppUser? current = _user;
    if (current == null) {
      return;
    }
    final int epoch = _epoch;
    try {
      final Map<String, dynamic> data = await api.getProfile();
      if (epoch != _epoch) {
        return;
      }
      final Object? fresh = data['user'];
      if (fresh is Map) {
        _mergeUser(asMap(fresh));
        notifyListeners();
      }
    } catch (_) {
      // Keep the cached account when the refresh fails.
    }
  }

  void _mergeUser(Map<String, dynamic> update) {
    final AppUser? current = _user;
    if (current == null) {
      return;
    }
    final AppUser merged = current.mergedWith(update);
    if (merged.id != current.id || !merged.isCustomer) {
      return;
    }
    _user = merged;
    unawaited(_safeWrite(userKey, jsonEncode(merged.toJson())));
  }

  /// Saves name, governorate and (optionally) a new password. Throws [ApiException] on failure.
  Future<void> updateProfile({
    required String name,
    required String city,
    String newPassword = '',
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'name': name.trim()};
    if (city.trim().isNotEmpty) {
      body['city'] = city.trim();
    }
    if (newPassword.isNotEmpty) {
      body['newPassword'] = newPassword;
    }
    final Map<String, dynamic> data = await _guard(() => api.putProfile(body));
    final Object? fresh = data['user'];
    if (fresh is Map) {
      _mergeUser(asMap(fresh));
    }
    notifyListeners();
  }

  Future<void> loadAvatar() async {
    final int epoch = _epoch;
    try {
      final Uint8List? bytes = await api.fetchAvatar();
      if (epoch != _epoch) {
        return;
      }
      _avatarBytes = bytes;
      notifyListeners();
    } catch (_) {
      // The initials are shown instead of a photo.
    }
  }

  /// Uploads a new profile photo (JPEG, at most 1.5 MB). Throws [ApiException] on failure.
  Future<void> uploadAvatar(Uint8List jpegBytes) async {
    if (!isJpegBytes(jpegBytes)) {
      throw const ApiException('صيغة الصورة غير مدعومة، اختر صورة بصيغة JPG.');
    }
    if (jpegBytes.length > maxAvatarBytes) {
      throw const ApiException('حجم الصورة كبير جداً. اختر صورة أصغر.');
    }
    await _guard(() => api.uploadAvatar(jpegBytes));
    _avatarBytes = jpegBytes;
    notifyListeners();
  }

  // ---------------------------------------------------------------- addresses

  Future<void> loadAddresses({bool silent = false}) {
    bool ready = true;
    return _runLoad<List<SavedAddress>>(
      silent: silent,
      hasData: _addressesLoaded,
      fetch: () async {
        final Map<String, dynamic> data = await api.getJson('/api/account/addresses');
        ready = data['ready'] != false;
        return asList(data['addresses'])
            .map((Object? e) => SavedAddress.fromJson(asMap(e)))
            .where((SavedAddress a) => a.id.isNotEmpty)
            .toList();
      },
      apply: (List<SavedAddress> list) {
        _addresses = list;
        _addressesLoaded = true;
        _addressesReady = ready;
      },
      report: (bool loading, String? error) {
        _addressesLoading = loading;
        _addressesError = error;
      },
    );
  }

  /// Creates ([id] null) or updates a saved address. Throws [ApiException] with a message for the user.
  Future<void> saveAddress({
    String? id,
    required String label,
    String governorate = '',
    String area = '',
    String street = '',
    String details = '',
    String phone = '',
    bool makeDefault = false,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'label': label.trim(),
      'governorate': governorate.trim(),
      'area': area.trim(),
      'street': street.trim(),
      'details': details.trim(),
      'phone': phone.trim(),
      if (makeDefault) 'isDefault': true,
    };
    if (id == null) {
      final AppUser? current = _user;
      if (current == null) throw const ApiException('يرجى تسجيل الدخول أولاً.');
      final String keyName = 'pending_address_key_${current.id}';
      String? key = await _safeRead(keyName);
      if (key == null || key.isEmpty) {
        key = _newIdempotencyKey();
        try {
          await store.write(keyName, key);
        } catch (_) {
          throw const ApiException('تعذر حفظ معرّف التأكيد بأمان. حاول مجدداً.');
        }
      }
      await _guard(() => api.postJson('/api/account/addresses', body, idempotencyKey: key));
      await _safeDelete(keyName);
    } else {
      await _guard(() => api.putJson('/api/account/addresses/$id', body));
    }
    await loadAddresses(silent: true);
  }

  Future<void> deleteAddress(String id) async {
    await _guard(() => api.deleteJson('/api/account/addresses/$id'));
    if (_checkoutAddressId == id) {
      _checkoutAddressId = null;
    }
    await loadAddresses(silent: true);
  }

  Future<void> setDefaultAddress(String id) async {
    await _guard(
      () => api.putJson('/api/account/addresses/$id', <String, dynamic>{'isDefault': true}),
    );
    await loadAddresses(silent: true);
  }

  /// Picks the address attached to the next order (the cart's address chooser).
  void selectCheckoutAddress(String? id) {
    if (id != _checkoutAddressId) {
      _checkoutAddressId = id;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- vehicles

  Future<void> loadVehicles({bool silent = false}) {
    bool ready = true;
    return _runLoad<List<SavedVehicle>>(
      silent: silent,
      hasData: _vehiclesLoaded,
      fetch: () async {
        final Map<String, dynamic> data = await api.getJson('/api/account/vehicles');
        ready = data['ready'] != false;
        return asList(data['vehicles'])
            .map((Object? e) => SavedVehicle.fromJson(asMap(e)))
            .where((SavedVehicle v) => v.id.isNotEmpty)
            .toList();
      },
      apply: (List<SavedVehicle> list) {
        _vehicles = list;
        _vehiclesLoaded = true;
        _vehiclesReady = ready;
      },
      report: (bool loading, String? error) {
        _vehiclesLoading = loading;
        _vehiclesError = error;
      },
    );
  }

  /// Creates ([id] null) or updates a registered vehicle. Throws [ApiException] with a message for the user.
  Future<void> saveVehicle({
    String? id,
    required String vin,
    String name = '',
    String make = '',
    String model = '',
    int? year,
    String notes = '',
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'vin': vin.trim(),
      'name': name.trim(),
      'make': make.trim(),
      'model': model.trim(),
      'year': year,
      'notes': notes.trim(),
    };
    if (id == null) {
      final AppUser? current = _user;
      if (current == null) throw const ApiException('يرجى تسجيل الدخول أولاً.');
      final String keyName = 'pending_vehicle_key_${current.id}';
      String? key = await _safeRead(keyName);
      if (key == null || key.isEmpty) {
        key = _newIdempotencyKey();
        try {
          await store.write(keyName, key);
        } catch (_) {
          throw const ApiException('تعذر حفظ معرّف التأكيد بأمان. حاول مجدداً.');
        }
      }
      await _guard(() => api.postJson('/api/account/vehicles', body, idempotencyKey: key));
      await _safeDelete(keyName);
    } else {
      await _guard(() => api.putJson('/api/account/vehicles/$id', body));
    }
    await loadVehicles(silent: true);
  }

  Future<void> deleteVehicle(String id) async {
    await _guard(() => api.deleteJson('/api/account/vehicles/$id'));
    await loadVehicles(silent: true);
  }

  /// Opens the catalog tab with [query] typed in its search box (a scanned or saved VIN, for example). The catalog's
  /// own search does the work: there is no second search engine.
  void searchCatalogFor(String query) {
    final String text = query.trim();
    if (_user == null || text.isEmpty) {
      return;
    }
    _pendingCatalogQuery = text;
    selectTab(tabCatalog);
    notifyListeners();
  }

  /// Returns the requested search once and forgets it (called by the catalog tab).
  String? takePendingCatalogQuery() {
    final String? query = _pendingCatalogQuery;
    _pendingCatalogQuery = null;
    return query;
  }

  // ---------------------------------------------------------------- account data, password, deletion

  /// Changes the password; the current one must be right. Throws [ApiException] with a message for the user.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _guard(
      () => api.postJson('/api/account/password', <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
  }

  /// Step 1 of a phone change: a code is sent to the NEW number on WhatsApp. Returns the server's message.
  Future<String> requestPhoneChange({required String newPhone, required String currentPassword}) async {
    final Map<String, dynamic> data = await _guard(
      () => api.postJson('/api/account/phone', <String, dynamic>{
        'mode': 'request',
        'newPhone': canonicalPhone(newPhone),
        'currentPassword': currentPassword,
      }),
    );
    return asString(data['message'], 'تم إرسال رمز التحقق إلى الرقم الجديد على واتساب');
  }

  /// Step 2: the code is checked, the number is changed and the session token is replaced (it carries the phone).
  Future<void> confirmPhoneChange({required String newPhone, required String code}) async {
    final Map<String, dynamic> data = await _guard(
      () => api.postJson('/api/account/phone', <String, dynamic>{
        'mode': 'confirm',
        'newPhone': canonicalPhone(newPhone),
        'code': toWesternDigits(code).trim(),
      }),
    );
    final Object? token = data['accessToken'];
    if (token is String && token.isNotEmpty) {
      api.token = token;
      await _safeWrite(tokenKey, token);
    }
    final Object? fresh = data['user'];
    if (fresh is Map) {
      _mergeUser(asMap(fresh));
    }
    notifyListeners();
  }

  Future<void> loadDeletion({bool silent = false}) async {
    if (_user == null) {
      return;
    }
    final int epoch = _epoch;
    try {
      final Map<String, dynamic> data = await api.getJson('/api/account/deletion');
      if (epoch != _epoch) {
        return;
      }
      final Object? request = data['request'];
      _deletion = request is Map ? DeletionRequest.fromJson(asMap(request)) : null;
      _deletionLoaded = true;
      notifyListeners();
    } catch (_) {
      // Quiet: the profile simply shows no countdown when this cannot be read.
    }
  }

  /// Starts the 30-day countdown. The password is asked again; throws [ApiException] with a message for the user.
  Future<void> requestAccountDeletion(String password) async {
    final Map<String, dynamic> data = await _guard(
      () => api.postJson('/api/account/deletion', <String, dynamic>{'password': password}),
    );
    final Object? request = data['request'];
    _deletion = request is Map ? DeletionRequest.fromJson(asMap(request)) : null;
    _deletionLoaded = true;
    notifyListeners();
  }

  /// Cancels the pending deletion (possible until the 30 days end).
  Future<void> cancelAccountDeletion() async {
    await _guard(() => api.deleteJson('/api/account/deletion'));
    _deletion = null;
    _deletionLoaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- forgot password (no session)

  /// Asks for a WhatsApp recovery code. The answer is the same whether or not the number is registered.
  Future<String> requestPasswordReset({required String role, required String phone}) async {
    final Map<String, dynamic> data = await _guard(
      () => api.postJson(
        '/api/password-reset/user',
        <String, dynamic>{'mode': 'request', 'role': role, 'phone': phone.trim()},
        auth: false,
      ),
    );
    return asString(data['message'], 'إن كان الرقم مسجلاً لدينا فسيصلك رمز التحقق على واتساب خلال دقيقة.');
  }

  /// Checks the code and sets the new password. The user then signs in with it.
  Future<String> confirmPasswordReset({
    required String role,
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final Map<String, dynamic> data = await _guard(
      () => api.postJson(
        '/api/password-reset/user',
        <String, dynamic>{
          'mode': 'confirm',
          'role': role,
          'phone': phone.trim(),
          'code': toWesternDigits(code).trim(),
          'newPassword': newPassword,
        },
        auth: false,
      ),
    );
    return asString(data['message'], 'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.');
  }

  // ---------------------------------------------------------------- foreground refresh

  /// Quietly refreshes what is on screen when the app returns to the foreground (at most every 30 seconds).
  void refreshOnResume() {
    if (_user == null) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? last = _lastResumeRefresh;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastResumeRefresh = now;
    unawaited(loadSettings());
    unawaited(loadParts(silent: true));
    if (_ordersLoaded) {
      unawaited(loadOrders(silent: true));
    }
    if (_requestsLoaded) {
      unawaited(loadRequests(silent: true));
    }
    if (dashboardLoaded) {
      unawaited(loadDashboard(silent: true));
    }
    unawaited(loadNotifications(silent: true));
  }

  // ---------------------------------------------------------------- storage guards

  Future<String?> _safeRead(String key) async {
    try {
      return await store.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await store.write(key, value);
    } catch (_) {
      // Local storage is best effort; the session still works for this run.
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await store.delete(key);
    } catch (_) {
      // Nothing more can be done if the keystore refuses.
    }
  }
}

/// Gives every screen access to the [AppState]; widgets that call [AppScope.of] rebuild when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Reads the state without subscribing to its changes (use inside callbacks).
  static AppState read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
