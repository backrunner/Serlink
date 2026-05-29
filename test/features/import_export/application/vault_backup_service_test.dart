import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/import_export/application/vault_backup_service.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';

void main() {
  late SerlinkDatabase sourceDatabase;
  late SerlinkDatabase targetDatabase;
  late Directory tempDir;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('serlink-backup-test-');
    sourceDatabase = SerlinkDatabase(
      NativeDatabase(File('${tempDir.path}/source.sqlite')),
    );
    targetDatabase = SerlinkDatabase(
      NativeDatabase(File('${tempDir.path}/target.sqlite')),
    );
  });

  tearDown(() async {
    await sourceDatabase.close();
    await targetDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'exports and imports encrypted vault backup without plaintext',
    () async {
      final sourceVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await sourceVault.initialize(passphrase: 'good passphrase');

      final sourceHeaders = DriftVaultHeaderStore(sourceDatabase);
      final sourceRecords = DriftVaultRecordRepository(sourceDatabase);
      await sourceHeaders.save(sourceVault.header!);
      final sourceHosts = EncryptedHostRepository(
        vault: sourceVault,
        records: sourceRecords,
      );
      await sourceHosts.save(
        HostConfig(
          id: HostId('production'),
          displayName: 'Production Bastion',
          hostname: 'bastion.internal',
          username: 'ops-user-sensitive',
          port: 22,
          authKinds: const {HostAuthKind.privateKey},
          tags: const {'prod-sensitive-tag'},
          trustState: HostTrustState.trusted,
          identityIds: const [],
          startupCommands: const [],
          jumpHostIds: const [],
          createdAt: DateTime.utc(2026, 5, 27),
          updatedAt: DateTime.utc(2026, 5, 27),
        ),
      );

      final backupService = VaultBackupService(
        headers: sourceHeaders,
        records: sourceRecords,
      );
      final bundle = await backupService.exportBackup();
      final backupJson = jsonEncode(bundle.toJson());

      expect(backupJson, isNot(contains('Production Bastion')));
      expect(backupJson, isNot(contains('bastion.internal')));
      expect(backupJson, isNot(contains('ops-user-sensitive')));
      expect(backupJson, isNot(contains('prod-sensitive-tag')));

      final targetHeaders = DriftVaultHeaderStore(targetDatabase);
      final targetRecords = DriftVaultRecordRepository(targetDatabase);
      await VaultBackupService(
        headers: targetHeaders,
        records: targetRecords,
      ).importBackup(VaultBackupBundle.fromBytes(bundle.toBytes()));

      final restoredHeader = await targetHeaders.read();
      final targetVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
        header: restoredHeader,
      );
      await targetVault.unlock(passphrase: 'good passphrase');
      final targetHosts = EncryptedHostRepository(
        vault: targetVault,
        records: targetRecords,
      );

      final restoredHosts = await targetHosts.list();
      expect(restoredHosts, hasLength(1));
      expect(restoredHosts.single.hostname, 'bastion.internal');
    },
  );
}
