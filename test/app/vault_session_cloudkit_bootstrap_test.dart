import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/database_recovery.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/local_sync_provider.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  late Directory remoteDir;

  setUp(() async {
    remoteDir = await Directory.systemTemp.createTemp(
      'serlink-cloudkit-bootstrap-test-',
    );
  });

  tearDown(() async {
    if (await remoteDir.exists()) {
      await remoteDir.delete(recursive: true);
    }
  });

  test(
    'new Apple device adopts CloudKit vault and pulls records after unlock',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'passphrase');
      final sourceRecords = InMemoryVaultRecordRepository();
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:prod'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"prod.example.test"}'),
      );
      await sourceRecords.upsert(host);
      await SyncRunService(
        vault: sourceVault,
        records: sourceRecords,
      ).pushEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'ios',
              targetPlatform: TargetPlatform.iOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      final initial = await container.read(
        vaultSessionControllerProvider.future,
      );

      expect(initial.vaultState, VaultState.locked);
      expect(await DriftVaultHeaderStore(database).read(), isNull);
      expect(await DriftVaultRecordRepository(database).list(), isEmpty);

      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      final unlocked = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(unlocked.failureMessage, isNull);
      expect(unlocked.vaultState, VaultState.unlocked);

      final targetRecords = DriftVaultRecordRepository(database);
      expect(await DriftVaultHeaderStore(database).read(), isNotNull);
      final restored = await targetRecords.read(VaultRecordId('host:prod'));
      expect(restored, isNotNull);
      expect(
        utf8.decode(
          await container
              .read(vaultSessionControllerProvider.notifier)
              .service
              .decryptRecord(restored!),
        ),
        '{"hostname":"prod.example.test"}',
      );
    },
  );

  test(
    'CloudKit bootstrap failure does not persist a partial local vault',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'passphrase');
      final sourceRecords = InMemoryVaultRecordRepository();
      final firstHost = await sourceVault.encryptRecord(
        id: VaultRecordId('host:first'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"first.example.test"}'),
      );
      final missingHost = await sourceVault.encryptRecord(
        id: VaultRecordId('host:missing'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"missing.example.test"}'),
      );
      await sourceRecords.upsert(firstHost);
      await sourceRecords.upsert(missingHost);
      final provider = LocalDirectorySyncProvider(remoteDir);
      await SyncRunService(
        vault: sourceVault,
        records: sourceRecords,
      ).pushEncryptedSnapshot(provider);
      await provider.deleteObject(
        const RemoteObjectRef('records/host%3Amissing.json'),
      );

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'ios',
              targetPlatform: TargetPlatform.iOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      final initial = await container.read(
        vaultSessionControllerProvider.future,
      );

      expect(initial.vaultState, VaultState.locked);
      expect(await DriftVaultHeaderStore(database).read(), isNull);

      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      final failed = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(failed.vaultState, VaultState.locked);
      expect(
        failed.failureMessage,
        'Remote sync record is invalid or corrupted.',
      );
      expect(await DriftVaultHeaderStore(database).read(), isNull);
      expect(await DriftVaultRecordRepository(database).list(), isEmpty);
    },
  );

  test(
    'CloudKit header corruption is reported as remote recovery state',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'passphrase');
      final sourceRecords = InMemoryVaultRecordRepository();
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:corrupt-header'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"corrupt.example.test"}'),
      );
      await sourceRecords.upsert(host);
      final provider = LocalDirectorySyncProvider(remoteDir);
      await SyncRunService(
        vault: sourceVault,
        records: sourceRecords,
      ).pushEncryptedSnapshot(provider);
      await provider.deleteObject(const RemoteObjectRef('vault/header.json'));

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'ios',
              targetPlatform: TargetPlatform.iOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      final state = await container.read(vaultSessionControllerProvider.future);

      expect(state.vaultState, VaultState.locked);
      expect(state.recoveryStatus, VaultRecoveryStatus.remoteCorrupt);
      expect(state.failureMessage, 'Remote vault header is missing.');
    },
  );

  test(
    'new Apple device stays uninitialized when CloudKit has no vault',
    () async {
      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'ios',
              targetPlatform: TargetPlatform.iOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      final initial = await container.read(
        vaultSessionControllerProvider.future,
      );

      expect(initial.vaultState, VaultState.uninitialized);
      expect(await DriftVaultHeaderStore(database).read(), isNull);
    },
  );
}
