import 'dart:io';

import 'package:dartssh2/dartssh2.dart' as ssh;

import '../application/sftp_failure.dart';

SftpFailure mapExternalSftpError(Object error) {
  if (error case SftpFailureException(:final failure)) {
    return failure;
  }
  if (error case SftpFailure failure) {
    return failure;
  }

  final diagnostic = error.toString();
  if (error case ssh.SftpStatusError(:final code)) {
    return switch (code) {
      ssh.SftpStatusCode.noSuchFile => SftpFailure.notFound(
        diagnostic: diagnostic,
      ),
      ssh.SftpStatusCode.permissionDenied => SftpFailure.permissionDenied(
        diagnostic: diagnostic,
      ),
      ssh.SftpStatusCode.noConnection || ssh.SftpStatusCode.connectionLost =>
        SftpFailure.connectionClosed(diagnostic: diagnostic),
      _ => SftpFailure.operationFailed(diagnostic: diagnostic),
    };
  }

  if (error case FileSystemException(:final osError, :final message)) {
    final errorCode = osError?.errorCode;
    final normalized = message.toLowerCase();
    if (_isNotFoundError(errorCode, normalized)) {
      return SftpFailure.notFound(diagnostic: diagnostic);
    }
    if (_isPermissionDeniedError(errorCode, normalized)) {
      return SftpFailure.permissionDenied(diagnostic: diagnostic);
    }
    if (_isConflictError(errorCode, normalized)) {
      return SftpFailure.conflict(diagnostic: diagnostic);
    }
    return SftpFailure.operationFailed(diagnostic: diagnostic);
  }

  if (error is SocketException || error is ssh.SSHSocketError) {
    return SftpFailure.connectionClosed(diagnostic: diagnostic);
  }

  if (error case ssh.SftpError(:final message)) {
    final normalized = message.toLowerCase();
    if (_looksConnectionClosed(normalized)) {
      return SftpFailure.connectionClosed(diagnostic: diagnostic);
    }
    return SftpFailure.operationFailed(diagnostic: diagnostic);
  }

  if (error case ssh.SSHStateError(:final message)) {
    final normalized = message.toLowerCase();
    if (_looksConnectionClosed(normalized)) {
      return SftpFailure.connectionClosed(diagnostic: diagnostic);
    }
    return SftpFailure.operationFailed(diagnostic: diagnostic);
  }

  return SftpFailure.operationFailed(diagnostic: diagnostic);
}

bool _isNotFoundError(int? code, String message) {
  return code == 2 ||
      code == 3 ||
      message.contains('no such file') ||
      message.contains('cannot find') ||
      message.contains('path not found');
}

bool _isPermissionDeniedError(int? code, String message) {
  return code == 5 ||
      code == 13 ||
      message.contains('permission denied') ||
      message.contains('access denied');
}

bool _isConflictError(int? code, String message) {
  return code == 17 ||
      code == 80 ||
      code == 183 ||
      message.contains('already exists') ||
      message.contains('file exists');
}

bool _looksConnectionClosed(String message) {
  return message.contains('closed') ||
      message.contains('connection lost') ||
      message.contains('no connection') ||
      message.contains('broken pipe') ||
      message.contains('reset by peer');
}
