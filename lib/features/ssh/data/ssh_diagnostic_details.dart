import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../application/connection_profile_resolver.dart';
import '../domain/connection_profile.dart';
import 'ssh_agent_client.dart';

/// Structured causes only: arbitrary exception messages can contain credentials,
/// hostnames, paths, commands, or text supplied by a remote server.
Map<String, Object?> sshDiagnosticDetails(
  Object error, {
  StackTrace? stackTrace,
}) {
  return {
    'errorType': error.runtimeType.toString(),
    ...switch (error) {
      UnsupportedSshAuthException(:final code) => {'code': code},
      ConnectionProfileResolutionException(:final code) => {'code': code},
      SshAgentException(:final code) => {'code': code},
      SSHAuthFailError() => {'code': 'ssh.authentication_failed'},
      SSHAuthAbortError(:final reason) => {
        'code': 'ssh.authentication_aborted',
        if (reason != null) 'cause': sshDiagnosticDetails(reason),
      },
      SSHDisconnectError(:final reasonCode) => {
        'code': 'ssh.peer_disconnected',
        'reasonCode': reasonCode,
      },
      SSHChannelOpenError(:final code) => {
        'code': 'ssh.channel_open_failed',
        'reasonCode': code,
      },
      SSHChannelRequestError(:final message) => {
        'code': 'ssh.channel_request_failed',
        'request': switch (message) {
          'Failed to start pty' => 'pty',
          'Failed to start shell' => 'shell',
          _ => 'other',
        },
      },
      SSHHostkeyError() => {'code': 'ssh.host_key_rejected'},
      SSHHandshakeError() => {'code': 'ssh.handshake_failed'},
      SSHSocketError(:final error) => {'cause': sshDiagnosticDetails(error)},
      SSHInternalError(:final error) => {'cause': sshDiagnosticDetails(error)},
      SocketException(:final osError) => {
        'code': 'ssh.socket_failed',
        if (osError != null) 'osErrorCode': osError.errorCode,
      },
      TimeoutException() => {'code': 'ssh.timeout'},
      _ => <String, Object?>{},
    },
    // Package frames identify the failing code without local filesystem paths.
    if (stackTrace != null)
      'stack': stackTrace
          .toString()
          .split('\n')
          .where(
            (line) => line.contains('(package:') || line.contains('(dart:'),
          )
          .take(8)
          .join('\n'),
  };
}
