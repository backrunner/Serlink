import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/snippets/domain/snippet.dart';
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
