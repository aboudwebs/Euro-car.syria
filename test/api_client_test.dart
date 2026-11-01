import 'dart:convert';
import 'dart:typed_data';

import 'package:euro_cars/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_server.dart';
import 'support/matchers.dart';

ApiClient makeClient(FakeServer server, {String baseUrl = 'https://api.test', String? token = 'tok'}) {
  final ApiClient api = ApiClient(baseUrl: baseUrl, client: server.client, retryDelay: Duration.zero);
  api.token = token;
  return api;
}

void main() {
  group('request headers', () {
    test('GET sends the bearer token and no cookie', () async {
      final FakeServer server = FakeServer()..reply('GET', '/api/parts', <String, dynamic>{'parts': <Object>[]});
      final ApiClient api = makeClient(server);

      final Map<String, dynamic> data = await api.getJson('/api/parts');

      expect(data['parts'], isEmpty);
      final http.Request request = server.requests.single;
      expect(request.url.toString(), 'https://api.test/api/parts');
      expect(request.headers['authorization'], 'Bearer tok');
      expect(request.headers['accept'], 'application/json');
      expect(request.headers.containsKey('cookie'), isFalse);
    });

    test('a call without auth carries no token', () async {
      final FakeServer server = FakeServer()..reply('GET', '/api/public', <String, dynamic>{'ok': true});
      final ApiClient api = makeClient(server);

      await api.getJson('/api/public', auth: false);

      expect(server.requests.single.headers.containsKey('authorization'), isFalse);
    });

    test('an empty or missing token sends no Authorization header', () async {
      final FakeServer server = FakeServer()..reply('GET', '/api/public', <String, dynamic>{'ok': true});

      await makeClient(server, token: '').getJson('/api/public');
      await makeClient(server, token: null).getJson('/api/public');

      expect(server.requests, hasLength(2));
      for (final http.Request request in server.requests) {
        expect(request.headers.containsKey('authorization'), isFalse);
      }
    });

    test('the profile calls also send the session cookie', () async {
      final FakeServer server = FakeServer()
        ..reply('GET', '/api/auth', <String, dynamic>{'user': null})
        ..reply('PUT', '/api/auth', <String, dynamic>{'user': <String, dynamic>{'name': 'محمد'}});
      final ApiClient api = makeClient(server);

      await api.getProfile();
      await api.putProfile(<String, dynamic>{'name': 'محمد'});

      final http.Request get = server.requestsTo('GET', '/api/auth').single;
      expect(get.headers['cookie'], 'euro_session=tok');
      expect(get.headers['authorization'], 'Bearer tok');

      final http.Request put = server.requestsTo('PUT', '/api/auth').single;
      expect(put.headers['cookie'], 'euro_session=tok');
      expect(put.headers['authorization'], 'Bearer tok');
      expect(put.headers['content-type'], 'application/json; charset=utf-8');
      expect(jsonDecode(utf8.decode(put.bodyBytes)), <String, dynamic>{'name': 'محمد'});
    });

    test('JSON bodies are sent as UTF-8', () async {
      final FakeServer server = FakeServer()..reply('POST', '/api/auth', <String, dynamic>{'ok': true});
      final ApiClient api = makeClient(server);

      await api.postJson('/api/auth', <String, dynamic>{'name': 'محمد', 'phone': '0982026134'}, auth: false);

      final http.Request request = server.requests.single;
      expect(request.headers['content-type'], 'application/json; charset=utf-8');
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(
        jsonDecode(utf8.decode(request.bodyBytes)),
        <String, dynamic>{'name': 'محمد', 'phone': '0982026134'},
      );
    });

    test('JSON mutations carry the supplied idempotency key', () async {
      final FakeServer server = FakeServer()..reply('POST', '/api/account/addresses', <String, dynamic>{'ok': true});
      final ApiClient api = makeClient(server);

      await api.postJson(
        '/api/account/addresses',
        <String, dynamic>{'label': 'البيت'},
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
      );

      expect(server.requests.single.headers['idempotency-key'], '11111111-1111-4111-8111-111111111111');
    });

    test('a trailing slash on the base URL is ignored', () async {
      final FakeServer server = FakeServer()..reply('GET', '/api/parts', <String, dynamic>{'parts': <Object>[]});
      final ApiClient api = makeClient(server, baseUrl: 'https://api.test/');

      await api.getJson('/api/parts');

      expect(api.baseUrl, 'https://api.test');
      expect(server.requests.single.url.toString(), 'https://api.test/api/parts');
    });
  });

  group('error handling', () {
    test('Arabic error messages are decoded as UTF-8', () async {
      final FakeServer server = FakeServer()
        ..reply('POST', '/api/auth', <String, dynamic>{'error': 'رقم الهاتف مسجل مسبقاً'}, 400);
      final ApiClient api = makeClient(server);

      await expectLater(
        api.postJson('/api/auth', <String, dynamic>{}, auth: false),
        throwsA(apiError(status: 400, message: 'رقم الهاتف مسجل مسبقاً')),
      );
    });

    test('a status without a message gets a readable Arabic fallback', () async {
      const Map<int, String> fallbacks = <int, String>{
        401: 'انتهت الجلسة، سجّل الدخول مجدداً.',
        403: 'غير مصرح بهذه العملية.',
        404: 'الخدمة المطلوبة غير موجودة على الخادم.',
        413: 'حجم الملف كبير جداً.',
        429: 'محاولات كثيرة، حاول مجدداً بعد قليل.',
        500: 'حدث خطأ في الخادم، حاول مجدداً لاحقاً.',
        503: 'الخادم غير متاح حالياً أو قيد التشغيل، حاول مجدداً بعد لحظات.',
        418: 'تعذر إتمام العملية (رمز 418).',
      };
      for (final MapEntry<int, String> entry in fallbacks.entries) {
        final FakeServer server = FakeServer()
          ..on(
            'GET',
            '/api/x',
            (http.Request _) => http.Response.bytes(utf8.encode('not json'), entry.key),
          );
        final ApiClient api = makeClient(server);

        await expectLater(
          api.getJson('/api/x', retry: false),
          throwsA(apiError(status: entry.key, message: entry.value)),
          reason: 'status ${entry.key}',
        );
      }
    });

    test('an empty error body also gets the fallback', () async {
      final FakeServer server = FakeServer()
        ..on('GET', '/api/x', (http.Request _) => http.Response.bytes(<int>[], 500));
      final ApiClient api = makeClient(server);

      await expectLater(
        api.getJson('/api/x'),
        throwsA(apiError(status: 500, message: 'حدث خطأ في الخادم، حاول مجدداً لاحقاً.')),
      );
    });

    test('a 2xx answer that is not a JSON object is a bad response', () async {
      for (final String body in <String>['<html>hello</html>', '[1,2]', '']) {
        final FakeServer server = FakeServer()
          ..on('GET', '/api/x', (http.Request _) => http.Response.bytes(utf8.encode(body), 200));
        final ApiClient api = makeClient(server);

        await expectLater(
          api.getJson('/api/x'),
          throwsA(apiError(status: 200, message: badResponseMessage)),
          reason: 'body "$body"',
        );
      }
    });

    test('a 401 on an authenticated call reports an expired session once', () async {
      final FakeServer server = FakeServer()
        ..reply('GET', '/api/orders', <String, dynamic>{'error': 'غير مصرح'}, 401);
      final ApiClient api = makeClient(server);
      int fired = 0;
      api.onUnauthorized = () => fired++;

      await expectLater(
        api.getJson('/api/orders'),
        throwsA(apiError(status: 401, unauthorized: true, message: 'غير مصرح')),
      );

      expect(fired, 1);
      expect(server.requests, hasLength(1), reason: 'a 401 is not retried');
    });

    test('a 401 on a call without auth (a wrong password) is not a session expiry', () async {
      final FakeServer server = FakeServer()
        ..reply('POST', '/api/auth', <String, dynamic>{'error': 'بيانات الدخول غير صحيحة'}, 401);
      final ApiClient api = makeClient(server, token: null);
      int fired = 0;
      api.onUnauthorized = () => fired++;

      await expectLater(
        api.postJson('/api/auth', <String, dynamic>{}, auth: false),
        throwsA(apiError(status: 401, unauthorized: false, message: 'بيانات الدخول غير صحيحة')),
      );

      expect(fired, 0);
    });

    test('the pending approval flag is read from the body', () async {
      final FakeServer server = FakeServer()
        ..reply(
          'POST',
          '/api/auth',
          <String, dynamic>{'error': 'حسابك قيد المراجعة', 'pendingApproval': true},
          403,
        );
      final ApiClient api = makeClient(server, token: null);

      await expectLater(
        api.postJson('/api/auth', <String, dynamic>{}, auth: false),
        throwsA(apiError(status: 403, pending: true, message: 'حسابك قيد المراجعة')),
      );
    });

    test('a connection failure becomes a network error with an Arabic message', () async {
      final FakeServer server = FakeServer()
        ..on('POST', '/api/auth', (http.Request _) => throw http.ClientException('offline'));
      final ApiClient api = makeClient(server, token: null);

      await expectLater(
        api.postJson('/api/auth', <String, dynamic>{}, auth: false),
        throwsA(apiError(network: true, message: networkErrorMessage)),
      );
    });
  });

  group('retries', () {
    test('a GET is retried once after a 503 and then succeeds', () async {
      final FakeServer server = FakeServer();
      int calls = 0;
      server.on('GET', '/api/parts', (http.Request _) {
        calls++;
        return calls == 1
            ? jsonResponse(<String, dynamic>{'error': 'waking up'}, 503)
            : jsonResponse(<String, dynamic>{'parts': <Object>[]});
      });
      final ApiClient api = makeClient(server);

      final Map<String, dynamic> data = await api.getJson('/api/parts');

      expect(data['parts'], isEmpty);
      expect(calls, 2);
    });

    test('a GET gives up after the second 503', () async {
      final FakeServer server = FakeServer()
        ..reply('GET', '/api/parts', <String, dynamic>{'error': 'still asleep'}, 503);
      final ApiClient api = makeClient(server);

      await expectLater(api.getJson('/api/parts'), throwsA(apiError(status: 503, message: 'still asleep')));

      expect(server.requests, hasLength(2));
    });

    test('a GET is retried once after a connection failure', () async {
      final FakeServer server = FakeServer();
      int calls = 0;
      server.on('GET', '/api/parts', (http.Request _) {
        calls++;
        if (calls == 1) {
          throw http.ClientException('connection reset');
        }
        return jsonResponse(<String, dynamic>{'parts': <Object>[]});
      });
      final ApiClient api = makeClient(server);

      await api.getJson('/api/parts');

      expect(calls, 2);
    });

    test('two connection failures in a row give a network error', () async {
      final FakeServer server = FakeServer()
        ..on('GET', '/api/parts', (http.Request _) => throw http.ClientException('offline'));
      final ApiClient api = makeClient(server);

      await expectLater(
        api.getJson('/api/parts'),
        throwsA(apiError(network: true, message: networkErrorMessage)),
      );

      expect(server.requests, hasLength(2));
    });

    test('a 500 is a real server error and is not retried', () async {
      final FakeServer server = FakeServer()..reply('GET', '/api/parts', <String, dynamic>{'error': 'boom'}, 500);
      final ApiClient api = makeClient(server);

      await expectLater(api.getJson('/api/parts'), throwsA(apiError(status: 500)));

      expect(server.requests, hasLength(1));
    });

    test('retry: false turns the retry off', () async {
      final FakeServer server = FakeServer()..reply('GET', '/api/parts', <String, dynamic>{'error': 'x'}, 503);
      final ApiClient api = makeClient(server);

      await expectLater(api.getJson('/api/parts', retry: false), throwsA(apiError(status: 503)));

      expect(server.requests, hasLength(1));
    });

    test('a POST is never repeated automatically', () async {
      final FakeServer server = FakeServer()..reply('POST', '/api/orders', <String, dynamic>{'error': 'x'}, 503);
      final ApiClient api = makeClient(server);

      await expectLater(
        api.postJson('/api/orders', <String, dynamic>{}),
        throwsA(apiError(status: 503)),
      );

      expect(server.requests, hasLength(1));
    });

    test('a multipart POST is never repeated automatically', () async {
      final FakeServer server = FakeServer()
        ..on('POST', '/api/orders', (http.Request _) => throw http.ClientException('connection reset'));
      final ApiClient api = makeClient(server);

      await expectLater(
        api.postMultipart('/api/orders', fields: <String, String>{'pay': 'cod'}),
        throwsA(apiError(network: true)),
      );

      expect(server.requests, hasLength(1));
    });
  });

  group('multipart uploads', () {
    test('sends text fields and files as multipart/form-data with the bearer token', () async {
      final FakeServer server = FakeServer()..reply('POST', '/api/orders', <String, dynamic>{'orderId': 'o1'});
      final ApiClient api = makeClient(server);
      final Uint8List receipt = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 13, 10, 13, 10, 4]);

      final Map<String, dynamic> data = await api.postMultipart(
        '/api/orders',
        fields: <String, String>{'items': '{"p1":2}', 'pay': 'sham', 'note': 'ملاحظة'},
        files: <UploadFile>[UploadFile(field: 'receipt', bytes: receipt, filename: 'receipt.jpg')],
        idempotencyKey: '22222222-2222-4222-8222-222222222222',
      );

      expect(data['orderId'], 'o1');
      final http.Request request = server.requests.single;
      expect(request.headers['content-type'], startsWith('multipart/form-data; boundary='));
      expect(request.headers['authorization'], 'Bearer tok');
      expect(request.headers['idempotency-key'], '22222222-2222-4222-8222-222222222222');

      final List<MultipartPart> parts = parseMultipart(request);
      expect(partNamed(parts, 'items').text, '{"p1":2}');
      expect(partNamed(parts, 'pay').text, 'sham');
      expect(partNamed(parts, 'note').text, 'ملاحظة');
      expect(partNamed(parts, 'items').filename, isNull);

      final MultipartPart file = partNamed(parts, 'receipt');
      expect(file.filename, 'receipt.jpg');
      expect(file.bytes, orderedEquals(receipt));
    });

    test('works with fields only', () async {
      final FakeServer server = FakeServer()..reply('POST', '/api/special-requests', <String, dynamic>{'ok': true});
      final ApiClient api = makeClient(server);

      await api.postMultipart('/api/special-requests', fields: <String, String>{'brand': 'BMW'});

      final List<MultipartPart> parts = parseMultipart(server.requests.single);
      expect(parts, hasLength(1));
      expect(partNamed(parts, 'brand').text, 'BMW');
    });
  });

  group('avatar', () {
    test('fetchAvatar returns the image bytes', () async {
      final FakeServer server = FakeServer()
        ..on(
          'GET',
          '/api/account/avatar',
          (http.Request _) => http.Response.bytes(
            <int>[1, 2, 3],
            200,
            headers: const <String, String>{'content-type': 'image/jpeg'},
          ),
        );
      final ApiClient api = makeClient(server);

      final Uint8List? bytes = await api.fetchAvatar();

      expect(bytes, orderedEquals(<int>[1, 2, 3]));
      final http.Request request = server.requests.single;
      expect(request.headers['authorization'], 'Bearer tok');
      expect(request.headers.containsKey('cookie'), isFalse);
    });

    test('fetchAvatar returns null when there is no photo', () async {
      final FakeServer notFound = FakeServer()
        ..reply('GET', '/api/account/avatar', <String, dynamic>{'error': 'none'}, 404);
      expect(await makeClient(notFound).fetchAvatar(), isNull);

      final FakeServer empty = FakeServer()
        ..on('GET', '/api/account/avatar', (http.Request _) => http.Response.bytes(<int>[], 200));
      expect(await makeClient(empty).fetchAvatar(), isNull);
    });

    test('fetchAvatar reports an expired session', () async {
      final FakeServer server = FakeServer()
        ..reply('GET', '/api/account/avatar', <String, dynamic>{'error': 'غير مصرح'}, 401);
      final ApiClient api = makeClient(server);
      int fired = 0;
      api.onUnauthorized = () => fired++;

      await expectLater(api.fetchAvatar(), throwsA(apiError(unauthorized: true)));

      expect(fired, 1);
    });

    test('fetchAvatar reports a server error', () async {
      final FakeServer server = FakeServer()
        ..reply('GET', '/api/account/avatar', <String, dynamic>{'error': 'boom'}, 500);

      await expectLater(makeClient(server).fetchAvatar(), throwsA(apiError(status: 500, message: 'boom')));
    });

    test('uploadAvatar sends the raw JPEG with its content type', () async {
      final FakeServer server = FakeServer()..reply('PUT', '/api/account/avatar', <String, dynamic>{'ok': true});
      final ApiClient api = makeClient(server);
      final Uint8List jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 9, 9]);

      await api.uploadAvatar(jpeg);

      final http.Request request = server.requests.single;
      expect(request.method, 'PUT');
      expect(request.headers['content-type'], 'image/jpeg');
      expect(request.headers['authorization'], 'Bearer tok');
      expect(request.bodyBytes, orderedEquals(jpeg));
    });
  });

  group('ApiException', () {
    test('prints its message', () {
      expect(const ApiException('مرحبا').toString(), 'مرحبا');
    });
  });
}
