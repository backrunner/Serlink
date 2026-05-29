import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/snippets/application/snippet_repository.dart';
import 'package:serlink/features/snippets/application/snippet_write_service.dart';
import 'package:serlink/features/sync/application/sync_delete_tombstone_repository.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late EncryptedSnippetRepository snippets;
  late EncryptedSyncDeleteTombstoneRepository tombstones;
  late SnippetWriteService service;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    records = InMemoryVaultRecordRepository();
    snippets = EncryptedSnippetRepository(vault: vault, records: records);
    tombstones = EncryptedSyncDeleteTombstoneRepository(
      vault: vault,
      records: records,
    );
    service = SnippetWriteService(
      snippets: snippets,
      tombstones: tombstones,
      now: () => DateTime.utc(2026, 5, 28, 10),
    );
  });

  test('rejects empty name and command', () async {
    await expectLater(
      () => service.create(const SnippetDraft(name: '  ', command: 'echo ok')),
      throwsA(
        isA<SnippetWriteException>().having(
          (error) => error.code,
          'code',
          'snippet.name_required',
        ),
      ),
    );

    await expectLater(
      () => service.create(const SnippetDraft(name: 'Example', command: '   ')),
      throwsA(
        isA<SnippetWriteException>().having(
          (error) => error.code,
          'code',
          'snippet.command_required',
        ),
      ),
    );
  });

  test('creates and updates snippet', () async {
    final created = await service.create(
      const SnippetDraft(
        name: ' Deploy ',
        command: 'echo deploy  \n',
        tags: {' prod ', '', 'ops'},
        confirmBeforeRun: false,
      ),
    );

    expect(created.name, 'Deploy');
    expect(created.command, 'echo deploy');
    expect(created.tags, {'prod', 'ops'});
    expect(created.confirmBeforeRun, isFalse);

    final updated = await service.update(
      created.id,
      const SnippetDraft(
        name: 'Deploy prod',
        command: './deploy prod',
        tags: {'prod'},
        confirmBeforeRun: true,
      ),
    );

    expect(updated.id, created.id);
    expect(updated.createdAt, created.createdAt);
    expect(updated.updatedAt, DateTime.utc(2026, 5, 28, 10));
    expect(updated.name, 'Deploy prod');
    expect(updated.command, './deploy prod');
    expect(updated.tags, {'prod'});
    expect(updated.confirmBeforeRun, isTrue);
  });

  test('delete removes snippet and writes tombstone', () async {
    final created = await service.create(
      const SnippetDraft(name: 'Logs', command: 'journalctl -fu app'),
    );

    await service.delete(created.id);

    expect(await snippets.read(created.id), isNull);
    final savedTombstones = await tombstones.list();
    expect(savedTombstones, hasLength(1));
    expect(savedTombstones.single.targetRecordId, snippetRecordId(created.id));
    expect(
      savedTombstones.single.targetRecordType,
      EncryptedSnippetRepository.recordType,
    );
  });

  test('update fails when snippet is missing', () async {
    await expectLater(
      () => service.update(
        SnippetId('missing'),
        const SnippetDraft(name: 'Logs', command: 'tail -f /var/log/app.log'),
      ),
      throwsA(
        isA<SnippetWriteException>().having(
          (error) => error.code,
          'code',
          'snippet.not_found',
        ),
      ),
    );
  });
}
