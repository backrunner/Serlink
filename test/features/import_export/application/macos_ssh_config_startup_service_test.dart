import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/import_export/application/macos_ssh_config_startup_service.dart';
import 'package:serlink/features/import_export/application/open_ssh_config_import_service.dart';
import 'package:serlink/features/settings/application/ssh_config_import_settings.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  test(
    'startup controller imports the first config and prompts for additions',
    () async {
      final hosts = _FakeHostRepository(const []);
      final settings = _FakeSettingsRepository();
      final reader = _MutableReader(_document('prod'));
      final session = _FakeVaultSessionController();
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          sshConfigImportSettingsRepositoryProvider.overrideWithValue(settings),
          vaultSessionControllerProvider.overrideWith(() => session),
          macOsSshConfigStartupServiceProvider.overrideWithValue(
            MacOsSshConfigStartupService(
              reader: reader,
              importer: OpenSshConfigImportService(hosts: hosts),
              hosts: hosts,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(macOsSshConfigStartupProvider);
      await _waitFor(() => hosts._hosts.length == 1);
      expect((await settings.read()).initialScanCompleted, isTrue);
      expect(
        container.read(macOsSshConfigStartupProvider).phase,
        MacOsSshConfigStartupPhase.idle,
      );

      reader.document = _document('prod', 'staging');
      session.setUnlockGeneration(2);
      await _waitFor(
        () => container.read(macOsSshConfigStartupProvider).hasPendingPrompt,
      );

      final result = await container
          .read(macOsSshConfigStartupProvider.notifier)
          .importPending(enableAutoImport: true);

      expect(result?.hostsCreated, 1);
      expect(hosts._hosts, hasLength(2));
      expect((await settings.read()).autoImport, isTrue);
    },
  );

  test('imports all missing hosts during the initial scan', () async {
    final service = _startupService(const []);

    final scan = await service.scan(const SshConfigImportSettings());

    expect(scan, isNotNull);
    expect(scan!.initialScan, isTrue);
    expect(scan.shouldImportAutomatically, isTrue);
    expect(scan.importPreview.entries.map((entry) => entry.alias), [
      'prod',
      'staging',
    ]);
  });

  test('only returns aliases added after the last completed scan', () async {
    final service = _startupService(const []);

    final scan = await service.scan(
      const SshConfigImportSettings(
        initialScanCompleted: true,
        observedAliases: {'prod'},
      ),
    );

    expect(scan, isNotNull);
    expect(scan!.initialScan, isFalse);
    expect(scan.shouldImportAutomatically, isFalse);
    expect(scan.importPreview.entries.map((entry) => entry.alias), ['staging']);
    expect(scan.observedAliases, {'prod', 'staging'});
  });

  test('does not re-import an existing alias or endpoint', () async {
    final service = _startupService([
      _host(id: HostId('existing-alias'), displayName: 'prod'),
      _host(id: HostId('existing-endpoint'), hostname: 'staging.example.test'),
    ]);

    final scan = await service.scan(
      const SshConfigImportSettings(initialScanCompleted: true),
    );

    expect(scan, isNotNull);
    expect(scan!.importPreview.entries, isEmpty);
  });

  test('returns no scan when the macOS config file is unavailable', () async {
    final service = MacOsSshConfigStartupService(
      reader: _Reader(null),
      importer: OpenSshConfigImportService(),
      hosts: _FakeHostRepository(const []),
    );

    expect(await service.scan(const SshConfigImportSettings()), isNull);
  });

  test(
    'config created after an empty initial scan is treated as an addition',
    () async {
      final hosts = _FakeHostRepository(const []);
      final settings = _FakeSettingsRepository();
      final reader = _MutableReader(null);
      final session = _FakeVaultSessionController();
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          sshConfigImportSettingsRepositoryProvider.overrideWithValue(settings),
          vaultSessionControllerProvider.overrideWith(() => session),
          macOsSshConfigStartupServiceProvider.overrideWithValue(
            MacOsSshConfigStartupService(
              reader: reader,
              importer: OpenSshConfigImportService(hosts: hosts),
              hosts: hosts,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(macOsSshConfigStartupProvider);
      await _waitFor(() => settings.updateCount > 0);
      expect((await settings.read()).initialScanCompleted, isTrue);

      reader.document = _document('prod');
      session.setUnlockGeneration(2);
      await _waitFor(
        () => container.read(macOsSshConfigStartupProvider).hasPendingPrompt,
      );

      expect(hosts._hosts, isEmpty);
      expect(
        container
            .read(macOsSshConfigStartupProvider)
            .scan
            ?.importPreview
            .entries
            .single
            .alias,
        'prod',
      );
    },
  );

  test('corrected aliases remain eligible after a skipped import', () async {
    final hosts = _FakeHostRepository(const []);
    final reader = _MutableReader(
      const OpenSshConfigDocument(
        path: '/tmp/serlink-ssh-config',
        contents: 'Host prod\n  HostName prod.example.test\n',
      ),
    );
    final importer = OpenSshConfigImportService(hosts: hosts);
    final service = MacOsSshConfigStartupService(
      reader: reader,
      importer: importer,
      hosts: hosts,
    );
    final scan = (await service.scan(const SshConfigImportSettings()))!;

    final result = await importer.applyPreview(
      scan.importPreview,
      defaultUsername: '',
      configSourcePath: scan.sourcePath,
    );
    final settings = SshConfigImportSettings(
      initialScanCompleted: true,
      observedAliases: scan.observedAliases.difference(result.retryAliases),
    );
    reader.document = const OpenSshConfigDocument(
      path: '/tmp/serlink-ssh-config',
      contents: 'Host prod\n  HostName prod.example.test\n  User deploy\n',
    );

    final correctedScan = await service.scan(settings);

    expect(result.retryAliases, {'prod'});
    expect(correctedScan?.importPreview.entries.single.alias, 'prod');
  });

  test(
    'enabling auto-import processes additions in the current session',
    () async {
      final hosts = _FakeHostRepository(const []);
      final settings = _FakeSettingsRepository(
        const SshConfigImportSettings(
          initialScanCompleted: true,
          observedAliases: {'prod'},
        ),
      );
      final reader = _MutableReader(_document('prod'));
      final session = _FakeVaultSessionController();
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          sshConfigImportSettingsRepositoryProvider.overrideWithValue(settings),
          vaultSessionControllerProvider.overrideWith(() => session),
          macOsSshConfigStartupServiceProvider.overrideWithValue(
            MacOsSshConfigStartupService(
              reader: reader,
              importer: OpenSshConfigImportService(hosts: hosts),
              hosts: hosts,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(macOsSshConfigStartupProvider);
      await _waitFor(() => settings.updateCount > 0);
      reader.document = _document('prod', 'staging');

      await container
          .read(appSshConfigAutoImportProvider.notifier)
          .setAutoImport(true);
      await _waitFor(() => hosts._hosts.length == 1);

      expect(hosts._hosts.single.displayName, 'staging');
      expect((await settings.read()).autoImport, isTrue);
    },
  );

  test(
    'surfaces startup scan failures and allows them to be dismissed',
    () async {
      final settings = _FakeSettingsRepository(
        const SshConfigImportSettings(initialScanCompleted: true),
      );
      final session = _FakeVaultSessionController();
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          sshConfigImportSettingsRepositoryProvider.overrideWithValue(settings),
          vaultSessionControllerProvider.overrideWith(() => session),
          macOsSshConfigStartupServiceProvider.overrideWithValue(
            MacOsSshConfigStartupService(
              reader: _ThrowingReader(),
              importer: OpenSshConfigImportService(),
              hosts: _FakeHostRepository(const []),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(macOsSshConfigStartupProvider);
      await _waitFor(
        () =>
            container.read(macOsSshConfigStartupProvider).phase ==
            MacOsSshConfigStartupPhase.failed,
      );
      expect(container.read(macOsSshConfigStartupProvider).error, isNotNull);

      container.read(macOsSshConfigStartupProvider.notifier).dismissFailure();
      expect(
        container.read(macOsSshConfigStartupProvider).phase,
        MacOsSshConfigStartupPhase.idle,
      );
    },
  );
}

MacOsSshConfigStartupService _startupService(List<HostConfig> hosts) {
  return MacOsSshConfigStartupService(
    reader: _Reader(_document('prod', 'staging')),
    importer: OpenSshConfigImportService(),
    hosts: _FakeHostRepository(hosts),
  );
}

OpenSshConfigDocument _document(String firstAlias, [String? secondAlias]) {
  final hosts = [firstAlias, ?secondAlias];
  return OpenSshConfigDocument(
    path: '/tmp/serlink-ssh-config',
    contents: [
      for (final alias in hosts) ...[
        'Host $alias',
        '  HostName $alias.example.test',
        '  User deploy',
        '',
      ],
    ].join('\n'),
  );
}

HostConfig _host({
  required HostId id,
  String? displayName,
  String hostname = 'host.example.test',
}) {
  return HostConfig(
    id: id,
    displayName: displayName ?? hostname,
    hostname: hostname,
    username: 'deploy',
    port: 22,
    authKinds: const {HostAuthKind.password},
    tags: const {},
    trustState: HostTrustState.unknown,
    identityIds: const [],
    startupCommands: const [],
    jumpHostIds: const [],
    createdAt: DateTime.utc(2026, 7, 23),
    updatedAt: DateTime.utc(2026, 7, 23),
  );
}

class _Reader implements OpenSshConfigDocumentReader {
  const _Reader(this.document);

  final OpenSshConfigDocument? document;

  @override
  Future<OpenSshConfigDocument?> read() async => document;
}

class _MutableReader implements OpenSshConfigDocumentReader {
  _MutableReader(this.document);

  OpenSshConfigDocument? document;

  @override
  Future<OpenSshConfigDocument?> read() async => document;
}

class _ThrowingReader implements OpenSshConfigDocumentReader {
  @override
  Future<OpenSshConfigDocument?> read() async {
    throw StateError('ssh config unavailable');
  }
}

class _FakeSettingsRepository implements SshConfigImportSettingsRepository {
  _FakeSettingsRepository([this._settings = const SshConfigImportSettings()]);

  SshConfigImportSettings _settings;
  int updateCount = 0;

  @override
  Future<SshConfigImportSettings> read() async => _settings;

  @override
  Future<void> save(SshConfigImportSettings settings) async {
    _settings = settings;
  }

  @override
  Future<SshConfigImportSettings> update(
    SshConfigImportSettings Function(SshConfigImportSettings current) transform,
  ) async {
    _settings = transform(_settings);
    updateCount += 1;
    return _settings;
  }
}

class _FakeVaultSessionController extends VaultSessionController {
  @override
  Future<VaultSessionState> build() async {
    return const VaultSessionState(
      vaultState: VaultState.unlocked,
      unlockGeneration: 1,
    );
  }

  void setUnlockGeneration(int generation) {
    state = AsyncData(
      VaultSessionState(
        vaultState: VaultState.unlocked,
        unlockGeneration: generation,
      ),
    );
  }
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition did not become true.');
}

class _FakeHostRepository implements HostRepository {
  _FakeHostRepository(List<HostConfig> hosts) : _hosts = List.of(hosts);

  final List<HostConfig> _hosts;

  @override
  Future<void> delete(HostId id) async {
    _hosts.removeWhere((host) => host.id == id);
  }

  @override
  Future<HostConfig?> read(HostId id) async {
    for (final host in _hosts) {
      if (host.id == id) {
        return host;
      }
    }
    return null;
  }

  @override
  Future<List<HostConfig>> list() async => List.of(_hosts);

  @override
  Future<void> save(HostConfig host) async {
    _hosts.removeWhere((existing) => existing.id == host.id);
    _hosts.add(host);
  }
}
