import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test(
    'encrypted host repository stores host config as vault envelope',
    () async {
      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final records = InMemoryVaultRecordRepository();
      final repository = EncryptedHostRepository(
        vault: vault,
        records: records,
      );
      await vault.initialize(passphrase: 'good passphrase');

      final host = HostConfig(
        id: HostId('production'),
        displayName: 'Production Bastion',
        hostname: 'bastion.internal',
        username: 'ops',
        port: 22,
        authKinds: const {HostAuthKind.privateKey, HostAuthKind.sshAgent},
        tags: const {'prod', 'bastion'},
        trustState: HostTrustState.trusted,
        identityIds: [IdentityId('ops-key')],
        startupCommands: const ['tmux attach || tmux'],
        jumpHostIds: const [],
        connectionSettings: const HostConnectionSettings(
          connectTimeoutSeconds: 30,
          keepAliveIntervalSeconds: 12,
          reconnectAttempts: 3,
          reconnectBackoffSeconds: 9,
        ),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27, 1),
      );

      await repository.save(host);

      final rawEnvelope = await records.read(VaultRecordId('host:production'));
      expect(rawEnvelope, isNotNull);
      expect(rawEnvelope!.id, VaultRecordId('host:production'));
      expect(rawEnvelope.type, EncryptedHostRepository.recordType);
      expect(rawEnvelope.ciphertext, isNotEmpty);
      expect(rawEnvelope.associatedData, isNotEmpty);
      expect(
        jsonDecode(utf8.decode(await vault.decryptRecord(rawEnvelope))),
        host.toJson(),
      );

      final restored = await repository.read(host.id);
      expect(restored, isNotNull);
      expect(restored!.hostname, host.hostname);
      expect(restored.toSummary().displayName, host.displayName);
      expect(
        restored.connectionSettings.toJson(),
        host.connectionSettings.toJson(),
      );

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
