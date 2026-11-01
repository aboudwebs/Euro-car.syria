import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:euro_cars/core/api_client.dart';
import 'package:euro_cars/core/config.dart';
import 'package:euro_cars/core/models.dart';
import 'package:euro_cars/core/session_store.dart';
import 'package:euro_cars/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_server.dart';
import 'support/fixtures.dart';
import 'support/matchers.dart';
import 'support/memory_store.dart';

/// An AppState wired to a scripted server and an in-memory store.
class Harness {
  Harness({Map<String, String>? stored})
      : store = MemoryStore(stored),
        server = FakeServer() {
    api = ApiClient(baseUrl: 'https://api.test', client: server.client, retryDelay: Duration.zero);
    state = AppState(api: api, store: store);
  }

  final MemoryStore store;
  final FakeServer server;
  late final ApiClient api;
  late final AppState state;

  /// What the app asks for in the background right after signing in.
  void serveBackground({Map<String, dynamic>? account, List<Map<String, dynamic>>? catalog}) {
    server.reply('GET', '/api/parts', <String, dynamic>{'parts': catalog ?? catalogJson()});
    server.reply('GET', '/api/account/avatar', <String, dynamic>{'error': 'no photo'}, 404);
    server.reply('GET', '/api/auth', <String, dynamic>{'user': account ?? workshopJson()});
  }

  void serveLists() {
    server.reply('GET', '/api/orders', <String, dynamic>{'orders': <Object>[]});
    server.reply('GET', '/api/special-requests', <String, dynamic>{'requests': <Object>[]});
  }

  void serveLogin(Map<String, dynamic> account, {String token = 'tok-9'}) {
    server.reply('POST', '/api/auth', <String, dynamic>{'accessToken': token, 'user': account});
    serveBackground(account: account);
  }
}

Map<String, String> savedSession(Map<String, dynamic> account) {
  return <String, String>{tokenKey: 'tok-1', userKey: jsonEncode(account)};
}

Future<Harness> signedInHarness({
  Map<String, dynamic>? account,
  Map<String, String> extraStore = const <String, String>{},
  List<Map<String, dynamic>>? catalog,
}) async {
  final Map<String, dynamic> user = account ?? workshopJson();
  final Harness h = Harness(stored: <String, String>{...savedSession(user), ...extraStore});
  h.serveBackground(account: user, catalog: catalog);
  h.serveLists();
  await h.state.restore();
  await pumpEventQueue();
  return h;
}

Part catalogPart(Harness h, String id) => h.state.parts.firstWhere((Part p) => p.id == id);

Map<String, dynamic> bodyOf(http.Request request) {
  return jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
}

String cartJson(String uid, Map<String, Object?> items) {
  return jsonEncode(<String, dynamic>{'uid': uid, 'items': items});
}

void main() {
  group('restoring a session', () {
    test('without a saved session it leads to the sign-in screen', () async {
      final Harness h = Harness();
      expect(h.state.status, SessionStatus.restoring);

      await h.state.restore();

      expect(h.state.status, SessionStatus.signedOut);
      expect(h.state.user, isNull);
      expect(h.state.isSignedIn, isFalse);
      expect(h.server.requests, isEmpty);
    });

    test('a saved session is restored and the catalog loads', () async {
      final Harness h = await signedInHarness();

      expect(h.state.status, SessionStatus.signedIn);
      expect(h.state.isSignedIn, isTrue);
      expect(h.state.user!.id, 'w1');
      expect(h.api.token, 'tok-1');
      expect(h.state.partsLoaded, isTrue);
      expect(h.state.parts.map((Part p) => p.id), <String>['p1', 'p2', 'p3']);
      expect(h.state.partsError, isNull);

      final http.Request parts = h.server.requestsTo('GET', '/api/parts').single;
      expect(parts.headers['authorization'], 'Bearer tok-1');
      final http.Request profile = h.server.requestsTo('GET', '/api/auth').single;
      expect(profile.headers['cookie'], 'euro_session=tok-1');
      expect(h.server.requestsTo('GET', '/api/account/avatar'), hasLength(1));
    });

    test('a damaged or incomplete saved session is cleaned up', () async {
      final Harness damaged = Harness(stored: <String, String>{tokenKey: 'tok', userKey: 'not json'});
      await damaged.state.restore();
      expect(damaged.state.status, SessionStatus.signedOut);
      expect(damaged.store.data, isEmpty);

      final Harness partial = Harness(stored: <String, String>{tokenKey: 'tok'});
      await partial.state.restore();
      expect(partial.state.status, SessionStatus.signedOut);
      expect(partial.store.data, isEmpty);
      expect(partial.server.requests, isEmpty);
    });

    test('an admin session found on the device is not accepted (admin is web only)', () async {
      final Harness h = Harness(stored: savedSession(adminJson()));
      await h.state.restore();
      expect(h.state.status, SessionStatus.signedOut);
      expect(h.store.data.containsKey(tokenKey), isFalse);
    });

    test('a keystore that refuses to read leads to the sign-in screen', () async {
      final Harness h = Harness(stored: savedSession(workshopJson()));
      h.store.failReads = true;
      await h.state.restore();
      expect(h.state.status, SessionStatus.signedOut);
      expect(h.state.themeMode, ThemeMode.dark);
    });

    test('the saved theme is restored', () async {
      for (final MapEntry<String, ThemeMode> entry in <String, ThemeMode>{
        'light': ThemeMode.light,
        'system': ThemeMode.system,
        'dark': ThemeMode.dark,
        'purple': ThemeMode.dark,
      }.entries) {
        final Harness h = Harness(stored: <String, String>{themeKey: entry.key});
        await h.state.restore();
        expect(h.state.themeMode, entry.value, reason: entry.key);
      }
    });
  });

  group('signing in and registering', () {
    test('a successful sign-in stores the session and starts the app', () async {
      final Harness h = Harness()..serveLogin(workshopJson());
      await h.state.restore();

      final AuthResult result = await h.state.login(role: 'workshop', phone: ' 0982026134 ', password: 'secret');
      await pumpEventQueue();

      expect(result.isSignedIn, isTrue);
      expect(h.state.status, SessionStatus.signedIn);
      expect(h.state.user!.name, 'ورشة النور');
      expect(h.api.token, 'tok-9');
      expect(h.store.data[tokenKey], 'tok-9');
      expect((jsonDecode(h.store.data[userKey]!) as Map<String, dynamic>)['id'], 'w1');
      expect(h.state.partsLoaded, isTrue);

      final http.Request request = h.server.requestsTo('POST', '/api/auth').single;
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(bodyOf(request), <String, dynamic>{
        'mode': 'login',
        'client': 'mobile',
        'role': 'workshop',
        'phone': '0982026134',
        'password': 'secret',
      });
    });

    test('sign-in sends the phone exactly as typed, only trimmed', () async {
      final Harness h = Harness()..serveLogin(workshopJson());
      await h.state.restore();

      await h.state.login(role: 'workshop', phone: ' ٠٩٨٢٠٢٦١٣٤ ', password: 'secret');
      await pumpEventQueue();

      expect(bodyOf(h.server.requestsTo('POST', '/api/auth').single)['phone'], '٠٩٨٢٠٢٦١٣٤');
    });

    test('a workshop that is not approved yet gets the pending result', () async {
      final Harness h = Harness();
      h.server.reply(
        'POST',
        '/api/auth',
        <String, dynamic>{'error': 'حسابك قيد المراجعة من الإدارة', 'pendingApproval': true},
        403,
      );
      await h.state.restore();

      final AuthResult result = await h.state.login(role: 'workshop', phone: '0982026134', password: 'secret');

      expect(result.isPending, isTrue);
      expect(result.message, 'حسابك قيد المراجعة من الإدارة');
      expect(h.state.status, SessionStatus.signedOut);
      expect(h.store.data.containsKey(tokenKey), isFalse);
    });

    test('a wrong password shows the server message and is not a session expiry', () async {
      final Harness h = Harness();
      h.server.reply('POST', '/api/auth', <String, dynamic>{'error': 'بيانات الدخول غير صحيحة'}, 401);
      await h.state.restore();

      final AuthResult result = await h.state.login(role: 'workshop', phone: '0982026134', password: 'wrong');

      expect(result.kind, AuthResultKind.failed);
      expect(result.message, 'بيانات الدخول غير صحيحة');
      expect(h.state.sessionNotice, isNull);
    });

    test('an answer without a session, an admin account or a dead network all fail cleanly', () async {
      final Harness noSession = Harness();
      noSession.server.reply('POST', '/api/auth', <String, dynamic>{'user': workshopJson()});
      await noSession.state.restore();
      final AuthResult a = await noSession.state.login(role: 'workshop', phone: '1', password: 'secret');
      expect(a.kind, AuthResultKind.failed);
      expect(a.message, 'الخادم لم يرجع جلسة تطبيق صالحة');

      final Harness admin = Harness();
      admin.server.reply('POST', '/api/auth', <String, dynamic>{'accessToken': 't', 'user': adminJson()});
      await admin.state.restore();
      final AuthResult b = await admin.state.login(role: 'workshop', phone: '1', password: 'secret');
      expect(b.kind, AuthResultKind.failed);
      expect(b.message, 'هذا النوع من الحسابات غير متاح في التطبيق.');
      expect(admin.store.data.containsKey(tokenKey), isFalse);

      final Harness offline = Harness();
      offline.server.on('POST', '/api/auth', (http.Request _) => throw http.ClientException('offline'));
      await offline.state.restore();
      final AuthResult c = await offline.state.login(role: 'workshop', phone: '1', password: 'secret');
      expect(c.kind, AuthResultKind.failed);
      expect(c.message, networkErrorMessage);
    });

    test('a keystore that refuses to write does not block signing in', () async {
      final Harness h = Harness()..serveLogin(workshopJson());
      await h.state.restore();
      h.store.failWrites = true;

      final AuthResult result = await h.state.login(role: 'workshop', phone: '0982026134', password: 'secret');
      await pumpEventQueue();

      expect(result.isSignedIn, isTrue);
      expect(h.state.isSignedIn, isTrue);
      expect(h.store.data.containsKey(tokenKey), isFalse);
    });

    test('a workshop registration waits for the admin and sends the cleaned fields', () async {
      final Harness h = Harness();
      h.server.reply(
        'POST',
        '/api/auth',
        <String, dynamic>{'pendingApproval': true, 'message': 'تم إرسال الطلب للإدارة'},
      );
      await h.state.restore();

      final AuthResult result = await h.state.register(
        role: 'workshop',
        name: '  ورشة الأمل ',
        phone: '٠٩٨٢ ٠٢٦ ١٣٤',
        password: 'secret',
        license: ' L-77 ',
        city: ' حلب ',
        specs: 'BMW, Audi',
        refCode: ' MK-1A2B3C ',
        refSignature: ' sig123 ',
      );

      expect(result.isPending, isTrue);
      expect(result.message, 'تم إرسال الطلب للإدارة');
      expect(h.state.status, SessionStatus.signedOut);
      expect(bodyOf(h.server.requestsTo('POST', '/api/auth').single), <String, dynamic>{
        'mode': 'register',
        'client': 'mobile',
        'role': 'workshop',
        'name': 'ورشة الأمل',
        'phone': '0982026134',
        'password': 'secret',
        'license': 'L-77',
        'city': 'حلب',
        'spec': 'BMW, Audi',
        'refCode': 'MK-1A2B3C',
        'refSignature': 'sig123',
      });
    });

    test('blank referral values are not sent and a missing server message gets a default', () async {
      final Harness h = Harness();
      h.server.reply('POST', '/api/auth', <String, dynamic>{'pendingApproval': true});
      await h.state.restore();

      final AuthResult result = await h.state.register(
        role: 'workshop',
        name: 'ورشة',
        phone: '0982026134',
        password: 'secret',
        license: 'L-1',
        city: 'حلب',
        specs: 'BMW',
        refCode: '  ',
      );

      expect(result.isPending, isTrue);
      expect(result.message, isNotEmpty);
      final Map<String, dynamic> body = bodyOf(h.server.requestsTo('POST', '/api/auth').single);
      expect(body.containsKey('refCode'), isFalse);
      expect(body.containsKey('refSignature'), isFalse);
    });

    test('a marketer registration signs in at once and sends no workshop fields', () async {
      final Harness h = Harness()..serveLogin(marketerJson(), token: 'tok-m');
      await h.state.restore();

      final AuthResult result = await h.state.register(
        role: 'marketer',
        name: 'مسوّق الشمال',
        phone: '0933000111',
        password: 'secret',
        license: 'ignored',
        city: 'ignored',
        specs: 'ignored',
        refCode: 'MK-1',
      );
      await pumpEventQueue();

      expect(result.isSignedIn, isTrue);
      expect(h.state.user!.isMarketer, isTrue);
      expect(h.api.token, 'tok-m');
      expect(
        bodyOf(h.server.requestsTo('POST', '/api/auth').single).keys,
        unorderedEquals(<String>['mode', 'client', 'role', 'name', 'phone', 'password']),
      );
    });

    test('a refused registration shows the server message', () async {
      final Harness h = Harness();
      h.server.reply('POST', '/api/auth', <String, dynamic>{'error': 'رقم الهاتف مسجل مسبقاً'}, 400);
      await h.state.restore();

      final AuthResult result = await h.state.register(
        role: 'marketer',
        name: 'م',
        phone: '0933000111',
        password: 'secret',
      );

      expect(result.kind, AuthResultKind.failed);
      expect(result.message, 'رقم الهاتف مسجل مسبقاً');
    });
  });

  group('signing out and expired sessions', () {
    test('signing out clears the session, the data and the saved cart', () async {
      final Harness h = await signedInHarness(
        extraStore: <String, String>{cartKey: cartJson('w1', <String, Object?>{'p1': 2})},
      );
      expect(h.state.qtyInCart('p1'), 2);

      await h.state.logout();

      expect(h.state.status, SessionStatus.signedOut);
      expect(h.state.user, isNull);
      expect(h.api.token, isNull);
      expect(h.state.cartItems, isEmpty);
      expect(h.state.parts, isEmpty);
      expect(h.state.sessionNotice, isNull);
      expect(h.store.data.containsKey(tokenKey), isFalse);
      expect(h.store.data.containsKey(userKey), isFalse);
      expect(h.store.data.containsKey(cartKey), isFalse);
    });

    test('a 401 on an authenticated call ends the session but keeps the saved cart', () async {
      final Harness h = await signedInHarness(
        extraStore: <String, String>{cartKey: cartJson('w1', <String, Object?>{'p1': 2})},
      );
      h.server.reply('GET', '/api/orders', <String, dynamic>{'error': 'غير مصرح'}, 401);

      await h.state.loadOrders();
      await pumpEventQueue();

      expect(h.state.status, SessionStatus.signedOut);
      expect(h.state.user, isNull);
      expect(h.api.token, isNull);
      expect(h.state.sessionNotice, 'انتهت جلسة الدخول. سجّل الدخول مجدداً للمتابعة.');
      expect(h.state.ordersError, isNull);
      expect(h.store.data.containsKey(tokenKey), isFalse);
      expect(h.store.data.containsKey(userKey), isFalse);
      expect(h.store.data.containsKey(cartKey), isTrue);

      int notified = 0;
      h.state.addListener(() => notified++);
      h.state.dismissSessionNotice();
      h.state.dismissSessionNotice();
      expect(h.state.sessionNotice, isNull);
      expect(notified, 1);

      // The same account gets its saved cart back after signing in again.
      h.serveLogin(workshopJson());
      await h.state.login(role: 'workshop', phone: '0982026134', password: 'secret');
      await pumpEventQueue();
      expect(h.state.qtyInCart('p1'), 2);
    });

    test('a saved cart of another account is not shown, and a damaged one is ignored', () async {
      final Harness other = await signedInHarness(
        extraStore: <String, String>{cartKey: cartJson('someone-else', <String, Object?>{'p1': 2})},
      );
      expect(other.state.cartItems, isEmpty);

      for (final String broken in <String>['{broken', '[1,2]', '']) {
        final Harness h = await signedInHarness(extraStore: <String, String>{cartKey: broken});
        expect(h.state.cartItems, isEmpty, reason: 'saved cart "$broken"');
      }
    });

    test('answers that arrive after signing out are ignored', () async {
      final Harness h = Harness(stored: savedSession(workshopJson()));
      final Completer<http.Response> gate = Completer<http.Response>();
      h.serveBackground();
      h.server.on('GET', '/api/parts', (http.Request _) => gate.future);
      await h.state.restore();
      expect(h.state.partsLoading, isTrue);

      await h.state.logout();
      gate.complete(jsonResponse(<String, dynamic>{'parts': catalogJson()}));
      await pumpEventQueue();

      expect(h.state.parts, isEmpty);
      expect(h.state.partsLoaded, isFalse);
      expect(h.state.status, SessionStatus.signedOut);
    });

    test('notifications after dispose are harmless', () async {
      final Harness h = await signedInHarness();
      h.state.dispose();

      await h.state.loadOrders();

      expect(h.api.onUnauthorized, isNull);
    });
  });

  group('catalog and cart', () {
    test('a failed catalog request shows the server message and can be retried', () async {
      final Harness h = Harness(stored: savedSession(workshopJson()));
      h.serveBackground();
      h.server.reply('GET', '/api/parts', <String, dynamic>{'error': 'خطأ في قاعدة البيانات'}, 500);
      await h.state.restore();
      await pumpEventQueue();

      expect(h.state.partsLoaded, isFalse);
      expect(h.state.partsLoading, isFalse);
      expect(h.state.partsError, 'خطأ في قاعدة البيانات');

      h.server.reply('GET', '/api/parts', <String, dynamic>{'parts': catalogJson()});
      await h.state.loadParts();

      expect(h.state.partsError, isNull);
      expect(h.state.partsLoaded, isTrue);
    });

    test('a quiet refresh that fails keeps what is on screen, a visible one reports it', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/parts', <String, dynamic>{'error': 'boom'}, 500);

      await h.state.loadParts(silent: true);
      expect(h.state.partsError, isNull);
      expect(h.state.parts, hasLength(3));

      h.server.on('GET', '/api/parts', (http.Request _) => http.Response.bytes(utf8.encode('<html>'), 200));
      await h.state.loadParts();
      expect(h.state.partsError, badResponseMessage);
      expect(h.state.parts, hasLength(3));
    });

    test('only parts in stock can be added, up to the stock on hand', () async {
      final Harness h = await signedInHarness();
      final Part inStock = catalogPart(h, 'p2');

      expect(h.state.addToCart(catalogPart(h, 'p3')), 'هذه القطعة غير متوفرة حالياً.');
      expect(h.state.addToCart(inStock), isNull);
      expect(h.state.addToCart(inStock), isNull);
      expect(h.state.addToCart(inStock), isNull);
      expect(h.state.addToCart(inStock), 'وصلت إلى أقصى كمية متاحة من هذه القطعة.');

      expect(h.state.qtyInCart('p2'), 3);
      expect(h.state.qtyInCart('p3'), 0);
      expect(h.state.cartItemCount, 3);
      expect(h.state.cartTotalAmount, 120.0);
      expect(h.state.cartLines.single.part.id, 'p2');
    });

    test('quantities can be lowered, removed and cleared', () async {
      final Harness h = await signedInHarness();
      final Part p1 = catalogPart(h, 'p1');
      final Part p2 = catalogPart(h, 'p2');
      h.state.addToCart(p1);
      h.state.addToCart(p1);
      h.state.addToCart(p2);
      expect(h.state.cartItemCount, 3);

      h.state.decrementCart('p1');
      expect(h.state.qtyInCart('p1'), 1);
      h.state.decrementCart('p1');
      expect(h.state.cartItems.containsKey('p1'), isFalse);

      h.state.removeFromCart('p2');
      expect(h.state.cartItems, isEmpty);

      h.state.addToCart(p1);
      h.state.clearCart();
      expect(h.state.cartItems, isEmpty);
      h.state.decrementCart('unknown');
      expect(h.state.cartItemCount, 0);
    });

    test('an order holds at most 50 different parts', () async {
      final List<Map<String, dynamic>> many = <Map<String, dynamic>>[
        for (int i = 0; i < 51; i++)
          <String, dynamic>{'id': 'x$i', 'name': 'قطعة $i', 'brand': 'BMW', 'pn': 'PN$i', 'price': 1, 'stock': 5},
      ];
      final Harness h = await signedInHarness(catalog: many);

      for (int i = 0; i < 50; i++) {
        expect(h.state.addToCart(h.state.parts[i]), isNull, reason: 'line $i');
      }
      expect(h.state.addToCart(h.state.parts[50]), 'لا يمكن إضافة أكثر من 50 صنفاً في الطلب الواحد.');
      expect(h.state.cartItems, hasLength(50));
      expect(h.state.addToCart(h.state.parts[0]), isNull);
    });

    test('the cart is saved on the device and removed when it empties', () async {
      final Harness h = await signedInHarness();
      h.state.addToCart(catalogPart(h, 'p2'));
      h.state.addToCart(catalogPart(h, 'p2'));
      await pumpEventQueue();

      expect(jsonDecode(h.store.data[cartKey]!), <String, dynamic>{
        'uid': 'w1',
        'items': <String, dynamic>{'p2': 2},
      });

      h.state.clearCart();
      await pumpEventQueue();
      expect(h.store.data.containsKey(cartKey), isFalse);
    });

    test('a saved cart is trimmed to the stock on hand once the catalog loads', () async {
      final Harness h = Harness(
        stored: <String, String>{
          ...savedSession(workshopJson()),
          cartKey: cartJson('w1', <String, Object?>{
            'p1': 500,
            'p2': 2,
            'p3': 1,
            'ghost': 4,
            'bad': 'x',
            'negative': -3,
          }),
        },
      );
      final Completer<http.Response> gate = Completer<http.Response>();
      h.serveBackground();
      h.server.on('GET', '/api/parts', (http.Request _) => gate.future);

      await h.state.restore();
      expect(h.state.cartItems, <String, int>{'p1': 100, 'p2': 2, 'p3': 1, 'ghost': 4});
      expect(h.state.cartItemCount, 107);
      expect(h.state.cartNotice, isNull);

      gate.complete(jsonResponse(<String, dynamic>{'parts': catalogJson()}));
      await pumpEventQueue();

      expect(h.state.cartItems, <String, int>{'p1': 10, 'p2': 2});
      expect(h.state.cartNotice, 'تم تحديث السلة حسب القطع المتوفرة حالياً في المخزون.');
      expect(jsonDecode(h.store.data[cartKey]!), <String, dynamic>{
        'uid': 'w1',
        'items': <String, dynamic>{'p1': 10, 'p2': 2},
      });

      h.state.dismissCartNotice();
      expect(h.state.cartNotice, isNull);
    });
  });

  group('placing orders', () {
    test('an order that cannot succeed is refused before any request is sent', () async {
      final Harness signedOut = Harness();
      await signedOut.state.restore();
      await expectLater(
        signedOut.state.placeOrder(pay: 'cod'),
        throwsA(apiError(message: 'يرجى تسجيل الدخول لإتمام الطلب')),
      );

      final Harness marketer = await signedInHarness(account: marketerJson());
      marketer.state.addToCart(catalogPart(marketer, 'p1'));
      await expectLater(
        marketer.state.placeOrder(pay: 'debt'),
        throwsA(apiError(message: 'طريقة الدفع هذه غير متاحة لحسابك.')),
      );

      final Harness empty = await signedInHarness();
      await expectLater(empty.state.placeOrder(pay: 'cod'), throwsA(apiError(message: 'السلة فارغة.')));

      final Harness sham = await signedInHarness();
      sham.state.addToCart(catalogPart(sham, 'p1'));
      const String needReceipt = 'يرجى إرفاق إشعار تحويل شام كاش.';
      await expectLater(sham.state.placeOrder(pay: 'sham'), throwsA(apiError(message: needReceipt)));
      await expectLater(
        sham.state.placeOrder(pay: 'sham', receipt: Uint8List(0)),
        throwsA(apiError(message: needReceipt)),
      );
      await expectLater(
        sham.state.placeOrder(pay: 'sham', receipt: Uint8List(maxImageBytes + 1)),
        throwsA(apiError(message: 'حجم الصورة يجب ألا يتجاوز 5 ميغابايت.')),
      );

      for (final Harness h in <Harness>[signedOut, marketer, empty, sham]) {
        expect(h.server.requestsTo('POST', '/api/orders'), isEmpty);
      }
    });

    test('a cash order sends only part ids and quantities, then empties the cart', () async {
      final Harness h = await signedInHarness();
      h.server.reply(
        'POST',
        '/api/orders',
        <String, dynamic>{'orderId': 'o1', 'orderNumber': 7, 'pay': 'cod', 'total': 61},
      );
      h.state.addToCart(catalogPart(h, 'p1'));
      h.state.addToCart(catalogPart(h, 'p1'));
      h.state.addToCart(catalogPart(h, 'p2'));

      final PlacedOrder placed = await h.state.placeOrder(pay: 'cod');
      await pumpEventQueue();

      expect(placed.orderId, 'o1');
      expect(placed.orderNumber, 7);
      expect(placed.total, 61.0);
      expect(h.state.cartItems, isEmpty);
      expect(h.store.data.containsKey(cartKey), isFalse);
      expect(h.state.ordersLoaded, isTrue);

      final http.Request request = h.server.requestsTo('POST', '/api/orders').single;
      expect(request.headers['authorization'], 'Bearer tok-1');
      final List<MultipartPart> parts = parseMultipart(request);
      expect(parts.map((MultipartPart p) => p.name), unorderedEquals(<String>['items', 'pay']));
      expect(jsonDecode(partNamed(parts, 'items').text), <String, dynamic>{'p1': 2, 'p2': 1});
      expect(partNamed(parts, 'pay').text, 'cod');
    });

    test('a Sham Cash order attaches the receipt, named after its real format', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/orders', <String, dynamic>{'orderId': 'o2', 'pay': 'sham', 'total': 10.5});
      final Uint8List jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      final Uint8List png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01]);

      h.state.addToCart(catalogPart(h, 'p1'));
      await h.state.placeOrder(pay: 'sham', receipt: jpeg);
      h.state.addToCart(catalogPart(h, 'p1'));
      await h.state.placeOrder(pay: 'sham', receipt: png);
      await pumpEventQueue();

      final List<http.Request> sent = h.server.requestsTo('POST', '/api/orders');
      expect(sent, hasLength(2));
      final MultipartPart first = partNamed(parseMultipart(sent[0]), 'receipt');
      expect(first.filename, 'receipt.jpg');
      expect(first.bytes, orderedEquals(jpeg));
      final MultipartPart second = partNamed(parseMultipart(sent[1]), 'receipt');
      expect(second.filename, 'receipt.png');
      expect(second.bytes, orderedEquals(png));
    });

    test('a workshop may put an order on the debt ledger', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/orders', <String, dynamic>{'orderId': 'o3', 'pay': 'debt', 'total': 10.5});
      h.state.addToCart(catalogPart(h, 'p1'));

      await h.state.placeOrder(pay: 'debt');

      final List<MultipartPart> parts = parseMultipart(h.server.requestsTo('POST', '/api/orders').single);
      expect(partNamed(parts, 'pay').text, 'debt');
      expect(parts.any((MultipartPart p) => p.filename != null), isFalse);
    });

    test('a refused order keeps the cart and refreshes the catalog', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/orders', <String, dynamic>{'error': 'الكمية المطلوبة غير متوفرة'}, 400);
      h.state.addToCart(catalogPart(h, 'p1'));
      final int before = h.server.requestsTo('GET', '/api/parts').length;

      await expectLater(
        h.state.placeOrder(pay: 'cod'),
        throwsA(apiError(status: 400, message: 'الكمية المطلوبة غير متوفرة')),
      );
      await pumpEventQueue();

      expect(h.state.qtyInCart('p1'), 1);
      expect(h.server.requestsTo('GET', '/api/parts'), hasLength(before + 1));
    });

    test('a dropped connection warns that the order may have arrived and is never resent', () async {
      final Harness h = await signedInHarness();
      h.server.on('POST', '/api/orders', (http.Request _) => throw http.ClientException('connection reset'));
      h.state.addToCart(catalogPart(h, 'p1'));

      await expectLater(
        h.state.placeOrder(pay: 'cod'),
        throwsA(
          apiError(network: true, message: '$networkErrorMessage\nقد يكون الطلب وصل رغم ذلك، راجع «طلباتي» قبل إعادة المحاولة لتجنّب تكراره.'),
        ),
      );

      expect(h.server.requestsTo('POST', '/api/orders'), hasLength(1));
      expect(h.state.qtyInCart('p1'), 1);
    });

    test('orders and special requests are listed from the API', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/orders', <String, dynamic>{
        'orders': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'o1',
            'order_number': 3,
            'total_amount': 20,
            'pay_method': 'cod',
            'status': 'pending',
          },
        ],
      });
      h.server.reply('GET', '/api/special-requests', <String, dynamic>{
        'requests': <Map<String, dynamic>>[
          <String, dynamic>{'id': 's1', 'brand': 'BMW', 'part_name': 'مرآة', 'status': 'new'},
        ],
      });

      await h.state.loadOrders();
      await h.state.loadRequests();

      expect(h.state.ordersLoaded, isTrue);
      expect(h.state.orders.single.label, '#3');
      expect(h.state.requestsLoaded, isTrue);
      expect(h.state.requests.single.partName, 'مرآة');
    });
  });

  group('special requests', () {
    test('send the trimmed fields and the photo, then refresh the list', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/special-requests', <String, dynamic>{'ok': true});
      final Uint8List photo = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01]);

      await h.state.submitSpecialRequest(
        brand: 'أخرى',
        otherBrand: ' Toyota ',
        partName: ' مرآة جانبية ',
        partNumber: ' 87910 ',
        notes: ' للجهة اليمنى ',
        image: photo,
      );
      await pumpEventQueue();

      final List<MultipartPart> parts = parseMultipart(h.server.requestsTo('POST', '/api/special-requests').single);
      expect(partNamed(parts, 'brand').text, 'أخرى');
      expect(partNamed(parts, 'otherBrand').text, 'Toyota');
      expect(partNamed(parts, 'partName').text, 'مرآة جانبية');
      expect(partNamed(parts, 'partNumber').text, '87910');
      expect(partNamed(parts, 'notes').text, 'للجهة اليمنى');
      final MultipartPart image = partNamed(parts, 'image');
      expect(image.filename, 'part.png');
      expect(image.bytes, orderedEquals(photo));
      expect(h.state.requestsLoaded, isTrue);
    });

    test('work without a photo, and refuse a photo above 5 MB', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/special-requests', <String, dynamic>{'ok': true});

      await h.state.submitSpecialRequest(brand: 'BMW', partName: 'مرآة');
      final List<MultipartPart> parts = parseMultipart(h.server.requestsTo('POST', '/api/special-requests').single);
      expect(parts.any((MultipartPart p) => p.name == 'image'), isFalse);

      await expectLater(
        h.state.submitSpecialRequest(brand: 'BMW', partName: 'مرآة', image: Uint8List(maxImageBytes + 1)),
        throwsA(apiError(message: 'حجم الصورة يجب ألا يتجاوز 5 ميغابايت.')),
      );
      expect(h.server.requestsTo('POST', '/api/special-requests'), hasLength(1));
    });

    test('a refusal from the server is passed on', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/special-requests', <String, dynamic>{'error': 'اسم القطعة مطلوب'}, 400);

      await expectLater(
        h.state.submitSpecialRequest(brand: 'BMW', partName: ' '),
        throwsA(apiError(status: 400, message: 'اسم القطعة مطلوب')),
      );
    });
  });

  group('tabs and dashboards', () {
    test('the workshop dashboard refreshes the debt figures of the saved account', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/workshop/dashboard', <String, dynamic>{
        'user': <String, dynamic>{...workshopJson(debtBalance: 300), 'cashback_balance': 15},
        'orders': <Object>[],
        'ledger': <Object>[],
      });

      await h.state.loadDashboard();
      await pumpEventQueue();

      expect(h.state.dashboardLoaded, isTrue);
      expect(h.state.workshopDashboard!.debtBalance, 300.0);
      expect(h.state.marketerDashboard, isNull);
      expect(h.state.user!.debtBalance, 300.0);
      expect(h.state.user!.cashbackBalance, 15.0);
      expect((jsonDecode(h.store.data[userKey]!) as Map<String, dynamic>)['debt_balance'], 300.0);
    });

    test('the marketer dashboard shows the code and commissions', () async {
      final Harness h = await signedInHarness(account: marketerJson());
      h.server.reply('GET', '/api/marketer/dashboard', <String, dynamic>{
        'marketer': <String, dynamic>{'name': 'م', 'code': 'MK-1A2B3C', 'referralUrl': 'https://x.test/login?ref=MK-1A2B3C'},
        'workshops': 3,
        'commissions': <String, dynamic>{'available': 12.5, 'held': 1, 'paid': 2, 'total': 15.5},
      });

      await h.state.loadDashboard();

      expect(h.state.marketerDashboard!.code, 'MK-1A2B3C');
      expect(h.state.marketerDashboard!.workshops, 3);
      expect(h.state.marketerDashboard!.commissions.available, 12.5);
      expect(h.state.workshopDashboard, isNull);
    });

    test('a dashboard error is reported and nothing is shown', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/workshop/dashboard', <String, dynamic>{'error': 'تعذر تحميل اللوحة'}, 500);

      await h.state.loadDashboard();

      expect(h.state.dashboardLoaded, isFalse);
      expect(h.state.dashboardError, 'تعذر تحميل اللوحة');
    });

    test('opening a tab refreshes the data that tab shows', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/workshop/dashboard', <String, dynamic>{
        'user': workshopJson(),
        'orders': <Object>[],
        'ledger': <Object>[],
      });

      h.state.selectTab(tabOrders);
      await pumpEventQueue();
      expect(h.state.selectedTab, tabOrders);
      expect(h.state.ordersLoaded, isTrue);
      expect(h.state.requestsLoaded, isTrue);

      h.state.selectTab(tabDashboard);
      await pumpEventQueue();
      expect(h.state.dashboardLoaded, isTrue);

      final int partsBefore = h.server.requestsTo('GET', '/api/parts').length;
      final int dashboardBefore = h.server.requestsTo('GET', '/api/workshop/dashboard').length;
      h.state.selectTab(tabCart);
      await pumpEventQueue();
      expect(h.server.requestsTo('GET', '/api/parts'), hasLength(partsBefore + 1));
      expect(h.server.requestsTo('GET', '/api/workshop/dashboard'), hasLength(dashboardBefore + 1));
    });

    test('a marketer opening the cart only refreshes the catalog', () async {
      final Harness h = await signedInHarness(account: marketerJson());

      h.state.selectTab(tabCart);
      await pumpEventQueue();

      expect(h.server.requestsTo('GET', '/api/workshop/dashboard'), isEmpty);
      expect(h.server.requestsTo('GET', '/api/marketer/dashboard'), isEmpty);
    });

    test('tabs outside the range, or while signed out, are ignored', () async {
      final Harness out = Harness();
      await out.state.restore();
      out.state.selectTab(tabOrders);
      expect(out.state.selectedTab, tabCatalog);

      final Harness h = await signedInHarness();
      h.state.selectTab(9);
      h.state.selectTab(-1);
      expect(h.state.selectedTab, tabCatalog);
    });

    test('the special requests shortcut opens the orders tab on that list', () async {
      final Harness h = await signedInHarness();

      h.state.showSpecialRequests();
      await pumpEventQueue();
      expect(h.state.ordersView, OrdersView.requests);
      expect(h.state.selectedTab, tabOrders);

      h.state.setOrdersView(OrdersView.orders);
      expect(h.state.ordersView, OrdersView.orders);
    });

    test('returning to the app refreshes the catalog at most every 30 seconds', () async {
      final Harness h = await signedInHarness();
      expect(h.server.requestsTo('GET', '/api/parts'), hasLength(1));

      h.state.refreshOnResume();
      await pumpEventQueue();
      expect(h.server.requestsTo('GET', '/api/parts'), hasLength(2));

      h.state.refreshOnResume();
      await pumpEventQueue();
      expect(h.server.requestsTo('GET', '/api/parts'), hasLength(2));
    });
  });

  group('profile', () {
    test('saving sends the trimmed name and city, and only a non-empty password', () async {
      final Harness h = await signedInHarness();
      h.server.reply('PUT', '/api/auth', <String, dynamic>{
        'user': <String, dynamic>{...workshopJson(), 'name': 'اسم جديد', 'city': 'دمشق'},
      });

      await h.state.updateProfile(name: '  اسم جديد ', city: ' دمشق ');
      await pumpEventQueue();

      expect(bodyOf(h.server.requestsTo('PUT', '/api/auth').single), <String, dynamic>{
        'name': 'اسم جديد',
        'city': 'دمشق',
      });
      expect(h.state.user!.name, 'اسم جديد');
      expect((jsonDecode(h.store.data[userKey]!) as Map<String, dynamic>)['name'], 'اسم جديد');

      await h.state.updateProfile(name: 'اسم جديد', city: '', newPassword: 'abcd1234');
      expect(bodyOf(h.server.requestsTo('PUT', '/api/auth').last), <String, dynamic>{
        'name': 'اسم جديد',
        'newPassword': 'abcd1234',
      });
    });

    test('a refused change is passed on and the account stays as it was', () async {
      final Harness h = await signedInHarness();
      h.server.reply('PUT', '/api/auth', <String, dynamic>{'error': 'كلمة المرور قصيرة'}, 400);

      await expectLater(
        h.state.updateProfile(name: 'x', city: 'حلب', newPassword: 'ab'),
        throwsA(apiError(status: 400, message: 'كلمة المرور قصيرة')),
      );

      expect(h.state.user!.name, 'ورشة النور');
    });

    test('a profile refresh that answers "no user" or another account is ignored', () async {
      final Harness h = await signedInHarness();

      h.server.reply('GET', '/api/auth', <String, dynamic>{'user': null});
      await h.state.refreshProfile();
      expect(h.state.isSignedIn, isTrue);
      expect(h.state.user!.id, 'w1');

      h.server.reply('GET', '/api/auth', <String, dynamic>{'user': marketerJson()});
      await h.state.refreshProfile();
      expect(h.state.user!.id, 'w1');
      expect(h.state.user!.isWorkshop, isTrue);
    });

    test('the profile photo is loaded, validated and uploaded', () async {
      final Harness h = Harness(stored: savedSession(workshopJson()));
      h.serveBackground();
      h.server.on(
        'GET',
        '/api/account/avatar',
        (http.Request _) => http.Response.bytes(<int>[1, 2, 3], 200, headers: const <String, String>{'content-type': 'image/jpeg'}),
      );
      h.server.reply('PUT', '/api/account/avatar', <String, dynamic>{'ok': true});
      await h.state.restore();
      await pumpEventQueue();
      expect(h.state.avatarBytes, orderedEquals(<int>[1, 2, 3]));

      await expectLater(
        h.state.uploadAvatar(Uint8List.fromList(<int>[1, 2, 3, 4])),
        throwsA(apiError(message: 'صيغة الصورة غير مدعومة، اختر صورة بصيغة JPG.')),
      );
      final Uint8List tooBig = Uint8List(maxAvatarBytes + 1)..setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);
      await expectLater(
        h.state.uploadAvatar(tooBig),
        throwsA(apiError(message: 'حجم الصورة كبير جداً. اختر صورة أصغر.')),
      );
      expect(h.server.requestsTo('PUT', '/api/account/avatar'), isEmpty);

      final Uint8List jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 9, 9]);
      await h.state.uploadAvatar(jpeg);
      expect(h.state.avatarBytes, orderedEquals(jpeg));
      expect(h.server.requestsTo('PUT', '/api/account/avatar').single.bodyBytes, orderedEquals(jpeg));
    });
  });

  group('theme', () {
    test('changing the theme notifies once, is saved, and survives a restart', () async {
      final Harness h = Harness();
      await h.state.restore();
      int notified = 0;
      h.state.addListener(() => notified++);

      h.state.setThemeMode(ThemeMode.light);
      h.state.setThemeMode(ThemeMode.light);
      await pumpEventQueue();

      expect(notified, 1);
      expect(h.state.themeMode, ThemeMode.light);
      expect(h.store.data[themeKey], 'light');

      final Harness again = Harness(stored: h.store.data);
      await again.state.restore();
      expect(again.state.themeMode, ThemeMode.light);
    });
  });
}
