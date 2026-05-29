import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/snippets/application/snippet_repository.dart';
import 'package:serlink/features/snippets/domain/snippet.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late EncryptedSnippetRepository repository;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    records = InMemoryVaultRecordRepository();
    repository = EncryptedSnippetRepository(vault: vault, records: records);
  });

  test('stores snippet payload encrypted and reads it back', () async {
    final snippet = CommandSnippet(
      id: SnippetId('snippet-1'),
      name: 'Restart API',
      command: 'sudo systemctl restart api',
      tags: {'prod', 'ops'},
      confirmBeforeRun: true,
      createdAt: DateTime.utc(2026, 5, 28, 9),
      updatedAt: DateTime.utc(2026, 5, 28, 9),
    );

    await repository.save(snippet);

    final stored = await repository.read(snippet.id);
    expect(stored, isNotNull);
    expect(stored!.name, snippet.name);
    expect(stored.command, snippet.command);
    expect(stored.tags, snippet.tags);

    final serializedRecords = jsonEncode([
      for (final record in await records.list()) record.toJson(),
    ]);
    expect(serializedRecords, isNot(contains('Restart API')));
    expect(serializedRecords, isNot(contains('sudo systemctl restart api')));
  });

  test('lists snippets sorted by name then id', () async {
    await repository.save(
      CommandSnippet(
        id: SnippetId('z-id'),
        name: 'logs',
        command: 'tail -f /var/log/app.log',
        tags: {},
        confirmBeforeRun: false,
        createdAt: DateTime.utc(2026, 5, 28, 9),
        updatedAt: DateTime.utc(2026, 5, 28, 9),
      ),
    );
    await repository.save(
      CommandSnippet(
        id: SnippetId('a-id'),
        name: 'Deploy',
        command: './deploy.sh',
        tags: {},
        confirmBeforeRun: true,
        createdAt: DateTime.utc(2026, 5, 28, 9),
        updatedAt: DateTime.utc(2026, 5, 28, 9),
      ),
    );
    await repository.save(
      CommandSnippet(
        id: SnippetId('b-id'),
        name: 'deploy',
        command: './deploy staging',
        tags: {},
        confirmBeforeRun: false,
        createdAt: DateTime.utc(2026, 5, 28, 9),
        updatedAt: DateTime.utc(2026, 5, 28, 9),
      ),
    );

    final snippets = await repository.list();

    expect(snippets.map((snippet) => snippet.id.value).toList(), [
      'a-id',
      'b-id',
      'z-id',
    ]);
  });

  test('deletes stored snippets', () async {
    final id = SnippetId('snippet-1');
    await repository.save(
      CommandSnippet(
        id: id,
        name: 'Clean temp',
        command: 'rm -rf /tmp/build',
        tags: {},
        confirmBeforeRun: true,
        createdAt: DateTime.utc(2026, 5, 28, 9),
        updatedAt: DateTime.utc(2026, 5, 28, 9),
      ),
    );

    await repository.delete(id);

    expect(await repository.read(id), isNull);
    expect(await repository.list(), isEmpty);
  });
}
