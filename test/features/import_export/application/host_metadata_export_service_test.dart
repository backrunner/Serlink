import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/import_export/application/host_metadata_export_service.dart';

void main() {
  test('exports selected host metadata without credential ids', () async {
    final jumpHost = _host(
      id: 'jump',
      displayName: 'Jump Box',
      hostname: 'jump.internal',
      username: 'ops',
    );
    final appHost = _host(
      id: 'app',
      displayName: 'App Server',
      hostname: 'app.internal',
      username: 'deploy',
      tags: {'prod', 'api'},
      identityIds: [IdentityId('identity-secret')],
      startupCommands: ['cd /srv/app'],
      jumpHostIds: [jumpHost.id],
    );
    final service = HostMetadataExportService(
      hosts: _FakeHostRepository([jumpHost, appHost]),
    );

    final bundle = await service.export(selectedHostIds: [appHost.id]);

    expect(bundle.formatVersion, 1);
    expect(bundle.hosts, hasLength(1));
    final exported = bundle.hosts.single;
    expect(exported.hostId, 'app');
    expect(exported.hostname, 'app.internal');
    expect(exported.username, 'deploy');
    expect(exported.tags, ['api', 'prod']);
    expect(exported.startupCommands, ['cd /srv/app']);
    expect(exported.jumpHosts.single.displayName, 'Jump Box');
    expect(exported.toJson().toString(), isNot(contains('identity-secret')));
  });

  test('round trips host metadata export bundle json', () async {
    final service = HostMetadataExportService(
      hosts: _FakeHostRepository([
        _host(
          id: 'app',
          displayName: 'App Server',
          hostname: 'app.internal',
          username: 'deploy',
        ),
      ]),
    );

    final bundle = await service.export();
    final restored = HostMetadataExportBundle.fromBytes(bundle.toBytes());

    expect(restored.formatVersion, 1);
    expect(restored.hosts.single.displayName, 'App Server');
    expect(
      restored.hosts.single.connectionSettings['connectTimeoutSeconds'],
      20,
    );
  });
}

HostConfig _host({
  required String id,
  required String displayName,
  required String hostname,
  required String username,
  Set<String> tags = const {},
  List<IdentityId> identityIds = const [],
  List<String> startupCommands = const [],
  List<HostId> jumpHostIds = const [],
}) {
  return HostConfig(
    id: HostId(id),
    displayName: displayName,
    hostname: hostname,
    username: username,
    port: 22,
    authKinds: const {HostAuthKind.password},
    tags: tags,
    trustState: HostTrustState.trusted,
    identityIds: identityIds,
    startupCommands: startupCommands,
    jumpHostIds: jumpHostIds,
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
