import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sync/application/sync_device_service.dart';
import 'package:serlink/features/sync/application/sync_delete_tombstone_repository.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/local_sync_provider.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';

void main() {
  late Directory tempDir;
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late SyncRunService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('serlink-sync-run-test-');
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    records = InMemoryVaultRecordRepository();
    service = SyncRunService(vault: vault, records: records);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('pushes encrypted vault header, records, and manifest', () async {
    final envelope = await vault.encryptRecord(
      id: VaultRecordId('host:1'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"secret.example.test"}'),
    );
    await records.upsert(envelope);

    final provider = LocalDirectorySyncProvider(tempDir);
    final result = await service.pushEncryptedSnapshot(provider);

    expect(result.recordsUploaded, 1);
    expect(result.headerUploaded, isTrue);

    final refs = await provider.listRecordObjects();
    expect([
      for (final ref in refs) ref.path,
    ], containsAll(['records/host%3A1.json', 'vault/header.json']));

    final remoteRecord = utf8.decode(
      await provider.readObject(const RemoteObjectRef('records/host%3A1.json')),
    );
    expect(remoteRecord, isNot(contains('secret.example.test')));

    final manifest = await provider.readManifest();
    expect(manifest, isNotNull);
    final manifestPayload = utf8.decode(manifest!.encryptedPayload);
    expect(manifestPayload, isNot(contains('secret.example.test')));
  });

  test('push includes encrypted writer device metadata', () async {
    final deviceService = SyncDeviceService(
      devices: EncryptedSyncDeviceRepository(vault: vault, records: records),
      secrets: InMemorySecretStore(),
      displayName: 'Ops Laptop',
      platform: 'test-os',
      now: () => DateTime.utc(2026, 5, 27, 10),
    );
    service = SyncRunService(
      vault: vault,
      records: records,
      devices: deviceService,
    );
    final envelope = await vault.encryptRecord(
      id: VaultRecordId('host:1'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"secret.example.test"}'),
    );
    await records.upsert(envelope);

    final provider = LocalDirectorySyncProvider(tempDir);
    final result = await service.pushEncryptedSnapshot(provider);

    expect(result.recordsUploaded, 2);
    expect(result.writerDevice!.displayName, 'Ops Laptop');

    final refs = await provider.listRecordObjects(prefix: 'records/');
    expect(refs.map((ref) => ref.path), contains('records/host%3A1.json'));
    expect(
      refs.map((ref) => ref.path),
      contains(startsWith('records/sync%3Adevice%3A')),
    );

    final manifest = await provider.readManifest();
    final manifestPayload = utf8.decode(manifest!.encryptedPayload);
    expect(manifestPayload, isNot(contains('Ops Laptop')));
    expect(manifestPayload, isNot(contains('test-os')));

    final manifestEnvelope = VaultRecordEnvelope.fromJson(
      jsonDecode(manifestPayload) as Map<String, Object?>,
    );
    final manifestData =
        jsonDecode(utf8.decode(await vault.decryptRecord(manifestEnvelope)))
            as Map<String, Object?>;
    expect(
      manifestData['writerDevice'],
      containsPair('displayName', 'Ops Laptop'),
    );
  });

  test('requires unlocked vault before pushing', () async {
    await vault.lock();

    await expectLater(
      service.pushEncryptedSnapshot(LocalDirectorySyncProvider(tempDir)),
      throwsA(
        isA<SyncRunException>().having(
          (error) => error.code,
          'code',
          'sync.vault_locked',
        ),
      ),
    );
  });

  test('pull imports missing encrypted records from remote manifest', () async {
    final remoteVault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    await remoteVault.initialize(passphrase: 'passphrase');
    final remoteRecords = InMemoryVaultRecordRepository();
    final remoteService = SyncRunService(
      vault: remoteVault,
      records: remoteRecords,
    );
    final remoteEnvelope = await remoteVault.encryptRecord(
      id: VaultRecordId('host:remote'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
    );
    await remoteRecords.upsert(remoteEnvelope);

    final provider = LocalDirectorySyncProvider(tempDir);
    await remoteService.pushEncryptedSnapshot(provider);

    final localRecords = InMemoryVaultRecordRepository();
    final localService = SyncRunService(
      vault: remoteVault,
      records: localRecords,
    );
    final pull = await localService.pullEncryptedSnapshot(provider);

    expect(pull.recordsDownloaded, 1);
    expect(pull.conflicts, isEmpty);
    expect(
      (await localRecords.read(remoteEnvelope.id))!.revision,
      remoteEnvelope.revision,
    );
  });

  test('pull rejects remote manifest from another vault', () async {
    final remoteVault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    await remoteVault.initialize(passphrase: 'different passphrase');
    final remoteRecords = InMemoryVaultRecordRepository();
    final remoteService = SyncRunService(
      vault: remoteVault,
      records: remoteRecords,
    );
    final remoteEnvelope = await remoteVault.encryptRecord(
      id: VaultRecordId('host:remote'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
    );
    await remoteRecords.upsert(remoteEnvelope);

    final provider = LocalDirectorySyncProvider(tempDir);
    await remoteService.pushEncryptedSnapshot(provider);

    await expectLater(
      service.pullEncryptedSnapshot(provider),
      throwsA(
        isA<SyncRunException>().having(
          (error) => error.code,
          'code',
          'sync.remote_manifest_wrong_vault',
        ),
      ),
    );
  });

  test(
    'pull reports corrupted remote manifest as repairable invalid state',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      await provider.writeManifest(
        RemoteManifest(
          vaultId: base64Url
              .encode(vault.header!.passphraseSalt)
              .replaceAll('=', ''),
          protocolVersion: 1,
          encryptedPayload: utf8.encode('{broken'),
        ),
      );

      await expectLater(
        service.pullEncryptedSnapshot(provider),
        throwsA(
          isA<SyncRunException>().having(
            (error) => error.code,
            'code',
            'sync.remote_manifest_invalid',
          ),
        ),
      );
    },
  );

  test('pull reports conflicts without overwriting local records', () async {
    final provider = LocalDirectorySyncProvider(tempDir);
    final remoteEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:conflict'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
    );
    await records.upsert(remoteEnvelope);
    await service.pushEncryptedSnapshot(provider);

    final localEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:conflict'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"local.example.test"}'),
    );
    await records.upsert(localEnvelope);

    final pull = await service.pullEncryptedSnapshot(provider);

    expect(pull.conflicts, hasLength(1));
    expect(pull.conflicts.single.id, localEnvelope.id);
    expect(pull.conflicts.single.fieldSet, isNotNull);
    expect(
      (await records.read(localEnvelope.id))!.revision,
      localEnvelope.revision,
    );
  });

  test(
    'conflict field set exposes field merge choices for host records',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:conflict'),
        type: 'host',
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'host-1',
            'displayName': 'Ops Bastion',
            'hostname': 'ops.remote',
            'username': 'deploy',
            'port': 2222,
            'authKinds': ['password'],
            'tags': ['prod', 'bastion'],
            'trustState': 'trusted',
            'identityIds': <String>[],
            'startupCommands': ['tmux attach'],
            'jumpHostIds': <String>[],
            'groupId': null,
            'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
            'lastConnectedAt': null,
          }),
        ),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider);

      final localEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:conflict'),
        type: 'host',
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'host-1',
            'displayName': 'Ops',
            'hostname': 'ops.local',
            'username': 'root',
            'port': 22,
            'authKinds': ['password'],
            'tags': ['prod'],
            'trustState': 'trusted',
            'identityIds': <String>[],
            'startupCommands': ['pwd'],
            'jumpHostIds': <String>[],
            'groupId': null,
            'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 5, 28).toIso8601String(),
            'lastConnectedAt': null,
          }),
        ),
      );
      await records.upsert(localEnvelope);

      final pull = await service.pullEncryptedSnapshot(provider);
      final fieldSet = pull.conflicts.single.fieldSet!;

      expect(fieldSet.supportsFieldMerge, isTrue);
      expect(
        fieldSet.fields.map((field) => field.key),
        containsAll([
          'displayName',
          'hostname',
          'username',
          'port',
          'tags',
          'startupCommands',
        ]),
      );
    },
  );

  test('applyMergedRecord writes merged encrypted json locally', () async {
    final localEnvelope = await vault.encryptRecord(
      id: VaultRecordId('snippet:merge'),
      type: 'snippet',
      plaintext: utf8.encode(
        jsonEncode({
          'id': 'snippet-1',
          'name': 'Logs',
          'command': 'tail -f app.log',
          'tags': ['ops'],
          'confirmBeforeRun': true,
          'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
          'updatedAt': DateTime.utc(2026, 5, 28).toIso8601String(),
        }),
      ),
    );
    await records.upsert(localEnvelope);

    await service.applyMergedRecord(
      recordId: localEnvelope.id,
      mergedJson: {
        'id': 'snippet-1',
        'name': 'Logs prod',
        'command': 'journalctl -fu app',
        'tags': ['ops', 'prod'],
        'confirmBeforeRun': false,
        'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
      },
    );

    final updated = await records.read(localEnvelope.id);
    expect(updated, isNotNull);
    expect(updated!.revision, isNot(localEnvelope.revision));
    final json =
        jsonDecode(utf8.decode(await vault.decryptRecord(updated)))
            as Map<String, Object?>;
    expect(json['name'], 'Logs prod');
    expect(json['confirmBeforeRun'], isFalse);
  });

  test(
    'sync pulls remote additions before pushing merged encrypted snapshot',
    () async {
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:remote-only'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"remote-only.example.test"}'),
      );
      await records.upsert(remoteEnvelope);
      final provider = LocalDirectorySyncProvider(tempDir);
      await service.pushEncryptedSnapshot(provider);

      records = InMemoryVaultRecordRepository();
      service = SyncRunService(vault: vault, records: records);
      final localEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:local-only'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"local-only.example.test"}'),
      );
      await records.upsert(localEnvelope);

      final result = await service.syncEncryptedSnapshot(provider);

      expect(result.recordsDownloaded, 1);
      expect(result.recordsUploaded, 2);
      expect(await records.read(remoteEnvelope.id), isNotNull);
    },
  );

  test(
    'resolving with keepLocal overwrites conflicting remote record',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:conflict'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider);

      final localEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:conflict'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"local.example.test"}'),
      );
      await records.upsert(localEnvelope);

      final result = await service.resolveConflicts(
        provider,
        SyncConflictResolution.keepLocal,
      );

      expect(result.recordsUploaded, 1);
      final remoteObject = VaultRecordEnvelope.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(
                  const RemoteObjectRef('records/host%3Aconflict.json'),
                ),
              ),
            )
            as Map<String, Object?>,
      );
      expect(remoteObject.revision, localEnvelope.revision);
    },
  );

  test('resolving with useRemote replaces conflicting local record', () async {
    final provider = LocalDirectorySyncProvider(tempDir);
    final remoteEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:conflict'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
    );
    await records.upsert(remoteEnvelope);
    await service.pushEncryptedSnapshot(provider);

    final localEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:conflict'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"local.example.test"}'),
    );
    await records.upsert(localEnvelope);

    final result = await service.resolveConflicts(
      provider,
      SyncConflictResolution.useRemote,
    );

    expect(result.recordsDownloaded, 1);
    expect(
      (await records.read(localEnvelope.id))!.revision,
      remoteEnvelope.revision,
    );
  });

  test(
    'local tombstone prevents deleted records from being restored by pull',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:deleted'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider);

      await records.delete(remoteEnvelope.id);
      await EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ).save(
        SyncDeleteTombstone(
          targetRecordId: remoteEnvelope.id,
          targetRecordType: remoteEnvelope.type,
          deletedAt: DateTime.utc(2026, 5, 28),
        ),
      );

      final result = await service.syncEncryptedSnapshot(provider);

      expect(result.recordsUnchanged, 1);
      expect(await records.read(remoteEnvelope.id), isNull);
      final refs = await provider.listRecordObjects(prefix: 'records/');
      expect(
        refs.map((ref) => ref.path),
        isNot(contains('records/host%3Adeleted.json')),
      );
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/sync%3Atombstone%3A')),
      );
    },
  );

  test(
    'device tombstone prevents revoked remote device from being restored',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteRecords = InMemoryVaultRecordRepository();
      final remoteDeviceRepository = EncryptedSyncDeviceRepository(
        vault: vault,
        records: remoteRecords,
      );
      await remoteDeviceRepository.save(
        SyncDeviceMetadata(
          id: 'revoked-device',
          displayName: 'Revoked Device',
          platform: 'linux',
          createdAt: DateTime.utc(2026, 5, 28, 9),
          lastSeenAt: DateTime.utc(2026, 5, 28, 9),
        ),
      );
      await SyncRunService(
        vault: vault,
        records: remoteRecords,
      ).pushEncryptedSnapshot(provider);

      await EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ).save(
        SyncDeleteTombstone(
          targetRecordId: syncDeviceRecordId('revoked-device'),
          targetRecordType: EncryptedSyncDeviceRepository.recordType,
          deletedAt: DateTime.utc(2026, 5, 28, 10),
        ),
      );

      final result = await service.syncEncryptedSnapshot(provider);

      expect(result.recordsUnchanged, 1);
      expect(
        await EncryptedSyncDeviceRepository(
          vault: vault,
          records: records,
        ).read('revoked-device'),
        isNull,
      );
      final refs = await provider.listRecordObjects(prefix: 'records/');
      expect(
        refs.map((ref) => ref.path),
        isNot(contains('records/sync%3Adevice%3Arevoked-device.json')),
      );
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/sync%3Atombstone%3A')),
      );
    },
  );

  test('remote tombstone deletes matching local record during pull', () async {
    final provider = LocalDirectorySyncProvider(tempDir);
    final remoteRecords = InMemoryVaultRecordRepository();
    final remoteService = SyncRunService(vault: vault, records: remoteRecords);
    final staleEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:stale'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"stale.example.test"}'),
    );
    await remoteRecords.upsert(staleEnvelope);
    await remoteService.pushEncryptedSnapshot(provider);
    await remoteRecords.delete(staleEnvelope.id);
    await EncryptedSyncDeleteTombstoneRepository(
      vault: vault,
      records: remoteRecords,
    ).save(
      SyncDeleteTombstone(
        targetRecordId: staleEnvelope.id,
        targetRecordType: staleEnvelope.type,
        deletedAt: DateTime.utc(2026, 5, 28),
      ),
    );
    await remoteService.pushEncryptedSnapshot(provider);

    await records.upsert(staleEnvelope);
    final result = await service.pullEncryptedSnapshot(provider);

    expect(result.recordsDownloaded, 1);
    expect(await records.read(staleEnvelope.id), isNull);
  });
}
