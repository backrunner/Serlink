import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/transfers/data/encrypted_transfer_task_repository.dart';
import 'package:serlink/features/transfers/domain/transfer_task.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test('stores transfer task metadata as encrypted vault records', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final repository = EncryptedTransferTaskRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    final task = TransferTask(
      id: TransferTaskId('transfer-1'),
      direction: TransferDirection.upload,
      itemKind: TransferItemKind.directory,
      localPath: '/Users/person/secrets.env',
      remotePath: '/srv/app/secrets.env',
      state: TransferState.completed,
      transferredBytes: 12,
      totalBytes: 12,
      createdAt: DateTime.utc(2026, 5, 27),
      completedAt: DateTime.utc(2026, 5, 27, 1),
    );

    await repository.save(task);

    final rawEnvelope = await records.read(
      VaultRecordId('transfer_task:transfer-1'),
    );
    expect(rawEnvelope, isNotNull);
    expect(jsonEncode(rawEnvelope!.toJson()), isNot(contains('secrets.env')));
    expect(jsonEncode(rawEnvelope.toJson()), isNot(contains('/srv/app')));

    final restored = await repository.list();
    expect(restored, hasLength(1));
    expect(restored.single.remotePath, task.remotePath);
    expect(restored.single.itemKind, TransferItemKind.directory);
    expect(restored.single.state, TransferState.completed);

    await vault.lock();
    await expectLater(
      repository.list(),
      throwsA(
        isA<VaultException>().having(
          (error) => error.code,
          'code',
          'vault.locked',
        ),
      ),
    );
  });
}
