import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/identity.dart';

abstract interface class IdentityRepository {
  Future<void> save(IdentityConfig identity);
  Future<IdentityConfig?> read(IdentityId id);
  Future<List<IdentityConfig>> list();
  Future<void> delete(IdentityId id);
}

class EncryptedIdentityRepository implements IdentityRepository {
  EncryptedIdentityRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedIdentityRepository._(this._vault, this._records);

  static const recordType = 'identity';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<void> save(IdentityConfig identity) async {
    final envelope = await _vault.encryptRecord(
      id: _recordId(identity.id),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(identity.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<IdentityConfig?> read(IdentityId id) async {
    final envelope = await _records.read(_recordId(id));
    if (envelope == null) {
      return null;
    }
    return _decode(envelope);
  }

  @override
  Future<List<IdentityConfig>> list() async {
    final envelopes = await _records.list(type: recordType);
    return [for (final envelope in envelopes) await _decode(envelope)];
  }

  @override
  Future<void> delete(IdentityId id) async {
    await _records.delete(_recordId(id));
  }

  Future<IdentityConfig> _decode(VaultRecordEnvelope envelope) async {
    final plaintext = await _vault.decryptRecord(envelope);
    return IdentityConfig.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
    );
  }
}

VaultRecordId _recordId(IdentityId id) {
  return VaultRecordId('identity:${id.value}');
}
