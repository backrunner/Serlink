import '../../../core/ids/entity_id.dart';
import 'vault_service.dart';

abstract interface class VaultRecordRepository {
  Future<void> upsert(VaultRecordEnvelope envelope);
  Future<VaultRecordEnvelope?> read(VaultRecordId id);
  Future<List<VaultRecordEnvelope>> list({String? type});
  Future<void> delete(VaultRecordId id);
}

class InMemoryVaultRecordRepository implements VaultRecordRepository {
  final Map<VaultRecordId, VaultRecordEnvelope> _records = {};

  @override
  Future<void> upsert(VaultRecordEnvelope envelope) async {
    _records[envelope.id] = envelope;
  }

  @override
  Future<VaultRecordEnvelope?> read(VaultRecordId id) async {
    return _records[id];
  }

  @override
  Future<List<VaultRecordEnvelope>> list({String? type}) async {
    return [
      for (final record in _records.values)
        if (type == null || record.type == type) record,
    ];
  }

  @override
  Future<void> delete(VaultRecordId id) async {
    _records.remove(id);
  }
}
