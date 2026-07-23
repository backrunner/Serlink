import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/import_export/application/macos_ssh_config_writeback_service.dart';
import 'package:serlink/features/sync/application/auto_sync_controller.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  test(
    'updates imported host, renames alias, and removes it when disabled',
    () async {
      final fixture = await _Fixture.create('''
# User comment
Host *
  User inherited-user
  Port 2022

Host prod
  HostName old.example.test
  User old-user
  Port 22
  IdentityFile ~/.ssh/prod_key
  Compression yes
''');
      addTearDown(fixture.dispose);
      final host = _host(
        id: 'prod-id',
        displayName: 'prod',
        hostname: 'prod.example.test',
        username: 'deploy',
        port: 2222,
        writeBack: true,
      );
      fixture.hosts.replace(host);

      await fixture.service.reconcile();

      var contents = await fixture.config.readAsString();
      expect(
        contents.indexOf('Host prod'),
        lessThan(contents.indexOf('Host *')),
      );
      expect(contents, contains('Host prod'));
      expect(contents, contains('HostName prod.example.test'));
      expect(contents, contains('User deploy'));
      expect(contents, contains('Port 2222'));
      expect(contents, contains('IdentityFile ~/.ssh/prod_key'));
      expect(contents, contains('Compression yes'));
      final staleRegistration = fixture.registry.entries['prod-id']!;

      fixture.hosts.replace(
        _host(
          id: 'prod-id',
          displayName: 'production',
          hostname: 'new.example.test',
          username: 'ops',
          port: 2200,
          writeBack: true,
        ),
      );
      await fixture.service.reconcile();

      contents = await fixture.config.readAsString();
      expect(contents, contains('Host production\n'));
      expect(contents, isNot(contains('Host prod\n')));
      expect(contents, contains('HostName new.example.test'));
      fixture.registry.entries = {'prod-id': staleRegistration};

      fixture.hosts.replace(
        _host(
          id: 'prod-id',
          displayName: 'production',
          hostname: 'new.example.test',
          username: 'ops',
          port: 2200,
          writeBack: false,
        ),
      );
      await fixture.service.reconcile();

      contents = await fixture.config.readAsString();
      expect(contents, isNot(contains('Host production')));
      expect(contents, contains('# User comment'));
    },
  );

  test('preserves config symlinks when replacing their target', () async {
    final directory = await Directory.systemTemp.createTemp(
      'serlink-writeback-link-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final target = File('${directory.path}/real-config');
    await target.writeAsString('Host prod\n  HostName old.example.test\n');
    final link = Link('${directory.path}/config');
    await link.create(target.path);
    final service = MacOsSshConfigWritebackService(
      hosts: _MutableHostRepository([
        _host(
          id: 'prod-id',
          displayName: 'prod',
          hostname: 'new.example.test',
          username: 'ops',
          port: 22,
          writeBack: true,
        ),
      ]),
      registry: _MemoryRegistry(),
      files: const LocalSshConfigFileStore(),
      configPath: link.path,
    );

    await service.reconcile();

    expect(
      await FileSystemEntity.type(link.path, followLinks: false),
      FileSystemEntityType.link,
    );
    expect(await target.readAsString(), contains('HostName new.example.test'));
  });

  test(
    'rejects a stale file snapshot without replacing user changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'serlink-writeback-race-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final config = File('${directory.path}/config');
      await config.writeAsString('# User changed this\n');
      const files = LocalSshConfigFileStore();

      await expectLater(
        files.writeAtomically(
          config.path,
          '# Serlink update\n',
          expectedContents: '# Older snapshot\n',
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await config.readAsString(), '# User changed this\n');
    },
  );

  test(
    'updates an included multi-alias block without changing sibling alias',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'serlink-writeback-include-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final includedDirectory = Directory('${directory.path}/conf.d');
      await includedDirectory.create();
      final included = File('${includedDirectory.path}/hosts.conf');
      await included.writeAsString('''
Host prod stage
  HostName shared.example.test
  User deploy
  IdentityFile ~/.ssh/shared_key
''');
      final config = File('${directory.path}/config');
      await config.writeAsString('Include conf.d/*.conf\n');
      final hosts = _MutableHostRepository([
        _host(
          id: 'prod-id',
          displayName: 'prod',
          hostname: 'prod.example.test',
          username: 'ops',
          port: 2222,
          writeBack: true,
        ),
      ]);
      final registry = _MemoryRegistry();
      final service = MacOsSshConfigWritebackService(
        hosts: hosts,
        registry: registry,
        files: const LocalSshConfigFileStore(),
        configPath: config.path,
      );

      await service.reconcile();

      var contents = await included.readAsString();
      expect(contents, contains('Host stage\n'));
      expect(contents, isNot(contains('Host prod\n')));
      expect(contents, contains('HostName shared.example.test'));
      expect(
        RegExp(r'IdentityFile ~/.ssh/shared_key').allMatches(contents),
        hasLength(1),
      );
      final rootContents = await config.readAsString();
      expect(rootContents, contains('Host prod\n'));
      expect(rootContents, contains('HostName prod.example.test'));
      expect(rootContents, contains('IdentityFile ~/.ssh/shared_key'));
      expect(rootContents, contains('Include conf.d/*.conf'));

      hosts.remove('prod-id');
      await service.reconcile();

      contents = await included.readAsString();
      expect(contents, contains('Host stage\n'));
      expect(contents, isNot(contains('Host prod\n')));
      expect(contents, contains('IdentityFile ~/.ssh/shared_key'));
      expect(await config.readAsString(), 'Include conf.d/*.conf\n');
    },
  );

  test(
    'manages synced hosts that do not already exist in SSH config',
    () async {
      final fixture = await _Fixture.create('# Existing config\n');
      addTearDown(fixture.dispose);
      fixture.hosts.replace(
        _host(
          id: 'sync-id',
          displayName: 'Synced Host',
          hostname: 'sync.example.test',
          username: 'deploy',
          port: 22,
          writeBack: true,
        ),
      );

      await fixture.service.reconcile();

      var contents = await fixture.config.readAsString();
      expect(contents, contains('# >>> Serlink managed host sync-id'));
      expect(contents, contains('Host synced-host'));
      expect(contents, contains('HostName sync.example.test'));

      fixture.registry.entries = {};
      await fixture.service.reconcile();
      expect(fixture.registry.entries['sync-id']?.managed, isTrue);

      fixture.hosts.replace(
        _host(
          id: 'sync-id',
          displayName: 'Synced Host',
          hostname: 'changed.example.test',
          username: 'ops',
          port: 2200,
          writeBack: true,
        ),
      );
      await fixture.service.reconcile();
      contents = await fixture.config.readAsString();
      expect(contents, contains('HostName changed.example.test'));
      expect(contents, contains('Port 2200'));

      fixture.hosts.remove('sync-id');
      await fixture.service.reconcile();
      contents = await fixture.config.readAsString();
      expect(contents, '# Existing config\n');
      expect(fixture.registry.entries, isEmpty);
    },
  );

  test(
    'does not update registry or original contents when writing fails',
    () async {
      final hosts = _MutableHostRepository([
        _host(
          id: 'prod-id',
          displayName: 'prod',
          hostname: 'new.example.test',
          username: 'ops',
          port: 22,
          writeBack: true,
        ),
      ]);
      final registry = _MemoryRegistry();
      final files = _FailingFileStore('''
Host prod
  HostName old.example.test
''');
      final service = MacOsSshConfigWritebackService(
        hosts: hosts,
        registry: registry,
        files: files,
        configPath: '/virtual/config',
      );

      await expectLater(
        service.reconcile(),
        throwsA(isA<FileSystemException>()),
      );

      expect(files.contents, contains('HostName old.example.test'));
      expect(files.contents, isNot(contains('HostName new.example.test')));
      expect(registry.entries, isEmpty);
    },
  );

  test(
    'remote sync record changes trigger serialized reconciliation',
    () async {
      final fixture = await _Fixture.create('');
      addTearDown(fixture.dispose);
      final changes = StreamController<VaultRecordChange>.broadcast(sync: true);
      addTearDown(changes.close);
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          vaultSessionControllerProvider.overrideWith(
            _UnlockedVaultSessionController.new,
          ),
          vaultRecordChangesProvider.overrideWith((_) => changes.stream),
          macOsSshConfigWritebackServiceProvider.overrideWithValue(
            fixture.service,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        macOsSshConfigWritebackProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _waitFor(() async {
        return container.read(vaultSessionControllerProvider).hasValue;
      });

      fixture.hosts.replace(
        _host(
          id: 'remote-id',
          displayName: 'remote',
          hostname: 'remote.example.test',
          username: 'ops',
          port: 22,
          writeBack: true,
        ),
      );
      changes.add(
        VaultRecordChange(
          kind: VaultRecordChangeKind.upsert,
          id: VaultRecordId('host:remote-id'),
          type: 'host',
          origin: VaultRecordChangeOrigin.remoteSync,
        ),
      );

      await _waitFor(() async {
        return await fixture.config.exists() &&
            (await fixture.config.readAsString()).contains(
              'HostName remote.example.test',
            );
      });

      fixture.hosts.remove('remote-id');
      changes.add(
        VaultRecordChange(
          kind: VaultRecordChangeKind.delete,
          id: VaultRecordId('host:remote-id'),
          type: 'host',
          origin: VaultRecordChangeOrigin.remoteSync,
        ),
      );
      await _waitFor(() async {
        return !(await fixture.config.readAsString()).contains('Host remote');
      });
    },
  );
}

class _Fixture {
  _Fixture({
    required this.directory,
    required this.config,
    required this.hosts,
    required this.registry,
    required this.service,
  });

  final Directory directory;
  final File config;
  final _MutableHostRepository hosts;
  final _MemoryRegistry registry;
  final MacOsSshConfigWritebackService service;

  static Future<_Fixture> create(String contents) async {
    final directory = await Directory.systemTemp.createTemp(
      'serlink-writeback-',
    );
    final config = File('${directory.path}/config');
    await config.writeAsString(contents);
    final hosts = _MutableHostRepository();
    final registry = _MemoryRegistry();
    return _Fixture(
      directory: directory,
      config: config,
      hosts: hosts,
      registry: registry,
      service: MacOsSshConfigWritebackService(
        hosts: hosts,
        registry: registry,
        files: const LocalSshConfigFileStore(),
        configPath: config.path,
      ),
    );
  }

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class _MutableHostRepository implements HostRepository {
  _MutableHostRepository([List<HostConfig> hosts = const []])
    : _hosts = {for (final host in hosts) host.id: host};

  final Map<HostId, HostConfig> _hosts;

  void replace(HostConfig host) {
    _hosts[host.id] = host;
  }

  void remove(String id) {
    _hosts.remove(HostId(id));
  }

  @override
  Future<void> delete(HostId id) async {
    _hosts.remove(id);
  }

  @override
  Future<List<HostConfig>> list() async => _hosts.values.toList();

  @override
  Future<HostConfig?> read(HostId id) async => _hosts[id];

  @override
  Future<void> save(HostConfig host) async {
    replace(host);
  }
}

class _MemoryRegistry implements SshConfigWritebackRegistry {
  Map<String, SshConfigWritebackRegistration> entries = {};

  @override
  Future<Map<String, SshConfigWritebackRegistration>> read() async {
    return Map.of(entries);
  }

  @override
  Future<void> save(Map<String, SshConfigWritebackRegistration> entries) async {
    this.entries = Map.of(entries);
  }
}

class _FailingFileStore implements SshConfigFileStore {
  _FailingFileStore(this.contents);

  String contents;

  @override
  Future<String?> read(String path) async => contents;

  @override
  Future<void> writeAtomically(
    String path,
    String contents, {
    required String? expectedContents,
  }) async {
    throw FileSystemException('write failed', path);
  }
}

class _UnlockedVaultSessionController extends VaultSessionController {
  @override
  Future<VaultSessionState> build() async {
    return const VaultSessionState(
      vaultState: VaultState.unlocked,
      unlockGeneration: 1,
    );
  }
}

HostConfig _host({
  required String id,
  required String displayName,
  required String hostname,
  required String username,
  required int port,
  required bool writeBack,
}) {
  return HostConfig(
    id: HostId(id),
    displayName: displayName,
    hostname: hostname,
    username: username,
    port: port,
    authKinds: const {},
    tags: const {},
    trustState: HostTrustState.unknown,
    identityIds: const [],
    startupCommands: const [],
    jumpHostIds: const [],
    writeBackToSshConfig: writeBack,
    createdAt: DateTime.utc(2026, 7, 23),
    updatedAt: DateTime.utc(2026, 7, 23),
  );
}

Future<void> _waitFor(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
