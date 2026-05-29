import 'package:uuid/uuid.dart';

import '../../../core/ids/entity_id.dart';
import '../../sync/application/sync_delete_tombstone_repository.dart';
import '../domain/snippet.dart';
import 'snippet_repository.dart';

class SnippetDraft {
  const SnippetDraft({
    required this.name,
    required this.command,
    this.tags = const {},
    this.confirmBeforeRun = true,
  });

  final String name;
  final String command;
  final Set<String> tags;
  final bool confirmBeforeRun;
}

class SnippetWriteException implements Exception {
  const SnippetWriteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SnippetWriteException($code): $message';
}

class SnippetWriteService {
  SnippetWriteService({
    required SnippetRepository snippets,
    SyncDeleteTombstoneRepository? tombstones,
    Uuid? uuid,
    DateTime Function()? now,
  }) : this._(snippets, tombstones, uuid ?? const Uuid(), now ?? DateTime.now);

  SnippetWriteService._(
    this._snippets,
    this._tombstones,
    this._uuid,
    this._now,
  );

  final SnippetRepository _snippets;
  final SyncDeleteTombstoneRepository? _tombstones;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<CommandSnippet> create(SnippetDraft draft) async {
    final now = _now().toUtc();
    final snippet = CommandSnippet(
      id: SnippetId(_uuid.v4()),
      name: _normalizeName(draft.name),
      command: _normalizeCommand(draft.command),
      tags: _normalizeTags(draft.tags),
      confirmBeforeRun: draft.confirmBeforeRun,
      createdAt: now,
      updatedAt: now,
    );
    await _snippets.save(snippet);
    return snippet;
  }

  Future<CommandSnippet> update(SnippetId id, SnippetDraft draft) async {
    final existing = await _snippets.read(id);
    if (existing == null) {
      throw const SnippetWriteException(
        'snippet.not_found',
        'Snippet no longer exists.',
      );
    }
    final updated = existing.copyWith(
      name: _normalizeName(draft.name),
      command: _normalizeCommand(draft.command),
      tags: _normalizeTags(draft.tags),
      confirmBeforeRun: draft.confirmBeforeRun,
      updatedAt: _now().toUtc(),
    );
    await _snippets.save(updated);
    return updated;
  }

  Future<void> delete(SnippetId id) async {
    await _tombstones?.save(
      SyncDeleteTombstone(
        targetRecordId: snippetRecordId(id),
        targetRecordType: EncryptedSnippetRepository.recordType,
        deletedAt: _now().toUtc(),
      ),
    );
    await _snippets.delete(id);
  }
}

String _normalizeName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw const SnippetWriteException(
      'snippet.name_required',
      'Snippet name is required.',
    );
  }
  return trimmed;
}

String _normalizeCommand(String value) {
  final normalized = value.trimRight();
  if (normalized.trim().isEmpty) {
    throw const SnippetWriteException(
      'snippet.command_required',
      'Snippet command is required.',
    );
  }
  return normalized;
}

Set<String> _normalizeTags(Set<String> tags) {
  return {
    for (final tag in tags.map((tag) => tag.trim()))
      if (tag.isNotEmpty) tag,
  };
}
