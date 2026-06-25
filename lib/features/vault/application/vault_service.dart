import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../../platform/secret_store.dart';
import '../../ssh/domain/connection_profile.dart';

enum VaultState { uninitialized, locked, unlocked }

class VaultException implements Exception {
  const VaultException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'VaultException($code): $message';
}

class VaultRecoveryKey {
  const VaultRecoveryKey(this.value);

  static const _prefix = 'SRLK-RK1-';

  final String value;

  factory VaultRecoveryKey.fromBytes(List<int> bytes) {
    return VaultRecoveryKey('$_prefix${_base64UrlNoPadding(bytes)}');
  }

  List<int> decodeBytes() {
    if (!value.startsWith(_prefix)) {
      throw const FormatException('Unsupported Serlink recovery key format.');
    }
    return _decodeBase64UrlNoPadding(value.substring(_prefix.length));
  }
}

class VaultKdfConfig {
  const VaultKdfConfig({
    required this.algorithm,
    required this.memoryKiB,
    required this.parallelism,
    required this.iterations,
    required this.hashLength,
  });

  const VaultKdfConfig.argon2idDesktop()
    : this(
        algorithm: 'argon2id',
        memoryKiB: 65536,
        parallelism: 2,
        iterations: 3,
        hashLength: 32,
      );

  const VaultKdfConfig.argon2idTesting()
    : this(
        algorithm: 'argon2id',
        memoryKiB: 64,
        parallelism: 1,
        iterations: 1,
        hashLength: 32,
      );

  final String algorithm;
  final int memoryKiB;
  final int parallelism;
  final int iterations;
  final int hashLength;

  Map<String, Object?> toJson() {
    return {
      'algorithm': algorithm,
      'memoryKiB': memoryKiB,
      'parallelism': parallelism,
      'iterations': iterations,
      'hashLength': hashLength,
    };
  }

  factory VaultKdfConfig.fromJson(Map<String, Object?> json) {
    return VaultKdfConfig(
      algorithm: json['algorithm'] as String,
      memoryKiB: json['memoryKiB'] as int,
      parallelism: json['parallelism'] as int,
      iterations: json['iterations'] as int,
      hashLength: json['hashLength'] as int,
    );
  }
}

class VaultCryptoConfig {
  const VaultCryptoConfig({
    this.kdf = const VaultKdfConfig.argon2idDesktop(),
    this.saltLength = 32,
    this.rootKeyLength = 32,
    this.recoveryKeyLength = 32,
  });

  const VaultCryptoConfig.testing()
    : this(kdf: const VaultKdfConfig.argon2idTesting());

  final VaultKdfConfig kdf;
  final int saltLength;
  final int rootKeyLength;
  final int recoveryKeyLength;
}

class VaultHeader {
  const VaultHeader({
    required this.schemaVersion,
    required this.kdf,
    required this.passphraseSalt,
    required this.passphraseNonce,
    required this.passphraseMac,
    required this.passphraseCiphertext,
    required this.recoveryNonce,
    required this.recoveryMac,
    required this.recoveryCiphertext,
    required this.createdAt,
    this.localUnlockProtectors = const [],
  });

  final int schemaVersion;
  final VaultKdfConfig kdf;
  final List<int> passphraseSalt;
  final List<int> passphraseNonce;
  final List<int> passphraseMac;
  final List<int> passphraseCiphertext;
  final List<int> recoveryNonce;
  final List<int> recoveryMac;
  final List<int> recoveryCiphertext;
  final DateTime createdAt;
  final List<VaultLocalUnlockProtector> localUnlockProtectors;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'kdf': kdf.toJson(),
      'passphraseSalt': base64Encode(passphraseSalt),
      'passphraseNonce': base64Encode(passphraseNonce),
      'passphraseMac': base64Encode(passphraseMac),
      'passphraseCiphertext': base64Encode(passphraseCiphertext),
      'recoveryNonce': base64Encode(recoveryNonce),
      'recoveryMac': base64Encode(recoveryMac),
      'recoveryCiphertext': base64Encode(recoveryCiphertext),
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (localUnlockProtectors.isNotEmpty)
        'localUnlockProtectors': [
          for (final protector in localUnlockProtectors) protector.toJson(),
        ],
    };
  }

  factory VaultHeader.fromJson(Map<String, Object?> json) {
    return VaultHeader(
      schemaVersion: json['schemaVersion'] as int,
      kdf: VaultKdfConfig.fromJson(json['kdf'] as Map<String, Object?>),
      passphraseSalt: base64Decode(json['passphraseSalt'] as String),
      passphraseNonce: base64Decode(json['passphraseNonce'] as String),
      passphraseMac: base64Decode(json['passphraseMac'] as String),
      passphraseCiphertext: base64Decode(
        json['passphraseCiphertext'] as String,
      ),
      recoveryNonce: base64Decode(json['recoveryNonce'] as String),
      recoveryMac: base64Decode(json['recoveryMac'] as String),
      recoveryCiphertext: base64Decode(json['recoveryCiphertext'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      localUnlockProtectors: [
        for (final rawProtector
            in (json['localUnlockProtectors'] as List<Object?>? ??
                const <Object?>[]))
          VaultLocalUnlockProtector.fromJson(
            rawProtector as Map<String, Object?>,
          ),
      ],
    );
  }

  VaultHeader copyWith({
    int? schemaVersion,
    VaultKdfConfig? kdf,
    List<int>? passphraseSalt,
    List<int>? passphraseNonce,
    List<int>? passphraseMac,
    List<int>? passphraseCiphertext,
    List<int>? recoveryNonce,
    List<int>? recoveryMac,
    List<int>? recoveryCiphertext,
    DateTime? createdAt,
    List<VaultLocalUnlockProtector>? localUnlockProtectors,
  }) {
    return VaultHeader(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      kdf: kdf ?? this.kdf,
      passphraseSalt: passphraseSalt ?? this.passphraseSalt,
      passphraseNonce: passphraseNonce ?? this.passphraseNonce,
      passphraseMac: passphraseMac ?? this.passphraseMac,
      passphraseCiphertext: passphraseCiphertext ?? this.passphraseCiphertext,
      recoveryNonce: recoveryNonce ?? this.recoveryNonce,
      recoveryMac: recoveryMac ?? this.recoveryMac,
      recoveryCiphertext: recoveryCiphertext ?? this.recoveryCiphertext,
      createdAt: createdAt ?? this.createdAt,
      localUnlockProtectors:
          localUnlockProtectors ?? this.localUnlockProtectors,
    );
  }
}

class VaultLocalUnlockProtector {
  const VaultLocalUnlockProtector({
    required this.id,
    required this.secretRef,
    required this.nonce,
    required this.mac,
    required this.ciphertext,
    required this.createdAt,
    required this.protection,
  });

  final String id;
  final SecretRef secretRef;
  final List<int> nonce;
  final List<int> mac;
  final List<int> ciphertext;
  final DateTime createdAt;
  final VaultLocalUnlockProtection protection;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'secretRef': secretRef.value,
      'nonce': base64Encode(nonce),
      'mac': base64Encode(mac),
      'ciphertext': base64Encode(ciphertext),
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (protection == VaultLocalUnlockProtection.biometricCurrentSet)
        'protection': protection.name,
    };
  }

  factory VaultLocalUnlockProtector.fromJson(Map<String, Object?> json) {
    return VaultLocalUnlockProtector(
      id: json['id'] as String,
      secretRef: SecretRef(json['secretRef'] as String),
      nonce: base64Decode(json['nonce'] as String),
      mac: base64Decode(json['mac'] as String),
      ciphertext: base64Decode(json['ciphertext'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      protection: _localUnlockProtectionFromJson(json['protection']),
    );
  }
}

enum VaultLocalUnlockProtection { biometricCurrentSet, unsupported }

VaultLocalUnlockProtection _localUnlockProtectionFromJson(Object? value) {
  return switch (value) {
    'biometricCurrentSet' => VaultLocalUnlockProtection.biometricCurrentSet,
    _ => VaultLocalUnlockProtection.unsupported,
  };
}

class VaultInitializationResult {
  const VaultInitializationResult({
    required this.header,
    required this.recoveryKey,
  });

  final VaultHeader header;
  final VaultRecoveryKey recoveryKey;
}

class VaultRecordEnvelope {
  const VaultRecordEnvelope({
    required this.id,
    required this.type,
    required this.schemaVersion,
    required this.revision,
    required this.nonce,
    required this.mac,
    required this.associatedData,
    required this.ciphertext,
  });

  final VaultRecordId id;
  final String type;
  final int schemaVersion;
  final String revision;
  final List<int> nonce;
  final List<int> mac;
  final List<int> associatedData;
  final List<int> ciphertext;

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'type': type,
      'schemaVersion': schemaVersion,
      'revision': revision,
      'nonce': base64Encode(nonce),
      'mac': base64Encode(mac),
      'associatedData': base64Encode(associatedData),
      'ciphertext': base64Encode(ciphertext),
    };
  }

  factory VaultRecordEnvelope.fromJson(Map<String, Object?> json) {
    return VaultRecordEnvelope(
      id: VaultRecordId(json['id'] as String),
      type: json['type'] as String,
      schemaVersion: json['schemaVersion'] as int,
      revision: json['revision'] as String,
      nonce: base64Decode(json['nonce'] as String),
      mac: base64Decode(json['mac'] as String),
      associatedData: base64Decode(json['associatedData'] as String),
      ciphertext: base64Decode(json['ciphertext'] as String),
    );
  }
}

abstract interface class VaultService {
  VaultState get state;
  VaultHeader? get header;

  Stream<VaultState> watchState();
  Future<VaultInitializationResult> initialize({required String passphrase});
  Future<void> unlock({required String passphrase});
  Future<void> unlockWithRecoveryKey(VaultRecoveryKey recoveryKey);
  Future<void> unlockWithLocalKey({required SecretStore secrets});
  Future<void> lock();
  Future<bool> hasLocalUnlock({required SecretStore secrets});
  Future<VaultHeader> enableLocalUnlock({required SecretStore secrets});
  Future<VaultHeader> disableLocalUnlock({required SecretStore secrets});
  Future<VaultRecordEnvelope> encryptRecord({
    required VaultRecordId id,
    required String type,
    required List<int> plaintext,
    int schemaVersion,
    String? revision,
  });
  Future<List<int>> decryptRecord(VaultRecordEnvelope envelope);
  Future<ConnectionProfileSnapshot> resolveConnectionProfile(HostId hostId);
}

String _base64UrlNoPadding(List<int> bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}

List<int> _decodeBase64UrlNoPadding(String value) {
  final paddingLength = (4 - value.length % 4) % 4;
  return base64Url.decode('$value${'=' * paddingLength}');
}
