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
        portForwarding: const HostPortForwardingSettings(
          localForwards: [
            HostLocalPortForward(
              localPort: 15432,
              remoteHost: 'db.internal',
              remotePort: 5432,
            ),
          ],
          remoteForwards: [
            HostRemotePortForward(
              bindHost: '127.0.0.1',
              bindPort: 18080,
              localHost: '127.0.0.1',
              localPort: 8080,
            ),
          ],
          dynamicForwards: [
            HostDynamicPortForward(bindHost: '127.0.0.1', bindPort: 1080),
          ],
        ),
        connectionSettings: const HostConnectionSettings(
          connectTimeoutSeconds: 30,
          keepAliveIntervalSeconds: 12,
          reconnectAttempts: 3,
          reconnectBackoffSeconds: 9,
        ),
        remoteSessionSettings: const HostRemoteSessionSettings(
          enabled: true,
          manager: HostRemoteSessionManager.tmux,
          sessionName: 'ops',
          createIfMissing: true,
          fallbackToShell: false,
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
      expect(restored.portForwarding, host.portForwarding);
      expect(restored.remoteSessionSettings, host.remoteSessionSettings);

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

  test('host config defaults missing port forwarding to empty settings', () {
    final host = HostConfig.fromJson({
      'id': 'legacy',
      'displayName': 'Legacy Host',
      'hostname': 'legacy.internal',
      'username': 'ops',
      'port': 22,
      'authKinds': ['password'],
      'tags': ['legacy'],
      'trustState': 'unknown',
      'identityIds': ['identity-1'],
      'startupCommands': <String>[],
      'jumpHostIds': <String>[],
      'createdAt': DateTime.utc(2026, 5, 27).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 5, 27).toIso8601String(),
    });

    expect(host.portForwarding, const HostPortForwardingSettings());
    expect(host.portForwarding.isEmpty, isTrue);
    expect(host.remoteSessionSettings, const HostRemoteSessionSettings());
  });
}
