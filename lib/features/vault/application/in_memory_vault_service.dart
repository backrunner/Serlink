import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../../core/ids/entity_id.dart';
import '../../../platform/secret_store.dart';
import '../../ssh/domain/connection_profile.dart';
import 'vault_service.dart';

class InMemoryVaultService implements VaultService {
  InMemoryVaultService({
    this.config = const VaultCryptoConfig(),
    VaultHeader? header,
  }) : _state = header == null ? VaultState.uninitialized : VaultState.locked,
       _header = header;

  final VaultCryptoConfig config;
  final Cipher _cipher = Xchacha20.poly1305Aead();
  final StreamController<VaultState> _stateController =
      StreamController<VaultState>.broadcast();

  VaultState _state;
  VaultHeader? _header;
  SecretKey? _rootKey;

  @override
  VaultState get state => _state;

  @override
  VaultHeader? get header => _header;

  @override
  Stream<VaultState> watchState() async* {
    yield _state;
    yield* _stateController.stream;
  }

  @override
  Future<VaultInitializationResult> initialize({
    required String passphrase,
  }) async {
    if (_header != null) {
      throw const VaultException(
        'vault.already_initialized',
        'Vault has already been initialized.',
      );
    }
    _validatePassphrase(passphrase);

    final rootKeyBytes = _randomBytes(config.rootKeyLength);
    final passphraseSalt = _randomBytes(config.saltLength);
    final passphraseKey = await _derivePassphraseKey(
      passphrase: passphrase,
      salt: passphraseSalt,
      kdf: config.kdf,
    );
    final passphraseBox = await _cipher.encrypt(
      rootKeyBytes,
      secretKey: passphraseKey,
      nonce: _cipher.newNonce(),
      aad: _passphraseRootKeyAad,
    );

    final recoveryKeyBytes = _randomBytes(config.recoveryKeyLength);
    final recoveryKey = SecretKey(recoveryKeyBytes);
    final recoveryBox = await _cipher.encrypt(
      rootKeyBytes,
      secretKey: recoveryKey,
      nonce: _cipher.newNonce(),
      aad: _recoveryRootKeyAad,
    );

    passphraseKey.destroy();
    recoveryKey.destroy();

    _header = VaultHeader(
      schemaVersion: 1,
      kdf: config.kdf,
      passphraseSalt: List<int>.unmodifiable(passphraseSalt),
      passphraseNonce: List<int>.unmodifiable(passphraseBox.nonce),
      passphraseMac: List<int>.unmodifiable(passphraseBox.mac.bytes),
      passphraseCiphertext: List<int>.unmodifiable(passphraseBox.cipherText),
      recoveryNonce: List<int>.unmodifiable(recoveryBox.nonce),
      recoveryMac: List<int>.unmodifiable(recoveryBox.mac.bytes),
      recoveryCiphertext: List<int>.unmodifiable(recoveryBox.cipherText),
      createdAt: DateTime.now().toUtc(),
    );
    _replaceRootKey(rootKeyBytes);
    _setState(VaultState.unlocked);

    return VaultInitializationResult(
      header: _header!,
      recoveryKey: VaultRecoveryKey.fromBytes(recoveryKeyBytes),
    );
  }

  @override
  Future<void> unlock({required String passphrase}) async {
    _validatePassphrase(passphrase);
    final header = _requireHeader();
    final passphraseKey = await _derivePassphraseKey(
      passphrase: passphrase,
      salt: header.passphraseSalt,
      kdf: header.kdf,
    );
    try {
      final rootKeyBytes = await _cipher.decrypt(
        SecretBox(
          header.passphraseCiphertext,
          nonce: header.passphraseNonce,
          mac: Mac(header.passphraseMac),
        ),
        secretKey: passphraseKey,
        aad: _passphraseRootKeyAad,
      );
      _replaceRootKey(rootKeyBytes);
      _setState(VaultState.unlocked);
    } on SecretBoxAuthenticationError {
      throw const VaultException(
        'vault.invalid_passphrase',
        'Passphrase did not unlock the vault.',
      );
    } finally {
      passphraseKey.destroy();
    }
  }

  @override
  Future<void> unlockWithRecoveryKey(VaultRecoveryKey recoveryKey) async {
    final header = _requireHeader();
    final secretKey = SecretKey(recoveryKey.decodeBytes());
    try {
      final rootKeyBytes = await _cipher.decrypt(
        SecretBox(
          header.recoveryCiphertext,
          nonce: header.recoveryNonce,
          mac: Mac(header.recoveryMac),
        ),
        secretKey: secretKey,
        aad: _recoveryRootKeyAad,
      );
      _replaceRootKey(rootKeyBytes);
      _setState(VaultState.unlocked);
    } on SecretBoxAuthenticationError {
      throw const VaultException(
        'vault.invalid_recovery_key',
        'Recovery key did not unlock the vault.',
      );
    } on FormatException {
      throw const VaultException(
        'vault.invalid_recovery_key_format',
        'Recovery key format is not supported.',
      );
    } finally {
      secretKey.destroy();
    }
  }

  @override
  Future<void> unlockWithLocalKey({required SecretStore secrets}) async {
    final header = _requireHeader();
    if (header.localUnlockProtectors.isEmpty) {
      throw const VaultException(
        'vault.local_unlock_not_enabled',
        'Local vault unlock is not enabled on this device.',
      );
    }
    for (final protector in header.localUnlockProtectors) {
      final secretBytes = await secrets.read(protector.secretRef);
      if (secretBytes == null) {
        continue;
      }
      final secretKey = SecretKey(secretBytes);
      try {
        final rootKeyBytes = await _cipher.decrypt(
          SecretBox(
            protector.ciphertext,
            nonce: protector.nonce,
            mac: Mac(protector.mac),
          ),
          secretKey: secretKey,
          aad: _localUnlockRootKeyAad,
        );
        _replaceRootKey(rootKeyBytes);
        _setState(VaultState.unlocked);
        return;
      } on SecretBoxAuthenticationError {
        continue;
      } finally {
        secretKey.destroy();
      }
    }
    throw const VaultException(
      'vault.local_unlock_failed',
      'Local vault unlock failed. Use the vault passphrase.',
    );
  }

  @override
  Future<void> lock() async {
    _rootKey?.destroy();
    _rootKey = null;
    _setState(_header == null ? VaultState.uninitialized : VaultState.locked);
  }

  @override
  Future<bool> hasLocalUnlock({required SecretStore secrets}) async {
    final header = _header;
    if (header == null || header.localUnlockProtectors.isEmpty) {
      return false;
    }
    final capabilities = await secrets.capabilities();
    if (!capabilities.available) {
      return false;
    }
    for (final protector in header.localUnlockProtectors) {
      if (await secrets.read(protector.secretRef) != null) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<VaultHeader> enableLocalUnlock({required SecretStore secrets}) async {
    final rootKey = _requireRootKey();
    final capabilities = await secrets.capabilities();
    if (!capabilities.available || !capabilities.deviceLocal) {
      throw const VaultException(
        'vault.local_unlock_unavailable',
        'Local secure storage is not available on this device.',
      );
    }
    final header = _requireHeader();
    for (final protector in header.localUnlockProtectors) {
      if (await secrets.read(protector.secretRef) != null) {
        return header;
      }
    }

    final deviceSecretBytes = _randomBytes(config.rootKeyLength);
    final secretRef = SecretRef(
      'vault/local-unlock/${_base64UrlNoPadding(_randomBytes(16))}',
    );
    final deviceSecret = SecretKey(deviceSecretBytes);
    try {
      final rootKeyBytes = await rootKey.extractBytes();
      final box = await _cipher.encrypt(
        rootKeyBytes,
        secretKey: deviceSecret,
        nonce: _cipher.newNonce(),
        aad: _localUnlockRootKeyAad,
      );
      await secrets.write(secretRef, deviceSecretBytes);
      final nextHeader = header.copyWith(
        localUnlockProtectors: [
          ...header.localUnlockProtectors,
          VaultLocalUnlockProtector(
            id: _base64UrlNoPadding(_randomBytes(16)),
            secretRef: secretRef,
            nonce: List<int>.unmodifiable(box.nonce),
            mac: List<int>.unmodifiable(box.mac.bytes),
            ciphertext: List<int>.unmodifiable(box.cipherText),
            createdAt: DateTime.now().toUtc(),
          ),
        ],
      );
      _header = nextHeader;
      return nextHeader;
    } finally {
      deviceSecret.destroy();
    }
  }

  @override
  Future<VaultHeader> disableLocalUnlock({required SecretStore secrets}) async {
    final header = _requireHeader();
    for (final protector in header.localUnlockProtectors) {
      await secrets.delete(protector.secretRef);
    }
    final nextHeader = header.copyWith(localUnlockProtectors: const []);
    _header = nextHeader;
    return nextHeader;
  }

  @override
  Future<VaultRecordEnvelope> encryptRecord({
    required VaultRecordId id,
    required String type,
    required List<int> plaintext,
    int schemaVersion = 1,
    String? revision,
  }) async {
    final rootKey = _requireRootKey();
    final currentRevision = revision ?? _newRevision();
    final associatedData = _recordAssociatedData(
      id: id,
      type: type,
      schemaVersion: schemaVersion,
      revision: currentRevision,
    );
    final recordKey = await _deriveRecordKey(rootKey);
    try {
      final box = await _cipher.encrypt(
        plaintext,
        secretKey: recordKey,
        nonce: _cipher.newNonce(),
        aad: associatedData,
      );
      return VaultRecordEnvelope(
        id: id,
        type: type,
        schemaVersion: schemaVersion,
        revision: currentRevision,
        nonce: List<int>.unmodifiable(box.nonce),
        mac: List<int>.unmodifiable(box.mac.bytes),
        associatedData: List<int>.unmodifiable(associatedData),
        ciphertext: List<int>.unmodifiable(box.cipherText),
      );
    } finally {
      recordKey.destroy();
    }
  }

  @override
  Future<List<int>> decryptRecord(VaultRecordEnvelope envelope) async {
    final rootKey = _requireRootKey();
    final expectedAad = _recordAssociatedData(
      id: envelope.id,
      type: envelope.type,
      schemaVersion: envelope.schemaVersion,
      revision: envelope.revision,
    );
    if (!_constantTimeEquals(expectedAad, envelope.associatedData)) {
      throw const VaultException(
        'vault.record_metadata_tampered',
        'Vault record metadata does not match its authenticated data.',
      );
    }
    final recordKey = await _deriveRecordKey(rootKey);
    try {
      return await _cipher.decrypt(
        SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: Mac(envelope.mac),
        ),
        secretKey: recordKey,
        aad: envelope.associatedData,
      );
    } on SecretBoxAuthenticationError {
      throw const VaultException(
        'vault.record_authentication_failed',
        'Vault record authentication failed.',
      );
    } finally {
      recordKey.destroy();
    }
  }

  @override
  Future<ConnectionProfileSnapshot> resolveConnectionProfile(
    HostId hostId,
  ) async {
    _requireRootKey();
    throw const VaultException(
      'vault.profile_resolution_unimplemented',
      'Connection profile resolution requires the host repository layer.',
    );
  }

  VaultHeader _requireHeader() {
    final header = _header;
    if (header == null) {
      throw const VaultException(
        'vault.not_initialized',
        'Vault has not been initialized.',
      );
    }
    return header;
  }

  SecretKey _requireRootKey() {
    final rootKey = _rootKey;
    if (rootKey == null || _state != VaultState.unlocked) {
      throw const VaultException(
        'vault.locked',
        'Vault is locked and cannot decrypt secrets.',
      );
    }
    return rootKey;
  }

  Future<SecretKey> _derivePassphraseKey({
    required String passphrase,
    required List<int> salt,
    required VaultKdfConfig kdf,
  }) {
    if (kdf.algorithm != 'argon2id') {
      throw VaultException(
        'vault.unsupported_kdf',
        'Unsupported vault KDF: ${kdf.algorithm}.',
      );
    }
    return Argon2id(
      memory: kdf.memoryKiB,
      parallelism: kdf.parallelism,
      iterations: kdf.iterations,
      hashLength: kdf.hashLength,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  Future<SecretKey> _deriveRecordKey(SecretKey rootKey) {
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: rootKey,
      nonce: utf8.encode('serlink:vault:record-key:v1'),
    );
  }

  void _replaceRootKey(List<int> rootKeyBytes) {
    _rootKey?.destroy();
    _rootKey = SecretKey(rootKeyBytes);
  }

  void _validatePassphrase(String passphrase) {
    if (passphrase.isEmpty) {
      throw const VaultException(
        'vault.empty_passphrase',
        'Vault passphrase cannot be empty.',
      );
    }
  }

  void _setState(VaultState nextState) {
    if (_state == nextState) {
      return;
    }
    _state = nextState;
    _stateController.add(nextState);
  }
}

List<int> _recordAssociatedData({
  required VaultRecordId id,
  required String type,
  required int schemaVersion,
  required String revision,
}) {
  return utf8.encode(
    'serlink:vault-record:v1:${id.value}:$type:$schemaVersion:$revision',
  );
}

String _newRevision() {
  return base64UrlEncode(_randomBytes(16)).replaceAll('=', '');
}

String _base64UrlNoPadding(List<int> bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var mismatch = 0;
  for (var i = 0; i < a.length; i += 1) {
    mismatch |= a[i] ^ b[i];
  }
  return mismatch == 0;
}

final List<int> _passphraseRootKeyAad = utf8.encode(
  'serlink:vault-root-key:passphrase:v1',
);
final List<int> _recoveryRootKeyAad = utf8.encode(
  'serlink:vault-root-key:recovery:v1',
);
final List<int> _localUnlockRootKeyAad = utf8.encode(
  'serlink:vault-root-key:local-unlock:v1',
);
