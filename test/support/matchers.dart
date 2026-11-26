// Custom matchers shared by the tests.

import 'package:euro_cars/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matches an [ApiException] and, for every argument that is given, the field it describes.
Matcher apiError({int? status, bool? unauthorized, bool? network, bool? pending, String? message}) {
  TypeMatcher<ApiException> matcher = isA<ApiException>();
  if (status != null) {
    matcher = matcher.having((ApiException e) => e.statusCode, 'statusCode', status);
  }
  if (unauthorized != null) {
    matcher = matcher.having((ApiException e) => e.unauthorized, 'unauthorized', unauthorized);
  }
  if (network != null) {
    matcher = matcher.having((ApiException e) => e.network, 'network', network);
  }
  if (pending != null) {
    matcher = matcher.having((ApiException e) => e.pendingApproval, 'pendingApproval', pending);
  }
  if (message != null) {
    matcher = matcher.having((ApiException e) => e.message, 'message', message);
  }
  return matcher;
}
