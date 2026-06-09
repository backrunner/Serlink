import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../../database/database_recovery.dart';
import '../../../core/ids/entity_id.dart';
import '../../import_export/application/automatic_vault_backup_service.dart';
import '../data/drift_vault_repository.dart';
import 'vault_record_repository.dart';
import 'vault_service.dart';

class VaultRecordHealthIssue {
  const VaultRecordHealthIssue({
    required this.id,
    required this.type,
    required this.revision,
    required this.code,
    required this.message,
  });

  final VaultRecordId id;
  final String type;
  final String revision;
  final String code;
  final String message;
}

class VaultRecordHealthReport {
  const VaultRecordHealthReport({
    required this.validCount,
    required this.corruptRecords,
    required this.unsupportedRecords,
  });

  final int validCount;
  final List<VaultRecordHealthIssue> corruptRecords;
  final List<VaultRecordHealthIssue> unsupportedRecords;

  bool get hasCorruptRecords => corruptRecords.isNotEmpty;
  bool get isHealthy => corruptRecords.isEmpty && unsupportedRecords.isEmpty;
}

class VaultRecordHealthService {
  const VaultRecordHealthService({
    required VaultService vault,
    required VaultRecordRepository records,
    VaultRecordQuarantineRepository? quarantine,
    AutomaticVaultBackupService? backups,
  }) : this._(vault, records, quarantine, backups);

  const VaultRecordHealthService._(
    this._vault,
    this._records,
    this._quarantine,
    this._backups,
  );

  final VaultService _vault;
  final VaultRecordRepository _records;
  final VaultRecordQuarantineRepository? _quarantine;
  final AutomaticVaultBackupService? _backups;

  Future<VaultRecordHealthReport> inspect() async {
    final envelopes = await _records.list();
    var validCount = 0;
    final corrupt = <VaultRecordHealthIssue>[];
    final unsupported = <VaultRecordHealthIssue>[];
    for (final envelope in envelopes) {
      try {
        await _vault.decryptRecord(envelope);
        validCount += 1;
      } on VaultException catch (error) {
        final issue = VaultRecordHealthIssue(
          id: envelope.id,
          type: envelope.type,
          revision: envelope.revision,
          code: error.code,
          message: error.message,
        );
        if (_isRecordCorruption(error)) {
          corrupt.add(issue);
        } else {
          unsupported.add(issue);
        }
      } on Object catch (error) {
        unsupported.add(
          VaultRecordHealthIssue(
            id: envelope.id,
            type: envelope.type,
            revision: envelope.revision,
            code: 'vault.record_unsupported',
            message: error.toString(),
          ),
        );
      }
    }
    return VaultRecordHealthReport(
      validCount: validCount,
      corruptRecords: List.unmodifiable(corrupt),
      unsupportedRecords: List.unmodifiable(unsupported),
    );
  }

  Future<VaultRecordHealthReport> quarantineCorruptRecords() async {
    final quarantine = _quarantine;
    if (quarantine == null) {
      throw const VaultException(
        'vault.record_quarantine_unavailable',
        'Vault record quarantine is not available.',
      );
    }
    final report = await inspect();
    if (!report.hasCorruptRecords) {
      return report;
    }
    await _backups?.createSnapshot(reason: 'before-record-quarantine');
    for (final issue in report.corruptRecords) {
      final restored = await _healthyRecordFromAutomaticBackups(issue);
      if (restored != null) {
        await _records.upsert(restored);
      }
    }
    final reportAfterRestore = await inspect();
    if (!reportAfterRestore.hasCorruptRecords) {
      return reportAfterRestore;
    }
    final corruptIds = {
      for (final issue in reportAfterRestore.corruptRecords) issue.id,
    };
    final envelopes = await _records.list();
    for (final envelope in envelopes) {
      if (!corruptIds.contains(envelope.id)) {
        continue;
      }
      await quarantine.quarantine(
        envelope: envelope,
        reason: VaultRecoveryStatus.recordsCorrupt.name,
      );
      await _records.delete(envelope.id);
    }
    return inspect();
  }

  Future<VaultRecordEnvelope?> _healthyRecordFromAutomaticBackups(
    VaultRecordHealthIssue issue,
  ) async {
    final backups = await _backups?.list() ?? const <DatabaseBackupEntry>[];
    for (final backup in backups) {
      final backupFile = File(backup.path);
      if (!await backupFile.exists()) {
        continue;
      }
      Database? database;
      try {
        database = sqlite3.open(backupFile.path, mode: OpenMode.readOnly);
        final rows = database.select(
          '''
          SELECT id, type, schema_version, revision, nonce, mac,
                 associated_data, ciphertext
          FROM encrypted_records
          WHERE id = ?
          ''',
          [issue.id.value],
        );
        if (rows.isEmpty) {
          continue;
        }
        final envelope = _envelopeFromBackupRow(rows.first);
        await _vault.decryptRecord(envelope);
        return envelope;
      } on VaultException catch (error) {
        if (_isRecordCorruption(error)) {
          continue;
        }
        continue;
      } on Object {
        continue;
      } finally {
        database?.close();
      }
    }
    return null;
  }
}

bool _isRecordCorruption(VaultException error) {
  return error.code == 'vault.record_metadata_tampered' ||
      error.code == 'vault.record_authentication_failed';
}

VaultRecordEnvelope _envelopeFromBackupRow(Row row) {
  return VaultRecordEnvelope(
    id: VaultRecordId(row['id'] as String),
    type: row['type'] as String,
    schemaVersion: row['schema_version'] as int,
    revision: row['revision'] as String,
    nonce: List<int>.unmodifiable(row['nonce'] as List<int>),
    mac: List<int>.unmodifiable(row['mac'] as List<int>),
    associatedData: List<int>.unmodifiable(row['associated_data'] as List<int>),
    ciphertext: List<int>.unmodifiable(row['ciphertext'] as List<int>),
  );
}
