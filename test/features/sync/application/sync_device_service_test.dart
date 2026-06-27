import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sync/application/sync_delete_tombstone_repository.dart';
import 'package:serlink/features/sync/application/sync_device_service.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/secret_store.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late InMemorySecretStore secrets;
  late SyncDeviceService service;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    records = InMemoryVaultRecordRepository();
    secrets = InMemorySecretStore();
    service = SyncDeviceService(
      devices: EncryptedSyncDeviceRepository(vault: vault, records: records),
      secrets: secrets,
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      displayName: 'Ops Laptop',
      platform: 'test-os',
      now: () => DateTime.utc(2026, 5, 27, 10),
    );
  });

  test('registers local sync device as encrypted vault record', () async {
    final device = await service.touchLocalDevice();

    expect(device.displayName, 'Ops Laptop');
    expect(device.platform, 'test-os');

    final storedId = await secrets.read(const SecretRef('sync:device:id'));
    expect(utf8.decode(storedId!), device.id);

    final envelopes = await records.list(
      type: EncryptedSyncDeviceRepository.recordType,
    );
    expect(envelopes, hasLength(1));
    final serializedEnvelope = jsonEncode(envelopes.single.toJson());
    expect(serializedEnvelope, isNot(contains('Ops Laptop')));
    expect(serializedEnvelope, isNot(contains('test-os')));
  });

  test('uses resolved local device name for sync registration', () async {
    service = SyncDeviceService(
      devices: EncryptedSyncDeviceRepository(vault: vault, records: records),
      secrets: secrets,
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      displayNameResolver: () async => 'Orchi iPhone',
      fallbackHostname: () => 'localhost',
      platform: 'ios',
      now: () => DateTime.utc(2026, 5, 27, 10),
    );

    final device = await service.touchLocalDevice();

    expect(device.displayName, 'Orchi iPhone');
    expect(device.displayName, isNot('localhost'));
  });

  test('does not store localhost as sync device name', () async {
    service = SyncDeviceService(
      devices: EncryptedSyncDeviceRepository(vault: vault, records: records),
      secrets: secrets,
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      displayNameResolver: () async => 'localhost',
      fallbackHostname: () => 'localhost',
      platform: 'ios',
      now: () => DateTime.utc(2026, 5, 27, 10),
    );

    final device = await service.touchLocalDevice();

    expect(device.displayName, 'This device');
    expect(device.displayName, isNot('localhost'));
  });

  test('reuses local device id and updates last seen time', () async {
    final first = await service.touchLocalDevice();

    service = SyncDeviceService(
      devices: EncryptedSyncDeviceRepository(vault: vault, records: records),
      secrets: secrets,
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: vault,
        records: records,
      ),
      displayName: 'Ops Laptop',
      platform: 'test-os',
      now: () => DateTime.utc(2026, 5, 27, 11),
    );
    final second = await service.touchLocalDevice();

    expect(second.id, first.id);
    expect(second.createdAt, first.createdAt);
    expect(second.lastSeenAt, DateTime.utc(2026, 5, 27, 11));
    expect(await service.listKnownDevices(), hasLength(1));
  });

  test('revokes non-local known devices with encrypted tombstone', () async {
    await service.touchLocalDevice();
    final repository = EncryptedSyncDeviceRepository(
      vault: vault,
      records: records,
    );
    await repository.save(
      SyncDeviceMetadata(
        id: 'remote-device',
        displayName: 'Remote Desktop',
        platform: 'linux',
        createdAt: DateTime.utc(2026, 5, 27, 9),
        lastSeenAt: DateTime.utc(2026, 5, 27, 9),
      ),
    );

    await service.deleteKnownDevice('remote-device');

    final devices = await service.listKnownDevices();
    expect(
      devices.map((device) => device.id),
      isNot(contains('remote-device')),
    );

    final tombstones = await EncryptedSyncDeleteTombstoneRepository(
      vault: vault,
      records: records,
    ).list();
    expect(tombstones, hasLength(1));
    expect(
      tombstones.single.targetRecordId,
      syncDeviceRecordId('remote-device'),
    );
    expect(
      tombstones.single.targetRecordType,
      EncryptedSyncDeviceRepository.recordType,
    );
  });

  test('does not delete the current sync device', () async {
    final local = await service.touchLocalDevice();

    await expectLater(
      service.deleteKnownDevice(local.id),
      throwsA(
        isA<SyncDeviceException>().having(
          (error) => error.code,
          'code',
          'sync.device.delete_local_blocked',
        ),
      ),
    );

    expect(await service.listKnownDevices(), hasLength(1));
  });

  test('does not recreate local device after remote revocation', () async {
    final local = await service.touchLocalDevice();
    await records.delete(syncDeviceRecordId(local.id));
    await EncryptedSyncDeleteTombstoneRepository(
      vault: vault,
      records: records,
    ).save(
      SyncDeleteTombstone(
        targetRecordId: syncDeviceRecordId(local.id),
        targetRecordType: EncryptedSyncDeviceRepository.recordType,
        deletedAt: DateTime.utc(2026, 5, 27, 12),
      ),
    );

    await expectLater(
      service.touchLocalDevice(),
      throwsA(
        isA<SyncDeviceException>().having(
          (error) => error.code,
          'code',
          'sync.device.revoked',
        ),
      ),
    );

    expect(await service.listKnownDevices(), isEmpty);
  });

  test('rotates local sync device registration with tombstone', () async {
    final first = await service.touchLocalDevice();

    final rotated = await service.rotateLocalDeviceRegistration();

    expect(rotated.id, isNot(first.id));
    expect(rotated.displayName, first.displayName);
    expect(
      utf8.decode((await secrets.read(const SecretRef('sync:device:id')))!),
      rotated.id,
    );

    final devices = await service.listKnownDevices();
    expect(devices.map((device) => device.id), [rotated.id]);

    final tombstones = await EncryptedSyncDeleteTombstoneRepository(
      vault: vault,
      records: records,
    ).list();
    expect(tombstones, hasLength(1));
    expect(tombstones.single.targetRecordId, syncDeviceRecordId(first.id));
    expect(
      tombstones.single.targetRecordType,
      EncryptedSyncDeviceRepository.recordType,
    );
  });
}
