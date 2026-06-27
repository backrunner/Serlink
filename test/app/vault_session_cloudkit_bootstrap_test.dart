import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/database_recovery.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sync/application/auto_sync_controller.dart';
import 'package:serlink/features/sync/application/encrypted_snapshot_staging.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/cloudkit_sync_provider.dart';
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

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
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
      expect(initial.notice, VaultSessionNotice.cloudKitRemoteVaultAdopted);
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
      expect(
        container.read(vaultSessionControllerProvider.notifier).service.state,
        VaultState.unlocked,
      );

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
    'new Apple device reports when CloudKit vault requires a newer app',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'passphrase');
      final provider = LocalDirectorySyncProvider(remoteDir);
      await SyncRunService(
        vault: sourceVault,
        records: InMemoryVaultRecordRepository(),
      ).pushEncryptedSnapshot(provider);
      final manifest = (await provider.readManifest())!;
      await provider.writeObject(
        RemoteObjectRef(manifest.headerPath!),
        utf8.encode(
          jsonEncode(sourceVault.header!.copyWith(schemaVersion: 2).toJson()),
        ),
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
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
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
      expect(initial.failureMessage, contains('Update Serlink before syncing'));
      expect(await DriftVaultHeaderStore(database).read(), isNull);
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
        await _manifestRecordRef(
          provider: provider,
          vault: sourceVault,
          id: missingHost.id,
        ),
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
      final manifest = await provider.readManifest();
      await provider.deleteObject(RemoteObjectRef(manifest!.headerPath!));

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

  test(
    'new Apple vault immediately publishes an initial CloudKit snapshot',
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

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final state = container.read(vaultSessionControllerProvider).requireValue;
      expect(state.vaultState, VaultState.unlocked);
      expect(state.failureMessage, isNull);

      final provider = LocalDirectorySyncProvider(remoteDir);
      final manifest = await provider.readManifest();
      expect(manifest, isNotNull);
      expect(manifest!.headerPath, startsWith('vault/headers/'));
      expect(
        await provider.readObject(RemoteObjectRef(manifest.headerPath!)),
        isNotEmpty,
      );

      final counters = _CountingSyncProviderCounters();
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _CountingSyncProvider(
              LocalDirectorySyncProvider(remoteDir),
              counters,
            ),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      targetContainer.read(cloudKitEncryptedSnapshotPrefetchControllerProvider);

      final discovered = await targetContainer.read(
        vaultSessionControllerProvider.future,
      );
      expect(discovered.vaultState, VaultState.locked);
    },
  );

  test(
    'uninitialized Apple device discovers a CloudKit vault after launch',
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
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
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

      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'passphrase');
      await SyncRunService(
        vault: sourceVault,
        records: InMemoryVaultRecordRepository(),
      ).pushEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      await container
          .read(vaultSessionControllerProvider.notifier)
          .refreshCloudKitVaultDiscovery();

      final discovered = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(discovered.vaultState, VaultState.locked);
      expect(discovered.failureMessage, isNull);
      expect(discovered.notice, VaultSessionNotice.cloudKitRemoteVaultAdopted);
      expect(await DriftVaultHeaderStore(database).read(), isNull);
    },
  );

  test(
    'enabling CloudKit discovers an existing vault after local pause',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'passphrase');
      await SyncRunService(
        vault: sourceVault,
        records: InMemoryVaultRecordRepository(),
      ).pushEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await targetContainer
          .read(syncSettingsServiceProvider)
          .saveCloudKit(false);
      final initial = await targetContainer.read(
        vaultSessionControllerProvider.future,
      );
      expect(initial.vaultState, VaultState.uninitialized);

      targetContainer.read(cloudKitVaultDiscoveryControllerProvider);
      await targetContainer
          .read(syncSettingsServiceProvider)
          .saveCloudKit(true);
      targetContainer.invalidate(cloudKitSyncSettingsProvider);

      await _waitForVaultState(targetContainer, VaultState.locked);
      final discovered = targetContainer
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(discovered.notice, VaultSessionNotice.cloudKitRemoteVaultAdopted);
      expect(await DriftVaultHeaderStore(database).read(), isNull);
    },
  );

  test(
    'reset publishes a CloudKit reset marker and clears the remote vault',
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

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final provider = LocalDirectorySyncProvider(remoteDir);
      final manifest = await provider.readManifest();
      expect(manifest, isNotNull);

      final error = await container
          .read(vaultSessionControllerProvider.notifier)
          .resetVault();

      expect(error, isNull);
      expect(
        container.read(vaultSessionControllerProvider).requireValue.vaultState,
        VaultState.uninitialized,
      );
      expect(await provider.readManifest(), isNull);
      expect(await provider.listRecordObjects(prefix: 'records/'), isEmpty);
      final marker = RemoteResetMarker.fromBytes(
        await provider.readObject(resetMarkerRef),
      );
      expect(marker.vaultId, manifest!.vaultId);

      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);

      final discovered = await targetContainer.read(
        vaultSessionControllerProvider.future,
      );
      expect(discovered.vaultState, VaultState.uninitialized);
    },
  );

  test(
    'new Apple device handles CloudKit reset after vault discovery before unlock',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);

      final discovered = await targetContainer.read(
        vaultSessionControllerProvider.future,
      );
      expect(discovered.vaultState, VaultState.locked);
      expect(await DriftVaultHeaderStore(targetDatabase).read(), isNull);

      final resetError = await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .resetVault();
      expect(resetError, isNull);

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      final state = targetContainer
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(state.vaultState, VaultState.uninitialized);
      expect(state.failureMessage, isNull);
      expect(await DriftVaultHeaderStore(targetDatabase).read(), isNull);
      expect(await DriftVaultRecordRepository(targetDatabase).list(), isEmpty);
    },
  );

  test('reset clears a local vault when remote sync is unavailable', () async {
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
        cloudKitAvailabilityCheckProvider.overrideWithValue(() async => false),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    await container.read(vaultSessionControllerProvider.future);
    await container
        .read(vaultSessionControllerProvider.notifier)
        .initialize(passphrase: 'passphrase');

    final record = await container
        .read(vaultSessionControllerProvider.notifier)
        .service
        .encryptRecord(
          id: VaultRecordId('host:local-reset'),
          type: 'host',
          plaintext: utf8.encode('{"hostname":"local.example.test"}'),
        );
    await DriftVaultRecordRepository(database).upsert(record);

    final error = await container
        .read(vaultSessionControllerProvider.notifier)
        .resetVault();

    expect(error, isNull);
    expect(
      container.read(vaultSessionControllerProvider).requireValue.vaultState,
      VaultState.uninitialized,
    );
    expect(await DriftVaultHeaderStore(database).read(), isNull);
    expect(await DriftVaultRecordRepository(database).list(), isEmpty);
  });

  test(
    'remote CloudKit reset clears an unlocked Apple device on next sync',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final counters = _CountingSyncProviderCounters();
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _CountingSyncProvider(
              LocalDirectorySyncProvider(remoteDir),
              counters,
            ),
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      targetContainer.read(autoSyncControllerProvider);

      final initial = await targetContainer.read(
        vaultSessionControllerProvider.future,
      );
      expect(initial.vaultState, VaultState.locked);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      final targetRecordIds = [
        for (final record in await DriftVaultRecordRepository(
          targetDatabase,
        ).list())
          record.id.value,
      ];
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .state,
        VaultState.unlocked,
      );
      final directCloudKit = await targetContainer
          .read(syncSettingsServiceProvider)
          .readCloudKit();
      expect(
        await targetContainer.read(cloudKitSyncSettingsProvider.future),
        isNotNull,
        reason: 'target records: $targetRecordIds direct: $directCloudKit',
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );

      final resetError = await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .resetVault();
      expect(resetError, isNull);
      expect(
        RemoteResetMarker.fromBytes(
          await LocalDirectorySyncProvider(
            remoteDir,
          ).readObject(resetMarkerRef),
        ).vaultId,
        isNotEmpty,
      );
      targetContainer
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);
      await _waitForVaultState(targetContainer, VaultState.uninitialized);

      expect(await DriftVaultHeaderStore(targetDatabase).read(), isNull);
      expect(await DriftVaultRecordRepository(targetDatabase).list(), isEmpty);
    },
  );

  test(
    'CloudKit change echoes settle without relocking an unlocked vault',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final cloudKitEvents = StreamController<CloudKitSyncChange>.broadcast(
        sync: true,
      );
      addTearDown(cloudKitEvents.close);
      final counters = _CountingSyncProviderCounters();
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _CountingSyncProvider(
              LocalDirectorySyncProvider(remoteDir),
              counters,
            ),
          ),
          cloudKitSyncChangesProvider.overrideWith(
            (_) => cloudKitEvents.stream,
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncIntervalDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      final autoSyncSubscription = targetContainer.listen(
        autoSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(autoSyncSubscription.close);

      final discovered = await targetContainer.read(
        vaultSessionControllerProvider.future,
      );
      expect(discovered.vaultState, VaultState.locked);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .state,
        VaultState.unlocked,
      );
      expect(
        await targetContainer.read(cloudKitSyncSettingsProvider.future),
        isNotNull,
      );
      counters.reset();
      await Future<void>.delayed(Duration.zero);

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:echo'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"echo.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      cloudKitEvents.add(
        CloudKitSyncChange(
          source: 'remote',
          receivedAt: DateTime.now().toUtc(),
        ),
      );
      await _waitForRecord(targetDatabase, VaultRecordId('host:echo'));
      await _waitForAutoSyncIdle(targetContainer);
      final writesAfterRemoteChange = counters.conditionalManifestWrites;
      expect(writesAfterRemoteChange, greaterThanOrEqualTo(1));

      cloudKitEvents.add(
        CloudKitSyncChange(source: 'echo', receivedAt: DateTime.now().toUtc()),
      );
      await _waitForAutoSyncIdle(targetContainer);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final status = targetContainer.read(autoSyncControllerProvider);
      expect(status.phase, AutoSyncPhase.idle);
      expect(status.recordsUploaded, 0);
      expect(counters.conditionalManifestWrites, writesAfterRemoteChange);
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .state,
        VaultState.unlocked,
      );
    },
  );

  test(
    'locked Apple device pulls pending CloudKit changes before showing unlocked state',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final counters = _CountingSyncProviderCounters();
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _CountingSyncProvider(
              LocalDirectorySyncProvider(remoteDir),
              counters,
            ),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);

      final discovered = await targetContainer.read(
        vaultSessionControllerProvider.future,
      );
      expect(discovered.vaultState, VaultState.locked);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      expect(
        (await targetContainer.read(syncSettingsServiceProvider).readCloudKit())
            ?.enabled,
        isTrue,
      );
      counters.reset();
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:while-locked'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"while-locked.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));
      final latestFingerprint = manifestFingerprint(
        (await LocalDirectorySyncProvider(remoteDir).readManifest())!,
      );
      expect([
        for (final ref in await LocalDirectorySyncProvider(
          remoteDir,
        ).listRecordObjects(prefix: 'records/'))
          ref.path,
      ], contains(startsWith('records/host%3Awhile-locked-')));
      await _manifestRecordRef(
        provider: LocalDirectorySyncProvider(remoteDir),
        vault: sourceVault,
        id: VaultRecordId('host:while-locked'),
      );
      targetContainer
          .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
          .refreshNow();
      await _waitForStagedSnapshot(
        targetContainer,
        syncVaultId(
          targetContainer
              .read(vaultSessionControllerProvider.notifier)
              .service
              .header!,
        ),
        expectedFingerprint: latestFingerprint,
      );
      await _waitForCloudKitPrefetchIdle(targetContainer);

      counters.reset();
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      expect(counters.manifestReads, isPositive);
      expect(counters.objectReadPaths, isNot(contains(startsWith('records/'))));

      final restored = await DriftVaultRecordRepository(
        targetDatabase,
      ).read(VaultRecordId('host:while-locked'));
      expect(restored, isNotNull);
      expect(
        utf8.decode(
          await targetContainer
              .read(vaultSessionControllerProvider.notifier)
              .service
              .decryptRecord(restored!),
        ),
        '{"hostname":"while-locked.example.test"}',
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
    },
  );

  test(
    'locked Apple device respects locally paused CloudKit during unlock',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final counters = _CountingSyncProviderCounters();
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _CountingSyncProvider(
              LocalDirectorySyncProvider(remoteDir),
              counters,
            ),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      await targetContainer
          .read(syncSettingsServiceProvider)
          .saveCloudKit(false);
      counters.reset();
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:paused-while-locked'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"paused.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));
      await _manifestRecordRef(
        provider: LocalDirectorySyncProvider(remoteDir),
        vault: sourceVault,
        id: VaultRecordId('host:paused-while-locked'),
      );

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      expect(counters.manifestReads, 0);
      expect(
        await DriftVaultRecordRepository(
          targetDatabase,
        ).read(VaultRecordId('host:paused-while-locked')),
        isNull,
      );
      expect(
        (await targetContainer.read(syncSettingsServiceProvider).readCloudKit())
            ?.enabled,
        isFalse,
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
    },
  );

  test(
    'unlock stays usable when CloudKit compensation fails and auto-sync retries later',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final provider = _FailingReadSyncProvider(
        LocalDirectorySyncProvider(remoteDir),
      );
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(() => provider),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncIntervalDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      final autoSyncSubscription = targetContainer.listen(
        autoSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(autoSyncSubscription.close);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault = sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .service;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:retry-after-unlock'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"retry.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      provider.failReads = true;
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      expect(
        await DriftVaultRecordRepository(
          targetDatabase,
        ).read(VaultRecordId('host:retry-after-unlock')),
        isNull,
      );

      provider.failReads = false;
      targetContainer
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);
      await _waitForRecord(
        targetDatabase,
        VaultRecordId('host:retry-after-unlock'),
      );
      await _waitForAutoSyncIdle(targetContainer);
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
    },
  );

  test(
    'locked Apple device applies completed staged snapshot when CloudKit objects are unavailable',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final provider = _FailingReadSyncProvider(
        LocalDirectorySyncProvider(remoteDir),
      );
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(() => provider),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      targetContainer.read(cloudKitEncryptedSnapshotPrefetchControllerProvider);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      final vaultId = syncVaultId(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .header!,
      );
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:staged-offline'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"staged.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));
      final latestFingerprint = manifestFingerprint(
        (await LocalDirectorySyncProvider(remoteDir).readManifest())!,
      );

      targetContainer
          .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
          .refreshNow();
      await _waitForStagedSnapshot(
        targetContainer,
        vaultId,
        expectedFingerprint: latestFingerprint,
      );
      provider.failedReads = 0;
      provider.failReads = true;
      provider.failResetMarkerReads = false;

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      final restored = await DriftVaultRecordRepository(
        targetDatabase,
      ).read(VaultRecordId('host:staged-offline'));
      expect(restored, isNotNull);
      expect(
        utf8.decode(
          await targetContainer
              .read(vaultSessionControllerProvider.notifier)
              .service
              .decryptRecord(restored!),
        ),
        '{"hostname":"staged.example.test"}',
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
    },
  );

  test(
    'stale locked CloudKit staging is discarded and live snapshot is pulled after unlock',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final counters = _CountingSyncProviderCounters();
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _CountingSyncProvider(
              LocalDirectorySyncProvider(remoteDir),
              counters,
            ),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      targetContainer.read(cloudKitEncryptedSnapshotPrefetchControllerProvider);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final first = await sourceVault.encryptRecord(
        id: VaultRecordId('host:stale-staged'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"staged.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(first);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      targetContainer
          .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
          .refreshNow();
      await _waitForObjectRead(counters);
      final vaultId = syncVaultId(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .header!,
      );
      await _waitForStagedSnapshot(targetContainer, vaultId);

      final second = await sourceVault.encryptRecord(
        id: VaultRecordId('host:live-after-stale'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"live.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(second);
      counters.reset();
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      expect(counters.objectReads, isPositive);
      final restored = await DriftVaultRecordRepository(
        targetDatabase,
      ).read(VaultRecordId('host:live-after-stale'));
      expect(restored, isNotNull);
      expect(
        utf8.decode(
          await targetContainer
              .read(vaultSessionControllerProvider.notifier)
              .service
              .decryptRecord(restored!),
        ),
        '{"hostname":"live.example.test"}',
      );
      expect(
        await targetContainer
            .read(encryptedSnapshotStagingRepositoryProvider)
            .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId),
        isNull,
      );
    },
  );

  test(
    'corrupt locked CloudKit staging is ignored and live snapshot is pulled after unlock',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      final vaultId = syncVaultId(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .header!,
      );
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:corrupt-staged-cache'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"corrupt-staged.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));
      await _insertCorruptStagedSnapshot(targetDatabase, vaultId);

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      final restored = await DriftVaultRecordRepository(
        targetDatabase,
      ).read(VaultRecordId('host:corrupt-staged-cache'));
      expect(restored, isNotNull);
      expect(
        utf8.decode(
          await targetContainer
              .read(vaultSessionControllerProvider.notifier)
              .service
              .decryptRecord(restored!),
        ),
        '{"hostname":"corrupt-staged.example.test"}',
      );
      expect(
        await targetContainer
            .read(encryptedSnapshotStagingRepositoryProvider)
            .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId),
        isNull,
      );
    },
  );

  test(
    'locked CloudKit prefetch records remote reset and clears local vault after unlock',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      targetContainer.read(cloudKitEncryptedSnapshotPrefetchControllerProvider);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      final vaultId = syncVaultId(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .header!,
      );
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final resetError = await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .resetVault();
      expect(resetError, isNull);

      targetContainer
          .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
          .refreshNow();
      await _waitForPendingReset(targetContainer, vaultId);

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.uninitialized,
      );
      expect(await DriftVaultHeaderStore(targetDatabase).read(), isNull);
      expect(await DriftVaultRecordRepository(targetDatabase).list(), isEmpty);
      expect(
        await targetContainer
            .read(pendingRemoteResetRepositoryProvider)
            .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId),
        isNull,
      );
    },
  );

  test(
    'corrupt pending CloudKit reset cache is ignored during unlock',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => LocalDirectorySyncProvider(remoteDir),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      final vaultId = syncVaultId(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .header!,
      );
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:corrupt-reset-cache'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"corrupt-reset.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));
      await _insertCorruptPendingReset(targetDatabase, vaultId);

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');

      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      final restored = await DriftVaultRecordRepository(
        targetDatabase,
      ).read(VaultRecordId('host:corrupt-reset-cache'));
      expect(restored, isNotNull);
      expect(
        await targetContainer
            .read(pendingRemoteResetRepositoryProvider)
            .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId),
        isNull,
      );
    },
  );

  test('locked CloudKit prefetch respects shadow disabled setting', () async {
    final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
    final sourceTransferQueue = TransferQueueController();
    final sourceContainer = ProviderContainer(
      overrides: [
        serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
        transferQueueControllerProvider.overrideWithValue(sourceTransferQueue),
      ],
    );
    addTearDown(sourceContainer.dispose);
    addTearDown(sourceTransferQueue.dispose);
    addTearDown(sourceDatabase.close);

    await sourceContainer.read(vaultSessionControllerProvider.future);
    await sourceContainer
        .read(vaultSessionControllerProvider.notifier)
        .initialize(passphrase: 'passphrase');

    final counters = _CountingSyncProviderCounters();
    final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
    final targetTransferQueue = TransferQueueController();
    final targetContainer = ProviderContainer(
      overrides: [
        serlinkDatabaseProvider.overrideWithValue(targetDatabase),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        platformCapabilitiesProvider.overrideWithValue(
          const PlatformCapabilities(
            operatingSystem: 'macos',
            targetPlatform: TargetPlatform.macOS,
          ),
        ),
        cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
        cloudKitSyncProviderFactoryProvider.overrideWithValue(
          () => _CountingSyncProvider(
            LocalDirectorySyncProvider(remoteDir),
            counters,
          ),
        ),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        transferQueueControllerProvider.overrideWithValue(targetTransferQueue),
        autoSyncDebounceDurationProvider.overrideWithValue(
          const Duration(days: 1),
        ),
      ],
    );
    addTearDown(targetContainer.dispose);
    addTearDown(targetTransferQueue.dispose);
    addTearDown(targetDatabase.close);
    targetContainer.read(cloudKitEncryptedSnapshotPrefetchControllerProvider);

    await targetContainer.read(vaultSessionControllerProvider.future);
    await targetContainer
        .read(vaultSessionControllerProvider.notifier)
        .unlock(passphrase: 'passphrase');
    final vaultId = syncVaultId(
      targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .service
          .header!,
    );
    await targetContainer.read(syncSettingsServiceProvider).saveCloudKit(false);
    await targetContainer
        .read(cloudKitSyncShadowSettingsStoreProvider)
        .save(vaultId: vaultId, enabled: false);
    await targetContainer
        .read(encryptedSnapshotStagingRepositoryProvider)
        .clear(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
    await targetContainer
        .read(pendingRemoteResetRepositoryProvider)
        .clear(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
    await targetContainer.read(vaultSessionControllerProvider.notifier).lock();
    await Future<void>.delayed(Duration.zero);
    counters.reset();

    final sourceVault =
        sourceContainer.read(vaultSessionControllerProvider.notifier).service
            as InMemoryVaultService;
    final host = await sourceVault.encryptRecord(
      id: VaultRecordId('host:shadow-disabled'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"shadow-disabled.example.test"}'),
    );
    await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
    await sourceContainer
        .read(syncRunServiceProvider)
        .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

    targetContainer
        .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
        .refreshNow();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(counters.objectReads, 0);
    expect(
      await targetContainer
          .read(encryptedSnapshotStagingRepositoryProvider)
          .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId),
      isNull,
    );
  });

  test(
    'locked CloudKit prefetch result is discarded when unlock wins the race',
    () async {
      final sourceDatabase = SerlinkDatabase(NativeDatabase.memory());
      final sourceTransferQueue = TransferQueueController();
      final sourceContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(sourceDatabase),
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
          transferQueueControllerProvider.overrideWithValue(
            sourceTransferQueue,
          ),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(sourceTransferQueue.dispose);
      addTearDown(sourceDatabase.close);

      await sourceContainer.read(vaultSessionControllerProvider.future);
      await sourceContainer
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final provider = _BlockingObjectReadSyncProvider(
        LocalDirectorySyncProvider(remoteDir),
      );
      final targetDatabase = SerlinkDatabase(NativeDatabase.memory());
      final targetTransferQueue = TransferQueueController();
      final targetContainer = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(targetDatabase),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(() => provider),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(
            targetTransferQueue,
          ),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(targetContainer.dispose);
      addTearDown(targetTransferQueue.dispose);
      addTearDown(targetDatabase.close);
      targetContainer.read(cloudKitEncryptedSnapshotPrefetchControllerProvider);

      await targetContainer.read(vaultSessionControllerProvider.future);
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      final vaultId = syncVaultId(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .header!,
      );
      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .lock();

      final sourceVault =
          sourceContainer.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      final host = await sourceVault.encryptRecord(
        id: VaultRecordId('host:unlock-race'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"race.example.test"}'),
      );
      await sourceContainer.read(vaultRecordRepositoryProvider).upsert(host);
      await sourceContainer
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));

      provider.armNextNonResetObjectRead();
      targetContainer
          .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
          .refreshNow();
      await provider.waitForBlockedRead();

      await targetContainer
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'passphrase');
      expect(
        targetContainer
            .read(vaultSessionControllerProvider)
            .requireValue
            .vaultState,
        VaultState.unlocked,
      );
      expect(
        await DriftVaultRecordRepository(
          targetDatabase,
        ).read(VaultRecordId('host:unlock-race')),
        isNotNull,
      );

      provider.releaseBlockedRead();
      await provider.waitForBlockedReadToComplete();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        await targetContainer
            .read(encryptedSnapshotStagingRepositoryProvider)
            .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId),
        isNull,
      );
      expect(
        targetContainer
            .read(vaultSessionControllerProvider.notifier)
            .service
            .state,
        VaultState.unlocked,
      );
    },
  );

  test(
    'CloudKit sync failures back off without an immediate retry loop',
    () async {
      final provider = _FailingReadSyncProvider(
        LocalDirectorySyncProvider(remoteDir),
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
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(() async => true),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(() => provider),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
          autoSyncIntervalDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');
      final autoSyncSubscription = container.listen(
        autoSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(autoSyncSubscription.close);

      provider.failReads = true;
      provider.failedReads = 0;
      container
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);

      await _waitForFailedRead(provider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.failedReads, 1);
      expect(
        container.read(autoSyncControllerProvider).phase,
        AutoSyncPhase.failed,
      );
      expect(
        container.read(vaultSessionControllerProvider).requireValue.vaultState,
        VaultState.unlocked,
      );
      expect(
        container.read(vaultSessionControllerProvider.notifier).service.state,
        VaultState.unlocked,
      );
    },
  );

  test(
    'CloudKit bootstrap failure does not block local vault creation',
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
          cloudKitAvailabilityCheckProvider.overrideWithValue(
            () async => false,
          ),
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

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'passphrase');

      final state = container.read(vaultSessionControllerProvider).requireValue;
      expect(state.vaultState, VaultState.unlocked);
      expect(state.failureMessage, 'iCloud sync is not available.');
      expect(await DriftVaultHeaderStore(database).read(), isNotNull);
      expect(
        await LocalDirectorySyncProvider(remoteDir).readManifest(),
        isNull,
      );
    },
  );

  test(
    'CloudKit bootstrap adopts an existing remote vault instead of local key',
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

      final remoteVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await remoteVault.initialize(passphrase: 'remote passphrase');
      final remoteRecords = InMemoryVaultRecordRepository();
      final remoteHost = await remoteVault.encryptRecord(
        id: VaultRecordId('host:remote'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
      );
      await remoteRecords.upsert(remoteHost);
      await SyncRunService(
        vault: remoteVault,
        records: remoteRecords,
      ).pushEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));
      final remoteManifest = await LocalDirectorySyncProvider(
        remoteDir,
      ).readManifest();

      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'local passphrase');

      final state = container.read(vaultSessionControllerProvider).requireValue;
      expect(state.vaultState, VaultState.locked);
      expect(state.recoveryKey, isNull);
      expect(state.failureMessage, isNull);
      expect(state.notice, VaultSessionNotice.cloudKitRemoteVaultAdopted);
      final after = await LocalDirectorySyncProvider(remoteDir).readManifest();
      expect(after?.vaultId, remoteManifest?.vaultId);
      expect(
        syncVaultId((await DriftVaultHeaderStore(database).read())!),
        remoteManifest?.vaultId,
      );
      expect(await DriftVaultRecordRepository(database).list(), isEmpty);

      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'local passphrase');
      expect(
        container.read(vaultSessionControllerProvider).requireValue,
        isA<VaultSessionState>()
            .having(
              (state) => state.failureMessage,
              'failureMessage',
              'Passphrase did not unlock the vault.',
            )
            .having((state) => state.notice, 'notice', isNull),
      );

      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'remote passphrase');
      final unlocked = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(unlocked.vaultState, VaultState.unlocked);
      expect(unlocked.failureMessage, isNull);
      final restored = await DriftVaultRecordRepository(
        database,
      ).read(VaultRecordId('host:remote'));
      expect(restored, isNotNull);
    },
  );

  test(
    'concurrent CloudKit bootstrap cannot corrupt the winning vault header',
    () async {
      final inner = LocalDirectorySyncProvider(remoteDir);
      final provider = _BootstrapRaceProvider(inner);
      final remoteVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await remoteVault.initialize(passphrase: 'remote passphrase');
      provider.onFirstManifestWrite = () async {
        await SyncRunService(
          vault: remoteVault,
          records: InMemoryVaultRecordRepository(),
        ).pushEncryptedSnapshot(inner);
      };

      final localVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await localVault.initialize(passphrase: 'local passphrase');
      final localService = SyncRunService(
        vault: localVault,
        records: InMemoryVaultRecordRepository(),
      );

      await expectLater(
        localService.pushEncryptedSnapshot(provider),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            'sync.provider.conflict',
          ),
        ),
      );

      final manifest = await inner.readManifest();
      expect(manifest?.vaultId, syncVaultId(remoteVault.header!));
      expect(manifest?.headerPath, startsWith('vault/headers/'));
      final header = VaultHeader.fromJson(
        jsonDecode(
              utf8.decode(
                await inner.readObject(RemoteObjectRef(manifest!.headerPath!)),
              ),
            )
            as Map<String, Object?>,
      );
      expect(syncVaultId(header), manifest.vaultId);
    },
  );

  test(
    'new Apple vault bootstrap does not overwrite a concurrently created CloudKit vault',
    () async {
      final inner = LocalDirectorySyncProvider(remoteDir);
      final provider = _BootstrapRaceProvider(inner);
      final remoteVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await remoteVault.initialize(passphrase: 'remote passphrase');
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
          cloudKitSyncProviderFactoryProvider.overrideWithValue(() => provider),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      provider.onFirstManifestRead = () async {
        await SyncRunService(
          vault: remoteVault,
          records: InMemoryVaultRecordRepository(),
        ).publishInitialEncryptedSnapshot(inner);
      };
      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'local passphrase');

      final state = container.read(vaultSessionControllerProvider).requireValue;
      expect(state.vaultState, VaultState.unlocked);
      expect(state.failureMessage, 'Remote sync data changed while syncing.');
      expect(
        (await container.read(cloudKitSyncSettingsProvider.future))?.enabled,
        isTrue,
      );
      final manifest = await inner.readManifest();
      expect(manifest?.vaultId, syncVaultId(remoteVault.header!));
      final header = VaultHeader.fromJson(
        jsonDecode(
              utf8.decode(
                await inner.readObject(RemoteObjectRef(manifest!.headerPath!)),
              ),
            )
            as Map<String, Object?>,
      );
      expect(syncVaultId(header), manifest.vaultId);
      expect(
        [
          for (final ref in await inner.listRecordObjects(prefix: 'vault/'))
            ref.path,
        ],
        [manifest.headerPath],
      );
    },
  );
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
  for (final raw in manifestData['records'] as List<Object?>) {
    final entry = raw as Map<String, Object?>;
    if (entry['id'] == id.value) {
      return RemoteObjectRef(entry['path'] as String);
    }
  }
  fail('Manifest did not contain ${id.value}');
}

Future<void> _insertCorruptStagedSnapshot(
  SerlinkDatabase database,
  String vaultId,
) async {
  await database.customStatement(
    '''
INSERT INTO sync_staged_snapshots (
  provider_kind,
  vault_id,
  manifest,
  manifest_fingerprint,
  protocol_version,
  header_path,
  completed_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
''',
    [
      syncProviderKindName(SyncProviderKind.cloudKit),
      vaultId,
      Uint8List.fromList([0, 1, 2]),
      'corrupt',
      1,
      'vault/headers/$vaultId.json',
      DateTime.utc(2026, 6, 21).toIso8601String(),
    ],
  );
}

Future<void> _insertCorruptPendingReset(
  SerlinkDatabase database,
  String vaultId,
) async {
  final now = DateTime.utc(2026, 6, 21).toIso8601String();
  await database.customStatement(
    '''
INSERT INTO sync_pending_resets (
  provider_kind,
  vault_id,
  marker,
  reset_at,
  updated_at
) VALUES (?, ?, ?, ?, ?)
''',
    [
      syncProviderKindName(SyncProviderKind.cloudKit),
      vaultId,
      Uint8List.fromList([0, 1, 2]),
      now,
      now,
    ],
  );
}

Future<void> _waitForVaultState(
  ProviderContainer container,
  VaultState expected,
) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    final state = container.read(vaultSessionControllerProvider).value;
    if (state?.vaultState == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  final state = container.read(vaultSessionControllerProvider).value;
  final autoSync = container.read(autoSyncControllerProvider);
  fail(
    'Expected vault state $expected but found ${state?.vaultState}. '
    'Auto-sync phase: ${autoSync.phase}, failure: ${autoSync.lastFailureMessage}.',
  );
}

Future<void> _waitForRecord(SerlinkDatabase database, VaultRecordId id) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    if (await DriftVaultRecordRepository(database).read(id) != null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected record ${id.value} to be synced locally.');
}

Future<void> _waitForAutoSyncIdle(ProviderContainer container) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    final status = container.read(autoSyncControllerProvider);
    if (status.phase == AutoSyncPhase.idle) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  final status = container.read(autoSyncControllerProvider);
  fail(
    'Expected auto-sync to become idle but found ${status.phase}. '
    'Failure: ${status.lastFailureMessage}.',
  );
}

Future<void> _waitForFailedRead(_FailingReadSyncProvider provider) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    if (provider.failedReads > 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected CloudKit provider read to fail.');
}

Future<void> _waitForObjectRead(_CountingSyncProviderCounters counters) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    if (counters.objectReads > 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected CloudKit provider object read.');
}

Future<void> _waitForStagedSnapshot(
  ProviderContainer container,
  String vaultId, {
  String? expectedFingerprint,
}) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    final staged = await container
        .read(encryptedSnapshotStagingRepositoryProvider)
        .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
    if (staged != null &&
        (expectedFingerprint == null ||
            staged.manifestFingerprint == expectedFingerprint)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected locked CloudKit prefetch to stage a snapshot.');
}

Future<void> _waitForCloudKitPrefetchIdle(ProviderContainer container) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    if (!container
        .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
        .isRunning) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected locked CloudKit prefetch to become idle.');
}

Future<void> _waitForPendingReset(
  ProviderContainer container,
  String vaultId,
) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    final pending = await container
        .read(pendingRemoteResetRepositoryProvider)
        .read(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
    if (pending != null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected locked CloudKit prefetch to record a pending reset.');
}

class _CountingSyncProviderCounters {
  int conditionalManifestWrites = 0;
  int manifestReads = 0;
  int objectReads = 0;
  final List<String> objectReadPaths = [];

  void reset() {
    conditionalManifestWrites = 0;
    manifestReads = 0;
    objectReads = 0;
    objectReadPaths.clear();
  }
}

class _CountingSyncProvider implements SyncProvider {
  _CountingSyncProvider(this.inner, this.counters);

  final SyncProvider inner;
  final _CountingSyncProviderCounters counters;

  @override
  Future<ProviderCapabilities> capabilities() {
    return inner.capabilities();
  }

  @override
  Future<RemoteManifest?> readManifest() async {
    final manifest = await inner.readManifest();
    counters.manifestReads += 1;
    return manifest;
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
    await inner.writeManifestIfUnchanged(manifest, expectedCurrent);
    counters.conditionalManifestWrites += 1;
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) {
    return inner.listRecordObjects(prefix: prefix);
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    final bytes = await inner.readObject(ref);
    counters.objectReads += 1;
    counters.objectReadPaths.add(ref.path);
    return bytes;
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

class _BlockingObjectReadSyncProvider implements SyncProvider {
  _BlockingObjectReadSyncProvider(this.inner);

  final SyncProvider inner;
  Completer<void>? _blocked;
  Completer<void>? _release;
  Completer<void>? _completed;
  var _armed = false;

  void armNextNonResetObjectRead() {
    _armed = true;
    _blocked = Completer<void>();
    _release = Completer<void>();
    _completed = Completer<void>();
  }

  Future<void> waitForBlockedRead() async {
    final blocked = _blocked;
    if (blocked == null) {
      fail('Blocking provider was not armed.');
    }
    await blocked.future;
  }

  void releaseBlockedRead() {
    final release = _release;
    if (release == null || release.isCompleted) {
      return;
    }
    release.complete();
  }

  Future<void> waitForBlockedReadToComplete() async {
    final completed = _completed;
    if (completed != null) {
      await completed.future;
    }
  }

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
  ) {
    return inner.writeManifestIfUnchanged(manifest, expectedCurrent);
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) {
    return inner.listRecordObjects(prefix: prefix);
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    if (_armed && ref.path != resetMarkerRef.path) {
      _armed = false;
      _blocked?.complete();
      await _release!.future;
      try {
        return await inner.readObject(ref);
      } finally {
        _completed?.complete();
      }
    }
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

class _FailingReadSyncProvider implements SyncProvider {
  _FailingReadSyncProvider(this.inner);

  final SyncProvider inner;
  var failReads = false;
  var failResetMarkerReads = true;
  var failedReads = 0;
  var objectReads = 0;

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
  ) {
    return inner.writeManifestIfUnchanged(manifest, expectedCurrent);
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) {
    return inner.listRecordObjects(prefix: prefix);
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) {
    if (failReads &&
        (failResetMarkerReads || ref.path != resetMarkerRef.path)) {
      failedReads += 1;
      throw const SyncProviderException(
        'sync.cloudkit.failed',
        'Temporary CloudKit failure.',
      );
    }
    objectReads += 1;
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

class _BootstrapRaceProvider implements SyncProvider {
  _BootstrapRaceProvider(this.inner);

  final LocalDirectorySyncProvider inner;
  Future<void> Function()? onFirstManifestRead;
  Future<void> Function()? onFirstManifestWrite;
  var _readRaced = false;
  var _raced = false;

  @override
  Future<ProviderCapabilities> capabilities() {
    return inner.capabilities();
  }

  @override
  Future<RemoteManifest?> readManifest() async {
    if (!_readRaced && onFirstManifestRead != null) {
      _readRaced = true;
      final current = await inner.readManifest();
      await onFirstManifestRead!();
      return current;
    }
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
    if (!_raced && onFirstManifestWrite != null) {
      _raced = true;
      await onFirstManifestWrite!();
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
