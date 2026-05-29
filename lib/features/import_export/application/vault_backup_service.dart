import 'dart:convert';

import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../../vault/data/drift_vault_repository.dart';

class VaultBackupBundle {
  const VaultBackupBundle({
    required this.formatVersion,
    required this.exportedAt,
    required this.header,
    required this.records,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final VaultHeader header;
  final List<VaultRecordEnvelope> records;

  Map<String, Object?> toJson() {
    return {
      'formatVersion': formatVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'header': header.toJson(),
      'records': [for (final record in records) record.toJson()],
    };
  }

  factory VaultBackupBundle.fromJson(Map<String, Object?> json) {
    return VaultBackupBundle(
      formatVersion: json['formatVersion'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      header: VaultHeader.fromJson(json['header'] as Map<String, Object?>),
      records: [
        for (final value in json['records'] as List<Object?>)
          VaultRecordEnvelope.fromJson(value as Map<String, Object?>),
      ],
    );
  }

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  factory VaultBackupBundle.fromBytes(List<int> bytes) {
    return VaultBackupBundle.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
    );
  }
}

class VaultBackupService {
  VaultBackupService({
    required VaultHeaderStore headers,
    required VaultRecordRepository records,
  }) : this._(headers, records);

  VaultBackupService._(this._headers, this._records);

  final VaultHeaderStore _headers;
  final VaultRecordRepository _records;

  Future<VaultBackupBundle> exportBackup() async {
    final header = await _headers.read();
    if (header == null) {
      throw const VaultException(
        'vault_backup.missing_header',
        'Cannot export a vault backup without a vault header.',
      );
    }
    return VaultBackupBundle(
      formatVersion: 1,
      exportedAt: DateTime.now().toUtc(),
      header: header,
      records: await _records.list(),
    );
  }

  Future<void> importBackup(VaultBackupBundle bundle) async {
    if (bundle.formatVersion != 1) {
      throw VaultException(
        'vault_backup.unsupported_version',
        'Unsupported vault backup version: ${bundle.formatVersion}.',
      );
    }
    await _headers.save(bundle.header);
    for (final record in bundle.records) {
      await _records.upsert(record);
    }
  }
}
