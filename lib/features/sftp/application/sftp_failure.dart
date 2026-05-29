import '../../../core/failure/app_failure.dart';

enum SftpFailureCode {
  notFound('sftp.not_found'),
  permissionDenied('sftp.permission_denied'),
  connectionClosed('sftp.connection_closed'),
  conflict('sftp.conflict'),
  operationFailed('sftp.operation_failed');

  const SftpFailureCode(this.id);

  final String id;
}

class SftpFailure {
  const SftpFailure({
    required this.code,
    required this.message,
    this.diagnostic,
  });

  factory SftpFailure.notFound({String? diagnostic}) {
    return SftpFailure(
      code: SftpFailureCode.notFound,
      message: 'Remote file or folder was not found.',
      diagnostic: diagnostic,
    );
  }

  factory SftpFailure.permissionDenied({String? diagnostic}) {
    return SftpFailure(
      code: SftpFailureCode.permissionDenied,
      message: 'Permission denied by the remote server.',
      diagnostic: diagnostic,
    );
  }

  factory SftpFailure.connectionClosed({String? diagnostic}) {
    return SftpFailure(
      code: SftpFailureCode.connectionClosed,
      message: 'The SFTP connection was closed. Reconnect and try again.',
      diagnostic: diagnostic,
    );
  }

  factory SftpFailure.conflict({String? diagnostic}) {
    return SftpFailure(
      code: SftpFailureCode.conflict,
      message: 'A file or folder already exists at the target path.',
      diagnostic: diagnostic,
    );
  }

  factory SftpFailure.operationFailed({String? diagnostic}) {
    return SftpFailure(
      code: SftpFailureCode.operationFailed,
      message: 'SFTP operation failed.',
      diagnostic: diagnostic,
    );
  }

  final SftpFailureCode code;
  final String message;
  final String? diagnostic;

  AppFailure toAppFailure() {
    return AppFailure(code: code.id, message: message, diagnostic: diagnostic);
  }
}

class SftpFailureException implements Exception {
  const SftpFailureException(this.failure);

  final SftpFailure failure;

  @override
  String toString() {
    return '${failure.code.id}: ${failure.message}';
  }
}

SftpFailure sftpFailureFrom(Object error) {
  return switch (error) {
    SftpFailure(:final code, :final message, :final diagnostic) => SftpFailure(
      code: code,
      message: message,
      diagnostic: diagnostic,
    ),
    SftpFailureException(:final failure) => failure,
    _ => SftpFailure.operationFailed(diagnostic: error.toString()),
  };
}

String sftpFailureMessage(Object error) {
  return sftpFailureFrom(error).message;
}
