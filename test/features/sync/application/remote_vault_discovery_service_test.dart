import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sync/application/remote_vault_discovery_service.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/local_sync_provider.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late Directory tempDir;
  late InMemoryVaultService vault;
  late LocalDirectorySyncProvider provider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'serlink-remote-discovery-test-',
    );
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    provider = LocalDirectorySyncProvider(tempDir);
    await SyncRunService(
      vault: vault,
      records: InMemoryVaultRecordRepository(),
    ).pushEncryptedSnapshot(provider);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'discovers legacy vault header path when manifest has no headerPath',
    () async {
      final manifest = await provider.readManifest();
      expect(manifest, isNotNull);
      final headerBytes = await provider.readObject(
        RemoteObjectRef(manifest!.headerPath!),
      );
      await provider.writeObject(
        RemoteVaultDiscoveryService.legacyHeaderRef,
        headerBytes,
      );
      await provider.writeManifest(
        RemoteManifest(
          vaultId: manifest.vaultId,
          protocolVersion: manifest.protocolVersion,
          encryptedPayload: manifest.encryptedPayload,
        ),
      );

      final discovery = await RemoteVaultDiscoveryService(provider).discover();

      expect(discovery, isNotNull);
      expect(syncVaultId(discovery!.header), manifest.vaultId);
    },
  );

  test(
    'rejects manifest header paths outside the sync header directory',
    () async {
      final manifest = await provider.readManifest();
      expect(manifest, isNotNull);
      await provider.writeObject(
        const RemoteObjectRef('vault/other.json'),
        utf8.encode(jsonEncode(vault.header!.toJson())),
      );
      await provider.writeManifest(
        RemoteManifest(
          vaultId: manifest!.vaultId,
          protocolVersion: manifest.protocolVersion,
          headerPath: 'vault/other.json',
          encryptedPayload: manifest.encryptedPayload,
        ),
      );

      await expectLater(
        RemoteVaultDiscoveryService(provider).discover(),
        throwsA(
          isA<SyncRunException>().having(
            (error) => error.code,
            'code',
            'sync.remote_header_invalid',
          ),
        ),
      );
    },
  );
}
