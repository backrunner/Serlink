import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/ssh/data/ssh_diagnostic_details.dart';

void main() {
  test('retains nested socket cause and OS code without sensitive text', () {
    final details = sshDiagnosticDetails(
      SSHAuthAbortError(
        'private auth text',
        SSHSocketError(
          SocketException(
            'password=secret host=private.example',
            osError: const OSError('private error text', 54),
          ),
        ),
      ),
    );
    final encoded = jsonEncode(details);
    expect(encoded, contains('SSHAuthAbortError'));
    expect(encoded, contains('SSHSocketError'));
    expect(encoded, contains('SocketException'));
    expect(encoded, contains('"osErrorCode":54'));
    expect(encoded, isNot(contains('private')));
    expect(encoded, isNot(contains('secret')));
  });

  test('records peer rejection and PTY failures without remote text', () {
    expect(
      sshDiagnosticDetails(SSHDisconnectError(2, 'private data')),
      containsPair('reasonCode', 2),
    );
    expect(
      sshDiagnosticDetails(SSHChannelRequestError('Failed to start pty')),
      containsPair('request', 'pty'),
    );
    expect(
      sshDiagnosticDetails(SSHChannelRequestError('command=private')),
      containsPair('request', 'other'),
    );
  });
}
