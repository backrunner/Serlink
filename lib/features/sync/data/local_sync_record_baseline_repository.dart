import 'package:drift/drift.dart';

import '../../../core/ids/entity_id.dart';
import '../../../database/serlink_database.dart';
import '../application/encrypted_snapshot_staging.dart';
import '../application/sync_record_baseline_repository.dart';
import '../domain/sync_provider.dart';

class LocalSyncRecordBaselineRepository
    implements SyncRecordBaselineRepository {
  const LocalSyncRecordBaselineRepository(this._database);

  final SerlinkDatabase _database;

  @override
  Future<Map<VaultRecordId, SyncRecordBaseline>> readForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    final rows = await _database
        .customSelect(
          '''
SELECT record_id, record_type, revision, modified_at, updated_at
FROM sync_record_baselines
WHERE provider_kind = ? AND vault_id = ?
ORDER BY record_id ASC
''',
          variables: [
            Variable(syncProviderKindName(providerKind)),
            Variable(vaultId),
          ],
          readsFrom: const {},
        )
        .get();
    return {
      for (final row in rows)
        VaultRecordId(row.read<String>('record_id')): SyncRecordBaseline(
          providerKind: providerKind,
          vaultId: vaultId,
          recordId: VaultRecordId(row.read<String>('record_id')),
          recordType: row.read<String>('record_type'),
          revision: row.read<String>('revision'),
          modifiedAt: _parseOptionalUtc(row.read<String?>('modified_at')),
          updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
        ),
    };
  }

  @override
  Future<void> replaceForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
    required Iterable<SyncRecordBaselineEntry> records,
  }) async {
    final providerKindName = syncProviderKindName(providerKind);
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await _database.transaction(() async {
      await _database.customStatement(
        '''
DELETE FROM sync_record_baselines
WHERE provider_kind = ? AND vault_id = ?
''',
        [providerKindName, vaultId],
      );
      for (final record in records) {
        await _database.customStatement(
          '''
INSERT INTO sync_record_baselines (
  provider_kind,
  vault_id,
  record_id,
  record_type,
  revision,
  modified_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
''',
          [
            providerKindName,
            vaultId,
            record.recordId.value,
            record.recordType,
            record.revision,
            record.modifiedAt?.toUtc().toIso8601String(),
            updatedAt,
          ],
        );
      }
    });
  }

  @override
  Future<void> clearForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    await _database.customStatement(
      '''
DELETE FROM sync_record_baselines
WHERE provider_kind = ? AND vault_id = ?
''',
      [syncProviderKindName(providerKind), vaultId],
    );
  }
}

DateTime? _parseOptionalUtc(String? value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value).toUtc();
}
