// A scripted HTTP server for tests, built on package:http's MockClient. It records every request so a test can
// check exactly what the app sent (headers, JSON bodies, multipart forms).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A JSON response whose body is UTF-8 bytes. Like the real server it sends no charset in the content type, so a
/// client that decodes with package:http's default (Latin-1) would garble every Arabic message.
http.Response jsonResponse(Object? body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

typedef Route = FutureOr<http.Response> Function(http.Request request);

class FakeServer {
  final Map<String, Route> _routes = <String, Route>{};

  /// Every request received, in order.
  final List<http.Request> requests = <http.Request>[];

  late final MockClient client = MockClient(_handle);

  /// Answers `METHOD path` (the query string is ignored) with whatever [route] returns or throws.
  void on(String method, String path, Route route) {
    _routes['$method $path'] = route;
  }

  /// Answers `METHOD path` with a fixed JSON body.
  void reply(String method, String path, Object? body, [int status = 200]) {
    on(method, path, (http.Request _) => jsonResponse(body, status));
  }

  List<http.Request> requestsTo(String method, String path) {
    return requests
        .where((http.Request r) => r.method == method && r.url.path == path)
        .toList();
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final Route? route = _routes['${request.method} ${request.url.path}'];
    if (route == null) {
      return jsonResponse(<String, dynamic>{'error': 'no such route'}, 404);
    }
    return route(request);
  }
}

/// One field or file of a multipart/form-data body.
class MultipartPart {
  MultipartPart({required this.name, required this.bytes, this.filename});

  final String name;
  final String? filename;
  final Uint8List bytes;

  String get text => utf8.decode(bytes);
}

/// Splits the body of a multipart request into its parts.
List<MultipartPart> parseMultipart(http.Request request) {
  final String? type = request.headers['content-type'];
  if (type == null) {
    throw StateError('request has no content-type');
  }
  final RegExpMatch? boundaryMatch = RegExp(r'boundary=(.+)$').firstMatch(type);
  if (boundaryMatch == null) {
    throw StateError('content-type has no boundary: $type');
  }
  final String boundary = boundaryMatch.group(1)!;

  // latin1 maps every byte to one character, so binary content survives the round trip untouched.
  final String body = latin1.decode(request.bodyBytes);
  final List<MultipartPart> parts = <MultipartPart>[];
  for (final String chunk in body.split('--$boundary')) {
    if (chunk.trim().isEmpty || chunk.startsWith('--')) {
      continue; // the empty preamble and the closing "--"
    }
    final int headerEnd = chunk.indexOf('\r\n\r\n');
    final String headers = chunk.substring(0, headerEnd);
    String content = chunk.substring(headerEnd + 4);
    if (content.endsWith('\r\n')) {
      content = content.substring(0, content.length - 2);
    }
    final RegExpMatch? name = RegExp(r'[;\s]name="([^"]*)"').firstMatch(headers);
    final RegExpMatch? filename = RegExp(r'filename="([^"]*)"').firstMatch(headers);
    parts.add(
      MultipartPart(
        name: name == null ? '' : name.group(1)!,
        filename: filename?.group(1),
        bytes: Uint8List.fromList(latin1.encode(content)),
      ),
    );
  }
  return parts;
}

MultipartPart partNamed(List<MultipartPart> parts, String name) {
  return parts.firstWhere((MultipartPart p) => p.name == name);
}
