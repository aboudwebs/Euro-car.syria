// Local persistence. The session keeps the SAME keys as the first Flutter client ('token' and 'user'), so an
// installed session survives the update. Values are plain strings in Android secure storage.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String tokenKey = 'token';
const String userKey = 'user';
const String cartKey = 'cart';
const String themeKey = 'theme';
const String languageKey = 'language';
const String currencyKey = 'currency';

/// Minimal key-value store so the app state can be tested without a device.
abstract class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
