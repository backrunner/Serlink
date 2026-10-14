import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/transfers/data/encrypted_transfer_task_repository.dart';
import 'package:serlink/features/transfers/domain/transfer_task.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';

void main() {
  late InMemoryVaultService vault;
  late SerlinkDatabase database;
  late EncryptedTransferTaskRepository repository;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'good passphrase');
    database = SerlinkDatabase(NativeDatabase.memory());
    repository = EncryptedTransferTaskRepository(
      vault: vault,
      database: database,
    );
  });
  tearDown(() async {
    await database.close();
    await vault.lock();
  });

  test(
    'encrypts history outside shared vault records and restores metadata',
    () async {
      final task = _task();
      await repository.save(task);
      final rows = await database
          .customSelect('SELECT envelope_json FROM local_transfer_tasks')
          .get();
      final raw = rows.single.read<String>('envelope_json');
      expect(raw, isNot(contains('secrets.env')));
      expect(raw, isNot(contains('/srv/app')));
      expect(await DriftVaultRecordRepository(database).list(), isEmpty);
      final restored = await repository.list();
      expect(restored.single.toJson(), task.toJson());
    },
  );

  test(
    'same vault on another device has independent history and deletion',
    () async {
      final otherDatabase = SerlinkDatabase(NativeDatabase.memory());
      addTearDown(otherDatabase.close);
      final other = EncryptedTransferTaskRepository(
        vault: vault,
        database: otherDatabase,
      );
      await repository.save(_task());
      expect(await other.list(), isEmpty);
      await other.save(_task());
      await repository.delete(_task().id);
      expect(await repository.list(), isEmpty);
      expect(await other.list(), hasLength(1));
      await repository.save(_task());
      await repository.clear();
      expect(await repository.list(), isEmpty);
      expect(await other.list(), hasLength(1));
    },
  );

  test(
    'does not import ambiguous shared history or remove its encrypted record',
    () async {
      final records = DriftVaultRecordRepository(database);
      final legacy = await vault.encryptRecord(
        id: VaultRecordId('transfer_task:legacy'),
        type: 'transfer_task',
        plaintext: utf8.encode(jsonEncode(_task().toJson())),
      );
      await records.upsert(legacy);
      expect(await repository.list(), isEmpty);
      await repository.clear();
      expect((await records.read(legacy.id))?.revision, legacy.revision);
    },
  );

  test(
    'empty locked history fails so restoration can retry after unlock',
    () async {
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
      await vault.unlock(passphrase: 'good passphrase');
      await repository.save(_task());
      expect(await repository.list(), hasLength(1));
    },
  );

  test(
    'a replacement vault cannot read or clear the previous vault history',
    () async {
      await repository.save(_task());
      final replacementVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await replacementVault.initialize(passphrase: 'other passphrase');
      addTearDown(replacementVault.lock);
      final replacement = EncryptedTransferTaskRepository(
        vault: replacementVault,
        database: database,
      );
      expect(await replacement.list(), isEmpty);
      await replacement.save(_task());
      await replacement.clear();
      expect(await replacement.list(), isEmpty);
      expect(await repository.list(), hasLength(1));
    },
  );

  test('history survives reopening the local database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'serlink-local-transfers-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/history.sqlite');
    final first = SerlinkDatabase(NativeDatabase(file));
    await EncryptedTransferTaskRepository(
      vault: vault,
      database: first,
    ).save(_task());
    await first.close();
    final reopened = SerlinkDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final restored = await EncryptedTransferTaskRepository(
      vault: vault,
      database: reopened,
    ).list();
    expect(restored.single.toJson(), _task().toJson());
  });
}

TransferTask _task() => TransferTask(
  id: TransferTaskId('transfer-1'),
  direction: TransferDirection.upload,
  itemKind: TransferItemKind.directory,
  sourceHostId: HostId('host-1'),
  sourceMachineName: 'Build Server',
  localPath: '/Users/person/secrets.env',
  remotePath: '/srv/app/secrets.env',
  state: TransferState.completed,
  transferredBytes: 12,
  totalBytes: 12,
  createdAt: DateTime.utc(2026, 5, 27),
  completedAt: DateTime.utc(2026, 5, 27, 1),
);
