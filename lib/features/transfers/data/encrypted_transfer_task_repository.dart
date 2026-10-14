import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/ids/entity_id.dart';
import '../../../database/serlink_database.dart';
import '../../vault/application/vault_service.dart';
import '../application/transfer_task_repository.dart';
import '../domain/transfer_task.dart';

/// Encrypted history for this installation, separate from shared vault records.
/// Legacy shared history has no initiating-device identity and is not imported.
class EncryptedTransferTaskRepository implements TransferTaskRepository {
  EncryptedTransferTaskRepository({
    required VaultService vault,
    required SerlinkDatabase database,
  }) : this.lazy(vault: () => vault, database: database);

  EncryptedTransferTaskRepository.lazy({
    required VaultService Function() vault,
    required SerlinkDatabase database,
  }) : this._(vault, database);

  EncryptedTransferTaskRepository._(this._vault, this._database);

  static const recordType = 'transfer_task';

  final VaultService Function() _vault;
  final SerlinkDatabase _database;

  @override
  Future<void> save(TransferTask task) async {
    final vault = _vault();
    final vaultId = _vaultId(vault);
    final envelope = await vault.encryptRecord(
      id: _recordId(task.id),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(task.toJson())),
    );
    await _database.customStatement(
      'INSERT OR REPLACE INTO local_transfer_tasks '
      '(vault_id, id, envelope_json) VALUES (?, ?, ?)',
      [vaultId, task.id.value, jsonEncode(envelope.toJson())],
    );
  }

  @override
  Future<List<TransferTask>> list() async {
    final vault = _vault();
    // Let the queue retry restoration after unlock, even for an empty table.
    if (vault.state != VaultState.unlocked) {
      throw const VaultException('vault.locked', 'Vault is locked.');
    }
    final rows = await _database
        .customSelect(
          'SELECT envelope_json FROM local_transfer_tasks WHERE vault_id = ?',
          variables: [Variable(_vaultId(vault))],
          readsFrom: const {},
        )
        .get();
    final tasks = <TransferTask>[];
    for (final row in rows) {
      final envelope = VaultRecordEnvelope.fromJson(
        jsonDecode(row.read<String>('envelope_json')) as Map<String, Object?>,
      );
      final plaintext = await vault.decryptRecord(envelope);
      tasks.add(
        TransferTask.fromJson(
          jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
        ),
      );
    }
    tasks.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return tasks;
  }

  @override
  Future<void> delete(TransferTaskId id) async {
    await _database.customStatement(
      'DELETE FROM local_transfer_tasks WHERE vault_id = ? AND id = ?',
      [_vaultId(_vault()), id.value],
    );
  }

  @override
  Future<void> clear() async {
    await _database.customStatement(
      'DELETE FROM local_transfer_tasks WHERE vault_id = ?',
      [_vaultId(_vault())],
    );
  }
}

String _vaultId(VaultService vault) {
  final header = vault.header;
  if (header == null) {
    throw const VaultException('vault.locked', 'Vault is locked.');
  }
  return base64Url.encode(header.passphraseSalt).replaceAll('=', '');
}

VaultRecordId _recordId(TransferTaskId id) {
  return VaultRecordId('transfer_task:${id.value}');
}
