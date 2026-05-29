import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';
import 'package:serlink/features/ssh/application/connection_profile_resolver.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/terminal/application/local_terminal_service.dart';
import 'package:serlink/features/terminal/application/terminal_display_settings.dart';
import 'package:serlink/features/workspace/application/workspace_tab_controller.dart';
import 'package:serlink/features/workspace/domain/workspace_tab.dart';

void main() {
  test(
    'opens terminal, marks disconnect, and reconnects in same tab',
    () async {
      final service = _FakeSshSessionService();
      final container = _container(service: service);
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();

      var state = container.read(workspaceTabControllerProvider);
      final tab = state.activeTab!;
      final content = tab.content as TerminalTabContent;
      expect(tab.lifecycle, SessionLifecycleState.connected);
      expect(service.openShellCount, 1);
      expect(
        container
            .read(workspaceRuntimeRegistryProvider)
            .terminalFor(content.primaryPane.sessionId),
        isNotNull,
      );

      service.shells.single.completeDone();
      await _drainMicrotasks();

      state = container.read(workspaceTabControllerProvider);
      expect(state.activeTab!.id, tab.id);
      expect(state.activeTab!.lifecycle, SessionLifecycleState.disconnected);

      controller.reconnect(tab.id);
      await _drainMicrotasks();

      state = container.read(workspaceTabControllerProvider);
      expect(state.activeTab!.id, tab.id);
      expect(state.activeTab!.lifecycle, SessionLifecycleState.connected);
      expect(service.openShellCount, 2);
    },
  );

  test(
    'auto reconnect retries terminal sessions up to the configured limit',
    () {
      fakeAsync((async) {
        final service = _FakeSshSessionService();
        final container = _container(
          service: service,
          profile: StaticConnectionProfile(
            hostId: _host.id,
            hostname: _host.hostname,
            port: _host.port,
            username: _host.username,
            authMethods: [staticPasswordAuth('secret')],
            reconnectPolicy: const SshReconnectPolicy(
              maxAttempts: 2,
              backoff: Duration(seconds: 1),
            ),
          ),
        );
        addTearDown(container.dispose);

        final controller = container.read(
          workspaceTabControllerProvider.notifier,
        );
        controller.openTerminal(_host);
        async.flushMicrotasks();

        final tab = container.read(workspaceTabControllerProvider).activeTab!;
        expect(service.openShellCount, 1);

        service.shells.single.completeDone();
        async.flushMicrotasks();

        expect(
          container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
          SessionLifecycleState.disconnected,
        );

        async.elapse(const Duration(milliseconds: 999));
        async.flushMicrotasks();
        expect(service.openShellCount, 1);

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(service.openShellCount, 2);

        service.shells.last.completeDone();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(service.openShellCount, 3);

        service.shells.last.completeDone();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(service.openShellCount, 3);

        expect(
          container.read(workspaceTabControllerProvider).activeTab!.id,
          tab.id,
        );
      });
    },
  );

  test('runs startup commands after terminal attach', () async {
    final service = _FakeSshSessionService();
    final container = _container(
      service: service,
      profile: StaticConnectionProfile(
        hostId: _host.id,
        hostname: _host.hostname,
        port: _host.port,
        username: _host.username,
        authMethods: [staticPasswordAuth('secret')],
        startupCommands: const ['tmux attach || tmux', 'cd /srv/app'],
      ),
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    expect(service.shells.single.writes, [
      'tmux attach || tmux\n',
      'cd /srv/app\n',
    ]);
  });

  test(
    'opens sftp connection and stores runtime in same tab container',
    () async {
      final service = _FakeSshSessionService();
      final container = _container(service: service);
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openSftp(_host);
      await _drainMicrotasks();

      final state = container.read(workspaceTabControllerProvider);
      final tab = state.activeTab!;
      final content = tab.content as SftpTabContent;
      expect(tab.lifecycle, SessionLifecycleState.connected);
      expect(service.openSftpCount, 1);
      expect(
        container
            .read(workspaceRuntimeRegistryProvider)
            .sftpFor(content.sessionId),
        isNotNull,
      );
    },
  );

  test(
    'opens related sftp and terminal tabs from active workspace tabs',
    () async {
      final service = _FakeSshSessionService();
      final container = _container(service: service);
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();

      final terminalTab = container
          .read(workspaceTabControllerProvider)
          .activeTab!;
      controller.openSftpFromTab(terminalTab.id);
      await _drainMicrotasks();

      var state = container.read(workspaceTabControllerProvider);
      expect(state.tabs, hasLength(2));
      expect(state.activeTab!.content, isA<SftpTabContent>());
      expect(service.openShellCount, 1);
      expect(service.openSftpCount, 1);

      final sftpTab = state.activeTab!;
      controller.openTerminalFromTab(sftpTab.id);
      await _drainMicrotasks();

      state = container.read(workspaceTabControllerProvider);
      expect(state.tabs, hasLength(3));
      expect(state.activeTab!.content, isA<TerminalTabContent>());
      expect(service.openShellCount, 2);
      expect(service.openSftpCount, 1);
    },
  );

  test('opens local terminal and reconnects in the same tab', () async {
    final localTerminal = _FakeLocalTerminalService();
    final container = _container(
      service: _FakeSshSessionService(),
      localTerminal: localTerminal,
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openLocalTerminal();
    await _drainMicrotasks();

    var state = container.read(workspaceTabControllerProvider);
    final tab = state.activeTab!;
    final content = tab.content as LocalTerminalTabContent;
    expect(tab.hostId, isNull);
    expect(tab.lifecycle, SessionLifecycleState.connected);
    expect(localTerminal.openShellCount, 1);
    expect(
      container
          .read(workspaceRuntimeRegistryProvider)
          .terminalFor(content.sessionId),
      isNotNull,
    );

    localTerminal.shells.single.completeDone();
    await _drainMicrotasks();

    state = container.read(workspaceTabControllerProvider);
    expect(state.activeTab!.id, tab.id);
    expect(state.activeTab!.lifecycle, SessionLifecycleState.disconnected);
    expect(
      state.activeTab!.failure?.message,
      'Local shell exited. Restart opens a new shell.',
    );

    controller.reconnect(tab.id);
    await _drainMicrotasks();

    state = container.read(workspaceTabControllerProvider);
    expect(state.activeTab!.id, tab.id);
    expect(state.activeTab!.lifecycle, SessionLifecycleState.connected);
    expect(localTerminal.openShellCount, 2);
  });

  test('local terminal failures use local shell wording', () async {
    final container = _container(
      service: _FakeSshSessionService(),
      localTerminal: _FailingLocalTerminalService(StateError('pty missing')),
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openLocalTerminal();
    await _drainMicrotasks();

    final state = container.read(workspaceTabControllerProvider);
    final tab = state.activeTab!;
    final content = tab.content as LocalTerminalTabContent;
    expect(tab.lifecycle, SessionLifecycleState.failed);
    expect(tab.failure?.code, 'local_terminal.failed');
    expect(tab.failure?.message, 'Local terminal failed.');
    expect(
      container
          .read(workspaceRuntimeRegistryProvider)
          .terminalFor(content.sessionId)!
          .buffer
          .getText(),
      contains('Local terminal failed: Local terminal failed.'),
    );
  });

  test('closing terminal tabs closes split pane sessions', () async {
    final service = _FakeSshSessionService();
    final container = _container(service: service);
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final tab = container.read(workspaceTabControllerProvider).activeTab!;
    controller.enableTerminalSplit(tab.id);
    await _drainMicrotasks();

    final splitContent =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(splitContent.panes, hasLength(2));

    controller.closeTab(tab.id);
    await _drainMicrotasks();

    expect(service.shells, hasLength(2));
    expect(service.shells.every((shell) => shell._done.isCompleted), isTrue);
  });

  test('inserts snippet into active connected terminal', () async {
    final service = _FakeSshSessionService();
    final container = _container(service: service);
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final inserted = controller.insertIntoActiveTerminal('pwd');

    expect(inserted, isTrue);
    expect(service.shells.single.writes, ['pwd']);
  });

  test('submit adds trailing newline when running snippet', () async {
    final service = _FakeSshSessionService();
    final container = _container(service: service);
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final inserted = controller.insertIntoActiveTerminal(
      'systemctl restart api',
      submit: true,
    );

    expect(inserted, isTrue);
    expect(service.shells.single.writes, ['systemctl restart api\n']);
  });

  test('enables, configures, and disables terminal split state', () async {
    final service = _FakeSshSessionService();
    final container = _container(service: service);
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final tabId = container.read(workspaceTabControllerProvider).activeTab!.id;

    controller.enableTerminalSplit(tabId);
    await _drainMicrotasks();
    var content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.showSplit, isTrue);
    expect(content.splitAxis, Axis.horizontal);
    expect(content.activePane, 1);
    expect(content.panes, hasLength(2));
    expect(service.openShellCount, 2);
    expect(content.panes[0].sessionId, isNot(content.panes[1].sessionId));

    controller.setActiveTerminalPane(tabId, 1);
    content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.activePane, 1);

    controller.setTerminalSplitAxis(tabId, Axis.vertical);
    content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.showSplit, isTrue);
    expect(content.splitAxis, Axis.vertical);
    expect(content.activePane, 1);

    controller.disableTerminalSplit(tabId);
    await _drainMicrotasks();
    content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.showSplit, isFalse);
    expect(content.activePane, 0);
    expect(content.panes, hasLength(1));
  });

  test(
    'does not insert when active tab is disconnected or non-terminal',
    () async {
      final service = _FakeSshSessionService();
      final container = _container(service: service);
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();

      final terminalTab = container
          .read(workspaceTabControllerProvider)
          .activeTab!;
      service.shells.single.completeDone();
      await _drainMicrotasks();

      expect(controller.insertIntoActiveTerminal('pwd'), isFalse);

      controller.openSftp(_host);
      await _drainMicrotasks();

      final state = container.read(workspaceTabControllerProvider);
      expect(state.activeTab!.content, isA<SftpTabContent>());
      expect(controller.insertIntoActiveTerminal('pwd'), isFalse);
      expect(terminalTab.id, isNot(state.activeTab!.id));
    },
  );

  test(
    'profile resolution failure marks tab failed without creating transport',
    () async {
      final service = _FakeSshSessionService();
      final container = ProviderContainer(
        overrides: [
          sshSessionServiceProvider.overrideWithValue(service),
          connectionProfileResolverProvider.overrideWithValue(
            const LockedVaultConnectionProfileResolver(),
          ),
          terminalHostDisplaySettingsRepositoryProvider.overrideWithValue(
            _FakeTerminalHostDisplaySettingsRepository(),
          ),
          terminalDisplaySettingsRepositoryProvider.overrideWithValue(
            _FakeTerminalDisplaySettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();

      final tab = container.read(workspaceTabControllerProvider).activeTab!;
      final content = tab.content as TerminalTabContent;
      final terminal = container
          .read(workspaceRuntimeRegistryProvider)
          .terminalFor(content.primaryPane.sessionId)!;

      expect(tab.lifecycle, SessionLifecycleState.failed);
      expect(tab.failure!.code, 'connection_profile.vault_locked');
      expect(service.openShellCount, 0);
      expect(terminal.buffer.getText(), contains('Connection failed'));
    },
  );

  test('opens terminal with encrypted per-host display profile', () async {
    final service = _FakeSshSessionService();
    const profile = TerminalDisplaySettings(
      themeId: SerlinkTerminalThemeId.highContrast,
      fontSize: 16,
      lineHeight: 1.3,
      scrollbackLines: 60000,
    );
    final profileRepository = _FakeTerminalHostDisplaySettingsRepository({
      _host.id: profile,
    });
    final container = _container(
      service: service,
      terminalProfiles: profileRepository,
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final tab = container.read(workspaceTabControllerProvider).activeTab!;
    final content = tab.content as TerminalTabContent;
    expect(content.primaryPane.displaySettings, profile);
    expect(
      container
          .read(workspaceRuntimeRegistryProvider)
          .terminalFor(content.primaryPane.sessionId)!
          .maxLines,
      60000,
    );
    expect(profileRepository.readCount, 1);
  });

  test('saves and resets per-host terminal display profile', () async {
    final service = _FakeSshSessionService();
    final profileRepository = _FakeTerminalHostDisplaySettingsRepository();
    final container = _container(
      service: service,
      terminalProfiles: profileRepository,
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final tab = container.read(workspaceTabControllerProvider).activeTab!;
    const profile = TerminalDisplaySettings(
      themeId: SerlinkTerminalThemeId.serlinkLight,
      fontSize: 18,
      lineHeight: 1.25,
      scrollbackLines: 25000,
    );

    controller.saveTerminalDisplaySettingsForHost(tab.id, profile);
    await _drainMicrotasks();

    var content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.primaryPane.displaySettings, profile);
    expect(profileRepository.profiles[_host.id], profile);

    controller.resetTerminalDisplaySettingsForHost(tab.id);
    await _drainMicrotasks();

    content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.primaryPane.displaySettings, isNull);
    expect(profileRepository.profiles.containsKey(_host.id), isFalse);
  });
}

final _host = HostSummary(
  id: HostId('host-1'),
  displayName: 'Test Host',
  hostname: 'example.internal',
  username: 'ops',
  port: 22,
  authKinds: const {HostAuthKind.password},
  tags: const {},
  trustState: HostTrustState.trusted,
);

ProviderContainer _container({
  required _FakeSshSessionService service,
  LocalTerminalService? localTerminal,
  _FakeTerminalHostDisplaySettingsRepository? terminalProfiles,
  StaticConnectionProfile? profile,
}) {
  return ProviderContainer(
    overrides: [
      sshSessionServiceProvider.overrideWithValue(service),
      if (localTerminal != null)
        localTerminalServiceProvider.overrideWithValue(localTerminal),
      connectionProfileResolverProvider.overrideWithValue(
        StaticConnectionProfileResolver({
          _host.id:
              profile ??
              StaticConnectionProfile(
                hostId: _host.id,
                hostname: _host.hostname,
                port: _host.port,
                username: _host.username,
                authMethods: [staticPasswordAuth('secret')],
              ),
        }),
      ),
      terminalHostDisplaySettingsRepositoryProvider.overrideWithValue(
        terminalProfiles ?? _FakeTerminalHostDisplaySettingsRepository(),
      ),
      terminalDisplaySettingsRepositoryProvider.overrideWithValue(
        _FakeTerminalDisplaySettingsRepository(),
      ),
    ],
  );
}

class _FakeLocalTerminalService implements LocalTerminalService {
  final List<_FakeShellSession> shells = [];
  var openShellCount = 0;

  @override
  Future<SshShellSession> openShell({int columns = 80, int rows = 24}) async {
    openShellCount += 1;
    final shell = _FakeShellSession();
    shells.add(shell);
    return shell;
  }
}

class _FailingLocalTerminalService implements LocalTerminalService {
  const _FailingLocalTerminalService(this.error);

  final Object error;

  @override
  Future<SshShellSession> openShell({int columns = 80, int rows = 24}) async {
    throw error;
  }
}

Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 8; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeSshSessionService implements SshSessionService {
  final List<_FakeShellSession> shells = [];
  var openShellCount = 0;
  var openSftpCount = 0;

  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    openShellCount += 1;
    final shell = _FakeShellSession();
    shells.add(shell);
    return shell;
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) async {
    openSftpCount += 1;
    return _FakeSftpConnection();
  }

  @override
  Future<void> startLocalForward({
    required SessionId sessionId,
    required int localPort,
    required String remoteHost,
    required int remotePort,
  }) async {}

  @override
  Future<void> stopLocalForward({required SessionId sessionId}) async {}

  @override
  Future<RemoteForwardBinding> startRemoteForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
    required String localHost,
    required int localPort,
  }) async {
    return RemoteForwardBinding(
      bindHost: bindHost,
      bindPort: bindPort,
      localHost: localHost,
      localPort: localPort,
    );
  }

  @override
  Future<void> stopRemoteForward({required SessionId sessionId}) async {}

  @override
  Future<DynamicForwardBinding> startDynamicForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
  }) async {
    return DynamicForwardBinding(bindHost: bindHost, bindPort: bindPort);
  }

  @override
  Future<void> stopDynamicForward({required SessionId sessionId}) async {}

  @override
  Future<void> testConnection(ConnectionProfileSnapshot profile) async {}
}

class _FakeShellSession implements SshShellSession {
  final Completer<void> _done = Completer<void>();
  final List<String> writes = [];

  void completeDone() {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Future<void> close() async {
    completeDone();
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {}

  @override
  Future<void> write(List<int> bytes) async {
    writes.add(String.fromCharCodes(bytes));
  }
}

class _FakeSftpConnection implements SftpConnection {
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {}

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) {
    return const Stream<TransferProgress>.empty();
  }

  @override
  Future<List<SftpEntry>> list(String path) async => [];

  @override
  Future<void> mkdir(String path) async {}

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    return const SftpFilePreview(text: '', bytesRead: 0, truncated: false);
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<void> writeTextFile(String path, String contents) async {}

  @override
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) {
    return const Stream<TransferProgress>.empty();
  }
}

class _FakeTerminalHostDisplaySettingsRepository
    implements TerminalHostDisplaySettingsRepository {
  _FakeTerminalHostDisplaySettingsRepository([
    Map<HostId, TerminalDisplaySettings>? profiles,
  ]) : profiles = {...?profiles};

  final Map<HostId, TerminalDisplaySettings> profiles;
  var readCount = 0;

  @override
  Future<void> deleteForHost(HostId hostId) async {
    profiles.remove(hostId);
  }

  @override
  Future<TerminalDisplaySettings?> readForHost(HostId hostId) async {
    readCount += 1;
    return profiles[hostId];
  }

  @override
  Future<void> saveForHost(
    HostId hostId,
    TerminalDisplaySettings settings,
  ) async {
    profiles[hostId] = settings;
  }
}

class _FakeTerminalDisplaySettingsRepository
    implements TerminalDisplaySettingsRepository {
  TerminalDisplaySettings? settings;

  @override
  Future<void> delete() async {
    settings = null;
  }

  @override
  Future<TerminalDisplaySettings?> read() async {
    return settings;
  }

  @override
  Future<void> save(TerminalDisplaySettings settings) async {
    this.settings = settings;
  }
}
