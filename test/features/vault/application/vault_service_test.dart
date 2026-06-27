import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/secret_store.dart';

void main() {
  group('InMemoryVaultService', () {
    late InMemoryVaultService service;

    setUp(() {
      service = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    });

    test(
      'initializes, encrypts, decrypts, and stores no plaintext envelope',
      () async {
        await service.initialize(passphrase: 'correct horse battery staple');

        final plaintext = utf8.encode('deployPassword=top-secret');
        final envelope = await service.encryptRecord(
          id: VaultRecordId('record-1'),
          type: 'identity.password',
          plaintext: plaintext,
        );

        expect(await service.decryptRecord(envelope), plaintext);
        expect(jsonEncode(envelope.toJson()), isNot(contains('top-secret')));
        expect(
          jsonEncode(envelope.toJson()),
          isNot(contains('deployPassword')),
        );
      },
    );

    test('rejects wrong passphrase', () async {
      await service.initialize(passphrase: 'good passphrase');
      await service.lock();

      await expectLater(
        service.unlock(passphrase: 'bad passphrase'),
        throwsA(
          isA<VaultException>().having(
            (error) => error.code,
            'code',
            'vault.invalid_passphrase',
          ),
        ),
      );
      expect(service.state, VaultState.locked);
    });

    test('unlocks with recovery key', () async {
      final result = await service.initialize(passphrase: 'good passphrase');
      final envelope = await service.encryptRecord(
        id: VaultRecordId('record-1'),
        type: 'identity.private_key',
        plaintext: utf8.encode('-----BEGIN PRIVATE KEY-----'),
      );

      await service.lock();
      await service.unlockWithRecoveryKey(result.recoveryKey);

      expect(service.state, VaultState.unlocked);
      expect(
        utf8.decode(await service.decryptRecord(envelope)),
        '-----BEGIN PRIVATE KEY-----',
      );
    });

    test(
      'unlocks with passphrase and biometric protector independently',
      () async {
        final store = InMemorySecretStore();
        await service.initialize(passphrase: 'good passphrase');
        final envelope = await service.encryptRecord(
          id: VaultRecordId('record-1'),
          type: 'identity.password',
          plaintext: utf8.encode('secret'),
        );

        final protectedHeader = await service.enableLocalUnlock(secrets: store);

        expect(protectedHeader.localUnlockProtectors, hasLength(1));
        expect(
          protectedHeader.localUnlockProtectors.single.protection,
          VaultLocalUnlockProtection.biometricCurrentSet,
        );
        expect(await service.hasLocalUnlock(secrets: store), isTrue);
        expect(
          jsonEncode(protectedHeader.toJson()),
          isNot(contains('good passphrase')),
        );

        await service.lock();
        await service.unlockWithLocalKey(secrets: store);

        expect(utf8.decode(await service.decryptRecord(envelope)), 'secret');

        await service.lock();
        await service.unlock(passphrase: 'good passphrase');

        expect(utf8.decode(await service.decryptRecord(envelope)), 'secret');
      },
    );

    test(
      'disables biometric unlock without breaking passphrase unlock',
      () async {
        final store = InMemorySecretStore();
        await service.initialize(passphrase: 'good passphrase');
        final protectedHeader = await service.enableLocalUnlock(secrets: store);
        final secretRef =
            protectedHeader.localUnlockProtectors.single.secretRef;

        final unprotectedHeader = await service.disableLocalUnlock(
          secrets: store,
        );

        expect(unprotectedHeader.localUnlockProtectors, isEmpty);
        expect(await store.read(secretRef), isNull);
        expect(await service.hasLocalUnlock(secrets: store), isFalse);

        await service.lock();
        await expectLater(
          service.unlockWithLocalKey(secrets: store),
          throwsA(
            isA<VaultException>().having(
              (error) => error.code,
              'code',
              'vault.local_unlock_not_enabled',
            ),
          ),
        );

        await service.unlock(passphrase: 'good passphrase');

        expect(service.state, VaultState.unlocked);
      },
    );

    test('maps biometric secret read failures to unlock failure', () async {
      final store = _ReadFailingSecretStore();
      await service.initialize(passphrase: 'good passphrase');
      await service.enableLocalUnlock(secrets: store);
      await service.lock();

      await expectLater(
        service.unlockWithLocalKey(secrets: store),
        throwsA(
          isA<VaultException>().having(
            (error) => error.code,
            'code',
            'vault.local_unlock_failed',
          ),
        ),
      );
      expect(service.state, VaultState.locked);

      await service.unlock(passphrase: 'good passphrase');

      expect(service.state, VaultState.unlocked);
    });

    test('reads only one available biometric protector per unlock', () async {
      final store = _CountingSecretStore();
      await service.initialize(passphrase: 'good passphrase');
      final protectedHeader = await service.enableLocalUnlock(secrets: store);
      final activeProtector = protectedHeader.localUnlockProtectors.single;
      const staleRef = SecretRef('vault/biometric-unlock/stale');
      await store.write(staleRef, [
        1,
        2,
        3,
      ], protection: SecretProtection.biometricCurrentSet);
      final staleProtector = VaultLocalUnlockProtector(
        id: 'stale-protector',
        secretRef: staleRef,
        nonce: activeProtector.nonce,
        mac: activeProtector.mac,
        ciphertext: activeProtector.ciphertext,
        createdAt: DateTime.utc(2020),
        protection: VaultLocalUnlockProtection.biometricCurrentSet,
      );
      final multiProtectorService = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
        header: protectedHeader.copyWith(
          localUnlockProtectors: [staleProtector, activeProtector],
        ),
      );
      store.resetCounts();

      await multiProtectorService.unlockWithLocalKey(secrets: store);

      expect(multiProtectorService.state, VaultState.unlocked);
      expect(store.biometricReadRefs, [activeProtector.secretRef]);
    });

    test(
      'falls back when the newest biometric protector cannot decrypt',
      () async {
        final store = _CountingSecretStore();
        await service.initialize(passphrase: 'good passphrase');
        final protectedHeader = await service.enableLocalUnlock(secrets: store);
        final activeProtector = protectedHeader.localUnlockProtectors.single;
        const staleRef = SecretRef('vault/biometric-unlock/newer-stale');
        await store.write(staleRef, [
          1,
          2,
          3,
        ], protection: SecretProtection.biometricCurrentSet);
        final staleProtector = VaultLocalUnlockProtector(
          id: 'newer-stale-protector',
          secretRef: staleRef,
          nonce: activeProtector.nonce,
          mac: activeProtector.mac,
          ciphertext: activeProtector.ciphertext,
          createdAt: DateTime.utc(2100),
          protection: VaultLocalUnlockProtection.biometricCurrentSet,
        );
        final multiProtectorService = InMemoryVaultService(
          config: const VaultCryptoConfig.testing(),
          header: protectedHeader.copyWith(
            localUnlockProtectors: [activeProtector, staleProtector],
          ),
        );
        store.resetCounts();

        await multiProtectorService.unlockWithLocalKey(secrets: store);

        expect(multiProtectorService.state, VaultState.unlocked);
        expect(store.biometricReadRefs, [
          staleProtector.secretRef,
          activeProtector.secretRef,
        ]);
      },
    );

    test(
      'ignores biometric secret lookup failures when checking status',
      () async {
        final store = _ContainsFailingSecretStore();
        await service.initialize(passphrase: 'good passphrase');
        await service.enableLocalUnlock(secrets: InMemorySecretStore());

        expect(await service.hasLocalUnlock(secrets: store), isFalse);
      },
    );

    test('replaces existing protector when biometric lookup fails', () async {
      final store = _ContainsFailingSecretStore();
      await service.initialize(passphrase: 'good passphrase');
      await service.enableLocalUnlock(secrets: InMemorySecretStore());

      final nextHeader = await service.enableLocalUnlock(secrets: store);

      expect(nextHeader.localUnlockProtectors, hasLength(1));
      expect(
        nextHeader.localUnlockProtectors.single.protection,
        VaultLocalUnlockProtection.biometricCurrentSet,
      );
      expect(await service.hasLocalUnlock(secrets: store), isFalse);
      await service.lock();
      await service.unlock(passphrase: 'good passphrase');
      expect(service.state, VaultState.unlocked);
    });

    test('disables biometric unlock even when cleanup fails', () async {
      final store = _DeleteFailingSecretStore();
      await service.initialize(passphrase: 'good passphrase');
      final protectedHeader = await service.enableLocalUnlock(secrets: store);
      store.ref = protectedHeader.localUnlockProtectors.single.secretRef;

      final unprotectedHeader = await service.disableLocalUnlock(
        secrets: store,
      );

      expect(unprotectedHeader.localUnlockProtectors, isEmpty);
      expect(service.header!.localUnlockProtectors, isEmpty);
      expect(await service.hasLocalUnlock(secrets: store), isFalse);

      await service.lock();
      await expectLater(
        service.unlockWithLocalKey(secrets: store),
        throwsA(
          isA<VaultException>().having(
            (error) => error.code,
            'code',
            'vault.local_unlock_not_enabled',
          ),
        ),
      );

      await service.unlock(passphrase: 'good passphrase');

      expect(service.state, VaultState.unlocked);
    });

    test(
      'rejects enabling biometric unlock when biometrics are unavailable',
      () async {
        final store = InMemorySecretStore(
          capabilities: const SecretStoreCapabilities(
            available: true,
            deviceLocal: true,
            syncable: false,
            biometricGate: false,
          ),
        );
        await service.initialize(passphrase: 'good passphrase');

        await expectLater(
          service.enableLocalUnlock(secrets: store),
          throwsA(
            isA<VaultException>().having(
              (error) => error.code,
              'code',
              'vault.local_unlock_unavailable',
            ),
          ),
        );
      },
    );

    test(
      'ignores old local unlock protectors without biometric protection',
      () async {
        await service.initialize(passphrase: 'good passphrase');
        final header = service.header!;
        final legacyHeader = VaultHeader.fromJson({
          ...header.toJson(),
          'localUnlockProtectors': [
            {
              'id': 'legacy-protector',
              'secretRef': 'vault/local-unlock/legacy',
              'nonce': base64Encode(List<int>.filled(12, 1)),
              'mac': base64Encode(List<int>.filled(16, 2)),
              'ciphertext': base64Encode(List<int>.filled(32, 3)),
              'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
          ],
        });
        final legacyService = InMemoryVaultService(
          config: const VaultCryptoConfig.testing(),
          header: legacyHeader,
        );
        final store = InMemorySecretStore();
        await store.write(const SecretRef('vault/local-unlock/legacy'), [
          1,
          2,
          3,
        ]);

        expect(
          legacyHeader.localUnlockProtectors.single.protection,
          VaultLocalUnlockProtection.unsupported,
        );
        expect(await legacyService.hasLocalUnlock(secrets: store), isFalse);
        await expectLater(
          legacyService.unlockWithLocalKey(secrets: store),
          throwsA(
            isA<VaultException>().having(
              (error) => error.code,
              'code',
              'vault.local_unlock_not_enabled',
            ),
          ),
        );
      },
    );

    test('replaces stale protectors even when cleanup fails', () async {
      await service.initialize(passphrase: 'good passphrase');
      final header = service.header!;
      final legacyRef = const SecretRef('vault/local-unlock/stale');
      final legacyHeader = VaultHeader.fromJson({
        ...header.toJson(),
        'localUnlockProtectors': [
          {
            'id': 'legacy-protector',
            'secretRef': legacyRef.value,
            'nonce': base64Encode(List<int>.filled(12, 1)),
            'mac': base64Encode(List<int>.filled(16, 2)),
            'ciphertext': base64Encode(List<int>.filled(32, 3)),
            'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ],
      });
      final legacyService = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
        header: legacyHeader,
      );
      final store = _DeleteFailingSecretStore(legacyRef);
      await store.write(legacyRef, [1, 2, 3]);

      await legacyService.unlock(passphrase: 'good passphrase');
      final protectedHeader = await legacyService.enableLocalUnlock(
        secrets: store,
      );

      expect(protectedHeader.localUnlockProtectors, hasLength(1));
      expect(
        protectedHeader.localUnlockProtectors.single.secretRef,
        isNot(legacyRef),
      );
      expect(
        protectedHeader.localUnlockProtectors.single.protection,
        VaultLocalUnlockProtection.biometricCurrentSet,
      );

      await legacyService.lock();
      await legacyService.unlockWithLocalKey(secrets: store);

      expect(legacyService.state, VaultState.unlocked);
      expect(await store.read(legacyRef), isNotNull);
    });

    test('blocks record access while locked', () async {
      await service.initialize(passphrase: 'good passphrase');
      final envelope = await service.encryptRecord(
        id: VaultRecordId('record-1'),
        type: 'identity.password',
        plaintext: utf8.encode('secret'),
      );
      await service.lock();

      await expectLater(
        service.decryptRecord(envelope),
        throwsA(
          isA<VaultException>().having(
            (error) => error.code,
            'code',
            'vault.locked',
          ),
        ),
      );
    });

    test('detects associated data tampering before decrypting', () async {
      await service.initialize(passphrase: 'good passphrase');
      final envelope = await service.encryptRecord(
        id: VaultRecordId('record-1'),
        type: 'identity.password',
        plaintext: utf8.encode('secret'),
      );
      final tamperedAad = [...envelope.associatedData];
      tamperedAad[0] ^= 1;

      await expectLater(
        service.decryptRecord(
          _copyEnvelope(envelope, associatedData: tamperedAad),
        ),
        throwsA(
          isA<VaultException>().having(
            (error) => error.code,
            'code',
            'vault.record_metadata_tampered',
          ),
        ),
      );
    });

    test('detects ciphertext tampering', () async {
      await service.initialize(passphrase: 'good passphrase');
      final envelope = await service.encryptRecord(
        id: VaultRecordId('record-1'),
        type: 'identity.password',
        plaintext: utf8.encode('secret'),
      );
      final tamperedCiphertext = [...envelope.ciphertext];
      tamperedCiphertext[0] ^= 1;

      await expectLater(
        service.decryptRecord(
          _copyEnvelope(envelope, ciphertext: tamperedCiphertext),
        ),
        throwsA(
          isA<VaultException>().having(
            (error) => error.code,
            'code',
            'vault.record_authentication_failed',
          ),
        ),
      );
    });
  });

  group('InMemoryVaultRecordRepository', () {
    test('upserts, lists by type, and deletes envelopes', () async {
      final repository = InMemoryVaultRecordRepository();
      final service = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await service.initialize(passphrase: 'good passphrase');
      final password = await service.encryptRecord(
        id: VaultRecordId('record-password'),
        type: 'identity.password',
        plaintext: utf8.encode('secret'),
      );
      final host = await service.encryptRecord(
        id: VaultRecordId('record-host'),
        type: 'host',
        plaintext: utf8.encode('host metadata'),
      );

      await repository.upsert(password);
      await repository.upsert(host);

      expect(await repository.read(password.id), password);
      expect(await repository.list(type: 'identity.password'), [password]);
      expect(await repository.list(), hasLength(2));

      await repository.delete(password.id);

      expect(await repository.read(password.id), isNull);
    });
  });

  group('InMemorySecretStore', () {
    test('round trips secret bytes by stable reference', () async {
      final store = InMemorySecretStore();
      const ref = SecretRef('vault/unlock-key');
      await store.write(ref, [1, 2, 3, 4]);

      expect(await store.read(const SecretRef('vault/unlock-key')), [
        1,
        2,
        3,
        4,
      ]);

      await store.delete(ref);

      expect(await store.read(ref), isNull);
    });
  });
}

VaultRecordEnvelope _copyEnvelope(
  VaultRecordEnvelope envelope, {
  List<int>? nonce,
  List<int>? mac,
  List<int>? associatedData,
  List<int>? ciphertext,
}) {
  return VaultRecordEnvelope(
    id: envelope.id,
    type: envelope.type,
    schemaVersion: envelope.schemaVersion,
    revision: envelope.revision,
    nonce: nonce ?? envelope.nonce,
    mac: mac ?? envelope.mac,
    associatedData: associatedData ?? envelope.associatedData,
    ciphertext: ciphertext ?? envelope.ciphertext,
  );
}

class _DeleteFailingSecretStore extends InMemorySecretStore {
  _DeleteFailingSecretStore([this.ref]);

  SecretRef? ref;

  @override
  Future<void> delete(SecretRef ref) async {
    if (ref == this.ref) {
      throw StateError('delete failed');
    }
    await super.delete(ref);
  }
}

class _ReadFailingSecretStore extends InMemorySecretStore {
  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    if (protection == SecretProtection.biometricCurrentSet) {
      throw StateError('biometric read failed');
    }
    return super.read(ref, protection: protection);
  }
}

class _CountingSecretStore extends InMemorySecretStore {
  final List<SecretRef> biometricReadRefs = [];

  void resetCounts() {
    biometricReadRefs.clear();
  }

  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    if (protection == SecretProtection.biometricCurrentSet) {
      biometricReadRefs.add(ref);
    }
    return super.read(ref, protection: protection);
  }
}

class _ContainsFailingSecretStore extends InMemorySecretStore {
  @override
  Future<bool> contains(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    throw StateError('secret lookup failed');
  }
}
