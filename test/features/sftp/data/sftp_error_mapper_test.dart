import 'dart:io';

import 'package:dartssh2/dartssh2.dart' as ssh;
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sftp/application/sftp_failure.dart';
import 'package:serlink/features/sftp/data/sftp_error_mapper.dart';

void main() {
  test('maps SFTP status not found to stable failure', () {
    final failure = mapExternalSftpError(
      ssh.SftpStatusError(ssh.SftpStatusCode.noSuchFile, 'No such file'),
    );

    expect(failure.code, SftpFailureCode.notFound);
    expect(failure.code.id, 'sftp.not_found');
    expect(failure.message, 'Remote file or folder was not found.');
    expect(failure.diagnostic, contains('No such file'));
  });

  test('maps SFTP status permission denied to stable failure', () {
    final failure = mapExternalSftpError(
      ssh.SftpStatusError(
        ssh.SftpStatusCode.permissionDenied,
        'Permission denied',
      ),
    );

    expect(failure.code, SftpFailureCode.permissionDenied);
    expect(failure.code.id, 'sftp.permission_denied');
    expect(failure.message, 'Permission denied by the remote server.');
  });

  test('maps connection-loss SFTP status to reconnect guidance', () {
    final failure = mapExternalSftpError(
      ssh.SftpStatusError(ssh.SftpStatusCode.connectionLost, 'Connection lost'),
    );

    expect(failure.code, SftpFailureCode.connectionClosed);
    expect(failure.code.id, 'sftp.connection_closed');
    expect(failure.message, contains('Reconnect'));
  });

  test(
    'maps local file-system conflicts without exposing paths in message',
    () {
      final failure = mapExternalSftpError(
        const FileSystemException(
          'File exists',
          '/Users/person/private/key.pem',
          OSError('File exists', 17),
        ),
      );

      expect(failure.code, SftpFailureCode.conflict);
      expect(failure.message, isNot(contains('/Users/person/private')));
      expect(failure.diagnostic, contains('/Users/person/private/key.pem'));
    },
  );

  test('maps closed SFTP errors to connection closed', () {
    final failure = mapExternalSftpError(ssh.SftpError('File is closed'));

    expect(failure.code, SftpFailureCode.connectionClosed);
  });
}
