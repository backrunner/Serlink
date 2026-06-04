import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart' as ssh;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/application/sftp_failure.dart';
import 'package:serlink/features/sftp/data/dartssh2_sftp_connection.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';

void main() {
  final settings = _SftpIntegrationSettings.fromEnvironment();

  test(
    'round trips chmod, timestamps, recursive transfers, overwrites, and failures',
    () async {
      final connection = await _openConnection(settings);
      final runRoot = p.posix.join(
        settings.remoteRoot,
        'serlink-${DateTime.now().microsecondsSinceEpoch}',
      );
      await connection.mkdir(runRoot);
      try {
        await _exerciseFileUpload(connection, runRoot);
        await _exerciseDirectoryTransfer(connection, runRoot);
        await _exerciseOverwrite(connection, runRoot);
        await _exerciseFailureMapping(connection, runRoot);
      } finally {
        await connection.deleteDirectory(runRoot, recursive: true);
        await connection.close();
      }
    },
    skip: settings.enabled
        ? false
        : 'Set SERLINK_SFTP_INTEGRATION=1 and start test/fixtures/sftp.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<DartSsh2SftpConnection> _openConnection(
  _SftpIntegrationSettings settings,
) async {
  final socket = await ssh.SSHSocket.connect(
    settings.host,
    settings.port,
    timeout: const Duration(seconds: 10),
  );
  final client = ssh.SSHClient(
    socket,
    username: settings.username,
    onPasswordRequest: () => settings.password,
  );
  final sftp = await client.sftp();
  return DartSsh2SftpConnection(sftpClient: sftp, sshClient: client);
}

Future<void> _exerciseFileUpload(
  DartSsh2SftpConnection connection,
  String runRoot,
) async {
  final localDirectory = await Directory.systemTemp.createTemp(
    'serlink-sftp-file-',
  );
  addTearDown(() async {
    if (await localDirectory.exists()) {
      await localDirectory.delete(recursive: true);
    }
  });
  final localFile = File(p.join(localDirectory.path, 'app.env'));
  await localFile.writeAsString('PORT=8080\n');
  final modifiedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
  await localFile.setLastModified(modifiedAt);

  final remotePath = p.posix.join(runRoot, 'app.env');
  await _expectCompleted(
    connection.upload(
      taskId: TransferTaskId('integration-upload-file'),
      itemKind: TransferItemKind.file,
      localPath: localFile.path,
      remotePath: remotePath,
    ),
  );
  await connection.chmod(remotePath, SftpPermissions.tryParse('rwx------')!);

  final entries = await connection.list(runRoot);
  final uploaded = entries.singleWhere((entry) => entry.path == remotePath);
  expect(uploaded.permissions!.symbolic, 'rwx------');
  expect(uploaded.modifiedAt, _withinSeconds(modifiedAt, 3));

  final downloadPath = p.join(localDirectory.path, 'downloaded.env');
  await _expectCompleted(
    connection.download(
      taskId: TransferTaskId('integration-download-file'),
      itemKind: TransferItemKind.file,
      remotePath: remotePath,
      localPath: downloadPath,
    ),
  );
  expect(await File(downloadPath).readAsString(), 'PORT=8080\n');
  expect(
    (await File(downloadPath).stat()).modified,
    _withinSeconds(modifiedAt, 3),
  );
}

Future<void> _exerciseDirectoryTransfer(
  DartSsh2SftpConnection connection,
  String runRoot,
) async {
  final localRoot = await Directory.systemTemp.createTemp('serlink-sftp-tree-');
  final downloadRoot = await Directory.systemTemp.createTemp(
    'serlink-sftp-tree-download-',
  );
  addTearDown(() async {
    for (final directory in [localRoot, downloadRoot]) {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  final nested = Directory(p.join(localRoot.path, 'config', 'prod'));
  await nested.create(recursive: true);
  final nestedFile = File(p.join(nested.path, 'service.txt'));
  await nestedFile.writeAsString('worker=true\n');
  final modifiedAt = DateTime.utc(2026, 2, 3, 4, 5, 6);
  await nestedFile.setLastModified(modifiedAt);

  final remoteTree = p.posix.join(runRoot, 'tree');
  await _expectCompleted(
    connection.upload(
      taskId: TransferTaskId('integration-upload-directory'),
      itemKind: TransferItemKind.directory,
      localPath: localRoot.path,
      remotePath: remoteTree,
    ),
  );

  final remoteNested = await connection.list(
    p.posix.join(remoteTree, 'config', 'prod'),
  );
  final remoteFile = remoteNested.singleWhere(
    (entry) => entry.name == 'service.txt',
  );
  expect(remoteFile.modifiedAt, _withinSeconds(modifiedAt, 3));

  await _expectCompleted(
    connection.download(
      taskId: TransferTaskId('integration-download-directory'),
      itemKind: TransferItemKind.directory,
      remotePath: remoteTree,
      localPath: downloadRoot.path,
    ),
  );
  final downloadedFile = File(
    p.join(downloadRoot.path, 'config', 'prod', 'service.txt'),
  );
  expect(await downloadedFile.readAsString(), 'worker=true\n');
  expect((await downloadedFile.stat()).modified, _withinSeconds(modifiedAt, 3));
}

Future<void> _exerciseOverwrite(
  DartSsh2SftpConnection connection,
  String runRoot,
) async {
  final localDirectory = await Directory.systemTemp.createTemp(
    'serlink-sftp-overwrite-',
  );
  addTearDown(() async {
    if (await localDirectory.exists()) {
      await localDirectory.delete(recursive: true);
    }
  });
  final localFile = File(p.join(localDirectory.path, 'overwrite.txt'));
  final remotePath = p.posix.join(runRoot, 'overwrite.txt');

  await localFile.writeAsString('first');
  await _expectCompleted(
    connection.upload(
      taskId: TransferTaskId('integration-upload-overwrite-first'),
      itemKind: TransferItemKind.file,
      localPath: localFile.path,
      remotePath: remotePath,
    ),
  );
  await localFile.writeAsString('second');
  await _expectCompleted(
    connection.upload(
      taskId: TransferTaskId('integration-upload-overwrite-second'),
      itemKind: TransferItemKind.file,
      localPath: localFile.path,
      remotePath: remotePath,
    ),
  );

  final downloadPath = p.join(localDirectory.path, 'overwrite-download.txt');
  await _expectCompleted(
    connection.download(
      taskId: TransferTaskId('integration-download-overwrite'),
      itemKind: TransferItemKind.file,
      remotePath: remotePath,
      localPath: downloadPath,
    ),
  );
  expect(await File(downloadPath).readAsString(), 'second');
}

Future<void> _exerciseFailureMapping(
  DartSsh2SftpConnection connection,
  String runRoot,
) async {
  await expectLater(
    connection.list(p.posix.join(runRoot, 'missing')),
    throwsA(
      isA<SftpFailureException>().having(
        (error) => error.failure.code,
        'code',
        SftpFailureCode.notFound,
      ),
    ),
  );
}

Future<void> _expectCompleted(Stream<TransferProgress> progress) async {
  TransferProgress? last;
  await for (final update in progress) {
    last = update;
  }
  expect(last?.state, TransferState.completed);
}

Matcher _withinSeconds(DateTime expected, int seconds) {
  return predicate<DateTime?>((actual) {
    if (actual == null) {
      return false;
    }
    return actual.toUtc().difference(expected).abs() <=
        Duration(seconds: seconds);
  }, 'within $seconds seconds of $expected');
}

class _SftpIntegrationSettings {
  const _SftpIntegrationSettings({
    required this.enabled,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.remoteRoot,
  });

  factory _SftpIntegrationSettings.fromEnvironment() {
    final environment = Platform.environment;
    return _SftpIntegrationSettings(
      enabled: environment['SERLINK_SFTP_INTEGRATION'] == '1',
      host: environment['SERLINK_SFTP_HOST'] ?? '127.0.0.1',
      port: int.tryParse(environment['SERLINK_SFTP_PORT'] ?? '') ?? 2222,
      username: environment['SERLINK_SFTP_USER'] ?? 'serlink',
      password: environment['SERLINK_SFTP_PASSWORD'] ?? 'serlink',
      remoteRoot: environment['SERLINK_SFTP_ROOT'] ?? '/home/serlink/workspace',
    );
  }

  final bool enabled;
  final String host;
  final int port;
  final String username;
  final String password;
  final String remoteRoot;
}
