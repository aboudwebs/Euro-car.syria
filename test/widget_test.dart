// Widget tests: the whole app is started with an in-memory store and a scripted server, so nothing touches the
// device keystore or the network.

import 'dart:convert';

import 'package:euro_cars/app.dart';
import 'package:euro_cars/core/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';
import 'support/fixtures.dart';
import 'support/memory_store.dart';

/// Loads the bundled Arabic font so text has realistic widths (the test engine otherwise draws every glyph as a
/// full-width square, which makes rows overflow that are fine on a phone).
Future<void> loadAppFont() async {
  try {
    final FontLoader loader = FontLoader('Tajawal');
    for (final String name in <String>['Regular', 'Medium', 'Bold', 'ExtraBold', 'Black']) {
      loader.addFont(rootBundle.load('assets/fonts/Tajawal-$name.ttf'));
    }
    await loader.load();
  } catch (_) {
    // Without the font the test still runs with the default test font.
  }
}

/// A phone-sized screen.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadAppFont);

  group('signed out', () {
    testWidgets('shows a spinner while the saved session is read, then the sign-in screen', (WidgetTester tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(EuroApp(store: MemoryStore(), httpClient: FakeServer().client));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('رقم الموبايل'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('تسجيل دخول الورشة / الشركة'), findsOneWidget);
      expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    });

    testWidgets('choosing the marketer role changes the sign-in button', (WidgetTester tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(EuroApp(store: MemoryStore(), httpClient: FakeServer().client));
      await settle(tester);

      await tester.tap(find.text('حساب عميل / مسوّق'));
      await settle(tester);

      expect(find.text('تسجيل دخول المسوّق'), findsOneWidget);
      expect(find.text('تسجيل دخول الورشة / الشركة'), findsNothing);
    });

    testWidgets('an empty form is rejected before any request is sent', (WidgetTester tester) async {
      usePhoneScreen(tester);
      final FakeServer server = FakeServer();
      await tester.pumpWidget(EuroApp(store: MemoryStore(), httpClient: server.client));
      await settle(tester);

      await tester.ensureVisible(find.text('تسجيل دخول الورشة / الشركة'));
      await tester.tap(find.text('تسجيل دخول الورشة / الشركة'));
      await settle(tester);

      expect(find.text('يرجى إدخال رقم الموبايل وكلمة مرور من 4 أحرف على الأقل'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('a wrong password shows the Arabic message from the server', (WidgetTester tester) async {
      usePhoneScreen(tester);
      final FakeServer server = FakeServer()
        ..reply('POST', '/api/auth', <String, dynamic>{'error': 'بيانات الدخول غير صحيحة'}, 401);
      await tester.pumpWidget(EuroApp(store: MemoryStore(), httpClient: server.client));
      await settle(tester);

      await tester.enterText(find.byType(TextField).at(0), '0982026134');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
      await tester.ensureVisible(find.text('تسجيل دخول الورشة / الشركة'));
      await tester.tap(find.text('تسجيل دخول الورشة / الشركة'));
      await settle(tester);

      expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
      expect(server.requestsTo('POST', '/api/auth'), hasLength(1));
    });

    testWidgets('forgot password opens the WhatsApp recovery page and asks for the number first', (WidgetTester tester) async {
      usePhoneScreen(tester);
      final FakeServer server = FakeServer();
      await tester.pumpWidget(EuroApp(store: MemoryStore(), httpClient: server.client));
      await settle(tester);

      await tester.ensureVisible(find.text('نسيت كلمة المرور؟'));
      await tester.tap(find.text('نسيت كلمة المرور؟'));
      await settle(tester);

      expect(find.text('استعادة كلمة المرور عبر واتساب'), findsOneWidget);
      expect(find.text('إرسال رمز التحقق'), findsOneWidget);

      // A too short number is refused on the device; nothing is sent.
      await tester.tap(find.text('إرسال رمز التحقق'));
      await settle(tester);
      expect(find.text('أدخل رقم الموبايل المسجل في حسابك.'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('the registration screen opens from the sign-in screen', (WidgetTester tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(EuroApp(store: MemoryStore(), httpClient: FakeServer().client));
      await settle(tester);

      await tester.ensureVisible(find.text('إنشاء حساب جديد'));
      await tester.tap(find.text('إنشاء حساب جديد'));
      await settle(tester);

      expect(find.text('بيانات اعتماد الورشة الجديدة'), findsOneWidget);
    });
  });

  group('signed in', () {
    FakeServer serverFor(Map<String, dynamic> account) {
      return FakeServer()
        ..reply('GET', '/api/parts', <String, dynamic>{'parts': catalogJson()})
        ..reply('GET', '/api/account/avatar', <String, dynamic>{'error': 'no photo'}, 404)
        ..reply('GET', '/api/auth', <String, dynamic>{'user': account})
        ..reply('GET', '/api/orders', <String, dynamic>{'orders': <Object>[]})
        ..reply('GET', '/api/special-requests', <String, dynamic>{'requests': <Object>[]})
        ..reply('GET', '/api/workshop/dashboard', <String, dynamic>{
          'user': account,
          'orders': <Object>[],
          'ledger': <Object>[],
        })
        ..reply('GET', '/api/marketer/dashboard', <String, dynamic>{
          'marketer': <String, dynamic>{
            'name': 'مسوّق الشمال',
            'code': 'MK-1A2B3C',
            'referralUrl': 'https://example.test/login?ref=MK-1A2B3C&sig=abc',
          },
          'workshops': 0,
          'commissions': <String, dynamic>{'available': 0, 'held': 0, 'paid': 0, 'total': 0},
        });
    }

    Future<void> openEveryTab(WidgetTester tester) async {
      for (final String label in <String>['السلة', 'طلباتي', 'لوحتي', 'حسابي', 'الكتالوج']) {
        await tester.tap(find.text(label).last);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'tab $label');
      }
    }

    testWidgets('the account tab offers settings, the four pages and the deletion option', (WidgetTester tester) async {
      usePhoneScreen(tester);
      final Map<String, dynamic> account = workshopJson();
      final FakeServer server = serverFor(account);
      final MemoryStore store = MemoryStore(<String, String>{tokenKey: 'tok-1', userKey: jsonEncode(account)});
      await tester.pumpWidget(EuroApp(store: store, httpClient: server.client));
      await settle(tester);

      await tester.tap(find.text('حسابي').last);
      await settle(tester);

      for (final String title in <String>['العملة', 'اللغة', 'بيانات الحساب', 'عناويني', 'مركباتي']) {
        await tester.scrollUntilVisible(find.text(title), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(title), findsOneWidget, reason: title);
      }
      for (final String title in <String>['عن EURO', 'حذف الحساب']) {
        await tester.scrollUntilVisible(find.text(title), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('طلباتي النشطة'), findsNothing);
      expect(find.text('طلباتي السابقة'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final Map<String, dynamic> account in <Map<String, dynamic>>[workshopJson(), marketerJson()]) {
      final String role = account['role'] as String;

      testWidgets('a saved $role session opens the app with the catalog and every tab', (WidgetTester tester) async {
        usePhoneScreen(tester);
        final FakeServer server = serverFor(account);
        final MemoryStore store = MemoryStore(<String, String>{
          tokenKey: 'tok-1',
          userKey: jsonEncode(account),
        });
        await tester.pumpWidget(EuroApp(store: store, httpClient: server.client));
        await settle(tester);

        expect(find.byType(NavigationBar), findsOneWidget);
        for (final String label in <String>['الكتالوج', 'السلة', 'طلباتي', 'لوحتي', 'حسابي']) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        expect(find.text('فلتر زيت'), findsWidgets);

        await openEveryTab(tester);

        // Leave the tree so the app releases its listeners and HTTP client.
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });
}
