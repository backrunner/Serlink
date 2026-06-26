import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sync/application/sync_settings_service.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/local_sync_provider.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  late Directory cloudKitDir;

  setUp(() async {
    cloudKitDir = await Directory.systemTemp.createTemp(
      'serlink-sync-metadata-cloudkit-test-',
    );
  });

  tearDown(() async {
    if (await cloudKitDir.exists()) {
      await cloudKitDir.delete(recursive: true);
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
}
