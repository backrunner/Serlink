// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/ssh_hostkey.dart';

import '../../../core/ids/entity_id.dart';
import '../../../core/logging/offline_diagnostic_logger.dart';
import '../../sftp/application/sftp_connection.dart';
import '../../sftp/data/dartssh2_sftp_connection.dart';
import '../application/ssh_session_service.dart';
import '../domain/connection_profile.dart';
import 'ssh_agent_client.dart';

typedef SshSocketFactory =
    Future<SSHSocket> Function(String host, int port, {Duration? timeout});

class DartSsh2SessionService implements SshSessionService {
  DartSsh2SessionService({
    SshSocketFactory socketFactory = SSHSocket.connect,
    Future<HostKeyDecision> Function(HostKeyPrompt prompt)? confirmHostKey,
    SshAgentClient agentClient = const LocalSshAgentClient(),
    DiagnosticLogger diagnosticLogger = const NoopDiagnosticLogger(),
  }) : this._(socketFactory, confirmHostKey, agentClient, diagnosticLogger);

  DartSsh2SessionService._(
    this._socketFactory,
    this._confirmHostKey,
    this._agentClient,
    this._diagnosticLogger,
  );

  final SshSocketFactory _socketFactory;
  final Future<HostKeyDecision> Function(HostKeyPrompt prompt)? _confirmHostKey;
  final SshAgentClient _agentClient;
  final DiagnosticLogger _diagnosticLogger;
  final Map<SessionId, _SshClientChain> _clientChains = {};
  final Map<SessionId, ServerSocket> _localForwards = {};
  final Map<SessionId, SSHRemoteForward> _remoteForwards = {};
  final Map<SessionId, SSHDynamicForward> _dynamicForwards = {};
  final Map<SessionId, List<ServerSocket>> _profileLocalForwards = {};
  final Map<SessionId, List<SSHRemoteForward>> _profileRemoteForwards = {};
  final Map<SessionId, List<SSHDynamicForward>> _profileDynamicForwards = {};

  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    final chain = await _connect(profile, purpose: 'shell');
    late final SSHSession session;
    try {
      session = await chain.target.shell(
        pty: SSHPtyConfig(
          width: profile.terminalColumns,
          height: profile.terminalRows,
        ),
      );
    } on Object {
      chain.close();
      rethrow;
    }
    _clientChains[profile.sessionId] = chain;
    try {
      await _startProfileForwarding(profile, chain.target);
    } on Object {
      session.close();
      await _closeSessionResources(profile.sessionId);
      rethrow;
    }
    return DartSsh2ShellSession(
      session: session,
      onClose: () => _closeSessionResources(profile.sessionId),
    );
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) async {
    final chain = await _connect(profile, purpose: 'sftp');
    late final SftpClient sftp;
    try {
      sftp = await chain.target.sftp();
    } on Object {
      chain.close();
      rethrow;
    }
    _clientChains[profile.sessionId] = chain;
    try {
      await _startProfileForwarding(profile, chain.target);
    } on Object {
      sftp.close();
      await _closeSessionResources(profile.sessionId);
      rethrow;
    }
    return DartSsh2SftpConnection(
      sftpClient: sftp,
      sshClient: chain.target,
      onClose: () => _closeSessionResources(profile.sessionId),
    );
  }

  @override
  Future<void> testConnection(ConnectionProfileSnapshot profile) async {
    final chain = await _connect(profile, purpose: 'test');
    try {
      await chain.target.ping();
    } finally {
      chain.close();
    }
  }

  @override
  Future<void> startLocalForward({
    required SessionId sessionId,
    required int localPort,
    required String remoteHost,
    required int remotePort,
  }) async {
    final client = _activeClient(sessionId);

    await _localForwards.remove(sessionId)?.close();
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      localPort,
    );
    _localForwards[sessionId] = server;

    unawaited(
      server.forEach((socket) {
        unawaited(_pipeForward(client, socket, remoteHost, remotePort));
      }),
    );
  }

  @override
  Future<void> stopLocalForward({required SessionId sessionId}) async {
    await _localForwards.remove(sessionId)?.close();
  }

  @override
  Future<RemoteForwardBinding> startRemoteForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
    required String localHost,
    required int localPort,
  }) async {
    final client = _activeClient(sessionId);
    await stopRemoteForward(sessionId: sessionId);
    final forward = await client.forwardRemote(host: bindHost, port: bindPort);
    if (forward == null) {
      throw StateError('Remote port forward request was rejected.');
    }
    _remoteForwards[sessionId] = forward;
    unawaited(
      forward.connections.forEach((channel) {
        unawaited(_pipeRemoteForward(channel, localHost, localPort));
      }),
    );
    return RemoteForwardBinding(
      bindHost: forward.host.isEmpty ? '0.0.0.0' : forward.host,
      bindPort: forward.port,
      localHost: localHost,
      localPort: localPort,
    );
  }

  @override
  Future<void> stopRemoteForward({required SessionId sessionId}) async {
    _remoteForwards.remove(sessionId)?.close();
  }

  @override
  Future<DynamicForwardBinding> startDynamicForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
  }) async {
    final client = _activeClient(sessionId);
    await stopDynamicForward(sessionId: sessionId);
    final forward = await client.forwardDynamic(
      bindHost: bindHost,
      bindPort: bindPort,
    );
    _dynamicForwards[sessionId] = forward;
    return DynamicForwardBinding(
      bindHost: forward.host,
      bindPort: forward.port,
    );
  }

  @override
  Future<void> stopDynamicForward({required SessionId sessionId}) async {
    await _dynamicForwards.remove(sessionId)?.close();
  }

  Future<void> _closeSessionResources(SessionId sessionId) async {
    await stopLocalForward(sessionId: sessionId);
    await _stopProfileLocalForwards(sessionId);
    await stopDynamicForward(sessionId: sessionId);
    await _stopProfileDynamicForwards(sessionId);
    await stopRemoteForward(sessionId: sessionId);
    await _stopProfileRemoteForwards(sessionId);
    _clientChains.remove(sessionId)?.close();
  }

  SSHClient _activeClient(SessionId sessionId) {
    final client = _clientChains[sessionId]?.target;
    if (client == null || client.isClosed) {
      throw StateError('No active SSH client for session ${sessionId.value}.');
    }
    return client;
  }

  Future<void> _startProfileForwarding(
    ConnectionProfileSnapshot profile,
    SSHClient client,
  ) async {
    final forwarding = profile.portForwarding;
    if (forwarding.isEmpty) {
      return;
    }
    for (final forward in forwarding.localForwards) {
      await _startProfileLocalForward(
        sessionId: profile.sessionId,
        client: client,
        forward: forward,
      );
    }
    for (final forward in forwarding.remoteForwards) {
      await _startProfileRemoteForward(
        sessionId: profile.sessionId,
        client: client,
        forward: forward,
      );
    }
    for (final forward in forwarding.dynamicForwards) {
      await _startProfileDynamicForward(
        sessionId: profile.sessionId,
        client: client,
        forward: forward,
      );
    }
  }

  Future<void> _startProfileLocalForward({
    required SessionId sessionId,
    required SSHClient client,
    required SshLocalPortForward forward,
  }) async {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      forward.localPort,
    );
    (_profileLocalForwards[sessionId] ??= []).add(server);
    unawaited(
      server.forEach((socket) {
        unawaited(
          _pipeForward(client, socket, forward.remoteHost, forward.remotePort),
        );
      }),
    );
  }

  Future<void> _startProfileRemoteForward({
    required SessionId sessionId,
    required SSHClient client,
    required SshRemotePortForward forward,
  }) async {
    final remoteForward = await client.forwardRemote(
      host: forward.bindHost,
      port: forward.bindPort,
    );
    if (remoteForward == null) {
      throw StateError('Remote port forward request was rejected.');
    }
    (_profileRemoteForwards[sessionId] ??= []).add(remoteForward);
    unawaited(
      remoteForward.connections.forEach((channel) {
        unawaited(
          _pipeRemoteForward(channel, forward.localHost, forward.localPort),
        );
      }),
    );
  }

  Future<void> _startProfileDynamicForward({
    required SessionId sessionId,
    required SSHClient client,
    required SshDynamicPortForward forward,
  }) async {
    final dynamicForward = await client.forwardDynamic(
      bindHost: forward.bindHost,
      bindPort: forward.bindPort,
    );
    (_profileDynamicForwards[sessionId] ??= []).add(dynamicForward);
  }

  Future<void> _stopProfileLocalForwards(SessionId sessionId) async {
    final forwards = _profileLocalForwards.remove(sessionId);
    if (forwards == null) {
      return;
    }
    for (final forward in forwards) {
      await forward.close();
    }
  }

  Future<void> _stopProfileRemoteForwards(SessionId sessionId) async {
    final forwards = _profileRemoteForwards.remove(sessionId);
    if (forwards == null) {
      return;
    }
    for (final forward in forwards) {
      forward.close();
    }
  }

  Future<void> _stopProfileDynamicForwards(SessionId sessionId) async {
    final forwards = _profileDynamicForwards.remove(sessionId);
    if (forwards == null) {
      return;
    }
    for (final forward in forwards) {
      await forward.close();
    }
  }

  Future<_SshClientChain> _connect(
    ConnectionProfileSnapshot profile, {
    required String purpose,
  }) async {
    final details = _connectionLogDetails(profile, purpose: purpose);
    await _diagnosticLogger.record('ssh.connect.start', details: details);
    final clients = <SSHClient>[];
    try {
      SSHSocket socket;
      if (profile.jumpHosts.isEmpty) {
        socket = await _socketFactory(
          profile.hostname,
          profile.port,
          timeout: profile.connectTimeout,
        );
      } else {
        final firstJump = profile.jumpHosts.first;
        socket = await _socketFactory(
          firstJump.hostname,
          firstJump.port,
          timeout: firstJump.connectTimeout,
        );
        for (var index = 0; index < profile.jumpHosts.length; index += 1) {
          final jump = profile.jumpHosts[index];
          final jumpClient = _createClient(socket, _SshEndpoint.fromJump(jump));
          clients.add(jumpClient);
          final nextJump = index + 1 < profile.jumpHosts.length
              ? profile.jumpHosts[index + 1]
              : null;
          socket = await jumpClient.forwardLocal(
            nextJump?.hostname ?? profile.hostname,
            nextJump?.port ?? profile.port,
          );
        }
      }

      clients.add(_createClient(socket, _SshEndpoint.fromProfile(profile)));
      final chain = _SshClientChain(clients);
      await _diagnosticLogger.record('ssh.connect.success', details: details);
      return chain;
    } on Object catch (error) {
      await _diagnosticLogger.record(
        'ssh.connect.failure',
        level: DiagnosticLogLevel.error,
        details: {...details, ..._sshErrorDetails(error)},
      );
      _SshClientChain(clients).close();
      rethrow;
    }
  }

  Map<String, Object?> _connectionLogDetails(
    ConnectionProfileSnapshot profile, {
    required String purpose,
  }) {
    return {
      'sessionId': profile.sessionId.value,
      'purpose': purpose,
      'jumpHosts': profile.jumpHosts.length,
      'authMethods': _authMethodKinds(profile.authMethods),
      'automaticReconnect': profile.reconnectPolicy.isAutomatic,
      'connectTimeoutSeconds': profile.connectTimeout.inSeconds,
    };
  }

  List<String> _authMethodKinds(List<SshAuthMethod> authMethods) {
    return [
      for (final method in authMethods)
        switch (method) {
          SshPasswordAuth() => 'password',
          SshPrivateKeyAuth() => 'privateKey',
          SshKeyboardInteractiveAuth() => 'keyboardInteractive',
          SshAgentAuth() => 'agent',
          SshOpenSshCertificateAuth() => 'openSshCertificate',
          SshHardwareKeyAuth() => 'hardwareKey',
        },
    ];
  }

  Map<String, Object?> _sshErrorDetails(Object error) {
    return switch (error) {
      UnsupportedSshAuthException(:final code) => {
        'errorType': 'UnsupportedSshAuthException',
        'code': code,
      },
      SshAgentException(:final code) => {
        'errorType': 'SshAgentException',
        'code': code,
      },
      _ => {'errorType': error.runtimeType.toString()},
    };
  }

  SSHClient _createClient(SSHSocket socket, _SshEndpoint endpoint) {
    final material = DartSsh2AuthMaterial.fromAuthMethods(
      endpoint.authMethods,
      agentClient: _agentClient,
    );
    return SSHClient(
      socket,
      username: endpoint.username,
      identities: material.identities.isEmpty ? null : material.identities,
      onPasswordRequest: material.password == null
          ? null
          : () => material.password,
      onUserInfoRequest: material.keyboardInteractiveResponses.isEmpty
          ? null
          : (_) => material.keyboardInteractiveResponses,
      keepAliveInterval: endpoint.keepAliveInterval,
      onVerifyHostKey: (algorithm, fingerprint) {
        return _verifyHostKey(endpoint, algorithm, fingerprint);
      },
    );
  }

  Future<bool> _verifyHostKey(
    _SshEndpoint endpoint,
    String algorithm,
    Uint8List fingerprint,
  ) async {
    final confirmHostKey = _confirmHostKey;
    if (confirmHostKey == null) {
      return true;
    }
    final decision = await confirmHostKey(
      HostKeyPrompt(
        hostId: endpoint.hostId,
        hostname: endpoint.hostname,
        port: endpoint.port,
        algorithm: algorithm,
        fingerprint: _formatMd5Fingerprint(fingerprint),
      ),
    );
    return decision != HostKeyDecision.cancel;
  }
}

class DartSsh2AuthMaterial {
  const DartSsh2AuthMaterial({
    required this.identities,
    required this.keyboardInteractiveResponses,
    this.password,
  });

  final List<SSHKeyPair> identities;
  final String? password;
  final List<String> keyboardInteractiveResponses;

  factory DartSsh2AuthMaterial.fromProfile(
    ConnectionProfileSnapshot profile, {
    SshAgentClient agentClient = const LocalSshAgentClient(),
  }) {
    return DartSsh2AuthMaterial.fromAuthMethods(
      profile.authMethods,
      agentClient: agentClient,
    );
  }

  factory DartSsh2AuthMaterial.fromAuthMethods(
    List<SshAuthMethod> authMethods, {
    SshAgentClient agentClient = const LocalSshAgentClient(),
  }) {
    final identities = <SSHKeyPair>[];
    final keyboardResponses = <String>[];
    String? passwordValue;
    var agentRequested = false;

    for (final method in authMethods) {
      switch (method) {
        case SshPasswordAuth(:final password):
          passwordValue ??= utf8.decode(password.copyBytes());
        case SshPrivateKeyAuth(:final privateKeyPem, :final passphrase):
          identities.addAll(
            SSHKeyPair.fromPem(
              utf8.decode(privateKeyPem.copyBytes()),
              passphrase == null ? null : utf8.decode(passphrase.copyBytes()),
            ),
          );
        case SshKeyboardInteractiveAuth(:final responses):
          keyboardResponses.addAll([
            for (final response in responses) utf8.decode(response.copyBytes()),
          ]);
        case SshAgentAuth():
          if (agentRequested) {
            continue;
          }
          agentRequested = true;
          try {
            identities.addAll([
              for (final identity in agentClient.listIdentities())
                SshAgentKeyPair(identity: identity, agent: agentClient),
            ]);
          } on SshAgentException catch (error) {
            throw UnsupportedSshAuthException(
              'ssh_auth.agent_unavailable',
              error.message,
            );
          } on Object {
            throw const UnsupportedSshAuthException(
              'ssh_auth.agent_unavailable',
              'SSH agent is not available.',
            );
          }
        case SshOpenSshCertificateAuth(
          :final privateKeyPem,
          :final certificate,
          :final passphrase,
        ):
          final userCertificate = _OpenSshUserCertificate.parse(
            utf8.decode(certificate.copyBytes()),
          );
          identities.addAll(
            SSHKeyPair.fromPem(
              utf8.decode(privateKeyPem.copyBytes()),
              passphrase == null ? null : utf8.decode(passphrase.copyBytes()),
            ).map(
              (keyPair) => _OpenSshCertificateKeyPair(
                keyPair: keyPair,
                certificate: userCertificate,
              ),
            ),
          );
        case SshHardwareKeyAuth():
          throw const UnsupportedSshAuthException(
            'ssh_auth.hardware_key_unsupported',
            'Hardware security key authentication requires platform support.',
          );
      }
    }

    if (passwordValue == null &&
        identities.isEmpty &&
        keyboardResponses.isEmpty) {
      if (agentRequested) {
        throw const UnsupportedSshAuthException(
          'ssh_auth.agent_empty',
          'SSH agent has no loaded identities.',
        );
      }
      throw const UnsupportedSshAuthException(
        'ssh_auth.empty',
        'Connection profile does not contain a supported authentication method.',
      );
    }

    return DartSsh2AuthMaterial(
      identities: identities,
      password: passwordValue,
      keyboardInteractiveResponses: keyboardResponses,
    );
  }
}

class DartSsh2ShellSession implements SshShellSession {
  DartSsh2ShellSession({
    required SSHSession session,
    Future<void> Function()? onClose,
  }) : this._(session, onClose);

  DartSsh2ShellSession._(this._session, this._onClose) {
    _done = _session.done.whenComplete(_cleanup);
  }

  final SSHSession _session;
  final Future<void> Function()? _onClose;
  late final Future<void> _done;
  bool _closed = false;

  @override
  Stream<List<int>> get stdout => _session.stdout;

  @override
  Stream<List<int>> get stderr => _session.stderr;

  @override
  Future<void> get done => _done;

  @override
  Future<void> write(List<int> bytes) async {
    _session.write(Uint8List.fromList(bytes));
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    _session.resizeTerminal(columns, rows, pixelWidth ?? 0, pixelHeight ?? 0);
  }

  @override
  Future<void> close() async {
    _session.close();
    await _cleanup();
    await _session.done.catchError((Object _) {});
  }

  Future<void> _cleanup() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _onClose?.call();
  }
}

class _SshEndpoint {
  const _SshEndpoint({
    required this.hostId,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authMethods,
    this.keepAliveInterval,
  });

  factory _SshEndpoint.fromProfile(ConnectionProfileSnapshot profile) {
    return _SshEndpoint(
      hostId: profile.hostId,
      hostname: profile.hostname,
      port: profile.port,
      username: profile.username,
      authMethods: profile.authMethods,
      keepAliveInterval: profile.keepAliveInterval,
    );
  }

  factory _SshEndpoint.fromJump(SshJumpHostSnapshot jump) {
    return _SshEndpoint(
      hostId: jump.hostId,
      hostname: jump.hostname,
      port: jump.port,
      username: jump.username,
      authMethods: jump.authMethods,
      keepAliveInterval: jump.keepAliveInterval,
    );
  }

  final HostId hostId;
  final String hostname;
  final int port;
  final String username;
  final List<SshAuthMethod> authMethods;
  final Duration? keepAliveInterval;
}

class _SshClientChain {
  const _SshClientChain(this.clients);

  final List<SSHClient> clients;

  SSHClient get target => clients.last;

  void close() {
    for (final client in clients.reversed) {
      client.close();
    }
  }
}

class _OpenSshUserCertificate {
  const _OpenSshUserCertificate({required this.algorithm, required this.blob});

  final String algorithm;
  final Uint8List blob;

  static _OpenSshUserCertificate parse(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || !parts.first.endsWith('-cert-v01@openssh.com')) {
      throw const UnsupportedSshAuthException(
        'ssh_auth.certificate_invalid',
        'OpenSSH certificate material is not a certificate public-key line.',
      );
    }
    try {
      return _OpenSshUserCertificate(
        algorithm: parts.first,
        blob: base64Decode(parts[1]),
      );
    } on FormatException {
      throw const UnsupportedSshAuthException(
        'ssh_auth.certificate_invalid',
        'OpenSSH certificate public-key payload is not valid base64.',
      );
    }
  }
}

class _OpenSshCertificateKeyPair implements SSHKeyPair {
  const _OpenSshCertificateKeyPair({
    required this.keyPair,
    required this.certificate,
  });

  final SSHKeyPair keyPair;
  final _OpenSshUserCertificate certificate;

  @override
  String get name => keyPair.name;

  @override
  String get type => certificate.algorithm;

  @override
  SSHSignature sign(Uint8List data) => keyPair.sign(data);

  @override
  SSHHostKey toPublicKey() => _RawSshHostKey(certificate.blob);

  @override
  String toPem() => keyPair.toPem();
}

class _RawSshHostKey implements SSHHostKey {
  const _RawSshHostKey(this._encoded);

  final Uint8List _encoded;

  @override
  Uint8List encode() => _encoded;
}

Future<void> _pipeForward(
  SSHClient client,
  Socket socket,
  String remoteHost,
  int remotePort,
) async {
  try {
    final channel = await client.forwardLocal(remoteHost, remotePort);
    final remoteToLocal = socket.addStream(channel.stream);
    final localToRemote = channel.sink.addStream(socket);
    await Future.wait([remoteToLocal, localToRemote]);
    await channel.close();
  } finally {
    await socket.close();
  }
}

Future<void> _pipeRemoteForward(
  SSHForwardChannel channel,
  String localHost,
  int localPort,
) async {
  Socket? socket;
  try {
    socket = await Socket.connect(localHost, localPort);
    final remoteToLocal = socket.addStream(channel.stream);
    final localToRemote = channel.sink.addStream(socket);
    await Future.wait([remoteToLocal, localToRemote]);
    await channel.close();
  } finally {
    await socket?.close();
  }
}

String _formatMd5Fingerprint(Uint8List fingerprint) {
  final parts = [
    for (final byte in fingerprint) byte.toRadixString(16).padLeft(2, '0'),
  ];
  return 'MD5:${parts.join(':')}';
}
