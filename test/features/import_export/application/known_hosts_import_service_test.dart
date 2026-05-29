import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/import_export/application/known_hosts_import_service.dart';
import 'package:serlink/features/ssh/application/known_host_repository.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late EncryptedHostRepository hosts;
  late EncryptedKnownHostRepository knownHosts;
  late KnownHostsImportService service;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    records = InMemoryVaultRecordRepository();
    hosts = EncryptedHostRepository(vault: vault, records: records);
    knownHosts = EncryptedKnownHostRepository(vault: vault, records: records);
    service = KnownHostsImportService(
      hosts: hosts,
      knownHosts: knownHosts,
      now: () => DateTime.utc(2026, 5, 27, 12),
    );
  });

  test(
    'imports matching OpenSSH known_hosts entries into known hosts',
    () async {
      await hosts.save(
        _host(id: HostId('host-1'), hostname: 'bastion.internal', port: 22),
      );
      await hosts.save(
        _host(id: HostId('host-2'), hostname: 'db.internal', port: 2222),
      );

      final result = await service.importText('''
bastion.internal ssh-ed25519 aGVsbG8= comment
[db.internal]:2222 ssh-rsa aGVsbG8=
unmatched.example.test ssh-ed25519 aGVsbG8=
|1|salt|hash ssh-ed25519 aGVsbG8=
@cert-authority *.example.com ssh-ed25519 aGVsbG8=
''');

      expect(result.entriesParsed, 3);
      expect(result.recordsImported, 2);
      expect(result.unmatchedHosts, 1);
      expect(result.skippedLines, 2);
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll([
          'known_hosts.cert_authority_unsupported',
          'known_hosts.hashed_host_unsupported',
        ]),
      );

      final bastion = await knownHosts.read(HostId('host-1'));
      expect(bastion!.algorithm, 'ssh-ed25519');
      expect(
        bastion.fingerprint,
        'MD5:5d:41:40:2a:bc:4b:2a:76:b9:71:9d:91:10:17:c5:92',
      );
      expect(bastion.updatedAt, DateTime.utc(2026, 5, 27, 12));

      final db = await knownHosts.read(HostId('host-2'));
      expect(db!.algorithm, 'ssh-rsa');

      final envelopes = await records.list(
        type: EncryptedKnownHostRepository.recordType,
      );
      final serialized = jsonEncode([
        for (final envelope in envelopes) envelope.toJson(),
      ]);
      expect(serialized, isNot(contains('bastion.internal')));
      expect(serialized, isNot(contains('db.internal')));
    },
  );

  test('imports comma-separated targets from one known_hosts line', () async {
    await hosts.save(
      _host(id: HostId('host-1'), hostname: 'bastion.internal', port: 22),
    );
    await hosts.save(
      _host(id: HostId('host-2'), hostname: 'alias.internal', port: 22),
    );
    await hosts.save(
      _host(id: HostId('host-3'), hostname: 'db.internal', port: 2222),
    );

    final result = await service.importText(
      'bastion.internal,alias.internal,[db.internal]:2222 ssh-ed25519 aGVsbG8=',
    );

    expect(result.entriesParsed, 1);
    expect(result.recordsImported, 3);
    expect(result.unmatchedHosts, 0);
    expect(result.skippedLines, 0);
    expect(result.warnings, isEmpty);
    expect(await knownHosts.read(HostId('host-1')), isNotNull);
    expect(await knownHosts.read(HostId('host-2')), isNotNull);
    expect(await knownHosts.read(HostId('host-3')), isNotNull);
  });

  test(
    'counts unmatched targets on partially matched known_hosts lines',
    () async {
      await hosts.save(
        _host(id: HostId('host-1'), hostname: 'bastion.internal', port: 22),
      );

      final result = await service.importText(
        'bastion.internal,missing.internal,[other.internal]:2200 ssh-ed25519 aGVsbG8=',
      );

      expect(result.entriesParsed, 1);
      expect(result.recordsImported, 1);
      expect(result.unmatchedHosts, 2);
      expect(await knownHosts.read(HostId('host-1')), isNotNull);
    },
  );

  test('keeps valid targets but warns for hashed or pattern targets', () async {
    await hosts.save(
      _host(id: HostId('host-1'), hostname: 'bastion.internal', port: 22),
    );

    final result = await service.importText(
      'bastion.internal,|1|salt|hash,*.example.test ssh-ed25519 aGVsbG8=',
    );

    expect(result.entriesParsed, 1);
    expect(result.recordsImported, 1);
    expect(result.skippedLines, 0);
    expect(
      result.warnings.map((warning) => warning.code),
      containsAll([
        'known_hosts.hashed_host_unsupported',
        'known_hosts.pattern_unsupported',
      ]),
    );
    expect(await knownHosts.read(HostId('host-1')), isNotNull);
  });

  test('warns specifically for cert-authority and revoked markers', () async {
    await hosts.save(
      _host(id: HostId('host-1'), hostname: 'bastion.internal', port: 22),
    );

    final result = await service.importText('''
@revoked bastion.internal ssh-ed25519 aGVsbG8=
@cert-authority *.example.test ssh-ed25519 aGVsbG8=
''');

    expect(result.entriesParsed, 0);
    expect(result.recordsImported, 0);
    expect(result.skippedLines, 2);
    expect(
      result.warnings.map((warning) => warning.code),
      containsAll([
        'known_hosts.cert_authority_unsupported',
        'known_hosts.revoked_key_unsupported',
      ]),
    );
    expect(await knownHosts.read(HostId('host-1')), isNull);
  });

  test(
    'preserves known host creation time when replacing fingerprint',
    () async {
      await hosts.save(
        _host(id: HostId('host-1'), hostname: 'bastion.internal', port: 22),
      );
      await knownHosts.save(
        KnownHostRecord(
          hostId: HostId('host-1'),
          hostname: 'bastion.internal',
          port: 22,
          algorithm: 'ssh-rsa',
          fingerprint: 'MD5:old',
          createdAt: DateTime.utc(2026, 5, 1),
          updatedAt: DateTime.utc(2026, 5, 1),
        ),
      );

      await service.importText('bastion.internal ssh-ed25519 aGVsbG8=');

      final imported = await knownHosts.read(HostId('host-1'));
      expect(imported!.createdAt, DateTime.utc(2026, 5, 1));
      expect(imported.updatedAt, DateTime.utc(2026, 5, 27, 12));
      expect(imported.algorithm, 'ssh-ed25519');
    },
  );
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
    createdAt: DateTime.utc(2026, 5, 27),
    updatedAt: DateTime.utc(2026, 5, 27),
  );
}
