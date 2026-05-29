import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';

class KnownHostRecord {
  const KnownHostRecord({
    required this.hostId,
    required this.hostname,
    required this.port,
    required this.algorithm,
    required this.fingerprint,
    required this.createdAt,
    required this.updatedAt,
  });

  final HostId hostId;
  final String hostname;
  final int port;
  final String algorithm;
  final String fingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;

  KnownHostRecord copyWith({
    String? hostname,
    int? port,
    String? algorithm,
    String? fingerprint,
    DateTime? updatedAt,
  }) {
    return KnownHostRecord(
      hostId: hostId,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      algorithm: algorithm ?? this.algorithm,
      fingerprint: fingerprint ?? this.fingerprint,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'hostId': hostId.value,
      'hostname': hostname,
      'port': port,
      'algorithm': algorithm,
      'fingerprint': fingerprint,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory KnownHostRecord.fromJson(Map<String, Object?> json) {
    return KnownHostRecord(
      hostId: HostId(json['hostId'] as String),
      hostname: json['hostname'] as String,
      port: json['port'] as int,
      algorithm: json['algorithm'] as String,
      fingerprint: json['fingerprint'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

abstract interface class KnownHostRepository {
  Future<KnownHostRecord?> read(HostId hostId);
  Future<List<KnownHostRecord>> list();
  Future<void> save(KnownHostRecord record);
  Future<void> delete(HostId hostId);
}

class EncryptedKnownHostRepository implements KnownHostRepository {
  EncryptedKnownHostRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedKnownHostRepository._(this._vault, this._records);

  static const recordType = 'known_host';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<KnownHostRecord?> read(HostId hostId) async {
    final envelope = await _records.read(_recordId(hostId));
    if (envelope == null) {
      return null;
    }
    final plaintext = await _vault.decryptRecord(envelope);
    return KnownHostRecord.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
    );
  }

  @override
  Future<List<KnownHostRecord>> list() async {
    final envelopes = await _records.list(type: recordType);
    final records = <KnownHostRecord>[];
    for (final envelope in envelopes) {
      final plaintext = await _vault.decryptRecord(envelope);
      records.add(
        KnownHostRecord.fromJson(
          jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
        ),
      );
    }
    return records;
  }

  @override
  Future<void> save(KnownHostRecord record) async {
    final envelope = await _vault.encryptRecord(
      id: _recordId(record.hostId),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(record.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<void> delete(HostId hostId) async {
    await _records.delete(_recordId(hostId));
  }
}

VaultRecordId _recordId(HostId hostId) {
  return VaultRecordId('known_host:${hostId.value}');
}
