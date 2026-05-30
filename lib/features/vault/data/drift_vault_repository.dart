import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/ids/entity_id.dart';
import '../../../database/serlink_database.dart';
import '../application/vault_record_repository.dart';
import '../application/vault_service.dart';

abstract interface class VaultHeaderStore {
  Future<void> save(VaultHeader header);
  Future<VaultHeader?> read();
  Future<void> clear();
}

class DriftVaultHeaderStore implements VaultHeaderStore {
  DriftVaultHeaderStore(this._database);

  static const _primaryHeaderId = 'default';

  final SerlinkDatabase _database;

  @override
  Future<void> save(VaultHeader header) async {
    await _database
        .into(_database.vaultHeaders)
        .insertOnConflictUpdate(
          VaultHeadersCompanion.insert(
            id: _primaryHeaderId,
            json: jsonEncode(header.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<VaultHeader?> read() async {
    final row = await (_database.select(
      _database.vaultHeaders,
    )..where((table) => table.id.equals(_primaryHeaderId))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return VaultHeader.fromJson(jsonDecode(row.json) as Map<String, Object?>);
  }

  @override
  Future<void> clear() async {
    await (_database.delete(
      _database.vaultHeaders,
    )..where((table) => table.id.equals(_primaryHeaderId))).go();
  }
}

class DriftVaultRecordRepository implements VaultRecordRepository {
  DriftVaultRecordRepository(this._database);

  final SerlinkDatabase _database;

  @override
  Future<void> upsert(VaultRecordEnvelope envelope) async {
    await _database
        .into(_database.encryptedRecords)
        .insertOnConflictUpdate(
          EncryptedRecordsCompanion.insert(
            id: envelope.id.value,
            type: envelope.type,
            schemaVersion: envelope.schemaVersion,
            revision: envelope.revision,
            nonce: Uint8List.fromList(envelope.nonce),
            mac: Uint8List.fromList(envelope.mac),
            associatedData: Uint8List.fromList(envelope.associatedData),
            ciphertext: Uint8List.fromList(envelope.ciphertext),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<VaultRecordEnvelope?> read(VaultRecordId id) async {
    final row = await (_database.select(
      _database.encryptedRecords,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : _toEnvelope(row);
  }

  @override
  Future<List<VaultRecordEnvelope>> list({String? type}) async {
    final query = _database.select(_database.encryptedRecords);
    if (type != null) {
      query.where((table) => table.type.equals(type));
    }
    query.orderBy([
      (table) => OrderingTerm.asc(table.type),
      (table) => OrderingTerm.asc(table.id),
    ]);
    final rows = await query.get();
    return [for (final row in rows) _toEnvelope(row)];
  }

  @override
  Future<void> delete(VaultRecordId id) async {
    await (_database.delete(
      _database.encryptedRecords,
    )..where((table) => table.id.equals(id.value))).go();
  }

  @override
  Future<void> clear() async {
    await _database.delete(_database.encryptedRecords).go();
  }
}

VaultRecordEnvelope _toEnvelope(EncryptedRecordRow row) {
  return VaultRecordEnvelope(
    id: VaultRecordId(row.id),
    type: row.type,
    schemaVersion: row.schemaVersion,
    revision: row.revision,
    nonce: List<int>.unmodifiable(row.nonce),
    mac: List<int>.unmodifiable(row.mac),
    associatedData: List<int>.unmodifiable(row.associatedData),
    ciphertext: List<int>.unmodifiable(row.ciphertext),
  );
}
