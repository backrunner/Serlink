import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/failure/app_failure.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/application/sftp_failure.dart';
import 'package:serlink/features/snippets/domain/snippet.dart';
import 'package:serlink/features/transfers/domain/transfer_task.dart';
import 'package:serlink/features/workspace/presentation/workspace_search.dart';

void main() {
  test('filters host summaries by name, address, username, port, and tags', () {
    final hosts = [
      _host(
        id: 'host-1',
        displayName: 'Production API',
        hostname: 'api.prod.internal',
        username: 'deploy',
        tags: {'prod', 'api'},
      ),
      _host(
        id: 'host-2',
        displayName: 'Build Worker',
        hostname: 'ci.internal',
        username: 'runner',
        port: 2200,
        tags: {'ci'},
      ),
    ];

    expect(filterHostSummaries(hosts, 'prod'), [hosts.first]);
    expect(filterHostSummaries(hosts, 'runner'), [hosts.last]);
    expect(filterHostSummaries(hosts, '2200'), [hosts.last]);
    expect(filterHostSummaries(hosts, '   '), hosts);
  });

  test('filters snippets by name, command, and tags', () {
    final snippets = [
      _snippet('Restart API', 'systemctl restart api', {'prod'}),
      _snippet('Show Disk', 'df -h', {'ops'}),
    ];

    expect(filterCommandSnippets(snippets, 'systemctl'), [snippets.first]);
    expect(filterCommandSnippets(snippets, 'ops'), [snippets.last]);
  });

  test('filters transfer tasks by paths, machine, state, and failures', () {
    final tasks = [
      _transferTask(
        id: 'transfer-1',
        direction: TransferDirection.upload,
        sourceMachineName: 'MacBook Pro',
        localPath: '/Users/ops/Releases/release.zip',
        remotePath: '/srv/releases/release.zip',
        state: TransferState.completed,
      ),
      _transferTask(
        id: 'transfer-2',
        direction: TransferDirection.download,
        sourceMachineName: 'Bastion',
        localPath: '/tmp/access.log',
        remotePath: '/var/log/nginx/access.log',
        state: TransferState.running,
      ),
      _transferTask(
        id: 'transfer-3',
        direction: TransferDirection.download,
        localPath: '/tmp/secret.env',
        remotePath: '/etc/secret.env',
        state: TransferState.failed,
        failure: SftpFailure.permissionDenied().toAppFailure(),
      ),
    ];

    expect(filterTransferTasks(tasks, 'release'), [tasks.first]);
    expect(filterTransferTasks(tasks, 'macbook'), [tasks.first]);
    expect(filterTransferTasks(tasks, 'running'), [tasks[1]]);
    expect(filterTransferTasks(tasks, 'permission'), [tasks.last]);
    expect(filterTransferTasks(tasks, 'download'), [tasks[1], tasks.last]);
    expect(filterTransferTasks(tasks, '   '), tasks);
  });
}

HostSummary _host({
  required String id,
  required String displayName,
  required String hostname,
  required String username,
  int port = 22,
  Set<String> tags = const {},
}) {
  return HostSummary(
    id: HostId(id),
    displayName: displayName,
    hostname: hostname,
    username: username,
    port: port,
    authKinds: const {HostAuthKind.password},
    tags: tags,
    trustState: HostTrustState.trusted,
    createdAt: DateTime.utc(2026),
  );
}

CommandSnippet _snippet(String name, String command, Set<String> tags) {
  return CommandSnippet(
    id: SnippetId(name),
    name: name,
    command: command,
    tags: tags,
    confirmBeforeRun: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

TransferTask _transferTask({
  required String id,
  required TransferDirection direction,
  String? sourceMachineName,
  required String localPath,
  required String remotePath,
  required TransferState state,
  AppFailure? failure,
}) {
  return TransferTask(
    id: TransferTaskId(id),
    direction: direction,
    sourceMachineName: sourceMachineName,
    localPath: localPath,
    remotePath: remotePath,
    state: state,
    transferredBytes: 0,
    failure: failure,
    createdAt: DateTime.utc(2026),
  );
}
