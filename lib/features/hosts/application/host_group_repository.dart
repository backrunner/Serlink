import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';

final hostGroupRepositoryProvider = Provider<EncryptedHostGroupRepository>((
  ref,
) {
  return EncryptedHostGroupRepository(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

/// Explicit groups survive after their last host is moved or removed. Legacy
/// groups are still read from HostConfig.groupId, which remains the group name.
class EncryptedHostGroupRepository {
  EncryptedHostGroupRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedHostGroupRepository._(this._vault, this._records);

  static const recordType = 'host_group';
  final VaultService _vault;
  final VaultRecordRepository _records;

  Future<List<String>> list() async {
    final names = <String>{};
    for (final envelope in await _records.list(type: recordType)) {
      final json =
          jsonDecode(utf8.decode(await _vault.decryptRecord(envelope)))
              as Map<String, Object?>;
      names.add(json['name'] as String);
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> save(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized == '__new_group__') {
      throw ArgumentError.value(name, 'name', 'Invalid group name');
    }
    if ((await list()).contains(normalized)) return;
    final envelope = await _vault.encryptRecord(
      id: VaultRecordId('host_group:${const Uuid().v4()}'),
      type: recordType,
      plaintext: utf8.encode(jsonEncode({'name': normalized})),
    );
    await _records.upsert(envelope);
  }
}
