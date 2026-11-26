// An in-memory SessionStore for tests, with switches that simulate a keystore that refuses to work
// (which happens on real devices, for example after a backup restore).

import 'package:euro_cars/core/session_store.dart';

class MemoryStore implements SessionStore {
  MemoryStore([Map<String, String>? initial]) : data = <String, String>{...?initial};

  /// What is currently stored.
  final Map<String, String> data;

  /// When true, every read throws.
  bool failReads = false;

  /// When true, every write and delete throws.
  bool failWrites = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) {
      throw StateError('keystore unavailable');
    }
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw StateError('keystore unavailable');
    }
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failWrites) {
      throw StateError('keystore unavailable');
    }
    data.remove(key);
  }
}
