import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/host.dart';

abstract interface class HostRepository {
  Future<void> save(HostConfig host);
  Future<HostConfig?> read(HostId id);
  Future<List<HostConfig>> list();
  Future<void> delete(HostId id);
}

class EncryptedHostRepository implements HostRepository {
  EncryptedHostRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedHostRepository._(this._vault, this._records);

  static const recordType = 'host';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<void> save(HostConfig host) async {
    final envelope = await _vault.encryptRecord(
      id: _recordId(host.id),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(host.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<HostConfig?> read(HostId id) async {
    final envelope = await _records.read(_recordId(id));
    if (envelope == null) {
      return null;
    }
    return _decode(envelope);
  }

  @override
  Future<List<HostConfig>> list() async {
    final envelopes = await _records.list(type: recordType);
    return [for (final envelope in envelopes) await _decode(envelope)];
  }

  @override
  Future<void> delete(HostId id) async {
    await _records.delete(_recordId(id));
  }

  Future<HostConfig> _decode(VaultRecordEnvelope envelope) async {
    final plaintext = await _vault.decryptRecord(envelope);
    return HostConfig.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
    );
  }
}

VaultRecordId _recordId(HostId id) => VaultRecordId('host:${id.value}');
