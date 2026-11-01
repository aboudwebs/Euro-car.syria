// HTTP client for the EURO CARS API.
//
// Notes on compatibility with the existing Next.js backend (which is not modified):
// * Responses are decoded as UTF-8 explicitly. package:http falls back to Latin-1 when the server sends no
//   charset, which would garble every Arabic message.
// * GET and PUT /api/auth only read the session from the euro_session cookie, so those two calls also send the
//   same signed token as a Cookie header. Everything else uses "Authorization: Bearer".
// * A 401 on an authenticated call means the 30-day token expired or is invalid: onUnauthorized fires once per
//   response so the app can return to the sign-in screen.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'config.dart';

const String networkErrorMessage = 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.';
const String timeoutMessage =
    'انتهت مهلة الاتصال بالخادم. قد يكون الخادم في وضع السكون، حاول مجدداً بعد لحظات.';
const String unexpectedMessage = 'حدث خطأ غير متوقع، حاول مجدداً.';
const String badResponseMessage = 'استجابة غير متوقعة من الخادم، حاول مجدداً.';

/// An error whose message is safe to show to the user (always Arabic).
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.unauthorized = false,
    this.pendingApproval = false,
    this.network = false,
    this.timedOut = false,
  });

  final String message;
  final int? statusCode;

  /// The session is no longer valid (401 on an authenticated call).
  final bool unauthorized;

  /// The account exists but an admin has not approved it yet.
  final bool pendingApproval;

  /// The server could not be reached at all.
  final bool network;
  final bool timedOut;

  @override
  String toString() => message;
}

/// A file sent as part of a multipart form.
class UploadFile {
  const UploadFile({required this.field, required this.bytes, required this.filename});

  final String field;
  final Uint8List bytes;
  final String filename;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.retryDelay = const Duration(seconds: 2),
  })  : baseUrl = _withoutTrailingSlash(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  final Duration retryDelay;
  final http.Client _client;

  /// Signed session token of the signed-in user, sent as a Bearer token.
  String? token;

  /// Called when an authenticated request is answered with 401.
  void Function()? onUnauthorized;

  static String _withoutTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({bool auth = true, String? contentType, bool cookie = false}) {
    final Map<String, String> headers = <String, String>{'Accept': 'application/json'};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    final String? current = token;
    if (auth && current != null && current.isNotEmpty) {
      headers['Authorization'] = 'Bearer $current';
      if (cookie) {
        headers['Cookie'] = 'euro_session=$current';
      }
    }
    return headers;
  }

  static const String _jsonType = 'application/json; charset=utf-8';

  Future<Map<String, dynamic>> getJson(String path, {bool auth = true, bool retry = true}) {
    return _request(
      () => _client.get(_uri(path), headers: _headers(auth: auth)),
      auth: auth,
      timeout: requestTimeout,
      retry: retry,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
    String? idempotencyKey,
  }) {
    return _request(
      () => _client.post(
        _uri(path),
        headers: <String, String>{
          ..._headers(auth: auth, contentType: _jsonType),
          if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'idempotency-key': idempotencyKey,
        },
        body: utf8.encode(jsonEncode(body)),
      ),
      auth: auth,
      timeout: requestTimeout,
      retry: false,
    );
  }

  /// PUT with a JSON body (saved addresses and vehicles).
  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) {
    return _request(
      () => _client.put(
        _uri(path),
        headers: _headers(contentType: _jsonType),
        body: utf8.encode(jsonEncode(body)),
      ),
      auth: true,
      timeout: requestTimeout,
      retry: false,
    );
  }

  /// DELETE (saved addresses and vehicles, cancelling an account deletion).
  Future<Map<String, dynamic>> deleteJson(String path) {
    return _request(
      () => _client.delete(_uri(path), headers: _headers()),
      auth: true,
      timeout: requestTimeout,
      retry: false,
    );
  }

  /// GET /api/auth: the current account (always HTTP 200, with user null when the session is not accepted).
  Future<Map<String, dynamic>> getProfile() {
    return _request(
      () => _client.get(_uri('/api/auth'), headers: _headers(cookie: true)),
      auth: true,
      timeout: requestTimeout,
      retry: false,
    );
  }

  /// PUT /api/auth: update name, governorate or password.
  Future<Map<String, dynamic>> putProfile(Map<String, dynamic> body) {
    return _request(
      () => _client.put(
        _uri('/api/auth'),
        headers: _headers(contentType: _jsonType, cookie: true),
        body: utf8.encode(jsonEncode(body)),
      ),
      auth: true,
      timeout: requestTimeout,
      retry: false,
    );
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<UploadFile> files = const <UploadFile>[],
    String? idempotencyKey,
  }) {
    return _request(
      () async {
        final http.MultipartRequest request = http.MultipartRequest('POST', _uri(path));
        request.headers.addAll(_headers());
        if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
          request.headers['idempotency-key'] = idempotencyKey;
        }
        request.fields.addAll(fields);
        for (final UploadFile file in files) {
          request.files.add(
            http.MultipartFile.fromBytes(file.field, file.bytes, filename: file.filename),
          );
        }
        final http.StreamedResponse streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      },
      auth: true,
      timeout: uploadTimeout,
      retry: false,
    );
  }

  /// The signed-in user's avatar bytes, or null when none was uploaded.
  Future<Uint8List?> fetchAvatar() async {
    final http.Response response = await _perform(
      () => _client.get(_uri('/api/account/avatar'), headers: _headers()),
      requestTimeout,
    );
    final int status = response.statusCode;
    if (status == 404) {
      return null;
    }
    if (status >= 200 && status < 300) {
      return response.bodyBytes.isEmpty ? null : response.bodyBytes;
    }
    _decode(response, auth: true);
    return null;
  }

  /// Uploads a JPEG avatar (the server only accepts image/jpeg up to 1.5 MB).
  Future<void> uploadAvatar(Uint8List jpegBytes) async {
    await _request(
      () => _client.put(
        _uri('/api/account/avatar'),
        headers: _headers(contentType: 'image/jpeg'),
        body: jpegBytes,
      ),
      auth: true,
      timeout: uploadTimeout,
      retry: false,
    );
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    required bool auth,
    required Duration timeout,
    required bool retry,
  }) async {
    try {
      final http.Response response = await _perform(send, timeout);
      return _decode(response, auth: auth);
    } on ApiException catch (error) {
      if (retry && _isTransient(error)) {
        // The hosted API may still be waking up: one more attempt is enough for a read.
        await Future<void>.delayed(retryDelay);
        final http.Response again = await _perform(send, timeout);
        return _decode(again, auth: auth);
      }
      rethrow;
    }
  }

  bool _isTransient(ApiException error) {
    if (error.timedOut) {
      return false;
    }
    final int? status = error.statusCode;
    return error.network || status == 502 || status == 503 || status == 504;
  }

  Future<http.Response> _perform(
    Future<http.Response> Function() send,
    Duration timeout,
  ) async {
    try {
      return await send().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(timeoutMessage, network: true, timedOut: true);
    } on Exception {
      throw const ApiException(networkErrorMessage, network: true);
    }
  }

  Map<String, dynamic> _decode(http.Response response, {required bool auth}) {
    final int status = response.statusCode;
    final Map<String, dynamic>? body = _parseBody(response);
    if (status >= 200 && status < 300) {
      if (body == null) {
        throw ApiException(badResponseMessage, statusCode: status);
      }
      return body;
    }

    final bool unauthorized = auth && status == 401;
    String message = '';
    final Object? error = body == null ? null : body['error'];
    if (error is String && error.trim().isNotEmpty) {
      message = error.trim();
    }
    if (message.isEmpty) {
      message = _fallbackMessage(status);
    }
    if (unauthorized) {
      onUnauthorized?.call();
    }
    throw ApiException(
      message,
      statusCode: status,
      unauthorized: unauthorized,
      pendingApproval: body != null && body['pendingApproval'] == true,
    );
  }

  Map<String, dynamic>? _parseBody(http.Response response) {
    final String text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  String _fallbackMessage(int status) {
    if (status == 502 || status == 503 || status == 504) {
      return 'الخادم غير متاح حالياً أو قيد التشغيل، حاول مجدداً بعد لحظات.';
    }
    if (status == 401) {
      return 'انتهت الجلسة، سجّل الدخول مجدداً.';
    }
    if (status == 403) {
      return 'غير مصرح بهذه العملية.';
    }
    if (status == 404) {
      return 'الخدمة المطلوبة غير موجودة على الخادم.';
    }
    if (status == 413) {
      return 'حجم الملف كبير جداً.';
    }
    if (status == 429) {
      return 'محاولات كثيرة، حاول مجدداً بعد قليل.';
    }
    if (status >= 500) {
      return 'حدث خطأ في الخادم، حاول مجدداً لاحقاً.';
    }
    return 'تعذر إتمام العملية (رمز $status).';
  }
}
