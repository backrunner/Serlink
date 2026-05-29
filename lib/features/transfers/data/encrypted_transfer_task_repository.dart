import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../application/transfer_task_repository.dart';
import '../domain/transfer_task.dart';

class EncryptedTransferTaskRepository implements TransferTaskRepository {
  EncryptedTransferTaskRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedTransferTaskRepository._(this._vault, this._records);

  static const recordType = 'transfer_task';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<void> save(TransferTask task) async {
    final envelope = await _vault.encryptRecord(
      id: _recordId(task.id),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(task.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<List<TransferTask>> list() async {
    final envelopes = await _records.list(type: recordType);
    final tasks = <TransferTask>[];
    for (final envelope in envelopes) {
      final plaintext = await _vault.decryptRecord(envelope);
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
    await _records.delete(_recordId(id));
  }

  @override
  Future<void> clear() async {
    final envelopes = await _records.list(type: recordType);
    for (final envelope in envelopes) {
      await _records.delete(envelope.id);
    }
  }
}

VaultRecordId _recordId(TransferTaskId id) {
  return VaultRecordId('transfer_task:${id.value}');
}
