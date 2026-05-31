import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ids/entity_id.dart';
import '../../identities/application/identity_repository.dart';
import '../../identities/domain/identity.dart';
import '../../identities/domain/identity_secret.dart';
import '../../sync/application/sync_delete_tombstone_repository.dart';
import '../../ssh/application/known_host_repository.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/host.dart';
import 'host_repository.dart';

final hostWriteServiceProvider = Provider<HostWriteService>((ref) {
  return HostWriteService(
    hosts: ref.watch(hostRepositoryProvider),
    identities: ref.watch(identityRepositoryProvider),
    knownHosts: ref.watch(knownHostRepositoryProvider),
    tombstones: ref.watch(syncDeleteTombstoneRepositoryProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
    vault: ref.watch(vaultServiceProvider),
  );
});

class PasswordHostDraft {
  const PasswordHostDraft({
    required this.displayName,
    required this.hostname,
    required this.port,
    required this.username,
    required this.password,
    required this.tags,
    this.startupCommands = const [],
    this.jumpHostIds = const [],
    this.sftpDefaultDirectory = '/',
    this.connectionSettings = const HostConnectionSettings(),
  });

  final String displayName;
  final String hostname;
  final int port;
  final String username;
  final String password;
  final Set<String> tags;
  final List<String> startupCommands;
  final List<HostId> jumpHostIds;
  final String sftpDefaultDirectory;
  final HostConnectionSettings connectionSettings;
}

class PrivateKeyHostDraft {
  const PrivateKeyHostDraft({
    required this.displayName,
    required this.hostname,
    required this.port,
    required this.username,
    required this.privateKeyPem,
    required this.privateKeyPassphrase,
    required this.tags,
    this.startupCommands = const [],
    this.jumpHostIds = const [],
    this.sftpDefaultDirectory = '/',
    this.connectionSettings = const HostConnectionSettings(),
  });

  final String displayName;
  final String hostname;
  final int port;
  final String username;
  final String privateKeyPem;
  final String privateKeyPassphrase;
  final Set<String> tags;
  final List<String> startupCommands;
  final List<HostId> jumpHostIds;
  final String sftpDefaultDirectory;
  final HostConnectionSettings connectionSettings;
}

class ExistingIdentitiesHostDraft {
  const ExistingIdentitiesHostDraft({
    required this.displayName,
    required this.hostname,
    required this.port,
    required this.username,
    required this.identityIds,
    required this.tags,
    this.startupCommands = const [],
    this.jumpHostIds = const [],
    this.sftpDefaultDirectory = '/',
    this.connectionSettings = const HostConnectionSettings(),
  });

  final String displayName;
  final String hostname;
  final int port;
  final String username;
  final List<IdentityId> identityIds;
  final Set<String> tags;
  final List<String> startupCommands;
  final List<HostId> jumpHostIds;
  final String sftpDefaultDirectory;
  final HostConnectionSettings connectionSettings;
}

class SshAgentHostDraft {
  const SshAgentHostDraft({
    required this.displayName,
    required this.hostname,
    required this.port,
    required this.username,
    required this.tags,
    this.startupCommands = const [],
    this.jumpHostIds = const [],
    this.sftpDefaultDirectory = '/',
    this.connectionSettings = const HostConnectionSettings(),
  });

  final String displayName;
  final String hostname;
  final int port;
  final String username;
  final Set<String> tags;
  final List<String> startupCommands;
  final List<HostId> jumpHostIds;
  final String sftpDefaultDirectory;
  final HostConnectionSettings connectionSettings;
}

class HostMetadataDraft {
  const HostMetadataDraft({
    required this.id,
    required this.displayName,
    required this.hostname,
    required this.port,
    required this.username,
    required this.tags,
    required this.identityIds,
    this.startupCommands = const [],
    this.jumpHostIds = const [],
    this.sftpDefaultDirectory = '/',
    this.connectionSettings = const HostConnectionSettings(),
  });

  final HostId id;
  final String displayName;
  final String hostname;
  final int port;
  final String username;
  final Set<String> tags;
  final List<IdentityId> identityIds;
  final List<String> startupCommands;
  final List<HostId> jumpHostIds;
  final String sftpDefaultDirectory;
  final HostConnectionSettings connectionSettings;
}

class HostWriteService {
  HostWriteService({
    required HostRepository hosts,
    required IdentityRepository identities,
    required KnownHostRepository knownHosts,
    required SyncDeleteTombstoneRepository tombstones,
    required VaultRecordRepository records,
    required VaultService vault,
  }) : this._(hosts, identities, knownHosts, tombstones, records, vault);

  HostWriteService._(
    this._hosts,
    this._identities,
    this._knownHosts,
    this._tombstones,
    this._records,
    this._vault,
  );

  static const _uuid = Uuid();

  final HostRepository _hosts;
  final IdentityRepository _identities;
  final KnownHostRepository _knownHosts;
  final SyncDeleteTombstoneRepository _tombstones;
  final VaultRecordRepository _records;
  final VaultService _vault;

  Future<HostSummary> createPasswordHost(PasswordHostDraft draft) async {
    final normalized = _normalizeHostFields(
      displayName: draft.displayName,
      hostname: draft.hostname,
      port: draft.port,
      username: draft.username,
    );
    final connectionSettings = _normalizeConnectionSettings(
      draft.connectionSettings,
    );
    final sftpDefaultDirectory = _normalizeSftpDefaultDirectory(
      draft.sftpDefaultDirectory,
    );
    final password = draft.password;
    if (password.isEmpty) {
      throw const HostWriteException(
        'host.password_required',
        'Password is required.',
      );
    }

    final now = DateTime.now().toUtc();
    final hostId = HostId(_uuid.v4());
    final identityId = IdentityId(_uuid.v4());
    final secretRecordId = VaultRecordId('secret:${identityId.value}');

    final secret = await _vault.encryptRecord(
      id: secretRecordId,
      type: 'identity_secret',
      plaintext: IdentitySecretMaterial(password: password).toBytes(),
    );
    await _records.upsert(secret);

    await _identities.save(
      IdentityConfig(
        id: identityId,
        displayName: '${normalized.displayName} Password',
        kind: IdentityKind.password,
        usernameHint: normalized.username,
        secretRecordId: secretRecordId,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final host = HostConfig(
      id: hostId,
      displayName: normalized.displayName,
      hostname: normalized.hostname,
      username: normalized.username,
      port: normalized.port,
      authKinds: const {HostAuthKind.password},
      tags: draft.tags,
      trustState: HostTrustState.unknown,
      identityIds: [identityId],
      startupCommands: _normalizeStartupCommands(draft.startupCommands),
      jumpHostIds: _normalizeJumpHostIds(draft.jumpHostIds, hostId: hostId),
      sftpDefaultDirectory: sftpDefaultDirectory,
      connectionSettings: connectionSettings,
      createdAt: now,
      updatedAt: now,
    );
    await _hosts.save(host);
    return host.toSummary();
  }

  Future<HostSummary> createPrivateKeyHost(PrivateKeyHostDraft draft) async {
    final normalized = _normalizeHostFields(
      displayName: draft.displayName,
      hostname: draft.hostname,
      port: draft.port,
      username: draft.username,
    );
    final connectionSettings = _normalizeConnectionSettings(
      draft.connectionSettings,
    );
    final sftpDefaultDirectory = _normalizeSftpDefaultDirectory(
      draft.sftpDefaultDirectory,
    );
    final privateKeyPem = draft.privateKeyPem.trim();
    if (!_looksLikePrivateKey(privateKeyPem)) {
      throw const HostWriteException(
        'host.private_key_invalid',
        'Private key must be an OpenSSH or PEM private key.',
      );
    }

    final now = DateTime.now().toUtc();
    final hostId = HostId(_uuid.v4());
    final identityId = IdentityId(_uuid.v4());
    final secretRecordId = VaultRecordId('secret:${identityId.value}');
    final passphrase = draft.privateKeyPassphrase.trim();

    final secret = await _vault.encryptRecord(
      id: secretRecordId,
      type: 'identity_secret',
      plaintext: IdentitySecretMaterial(
        privateKeyPem: privateKeyPem,
        privateKeyPassphrase: passphrase.isEmpty ? null : passphrase,
      ).toBytes(),
    );
    await _records.upsert(secret);

    await _identities.save(
      IdentityConfig(
        id: identityId,
        displayName: '${normalized.displayName} Key',
        kind: IdentityKind.privateKey,
        usernameHint: normalized.username,
        secretRecordId: secretRecordId,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final host = HostConfig(
      id: hostId,
      displayName: normalized.displayName,
      hostname: normalized.hostname,
      username: normalized.username,
      port: normalized.port,
      authKinds: const {HostAuthKind.privateKey},
      tags: draft.tags,
      trustState: HostTrustState.unknown,
      identityIds: [identityId],
      startupCommands: _normalizeStartupCommands(draft.startupCommands),
      jumpHostIds: _normalizeJumpHostIds(draft.jumpHostIds, hostId: hostId),
      sftpDefaultDirectory: sftpDefaultDirectory,
      connectionSettings: connectionSettings,
      createdAt: now,
      updatedAt: now,
    );
    await _hosts.save(host);
    return host.toSummary();
  }

  Future<HostSummary> createHostWithExistingIdentities(
    ExistingIdentitiesHostDraft draft,
  ) async {
    final normalized = _normalizeHostFields(
      displayName: draft.displayName,
      hostname: draft.hostname,
      port: draft.port,
      username: draft.username,
    );
    final connectionSettings = _normalizeConnectionSettings(
      draft.connectionSettings,
    );
    final sftpDefaultDirectory = _normalizeSftpDefaultDirectory(
      draft.sftpDefaultDirectory,
    );
    final now = DateTime.now().toUtc();
    final hostId = HostId(_uuid.v4());
    final identityIds = _normalizeIdentityIds(draft.identityIds);
    final authKinds = await _resolveAuthKinds(identityIds);

    final host = HostConfig(
      id: hostId,
      displayName: normalized.displayName,
      hostname: normalized.hostname,
      username: normalized.username,
      port: normalized.port,
      authKinds: authKinds,
      tags: draft.tags,
      trustState: HostTrustState.unknown,
      identityIds: identityIds,
      startupCommands: _normalizeStartupCommands(draft.startupCommands),
      jumpHostIds: _normalizeJumpHostIds(draft.jumpHostIds, hostId: hostId),
      sftpDefaultDirectory: sftpDefaultDirectory,
      connectionSettings: connectionSettings,
      createdAt: now,
      updatedAt: now,
    );
    await _hosts.save(host);
    return host.toSummary();
  }

  Future<HostSummary> createSshAgentHost(SshAgentHostDraft draft) async {
    final normalized = _normalizeHostFields(
      displayName: draft.displayName,
      hostname: draft.hostname,
      port: draft.port,
      username: draft.username,
    );
    final connectionSettings = _normalizeConnectionSettings(
      draft.connectionSettings,
    );
    final sftpDefaultDirectory = _normalizeSftpDefaultDirectory(
      draft.sftpDefaultDirectory,
    );
    final now = DateTime.now().toUtc();
    final hostId = HostId(_uuid.v4());
    final identityId = IdentityId(_uuid.v4());

    await _identities.save(
      IdentityConfig(
        id: identityId,
        displayName: '${normalized.displayName} SSH Agent',
        kind: IdentityKind.sshAgent,
        usernameHint: normalized.username,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final host = HostConfig(
      id: hostId,
      displayName: normalized.displayName,
      hostname: normalized.hostname,
      username: normalized.username,
      port: normalized.port,
      authKinds: const {HostAuthKind.sshAgent},
      tags: draft.tags,
      trustState: HostTrustState.unknown,
      identityIds: [identityId],
      startupCommands: _normalizeStartupCommands(draft.startupCommands),
      jumpHostIds: _normalizeJumpHostIds(draft.jumpHostIds, hostId: hostId),
      sftpDefaultDirectory: sftpDefaultDirectory,
      connectionSettings: connectionSettings,
      createdAt: now,
      updatedAt: now,
    );
    await _hosts.save(host);
    return host.toSummary();
  }

  Future<HostSummary> updateHostMetadata(HostMetadataDraft draft) async {
    final existing = await _hosts.read(draft.id);
    if (existing == null) {
      throw const HostWriteException('host.not_found', 'Host does not exist.');
    }
    final normalized = _normalizeHostFields(
      displayName: draft.displayName,
      hostname: draft.hostname,
      port: draft.port,
      username: draft.username,
    );
    final identityIds = _normalizeIdentityIds(draft.identityIds);
    final authKinds = await _resolveAuthKinds(identityIds);
    final connectionSettings = _normalizeConnectionSettings(
      draft.connectionSettings,
    );
    final sftpDefaultDirectory = _normalizeSftpDefaultDirectory(
      draft.sftpDefaultDirectory,
    );
    final updated = HostConfig(
      id: existing.id,
      displayName: normalized.displayName,
      hostname: normalized.hostname,
      username: normalized.username,
      port: normalized.port,
      authKinds: authKinds,
      tags: draft.tags,
      trustState: existing.trustState,
      identityIds: identityIds,
      startupCommands: _normalizeStartupCommands(draft.startupCommands),
      jumpHostIds: _normalizeJumpHostIds(
        draft.jumpHostIds,
        hostId: existing.id,
      ),
      sftpDefaultDirectory: sftpDefaultDirectory,
      connectionSettings: connectionSettings,
      groupId: existing.groupId,
      lastConnectedAt: existing.lastConnectedAt,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _hosts.save(updated);
    return updated.toSummary();
  }

  Future<HostSummary> updateSftpDefaultDirectory(
    HostId id,
    String sftpDefaultDirectory,
  ) async {
    final existing = await _hosts.read(id);
    if (existing == null) {
      throw const HostWriteException('host.not_found', 'Host does not exist.');
    }
    final updated = HostConfig(
      id: existing.id,
      displayName: existing.displayName,
      hostname: existing.hostname,
      username: existing.username,
      port: existing.port,
      authKinds: existing.authKinds,
      tags: existing.tags,
      trustState: existing.trustState,
      identityIds: existing.identityIds,
      startupCommands: existing.startupCommands,
      jumpHostIds: existing.jumpHostIds,
      sftpDefaultDirectory: _normalizeSftpDefaultDirectory(
        sftpDefaultDirectory,
      ),
      connectionSettings: existing.connectionSettings,
      groupId: existing.groupId,
      lastConnectedAt: existing.lastConnectedAt,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _hosts.save(updated);
    return updated.toSummary();
  }

  Future<void> deleteHost(HostId id) async {
    final host = await _hosts.read(id);
    if (host == null) {
      return;
    }
    await _recordDeletion(
      _hostRecordId(id),
      EncryptedHostRepository.recordType,
    );
    await _hosts.delete(id);
    await _recordDeletion(
      _knownHostRecordId(id),
      EncryptedKnownHostRepository.recordType,
    );
    await _knownHosts.delete(id);
    for (final identityId in host.identityIds) {
      if (await _identityUsedByAnotherHost(identityId, host.id)) {
        continue;
      }
      final identity = await _identities.read(identityId);
      final secretRecordId = identity?.secretRecordId;
      if (secretRecordId != null) {
        await _recordDeletion(secretRecordId, 'identity_secret');
        await _records.delete(secretRecordId);
      }
      await _recordDeletion(
        _identityRecordId(identityId),
        EncryptedIdentityRepository.recordType,
      );
      await _identities.delete(identityId);
    }
  }

  Future<bool> _identityUsedByAnotherHost(
    IdentityId identityId,
    HostId deletedHostId,
  ) async {
    final hosts = await _hosts.list();
    return hosts.any(
      (host) =>
          host.id != deletedHostId && host.identityIds.contains(identityId),
    );
  }

  List<IdentityId> _normalizeIdentityIds(List<IdentityId> identityIds) {
    final normalized = <IdentityId>[];
    for (final identityId in identityIds) {
      if (!normalized.contains(identityId)) {
        normalized.add(identityId);
      }
    }
    return List<IdentityId>.unmodifiable(normalized);
  }

  Future<Set<HostAuthKind>> _resolveAuthKinds(
    List<IdentityId> identityIds,
  ) async {
    final authKinds = <HostAuthKind>{};
    for (final identityId in identityIds) {
      final identity = await _identities.read(identityId);
      if (identity == null) {
        throw HostWriteException(
          'host.identity_not_found',
          'Credential ${identityId.value} does not exist.',
        );
      }
      authKinds.add(_hostAuthKindFor(identity.kind));
    }
    return Set<HostAuthKind>.unmodifiable(authKinds);
  }

  Future<void> _recordDeletion(VaultRecordId id, String type) {
    return _tombstones.save(
      SyncDeleteTombstone(
        targetRecordId: id,
        targetRecordType: type,
        deletedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

List<String> _normalizeStartupCommands(List<String> commands) {
  return List<String>.unmodifiable([
    for (final command in commands)
      if (command.trim().isNotEmpty) command.trimRight(),
  ]);
}

List<HostId> _normalizeJumpHostIds(
  List<HostId> jumpHostIds, {
  required HostId hostId,
}) {
  final normalized = <HostId>[];
  for (final jumpHostId in jumpHostIds) {
    if (jumpHostId == hostId || normalized.contains(jumpHostId)) {
      continue;
    }
    normalized.add(jumpHostId);
  }
  return List<HostId>.unmodifiable(normalized);
}

HostConnectionSettings _normalizeConnectionSettings(
  HostConnectionSettings settings,
) {
  final connectTimeoutSeconds = settings.connectTimeoutSeconds;
  final keepAliveIntervalSeconds = settings.keepAliveIntervalSeconds;
  final reconnectAttempts = settings.reconnectAttempts;
  final reconnectBackoffSeconds = settings.reconnectBackoffSeconds;
  if (connectTimeoutSeconds < 3 || connectTimeoutSeconds > 120) {
    throw const HostWriteException(
      'host.connect_timeout_invalid',
      'Connection timeout must be between 3 and 120 seconds.',
    );
  }
  if (keepAliveIntervalSeconds != 0 &&
      (keepAliveIntervalSeconds < 5 || keepAliveIntervalSeconds > 300)) {
    throw const HostWriteException(
      'host.keepalive_interval_invalid',
      'Keepalive interval must be 0 or between 5 and 300 seconds.',
    );
  }
  if (reconnectAttempts < 0 || reconnectAttempts > 10) {
    throw const HostWriteException(
      'host.reconnect_attempts_invalid',
      'Reconnect attempts must be between 0 and 10.',
    );
  }
  if (reconnectBackoffSeconds < 1 || reconnectBackoffSeconds > 300) {
    throw const HostWriteException(
      'host.reconnect_backoff_invalid',
      'Reconnect backoff must be between 1 and 300 seconds.',
    );
  }
  return HostConnectionSettings(
    connectTimeoutSeconds: connectTimeoutSeconds,
    keepAliveIntervalSeconds: keepAliveIntervalSeconds,
    reconnectAttempts: reconnectAttempts,
    reconnectBackoffSeconds: reconnectBackoffSeconds,
  );
}

String _normalizeSftpDefaultDirectory(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return '/';
  }
  if (!trimmed.startsWith('/')) {
    throw const HostWriteException(
      'host.sftp_default_directory_invalid',
      'SFTP start folder must be an absolute path.',
    );
  }
  final segments = <String>[];
  for (final segment in trimmed.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  return '/${segments.join('/')}';
}

HostAuthKind _hostAuthKindFor(IdentityKind kind) {
  return switch (kind) {
    IdentityKind.password => HostAuthKind.password,
    IdentityKind.privateKey => HostAuthKind.privateKey,
    IdentityKind.keyboardInteractive => HostAuthKind.keyboardInteractive,
    IdentityKind.openSshCertificate => HostAuthKind.openSshCertificate,
    IdentityKind.sshAgent => HostAuthKind.sshAgent,
    IdentityKind.hardwareKey => HostAuthKind.hardwareKey,
  };
}

VaultRecordId _hostRecordId(HostId id) => VaultRecordId('host:${id.value}');

VaultRecordId _identityRecordId(IdentityId id) {
  return VaultRecordId('identity:${id.value}');
}

VaultRecordId _knownHostRecordId(HostId id) {
  return VaultRecordId('known_host:${id.value}');
}

_NormalizedHostFields _normalizeHostFields({
  required String displayName,
  required String hostname,
  required int port,
  required String username,
}) {
  final normalizedHostname = hostname.trim();
  final normalizedUsername = username.trim();
  final normalizedDisplayName = displayName.trim().isEmpty
      ? normalizedHostname
      : displayName.trim();

  if (normalizedHostname.isEmpty) {
    throw const HostWriteException(
      'host.hostname_required',
      'Hostname is required.',
    );
  }
  if (port < 1 || port > 65535) {
    throw const HostWriteException(
      'host.port_invalid',
      'Port must be between 1 and 65535.',
    );
  }
  if (normalizedUsername.isEmpty) {
    throw const HostWriteException(
      'host.username_required',
      'Username is required.',
    );
  }
  return _NormalizedHostFields(
    displayName: normalizedDisplayName,
    hostname: normalizedHostname,
    port: port,
    username: normalizedUsername,
  );
}

bool _looksLikePrivateKey(String value) {
  return value.contains('BEGIN') &&
      value.contains('PRIVATE KEY') &&
      value.contains('END');
}

class _NormalizedHostFields {
  const _NormalizedHostFields({
    required this.displayName,
    required this.hostname,
    required this.port,
    required this.username,
  });

  final String displayName;
  final String hostname;
  final int port;
  final String username;
}

class HostWriteException implements Exception {
  const HostWriteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'HostWriteException($code): $message';
}
