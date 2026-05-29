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

    test('enables device-local unlock without storing passphrase', () async {
      final store = InMemorySecretStore();
      await service.initialize(passphrase: 'good passphrase');
      final envelope = await service.encryptRecord(
        id: VaultRecordId('record-1'),
        type: 'identity.password',
        plaintext: utf8.encode('secret'),
      );

      final protectedHeader = await service.enableLocalUnlock(secrets: store);

      expect(protectedHeader.localUnlockProtectors, hasLength(1));
      expect(await service.hasLocalUnlock(secrets: store), isTrue);
      expect(
        jsonEncode(protectedHeader.toJson()),
        isNot(contains('good passphrase')),
      );

      await service.lock();
      await service.unlockWithLocalKey(secrets: store);

      expect(utf8.decode(await service.decryptRecord(envelope)), 'secret');
    });

    test('disables device-local unlock and deletes protector secret', () async {
      final store = InMemorySecretStore();
      await service.initialize(passphrase: 'good passphrase');
      final protectedHeader = await service.enableLocalUnlock(secrets: store);
      final secretRef = protectedHeader.localUnlockProtectors.single.secretRef;

      final unprotectedHeader = await service.disableLocalUnlock(
        secrets: store,
      );

      expect(unprotectedHeader.localUnlockProtectors, isEmpty);
      expect(await store.read(secretRef), isNull);
      expect(await service.hasLocalUnlock(secrets: store), isFalse);
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
