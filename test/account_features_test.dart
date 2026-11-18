// The profile features: saved addresses and vehicles, the VIN search hand-off, password recovery, account deletion,
// currency and language. A scripted server answers; nothing touches the network or the keystore.

import 'dart:async';
import 'dart:convert';

import 'package:euro_cars/core/display.dart';
import 'package:euro_cars/core/models.dart';
import 'package:euro_cars/core/session_store.dart';
import 'package:euro_cars/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'app_state_test.dart' show Harness, bodyOf, catalogPart, signedInHarness;
import 'support/fake_server.dart';
import 'support/fixtures.dart' show marketerJson;
import 'support/matchers.dart';

Map<String, dynamic> addressJson(String id, {bool isDefault = false, String label = 'الورشة'}) {
  return <String, dynamic>{
    'id': id,
    'label': label,
    'governorate': 'حلب',
    'area': 'الفرقان',
    'street': null,
    'details': null,
    'phone': null,
    'isDefault': isDefault,
  };
}

Map<String, dynamic> vehicleJson(String id, {String vin = 'WBA3A5C55FK123456'}) {
  return <String, dynamic>{'id': id, 'vin': vin, 'name': 'سيارة الورشة', 'make': 'BMW', 'model': '320i', 'year': 2018, 'notes': null};
}

void main() {
  tearDown(DisplayPrefs.reset);

  group('addresses', () {
    test('are loaded and the default one is the checkout address', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/account/addresses', <String, dynamic>{
        'addresses': <Object>[addressJson('a1'), addressJson('a2', isDefault: true, label: 'المستودع')],
      });
      await h.state.loadAddresses();

      expect(h.state.addresses.map((SavedAddress a) => a.id), <String>['a1', 'a2']);
      expect(h.state.addressesReady, isTrue);
      expect(h.state.checkoutAddress?.id, 'a2');

      h.state.selectCheckoutAddress('a1');
      expect(h.state.checkoutAddress?.id, 'a1');
    });

    test('a server without the SQL update says it is not ready instead of failing', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/account/addresses', <String, dynamic>{'addresses': <Object>[], 'ready': false});
      await h.state.loadAddresses();
      expect(h.state.addressesReady, isFalse);
      expect(h.state.addresses, isEmpty);
    });

    test('saving sends the trimmed fields, then reloads the list', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/addresses', <String, dynamic>{'ok': true});
      h.server.reply('GET', '/api/account/addresses', <String, dynamic>{'addresses': <Object>[addressJson('a1')]});

      await h.state.saveAddress(label: ' الورشة ', governorate: 'حلب', area: ' الفرقان ', makeDefault: true);

      final Map<String, dynamic> body = bodyOf(h.server.requestsTo('POST', '/api/account/addresses').single);
      expect(body['label'], 'الورشة');
      expect(body['area'], 'الفرقان');
      expect(body['isDefault'], isTrue);
      expect(h.state.addresses, hasLength(1));
    });

    test('editing uses PUT on the address, deleting uses DELETE and forgets a chosen address', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/account/addresses', <String, dynamic>{'addresses': <Object>[addressJson('a1')]});
      h.server.reply('PUT', '/api/account/addresses/a1', <String, dynamic>{'ok': true});
      h.server.reply('DELETE', '/api/account/addresses/a1', <String, dynamic>{'ok': true});
      await h.state.loadAddresses();
      h.state.selectCheckoutAddress('a1');

      await h.state.saveAddress(id: 'a1', label: 'جديد', governorate: 'حلب');
      expect(h.server.requestsTo('PUT', '/api/account/addresses/a1'), hasLength(1));

      await h.state.setDefaultAddress('a1');
      expect(bodyOf(h.server.requestsTo('PUT', '/api/account/addresses/a1').last)['isDefault'], isTrue);

      h.server.reply('GET', '/api/account/addresses', <String, dynamic>{'addresses': <Object>[]});
      await h.state.deleteAddress('a1');
      expect(h.server.requestsTo('DELETE', '/api/account/addresses/a1'), hasLength(1));
      expect(h.state.checkoutAddress, isNull);
    });

    test('a refused save throws the server message', () async {
      final Harness h = await signedInHarness();
      h.server.reply(
        'POST',
        '/api/account/addresses',
        <String, dynamic>{'error': 'اكتب اسماً للعنوان (مثال: الورشة)'},
        400,
      );
      await expectLater(
        h.state.saveAddress(label: ''),
        throwsA(apiError(status: 400, message: 'اكتب اسماً للعنوان (مثال: الورشة)')),
      );
    });

    test('the chosen address id travels with the order', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/orders', <String, dynamic>{'orderId': 'o1', 'orderNumber': 7, 'pay': 'cod', 'total': 10.5});
      h.state.addToCart(catalogPart(h, 'p1'));

      await h.state.placeOrder(pay: 'cod', invoiceCurrency: 'SYP', addressId: 'a1');

      final List<MultipartPart> parts = parseMultipart(h.server.requestsTo('POST', '/api/orders').single);
      expect(partNamed(parts, 'addressId').text, 'a1');
      expect(partNamed(parts, 'invoiceCurrency').text, 'SYP');
    });
  });

  group('vehicles', () {
    test('are loaded, saved with a numeric year and deleted', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/account/vehicles', <String, dynamic>{'vehicles': <Object>[vehicleJson('v1')]});
      h.server.reply('POST', '/api/account/vehicles', <String, dynamic>{'ok': true});
      h.server.reply('DELETE', '/api/account/vehicles/v1', <String, dynamic>{'ok': true});
      await h.state.loadVehicles();
      expect(h.state.vehicles.single.vin, 'WBA3A5C55FK123456');

      await h.state.saveVehicle(vin: ' wba3a5c55fk123456 ', name: 'سيارة', year: 2018);
      final Map<String, dynamic> body = bodyOf(h.server.requestsTo('POST', '/api/account/vehicles').single);
      expect(body['year'], 2018);
      expect(body['name'], 'سيارة');

      await h.state.deleteVehicle('v1');
      expect(h.server.requestsTo('DELETE', '/api/account/vehicles/v1'), hasLength(1));
    });

    test('a refused VIN throws the server message', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/vehicles', <String, dynamic>{'error': 'رقم الشاصي غير صالح'}, 400);
      await expectLater(h.state.saveVehicle(vin: '12'), throwsA(apiError(status: 400)));
    });
  });

  group('searching the catalog with a VIN', () {
    test('hands the number to the catalog tab exactly once and opens that tab', () async {
      final Harness h = await signedInHarness();
      h.state.selectTab(tabOrders);

      h.state.searchCatalogFor('  WBA3A5C55FK123456 ');

      expect(h.state.selectedTab, tabCatalog);
      expect(h.state.pendingCatalogQuery, 'WBA3A5C55FK123456');
      expect(h.state.takePendingCatalogQuery(), 'WBA3A5C55FK123456');
      expect(h.state.takePendingCatalogQuery(), isNull);
    });

    test('an empty number or a signed-out user does nothing', () async {
      final Harness h = await signedInHarness();
      h.state.searchCatalogFor('   ');
      expect(h.state.pendingCatalogQuery, isNull);

      final Harness out = Harness();
      await out.state.restore();
      out.state.searchCatalogFor('WBA3A5C55FK123456');
      expect(out.state.pendingCatalogQuery, isNull);
    });
  });

  group('account data', () {
    test('changing the password sends both passwords', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'ok': true});
      await h.state.changePassword(currentPassword: 'old1', newPassword: 'new22');
      final Map<String, dynamic> body = bodyOf(h.server.requestsTo('POST', '/api/account/password').single);
      expect(body, <String, dynamic>{'currentPassword': 'old1', 'newPassword': 'new22'});
    });

    test('the fresh access token from a password change replaces the old one, so the user stays signed in', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'ok': true, 'accessToken': 'tok-after-change'});

      await h.state.changePassword(currentPassword: 'old1', newPassword: 'new22222');
      await pumpEventQueue();

      expect(h.api.token, 'tok-after-change');
      expect(h.store.data[tokenKey], 'tok-after-change');
      expect(h.state.isSignedIn, isTrue);

      h.server.reply('GET', '/api/orders', <String, dynamic>{'orders': <Object>[]});
      await h.state.loadOrders();
      expect(h.server.requestsTo('GET', '/api/orders').last.headers['authorization'], 'Bearer tok-after-change');
    });

    test('without an accessToken in the answer the old token stays (older servers)', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'ok': true});

      await h.state.changePassword(currentPassword: 'old1', newPassword: 'new22222');

      expect(h.api.token, 'tok-1');
      expect(h.store.data[tokenKey], 'tok-1');
      expect(h.state.isSignedIn, isTrue);
    });

    test('a 401 that a background refresh gets while the password is being changed does not sign the user out', () async {
      final Harness h = await signedInHarness();
      final Completer<http.Response> gate = Completer<http.Response>();
      h.server.on('POST', '/api/account/password', (http.Request _) => gate.future);
      h.server.reply('GET', '/api/orders', <String, dynamic>{'error': 'الجلسة غير صالحة'}, 401);
      h.server.reply('GET', '/api/auth', <String, dynamic>{'user': null});

      final Future<void> change = h.state.changePassword(currentPassword: 'old1', newPassword: 'new22222');
      await pumpEventQueue();
      await h.state.loadOrders(); // the old token is already refused by the server
      await pumpEventQueue();
      expect(h.state.isSignedIn, isTrue, reason: 'the 401 is held back while the change is in flight');

      gate.complete(jsonResponse(<String, dynamic>{'ok': true, 'accessToken': 'tok-after-change'}));
      await change;
      await pumpEventQueue();

      expect(h.state.isSignedIn, isTrue);
      expect(h.api.token, 'tok-after-change');
    });

    test('a held 401 is acted on when the password change brings no new token', () async {
      final Harness h = await signedInHarness();
      final Completer<http.Response> gate = Completer<http.Response>();
      h.server.on('POST', '/api/account/password', (http.Request _) => gate.future);
      h.server.reply('GET', '/api/orders', <String, dynamic>{'error': 'الجلسة غير صالحة'}, 401);

      final Future<void> change = h.state.changePassword(currentPassword: 'old1', newPassword: 'new22222');
      await pumpEventQueue();
      await h.state.loadOrders();
      gate.complete(jsonResponse(<String, dynamic>{'ok': true}));
      await change;
      await pumpEventQueue();

      expect(h.state.status, SessionStatus.signedOut);
    });

    test('a new token that arrives after signing out is not stored', () async {
      final Harness h = await signedInHarness();
      final Completer<http.Response> gate = Completer<http.Response>();
      h.server.on('POST', '/api/account/password', (http.Request _) => gate.future);

      final Future<void> change = h.state.changePassword(currentPassword: 'old1', newPassword: 'new22222');
      await pumpEventQueue();
      await h.state.logout();
      gate.complete(jsonResponse(<String, dynamic>{'ok': true, 'accessToken': 'tok-late'}));
      await change;

      expect(h.api.token, isNull);
      expect(h.store.data.containsKey(tokenKey), isFalse);
    });

    test('a wrong current password is reported and does not end the session', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'error': 'كلمة المرور الحالية غير صحيحة'}, 403);
      await expectLater(
        h.state.changePassword(currentPassword: 'x', newPassword: 'new22'),
        throwsA(apiError(status: 403, message: 'كلمة المرور الحالية غير صحيحة')),
      );
      expect(h.state.isSignedIn, isTrue);
      expect(h.api.token, 'tok-1');
    });

    test('a phone change is two steps and the new session token replaces the old one', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/phone', <String, dynamic>{'ok': true, 'message': 'تم إرسال الرمز'});
      final String message = await h.state.requestPhoneChange(newPhone: '+963 933 000 111', currentPassword: 'pw');
      expect(message, 'تم إرسال الرمز');
      final Map<String, dynamic> first = bodyOf(h.server.requestsTo('POST', '/api/account/phone').single);
      expect(first['mode'], 'request');
      expect(first['newPhone'], '+963933000111');

      h.server.reply('POST', '/api/account/phone', <String, dynamic>{
        'ok': true,
        'accessToken': 'tok-new',
        'user': <String, dynamic>{'id': 'w1', 'role': 'workshop', 'name': 'ورشة النور', 'phone': '963933000111'},
      });
      await h.state.confirmPhoneChange(newPhone: '963933000111', code: '١٢٣٤٥٦');
      final Map<String, dynamic> second = bodyOf(h.server.requestsTo('POST', '/api/account/phone').last);
      expect(second['mode'], 'confirm');
      expect(second['code'], '123456');
      expect(h.api.token, 'tok-new');
      expect(h.store.data[tokenKey], 'tok-new');
      expect(h.state.user?.phone, '963933000111');
    });
  });

  group('accounts made with e-mail (no phone and no password yet)', () {
    Map<String, dynamic> emailMarketer() => <String, dynamic>{
          ...marketerJson(),
          'phone': null,
          'has_password': false,
          'phone_verified': false,
        };

    Map<String, dynamic> dashboardJson({required bool phoneVerified}) => <String, dynamic>{
          'marketer': <String, dynamic>{
            'name': 'مسوّق الشمال',
            'code': 'MK-1A2B3C',
            'referralUrl': phoneVerified ? 'https://example.test/r?ref=MK-1A2B3C&sig=abc' : null,
            'phoneVerified': phoneVerified,
          },
          'workshops': 0,
          'commissions': <String, dynamic>{'available': 0, 'held': 0, 'paid': 0, 'total': 0},
        };

    test('an older server sends no flags: the account counts as having a password and a confirmed phone', () {
      final AppUser user = AppUser.fromJson(marketerJson());
      expect(user.hasPhone, isTrue);
      expect(user.hasPassword, isTrue);
      expect(user.phoneVerified, isTrue);

      final AppUser noPhone = AppUser.fromJson(<String, dynamic>{...marketerJson(), 'phone': null});
      expect(noPhone.hasPhone, isFalse);
      expect(noPhone.phoneVerified, isFalse);
    });

    test('the flags of an e-mail account choose "add" instead of "change"', () async {
      final Harness h = await signedInHarness(account: emailMarketer());
      final AppUser user = h.state.user!;
      expect(user.hasPhone, isFalse);
      expect(user.hasPassword, isFalse);
      expect(user.phoneVerified, isFalse);
    });

    test('the marketer dashboard says whether the invitation link is locked', () {
      final MarketerDashboard locked = MarketerDashboard.fromJson(dashboardJson(phoneVerified: false));
      expect(locked.phoneVerified, isFalse);
      expect(locked.referralUrl, isEmpty);

      final MarketerDashboard open = MarketerDashboard.fromJson(dashboardJson(phoneVerified: true));
      expect(open.phoneVerified, isTrue);
      expect(open.referralUrl, contains('sig=abc'));

      final Map<String, dynamic> older = dashboardJson(phoneVerified: true);
      (older['marketer'] as Map<String, dynamic>).remove('phoneVerified');
      expect(MarketerDashboard.fromJson(older).phoneVerified, isTrue, reason: 'older servers have no lock');
    });

    test('the first password is sent alone, keeps the user signed in and ends the "no password" state', () async {
      final Harness h = await signedInHarness(account: emailMarketer());
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'ok': true, 'accessToken': 'tok-first', 'has_password': true});

      await h.state.addPassword(newPassword: 'abcd1234');
      await pumpEventQueue();

      expect(bodyOf(h.server.requestsTo('POST', '/api/account/password').single), <String, dynamic>{'newPassword': 'abcd1234'});
      expect(h.api.token, 'tok-first');
      expect(h.store.data[tokenKey], 'tok-first');
      expect(h.state.isSignedIn, isTrue);
      expect(h.state.user!.hasPassword, isTrue);
    });

    test('a refused first password (one exists already) is reported and changes nothing', () async {
      final Harness h = await signedInHarness(account: emailMarketer());
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'error': 'لهذا الحساب كلمة مرور بالفعل'}, 409);
      await expectLater(h.state.addPassword(newPassword: 'abcd1234'), throwsA(apiError(status: 409)));
      expect(h.state.user!.hasPassword, isFalse);
      expect(h.api.token, 'tok-1');
    });

    test('a phone is added with the SMS code alone, and the invitation link unlocks afterwards', () async {
      final Harness h = await signedInHarness(account: emailMarketer());
      h.server.reply('POST', '/api/account/phone', <String, dynamic>{'ok': true, 'message': 'تم إرسال الرمز'});
      await h.state.requestPhoneChange(newPhone: '0933000111');
      final Map<String, dynamic> first = bodyOf(h.server.requestsTo('POST', '/api/account/phone').single);
      expect(first['mode'], 'request');
      expect(first.containsKey('currentPassword'), isFalse, reason: 'there is no password to ask for');

      h.server.reply('GET', '/api/marketer/dashboard', dashboardJson(phoneVerified: true));
      h.server.reply('POST', '/api/account/phone', <String, dynamic>{
        'ok': true,
        'accessToken': 'tok-new',
        'user': <String, dynamic>{
          'id': 'm1',
          'role': 'marketer',
          'name': 'مسوّق الشمال',
          'phone': '963933000111',
          'phone_verified': true,
          'has_password': false,
        },
      });
      await h.state.confirmPhoneChange(newPhone: '963933000111', code: '123456');
      await pumpEventQueue();

      expect(h.api.token, 'tok-new');
      expect(h.state.user!.hasPhone, isTrue);
      expect(h.state.user!.phoneVerified, isTrue);
      expect(h.state.user!.hasPassword, isFalse, reason: 'adding a phone does not add a password');
      expect(h.server.requestsTo('GET', '/api/marketer/dashboard'), hasLength(1));
      expect(h.state.marketerDashboard?.phoneVerified, isTrue);
      expect(h.state.marketerDashboard?.referralUrl, contains('sig=abc'));
    });

    test('forgot password while signed in: SMS code, then a new password, and this device stays signed in', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'ok': true, 'message': 'تم إرسال الرمز'});
      expect(await h.state.requestPasswordRecovery(), 'تم إرسال الرمز');
      expect(bodyOf(h.server.requestsTo('POST', '/api/account/password').single), <String, dynamic>{'mode': 'forgot-request'});

      h.server.reply('POST', '/api/account/password', <String, dynamic>{'ok': true, 'accessToken': 'tok-forgot', 'has_password': true});
      await h.state.confirmPasswordRecovery(code: '١٢٣٤٥٦', newPassword: 'abcd1234');
      await pumpEventQueue();

      expect(bodyOf(h.server.requestsTo('POST', '/api/account/password').last), <String, dynamic>{
        'mode': 'forgot-confirm',
        'code': '123456',
        'newPassword': 'abcd1234',
      });
      expect(h.api.token, 'tok-forgot');
      expect(h.store.data[tokenKey], 'tok-forgot');
      expect(h.state.isSignedIn, isTrue);
    });

    test('a wrong recovery code is reported with the server message', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'error': 'الرمز غير صحيح أو انتهت صلاحيته.'}, 400);
      await expectLater(
        h.state.confirmPasswordRecovery(code: '000000', newPassword: 'abcd1234'),
        throwsA(apiError(status: 400)),
      );
      expect(h.state.isSignedIn, isTrue);
      expect(h.api.token, 'tok-1');
    });
  });

  group('account deletion', () {
    test('a pending request is read, started and cancelled', () async {
      final Harness h = await signedInHarness();
      final String due = DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String();
      h.server.reply('GET', '/api/account/deletion', <String, dynamic>{'request': null, 'ready': true});
      await h.state.loadDeletion();
      expect(h.state.deletion, isNull);

      h.server.reply('POST', '/api/account/deletion', <String, dynamic>{'message': 'code sent'});
      expect(await h.state.sendAccountDeletionCode(), 'code sent');
      expect(h.state.deletion, isNull, reason: 'sending the code does not start the countdown');

      h.server.reply('POST', '/api/account/deletion', <String, dynamic>{
        'request': <String, dynamic>{'requestedAt': DateTime.now().toUtc().toIso8601String(), 'dueAt': due},
      });
      await h.state.confirmAccountDeletion(' 123456 ');
      final List<Map<String, dynamic>> bodies =
          h.server.requestsTo('POST', '/api/account/deletion').map(bodyOf).toList();
      expect(bodies, <Map<String, dynamic>>[
        <String, dynamic>{'action': 'send-code'},
        <String, dynamic>{'action': 'confirm-code', 'code': '123456'},
      ]);
      expect(h.state.deletion?.daysLeft, inInclusiveRange(29, 30));

      h.server.reply('DELETE', '/api/account/deletion', <String, dynamic>{'ok': true});
      await h.state.cancelAccountDeletion();
      expect(h.state.deletion, isNull);
    });

    test('a wrong email code does not start the countdown', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/deletion', <String, dynamic>{'error': 'رمز التحقق غير صحيح'}, 403);
      await expectLater(h.state.confirmAccountDeletion('000000'), throwsA(apiError(status: 403)));
      expect(h.state.deletion, isNull);
    });
  });

  group('forgot password', () {
    test('the request is sent without a session and shows the same message for any number', () async {
      final Harness h = Harness();
      await h.state.restore();
      h.server.reply('POST', '/api/password-reset/user', <String, dynamic>{'ok': true, 'message': 'إن كان الرقم مسجلاً لدينا فسيصلك رمز التحقق برسالة نصية خلال دقيقة.'});

      final String message = await h.state.requestPasswordReset(role: 'workshop', phone: ' 0982026134 ');

      expect(message, startsWith('إن كان الرقم مسجلاً'));
      final http.Request request = h.server.requestsTo('POST', '/api/password-reset/user').single;
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(bodyOf(request), <String, dynamic>{'mode': 'request', 'role': 'workshop', 'phone': '0982026134'});
    });

    test('confirming sends the code with Western digits and the new password', () async {
      final Harness h = Harness();
      await h.state.restore();
      h.server.reply('POST', '/api/password-reset/user', <String, dynamic>{'ok': true, 'message': 'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.'});

      await h.state.confirmPasswordReset(role: 'marketer', phone: '0933000111', code: '٠٠١٢٣٤', newPassword: 'abcd');

      final Map<String, dynamic> body = bodyOf(h.server.requestsTo('POST', '/api/password-reset/user').single);
      expect(body['mode'], 'confirm');
      expect(body['code'], '001234');
      expect(body['newPassword'], 'abcd');
    });

    test('a wrong or expired code is reported with the server message', () async {
      final Harness h = Harness();
      await h.state.restore();
      h.server.reply('POST', '/api/password-reset/user', <String, dynamic>{'error': 'الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزاً جديداً وحاول مجدداً.'}, 400);
      await expectLater(
        h.state.confirmPasswordReset(role: 'workshop', phone: '0982026134', code: '111111', newPassword: 'abcd'),
        throwsA(apiError(status: 400)),
      );
    });
  });

  group('currency and language', () {
    test('Syrian pounds need a published rate', () async {
      final Harness h = await signedInHarness();
      expect(h.state.canShowSyp, isFalse);
      expect(h.state.setCurrency(currencySyp), isFalse);
      expect(h.state.currency, currencyUsd);

      h.server.reply('GET', '/api/settings', <String, dynamic>{'usdToSyp': 15000});
      await h.state.loadSettings();
      expect(h.state.canShowSyp, isTrue);
      expect(h.state.canUseSypInvoices, isFalse, reason: 'a published rate alone does not prove stability');
      expect(h.state.setCurrency(currencySyp), isTrue);
      expect(DisplayPrefs.showSyp, isTrue);
    });

    test('only a fresh stable server decision enables SYP invoices', () async {
      final Harness h = await signedInHarness();
      h.server.reply('GET', '/api/settings', <String, dynamic>{
        'usdToSyp': 143.75,
        'canUseSypInvoices': true,
        'rateStatus': 'stable',
      });
      await h.state.loadSettings();
      expect(h.state.canUseSypInvoices, isTrue);
      expect(h.state.invoiceRate, 143.75);

      h.server.reply('GET', '/api/settings', <String, dynamic>{
        'usdToSyp': 143.75,
        'canUseSypInvoices': false,
        'rateStatus': 'unstable',
      });
      await h.state.loadSettings();
      expect(h.state.canUseSypInvoices, isFalse);
      expect(h.state.invoiceRate, isNull);
    });

    test('the choices are saved on the device and the app tree is told to rebuild', () async {
      final Harness h = await signedInHarness();
      final int before = h.state.displayVersion;
      h.state.setLanguage(languageEnglish);
      await pumpEventQueue();

      expect(h.state.language, languageEnglish);
      expect(DisplayPrefs.isEnglish, isTrue);
      expect(h.store.data[languageKey], languageEnglish);
      expect(h.state.displayVersion, greaterThan(before));
    });
  });

  test('the JSON helpers used above really encode UTF-8', () {
    expect(jsonDecode(utf8.decode(utf8.encode(jsonEncode(<String, String>{'a': 'حلب'})))), <String, String>{'a': 'حلب'});
  });
}
