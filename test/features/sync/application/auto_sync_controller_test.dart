import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sync/application/auto_sync_controller.dart';
import 'package:serlink/features/sync/application/sync_delete_tombstone_repository.dart';
import 'package:serlink/features/sync/application/sync_device_service.dart';
import 'package:serlink/features/sync/application/sync_record_scope.dart';
import 'package:serlink/features/sync/application/sync_settings_service.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository inner;
  late VaultRecordChangeBus changes;
  late NotifyingVaultRecordRepository repository;
  late List<VaultRecordChange> emitted;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    inner = InMemoryVaultRecordRepository();
    changes = VaultRecordChangeBus();
    emitted = [];
    changes.stream.listen(emitted.add);
    repository = NotifyingVaultRecordRepository(inner: inner, changes: changes);
  });

  tearDown(() async {
    await changes.close();
  });

  test('emits change events for syncable encrypted record writes', () async {
    final envelope = await vault.encryptRecord(
      id: VaultRecordId('host:prod'),
      type: 'host',
      plaintext: utf8.encode('encrypted host payload'),
    );

    await repository.upsert(envelope);

    expect(emitted, hasLength(1));
    expect(emitted.single.kind, VaultRecordChangeKind.upsert);
    expect(emitted.single.id, envelope.id);
    expect(emitted.single.type, 'host');
  });

  test('does not emit change events for sync device touches', () async {
    final envelope = await vault.encryptRecord(
      id: VaultRecordId('sync:device:local'),
      type: EncryptedSyncDeviceRepository.recordType,
      plaintext: utf8.encode('device metadata'),
    );

    await repository.upsert(envelope);

    expect(emitted, isEmpty);
  });

  test('does not emit change events for local iCloud sync setting', () async {
    final envelope = await vault.encryptRecord(
      id: cloudKitSyncSettingsRecordId,
      type: EncryptedSyncSettingsRepository.recordType,
      plaintext: utf8.encode(
        jsonEncode({
          'enabled': false,
          'updatedAt': DateTime.utc(2026, 6, 25).toIso8601String(),
        }),
      ),
    );

    await repository.upsert(envelope);

    expect(emitted, isEmpty);
  });

  test('emits change events for record deletes', () async {
    final envelope = await vault.encryptRecord(
      id: VaultRecordId('host:prod'),
      type: 'host',
      plaintext: utf8.encode('encrypted host payload'),
    );
    await inner.upsert(envelope);

    await repository.delete(envelope.id);

    expect(emitted, hasLength(1));
    expect(emitted.single.kind, VaultRecordChangeKind.delete);
    expect(emitted.single.id, envelope.id);
    expect(emitted.single.type, 'host');
  });

  test('does not emit change events for sync metadata deletes', () async {
    final device = await vault.encryptRecord(
      id: VaultRecordId('sync:device:local'),
      type: EncryptedSyncDeviceRepository.recordType,
      plaintext: utf8.encode('device metadata'),
    );
    final tombstone = await vault.encryptRecord(
      id: VaultRecordId('sync:tombstone:host%3Aprod'),
      type: EncryptedSyncDeleteTombstoneRepository.recordType,
      plaintext: utf8.encode('delete tombstone'),
    );
    await inner.upsert(device);
    await inner.upsert(tombstone);

    await repository.delete(device.id);
    await repository.delete(tombstone.id);

    expect(emitted, isEmpty);
  });

  test('clear emits deletes only for syncable records', () async {
    final host = await vault.encryptRecord(
      id: VaultRecordId('host:prod'),
      type: 'host',
      plaintext: utf8.encode('encrypted host payload'),
    );
    final device = await vault.encryptRecord(
      id: VaultRecordId('sync:device:local'),
      type: EncryptedSyncDeviceRepository.recordType,
      plaintext: utf8.encode('device metadata'),
    );
    await inner.upsert(host);
    await inner.upsert(device);

    await repository.clear();

    expect(emitted, hasLength(1));
    expect(emitted.single.kind, VaultRecordChangeKind.delete);
    expect(emitted.single.id, host.id);
    expect(emitted.single.type, 'host');
  });
}
