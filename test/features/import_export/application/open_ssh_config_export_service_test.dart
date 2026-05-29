import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/import_export/application/open_ssh_config_export_service.dart';
import 'package:serlink/features/import_export/application/open_ssh_config_import_service.dart';

void main() {
  test(
    'exports selected hosts and required jump hosts as OpenSSH config',
    () async {
      final jumpHost = _host(
        id: 'jump',
        displayName: 'Jump Box',
        hostname: 'jump.internal',
        username: 'ops',
        port: 2200,
        connectionSettings: const HostConnectionSettings(
          connectTimeoutSeconds: 17,
          keepAliveIntervalSeconds: 11,
        ),
      );
      final appHost = _host(
        id: 'app',
        displayName: 'App Server',
        hostname: 'app.internal',
        username: 'deploy',
        port: 2222,
        tags: {'prod', 'api'},
        jumpHostIds: [jumpHost.id],
        connectionSettings: const HostConnectionSettings(
          connectTimeoutSeconds: 25,
          keepAliveIntervalSeconds: 0,
        ),
      );

      final service = OpenSshConfigExportService(
        hosts: _FakeHostRepository([jumpHost, appHost]),
        now: () => DateTime.utc(2026, 5, 29, 12, 0),
      );

      final bundle = await service.export(selectedHostIds: [appHost.id]);

      expect(bundle.hostCount, 2);
      expect(bundle.contents, contains('# Serlink OpenSSH config export'));
      expect(bundle.contents, contains('Host app-server'));
      expect(bundle.contents, contains('Host jump-box'));
      expect(bundle.contents, contains('HostName app.internal'));
      expect(bundle.contents, contains('User deploy'));
      expect(bundle.contents, contains('Port 2222'));
      expect(bundle.contents, contains('ConnectTimeout 25'));
      expect(bundle.contents, contains('ServerAliveInterval 11'));
      expect(bundle.contents, contains('ProxyJump jump-box'));
      expect(bundle.contents, isNot(contains('identity-secret')));

      final preview = OpenSshConfigImportService().preview(bundle.contents);
      expect(preview.entries, hasLength(2));
      expect(
        preview.entries
            .firstWhere((entry) => entry.alias == 'app-server')
            .proxyJump,
        'jump-box',
      );
      expect(
        preview.entries.firstWhere((entry) => entry.alias == 'jump-box').port,
        2200,
      );
    },
  );
}

HostConfig _host({
  required String id,
  required String displayName,
  required String hostname,
  required String username,
  int port = 22,
  Set<String> tags = const {},
  List<HostId> jumpHostIds = const [],
  HostConnectionSettings connectionSettings = const HostConnectionSettings(),
}) {
  return HostConfig(
    id: HostId(id),
    displayName: displayName,
    hostname: hostname,
    username: username,
    port: port,
    authKinds: const {HostAuthKind.password},
    tags: tags,
    trustState: HostTrustState.trusted,
    identityIds: const [],
    startupCommands: const [],
    jumpHostIds: jumpHostIds,
    connectionSettings: connectionSettings,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

class _FakeHostRepository implements HostRepository {
  _FakeHostRepository(List<HostConfig> hosts)
    : _hosts = {for (final host in hosts) host.id: host};

  final Map<HostId, HostConfig> _hosts;

  @override
  Future<void> delete(HostId id) async {
    _hosts.remove(id);
  }

  @override
  Future<List<HostConfig>> list() async {
    return _hosts.values.toList();
  }

  @override
  Future<HostConfig?> read(HostId id) async {
    return _hosts[id];
  }

  @override
  Future<void> save(HostConfig host) async {
    _hosts[host.id] = host;
  }
}
