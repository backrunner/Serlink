import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/database_recovery.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/import_export/application/automatic_vault_backup_service.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/local_sync_provider.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_health_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'serlink-record-health-test-',
    );
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'good passphrase');
    records = InMemoryVaultRecordRepository();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reports authentication failures as corrupt records', () async {
    final valid = await vault.encryptRecord(
      id: VaultRecordId('host:valid'),
      type: 'host',
      plaintext: utf8.encode('valid'),
    );
    final corrupt = _withTamperedCiphertext(
      await vault.encryptRecord(
        id: VaultRecordId('host:corrupt'),
        type: 'host',
        plaintext: utf8.encode('corrupt'),
      ),
    );
    await records.upsert(valid);
    await records.upsert(corrupt);

    final report = await VaultRecordHealthService(
      vault: vault,
      records: records,
    ).inspect();

    expect(report.validCount, 1);
    expect(report.unsupportedRecords, isEmpty);
    expect(report.corruptRecords, hasLength(1));
    expect(report.corruptRecords.single.id, VaultRecordId('host:corrupt'));
    expect(
      report.corruptRecords.single.code,
      'vault.record_authentication_failed',
    );
  });

  test('quarantines corrupt records after creating a safety backup', () async {
    final databaseFile = File(p.join(tempDir.path, 'serlink.sqlite'));
    _createValidDatabase(databaseFile);
    final backups = AutomaticVaultBackupService(
      recovery: DatabaseRecoveryService(
        databaseFile: databaseFile,
        automaticBackupDirectory: Directory(
          p.join(tempDir.path, 'backups', 'automatic'),
        ),
        quarantineDirectory: Directory(p.join(tempDir.path, 'quarantine')),
      ),
    );
    final quarantine = _InMemoryVaultRecordQuarantineRepository();
    final valid = await vault.encryptRecord(
      id: VaultRecordId('host:valid'),
      type: 'host',
      plaintext: utf8.encode('valid'),
    );
    final corrupt = _withTamperedCiphertext(
      await vault.encryptRecord(
        id: VaultRecordId('host:corrupt'),
        type: 'host',
        plaintext: utf8.encode('corrupt'),
      ),
    );
    await records.upsert(valid);
    await records.upsert(corrupt);

    final report = await VaultRecordHealthService(
      vault: vault,
      records: records,
      quarantine: quarantine,
      backups: backups,
    ).quarantineCorruptRecords();

    expect(report.isHealthy, isTrue);
    expect(await records.read(valid.id), isNotNull);
    expect(await records.read(corrupt.id), isNull);
    final quarantined = await quarantine.list();
    expect(quarantined, hasLength(1));
    expect(quarantined.single.envelope.id, corrupt.id);
    expect(quarantined.single.reason, VaultRecoveryStatus.recordsCorrupt.name);
    expect(
      (await backups.list()).map((entry) => entry.reason),
      contains('before-record-quarantine'),
    );
  });

  test(
    'restores corrupt records from automatic backup before quarantine',
    () async {
      final databaseFile = File(p.join(tempDir.path, 'serlink.sqlite'));
      final original = await vault.encryptRecord(
        id: VaultRecordId('host:recoverable'),
        type: 'host',
        plaintext: utf8.encode('from backup'),
      );
      await _writeRecordDatabase(databaseFile, original);
      final backups = AutomaticVaultBackupService(
        recovery: DatabaseRecoveryService(
          databaseFile: databaseFile,
          automaticBackupDirectory: Directory(
            p.join(tempDir.path, 'backups', 'automatic'),
          ),
          quarantineDirectory: Directory(p.join(tempDir.path, 'quarantine')),
        ),
      );
      await backups.createSnapshot(reason: 'automatic');
      final quarantine = _InMemoryVaultRecordQuarantineRepository();
      await records.upsert(_withTamperedCiphertext(original));

      final report = await VaultRecordHealthService(
        vault: vault,
        records: records,
        quarantine: quarantine,
        backups: backups,
      ).quarantineCorruptRecords();

      expect(report.isHealthy, isTrue);
      expect(await quarantine.list(), isEmpty);
      final restored = await records.read(original.id);
      expect(restored, isNotNull);
      expect(utf8.decode(await vault.decryptRecord(restored!)), 'from backup');
    },
  );

  test('restores corrupt records from remote before quarantine', () async {
    final remote = LocalDirectorySyncProvider(
      Directory(p.join(tempDir.path, 'remote')),
    );
    final quarantine = _InMemoryVaultRecordQuarantineRepository();
    final original = await vault.encryptRecord(
      id: VaultRecordId('host:remote-recoverable'),
      type: 'host',
      plaintext: utf8.encode('from remote'),
    );
    final remoteRecords = InMemoryVaultRecordRepository();
    await remoteRecords.upsert(original);
    await SyncRunService(
      vault: vault,
      records: remoteRecords,
    ).pushEncryptedSnapshot(remote);
    await records.upsert(_withTamperedCiphertext(original));

    final report = await VaultRecordHealthService(
      vault: vault,
      records: records,
      quarantine: quarantine,
      remote: remote,
    ).quarantineCorruptRecords();

    expect(report.isHealthy, isTrue);
    expect(await quarantine.list(), isEmpty);
    final restored = await records.read(original.id);
    expect(restored, isNotNull);
    expect(utf8.decode(await vault.decryptRecord(restored!)), 'from remote');
  });

  test(
    'does not restore corrupt records from unsupported remote protocol',
    () async {
      final remote = LocalDirectorySyncProvider(
        Directory(p.join(tempDir.path, 'remote')),
      );
      final quarantine = _InMemoryVaultRecordQuarantineRepository();
      final original = await vault.encryptRecord(
        id: VaultRecordId('host:remote-future-protocol'),
        type: 'host',
        plaintext: utf8.encode('from remote'),
      );
      final remoteRecords = InMemoryVaultRecordRepository();
      await remoteRecords.upsert(original);
      await SyncRunService(
        vault: vault,
        records: remoteRecords,
      ).pushEncryptedSnapshot(remote);
      final manifest = await remote.readManifest();
      await remote.writeManifest(
        RemoteManifest(
          vaultId: manifest!.vaultId,
          protocolVersion: 2,
          encryptedPayload: manifest.encryptedPayload,
        ),
      );
      await records.upsert(_withTamperedCiphertext(original));

      final report = await VaultRecordHealthService(
        vault: vault,
        records: records,
        quarantine: quarantine,
        remote: remote,
      ).quarantineCorruptRecords();

      expect(report.isHealthy, isTrue);
      expect(await records.read(original.id), isNull);
      final quarantined = await quarantine.list();
      expect(quarantined, hasLength(1));
      expect(quarantined.single.envelope.id, original.id);
    },
  );
}

VaultRecordEnvelope _withTamperedCiphertext(VaultRecordEnvelope envelope) {
  final ciphertext = [...envelope.ciphertext];
  ciphertext[0] = ciphertext[0] ^ 0x01;
  return VaultRecordEnvelope(
    id: envelope.id,
    type: envelope.type,
    schemaVersion: envelope.schemaVersion,
    revision: envelope.revision,
    nonce: envelope.nonce,
    mac: envelope.mac,
    associatedData: envelope.associatedData,
    ciphertext: List<int>.unmodifiable(ciphertext),
  );
}

void _createValidDatabase(File file) {
  final database = sqlite3.open(file.path);
  try {
    database
      ..execute('CREATE TABLE markers (value TEXT NOT NULL)')
      ..execute("INSERT INTO markers (value) VALUES ('snapshot-source')")
      ..execute('PRAGMA user_version = 2');
  } finally {
    database.close();
  }
}

Future<void> _writeRecordDatabase(
  File file,
  VaultRecordEnvelope envelope,
) async {
  final database = SerlinkDatabase(NativeDatabase(file));
  try {
    await DriftVaultRecordRepository(database).upsert(envelope);
  } finally {
    await database.close();
  }
}

class _InMemoryVaultRecordQuarantineRepository
    implements VaultRecordQuarantineRepository {
  final List<QuarantinedVaultRecord> _records = [];

  @override
  Future<void> quarantine({
    required VaultRecordEnvelope envelope,
    required String reason,
  }) async {
    _records.add(
      QuarantinedVaultRecord(
        envelope: envelope,
        quarantinedAt: DateTime.utc(2026, 6, 9),
        reason: reason,
      ),
    );
  }

  @override
  Future<List<QuarantinedVaultRecord>> list() async {
    return List.unmodifiable(_records);
  }
}
