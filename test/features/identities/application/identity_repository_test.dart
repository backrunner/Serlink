import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/identities/domain/identity.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test(
    'encrypted identity repository stores identity metadata encrypted',
    () async {
      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final records = InMemoryVaultRecordRepository();
      final repository = EncryptedIdentityRepository(
        vault: vault,
        records: records,
      );
      await vault.initialize(passphrase: 'good passphrase');

      final identity = IdentityConfig(
        id: IdentityId('ops-key'),
        displayName: 'Ops Key',
        kind: IdentityKind.privateKey,
        usernameHint: 'ops',
        secretRecordId: VaultRecordId('secret:ops-key'),
        publicKeyFingerprint: 'SHA256:abc123',
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27, 1),
      );

      await repository.save(identity);

      final rawEnvelope = await records.read(VaultRecordId('identity:ops-key'));
      expect(rawEnvelope, isNotNull);
      expect(jsonEncode(rawEnvelope!.toJson()), isNot(contains('Ops Key')));
      expect(
        jsonEncode(rawEnvelope.toJson()),
        isNot(contains('SHA256:abc123')),
      );

      final restored = await repository.read(identity.id);
      expect(restored, isNotNull);
      expect(restored!.publicKeyFingerprint, identity.publicKeyFingerprint);

      await vault.lock();

      await expectLater(
        repository.list(),
        throwsA(
          isA<VaultException>().having(
            (error) => error.code,
            'code',
            'vault.locked',
          ),
        ),
      );
    },
  );
}
