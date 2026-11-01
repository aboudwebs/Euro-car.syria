// The profile features: saved addresses and vehicles, the VIN search hand-off, password recovery, account deletion,
// currency and language. A scripted server answers; nothing touches the network or the keystore.

import 'dart:convert';

import 'package:euro_cars/core/display.dart';
import 'package:euro_cars/core/models.dart';
import 'package:euro_cars/core/session_store.dart';
import 'package:euro_cars/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'app_state_test.dart' show Harness, bodyOf, catalogPart, signedInHarness;
import 'support/fake_server.dart';
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

      await h.state.placeOrder(pay: 'cod', addressId: 'a1');

      final List<MultipartPart> parts = parseMultipart(h.server.requestsTo('POST', '/api/orders').single);
      expect(partNamed(parts, 'addressId').text, 'a1');
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

    test('a wrong current password is reported', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/password', <String, dynamic>{'error': 'كلمة المرور الحالية غير صحيحة'}, 403);
      await expectLater(
        h.state.changePassword(currentPassword: 'x', newPassword: 'new22'),
        throwsA(apiError(status: 403, message: 'كلمة المرور الحالية غير صحيحة')),
      );
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

  group('account deletion', () {
    test('a pending request is read, started and cancelled', () async {
      final Harness h = await signedInHarness();
      final String due = DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String();
      h.server.reply('GET', '/api/account/deletion', <String, dynamic>{'request': null, 'ready': true});
      await h.state.loadDeletion();
      expect(h.state.deletion, isNull);

      h.server.reply('POST', '/api/account/deletion', <String, dynamic>{
        'request': <String, dynamic>{'requestedAt': DateTime.now().toUtc().toIso8601String(), 'dueAt': due},
      });
      await h.state.requestAccountDeletion('pw');
      expect(bodyOf(h.server.requestsTo('POST', '/api/account/deletion').single), <String, dynamic>{'password': 'pw'});
      expect(h.state.deletion?.daysLeft, inInclusiveRange(29, 30));

      h.server.reply('DELETE', '/api/account/deletion', <String, dynamic>{'ok': true});
      await h.state.cancelAccountDeletion();
      expect(h.state.deletion, isNull);
    });

    test('a wrong password does not start the countdown', () async {
      final Harness h = await signedInHarness();
      h.server.reply('POST', '/api/account/deletion', <String, dynamic>{'error': 'كلمة المرور غير صحيحة'}, 403);
      await expectLater(h.state.requestAccountDeletion('bad'), throwsA(apiError(status: 403)));
      expect(h.state.deletion, isNull);
    });
  });

  group('forgot password', () {
    test('the request is sent without a session and shows the same message for any number', () async {
      final Harness h = Harness();
      await h.state.restore();
      h.server.reply('POST', '/api/password-reset/user', <String, dynamic>{'ok': true, 'message': 'إن كان الرقم مسجلاً لدينا فسيصلك رمز التحقق على واتساب خلال دقيقة.'});

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
