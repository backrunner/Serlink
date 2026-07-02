import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/identities/domain/identity.dart';
import 'package:serlink/features/identities/domain/identity_secret.dart';
import 'package:serlink/features/ssh/application/connection_profile_resolver.dart';
import 'package:serlink/features/ssh/application/encrypted_connection_profile_resolver.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late EncryptedHostRepository hosts;
  late EncryptedIdentityRepository identities;
  late EncryptedConnectionProfileResolver resolver;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    records = InMemoryVaultRecordRepository();
    hosts = EncryptedHostRepository(vault: vault, records: records);
    identities = EncryptedIdentityRepository(vault: vault, records: records);
    resolver = EncryptedConnectionProfileResolver(
      hosts: hosts,
      identities: identities,
      records: records,
      vault: vault,
    );
    await vault.initialize(passphrase: 'good passphrase');
  });

  test(
    'resolves encrypted password identity into connection profile',
    () async {
      await _saveSecret(
        vault: vault,
        records: records,
        id: VaultRecordId('secret:ops-password'),
        material: const IdentitySecretMaterial(password: 'server-password'),
      );
      await identities.save(
        IdentityConfig(
          id: IdentityId('ops-password'),
          displayName: 'Ops Password',
          kind: IdentityKind.password,
          secretRecordId: VaultRecordId('secret:ops-password'),
          createdAt: DateTime.utc(2026, 5, 27),
          updatedAt: DateTime.utc(2026, 5, 27),
        ),
      );
      await hosts.save(
        _host(
          identityIds: [IdentityId('ops-password')],
          remoteSessionSettings: const HostRemoteSessionSettings(
            enabled: true,
            manager: HostRemoteSessionManager.screen,
            sessionName: 'ops',
            createIfMissing: true,
            fallbackToShell: false,
          ),
        ),
      );

      final profile = await resolver.resolve(
        hostId: HostId('production'),
        sessionId: SessionId('session-1'),
      );

      expect(profile.hostname, 'bastion.internal');
      expect(profile.username, 'ops');
      expect(profile.startupCommands, ['tmux attach || tmux']);
      expect(profile.remoteSession.enabled, isTrue);
      expect(profile.remoteSession.manager, SshRemoteSessionManager.screen);
      expect(profile.remoteSession.sessionName, 'ops');
      expect(profile.remoteSession.createIfMissing, isTrue);
      expect(profile.remoteSession.fallbackToShell, isFalse);
      expect(profile.authMethods, hasLength(1));
      final auth = profile.authMethods.single as SshPasswordAuth;
      expect(
        String.fromCharCodes(auth.password.copyBytes()),
        'server-password',
      );
    },
  );

  test('resolves host port forwarding into connection profile', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-password'),
      material: const IdentitySecretMaterial(password: 'server-password'),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-password'),
        displayName: 'Ops Password',
        kind: IdentityKind.password,
        secretRecordId: VaultRecordId('secret:ops-password'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(
      _host(
        identityIds: [IdentityId('ops-password')],
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
      ),
    );

    final profile = await resolver.resolve(
      hostId: HostId('production'),
      sessionId: SessionId('session-1'),
    );

    expect(profile.portForwarding.localForwards.single.localPort, 15432);
    expect(
      profile.portForwarding.localForwards.single.remoteHost,
      'db.internal',
    );
    expect(profile.portForwarding.remoteForwards.single.bindPort, 18080);
    expect(profile.portForwarding.dynamicForwards.single.bindPort, 1080);
  });

  test('uses password credential username before host username', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-password'),
      material: const IdentitySecretMaterial(password: 'server-password'),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-password'),
        displayName: 'Ops Password',
        kind: IdentityKind.password,
        usernameHint: 'credential-user',
        secretRecordId: VaultRecordId('secret:ops-password'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(
      _host(username: 'host-user', identityIds: [IdentityId('ops-password')]),
    );

    final profile = await resolver.resolve(
      hostId: HostId('production'),
      sessionId: SessionId('session-1'),
    );

    expect(profile.username, 'credential-user');
  });

  test('keeps host username for non-password credentials', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-key'),
      material: const IdentitySecretMaterial(
        privateKeyPem: '-----BEGIN OPENSSH PRIVATE KEY-----',
      ),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-key'),
        displayName: 'Ops Key',
        kind: IdentityKind.privateKey,
        usernameHint: 'key-user',
        secretRecordId: VaultRecordId('secret:ops-key'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(
      _host(username: 'host-user', identityIds: [IdentityId('ops-key')]),
    );

    final profile = await resolver.resolve(
      hostId: HostId('production'),
      sessionId: SessionId('session-1'),
    );

    expect(profile.username, 'host-user');
  });

  test('resolves encrypted private key identity', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-key'),
      material: const IdentitySecretMaterial(
        privateKeyPem: '-----BEGIN OPENSSH PRIVATE KEY-----',
        privateKeyPassphrase: 'key-passphrase',
      ),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-key'),
        displayName: 'Ops Key',
        kind: IdentityKind.privateKey,
        secretRecordId: VaultRecordId('secret:ops-key'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(_host(identityIds: [IdentityId('ops-key')]));

    final profile = await resolver.resolve(
      hostId: HostId('production'),
      sessionId: SessionId('session-1'),
    );

    final auth = profile.authMethods.single as SshPrivateKeyAuth;
    expect(
      String.fromCharCodes(auth.privateKeyPem.copyBytes()),
      '-----BEGIN OPENSSH PRIVATE KEY-----',
    );
    expect(
      String.fromCharCodes(auth.passphrase!.copyBytes()),
      'key-passphrase',
    );
  });

  test('resolves ProxyJump host links into ordered jump snapshots', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-password'),
      material: const IdentitySecretMaterial(password: 'server-password'),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-password'),
        displayName: 'Ops Password',
        kind: IdentityKind.password,
        secretRecordId: VaultRecordId('secret:ops-password'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(
      _host(
        id: HostId('jump-1'),
        displayName: 'Jump 1',
        hostname: 'jump-1.internal',
        identityIds: [IdentityId('ops-password')],
      ),
    );
    await hosts.save(
      _host(
        id: HostId('jump-2'),
        displayName: 'Jump 2',
        hostname: 'jump-2.internal',
        identityIds: [IdentityId('ops-password')],
        jumpHostIds: [HostId('jump-1')],
      ),
    );
    await hosts.save(
      _host(
        id: HostId('production'),
        displayName: 'Production',
        hostname: 'prod.internal',
        identityIds: [IdentityId('ops-password')],
        jumpHostIds: [HostId('jump-2')],
      ),
    );

    final profile = await resolver.resolve(
      hostId: HostId('production'),
      sessionId: SessionId('session-1'),
    );

    expect(profile.hostname, 'prod.internal');
    expect(profile.jumpHosts, hasLength(2));
    expect(profile.jumpHosts[0].hostId, HostId('jump-1'));
    expect(profile.jumpHosts[0].hostname, 'jump-1.internal');
    expect(profile.jumpHosts[1].hostId, HostId('jump-2'));
    expect(profile.jumpHosts[1].hostname, 'jump-2.internal');
    expect(profile.jumpHosts[0].authMethods.single, isA<SshPasswordAuth>());
  });

  test('uses password credential username for jump hosts', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-password'),
      material: const IdentitySecretMaterial(password: 'server-password'),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-password'),
        displayName: 'Ops Password',
        kind: IdentityKind.password,
        usernameHint: 'jump-credential-user',
        secretRecordId: VaultRecordId('secret:ops-password'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(
      _host(
        id: HostId('jump-1'),
        displayName: 'Jump 1',
        hostname: 'jump-1.internal',
        username: 'jump-host-user',
        identityIds: [IdentityId('ops-password')],
      ),
    );
    await hosts.save(
      _host(
        id: HostId('production'),
        displayName: 'Production',
        hostname: 'prod.internal',
        identityIds: [IdentityId('ops-password')],
        jumpHostIds: [HostId('jump-1')],
      ),
    );

    final profile = await resolver.resolve(
      hostId: HostId('production'),
      sessionId: SessionId('session-1'),
    );

    expect(profile.jumpHosts.single.username, 'jump-credential-user');
  });

  test('rejects cyclic jump host chains', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-password'),
      material: const IdentitySecretMaterial(password: 'server-password'),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-password'),
        displayName: 'Ops Password',
        kind: IdentityKind.password,
        secretRecordId: VaultRecordId('secret:ops-password'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(
      _host(
        id: HostId('production'),
        identityIds: [IdentityId('ops-password')],
        jumpHostIds: [HostId('jump-1')],
      ),
    );
    await hosts.save(
      _host(
        id: HostId('jump-1'),
        displayName: 'Jump 1',
        hostname: 'jump-1.internal',
        identityIds: [IdentityId('ops-password')],
        jumpHostIds: [HostId('production')],
      ),
    );

    await expectLater(
      resolver.resolve(
        hostId: HostId('production'),
        sessionId: SessionId('session-1'),
      ),
      throwsA(
        isA<ConnectionProfileResolutionException>().having(
          (error) => error.code,
          'code',
          'connection_profile.jump_cycle',
        ),
      ),
    );
  });

  test('fails when host has no identities', () async {
    await hosts.save(_host(identityIds: const []));

    await expectLater(
      resolver.resolve(
        hostId: HostId('production'),
        sessionId: SessionId('session-1'),
      ),
      throwsA(
        isA<ConnectionProfileResolutionException>().having(
          (error) => error.code,
          'code',
          'connection_profile.no_auth_methods',
        ),
      ),
    );
  });

  test('rejects SSH agent auth when platform does not support it', () async {
    final mobileResolver = EncryptedConnectionProfileResolver(
      hosts: hosts,
      identities: identities,
      records: records,
      vault: vault,
      sshAgentAuthAvailable: false,
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('agent'),
        displayName: 'Agent',
        kind: IdentityKind.sshAgent,
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(_host(identityIds: [IdentityId('agent')]));

    await expectLater(
      mobileResolver.resolve(
        hostId: HostId('production'),
        sessionId: SessionId('session-1'),
      ),
      throwsA(
        isA<ConnectionProfileResolutionException>().having(
          (error) => error.code,
          'code',
          'connection_profile.ssh_agent_unsupported',
        ),
      ),
    );
  });

  test('locked vault prevents profile resolution', () async {
    await _saveSecret(
      vault: vault,
      records: records,
      id: VaultRecordId('secret:ops-password'),
      material: const IdentitySecretMaterial(password: 'server-password'),
    );
    await identities.save(
      IdentityConfig(
        id: IdentityId('ops-password'),
        displayName: 'Ops Password',
        kind: IdentityKind.password,
        secretRecordId: VaultRecordId('secret:ops-password'),
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );
    await hosts.save(_host(identityIds: [IdentityId('ops-password')]));
    await vault.lock();

    await expectLater(
      resolver.resolve(
        hostId: HostId('production'),
        sessionId: SessionId('session-1'),
      ),
      throwsA(
        isA<VaultException>().having(
          (error) => error.code,
          'code',
          'vault.locked',
        ),
      ),
    );
  });
}

HostConfig _host({
  HostId? id,
  String displayName = 'Production Bastion',
  String hostname = 'bastion.internal',
  String username = 'ops',
  required List<IdentityId> identityIds,
  List<String> startupCommands = const ['tmux attach || tmux'],
  List<HostId> jumpHostIds = const [],
  HostPortForwardingSettings portForwarding =
      const HostPortForwardingSettings(),
  HostRemoteSessionSettings remoteSessionSettings =
      const HostRemoteSessionSettings(),
}) {
  return HostConfig(
    id: id ?? HostId('production'),
    displayName: displayName,
    hostname: hostname,
    username: username,
    port: 22,
    authKinds: const {HostAuthKind.privateKey},
    tags: const {'prod'},
    trustState: HostTrustState.trusted,
    identityIds: identityIds,
    startupCommands: startupCommands,
    jumpHostIds: jumpHostIds,
    portForwarding: portForwarding,
    remoteSessionSettings: remoteSessionSettings,
    createdAt: DateTime.utc(2026, 5, 27),
    updatedAt: DateTime.utc(2026, 5, 27),
  );
}

Future<void> _saveSecret({
  required InMemoryVaultService vault,
  required InMemoryVaultRecordRepository records,
  required VaultRecordId id,
  required IdentitySecretMaterial material,
}) async {
  await records.upsert(
    await vault.encryptRecord(
      id: id,
      type: 'identity.secret',
      plaintext: material.toBytes(),
    ),
  );
}
