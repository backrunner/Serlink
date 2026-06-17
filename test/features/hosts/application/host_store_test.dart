import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/application/host_store.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  test(
    'host summaries refresh on vault record changes without locking vault',
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
              operatingSystem: 'linux',
              targetPlatform: TargetPlatform.linux,
            ),
          ),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(transferQueue.dispose);
      addTearDown(database.close);

      expect(
        await container.read(vaultSessionControllerProvider.future),
        isA<VaultSessionState>().having(
          (state) => state.vaultState,
          'vaultState',
          VaultState.uninitialized,
        ),
      );

      await container
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: 'good passphrase');
      final session = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(session.vaultState, VaultState.unlocked);

      final generation = session.unlockGeneration;
      expect(
        await container.read(hostSummariesProvider(generation).future),
        isEmpty,
      );

      final remoteHost = _host(
        id: HostId('remote'),
        displayName: 'Remote Host',
        hostname: 'remote.example.test',
      );
      final vault = container
          .read(vaultSessionControllerProvider.notifier)
          .service;
      final envelope = await vault.encryptRecord(
        id: VaultRecordId('host:${remoteHost.id.value}'),
        type: EncryptedHostRepository.recordType,
        plaintext: utf8.encode(jsonEncode(remoteHost.toJson())),
      );

      await container.read(vaultRecordRepositoryProvider).upsert(envelope);
      await _drainMicrotasks();

      final refreshed = await container.read(
        hostSummariesProvider(generation).future,
      );
      expect(refreshed, hasLength(1));
      expect(refreshed.single.displayName, 'Remote Host');
      expect(refreshed.single.hostname, 'remote.example.test');

      final afterSync = container
          .read(vaultSessionControllerProvider)
          .requireValue;
      expect(afterSync.vaultState, VaultState.unlocked);
      expect(afterSync.unlockGeneration, generation);
      expect(vault.state, VaultState.unlocked);
    },
  );
}

HostConfig _host({
  required HostId id,
  required String displayName,
  required String hostname,
}) {
  final now = DateTime.utc(2026, 6, 18, 12);
  return HostConfig(
    id: id,
    displayName: displayName,
    hostname: hostname,
    username: 'ops',
    port: 22,
    authKinds: const {HostAuthKind.password},
    tags: const {},
    trustState: HostTrustState.trusted,
    identityIds: const [],
    startupCommands: const [],
    jumpHostIds: const [],
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _drainMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
