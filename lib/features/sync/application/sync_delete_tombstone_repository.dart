import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';

class SyncDeleteTombstone {
  const SyncDeleteTombstone({
    required this.targetRecordId,
    required this.targetRecordType,
    required this.deletedAt,
  });

  final VaultRecordId targetRecordId;
  final String targetRecordType;
  final DateTime deletedAt;

  Map<String, Object?> toJson() {
    return {
      'targetRecordId': targetRecordId.value,
      'targetRecordType': targetRecordType,
      'deletedAt': deletedAt.toUtc().toIso8601String(),
    };
  }

  factory SyncDeleteTombstone.fromJson(Map<String, Object?> json) {
    return SyncDeleteTombstone(
      targetRecordId: VaultRecordId(json['targetRecordId'] as String),
      targetRecordType: json['targetRecordType'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String),
    );
  }
}

abstract interface class SyncDeleteTombstoneRepository {
  Future<void> save(SyncDeleteTombstone tombstone);
  Future<List<SyncDeleteTombstone>> list();
}

class EncryptedSyncDeleteTombstoneRepository
    implements SyncDeleteTombstoneRepository {
  EncryptedSyncDeleteTombstoneRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedSyncDeleteTombstoneRepository._(this._vault, this._records);

  static const recordType = 'sync_tombstone';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<void> save(SyncDeleteTombstone tombstone) async {
    final envelope = await _vault.encryptRecord(
      id: tombstoneRecordId(tombstone.targetRecordId),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(tombstone.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<List<SyncDeleteTombstone>> list() async {
    final envelopes = await _records.list(type: recordType);
    final tombstones = <SyncDeleteTombstone>[];
    for (final envelope in envelopes) {
      final plaintext = await _vault.decryptRecord(envelope);
      tombstones.add(
        SyncDeleteTombstone.fromJson(
          jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
        ),
      );
    }
    tombstones.sort(
      (left, right) => left.deletedAt.compareTo(right.deletedAt) != 0
          ? left.deletedAt.compareTo(right.deletedAt)
          : left.targetRecordId.value.compareTo(right.targetRecordId.value),
    );
    return tombstones;
  }
}

VaultRecordId tombstoneRecordId(VaultRecordId targetRecordId) {
  return VaultRecordId(
    'sync:tombstone:${Uri.encodeComponent(targetRecordId.value)}',
  );
}
