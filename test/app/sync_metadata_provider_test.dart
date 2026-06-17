import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
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
