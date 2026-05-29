import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secret_store.dart';

class FlutterSecureStorageSecretStore implements SecretStore {
  const FlutterSecureStorageSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<SecretStoreCapabilities> capabilities() async {
    return const SecretStoreCapabilities(
      available: true,
      deviceLocal: true,
      syncable: false,
      biometricGate: false,
    );
  }

  @override
  Future<void> write(SecretRef ref, List<int> value) async {
    await _storage.write(key: ref.value, value: base64Encode(value));
  }

  @override
  Future<List<int>?> read(SecretRef ref) async {
    final value = await _storage.read(key: ref.value);
    if (value == null) {
      return null;
    }
    return base64Decode(value);
  }

  @override
  Future<void> delete(SecretRef ref) async {
    await _storage.delete(key: ref.value);
  }
}

class InMemorySecretStore implements SecretStore {
  final Map<SecretRef, List<int>> _values = {};

  @override
  Future<SecretStoreCapabilities> capabilities() async {
    return const SecretStoreCapabilities(
      available: true,
      deviceLocal: true,
      syncable: false,
      biometricGate: false,
    );
  }

  @override
  Future<void> write(SecretRef ref, List<int> value) async {
    _values[ref] = List<int>.unmodifiable(value);
  }

  @override
  Future<List<int>?> read(SecretRef ref) async {
    final value = _values[ref];
    return value == null ? null : List<int>.unmodifiable(value);
  }

  @override
  Future<void> delete(SecretRef ref) async {
    _values.remove(ref);
  }
}
