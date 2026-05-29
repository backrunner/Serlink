import '../../../core/ids/entity_id.dart';
import '../../sftp/application/sftp_connection.dart';
import '../domain/connection_profile.dart';

enum HostKeyDecision { cancel, trustOnce, trustAndSave }

class HostKeyPrompt {
  const HostKeyPrompt({
    required this.hostId,
    required this.hostname,
    required this.port,
    required this.algorithm,
    required this.fingerprint,
    this.previousFingerprint,
  });

  final HostId hostId;
  final String hostname;
  final int port;
  final String algorithm;
  final String fingerprint;
  final String? previousFingerprint;

  HostKeyPrompt copyWith({String? previousFingerprint}) {
    return HostKeyPrompt(
      hostId: hostId,
      hostname: hostname,
      port: port,
      algorithm: algorithm,
      fingerprint: fingerprint,
      previousFingerprint: previousFingerprint ?? this.previousFingerprint,
    );
  }
}

class RemoteForwardBinding {
  const RemoteForwardBinding({
    required this.bindHost,
    required this.bindPort,
    required this.localHost,
    required this.localPort,
  });

  final String bindHost;
  final int bindPort;
  final String localHost;
  final int localPort;
}

class DynamicForwardBinding {
  const DynamicForwardBinding({required this.bindHost, required this.bindPort});

  final String bindHost;
  final int bindPort;
}

abstract interface class SshShellSession {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<void> get done;
  Future<void> write(List<int> bytes);
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  });
  Future<void> close();
}

abstract interface class SshSessionService {
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile);
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile);
  Future<void> testConnection(ConnectionProfileSnapshot profile);
  Future<void> startLocalForward({
    required SessionId sessionId,
    required int localPort,
    required String remoteHost,
    required int remotePort,
  });
  Future<void> stopLocalForward({required SessionId sessionId});
  Future<RemoteForwardBinding> startRemoteForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
    required String localHost,
    required int localPort,
  });
  Future<void> stopRemoteForward({required SessionId sessionId});
  Future<DynamicForwardBinding> startDynamicForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
  });
  Future<void> stopDynamicForward({required SessionId sessionId});
}
