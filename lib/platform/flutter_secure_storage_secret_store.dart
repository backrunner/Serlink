import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secret_store.dart';

const IOSOptions _deviceLocalIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
  synchronizable: false,
);

const MacOsOptions _deviceLocalMacOsOptions = MacOsOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
  synchronizable: false,
  usesDataProtectionKeychain: true,
);

const IOSOptions _legacyIOSOptions = IOSOptions();
const MacOsOptions _legacyMacOsOptions = MacOsOptions();

class FlutterSecureStorageSecretStore implements SecretStore {
  const FlutterSecureStorageSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<SecretStoreCapabilities> capabilities() async {
    final nativeSecureStorage = !kIsWeb;
    return SecretStoreCapabilities(
      available: nativeSecureStorage,
      deviceLocal: nativeSecureStorage,
      syncable: false,
      biometricGate: false,
    );
  }

  @override
  Future<void> write(SecretRef ref, List<int> value) async {
    await _storage.write(
      key: ref.value,
      value: base64Encode(value),
      iOptions: _deviceLocalIOSOptions,
      mOptions: _deviceLocalMacOsOptions,
    );
  }

  @override
  Future<List<int>?> read(SecretRef ref) async {
    final value =
        await _storage.read(
          key: ref.value,
          iOptions: _deviceLocalIOSOptions,
          mOptions: _deviceLocalMacOsOptions,
        ) ??
        await _storage.read(
          key: ref.value,
          iOptions: _legacyIOSOptions,
          mOptions: _legacyMacOsOptions,
        );
    if (value == null) {
      return null;
    }
    return base64Decode(value);
  }

  @override
  Future<void> delete(SecretRef ref) async {
    await _storage.delete(
      key: ref.value,
      iOptions: _deviceLocalIOSOptions,
      mOptions: _deviceLocalMacOsOptions,
    );
    await _storage.delete(
      key: ref.value,
      iOptions: _legacyIOSOptions,
      mOptions: _legacyMacOsOptions,
    );
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
