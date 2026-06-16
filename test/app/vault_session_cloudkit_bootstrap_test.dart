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

  setUpAll(() {
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
      expect(await provider.readManifest(), isNotNull);
      expect(
        await provider.readObject(const RemoteObjectRef('vault/header.json')),
        isNotEmpty,
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
          autoSyncDebounceDurationProvider.overrideWithValue(
            const Duration(days: 1),
          ),
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
      await expectLater(
        targetContainer
            .read(syncRunServiceProvider)
            .syncEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir)),
        throwsA(
          isA<SyncRunException>().having(
            (error) => error.code,
            'code',
            'sync.remote_vault_reset',
          ),
        ),
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
    'CloudKit bootstrap does not overwrite an existing remote vault',
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
      await SyncRunService(
        vault: remoteVault,
        records: InMemoryVaultRecordRepository(),
      ).pushEncryptedSnapshot(LocalDirectorySyncProvider(remoteDir));
      final remoteManifest = await LocalDirectorySyncProvider(
        remoteDir,
      ).readManifest();

      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'local passphrase');

      final state = container.read(vaultSessionControllerProvider).requireValue;
      expect(state.vaultState, VaultState.unlocked);
      expect(
        state.failureMessage,
        'iCloud already has a Serlink vault. Reset this local vault and restore the iCloud vault.',
      );
      final after = await LocalDirectorySyncProvider(remoteDir).readManifest();
      expect(after?.vaultId, remoteManifest?.vaultId);
    },
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
