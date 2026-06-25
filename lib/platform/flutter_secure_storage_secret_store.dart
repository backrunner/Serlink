import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

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

const IOSOptions _biometricIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.unlocked_this_device,
  synchronizable: false,
  accessControlFlags: [AccessControlFlag.biometryCurrentSet],
);

const MacOsOptions _biometricMacOsOptions = MacOsOptions(
  accessibility: KeychainAccessibility.unlocked_this_device,
  synchronizable: false,
  accessControlFlags: [AccessControlFlag.biometryCurrentSet],
  usesDataProtectionKeychain: true,
);

const IOSOptions _lookupIOSOptions = IOSOptions(
  accessibility: null,
  synchronizable: false,
);

const MacOsOptions _lookupMacOsOptions = MacOsOptions(
  accessibility: null,
  synchronizable: false,
  usesDataProtectionKeychain: true,
);

class FlutterSecureStorageSecretStore implements SecretStore {
  FlutterSecureStorageSecretStore({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  @override
  Future<SecretStoreCapabilities> capabilities() async {
    final nativeSecureStorage = !kIsWeb;
    final biometricGate = nativeSecureStorage && await _hasBiometricGate();
    return SecretStoreCapabilities(
      available: nativeSecureStorage,
      deviceLocal: nativeSecureStorage,
      syncable: false,
      biometricGate: biometricGate,
    );
  }

  @override
  Future<void> write(
    SecretRef ref,
    List<int> value, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    final options = _optionsFor(protection);
    await _storage.write(
      key: ref.value,
      value: base64Encode(value),
      iOptions: options.ios,
      mOptions: options.macOs,
    );
  }

  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    final options = _optionsFor(protection);
    var value = await _storage.read(
      key: ref.value,
      iOptions: options.ios,
      mOptions: options.macOs,
    );
    if (value == null && protection == SecretProtection.deviceLocal) {
      value = await _storage.read(
        key: ref.value,
        iOptions: _legacyIOSOptions,
        mOptions: _legacyMacOsOptions,
      );
    }
    if (value == null) {
      return null;
    }
    return base64Decode(value);
  }

  @override
  Future<bool> contains(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    final exists = await _storage.containsKey(
      key: ref.value,
      iOptions: _lookupIOSOptions,
      mOptions: _lookupMacOsOptions,
    );
    if (exists || protection != SecretProtection.deviceLocal) {
      return exists;
    }
    return _storage.containsKey(
      key: ref.value,
      iOptions: _legacyIOSOptions,
      mOptions: _legacyMacOsOptions,
    );
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

  Future<bool> _hasBiometricGate() async {
    if (!_appleBiometricPlatform) {
      return false;
    }
    try {
      if (!await _localAuth.canCheckBiometrics) {
        return false;
      }
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

class InMemorySecretStore implements SecretStore {
  InMemorySecretStore({
    this._capabilities = const SecretStoreCapabilities(
      available: true,
      deviceLocal: true,
      syncable: false,
      biometricGate: true,
    ),
  });

  final SecretStoreCapabilities _capabilities;
  final Map<SecretRef, List<int>> _values = {};

  @override
  Future<SecretStoreCapabilities> capabilities() async {
    return _capabilities;
  }

  @override
  Future<void> write(
    SecretRef ref,
    List<int> value, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    _values[ref] = List<int>.unmodifiable(value);
  }

  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    final value = _values[ref];
    return value == null ? null : List<int>.unmodifiable(value);
  }

  @override
  Future<bool> contains(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    return _values.containsKey(ref);
  }

  @override
  Future<void> delete(SecretRef ref) async {
    _values.remove(ref);
  }
}

({IOSOptions ios, MacOsOptions macOs}) _optionsFor(
  SecretProtection protection,
) {
  return switch (protection) {
    SecretProtection.deviceLocal => (
      ios: _deviceLocalIOSOptions,
      macOs: _deviceLocalMacOsOptions,
    ),
    SecretProtection.biometricCurrentSet => (
      ios: _biometricIOSOptions,
      macOs: _biometricMacOsOptions,
    ),
  };
}

bool get _appleBiometricPlatform {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
}
