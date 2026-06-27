import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sync/application/auto_sync_controller.dart';
import 'package:serlink/features/sync/application/sync_settings_service.dart';
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
  late Directory cloudKitDir;
  late Directory webDavDir;

  setUp(() async {
    cloudKitDir = await Directory.systemTemp.createTemp(
      'serlink-sync-metadata-cloudkit-test-',
    );
    webDavDir = await Directory.systemTemp.createTemp(
      'serlink-sync-metadata-webdav-test-',
    );
  });

  tearDown(() async {
    if (await cloudKitDir.exists()) {
      await cloudKitDir.delete(recursive: true);
    }
    if (await webDavDir.exists()) {
      await webDavDir.delete(recursive: true);
    }
  });

  test('iCloud sync defaults to enabled on fresh install', () async {
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
          () => LocalDirectorySyncProvider(cloudKitDir),
        ),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        autoSyncEnabledProvider.overrideWithValue(false),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    final settings = await container.read(cloudKitSyncSettingsProvider.future);
    expect(settings?.enabled, isTrue);

    await container.read(vaultSessionControllerProvider.future);
    expect(
      container.read(vaultSessionControllerProvider).requireValue.vaultState,
      VaultState.uninitialized,
    );
  });

  test('iCloud sync setting can change before local vault exists', () async {
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
          () => LocalDirectorySyncProvider(cloudKitDir),
        ),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        autoSyncEnabledProvider.overrideWithValue(false),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    await container.read(vaultSessionControllerProvider.future);

    expect(
      container.read(vaultSessionControllerProvider).requireValue.vaultState,
      VaultState.uninitialized,
    );

    await container.read(syncSettingsServiceProvider).saveCloudKit(false);

    final settings = await container.read(cloudKitSyncSettingsProvider.future);
    expect(settings?.enabled, isFalse);
    expect(
      container.read(vaultSessionControllerProvider).requireValue.vaultState,
      VaultState.uninitialized,
    );
  });

  test('iCloud sync setting remains readable while vault is locked', () async {
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
          () => LocalDirectorySyncProvider(cloudKitDir),
        ),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        autoSyncEnabledProvider.overrideWithValue(false),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    await container.read(vaultSessionControllerProvider.future);
    await container.read(syncSettingsServiceProvider).saveCloudKit(false);
    await container
        .read(vaultSessionControllerProvider.notifier)
        .initialize(passphrase: 'good passphrase');
    await container.read(vaultSessionControllerProvider.notifier).lock();

    final settings = await container.read(cloudKitSyncSettingsProvider.future);
    expect(settings?.enabled, isFalse);
    expect(
      container.read(vaultSessionControllerProvider).requireValue.vaultState,
      VaultState.locked,
    );
  });

  test('WebDAV sync setting can change before local vault exists', () async {
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
        cloudKitAvailabilityCheckProvider.overrideWithValue(() async => false),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        autoSyncEnabledProvider.overrideWithValue(false),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    await container.read(vaultSessionControllerProvider.future);
    await container
        .read(syncSettingsServiceProvider)
        .saveWebDav(
          const WebDavSyncSettingsDraft(
            endpoint: 'https://dav.example.test',
            username: 'ops',
            password: 'server-password',
            enabled: false,
          ),
        );

    final settings = await container.read(webDavSyncSettingsProvider.future);
    expect(settings?.endpoint.host, 'dav.example.test');
    expect(settings?.enabled, isFalse);
    expect(
      container.read(vaultSessionControllerProvider).requireValue.vaultState,
      VaultState.uninitialized,
    );
  });

  test('WebDAV sync setting remains readable while vault is locked', () async {
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
        cloudKitAvailabilityCheckProvider.overrideWithValue(() async => false),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        autoSyncEnabledProvider.overrideWithValue(false),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    await container.read(vaultSessionControllerProvider.future);
    await container
        .read(syncSettingsServiceProvider)
        .saveWebDav(
          const WebDavSyncSettingsDraft(
            endpoint: 'https://dav.example.test',
            username: 'ops',
            password: 'server-password',
          ),
        );
    await container
        .read(vaultSessionControllerProvider.notifier)
        .initialize(passphrase: 'good passphrase');
    await container.read(vaultSessionControllerProvider.notifier).lock();

    final settings = await container.read(webDavSyncSettingsProvider.future);
    expect(settings?.endpoint.host, 'dav.example.test');
    expect(settings?.enabled, isTrue);
    expect(
      container.read(vaultSessionControllerProvider).requireValue.vaultState,
      VaultState.locked,
    );
  });

  test(
    'sync completion refreshes encrypted sync settings without locking vault',
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
          cloudKitAvailabilityCheckProvider.overrideWithValue(
            () async => false,
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          autoSyncEnabledProvider.overrideWithValue(false),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'good passphrase');
      final session = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(session.vaultState, VaultState.unlocked);

      final generation = session.unlockGeneration;
      await container.read(syncSettingsServiceProvider).saveCloudKit(true);
      final cached = await container.read(cloudKitSyncSettingsProvider.future);
      expect(cached?.enabled, isTrue);

      await container.read(syncSettingsServiceProvider).saveCloudKit(false);
      container
          .read(autoSyncControllerProvider.notifier)
          .markConflictResolution(
            SyncRunResult(
              recordsUploaded: 0,
              headerUploaded: false,
              completedAt: DateTime.utc(2026, 6, 18, 12),
            ),
          );

      final refreshed = await container.read(
        cloudKitSyncSettingsProvider.future,
      );
      expect(refreshed?.enabled, isFalse);

      final afterSync = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(afterSync.vaultState, VaultState.unlocked);
      expect(afterSync.unlockGeneration, generation);
      expect(
        container.read(vaultSessionControllerProvider.notifier).service.state,
        VaultState.unlocked,
      );
    },
  );

  test(
    'auto sync merges CloudKit and WebDAV changes when both are enabled',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'good passphrase');
      await _publishRemoteHost(
        vault: sourceVault,
        provider: LocalDirectorySyncProvider(cloudKitDir),
        id: VaultRecordId('host:cloudkit-only'),
        hostname: 'cloudkit-only.example.test',
      );
      await _publishRemoteHost(
        vault: sourceVault,
        provider: LocalDirectorySyncProvider(webDavDir),
        id: VaultRecordId('host:webdav-only'),
        hostname: 'webdav-only.example.test',
      );

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = _createDualSyncContainer(
        database: database,
        transferQueue: transferQueue,
        cloudKitDir: cloudKitDir,
        webDavDir: webDavDir,
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'good passphrase');
      await container
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            const WebDavSyncSettingsDraft(
              endpoint: 'https://dav.example.test',
              username: 'ops',
              password: 'server-password',
            ),
          );
      container.read(autoSyncControllerProvider);
      container
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);

      await _waitForAutoSyncIdle(container);
      await _waitForLocalRecords(database, [
        VaultRecordId('host:cloudkit-only'),
        VaultRecordId('host:webdav-only'),
      ]);

      final localVault =
          container.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      expect(
        await _manifestRecordIds(
          provider: LocalDirectorySyncProvider(cloudKitDir),
          vault: localVault,
        ),
        containsAll(['host:cloudkit-only', 'host:webdav-only']),
      );
      expect(
        await _manifestRecordIds(
          provider: LocalDirectorySyncProvider(webDavDir),
          vault: localVault,
        ),
        containsAll(['host:cloudkit-only', 'host:webdav-only']),
      );

      final status = container.read(autoSyncControllerProvider);
      expect(status.phase, AutoSyncPhase.idle);
      expect(status.recordsDownloaded, 1);
      expect(status.recordsUploaded, greaterThanOrEqualTo(2));
      expect(status.lastProviderKind, SyncProviderKind.webDav);
    },
  );

  test(
    'auto sync attributes same-record conflicts to WebDAV after CloudKit pull',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'good passphrase');
      final sharedId = VaultRecordId('host:dual-conflict');
      await _publishRemoteHost(
        vault: sourceVault,
        provider: LocalDirectorySyncProvider(cloudKitDir),
        id: sharedId,
        hostname: 'cloudkit-conflict.example.test',
      );
      await _publishRemoteHost(
        vault: sourceVault,
        provider: LocalDirectorySyncProvider(webDavDir),
        id: sharedId,
        hostname: 'webdav-conflict.example.test',
      );

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = _createDualSyncContainer(
        database: database,
        transferQueue: transferQueue,
        cloudKitDir: cloudKitDir,
        webDavDir: webDavDir,
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'good passphrase');
      await container
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            const WebDavSyncSettingsDraft(
              endpoint: 'https://dav.example.test',
              username: 'ops',
              password: 'server-password',
            ),
          );
      container.read(autoSyncControllerProvider);
      container
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);

      await _waitForAutoSyncPhase(container, AutoSyncPhase.conflicts);

      final status = container.read(autoSyncControllerProvider);
      expect(status.lastProviderKind, SyncProviderKind.webDav);
      expect(status.conflictCount, 1);
      final conflicts = container.read(syncConflictControllerProvider);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.id, sharedId);
      expect(
        container.read(syncConflictControllerProvider.notifier).providerKind,
        SyncProviderKind.webDav,
      );

      final localVault =
          container.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      expect(
        await _localHostName(
          database: database,
          vault: localVault,
          id: sharedId,
        ),
        'cloudkit-conflict.example.test',
      );
      expect(
        await _remoteHostName(
          provider: LocalDirectorySyncProvider(webDavDir),
          vault: localVault,
          id: sharedId,
        ),
        'webdav-conflict.example.test',
      );
    },
  );

  test(
    'manual keep-local conflict resolution fans out to both sync providers',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'good passphrase');
      final sharedId = VaultRecordId('host:dual-resolution');
      await _publishRemoteHost(
        vault: sourceVault,
        provider: LocalDirectorySyncProvider(cloudKitDir),
        id: sharedId,
        hostname: 'cloudkit-resolution.example.test',
      );
      await _publishRemoteHost(
        vault: sourceVault,
        provider: LocalDirectorySyncProvider(webDavDir),
        id: sharedId,
        hostname: 'webdav-resolution.example.test',
      );

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = _createDualSyncContainer(
        database: database,
        transferQueue: transferQueue,
        cloudKitDir: cloudKitDir,
        webDavDir: webDavDir,
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'good passphrase');
      await container
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            const WebDavSyncSettingsDraft(
              endpoint: 'https://dav.example.test',
              username: 'ops',
              password: 'server-password',
            ),
          );
      container.read(autoSyncControllerProvider);
      container
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);

      await _waitForAutoSyncPhase(container, AutoSyncPhase.conflicts);
      final conflicts = container.read(syncConflictControllerProvider);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.id, sharedId);

      final result = await container
          .read(syncRunServiceProvider)
          .resolveConflicts(
            LocalDirectorySyncProvider(webDavDir),
            SyncConflictResolution.keepLocal,
            acceptedConflicts: conflicts,
          );
      container.read(syncConflictControllerProvider.notifier).clear();
      container
          .read(autoSyncControllerProvider.notifier)
          .markConflictResolution(
            result,
            providerKind: SyncProviderKind.webDav,
          );
      container
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);

      await _waitForAutoSyncIdle(container);

      final localVault =
          container.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      expect(container.read(syncConflictControllerProvider), isEmpty);
      expect(
        await _remoteHostName(
          provider: LocalDirectorySyncProvider(cloudKitDir),
          vault: localVault,
          id: sharedId,
        ),
        'cloudkit-resolution.example.test',
      );
      expect(
        await _remoteHostName(
          provider: LocalDirectorySyncProvider(webDavDir),
          vault: localVault,
          id: sharedId,
        ),
        'cloudkit-resolution.example.test',
      );
      expect(
        container.read(autoSyncControllerProvider).lastProviderKind,
        SyncProviderKind.webDav,
      );
    },
  );

  test(
    'auto sync stops on newer WebDAV vault schema after CloudKit sync',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'good passphrase');
      final cloudKitId = VaultRecordId('host:cloudkit-before-newer-webdav');
      final webDavId = VaultRecordId('host:newer-webdav-schema');
      await _publishRemoteHost(
        vault: sourceVault,
        provider: LocalDirectorySyncProvider(cloudKitDir),
        id: cloudKitId,
        hostname: 'cloudkit-before-newer-webdav.example.test',
      );
      final webDavProvider = LocalDirectorySyncProvider(webDavDir);
      await _publishRemoteHost(
        vault: sourceVault,
        provider: webDavProvider,
        id: webDavId,
        hostname: 'newer-webdav-schema.example.test',
      );
      await _writeRemoteHeaderSchemaVersion(
        provider: webDavProvider,
        vault: sourceVault,
        schemaVersion: sourceVault.header!.schemaVersion + 1,
      );

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = _createDualSyncContainer(
        database: database,
        transferQueue: transferQueue,
        cloudKitDir: cloudKitDir,
        webDavDir: webDavDir,
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'good passphrase');
      await container
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            const WebDavSyncSettingsDraft(
              endpoint: 'https://dav.example.test',
              username: 'ops',
              password: 'server-password',
            ),
          );
      container.read(autoSyncControllerProvider);
      container
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);

      await _waitForAutoSyncPhase(container, AutoSyncPhase.failed);

      final status = container.read(autoSyncControllerProvider);
      expect(status.lastProviderKind, SyncProviderKind.webDav);
      expect(
        status.lastFailure,
        isA<SyncRunException>().having(
          (error) => error.code,
          'code',
          'sync.remote_vault_schema_unsupported',
        ),
      );
      expect(
        status.lastFailureMessage,
        contains('Update Serlink before syncing'),
      );
      final localVault =
          container.read(vaultSessionControllerProvider.notifier).service
              as InMemoryVaultService;
      expect(
        await _localHostName(
          database: database,
          vault: localVault,
          id: cloudKitId,
        ),
        'cloudkit-before-newer-webdav.example.test',
      );
      expect(await DriftVaultRecordRepository(database).read(webDavId), isNull);
      expect(
        await _remoteHeaderSchemaVersion(provider: webDavProvider),
        sourceVault.header!.schemaVersion + 1,
      );
    },
  );

  test('auto sync propagates a WebDAV remote reset to CloudKit', () async {
    final sourceVault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    await sourceVault.initialize(passphrase: 'good passphrase');
    final records = InMemoryVaultRecordRepository();
    await records.upsert(
      await sourceVault.encryptRecord(
        id: VaultRecordId('host:reset-shared'),
        type: 'host',
        plaintext: utf8.encode('{"hostname":"reset-shared.example.test"}'),
      ),
    );
    final cloudKitProvider = LocalDirectorySyncProvider(cloudKitDir);
    final webDavProvider = LocalDirectorySyncProvider(webDavDir);
    final sourceService = SyncRunService(vault: sourceVault, records: records);
    await sourceService.pushEncryptedSnapshot(cloudKitProvider);
    await sourceService.pushEncryptedSnapshot(webDavProvider);
    await sourceService.publishRemoteReset(webDavProvider);

    final database = SerlinkDatabase(NativeDatabase.memory());
    final transferQueue = TransferQueueController();
    final container = _createDualSyncContainer(
      database: database,
      transferQueue: transferQueue,
      cloudKitDir: cloudKitDir,
      webDavDir: webDavDir,
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    await container.read(vaultSessionControllerProvider.future);
    await container
        .read(vaultSessionControllerProvider.notifier)
        .unlock(passphrase: 'good passphrase');
    await container
        .read(syncSettingsServiceProvider)
        .saveWebDav(
          const WebDavSyncSettingsDraft(
            endpoint: 'https://dav.example.test',
            username: 'ops',
            password: 'server-password',
          ),
        );
    container.read(autoSyncControllerProvider);
    container
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);

    await _waitForVaultState(container, VaultState.uninitialized);
    expect(
      RemoteResetMarker.fromBytes(
        await cloudKitProvider.readObject(resetMarkerRef),
      ).vaultId,
      syncVaultId(sourceVault.header!),
    );
    expect(await DriftVaultRecordRepository(database).list(), isEmpty);
  });

  test(
    'auto sync keeps local vault when remote reset cannot fan out',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'good passphrase');
      final records = InMemoryVaultRecordRepository();
      await records.upsert(
        await sourceVault.encryptRecord(
          id: VaultRecordId('host:reset-shared'),
          type: 'host',
          plaintext: utf8.encode('{"hostname":"reset-shared.example.test"}'),
        ),
      );
      final cloudKitProvider = LocalDirectorySyncProvider(cloudKitDir);
      final webDavProvider = LocalDirectorySyncProvider(webDavDir);
      final sourceService = SyncRunService(
        vault: sourceVault,
        records: records,
      );
      await sourceService.pushEncryptedSnapshot(cloudKitProvider);
      await sourceService.pushEncryptedSnapshot(webDavProvider);
      await sourceService.publishRemoteReset(webDavProvider);

      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final container = _createDualSyncContainer(
        database: database,
        transferQueue: transferQueue,
        cloudKitDir: cloudKitDir,
        webDavDir: webDavDir,
        failCloudKitResetMarkerWrites: true,
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      await container.read(vaultSessionControllerProvider.future);
      await container
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: 'good passphrase');
      await container
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            const WebDavSyncSettingsDraft(
              endpoint: 'https://dav.example.test',
              username: 'ops',
              password: 'server-password',
            ),
          );
      container.read(autoSyncControllerProvider);
      container
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);

      await _waitForAutoSyncPhase(container, AutoSyncPhase.failed);
      expect(
        container.read(vaultSessionControllerProvider).requireValue.vaultState,
        VaultState.unlocked,
      );
      expect(await DriftVaultRecordRepository(database).list(), isNotEmpty);
      expect(
        () async => cloudKitProvider.readObject(resetMarkerRef),
        throwsA(isA<SyncProviderException>()),
      );
    },
  );
}

ProviderContainer _createDualSyncContainer({
  required SerlinkDatabase database,
  required TransferQueueController transferQueue,
  required Directory cloudKitDir,
  required Directory webDavDir,
  bool failCloudKitResetMarkerWrites = false,
}) {
  return ProviderContainer(
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
        () => _KindOverrideSyncProvider(
          LocalDirectorySyncProvider(cloudKitDir),
          SyncProviderKind.cloudKit,
          failResetMarkerWrites: failCloudKitResetMarkerWrites,
        ),
      ),
      webDavSyncProviderFactoryProvider.overrideWithValue(
        (_) async => _KindOverrideSyncProvider(
          LocalDirectorySyncProvider(webDavDir),
          SyncProviderKind.webDav,
        ),
      ),
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      transferQueueControllerProvider.overrideWithValue(transferQueue),
      autoSyncDebounceDurationProvider.overrideWithValue(
        const Duration(days: 1),
      ),
      autoSyncIntervalDurationProvider.overrideWithValue(
        const Duration(days: 1),
      ),
      cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
    ],
  );
}

Future<void> _publishRemoteHost({
  required InMemoryVaultService vault,
  required LocalDirectorySyncProvider provider,
  required VaultRecordId id,
  required String hostname,
}) async {
  final records = InMemoryVaultRecordRepository();
  await records.upsert(
    await vault.encryptRecord(
      id: id,
      type: 'host',
      plaintext: utf8.encode('{"hostname":"$hostname"}'),
    ),
  );
  await SyncRunService(
    vault: vault,
    records: records,
  ).pushEncryptedSnapshot(provider);
}

Future<void> _waitForAutoSyncIdle(ProviderContainer container) async {
  await _waitForAutoSyncPhase(container, AutoSyncPhase.idle);
}

Future<void> _waitForAutoSyncPhase(
  ProviderContainer container,
  AutoSyncPhase expected,
) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    final status = container.read(autoSyncControllerProvider);
    if (status.phase == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  final status = container.read(autoSyncControllerProvider);
  fail(
    'Expected auto-sync phase $expected but found ${status.phase}. '
    'Failure: ${status.lastFailureMessage}.',
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
  final status = container.read(autoSyncControllerProvider);
  fail(
    'Expected vault state $expected but found ${state?.vaultState}. '
    'Auto-sync phase: ${status.phase}, failure: ${status.lastFailureMessage}.',
  );
}

Future<void> _waitForLocalRecords(
  SerlinkDatabase database,
  List<VaultRecordId> ids,
) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    final records = DriftVaultRecordRepository(database);
    var allPresent = true;
    for (final id in ids) {
      allPresent = allPresent && await records.read(id) != null;
    }
    if (allPresent) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected records ${ids.map((id) => id.value).join(', ')}.');
}

Future<List<String>> _manifestRecordIds({
  required LocalDirectorySyncProvider provider,
  required InMemoryVaultService vault,
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
  return [
    for (final raw in entries) (raw as Map<String, Object?>)['id'] as String,
  ];
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

Future<String> _remoteHostName({
  required LocalDirectorySyncProvider provider,
  required InMemoryVaultService vault,
  required VaultRecordId id,
}) async {
  final envelope = VaultRecordEnvelope.fromJson(
    jsonDecode(
          utf8.decode(
            await provider.readObject(
              await _manifestRecordRef(
                provider: provider,
                vault: vault,
                id: id,
              ),
            ),
          ),
        )
        as Map<String, Object?>,
  );
  final data =
      jsonDecode(utf8.decode(await vault.decryptRecord(envelope)))
          as Map<String, Object?>;
  return data['hostname'] as String;
}

Future<String> _localHostName({
  required SerlinkDatabase database,
  required InMemoryVaultService vault,
  required VaultRecordId id,
}) async {
  final envelope = await DriftVaultRecordRepository(database).read(id);
  expect(envelope, isNotNull);
  final data =
      jsonDecode(utf8.decode(await vault.decryptRecord(envelope!)))
          as Map<String, Object?>;
  return data['hostname'] as String;
}

Future<void> _writeRemoteHeaderSchemaVersion({
  required LocalDirectorySyncProvider provider,
  required InMemoryVaultService vault,
  required int schemaVersion,
}) async {
  final manifest = await provider.readManifest();
  expect(manifest, isNotNull);
  await provider.writeObject(
    RemoteObjectRef(manifest!.headerPath!),
    utf8.encode(
      jsonEncode(vault.header!.copyWith(schemaVersion: schemaVersion).toJson()),
    ),
  );
}

Future<int> _remoteHeaderSchemaVersion({
  required LocalDirectorySyncProvider provider,
}) async {
  final manifest = await provider.readManifest();
  expect(manifest, isNotNull);
  final header = VaultHeader.fromJson(
    jsonDecode(
          utf8.decode(
            await provider.readObject(RemoteObjectRef(manifest!.headerPath!)),
          ),
        )
        as Map<String, Object?>,
  );
  return header.schemaVersion;
}

class _KindOverrideSyncProvider implements SyncProvider {
  const _KindOverrideSyncProvider(
    this.inner,
    this.kind, {
    this.failResetMarkerWrites = false,
  });

  final LocalDirectorySyncProvider inner;
  final SyncProviderKind kind;
  final bool failResetMarkerWrites;

  @override
  Future<ProviderCapabilities> capabilities() async {
    final capabilities = await inner.capabilities();
    return ProviderCapabilities(
      kind: kind,
      supportsConditionalWrites: capabilities.supportsConditionalWrites,
      requiresTls: capabilities.requiresTls,
    );
  }

  @override
  Future<RemoteManifest?> readManifest() => inner.readManifest();

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
    return inner.readObject(ref);
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) {
    if (failResetMarkerWrites && ref.path == resetMarkerRef.path) {
      throw const SyncProviderException(
        'sync.provider.unavailable',
        'CloudKit is unavailable.',
      );
    }
    return inner.writeObject(ref, bytes);
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) {
    return inner.deleteObject(ref);
  }
}
