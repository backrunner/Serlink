import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../../core/security/secret_bytes.dart';
import '../../hosts/application/host_repository.dart';
import '../../hosts/domain/host.dart';
import '../../identities/application/identity_repository.dart';
import '../../identities/domain/identity.dart';
import '../../identities/domain/identity_secret.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/connection_profile.dart';
import 'connection_profile_resolver.dart';

class EncryptedConnectionProfileResolver implements ConnectionProfileResolver {
  static const _maxJumpDepth = 8;

  EncryptedConnectionProfileResolver({
    required HostRepository hosts,
    required IdentityRepository identities,
    required VaultRecordRepository records,
    required VaultService vault,
    bool sshAgentAuthAvailable = true,
    bool hardwareKeyAuthAvailable = false,
  }) : this._(
         hosts,
         identities,
         records,
         vault,
         sshAgentAuthAvailable,
         hardwareKeyAuthAvailable,
       );

  EncryptedConnectionProfileResolver._(
    this._hosts,
    this._identities,
    this._records,
    this._vault,
    this._sshAgentAuthAvailable,
    this._hardwareKeyAuthAvailable,
  );

  final HostRepository _hosts;
  final IdentityRepository _identities;
  final VaultRecordRepository _records;
  final VaultService _vault;
  final bool _sshAgentAuthAvailable;
  final bool _hardwareKeyAuthAvailable;

  @override
  Future<ConnectionProfileSnapshot> resolve({
    required HostId hostId,
    required SessionId sessionId,
  }) async {
    final host = await _readHost(hostId);
    final credentials = await _credentialsFor(host);
    final jumpHosts = await _jumpChainFor(
      host,
      visitingHostIds: {host.id.value},
      depth: 0,
    );

    return ConnectionProfileSnapshot(
      sessionId: sessionId,
      hostId: host.id,
      hostname: host.hostname,
      port: host.port,
      username: credentials.username,
      authMethods: credentials.authMethods,
      startupCommands: host.startupCommands,
      jumpHosts: jumpHosts,
      portForwarding: _portForwardingProfileFor(host.portForwarding),
      connectTimeout: host.connectionSettings.connectTimeout,
      keepAliveInterval: host.connectionSettings.keepAliveInterval,
      reconnectPolicy: SshReconnectPolicy(
        maxAttempts: host.connectionSettings.reconnectAttempts,
        backoff: host.connectionSettings.reconnectBackoff,
      ),
      remoteSession: _remoteSessionProfileFor(host.remoteSessionSettings),
    );
  }

  SshRemoteSessionProfile _remoteSessionProfileFor(
    HostRemoteSessionSettings settings,
  ) {
    return SshRemoteSessionProfile(
      enabled: settings.enabled,
      manager: switch (settings.manager) {
        HostRemoteSessionManager.auto => SshRemoteSessionManager.auto,
        HostRemoteSessionManager.tmux => SshRemoteSessionManager.tmux,
        HostRemoteSessionManager.screen => SshRemoteSessionManager.screen,
      },
      sessionName: settings.sessionName,
      createIfMissing: settings.createIfMissing,
      fallbackToShell: settings.fallbackToShell,
    );
  }

  SshPortForwardingProfile _portForwardingProfileFor(
    HostPortForwardingSettings settings,
  ) {
    return SshPortForwardingProfile(
      localForwards: [
        for (final forward in settings.localForwards)
          SshLocalPortForward(
            localPort: forward.localPort,
            remoteHost: forward.remoteHost,
            remotePort: forward.remotePort,
          ),
      ],
      remoteForwards: [
        for (final forward in settings.remoteForwards)
          SshRemotePortForward(
            bindHost: forward.bindHost,
            bindPort: forward.bindPort,
            localHost: forward.localHost,
            localPort: forward.localPort,
          ),
      ],
      dynamicForwards: [
        for (final forward in settings.dynamicForwards)
          SshDynamicPortForward(
            bindHost: forward.bindHost,
            bindPort: forward.bindPort,
          ),
      ],
    );
  }

  Future<HostConfig> _readHost(HostId hostId) async {
    final host = await _hosts.read(hostId);
    if (host == null) {
      throw ConnectionProfileResolutionException(
        'connection_profile.host_not_found',
        'Host ${hostId.value} does not exist.',
      );
    }
    return host;
  }

  Future<_ResolvedSshCredentials> _credentialsFor(HostConfig host) async {
    final authMethods = <SshAuthMethod>[];
    String? passwordUsername;
    for (final identityId in host.identityIds) {
      final identity = await _identities.read(identityId);
      if (identity == null) {
        throw ConnectionProfileResolutionException(
          'connection_profile.identity_not_found',
          'Identity ${identityId.value} does not exist.',
        );
      }
      passwordUsername ??= _passwordUsernameFor(identity);
      authMethods.add(await _authMethodFor(identity));
    }

    if (authMethods.isEmpty) {
      throw ConnectionProfileResolutionException(
        'connection_profile.no_auth_methods',
        'Host ${host.id.value} has no identity configured.',
      );
    }

    return _ResolvedSshCredentials(
      username: passwordUsername ?? host.username,
      authMethods: List<SshAuthMethod>.unmodifiable(authMethods),
    );
  }

  Future<List<SshJumpHostSnapshot>> _jumpChainFor(
    HostConfig host, {
    required Set<String> visitingHostIds,
    required int depth,
  }) async {
    if (host.jumpHostIds.isEmpty) {
      return const [];
    }
    if (depth >= _maxJumpDepth) {
      throw ConnectionProfileResolutionException(
        'connection_profile.jump_chain_too_deep',
        'Jump host chain exceeds $_maxJumpDepth hops.',
      );
    }

    final chain = <SshJumpHostSnapshot>[];
    for (final jumpHostId in host.jumpHostIds) {
      if (visitingHostIds.contains(jumpHostId.value)) {
        throw ConnectionProfileResolutionException(
          'connection_profile.jump_cycle',
          'Jump host chain contains a cycle at host ${jumpHostId.value}.',
        );
      }

      final jumpHost = await _readHost(jumpHostId);
      final nextVisiting = {...visitingHostIds, jumpHost.id.value};
      chain.addAll(
        await _jumpChainFor(
          jumpHost,
          visitingHostIds: nextVisiting,
          depth: depth + 1,
        ),
      );
      chain.add(await _jumpSnapshotFor(jumpHost));
    }
    return chain;
  }

  Future<SshJumpHostSnapshot> _jumpSnapshotFor(HostConfig jumpHost) async {
    final credentials = await _credentialsFor(jumpHost);
    return SshJumpHostSnapshot(
      hostId: jumpHost.id,
      hostname: jumpHost.hostname,
      port: jumpHost.port,
      username: credentials.username,
      authMethods: credentials.authMethods,
      connectTimeout: jumpHost.connectionSettings.connectTimeout,
      keepAliveInterval: jumpHost.connectionSettings.keepAliveInterval,
    );
  }

  Future<SshAuthMethod> _authMethodFor(IdentityConfig identity) async {
    return switch (identity.kind) {
      IdentityKind.password => SshPasswordAuth(
        password: SecretBytes(
          (await _secretMaterial(identity)).requirePassword(identity.id),
        ),
      ),
      IdentityKind.privateKey => _privateKeyAuth(identity),
      IdentityKind.keyboardInteractive => SshKeyboardInteractiveAuth(
        responses: [
          for (final response in (await _secretMaterial(
            identity,
          )).keyboardInteractiveResponses)
            SecretBytes(utf8.encode(response)),
        ],
      ),
      IdentityKind.openSshCertificate => _certificateAuth(identity),
      IdentityKind.sshAgent => _sshAgentAuth(),
      IdentityKind.hardwareKey => _hardwareKeyAuth(),
    };
  }

  SshAgentAuth _sshAgentAuth() {
    if (!_sshAgentAuthAvailable) {
      throw ConnectionProfileResolutionException(
        'connection_profile.ssh_agent_unsupported',
        'SSH agent authentication is not available on this platform.',
      );
    }
    return const SshAgentAuth();
  }

  SshHardwareKeyAuth _hardwareKeyAuth() {
    if (!_hardwareKeyAuthAvailable) {
      throw ConnectionProfileResolutionException(
        'connection_profile.hardware_key_unsupported',
        'Hardware key authentication is not available on this platform.',
      );
    }
    return const SshHardwareKeyAuth();
  }

  Future<SshPrivateKeyAuth> _privateKeyAuth(IdentityConfig identity) async {
    final secret = await _secretMaterial(identity);
    return SshPrivateKeyAuth(
      privateKeyPem: SecretBytes(secret.requirePrivateKey(identity.id)),
      passphrase: secret.privateKeyPassphrase == null
          ? null
          : SecretBytes(utf8.encode(secret.privateKeyPassphrase!)),
    );
  }

  Future<SshOpenSshCertificateAuth> _certificateAuth(
    IdentityConfig identity,
  ) async {
    final secret = await _secretMaterial(identity);
    return SshOpenSshCertificateAuth(
      privateKeyPem: SecretBytes(secret.requirePrivateKey(identity.id)),
      certificate: SecretBytes(secret.requireCertificate(identity.id)),
      passphrase: secret.privateKeyPassphrase == null
          ? null
          : SecretBytes(utf8.encode(secret.privateKeyPassphrase!)),
    );
  }

  Future<IdentitySecretMaterial> _secretMaterial(
    IdentityConfig identity,
  ) async {
    final secretRecordId = identity.secretRecordId;
    if (secretRecordId == null) {
      throw ConnectionProfileResolutionException(
        'connection_profile.identity_secret_missing',
        'Identity ${identity.id.value} does not reference a secret record.',
      );
    }
    final envelope = await _records.read(secretRecordId);
    if (envelope == null) {
      throw ConnectionProfileResolutionException(
        'connection_profile.secret_not_found',
        'Secret ${secretRecordId.value} does not exist.',
      );
    }
    return IdentitySecretMaterial.fromBytes(
      await _vault.decryptRecord(envelope),
    );
  }
}

class _ResolvedSshCredentials {
  const _ResolvedSshCredentials({
    required this.username,
    required this.authMethods,
  });

  final String username;
  final List<SshAuthMethod> authMethods;
}

String? _passwordUsernameFor(IdentityConfig identity) {
  if (identity.kind != IdentityKind.password) {
    return null;
  }
  final username = identity.usernameHint?.trim();
  if (username == null || username.isEmpty) {
    return null;
  }
  return username;
}

extension on IdentitySecretMaterial {
  List<int> requirePassword(IdentityId identityId) {
    final value = password;
    if (value == null) {
      throw ConnectionProfileResolutionException(
        'connection_profile.password_missing',
        'Identity ${identityId.value} does not contain a password.',
      );
    }
    return utf8.encode(value);
  }

  List<int> requirePrivateKey(IdentityId identityId) {
    final value = privateKeyPem;
    if (value == null) {
      throw ConnectionProfileResolutionException(
        'connection_profile.private_key_missing',
        'Identity ${identityId.value} does not contain a private key.',
      );
    }
    return utf8.encode(value);
  }

  List<int> requireCertificate(IdentityId identityId) {
    final value = openSshCertificate;
    if (value == null) {
      throw ConnectionProfileResolutionException(
        'connection_profile.certificate_missing',
        'Identity ${identityId.value} does not contain an OpenSSH certificate.',
      );
    }
    return utf8.encode(value);
  }
}
