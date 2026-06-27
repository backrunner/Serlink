import '../../../core/ids/entity_id.dart';
import '../domain/sync_provider.dart';

class SyncRecordBaseline {
  const SyncRecordBaseline({
    required this.providerKind,
    required this.vaultId,
    required this.recordId,
    required this.recordType,
    required this.revision,
    required this.modifiedAt,
    required this.updatedAt,
  });

  final SyncProviderKind providerKind;
  final String vaultId;
  final VaultRecordId recordId;
  final String recordType;
  final String revision;
  final DateTime? modifiedAt;
  final DateTime updatedAt;
}

class SyncRecordBaselineEntry {
  const SyncRecordBaselineEntry({
    required this.recordId,
    required this.recordType,
    required this.revision,
    required this.modifiedAt,
  });

  final VaultRecordId recordId;
  final String recordType;
  final String revision;
  final DateTime? modifiedAt;
}

abstract interface class SyncRecordBaselineRepository {
  Future<Map<VaultRecordId, SyncRecordBaseline>> readForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
  });

  Future<void> replaceForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
    required Iterable<SyncRecordBaselineEntry> records,
  });

  Future<void> clearForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
  });
}

class InMemorySyncRecordBaselineRepository
    implements SyncRecordBaselineRepository {
  final Map<_SyncRecordBaselineKey, SyncRecordBaseline> _records = {};

  @override
  Future<Map<VaultRecordId, SyncRecordBaseline>> readForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    return {
      for (final entry in _records.entries)
        if (entry.key.providerKind == providerKind &&
            entry.key.vaultId == vaultId)
          entry.key.recordId: entry.value,
    };
  }

  @override
  Future<void> replaceForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
    required Iterable<SyncRecordBaselineEntry> records,
  }) async {
    await clearForVault(providerKind: providerKind, vaultId: vaultId);
    final updatedAt = DateTime.now().toUtc();
    for (final record in records) {
      final key = _SyncRecordBaselineKey(
        providerKind: providerKind,
        vaultId: vaultId,
        recordId: record.recordId,
      );
      _records[key] = SyncRecordBaseline(
        providerKind: providerKind,
        vaultId: vaultId,
        recordId: record.recordId,
        recordType: record.recordType,
        revision: record.revision,
        modifiedAt: record.modifiedAt?.toUtc(),
        updatedAt: updatedAt,
      );
    }
  }

  @override
  Future<void> clearForVault({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    _records.removeWhere(
      (key, _) => key.providerKind == providerKind && key.vaultId == vaultId,
    );
  }
}

class _SyncRecordBaselineKey {
  const _SyncRecordBaselineKey({
    required this.providerKind,
    required this.vaultId,
    required this.recordId,
  });

  final SyncProviderKind providerKind;
  final String vaultId;
  final VaultRecordId recordId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SyncRecordBaselineKey &&
            other.providerKind == providerKind &&
            other.vaultId == vaultId &&
            other.recordId == recordId;
  }

  @override
  int get hashCode => Object.hash(providerKind, vaultId, recordId);
}
