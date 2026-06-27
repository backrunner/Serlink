import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';
import 'package:serlink/platform/secret_store.dart';

void main() {
  test('vault session supports passphrase and biometric unlock', () async {
    final database = SerlinkDatabase(NativeDatabase.memory());
    final transferQueue = TransferQueueController();
    final secretStore = InMemorySecretStore();
    final container = ProviderContainer(
      overrides: [
        serlinkDatabaseProvider.overrideWithValue(database),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        platformCapabilitiesProvider.overrideWithValue(
          const PlatformCapabilities(
            operatingSystem: 'windows',
            targetPlatform: TargetPlatform.windows,
          ),
        ),
        secretStoreProvider.overrideWithValue(secretStore),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        autoSyncEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(transferQueue.dispose);
    addTearDown(database.close);

    await container.read(vaultSessionControllerProvider.future);
    await container
        .read(vaultSessionControllerProvider.notifier)
        .initialize(passphrase: 'good passphrase');

    var session = container.read(vaultSessionControllerProvider).requireValue;
    expect(session.vaultState, VaultState.unlocked);
    expect(session.biometricUnlockSupported, isTrue);

    final enabled = await container
        .read(vaultSessionControllerProvider.notifier)
        .enableLocalUnlock();

    expect(enabled, isTrue);
    session = container.read(vaultSessionControllerProvider).requireValue;
    expect(session.localUnlockAvailable, isTrue);

    await container.read(vaultSessionControllerProvider.notifier).lock();
    session = container.read(vaultSessionControllerProvider).requireValue;
    expect(session.vaultState, VaultState.locked);
    expect(session.localUnlockAvailable, isTrue);

    await container
        .read(vaultSessionControllerProvider.notifier)
        .unlockWithLocalKey();
    session = container.read(vaultSessionControllerProvider).requireValue;
    expect(session.vaultState, VaultState.unlocked);

    await container.read(vaultSessionControllerProvider.notifier).lock();
    await container
        .read(vaultSessionControllerProvider.notifier)
        .unlock(passphrase: 'good passphrase');
    session = container.read(vaultSessionControllerProvider).requireValue;
    expect(session.vaultState, VaultState.unlocked);
  });

  test(
    'vault session coalesces concurrent biometric unlock requests',
    () async {
      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final secretStore = _CountingSecretStore();
      final container = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'windows',
              targetPlatform: TargetPlatform.windows,
            ),
          ),
          secretStoreProvider.overrideWithValue(secretStore),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      final controller = container.read(
        vaultSessionControllerProvider.notifier,
      );
      await container.read(vaultSessionControllerProvider.future);
      await controller.initialize(passphrase: 'good passphrase');
      expect(await controller.enableLocalUnlock(), isTrue);
      await controller.lock();
      secretStore.resetCounts();

      final firstUnlock = controller.unlockWithLocalKey();
      final secondUnlock = controller.unlockWithLocalKey();

      expect(identical(firstUnlock, secondUnlock), isTrue);

      await Future.wait([firstUnlock, secondUnlock]);

      final session = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(session.vaultState, VaultState.unlocked);
      expect(session.localUnlockAvailable, isTrue);
      expect(session.biometricUnlockSupported, isTrue);
      expect(secretStore.biometricReadCount, 1);
      expect(secretStore.biometricContainsCount, 0);
    },
  );

  test(
    'vault session automatically unlocks with local key on startup',
    () async {
      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final secretStore = _CountingSecretStore();
      final overrides = [
        serlinkDatabaseProvider.overrideWithValue(database),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        platformCapabilitiesProvider.overrideWithValue(
          const PlatformCapabilities(
            operatingSystem: 'windows',
            targetPlatform: TargetPlatform.windows,
          ),
        ),
        secretStoreProvider.overrideWithValue(secretStore),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        autoSyncEnabledProvider.overrideWithValue(false),
      ];
      final firstContainer = ProviderContainer(overrides: overrides);
      final secondContainer = ProviderContainer(overrides: overrides);
      addTearDown(firstContainer.dispose);
      addTearDown(secondContainer.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      final firstController = firstContainer.read(
        vaultSessionControllerProvider.notifier,
      );
      await firstContainer.read(vaultSessionControllerProvider.future);
      await firstController.initialize(passphrase: 'good passphrase');
      expect(await firstController.enableLocalUnlock(), isTrue);
      secretStore.resetCounts();

      final session = await secondContainer.read(
        vaultSessionControllerProvider.future,
      );

      expect(session.vaultState, VaultState.unlocked);
      expect(session.localUnlockAvailable, isTrue);
      expect(session.biometricUnlockSupported, isTrue);
      expect(secretStore.biometricReadCount, 1);
      expect(secretStore.biometricContainsCount, 0);
    },
  );

  test(
    'vault session sanitizes unsupported local unlock protectors on load',
    () async {
      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final secretStore = InMemorySecretStore();
      final bootstrapVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final initialized = await bootstrapVault.initialize(
        passphrase: 'good passphrase',
      );
      final legacyRef = const SecretRef('vault/local-unlock/legacy');
      await secretStore.write(legacyRef, [1, 2, 3]);

      final legacyHeader = VaultHeader.fromJson({
        ...initialized.header.toJson(),
        'localUnlockProtectors': [
          {
            'id': 'legacy-protector',
            'secretRef': legacyRef.value,
            'nonce': base64Encode(List<int>.filled(12, 1)),
            'mac': base64Encode(List<int>.filled(16, 2)),
            'ciphertext': base64Encode(List<int>.filled(32, 3)),
            'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ],
      });
      await DriftVaultHeaderStore(database).save(legacyHeader);

      final container = ProviderContainer(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'windows',
              targetPlatform: TargetPlatform.windows,
            ),
          ),
          secretStoreProvider.overrideWithValue(secretStore),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      final session = await container.read(
        vaultSessionControllerProvider.future,
      );

      expect(session.vaultState, VaultState.locked);
      expect(session.localUnlockAvailable, isFalse);
      expect(session.biometricUnlockSupported, isTrue);
      expect(
        container.read(vaultSessionControllerProvider.notifier).service.header,
        isNotNull,
      );
      expect(
        container
            .read(vaultSessionControllerProvider.notifier)
            .service
            .header!
            .localUnlockProtectors,
        isEmpty,
      );
      expect(await secretStore.read(legacyRef), isNull);

      final storedHeader = await DriftVaultHeaderStore(database).read();
      expect(storedHeader, isNotNull);
      expect(storedHeader!.localUnlockProtectors, isEmpty);
    },
  );
}

class _CountingSecretStore extends InMemorySecretStore {
  int biometricReadCount = 0;
  int biometricContainsCount = 0;

  void resetCounts() {
    biometricReadCount = 0;
    biometricContainsCount = 0;
  }

  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    if (protection == SecretProtection.biometricCurrentSet) {
      biometricReadCount += 1;
      await Future<void>.delayed(Duration.zero);
    }
    return super.read(ref, protection: protection);
  }

  @override
  Future<bool> contains(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    if (protection == SecretProtection.biometricCurrentSet) {
      biometricContainsCount += 1;
    }
    return super.contains(ref, protection: protection);
  }
}
