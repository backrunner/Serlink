import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/identities/domain/identity.dart';
import 'package:serlink/features/import_export/application/open_ssh_config_import_service.dart';
import 'package:serlink/features/ssh/application/encrypted_connection_profile_resolver.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test('previews common OpenSSH config host directives', () {
    final service = OpenSshConfigImportService();

    final result = service.preview(r'''
Host prod bastion
  HostName prod.example.test
  User deploy
  Port 2222
  IdentityFile "~/.ssh/prod key"
  ProxyJump jumpbox
  ServerAliveInterval 30

Host *
  User ignored
''');

    expect(result.entries, hasLength(2));
    expect(result.skippedHosts, 0);
    expect(
      result.warnings.map((warning) => warning.code),
      contains('ssh_config.directive_unsupported'),
    );
    expect(
      result.warnings.map((warning) => warning.code),
      isNot(contains('ssh_config.host_pattern_unsupported')),
    );

    final prod = result.entries.first;
    expect(prod.alias, 'prod');
    expect(prod.hostname, 'prod.example.test');
    expect(prod.username, 'deploy');
    expect(prod.port, 2222);
    expect(prod.identityFiles, ['~/.ssh/prod key']);
    expect(prod.proxyJump, 'jumpbox');

    final bastion = result.entries.last;
    expect(bastion.alias, 'bastion');
    expect(bastion.hostname, 'prod.example.test');
  });

  test('expands Include files and applies Host star inheritance', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'serlink-ssh-config-include-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final defaults = File('${tempDir.path}/defaults.conf');
    await defaults.writeAsString('''
Host *
  User ops
  Port 2200
  IdentityFile shared_key
''');
    final configFile = File('${tempDir.path}/config');
    await configFile.writeAsString('''
Include defaults.conf

Host prod
  HostName prod.example.test
''');
    final service = OpenSshConfigImportService();

    final result = service.preview(
      await configFile.readAsString(),
      configSourcePath: configFile.path,
    );

    expect(result.entries, hasLength(1));
    expect(result.warnings, isEmpty);
    expect(result.skippedHosts, 0);
    expect(result.entries.single.alias, 'prod');
    expect(result.entries.single.hostname, 'prod.example.test');
    expect(result.entries.single.username, 'ops');
    expect(result.entries.single.port, 2200);
    expect(result.entries.single.identityFiles, ['shared_key']);
  });

  test('Include glob does not match nested child directories', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'serlink-ssh-config-include-glob-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final configDir = Directory('${tempDir.path}/conf.d');
    final nestedDir = Directory('${configDir.path}/nested');
    await nestedDir.create(recursive: true);
    await File('${configDir.path}/top.conf').writeAsString('''
Host top
  HostName top.example.test
  User ops
''');
    await File('${nestedDir.path}/nested.conf').writeAsString('''
Host nested
  HostName nested.example.test
  User ops
''');
    final configFile = File('${tempDir.path}/config');
    await configFile.writeAsString('Include conf.d/*.conf');
    final service = OpenSshConfigImportService();

    final result = service.preview(
      await configFile.readAsString(),
      configSourcePath: configFile.path,
    );

    expect(result.entries.map((entry) => entry.alias), ['top']);
  });

  test('warns on Include cycles and unsafe ProxyCommand', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'serlink-ssh-config-cycle-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final configFile = File('${tempDir.path}/config');
    await configFile.writeAsString('''
Include config

Host prod
  HostName prod.example.test
  User deploy
  ProxyCommand ssh bastion nc %h %p
  IdentityAgent ~/.ssh/agent.sock
''');
    final service = OpenSshConfigImportService();

    final result = service.preview(
      await configFile.readAsString(),
      configSourcePath: configFile.path,
    );

    expect(result.entries, hasLength(1));
    expect(
      result.warnings.map((warning) => warning.code),
      containsAll([
        'ssh_config.include_cycle',
        'ssh_config.identity_agent_unsupported',
        'ssh_config.proxy_command_unsupported',
      ]),
    );
  });

  test('does not let Match blocks mutate surrounding Host entries', () {
    final service = OpenSshConfigImportService();

    final result = service.preview('''
Host prod
  HostName prod.example.test
  User deploy

Match host prod
  User root
  IdentityFile root_key

Host db
  HostName db.example.test
  User ops
  UserKnownHostsFile ~/.ssh/custom_known_hosts
  GlobalKnownHostsFile /etc/ssh/ssh_known_hosts
''');

    expect(result.entries, hasLength(2));
    final prod = result.entries.singleWhere((entry) => entry.alias == 'prod');
    final db = result.entries.singleWhere((entry) => entry.alias == 'db');
    expect(prod.username, 'deploy');
    expect(prod.identityFiles, isEmpty);
    expect(db.username, 'ops');
    expect(
      result.warnings.map((warning) => warning.code),
      containsAll([
        'ssh_config.known_hosts_file_unsupported',
        'ssh_config.match_unsupported',
      ]),
    );
  });

  test(
    'falls back to alias and default port when optional fields are absent',
    () {
      final service = OpenSshConfigImportService();

      final result = service.preview('''
Host db
  User ops
''');

      expect(result.entries, hasLength(1));
      expect(result.entries.single.alias, 'db');
      expect(result.entries.single.hostname, 'db');
      expect(result.entries.single.port, 22);
      expect(result.entries.single.username, 'ops');
      expect(result.warnings, isEmpty);
    },
  );

  test('warns on invalid ports and empty directives without dropping host', () {
    final service = OpenSshConfigImportService();

    final result = service.preview('''
Host broken
  Port not-a-port
  HostName
''');

    expect(result.entries, hasLength(1));
    expect(result.entries.single.port, 22);
    expect(
      result.warnings.map((warning) => warning.code),
      containsAll(['ssh_config.port_invalid', 'ssh_config.directive_empty']),
    );
  });

  test('warns on unsupported port forwarding forms without dropping host', () {
    final service = OpenSshConfigImportService();

    final result = service.preview('''
Host forwarded
  HostName forwarded.example.test
  User deploy
  LocalForward 0.0.0.0:15432 db.internal:5432
''');

    expect(result.entries, hasLength(1));
    expect(result.entries.single.portForwarding.isEmpty, isTrue);
    expect(
      result.warnings.map((warning) => warning.code),
      contains('ssh_config.port_forwarding_invalid'),
    );
  });

  test('applies preview as encrypted host metadata records', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    await vault.initialize(passphrase: 'passphrase');
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final service = OpenSshConfigImportService(
      hosts: hosts,
      now: () => DateTime.utc(2026, 5, 28),
    );

    final preview = service.preview(r'''
Host prod
  HostName prod.example.test
  User deploy
  Port 2222
  IdentityFile ~/.ssh/prod
  ProxyJump jumpbox
  LocalForward 15432 db.internal:5432
  RemoteForward 127.0.0.1:18080 127.0.0.1:8080
  DynamicForward 1080
''');
    final result = await service.applyPreview(preview);

    expect(result.hostsCreated, 1);
    expect(result.hostsSkipped, 0);
    expect(result.identitiesImported, 0);
    expect(
      result.warnings.map((warning) => warning.code),
      containsAll([
        'ssh_config.identity_file_pending',
        'ssh_config.proxy_jump_unresolved',
      ]),
    );

    final importedHosts = await hosts.list();
    expect(importedHosts, hasLength(1));
    expect(importedHosts.single.displayName, 'prod');
    expect(importedHosts.single.hostname, 'prod.example.test');
    expect(importedHosts.single.username, 'deploy');
    expect(importedHosts.single.port, 2222);
    expect(importedHosts.single.identityIds, isEmpty);
    expect(importedHosts.single.tags, contains('imported'));
    expect(importedHosts.single.writeBackToSshConfig, isTrue);
    expect(
      importedHosts.single.portForwarding.localForwards.single,
      const HostLocalPortForward(
        localPort: 15432,
        remoteHost: 'db.internal',
        remotePort: 5432,
      ),
    );
    expect(
      importedHosts.single.portForwarding.remoteForwards.single,
      const HostRemotePortForward(
        bindHost: '127.0.0.1',
        bindPort: 18080,
        localHost: '127.0.0.1',
        localPort: 8080,
      ),
    );
    expect(
      importedHosts.single.portForwarding.dynamicForwards.single,
      const HostDynamicPortForward(bindHost: '127.0.0.1', bindPort: 1080),
    );

    final serializedRecords = jsonEncode([
      for (final record in await records.list()) record.toJson(),
    ]);
    expect(serializedRecords, isNot(contains('prod.example.test')));
    expect(serializedRecords, isNot(contains('deploy')));
  });

  test('imports readable IdentityFile private keys and links host', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'serlink-ssh-config-import-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final keyFile = File('${tempDir.path}/prod_key');
    await keyFile.writeAsString(
      '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
    );
    final configFile = File('${tempDir.path}/config');
    await configFile.writeAsString('''
Host prod
  HostName prod.example.test
  User deploy
  IdentityFile prod_key
''');

    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    await vault.initialize(passphrase: 'passphrase');
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    final service = OpenSshConfigImportService(
      hosts: hosts,
      identities: identities,
      records: records,
      vault: vault,
      now: () => DateTime.utc(2026, 5, 28),
    );

    final preview = service.preview(await configFile.readAsString());
    final result = await service.applyPreview(
      preview,
      configSourcePath: configFile.path,
    );

    expect(result.hostsCreated, 1);
    expect(result.identitiesImported, 1);
    expect(
      result.warnings.map((warning) => warning.code),
      isNot(contains('ssh_config.identity_file_pending')),
    );

    final importedHost = (await hosts.list()).single;
    expect(importedHost.identityIds, hasLength(1));
    expect(importedHost.authKinds, {HostAuthKind.privateKey});

    final resolver = EncryptedConnectionProfileResolver(
      hosts: hosts,
      identities: identities,
      records: records,
      vault: vault,
    );
    final profile = await resolver.resolve(
      hostId: importedHost.id,
      sessionId: SessionId('session-1'),
    );
    expect(profile.authMethods.single, isA<SshPrivateKeyAuth>());

    final serializedRecords = jsonEncode([
      for (final record in await records.list()) record.toJson(),
    ]);
    expect(serializedRecords, isNot(contains('OPENSSH PRIVATE KEY')));
    expect(serializedRecords, isNot(contains('prod.example.test')));
  });

  test(
    'imports paired IdentityFile and CertificateFile as certificate auth',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'serlink-ssh-config-cert-import-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final keyFile = File('${tempDir.path}/prod_key');
      await keyFile.writeAsString(
        '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
      );
      final certificateFile = File('${tempDir.path}/prod_key-cert.pub');
      await certificateFile.writeAsString(
        'ssh-ed25519-cert-v01@openssh.com YWJj deploy@prod',
      );
      final configFile = File('${tempDir.path}/config');
      await configFile.writeAsString('''
Host prod
  HostName prod.example.test
  User deploy
  IdentityFile prod_key
  CertificateFile prod_key-cert.pub
''');

      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await vault.initialize(passphrase: 'passphrase');
      final records = InMemoryVaultRecordRepository();
      final hosts = EncryptedHostRepository(vault: vault, records: records);
      final identities = EncryptedIdentityRepository(
        vault: vault,
        records: records,
      );
      final service = OpenSshConfigImportService(
        hosts: hosts,
        identities: identities,
        records: records,
        vault: vault,
        now: () => DateTime.utc(2026, 5, 28),
      );

      final preview = service.preview(
        await configFile.readAsString(),
        configSourcePath: configFile.path,
      );
      final result = await service.applyPreview(
        preview,
        configSourcePath: configFile.path,
      );

      expect(result.hostsCreated, 1);
      expect(result.identitiesImported, 1);
      expect(result.warnings, isEmpty);

      final importedHost = (await hosts.list()).single;
      expect(importedHost.authKinds, {HostAuthKind.openSshCertificate});
      expect(importedHost.identityIds, hasLength(1));
      final identity = await identities.read(importedHost.identityIds.single);
      expect(identity?.kind, IdentityKind.openSshCertificate);
      expect(identity?.certificatePrincipal, 'deploy@prod');

      final resolver = EncryptedConnectionProfileResolver(
        hosts: hosts,
        identities: identities,
        records: records,
        vault: vault,
      );
      final profile = await resolver.resolve(
        hostId: importedHost.id,
        sessionId: SessionId('session-1'),
      );
      expect(profile.authMethods.single, isA<SshOpenSshCertificateAuth>());

      final serializedRecords = jsonEncode([
        for (final record in await records.list()) record.toJson(),
      ]);
      expect(serializedRecords, isNot(contains('OPENSSH PRIVATE KEY')));
      expect(serializedRecords, isNot(contains('ssh-ed25519-cert')));
    },
  );

  test(
    'reuses private-key identity when paired certificate is missing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'serlink-ssh-config-missing-cert-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final keyFile = File('${tempDir.path}/shared_key');
      await keyFile.writeAsString(
        '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
      );
      final configFile = File('${tempDir.path}/config');
      await configFile.writeAsString('''
Host prod
  HostName prod.example.test
  User deploy
  IdentityFile shared_key
  CertificateFile missing-cert.pub

Host stage
  HostName stage.example.test
  User deploy
  IdentityFile shared_key
  CertificateFile missing-cert.pub
''');

      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await vault.initialize(passphrase: 'passphrase');
      final records = InMemoryVaultRecordRepository();
      final hosts = EncryptedHostRepository(vault: vault, records: records);
      final identities = EncryptedIdentityRepository(
        vault: vault,
        records: records,
      );
      final service = OpenSshConfigImportService(
        hosts: hosts,
        identities: identities,
        records: records,
        vault: vault,
        now: () => DateTime.utc(2026, 5, 28),
      );

      final preview = service.preview(
        await configFile.readAsString(),
        configSourcePath: configFile.path,
      );
      final result = await service.applyPreview(
        preview,
        configSourcePath: configFile.path,
      );

      expect(result.hostsCreated, 2);
      expect(result.identitiesImported, 1);
      expect(
        result.warnings.map((warning) => warning.code),
        contains('ssh_config.certificate_file_missing'),
      );

      final importedHosts = await hosts.list();
      for (final host in importedHosts) {
        expect(host.authKinds, {HostAuthKind.privateKey});
        expect(host.identityIds, hasLength(1));
      }
      expect(
        importedHosts.map((host) => host.identityIds.single).toSet(),
        hasLength(1),
      );
      final identity = await identities.read(
        importedHosts.first.identityIds.single,
      );
      expect(identity?.kind, IdentityKind.privateKey);
    },
  );

  test(
    'reuses an existing certificate identity across incremental imports',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'serlink-ssh-config-incremental-identity-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final keyFile = File('${tempDir.path}/shared_key');
      await keyFile.writeAsString(
        '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
      );
      final certificateFile = File('${tempDir.path}/shared_key-cert.pub');
      await certificateFile.writeAsString(
        'ssh-ed25519-cert-v01@openssh.com YWJj deploy@shared',
      );
      final configFile = File('${tempDir.path}/config');

      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await vault.initialize(passphrase: 'passphrase');
      final records = InMemoryVaultRecordRepository();
      final hosts = EncryptedHostRepository(vault: vault, records: records);
      final identities = EncryptedIdentityRepository(
        vault: vault,
        records: records,
      );
      final service = OpenSshConfigImportService(
        hosts: hosts,
        identities: identities,
        records: records,
        vault: vault,
        now: () => DateTime.utc(2026, 5, 28),
      );

      await configFile.writeAsString('''
Host prod
  HostName prod.example.test
  User deploy
  IdentityFile shared_key
  CertificateFile shared_key-cert.pub
''');
      final first = await service.applyPreview(
        service.preview(
          await configFile.readAsString(),
          configSourcePath: configFile.path,
        ),
        configSourcePath: configFile.path,
      );

      await configFile.writeAsString('''
Host stage
  HostName stage.example.test
  User deploy
  IdentityFile shared_key
  CertificateFile shared_key-cert.pub
''');
      final second = await service.applyPreview(
        service.preview(
          await configFile.readAsString(),
          configSourcePath: configFile.path,
        ),
        configSourcePath: configFile.path,
      );

      expect(first.identitiesImported, 1);
      expect(second.identitiesImported, 0);
      final savedIdentities = await identities.list();
      expect(savedIdentities, hasLength(1));
      expect(savedIdentities.single.kind, IdentityKind.openSshCertificate);
      expect(savedIdentities.single.certificatePrincipal, 'deploy@shared');
      final importedHosts = await hosts.list();
      expect(importedHosts, hasLength(2));
      expect(
        importedHosts.map((host) => host.identityIds.single).toSet(),
        hasLength(1),
      );
    },
  );

  test(
    'applies resolvable ProxyJump aliases as encrypted host links',
    () async {
      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await vault.initialize(passphrase: 'passphrase');
      final records = InMemoryVaultRecordRepository();
      final hosts = EncryptedHostRepository(vault: vault, records: records);
      final service = OpenSshConfigImportService(
        hosts: hosts,
        now: () => DateTime.utc(2026, 5, 28),
      );

      final preview = service.preview('''
Host bastion
  HostName bastion.example.test
  User ops

Host prod
  HostName prod.example.test
  User deploy
  ProxyJump ops@bastion:2222
''');
      final result = await service.applyPreview(preview);

      expect(result.hostsCreated, 2);
      expect(
        result.warnings.map((warning) => warning.code),
        isNot(contains('ssh_config.proxy_jump_unresolved')),
      );

      final importedHosts = await hosts.list();
      final bastion = importedHosts.singleWhere(
        (host) => host.displayName == 'bastion',
      );
      final prod = importedHosts.singleWhere(
        (host) => host.displayName == 'prod',
      );

      expect(prod.jumpHostIds, [bastion.id]);

      final serializedRecords = jsonEncode([
        for (final record in await records.list()) record.toJson(),
      ]);
      expect(serializedRecords, isNot(contains('bastion.example.test')));
      expect(serializedRecords, isNot(contains('prod.example.test')));
    },
  );

  test('apply skips duplicate hosts and entries without usernames', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    await vault.initialize(passphrase: 'passphrase');
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    await hosts.save(
      _host(id: HostId('existing'), hostname: 'prod.example.test', port: 22),
    );
    final service = OpenSshConfigImportService(
      hosts: hosts,
      now: () => DateTime.utc(2026, 5, 28),
    );

    final preview = service.preview('''
Host prod
  HostName prod.example.test
  User deploy

Host missing-user
  HostName missing.example.test
''');
    final result = await service.applyPreview(preview);

    expect(result.hostsCreated, 0);
    expect(result.duplicateHosts, 1);
    expect(result.missingUsernames, 1);
    expect(result.hostsSkipped, 2);
    expect(result.retryAliases, {'missing-user'});
    expect(
      result.warnings.map((warning) => warning.code),
      contains('ssh_config.username_missing'),
    );
    expect(await hosts.list(), hasLength(1));
  });
}

HostConfig _host({
  required HostId id,
  required String hostname,
  required int port,
}) {
  return HostConfig(
    id: id,
    displayName: hostname,
    hostname: hostname,
    username: 'ops',
    port: port,
    authKinds: const {HostAuthKind.password},
    tags: const {},
    trustState: HostTrustState.unknown,
    identityIds: const [],
    startupCommands: const [],
    jumpHostIds: const [],
    createdAt: DateTime.utc(2026, 5, 28),
    updatedAt: DateTime.utc(2026, 5, 28),
  );
}
