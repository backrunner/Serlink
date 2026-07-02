import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/application/host_write_service.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/identities/domain/identity.dart';
import 'package:serlink/features/identities/domain/identity_secret.dart';
import 'package:serlink/features/sync/application/sync_delete_tombstone_repository.dart';
import 'package:serlink/features/ssh/application/encrypted_connection_profile_resolver.dart';
import 'package:serlink/features/ssh/application/known_host_repository.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test('creates password host and stores all data encrypted', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final summary = await service.createPasswordHost(
      const PasswordHostDraft(
        displayName: 'Production Bastion',
        hostname: 'bastion.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {'prod'},
        startupCommands: ['tmux attach || tmux'],
        remoteSessionSettings: HostRemoteSessionSettings(
          enabled: true,
          manager: HostRemoteSessionManager.auto,
          sessionName: 'ops',
          createIfMissing: true,
          fallbackToShell: false,
        ),
      ),
    );

    final storedHosts = await hosts.list();
    expect(storedHosts, hasLength(1));
    expect(storedHosts.single.displayName, summary.displayName);
    expect(storedHosts.single.identityIds, hasLength(1));
    expect(storedHosts.single.startupCommands, ['tmux attach || tmux']);
    expect(
      storedHosts.single.remoteSessionSettings,
      const HostRemoteSessionSettings(
        enabled: true,
        manager: HostRemoteSessionManager.auto,
        sessionName: 'ops',
        createIfMissing: true,
        fallbackToShell: false,
      ),
    );

    final resolver = EncryptedConnectionProfileResolver(
      hosts: hosts,
      identities: identities,
      records: records,
      vault: vault,
    );
    final profile = await resolver.resolve(
      hostId: summary.id,
      sessionId: SessionId('session-1'),
    );
    expect(profile.hostname, 'bastion.internal');
    expect(profile.remoteSession.enabled, isTrue);
    expect(profile.remoteSession.manager, SshRemoteSessionManager.auto);
    expect(profile.remoteSession.sessionName, 'ops');
    expect(profile.remoteSession.fallbackToShell, isFalse);
    final auth = profile.authMethods.single as SshPasswordAuth;
    expect(String.fromCharCodes(auth.password.copyBytes()), 'server-password');

    final serializedRecords = jsonEncode([
      for (final record in await records.list()) record.toJson(),
    ]);
    expect(serializedRecords, isNot(contains('bastion.internal')));
    expect(serializedRecords, isNot(contains('server-password')));
  });

  test('uses hostname as display name when display name is blank', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final summary = await service.createPasswordHost(
      const PasswordHostDraft(
        displayName: '   ',
        hostname: 'bastion.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {},
      ),
    );

    final storedHost = await hosts.read(summary.id);
    expect(summary.displayName, 'bastion.internal');
    expect(storedHost!.displayName, 'bastion.internal');
  });

  test('persists normalized host connection settings', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final summary = await service.createPasswordHost(
      const PasswordHostDraft(
        displayName: 'Connection Tuning',
        hostname: 'tuned.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {},
        connectionSettings: HostConnectionSettings(
          connectTimeoutSeconds: 45,
          keepAliveIntervalSeconds: 20,
          reconnectAttempts: 2,
          reconnectBackoffSeconds: 11,
        ),
      ),
    );

    final stored = await hosts.read(summary.id);
    expect(stored, isNotNull);
    expect(
      stored!.connectionSettings,
      const HostConnectionSettings(
        connectTimeoutSeconds: 45,
        keepAliveIntervalSeconds: 20,
        reconnectAttempts: 2,
        reconnectBackoffSeconds: 11,
      ),
    );
  });

  test('persists host port forwarding settings', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final forwarding = const HostPortForwardingSettings(
      localForwards: [
        HostLocalPortForward(
          localPort: 15432,
          remoteHost: ' db.internal ',
          remotePort: 5432,
        ),
      ],
      remoteForwards: [
        HostRemotePortForward(
          bindHost: '127.0.0.1',
          bindPort: 18080,
          localHost: ' app.internal ',
          localPort: 8080,
        ),
      ],
      dynamicForwards: [
        HostDynamicPortForward(bindHost: ' 127.0.0.1 ', bindPort: 1080),
      ],
    );

    final summary = await service.createPasswordHost(
      PasswordHostDraft(
        displayName: 'Forwarded Host',
        hostname: 'forwarded.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {},
        portForwarding: forwarding,
      ),
    );

    final stored = await hosts.read(summary.id);
    expect(stored, isNotNull);
    expect(
      stored!.portForwarding,
      const HostPortForwardingSettings(
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
            localHost: 'app.internal',
            localPort: 8080,
          ),
        ],
        dynamicForwards: [
          HostDynamicPortForward(bindHost: '127.0.0.1', bindPort: 1080),
        ],
      ),
    );
  });

  test('persists normalized host sftp default directory', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final summary = await service.createPasswordHost(
      const PasswordHostDraft(
        displayName: 'SFTP Home',
        hostname: 'sftp.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {},
        sftpDefaultDirectory: '/home/ops/../ops/app/',
      ),
    );

    var stored = await hosts.read(summary.id);
    expect(stored, isNotNull);
    expect(stored!.sftpDefaultDirectory, '/home/ops/app');

    await service.updateSftpDefaultDirectory(summary.id, '/srv/app');
    stored = await hosts.read(summary.id);
    expect(stored!.sftpDefaultDirectory, '/srv/app');
  });

  test('rejects invalid host connection settings', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    await expectLater(
      service.createPasswordHost(
        const PasswordHostDraft(
          displayName: 'Bad Settings',
          hostname: 'bad.internal',
          port: 22,
          username: 'ops',
          password: 'server-password',
          tags: {},
          connectionSettings: HostConnectionSettings(
            connectTimeoutSeconds: 2,
            keepAliveIntervalSeconds: 1,
            reconnectAttempts: 11,
            reconnectBackoffSeconds: 0,
          ),
        ),
      ),
      throwsA(
        isA<HostWriteException>().having(
          (error) => error.code,
          'code',
          'host.connect_timeout_invalid',
        ),
      ),
    );
    expect(await records.list(), isEmpty);
  });

  test('rejects invalid host port forwarding settings', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    await expectLater(
      service.createPasswordHost(
        const PasswordHostDraft(
          displayName: 'Bad Forward',
          hostname: 'bad-forward.internal',
          port: 22,
          username: 'ops',
          password: 'server-password',
          tags: {},
          portForwarding: HostPortForwardingSettings(
            localForwards: [
              HostLocalPortForward(
                localPort: 0,
                remoteHost: 'db.internal',
                remotePort: 5432,
              ),
            ],
          ),
        ),
      ),
      throwsA(
        isA<HostWriteException>().having(
          (error) => error.code,
          'code',
          'host.port_forwarding_port_invalid',
        ),
      ),
    );
    expect(await hosts.list(), isEmpty);
  });

  test('rejects unsafe remote session names', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    await expectLater(
      service.createPasswordHost(
        const PasswordHostDraft(
          displayName: 'Bad Remote Session',
          hostname: 'bad-session.internal',
          port: 22,
          username: 'ops',
          password: 'server-password',
          tags: {},
          remoteSessionSettings: HostRemoteSessionSettings(
            enabled: true,
            sessionName: 'ops; rm -rf /',
          ),
        ),
      ),
      throwsA(
        isA<HostWriteException>().having(
          (error) => error.code,
          'code',
          'host.remote_session_name_invalid',
        ),
      ),
    );
    expect(await hosts.list(), isEmpty);
  });

  test('creates private key host and resolves private key auth', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final summary = await service.createPrivateKeyHost(
      const PrivateKeyHostDraft(
        displayName: 'Key Host',
        hostname: 'key.internal',
        port: 2222,
        username: 'deploy',
        privateKeyPem:
            '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
        privateKeyPassphrase: 'key-passphrase',
        tags: {'key'},
      ),
    );

    final resolver = EncryptedConnectionProfileResolver(
      hosts: hosts,
      identities: identities,
      records: records,
      vault: vault,
    );
    final profile = await resolver.resolve(
      hostId: summary.id,
      sessionId: SessionId('session-1'),
    );

    expect(profile.hostname, 'key.internal');
    expect(profile.port, 2222);
    final auth = profile.authMethods.single as SshPrivateKeyAuth;
    expect(
      String.fromCharCodes(auth.privateKeyPem.copyBytes()),
      contains('BEGIN OPENSSH PRIVATE KEY'),
    );
    expect(
      String.fromCharCodes(auth.passphrase!.copyBytes()),
      'key-passphrase',
    );

    final serializedRecords = jsonEncode([
      for (final record in await records.list()) record.toJson(),
    ]);
    expect(serializedRecords, isNot(contains('key.internal')));
    expect(serializedRecords, isNot(contains('key-passphrase')));
  });

  test('updates host metadata and preserves identity secrets', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );
    final summary = await service.createPasswordHost(
      const PasswordHostDraft(
        displayName: 'Old Name',
        hostname: 'old.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {},
        startupCommands: ['pwd'],
        remoteSessionSettings: HostRemoteSessionSettings(
          enabled: true,
          manager: HostRemoteSessionManager.tmux,
          sessionName: 'ops',
          createIfMissing: false,
          fallbackToShell: true,
        ),
      ),
    );
    final before = await hosts.read(summary.id);
    final updated = await service.updateHostMetadata(
      HostMetadataDraft(
        id: summary.id,
        displayName: 'New Name',
        hostname: 'new.internal',
        port: 2200,
        username: 'deploy',
        tags: const {'prod'},
        identityIds: before!.identityIds,
        startupCommands: ['tmux attach -t ops'],
        jumpHostIds: const [],
      ),
    );

    final after = await hosts.read(summary.id);
    expect(updated.displayName, 'New Name');
    expect(after!.hostname, 'new.internal');
    expect(after.identityIds, before.identityIds);
    expect(after.startupCommands, ['tmux attach -t ops']);
    expect(after.remoteSessionSettings, before.remoteSessionSettings);
    expect(after.jumpHostIds, isEmpty);

    final resolver = EncryptedConnectionProfileResolver(
      hosts: hosts,
      identities: identities,
      records: records,
      vault: vault,
    );
    final profile = await resolver.resolve(
      hostId: summary.id,
      sessionId: SessionId('session-1'),
    );
    final auth = profile.authMethods.single as SshPasswordAuth;
    expect(String.fromCharCodes(auth.password.copyBytes()), 'server-password');
  });

  test(
    'duplicates host with editable metadata and shared credentials',
    () async {
      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final records = InMemoryVaultRecordRepository();
      final hosts = EncryptedHostRepository(vault: vault, records: records);
      final identities = EncryptedIdentityRepository(
        vault: vault,
        records: records,
      );
      await vault.initialize(passphrase: 'good passphrase');

      final service = HostWriteService(
        hosts: hosts,
        identities: identities,
        knownHosts: EncryptedKnownHostRepository(
          vault: vault,
          records: records,
        ),
        tombstones: EncryptedSyncDeleteTombstoneRepository(
          vault: vault,
          records: records,
        ),
        records: records,
        vault: vault,
      );
      final summary = await service.createPasswordHost(
        const PasswordHostDraft(
          displayName: 'Source Host',
          hostname: 'source.internal',
          port: 22,
          username: 'ops',
          password: 'server-password',
          tags: {'prod'},
          startupCommands: ['cd /srv/app'],
          sftpDefaultDirectory: '/srv/app',
          connectionSettings: HostConnectionSettings(
            connectTimeoutSeconds: 30,
            keepAliveIntervalSeconds: 20,
            reconnectAttempts: 2,
            reconnectBackoffSeconds: 7,
          ),
        ),
      );
      final source = await hosts.read(summary.id);
      await hosts.save(
        HostConfig(
          id: source!.id,
          displayName: source.displayName,
          hostname: source.hostname,
          username: source.username,
          port: source.port,
          authKinds: source.authKinds,
          tags: source.tags,
          trustState: HostTrustState.trusted,
          identityIds: source.identityIds,
          startupCommands: source.startupCommands,
          jumpHostIds: source.jumpHostIds,
          sftpDefaultDirectory: source.sftpDefaultDirectory,
          portForwarding: source.portForwarding,
          connectionSettings: source.connectionSettings,
          groupId: 'ops',
          lastConnectedAt: DateTime.utc(2026, 6, 1),
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
        ),
      );

      final duplicate = await service.duplicateHost(
        DuplicateHostDraft(
          sourceHostId: summary.id,
          displayName: 'Copied Host',
          hostname: 'copied.internal',
          port: 2200,
          username: 'deploy',
          tags: const {'copied'},
          identityIds: source.identityIds,
          startupCommands: const ['tmux attach || tmux'],
          sftpDefaultDirectory: '/home/deploy',
          connectionSettings: const HostConnectionSettings(
            connectTimeoutSeconds: 45,
            keepAliveIntervalSeconds: 25,
            reconnectAttempts: 3,
            reconnectBackoffSeconds: 9,
          ),
        ),
      );

      final copied = await hosts.read(duplicate.id);
      expect(duplicate.id, isNot(summary.id));
      expect(copied!.displayName, 'Copied Host');
      expect(copied.hostname, 'copied.internal');
      expect(copied.port, 2200);
      expect(copied.username, 'deploy');
      expect(copied.tags, {'copied'});
      expect(copied.identityIds, source.identityIds);
      expect(copied.authKinds, source.authKinds);
      expect(copied.startupCommands, ['tmux attach || tmux']);
      expect(copied.sftpDefaultDirectory, '/home/deploy');
      expect(
        copied.connectionSettings,
        const HostConnectionSettings(
          connectTimeoutSeconds: 45,
          keepAliveIntervalSeconds: 25,
          reconnectAttempts: 3,
          reconnectBackoffSeconds: 9,
        ),
      );
      expect(copied.groupId, 'ops');
      expect(copied.trustState, HostTrustState.unknown);
      expect(copied.lastConnectedAt, isNull);

      await service.deleteHost(summary.id);
      expect(await identities.read(copied.identityIds.single), isNotNull);
    },
  );

  test('deletes host and unshared identity secret records', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );
    final summary = await service.createPasswordHost(
      const PasswordHostDraft(
        displayName: 'Delete Me',
        hostname: 'delete.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {},
      ),
    );

    final knownHosts = EncryptedKnownHostRepository(
      vault: vault,
      records: records,
    );
    await knownHosts.save(
      KnownHostRecord(
        hostId: summary.id,
        hostname: 'delete.internal',
        port: 22,
        algorithm: 'ssh-ed25519',
        fingerprint: 'MD5:aa',
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );

    expect(await records.list(), hasLength(4));
    await service.deleteHost(summary.id);

    expect(await hosts.read(summary.id), isNull);
    expect(await knownHosts.read(summary.id), isNull);
    expect(await identities.list(), isEmpty);
    expect(
      await records.list(
        type: EncryptedSyncDeleteTombstoneRepository.recordType,
      ),
      hasLength(4),
    );
  });

  test('creates host from existing identities and jump host links', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    await _saveIdentity(
      vault: vault,
      records: records,
      identities: identities,
      id: IdentityId('cert-1'),
      secretRecordId: VaultRecordId('secret:cert-1'),
      kind: IdentityKind.openSshCertificate,
      material: const IdentitySecretMaterial(
        privateKeyPem:
            '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
        openSshCertificate:
            'ssh-ed25519-cert-v01@openssh.com AAAAB3NzaC1yc2EAAAADAQABAAABAQ== ops@example',
      ),
    );
    await _saveIdentity(
      vault: vault,
      records: records,
      identities: identities,
      id: IdentityId('kbd-1'),
      secretRecordId: VaultRecordId('secret:kbd-1'),
      kind: IdentityKind.keyboardInteractive,
      material: const IdentitySecretMaterial(
        keyboardInteractiveResponses: ['otp-code'],
      ),
    );
    await hosts.save(
      HostConfig(
        id: HostId('jump-1'),
        displayName: 'Jump',
        hostname: 'jump.internal',
        username: 'ops',
        port: 22,
        authKinds: {HostAuthKind.password},
        tags: {},
        trustState: HostTrustState.unknown,
        identityIds: [IdentityId('cert-1')],
        startupCommands: [],
        jumpHostIds: [],
        createdAt: DateTime.utc(2026, 5, 28),
        updatedAt: DateTime.utc(2026, 5, 28),
      ),
    );

    final summary = await service.createHostWithExistingIdentities(
      ExistingIdentitiesHostDraft(
        displayName: 'Existing Identity Host',
        hostname: 'prod.internal',
        port: 22,
        username: 'ops',
        identityIds: [IdentityId('cert-1'), IdentityId('kbd-1')],
        tags: const {'imported'},
        startupCommands: const ['tmux attach || tmux', 'cd /srv/app'],
        jumpHostIds: [HostId('jump-1')],
      ),
    );

    final stored = await hosts.read(summary.id);
    expect(
      stored!.authKinds,
      containsAll([
        HostAuthKind.openSshCertificate,
        HostAuthKind.keyboardInteractive,
      ]),
    );
    expect(stored.startupCommands, ['tmux attach || tmux', 'cd /srv/app']);
    expect(stored.jumpHostIds, [HostId('jump-1')]);
  });

  test('creates and updates host without selected credentials', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final summary = await service.createHostWithExistingIdentities(
      const ExistingIdentitiesHostDraft(
        displayName: 'Credential Later',
        hostname: 'later.internal',
        port: 22,
        username: 'ops',
        identityIds: [],
        tags: {},
      ),
    );
    final created = await hosts.read(summary.id);
    expect(created!.identityIds, isEmpty);
    expect(created.authKinds, isEmpty);

    await service.updateHostMetadata(
      HostMetadataDraft(
        id: summary.id,
        displayName: 'Still Later',
        hostname: 'later.internal',
        port: 22,
        username: 'ops',
        tags: const {'pending'},
        identityIds: const [],
      ),
    );

    final updated = await hosts.read(summary.id);
    expect(updated!.displayName, 'Still Later');
    expect(updated.identityIds, isEmpty);
    expect(updated.authKinds, isEmpty);
  });

  test('creates ssh-agent host without storing secret material', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final service = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );

    final summary = await service.createSshAgentHost(
      const SshAgentHostDraft(
        displayName: 'Agent Host',
        hostname: 'agent.internal',
        port: 22,
        username: 'ops',
        tags: {},
      ),
    );

    final stored = await hosts.read(summary.id);
    expect(stored!.authKinds, {HostAuthKind.sshAgent});
    expect(stored.identityIds, hasLength(1));
    final identity = await identities.read(stored.identityIds.single);
    expect(identity!.kind, IdentityKind.sshAgent);
    expect(identity.secretRecordId, isNull);
    expect(await records.list(type: 'identity_secret'), isEmpty);
  });

  test('validates required fields before writing records', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final service = HostWriteService(
      hosts: EncryptedHostRepository(vault: vault, records: records),
      identities: EncryptedIdentityRepository(vault: vault, records: records),
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );
    await vault.initialize(passphrase: 'good passphrase');

    await expectLater(
      service.createPasswordHost(
        const PasswordHostDraft(
          displayName: '',
          hostname: '',
          port: 22,
          username: 'ops',
          password: 'server-password',
          tags: {},
        ),
      ),
      throwsA(
        isA<HostWriteException>().having(
          (error) => error.code,
          'code',
          'host.hostname_required',
        ),
      ),
    );
    expect(await records.list(), isEmpty);
  });
}

Future<void> _saveIdentity({
  required InMemoryVaultService vault,
  required InMemoryVaultRecordRepository records,
  required EncryptedIdentityRepository identities,
  required IdentityId id,
  required VaultRecordId secretRecordId,
  required IdentityKind kind,
  required IdentitySecretMaterial material,
}) async {
  await records.upsert(
    await vault.encryptRecord(
      id: secretRecordId,
      type: 'identity_secret',
      plaintext: material.toBytes(),
    ),
  );
  await identities.save(
    IdentityConfig(
      id: id,
      displayName: id.value,
      kind: kind,
      usernameHint: 'ops',
      secretRecordId: secretRecordId,
      createdAt: DateTime.utc(2026, 5, 28),
      updatedAt: DateTime.utc(2026, 5, 28),
    ),
  );
}
