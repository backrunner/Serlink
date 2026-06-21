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

    final manifest = await provider.readManifest();
    expect(manifest, isNotNull);
    expect(manifest!.headerPath, startsWith('vault/headers/'));
    expect(
      manifest.snapshotObjectPaths,
      containsAll([startsWith('records/host%3A1-'), manifest.headerPath!]),
    );

    final refs = await provider.listRecordObjects();
    expect([
      for (final ref in refs) ref.path,
    ], containsAll([startsWith('records/host%3A1-'), manifest.headerPath!]));

    final remoteRecord = utf8.decode(
      await provider.readObject(
        await _manifestRecordRef(
          provider: provider,
          vault: vault,
          id: VaultRecordId('host:1'),
        ),
      ),
    );
    expect(remoteRecord, isNot(contains('secret.example.test')));

    final remoteHeader = VaultHeader.fromJson(
      jsonDecode(
            utf8.decode(
              await provider.readObject(RemoteObjectRef(manifest.headerPath!)),
            ),
          )
          as Map<String, Object?>,
    );
    expect(remoteHeader.localUnlockProtectors, isEmpty);

    final manifestPayload = utf8.decode(manifest.encryptedPayload);
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
    expect(
      refs.map((ref) => ref.path),
      contains(startsWith('records/host%3A1-')),
    );
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

  test(
    'reset does not publish a CloudKit marker when the synced vault is absent',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);

      await service.publishRemoteReset(provider);

      await expectLater(
        provider.readObject(resetMarkerRef),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            'sync.provider.not_found',
          ),
        ),
      );
      expect(await provider.readManifest(), isNull);
    },
  );

  test(
    'reset publishes a CloudKit marker only after a synced vault exists',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final envelope = await vault.encryptRecord(
        id: VaultRecordId('host:reset-target'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"reset.example.test"}'),
      );
      await records.upsert(envelope);
      await service.pushEncryptedSnapshot(provider);

      await service.publishRemoteReset(provider);

      final marker = RemoteResetMarker.fromBytes(
        await provider.readObject(resetMarkerRef),
      );
      expect(marker.vaultId, syncVaultId(vault.header!));
    },
  );

  test('rejects repair push when local data is unhealthy', () async {
    service = SyncRunService(
      vault: vault,
      records: records,
      localDataHealthy: () async => false,
    );

    await expectLater(
      service.pushEncryptedSnapshotForRepair(
        LocalDirectorySyncProvider(tempDir),
      ),
      throwsA(
        isA<SyncRunException>().having(
          (error) => error.code,
          'code',
          'sync.local_unhealthy',
        ),
      ),
    );
  });

  test(
    'repair restore pulls remote snapshot even when local data is unhealthy',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:restore'),
        type: 'host',
        plaintext: utf8.encode('remote'),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider);

      records = InMemoryVaultRecordRepository();
      final localEnvelope = await vault.encryptRecord(
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode('local'),
      );
      await records.upsert(localEnvelope);
      service = SyncRunService(
        vault: vault,
        records: records,
        localDataHealthy: () async => false,
      );

      final result = await service.restoreLocalFromRemoteForRepair(provider);

      expect(result.recordsDownloaded, 1);
      final restored = await records.read(remoteEnvelope.id);
      expect(restored!.revision, remoteEnvelope.revision);
      expect(utf8.decode(await vault.decryptRecord(restored)), 'remote');
    },
  );

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

  test(
    'pull maps malformed manifest record entries to remote corruption',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final manifestEnvelope = await vault.encryptRecord(
        id: VaultRecordId('sync:manifest'),
        type: 'sync_manifest',
        plaintext: utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'createdAt': DateTime.utc(2026, 5, 29).toIso8601String(),
            'headerPath': 'vault/header.json',
            'records': ['not-a-record-entry'],
          }),
        ),
      );
      await provider.writeManifest(
        RemoteManifest(
          vaultId: base64Url
              .encode(vault.header!.passphraseSalt)
              .replaceAll('=', ''),
          protocolVersion: 1,
          encryptedPayload: utf8.encode(jsonEncode(manifestEnvelope.toJson())),
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

  test('pull can still report conflicts for manual review', () async {
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

    final pull = await service.pullEncryptedSnapshot(
      provider,
      reportConflicts: true,
    );

    expect(pull.conflicts, hasLength(1));
    expect(pull.conflicts.single.id, localEnvelope.id);
    expect(pull.conflicts.single.fieldSet, isNotNull);
    expect(
      (await records.read(localEnvelope.id))!.revision,
      localEnvelope.revision,
    );
  });

  test(
    'sync reports same-record conflicts without overwriting unlocked local data',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:auto-conflict'),
        type: 'host',
        plaintext: utf8.encode(
          jsonEncode({
            'hostname': 'remote.example.test',
            'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
          }),
        ),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider);

      final localEnvelope = await vault.encryptRecord(
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode(
          jsonEncode({
            'hostname': 'local.example.test',
            'updatedAt': DateTime.utc(2026, 5, 30).toIso8601String(),
          }),
        ),
      );
      await records.upsert(localEnvelope);

      await expectLater(
        service.syncEncryptedSnapshot(provider, reportConflicts: true),
        throwsA(
          isA<SyncRunConflictException>().having(
            (error) => error.conflicts.single.id,
            'conflict id',
            localEnvelope.id,
          ),
        ),
      );
      expect(vault.state, VaultState.unlocked);
      expect(
        (await records.read(localEnvelope.id))!.revision,
        localEnvelope.revision,
      );
      final remoteObject = VaultRecordEnvelope.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(
                  await _manifestRecordRef(
                    provider: provider,
                    vault: vault,
                    id: remoteEnvelope.id,
                  ),
                ),
              ),
            )
            as Map<String, Object?>,
      );
      expect(remoteObject.revision, remoteEnvelope.revision);
    },
  );

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

      final pull = await service.pullEncryptedSnapshot(
        provider,
        reportConflicts: true,
      );
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

  test('sync automatically keeps the newest remote record', () async {
    final provider = LocalDirectorySyncProvider(tempDir);
    final remoteEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:latest'),
      type: 'host',
      plaintext: utf8.encode(
        jsonEncode({
          'hostname': 'remote.example.test',
          'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
        }),
      ),
    );
    await records.upsert(remoteEnvelope);
    await service.pushEncryptedSnapshot(provider);

    final localEnvelope = await vault.encryptRecord(
      id: remoteEnvelope.id,
      type: remoteEnvelope.type,
      plaintext: utf8.encode(
        jsonEncode({
          'hostname': 'local.example.test',
          'updatedAt': DateTime.utc(2026, 5, 28).toIso8601String(),
        }),
      ),
    );
    await records.upsert(localEnvelope);

    final result = await service.syncEncryptedSnapshot(provider);

    expect(result.recordsDownloaded, 1);
    final restored = await records.read(remoteEnvelope.id);
    expect(restored!.revision, remoteEnvelope.revision);
    final restoredJson =
        jsonDecode(utf8.decode(await vault.decryptRecord(restored)))
            as Map<String, Object?>;
    expect(restoredJson['hostname'], 'remote.example.test');
  });

  test('sync automatically keeps the newest local record', () async {
    final provider = LocalDirectorySyncProvider(tempDir);
    final remoteEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:latest'),
      type: 'host',
      plaintext: utf8.encode(
        jsonEncode({
          'hostname': 'remote.example.test',
          'updatedAt': DateTime.utc(2026, 5, 28).toIso8601String(),
        }),
      ),
    );
    await records.upsert(remoteEnvelope);
    await service.pushEncryptedSnapshot(provider);

    final localEnvelope = await vault.encryptRecord(
      id: remoteEnvelope.id,
      type: remoteEnvelope.type,
      plaintext: utf8.encode(
        jsonEncode({
          'hostname': 'local.example.test',
          'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
        }),
      ),
    );
    await records.upsert(localEnvelope);

    final result = await service.syncEncryptedSnapshot(provider);

    expect(result.recordsDownloaded, 0);
    expect(
      (await records.read(localEnvelope.id))!.revision,
      localEnvelope.revision,
    );
    final remoteObject = VaultRecordEnvelope.fromJson(
      jsonDecode(
            utf8.decode(
              await provider.readObject(
                await _manifestRecordRef(
                  provider: provider,
                  vault: vault,
                  id: localEnvelope.id,
                ),
              ),
            ),
          )
          as Map<String, Object?>,
    );
    expect(remoteObject.revision, localEnvelope.revision);
  });

  test('sync auto-resolves sync device metadata conflicts', () async {
    final provider = LocalDirectorySyncProvider(tempDir);
    final remoteEnvelope = await vault.encryptRecord(
      id: syncDeviceRecordId('device-1'),
      type: EncryptedSyncDeviceRepository.recordType,
      plaintext: utf8.encode(
        jsonEncode({
          'id': 'device-1',
          'displayName': 'Remote Mac',
          'platform': 'macos',
          'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
          'lastSeenAt': DateTime.utc(2026, 5, 29).toIso8601String(),
        }),
      ),
    );
    await records.upsert(remoteEnvelope);
    await service.pushEncryptedSnapshot(provider);

    final localEnvelope = await vault.encryptRecord(
      id: remoteEnvelope.id,
      type: remoteEnvelope.type,
      plaintext: utf8.encode(
        jsonEncode({
          'id': 'device-1',
          'displayName': 'Local Mac',
          'platform': 'macos',
          'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
          'lastSeenAt': DateTime.utc(2026, 5, 28).toIso8601String(),
        }),
      ),
    );
    await records.upsert(localEnvelope);

    final result = await service.syncEncryptedSnapshot(
      provider,
      reportConflicts: true,
    );

    expect(result.recordsDownloaded, 1);
    final restored = await records.read(remoteEnvelope.id);
    expect(restored!.revision, remoteEnvelope.revision);
    final restoredJson =
        jsonDecode(utf8.decode(await vault.decryptRecord(restored)))
            as Map<String, Object?>;
    expect(restoredJson['displayName'], 'Remote Mac');
  });

  test(
    'sync keeps newest local identity secret using related identity timestamp',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteIdentity = await vault.encryptRecord(
        id: VaultRecordId('identity:linked-secret'),
        type: 'identity',
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'linked-secret',
            'displayName': 'Remote Key',
            'kind': 'privateKey',
            'secretRecordId': 'secret:linked-secret',
            'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 5, 28).toIso8601String(),
          }),
        ),
      );
      final remoteSecret = await vault.encryptRecord(
        id: VaultRecordId('secret:linked-secret'),
        type: 'identity_secret',
        plaintext: utf8.encode(
          jsonEncode({
            'password': 'remote-secret',
            'privateKeyPem': null,
            'privateKeyPassphrase': null,
            'openSshCertificate': null,
            'keyboardInteractiveResponses': <String>[],
          }),
        ),
      );
      await records.upsert(remoteIdentity);
      await records.upsert(remoteSecret);
      await service.pushEncryptedSnapshot(provider);

      final localIdentity = await vault.encryptRecord(
        id: remoteIdentity.id,
        type: remoteIdentity.type,
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'linked-secret',
            'displayName': 'Local Key',
            'kind': 'privateKey',
            'secretRecordId': 'secret:linked-secret',
            'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
          }),
        ),
      );
      final localSecret = await vault.encryptRecord(
        id: remoteSecret.id,
        type: remoteSecret.type,
        plaintext: utf8.encode(
          jsonEncode({
            'password': 'local-secret',
            'privateKeyPem': null,
            'privateKeyPassphrase': null,
            'openSshCertificate': null,
            'keyboardInteractiveResponses': <String>[],
          }),
        ),
      );
      await records.upsert(localIdentity);
      await records.upsert(localSecret);

      final result = await service.syncEncryptedSnapshot(provider);

      expect(result.recordsDownloaded, 0);
      expect(
        (await records.read(localIdentity.id))!.revision,
        localIdentity.revision,
      );
      expect(
        (await records.read(localSecret.id))!.revision,
        localSecret.revision,
      );
      final remoteSecretObject = VaultRecordEnvelope.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(
                  await _manifestRecordRef(
                    provider: provider,
                    vault: vault,
                    id: localSecret.id,
                  ),
                ),
              ),
            )
            as Map<String, Object?>,
      );
      expect(remoteSecretObject.revision, localSecret.revision);
    },
  );

  test(
    'applyMergedConflicts writes merged record and pushes it atomically',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('snippet:merge'),
        type: 'snippet',
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'snippet-1',
            'name': 'Logs',
            'command': 'journalctl -fu app',
            'tags': ['ops'],
            'confirmBeforeRun': false,
            'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
          }),
        ),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider);

      final localEnvelope = await vault.encryptRecord(
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'snippet-1',
            'name': 'Logs local',
            'command': 'tail -f app.log',
            'tags': ['ops'],
            'confirmBeforeRun': true,
            'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 5, 30).toIso8601String(),
          }),
        ),
      );
      await records.upsert(localEnvelope);

      final pull = await service.pullEncryptedSnapshot(
        provider,
        reportConflicts: true,
      );
      final conflict = pull.conflicts.single;

      final result = await service.applyMergedConflicts(
        provider,
        merges: [
          SyncMergedConflict(
            conflict: conflict,
            mergedJson: {
              'id': 'snippet-1',
              'name': 'Logs local',
              'command': 'journalctl -fu app',
              'tags': ['ops'],
              'confirmBeforeRun': false,
              'createdAt': DateTime.utc(2026, 5, 28).toIso8601String(),
              'updatedAt': DateTime.utc(2026, 5, 30).toIso8601String(),
            },
          ),
        ],
      );

      expect(result.recordsUploaded, 1);
      expect(vault.state, VaultState.unlocked);
      final updated = await records.read(localEnvelope.id);
      expect(updated, isNotNull);
      expect(updated!.revision, isNot(localEnvelope.revision));
      final json =
          jsonDecode(utf8.decode(await vault.decryptRecord(updated)))
              as Map<String, Object?>;
      expect(json['name'], 'Logs local');
      expect(json['command'], 'journalctl -fu app');
      expect(json['confirmBeforeRun'], isFalse);
      final remoteObject = VaultRecordEnvelope.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(
                  await _manifestRecordRef(
                    provider: provider,
                    vault: vault,
                    id: localEnvelope.id,
                  ),
                ),
              ),
            )
            as Map<String, Object?>,
      );
      expect(remoteObject.revision, updated.revision);
    },
  );

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
      expect(vault.state, VaultState.unlocked);
    },
  );

  test(
    'sync does not push again when local and remote snapshots match',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final envelope = await vault.encryptRecord(
        id: VaultRecordId('host:unchanged'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"unchanged.example.test"}'),
      );
      await records.upsert(envelope);
      await service.pushEncryptedSnapshot(provider);
      final before = await provider.readManifest();

      final result = await service.syncEncryptedSnapshot(provider);

      final after = await provider.readManifest();
      expect(result.recordsUploaded, 0);
      expect(result.headerUploaded, isFalse);
      expect(after!.encryptedPayload, before!.encryptedPayload);
      expect(after.headerPath, before.headerPath);
    },
  );

  test(
    'sync registers this device before treating a snapshot as unchanged',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final envelope = await vault.encryptRecord(
        id: VaultRecordId('host:unchanged-with-device'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"unchanged.example.test"}'),
      );
      await records.upsert(envelope);
      await service.pushEncryptedSnapshot(provider);

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

      final result = await service.syncEncryptedSnapshot(provider);

      expect(result.recordsUploaded, 2);
      expect(await deviceService.readLocalDevice(), isNotNull);
      final refs = await provider.listRecordObjects(prefix: 'records/');
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/sync%3Adevice%3A')),
      );
    },
  );

  test(
    'sync retries a conditional manifest conflict and merges concurrent remote additions',
    () async {
      final provider = _ManifestConflictProvider(
        LocalDirectorySyncProvider(tempDir),
      );
      final baseEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:base'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"base.example.test"}'),
      );
      await records.upsert(baseEnvelope);
      await service.pushEncryptedSnapshot(provider.inner);

      final remoteRecords = InMemoryVaultRecordRepository();
      await remoteRecords.upsert(baseEnvelope);
      final concurrentRemote = await vault.encryptRecord(
        id: VaultRecordId('host:concurrent-remote'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"remote-new.example.test"}'),
      );
      await remoteRecords.upsert(concurrentRemote);

      final localEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:local-new'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"local-new.example.test"}'),
      );
      await records.upsert(localEnvelope);
      provider.onFirstManifestConflict = () async {
        await SyncRunService(
          vault: vault,
          records: remoteRecords,
        ).pushEncryptedSnapshot(provider.inner);
      };

      final result = await service.syncEncryptedSnapshot(provider);

      expect(result.recordsDownloaded, 1);
      expect(await records.read(concurrentRemote.id), isNotNull);
      expect(await records.read(localEnvelope.id), isNotNull);
      final refs = await provider.inner.listRecordObjects(prefix: 'records/');
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/host%3Aconcurrent-remote-')),
      );
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/host%3Alocal-new-')),
      );
    },
  );

  test(
    'merged conflict resolution rolls back local merge when push conflict remains',
    () async {
      final provider = _ManifestConflictProvider(
        LocalDirectorySyncProvider(tempDir),
      );
      provider.alwaysConflict = true;
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('snippet:merge-conflict'),
        type: 'snippet',
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'snippet-1',
            'name': 'Remote',
            'command': 'journalctl -fu app',
            'tags': ['ops'],
            'confirmBeforeRun': false,
            'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
          }),
        ),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider.inner);

      final localEnvelope = await vault.encryptRecord(
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode(
          jsonEncode({
            'id': 'snippet-1',
            'name': 'Local',
            'command': 'tail -f app.log',
            'tags': ['ops'],
            'confirmBeforeRun': true,
            'updatedAt': DateTime.utc(2026, 5, 30).toIso8601String(),
          }),
        ),
      );
      await records.upsert(localEnvelope);
      final pull = await service.pullEncryptedSnapshot(
        provider.inner,
        reportConflicts: true,
      );

      await expectLater(
        service.applyMergedConflicts(
          provider,
          merges: [
            SyncMergedConflict(
              conflict: pull.conflicts.single,
              mergedJson: {
                'id': 'snippet-1',
                'name': 'Merged',
                'command': 'journalctl -fu app',
                'tags': ['ops'],
                'confirmBeforeRun': false,
                'updatedAt': DateTime.utc(2026, 5, 30).toIso8601String(),
              },
            ),
          ],
        ),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            'sync.provider.conflict',
          ),
        ),
      );

      final preserved = await records.read(localEnvelope.id);
      expect(preserved!.revision, localEnvelope.revision);
      final json =
          jsonDecode(utf8.decode(await vault.decryptRecord(preserved)))
              as Map<String, Object?>;
      expect(json['name'], 'Local');
      expect(json['command'], 'tail -f app.log');
      expect(json['confirmBeforeRun'], isTrue);
    },
  );

  test(
    'initial publish keeps manifest conflict visible when cleanup fails',
    () async {
      final provider = _FailingCleanupProvider(
        LocalDirectorySyncProvider(tempDir),
      );
      final envelope = await vault.encryptRecord(
        id: VaultRecordId('host:initial'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"initial.example.test"}'),
      );
      await records.upsert(envelope);

      await expectLater(
        service.publishInitialEncryptedSnapshot(provider),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            'sync.provider.conflict',
          ),
        ),
      );

      expect(provider.deleteAttempts, isPositive);
    },
  );

  test(
    'push prunes only records referenced by the previous manifest',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final initialEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:prune'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"initial.example.test"}'),
      );
      await records.upsert(initialEnvelope);
      await service.pushEncryptedSnapshot(provider);

      final staleRecordRef = await _manifestRecordRef(
        provider: provider,
        vault: vault,
        id: initialEnvelope.id,
      );
      await provider.writeObject(
        const RemoteObjectRef('records/host%3Aorphan-inflight.json'),
        utf8.encode('{"orphan":true}'),
      );

      final updatedEnvelope = await vault.encryptRecord(
        id: initialEnvelope.id,
        type: initialEnvelope.type,
        plaintext: utf8.encode('{"hostname":"updated.example.test"}'),
      );
      await records.upsert(updatedEnvelope);

      final result = await service.pushEncryptedSnapshot(provider);

      expect(result.recordsUploaded, 1);
      await expectLater(
        provider.readObject(staleRecordRef),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            'sync.provider.not_found',
          ),
        ),
      );
      expect(
        await provider.readObject(
          const RemoteObjectRef('records/host%3Aorphan-inflight.json'),
        ),
        utf8.encode('{"orphan":true}'),
      );
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

      final pull = await service.pullEncryptedSnapshot(
        provider,
        reportConflicts: true,
      );

      final result = await service.resolveConflicts(
        provider,
        SyncConflictResolution.keepLocal,
        acceptedConflicts: pull.conflicts,
      );

      expect(result.recordsUploaded, 1);
      final remoteObject = VaultRecordEnvelope.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(
                  await _manifestRecordRef(
                    provider: provider,
                    vault: vault,
                    id: localEnvelope.id,
                  ),
                ),
              ),
            )
            as Map<String, Object?>,
      );
      expect(remoteObject.revision, localEnvelope.revision);
    },
  );

  test(
    'keepLocal requires explicit acceptance before overwriting remote conflicts',
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
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode('{"hostname":"local.example.test"}'),
      );
      await records.upsert(localEnvelope);

      await expectLater(
        service.resolveConflicts(provider, SyncConflictResolution.keepLocal),
        throwsA(
          isA<SyncRunConflictException>()
              .having((error) => error.conflicts, 'conflicts', hasLength(1))
              .having(
                (error) => error.conflicts.single.remoteRevision,
                'remote revision',
                remoteEnvelope.revision,
              ),
        ),
      );

      final remoteObject = VaultRecordEnvelope.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(
                  await _manifestRecordRef(
                    provider: provider,
                    vault: vault,
                    id: remoteEnvelope.id,
                  ),
                ),
              ),
            )
            as Map<String, Object?>,
      );
      expect(remoteObject.revision, remoteEnvelope.revision);
      expect(
        (await records.read(localEnvelope.id))!.revision,
        localEnvelope.revision,
      );
    },
  );

  test(
    'keepLocal rejects stale accepted conflicts after remote revision changes',
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
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode('{"hostname":"local.example.test"}'),
      );
      await records.upsert(localEnvelope);
      final accepted = await service.pullEncryptedSnapshot(
        provider,
        reportConflicts: true,
      );
      expect(accepted.conflicts, hasLength(1));

      final remoteRecords = InMemoryVaultRecordRepository();
      final newerRemoteEnvelope = await vault.encryptRecord(
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode('{"hostname":"newer-remote.example.test"}'),
      );
      await remoteRecords.upsert(newerRemoteEnvelope);
      await SyncRunService(
        vault: vault,
        records: remoteRecords,
      ).pushEncryptedSnapshot(provider);

      await expectLater(
        service.resolveConflicts(
          provider,
          SyncConflictResolution.keepLocal,
          acceptedConflicts: accepted.conflicts,
        ),
        throwsA(
          isA<SyncRunConflictException>()
              .having((error) => error.conflicts, 'conflicts', hasLength(1))
              .having(
                (error) => error.conflicts.single.remoteRevision,
                'remote revision',
                newerRemoteEnvelope.revision,
              ),
        ),
      );

      final remoteObject = VaultRecordEnvelope.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(
                  await _manifestRecordRef(
                    provider: provider,
                    vault: vault,
                    id: remoteEnvelope.id,
                  ),
                ),
              ),
            )
            as Map<String, Object?>,
      );
      expect(remoteObject.revision, newerRemoteEnvelope.revision);
      expect(
        (await records.read(localEnvelope.id))!.revision,
        localEnvelope.revision,
      );
    },
  );

  test(
    'keepLocal conflict resolution preserves concurrent remote additions',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:conflict'),
        type: 'host',
        plaintext: utf8.encode(
          jsonEncode({
            'hostname': 'remote.example.test',
            'updatedAt': DateTime.utc(2026, 5, 28).toIso8601String(),
          }),
        ),
      );
      await records.upsert(remoteEnvelope);
      await service.pushEncryptedSnapshot(provider);

      final localEnvelope = await vault.encryptRecord(
        id: remoteEnvelope.id,
        type: remoteEnvelope.type,
        plaintext: utf8.encode(
          jsonEncode({
            'hostname': 'local.example.test',
            'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
          }),
        ),
      );
      await records.upsert(localEnvelope);

      final pull = await service.pullEncryptedSnapshot(
        provider,
        reportConflicts: true,
      );
      expect(pull.conflicts, hasLength(1));

      final remoteRecords = InMemoryVaultRecordRepository();
      await remoteRecords.upsert(remoteEnvelope);
      final remoteAddition = await vault.encryptRecord(
        id: VaultRecordId('host:remote-new'),
        type: 'host',
        plaintext: utf8.encode(
          jsonEncode({
            'hostname': 'remote-new.example.test',
            'updatedAt': DateTime.utc(2026, 5, 30).toIso8601String(),
          }),
        ),
      );
      await remoteRecords.upsert(remoteAddition);
      await SyncRunService(
        vault: vault,
        records: remoteRecords,
      ).pushEncryptedSnapshot(provider);

      final result = await service.resolveConflicts(
        provider,
        SyncConflictResolution.keepLocal,
        acceptedConflicts: pull.conflicts,
      );

      expect(result.recordsDownloaded, 1);
      expect(await records.read(remoteAddition.id), isNotNull);
      expect(
        (await records.read(localEnvelope.id))!.revision,
        localEnvelope.revision,
      );
      final refs = await provider.listRecordObjects(prefix: 'records/');
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/host%3Aremote-new-')),
      );
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/host%3Aconflict-')),
      );
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
        isNot(contains(startsWith('records/host%3Adeleted-'))),
      );
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/sync%3Atombstone%3A')),
      );
    },
  );

  test(
    'newer remote record restores a locally deleted record and clears tombstone',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final remoteEnvelope = await vault.encryptRecord(
        id: VaultRecordId('host:deleted-newer-remote'),
        type: 'host',
        plaintext: utf8.encode(
          jsonEncode({
            'hostname': 'remote-newer.example.test',
            'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
          }),
        ),
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

      expect(result.recordsDownloaded, 1);
      final restored = await records.read(remoteEnvelope.id);
      expect(restored, isNotNull);
      expect(
        utf8.decode(await vault.decryptRecord(restored!)),
        contains('remote-newer'),
      );
      final refs = await provider.listRecordObjects(prefix: 'records/');
      expect(
        refs.map((ref) => ref.path),
        contains(startsWith('records/host%3Adeleted-newer-remote-')),
      );
      expect(
        refs.map((ref) => ref.path),
        isNot(contains(startsWith('records/sync%3Atombstone%3A'))),
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
        isNot(contains(startsWith('records/sync%3Adevice%3Arevoked-device-'))),
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

  test('newer local record survives an older remote tombstone', () async {
    final provider = LocalDirectorySyncProvider(tempDir);
    final remoteRecords = InMemoryVaultRecordRepository();
    final remoteService = SyncRunService(vault: vault, records: remoteRecords);
    final staleEnvelope = await vault.encryptRecord(
      id: VaultRecordId('host:survives'),
      type: 'host',
      plaintext: utf8.encode(
        jsonEncode({
          'hostname': 'stale.example.test',
          'updatedAt': DateTime.utc(2026, 5, 27).toIso8601String(),
        }),
      ),
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

    final localEnvelope = await vault.encryptRecord(
      id: staleEnvelope.id,
      type: staleEnvelope.type,
      plaintext: utf8.encode(
        jsonEncode({
          'hostname': 'local-newer.example.test',
          'updatedAt': DateTime.utc(2026, 5, 29).toIso8601String(),
        }),
      ),
    );
    await records.upsert(localEnvelope);

    final result = await service.syncEncryptedSnapshot(provider);

    expect(result.recordsDownloaded, 1);
    final preserved = await records.read(staleEnvelope.id);
    expect(preserved!.revision, localEnvelope.revision);
    final refs = await provider.listRecordObjects(prefix: 'records/');
    expect(
      refs.map((ref) => ref.path),
      contains(startsWith('records/host%3Asurvives-')),
    );
    expect(
      refs.map((ref) => ref.path),
      isNot(contains(startsWith('records/sync%3Atombstone%3A'))),
    );
  });
}

Future<RemoteObjectRef> _manifestRecordRef({
  required LocalDirectorySyncProvider provider,
  required InMemoryVaultService vault,
  required VaultRecordId id,
}) async {
  final manifest = await provider.readManifest();
  expect(manifest, isNotNull);
  final manifestEnvelope = VaultRecordEnvelope.fromJson(
    jsonDecode(utf8.decode(manifest!.encryptedPayload)) as Map<String, Object?>,
  );
  final manifestData =
      jsonDecode(utf8.decode(await vault.decryptRecord(manifestEnvelope)))
          as Map<String, Object?>;
  final entries = manifestData['records'] as List<Object?>;
  for (final raw in entries) {
    final entry = raw as Map<String, Object?>;
    if (entry['id'] == id.value) {
      return RemoteObjectRef(entry['path'] as String);
    }
  }
  fail('Manifest did not contain ${id.value}');
}

class _ManifestConflictProvider implements SyncProvider {
  _ManifestConflictProvider(this.inner);

  final LocalDirectorySyncProvider inner;
  Future<void> Function()? onFirstManifestConflict;
  var alwaysConflict = false;
  var _conflicted = false;

  @override
  Future<ProviderCapabilities> capabilities() {
    return inner.capabilities();
  }

  @override
  Future<RemoteManifest?> readManifest() {
    return inner.readManifest();
  }

  @override
  Future<void> writeManifest(RemoteManifest manifest) {
    return inner.writeManifest(manifest);
  }

  @override
  Future<void> writeManifestIfUnchanged(
    RemoteManifest manifest,
    RemoteManifest? expectedCurrent,
  ) async {
    if (alwaysConflict) {
      throw const SyncProviderException(
        'sync.provider.conflict',
        'Remote sync data changed while syncing.',
      );
    }
    if (!_conflicted && onFirstManifestConflict != null) {
      _conflicted = true;
      await onFirstManifestConflict!();
    }
    final current = await inner.readManifest();
    if (!_sameManifest(current, expectedCurrent)) {
      throw const SyncProviderException(
        'sync.provider.conflict',
        'Remote sync data changed while syncing.',
      );
    }
    await inner.writeManifest(manifest);
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) {
    return inner.listRecordObjects(prefix: prefix);
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) {
    return inner.readObject(ref);
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) {
    return inner.writeObject(ref, bytes);
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) {
    return inner.deleteObject(ref);
  }
}

class _FailingCleanupProvider implements SyncProvider {
  _FailingCleanupProvider(this.inner);

  final LocalDirectorySyncProvider inner;
  var deleteAttempts = 0;

  @override
  Future<ProviderCapabilities> capabilities() {
    return inner.capabilities();
  }

  @override
  Future<RemoteManifest?> readManifest() {
    return inner.readManifest();
  }

  @override
  Future<void> writeManifest(RemoteManifest manifest) {
    return inner.writeManifest(manifest);
  }

  @override
  Future<void> writeManifestIfUnchanged(
    RemoteManifest manifest,
    RemoteManifest? expectedCurrent,
  ) async {
    throw const SyncProviderException(
      'sync.provider.conflict',
      'Remote sync data changed while syncing.',
    );
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) {
    return inner.listRecordObjects(prefix: prefix);
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) {
    return inner.readObject(ref);
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) {
    return inner.writeObject(ref, bytes);
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {
    deleteAttempts += 1;
    throw const SyncProviderException(
      'sync.provider.cleanup_failed',
      'Cleanup failed.',
    );
  }
}

bool _sameManifest(RemoteManifest? a, RemoteManifest? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return a.vaultId == b.vaultId &&
      a.protocolVersion == b.protocolVersion &&
      a.headerPath == b.headerPath &&
      _sameBytes(a.encryptedPayload, b.encryptedPayload);
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
