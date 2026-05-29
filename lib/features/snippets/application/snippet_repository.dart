import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/snippet.dart';

abstract interface class SnippetRepository {
  Future<void> save(CommandSnippet snippet);
  Future<CommandSnippet?> read(SnippetId id);
  Future<List<CommandSnippet>> list();
  Future<void> delete(SnippetId id);
}

class EncryptedSnippetRepository implements SnippetRepository {
  EncryptedSnippetRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedSnippetRepository._(this._vault, this._records);

  static const recordType = 'snippet';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<void> save(CommandSnippet snippet) async {
    final envelope = await _vault.encryptRecord(
      id: snippetRecordId(snippet.id),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(snippet.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<CommandSnippet?> read(SnippetId id) async {
    final envelope = await _records.read(snippetRecordId(id));
    if (envelope == null) {
      return null;
    }
    return _decode(envelope);
  }

  @override
  Future<List<CommandSnippet>> list() async {
    final envelopes = await _records.list(type: recordType);
    final snippets = [
      for (final envelope in envelopes) await _decode(envelope),
    ];
    snippets.sort((left, right) {
      final byName = left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      );
      return byName == 0 ? left.id.value.compareTo(right.id.value) : byName;
    });
    return snippets;
  }

  @override
  Future<void> delete(SnippetId id) async {
    await _records.delete(snippetRecordId(id));
  }

  Future<CommandSnippet> _decode(VaultRecordEnvelope envelope) async {
    final plaintext = await _vault.decryptRecord(envelope);
    return CommandSnippet.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
    );
  }
}

VaultRecordId snippetRecordId(SnippetId id) {
  return VaultRecordId('snippet:${id.value}');
}
