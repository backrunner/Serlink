import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../../core/security/secret_bytes.dart';
import '../domain/connection_profile.dart';

abstract interface class ConnectionProfileResolver {
  Future<ConnectionProfileSnapshot> resolve({
    required HostId hostId,
    required SessionId sessionId,
  });
}

class LockedVaultConnectionProfileResolver
    implements ConnectionProfileResolver {
  const LockedVaultConnectionProfileResolver();

  @override
  Future<ConnectionProfileSnapshot> resolve({
    required HostId hostId,
    required SessionId sessionId,
  }) async {
    throw const ConnectionProfileResolutionException(
      'connection_profile.vault_locked',
      'Unlock the vault before starting a new connection.',
    );
  }
}

class StaticConnectionProfileResolver implements ConnectionProfileResolver {
  StaticConnectionProfileResolver(this._profiles);

  final Map<HostId, StaticConnectionProfile> _profiles;

  @override
  Future<ConnectionProfileSnapshot> resolve({
    required HostId hostId,
    required SessionId sessionId,
  }) async {
    final profile = _profiles[hostId];
    if (profile == null) {
      throw ConnectionProfileResolutionException(
        'connection_profile.not_found',
        'No connection profile exists for host ${hostId.value}.',
      );
    }
    return profile.toSnapshot(sessionId: sessionId);
  }
}

class StaticConnectionProfile {
  const StaticConnectionProfile({
    required this.hostId,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authMethods,
    this.startupCommands = const [],
    this.jumpHosts = const [],
    this.portForwarding = const SshPortForwardingProfile(),
    this.connectTimeout = const Duration(seconds: 20),
    this.keepAliveInterval = const Duration(seconds: 10),
    this.reconnectPolicy = const SshReconnectPolicy(),
  });

  final HostId hostId;
  final String hostname;
  final int port;
  final String username;
  final List<SshAuthMethod> authMethods;
  final List<String> startupCommands;
  final List<SshJumpHostSnapshot> jumpHosts;
  final SshPortForwardingProfile portForwarding;
  final Duration connectTimeout;
  final Duration? keepAliveInterval;
  final SshReconnectPolicy reconnectPolicy;

  ConnectionProfileSnapshot toSnapshot({required SessionId sessionId}) {
    return ConnectionProfileSnapshot(
      sessionId: sessionId,
      hostId: hostId,
      hostname: hostname,
      port: port,
      username: username,
      authMethods: authMethods,
      startupCommands: startupCommands,
      jumpHosts: jumpHosts,
      portForwarding: portForwarding,
      connectTimeout: connectTimeout,
      keepAliveInterval: keepAliveInterval,
      reconnectPolicy: reconnectPolicy,
    );
  }
}

class ConnectionProfileResolutionException implements Exception {
  const ConnectionProfileResolutionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ConnectionProfileResolutionException($code): $message';
}

SshPasswordAuth staticPasswordAuth(String password) {
  return SshPasswordAuth(password: SecretBytes(utf8.encode(password)));
}
