import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_group_repository.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/application/host_write_service.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/ssh/application/known_host_repository.dart';
import 'package:serlink/features/sync/application/sync_delete_tombstone_repository.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late EncryptedHostGroupRepository groups;
  late EncryptedHostRepository hosts;
  late HostWriteService writer;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    records = InMemoryVaultRecordRepository();
    await vault.initialize(passphrase: 'test passphrase');
    groups = EncryptedHostGroupRepository(vault: vault, records: records);
    hosts = EncryptedHostRepository(vault: vault, records: records);
    writer = HostWriteService(
      hosts: hosts,
      identities: EncryptedIdentityRepository(vault: vault, records: records),
      knownHosts: EncryptedKnownHostRepository(vault: vault, records: records),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      records: records,
      vault: vault,
    );
  });

  test(
    'empty groups persist encrypted without hosts and survive reopening',
    () async {
      await groups.save('  Production  ');
      await groups.save('Production');
      expect(await hosts.list(), isEmpty);
      expect(await records.list(), hasLength(1));
      expect(
        jsonEncode([for (final r in await records.list()) r.toJson()]),
        isNot(contains('Production')),
      );
      final reopened = EncryptedHostGroupRepository(
        vault: vault,
        records: records,
      );
      expect(await reopened.list(), ['Production']);
      await vault.lock();
      await expectLater(reopened.list(), throwsA(isA<VaultException>()));
    },
  );

  test(
    'moving a host preserves its full configuration and empty source group',
    () async {
      final summary = await writer.createPasswordHost(
        const PasswordHostDraft(
          displayName: 'Bastion',
          hostname: 'bastion.example',
          port: 2222,
          username: 'ops',
          password: 'secret',
          tags: {'prod'},
          groupId: 'Legacy',
          startupCommands: ['pwd'],
          sftpDefaultDirectory: '/srv',
          connectionSettings: HostConnectionSettings(connectTimeoutSeconds: 42),
          remoteSessionSettings: HostRemoteSessionSettings(
            enabled: true,
            sessionName: 'work',
          ),
          portForwarding: HostPortForwardingSettings(
            localForwards: [
              HostLocalPortForward(
                localPort: 15432,
                remoteHost: 'db',
                remotePort: 5432,
              ),
            ],
          ),
          writeBackToSshConfig: true,
        ),
      );
      final before = (await hosts.read(summary.id))!.toJson();
      final credentialsBefore = [
        for (final r in await records.list())
          if (r.type.startsWith('identity')) r.toJson(),
      ];
      await writer.moveHostToGroup(summary.id, '  Staging  ');
      final after = (await hosts.read(summary.id))!.toJson();
      expect(after, {
        ...before,
        'groupId': 'Staging',
        'updatedAt': after['updatedAt'],
      });
      expect(await groups.list(), ['Legacy', 'Staging']);
      expect([
        for (final r in await records.list())
          if (r.type.startsWith('identity')) r.toJson(),
      ], credentialsBefore);
      await writer.moveHostToGroup(summary.id, null);
      expect((await hosts.read(summary.id))!.groupId, isNull);
      expect(await groups.list(), ['Legacy', 'Staging']);
    },
  );

  test('invalid groups and missing hosts do not create records', () async {
    await expectLater(groups.save('  '), throwsArgumentError);
    await expectLater(groups.save('__new_group__'), throwsArgumentError);
    await expectLater(
      writer.moveHostToGroup(HostId('missing'), 'Prod'),
      throwsA(isA<HostWriteException>()),
    );
    expect(await records.list(), isEmpty);
  });
}
