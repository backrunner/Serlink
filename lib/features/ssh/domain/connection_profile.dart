import '../../../core/ids/entity_id.dart';
import '../../../core/security/secret_bytes.dart';

class ConnectionProfileSnapshot {
  const ConnectionProfileSnapshot({
    required this.sessionId,
    required this.hostId,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authMethods,
    this.startupCommands = const [],
    this.jumpHosts = const [],
    this.connectTimeout = const Duration(seconds: 20),
    this.keepAliveInterval = const Duration(seconds: 10),
    this.reconnectPolicy = const SshReconnectPolicy(),
    this.terminalColumns = 80,
    this.terminalRows = 24,
  });

  final SessionId sessionId;
  final HostId hostId;
  final String hostname;
  final int port;
  final String username;
  final List<SshAuthMethod> authMethods;
  final List<String> startupCommands;
  final List<SshJumpHostSnapshot> jumpHosts;
  final Duration connectTimeout;
  final Duration? keepAliveInterval;
  final SshReconnectPolicy reconnectPolicy;
  final int terminalColumns;
  final int terminalRows;
}

class SshJumpHostSnapshot {
  const SshJumpHostSnapshot({
    required this.hostId,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authMethods,
    this.connectTimeout = const Duration(seconds: 20),
    this.keepAliveInterval = const Duration(seconds: 10),
  });

  final HostId hostId;
  final String hostname;
  final int port;
  final String username;
  final List<SshAuthMethod> authMethods;
  final Duration connectTimeout;
  final Duration? keepAliveInterval;
}

class SshReconnectPolicy {
  const SshReconnectPolicy({
    this.maxAttempts = 0,
    this.backoff = const Duration(seconds: 5),
  });

  final int maxAttempts;
  final Duration backoff;

  bool get isAutomatic => maxAttempts > 0;
}

sealed class SshAuthMethod {
  const SshAuthMethod();
}

class SshPasswordAuth extends SshAuthMethod {
  const SshPasswordAuth({required this.password});

  final SecretBytes password;
}

class SshPrivateKeyAuth extends SshAuthMethod {
  const SshPrivateKeyAuth({required this.privateKeyPem, this.passphrase});

  final SecretBytes privateKeyPem;
  final SecretBytes? passphrase;
}

class SshKeyboardInteractiveAuth extends SshAuthMethod {
  const SshKeyboardInteractiveAuth({required this.responses});

  final List<SecretBytes> responses;
}

class SshAgentAuth extends SshAuthMethod {
  const SshAgentAuth();
}

class SshOpenSshCertificateAuth extends SshAuthMethod {
  const SshOpenSshCertificateAuth({
    required this.privateKeyPem,
    required this.certificate,
    this.passphrase,
  });

  final SecretBytes privateKeyPem;
  final SecretBytes certificate;
  final SecretBytes? passphrase;
}

class SshHardwareKeyAuth extends SshAuthMethod {
  const SshHardwareKeyAuth();
}

class UnsupportedSshAuthException implements Exception {
  const UnsupportedSshAuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'UnsupportedSshAuthException($code): $message';
}
