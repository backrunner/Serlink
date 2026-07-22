import 'dart:async';

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
import 'package:serlink/platform/platform_capabilities.dart';
import 'package:xterm/xterm.dart';

part 'workspace_tab_controller_test_fakes.dart';

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
      final terminal = container
          .read(workspaceRuntimeRegistryProvider)
          .terminalFor(content.primaryPane.sessionId)!;
      expect(tab.lifecycle, SessionLifecycleState.connected);
      expect(service.openShellCount, 1);
      expect(terminal.buffer.getText(), isNot(contains('Serlink')));
      expect(
        terminal.buffer.getText(),
        isNot(contains('Connection runtime is preparing this tab.')),
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
    'reuses failed terminal tab when host is opened again from hosts',
    () async {
      final service = _FakeSshSessionService()
        ..shellFailures.add(StateError('network down'));
      final container = _container(service: service);
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();

      var state = container.read(workspaceTabControllerProvider);
      final failedTab = state.activeTab!;
      final failedContent = failedTab.content as TerminalTabContent;
      final failedSessionId = failedContent.primaryPane.sessionId;
      final failedTerminal = container
          .read(workspaceRuntimeRegistryProvider)
          .terminalFor(failedSessionId)!;

      expect(failedTab.lifecycle, SessionLifecycleState.failed);
      expect(failedTerminal.buffer.getText(), contains('Connection failed'));
      expect(service.openShellCount, 1);

      controller.openTerminal(_host);
      await _drainMicrotasks();

      state = container.read(workspaceTabControllerProvider);
      final retriedTab = state.activeTab!;
      final retriedContent = retriedTab.content as TerminalTabContent;
      final retriedSessionId = retriedContent.primaryPane.sessionId;
      final retriedTerminal = container
          .read(workspaceRuntimeRegistryProvider)
          .terminalFor(retriedSessionId)!;

      expect(state.tabs, hasLength(1));
      expect(retriedTab.id, failedTab.id);
      expect(retriedTab.lifecycle, SessionLifecycleState.connected);
      expect(retriedSessionId, isNot(failedSessionId));
      expect(
        container
            .read(workspaceRuntimeRegistryProvider)
            .terminalFor(failedSessionId),
        isNull,
      );
      expect(
        retriedTerminal.buffer.getText(),
        isNot(contains('Connection failed')),
      );
      expect(service.openShellCount, 2);
      expect(service.shells, hasLength(1));
    },
  );

  test('creates terminals with the active platform capabilities', () async {
    final service = _FakeSshSessionService();
    final container = _container(
      service: service,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final tab = container.read(workspaceTabControllerProvider).activeTab!;
    final content = tab.content as TerminalTabContent;
    final terminal = container
        .read(workspaceRuntimeRegistryProvider)
        .terminalFor(content.primaryPane.sessionId)!;

    expect(terminal.platform, TerminalTargetPlatform.ios);
    expect(terminal.reflowEnabled, isFalse);
  });

  test(
    'auto reconnect retries terminal sessions up to the configured limit',
    () async {
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
            backoff: Duration.zero,
          ),
        ),
      );
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();

      final tab = container.read(workspaceTabControllerProvider).activeTab!;
      expect(service.openShellCount, 1);

      service.shells.single.completeDone();
      await _drainMicrotasks();

      expect(service.openShellCount, 2);

      service.shells.last.completeDone();
      await _drainMicrotasks();
      expect(service.openShellCount, 3);

      service.shells.last.completeDone();
      await _drainMicrotasks();
      expect(service.openShellCount, 3);

      expect(
        container.read(workspaceTabControllerProvider).activeTab!.id,
        tab.id,
      );
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

  test('runs remote session command after startup commands', () async {
    final service = _FakeSshSessionService();
    final container = _container(
      service: service,
      profile: StaticConnectionProfile(
        hostId: _host.id,
        hostname: _host.hostname,
        port: _host.port,
        username: _host.username,
        authMethods: [staticPasswordAuth('secret')],
        startupCommands: const ['cd /srv/app'],
        remoteSession: const SshRemoteSessionProfile(
          enabled: true,
          manager: SshRemoteSessionManager.auto,
          sessionName: 'ops',
          createIfMissing: true,
          fallbackToShell: true,
        ),
      ),
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    expect(service.shells.single.writes, hasLength(2));
    expect(service.shells.single.writes.first, 'cd /srv/app\n');
    final remoteSessionCommand = service.shells.single.writes.last;
    expect(remoteSessionCommand, contains('command -v tmux'));
    expect(remoteSessionCommand, contains('command -v screen'));
    expect(remoteSessionCommand, contains("exec tmux new-session -A -s 'ops'"));
    expect(remoteSessionCommand, contains("exec screen -S 'ops' -xRR"));
  });

  test(
    'auto remote session tries screen when tmux session is missing',
    () async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profile: StaticConnectionProfile(
          hostId: _host.id,
          hostname: _host.hostname,
          port: _host.port,
          username: _host.username,
          authMethods: [staticPasswordAuth('secret')],
          remoteSession: const SshRemoteSessionProfile(
            enabled: true,
            manager: SshRemoteSessionManager.auto,
            sessionName: 'ops',
            createIfMissing: false,
            fallbackToShell: true,
          ),
        ),
      );
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();

      final command = service.shells.single.writes.single;
      expect(command, contains("tmux has-session -t 'ops'"));
      expect(command, contains('elif command -v screen'));
      expect(
        command,
        contains("screen -x 'ops' && exit 0; screen -r 'ops' && exit 0"),
      );
      expect(command, isNot(contains('tmux session was not found')));
    },
  );

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
    'opens sftp at host default folder and clamps parent navigation',
    () async {
      final service = _FakeSshSessionService();
      final container = _container(service: service);
      addTearDown(container.dispose);

      final host = _hostWithSftpDefault('/srv/app');
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openSftp(host);
      await _drainMicrotasks();

      var state = container.read(workspaceTabControllerProvider);
      var tab = state.activeTab!;
      var content = tab.content as SftpTabContent;
      expect(content.rootPath, '/srv/app');
      expect(content.currentPath, '/srv/app');

      controller.changeSftpDirectory(tab.id, '/srv/app/releases');
      state = container.read(workspaceTabControllerProvider);
      tab = state.activeTab!;
      content = tab.content as SftpTabContent;
      expect(content.currentPath, '/srv/app/releases');

      controller.changeSftpDirectory(tab.id, '/srv');
      state = container.read(workspaceTabControllerProvider);
      content = state.activeTab!.content as SftpTabContent;
      expect(content.currentPath, '/srv/app');
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

  test(
    'enables, configures, and disables local terminal split state',
    () async {
      final localTerminal = _FakeLocalTerminalService();
      final container = _container(
        service: _FakeSshSessionService(),
        localTerminal: localTerminal,
      );
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openLocalTerminal();
      await _drainMicrotasks();

      final tabId = container
          .read(workspaceTabControllerProvider)
          .activeTab!
          .id;

      controller.enableTerminalSplit(tabId);
      await _drainMicrotasks();
      var content =
          container.read(workspaceTabControllerProvider).activeTab!.content
              as LocalTerminalTabContent;
      expect(content.showSplit, isTrue);
      expect(content.splitAxis, Axis.horizontal);
      expect(content.activePane, 1);
      expect(content.panes, hasLength(2));
      expect(localTerminal.openShellCount, 2);
      expect(content.panes[0].sessionId, isNot(content.panes[1].sessionId));
      final firstSplit = _expectSplit(content.layout, Axis.horizontal);
      _expectLeaf(firstSplit.first, 0);
      _expectLeaf(firstSplit.second, 1);
      expect(
        container
            .read(workspaceRuntimeRegistryProvider)
            .terminalFor(content.panes[1].sessionId),
        isNotNull,
      );

      final inserted = controller.insertIntoActiveTerminal('echo split');
      expect(inserted, isTrue);
      expect(localTerminal.shells[0].writes, isEmpty);
      expect(localTerminal.shells[1].writes, ['echo split']);

      controller.enableTerminalSplit(tabId, axis: Axis.vertical);
      await _drainMicrotasks();
      content =
          container.read(workspaceTabControllerProvider).activeTab!.content
              as LocalTerminalTabContent;
      expect(content.showSplit, isTrue);
      expect(content.activePane, 2);
      expect(content.panes, hasLength(3));
      expect(localTerminal.openShellCount, 3);
      final nestedSplit = _expectSplit(content.layout, Axis.horizontal);
      _expectLeaf(nestedSplit.first, 0);
      final nestedRight = _expectSplit(nestedSplit.second, Axis.vertical);
      _expectLeaf(nestedRight.first, 1);
      _expectLeaf(nestedRight.second, 2);

      controller.setActiveTerminalPane(tabId, 1);
      controller.closeActiveTerminalPane(tabId);
      await _drainMicrotasks();
      content =
          container.read(workspaceTabControllerProvider).activeTab!.content
              as LocalTerminalTabContent;
      expect(content.showSplit, isTrue);
      expect(content.activePane, 1);
      expect(content.panes, hasLength(2));
      final collapsedSplit = _expectSplit(content.layout, Axis.horizontal);
      _expectLeaf(collapsedSplit.first, 0);
      _expectLeaf(collapsedSplit.second, 1);
      expect(localTerminal.shells[1]._done.isCompleted, isTrue);
      expect(localTerminal.shells[2]._done.isCompleted, isFalse);

      final insertedAfterClose = controller.insertIntoActiveTerminal(
        'after close',
      );
      expect(insertedAfterClose, isTrue);
      expect(localTerminal.shells[2].writes, ['after close']);

      controller.disableTerminalSplit(tabId);
      await _drainMicrotasks();
      content =
          container.read(workspaceTabControllerProvider).activeTab!.content
              as LocalTerminalTabContent;
      expect(content.showSplit, isFalse);
      expect(content.activePane, 0);
      expect(content.panes, hasLength(1));
      expect(localTerminal.shells[0]._done.isCompleted, isFalse);
      expect(localTerminal.shells[2]._done.isCompleted, isTrue);
    },
  );

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

  test('closing inactive split pane preserves active pane', () async {
    final service = _FakeSshSessionService();
    final container = _container(service: service);
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();

    final tabId = container.read(workspaceTabControllerProvider).activeTab!.id;
    controller.enableTerminalSplit(tabId);
    await _drainMicrotasks();
    controller.setActiveTerminalPane(tabId, 0);
    controller.enableTerminalSplit(tabId, axis: Axis.vertical);
    await _drainMicrotasks();
    controller.setActiveTerminalPane(tabId, 0);

    controller.closeTerminalPane(tabId, 2);
    await _drainMicrotasks();

    final content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.panes, hasLength(2));
    expect(content.activePane, 0);
    expect(service.shells[0]._done.isCompleted, isFalse);
    expect(service.shells[2]._done.isCompleted, isTrue);
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

  test(
    'inserts into active split pane while another pane is disconnected',
    () async {
      final service = _FakeSshSessionService();
      final container = _container(service: service);
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();
      final tabId = container
          .read(workspaceTabControllerProvider)
          .activeTab!
          .id;
      controller.enableTerminalSplit(tabId);
      await _drainMicrotasks();
      controller.setActiveTerminalPane(tabId, 1);

      service.shells.first.completeDone();
      await _drainMicrotasks();

      final tab = container.read(workspaceTabControllerProvider).activeTab!;
      final content = tab.content as TerminalTabContent;
      expect(tab.lifecycle, SessionLifecycleState.disconnected);
      expect(content.panes[1].lifecycle, SessionLifecycleState.connected);

      final inserted = controller.insertIntoActiveTerminal('still alive');

      expect(inserted, isTrue);
      expect(service.shells[0].writes, isEmpty);
      expect(service.shells[1].writes, ['still alive']);
    },
  );

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
    var split = _expectSplit(content.layout, Axis.horizontal);
    _expectLeaf(split.first, 0);
    _expectLeaf(split.second, 1);

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

    controller.enableTerminalSplit(tabId, axis: Axis.horizontal);
    await _drainMicrotasks();
    content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.showSplit, isTrue);
    expect(content.activePane, 2);
    expect(content.panes, hasLength(3));
    expect(service.openShellCount, 3);
    split = _expectSplit(content.layout, Axis.vertical);
    _expectLeaf(split.first, 0);
    final lowerSplit = _expectSplit(split.second, Axis.horizontal);
    _expectLeaf(lowerSplit.first, 1);
    _expectLeaf(lowerSplit.second, 2);

    controller.disableTerminalSplit(tabId);
    await _drainMicrotasks();
    content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as TerminalTabContent;
    expect(content.showSplit, isFalse);
    expect(content.activePane, 0);
    expect(content.panes, hasLength(1));
    expect(service.shells[1]._done.isCompleted, isTrue);
    expect(service.shells[2]._done.isCompleted, isTrue);
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

  test('moves single-pane terminal tab into another split layout', () async {
    final service = _FakeSshSessionService();
    final container = _container(
      service: service,
      profiles: {
        _host.id: _profileFor(_host),
        _secondHost.id: _profileFor(_secondHost),
      },
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();
    final targetTab = container.read(workspaceTabControllerProvider).activeTab!;
    controller.openTerminal(_secondHost);
    await _drainMicrotasks();
    final sourceTab = container.read(workspaceTabControllerProvider).activeTab!;
    final sourceContent = sourceTab.content as TerminalTabContent;
    final movedSessionId = sourceContent.primaryPane.sessionId;

    controller.mergeSinglePaneTabIntoSplit(
      sourceTabId: sourceTab.id,
      targetTabId: targetTab.id,
      targetPaneIndex: 0,
      axis: Axis.horizontal,
      before: false,
    );
    await _drainMicrotasks();

    var state = container.read(workspaceTabControllerProvider);
    expect(state.tabs, hasLength(1));
    expect(state.activeTab!.id, targetTab.id);
    var content = state.activeTab!.content as TerminalTabContent;
    expect(content.panes, hasLength(2));
    expect(content.activePane, 1);
    expect(content.panes[1].sessionId, movedSessionId);
    expect(content.panes[1].endpoint?.hostId, _secondHost.id);
    final split = _expectSplit(content.layout, Axis.horizontal);
    _expectLeaf(split.first, 0);
    _expectLeaf(split.second, 1);

    service.shells.last.completeDone();
    await _drainMicrotasks();

    state = container.read(workspaceTabControllerProvider);
    content = state.activeTab!.content as TerminalTabContent;
    expect(content.panes[1].lifecycle, SessionLifecycleState.disconnected);
    expect(state.activeTab!.lifecycle, SessionLifecycleState.disconnected);
  });

  test('opens sftp from the active split pane host', () async {
    final service = _FakeSshSessionService();
    final container = _container(
      service: service,
      profiles: {
        _host.id: _profileFor(_host),
        _secondHost.id: _profileFor(_secondHost),
      },
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openTerminal(_host);
    await _drainMicrotasks();
    final targetTab = container.read(workspaceTabControllerProvider).activeTab!;
    controller.openTerminal(_secondHost);
    await _drainMicrotasks();
    final sourceTab = container.read(workspaceTabControllerProvider).activeTab!;

    controller.mergeSinglePaneTabIntoSplit(
      sourceTabId: sourceTab.id,
      targetTabId: targetTab.id,
      targetPaneIndex: 0,
      axis: Axis.horizontal,
      before: false,
    );
    controller.openSftpFromTerminalPane(targetTab.id, 1);
    await _drainMicrotasks();

    final state = container.read(workspaceTabControllerProvider);
    final sftpTab = state.activeTab!;
    final sftpContent = sftpTab.content as SftpTabContent;
    expect(sftpTab.hostId, _secondHost.id);
    expect(sftpContent.rootPath, '/var/www');
    expect(service.sftpProfiles.single.hostId, _secondHost.id);
  });

  test(
    'saves terminal display settings for the active split pane host',
    () async {
      final service = _FakeSshSessionService();
      final profileRepository = _FakeTerminalHostDisplaySettingsRepository();
      final container = _container(
        service: service,
        terminalProfiles: profileRepository,
        profiles: {
          _host.id: _profileFor(_host),
          _secondHost.id: _profileFor(_secondHost),
        },
      );
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _drainMicrotasks();
      final targetTab = container
          .read(workspaceTabControllerProvider)
          .activeTab!;
      controller.openTerminal(_secondHost);
      await _drainMicrotasks();
      final sourceTab = container
          .read(workspaceTabControllerProvider)
          .activeTab!;

      controller.mergeSinglePaneTabIntoSplit(
        sourceTabId: sourceTab.id,
        targetTabId: targetTab.id,
        targetPaneIndex: 0,
        axis: Axis.horizontal,
        before: false,
      );
      const profile = TerminalDisplaySettings(
        themeId: SerlinkTerminalThemeId.serlinkLight,
        fontSize: 17,
        lineHeight: 1.2,
        scrollbackLines: 32000,
      );

      controller.saveTerminalDisplaySettingsForHost(
        targetTab.id,
        profile,
        paneIndex: 1,
      );
      await _drainMicrotasks();

      final content =
          container.read(workspaceTabControllerProvider).tabs.single.content
              as TerminalTabContent;
      expect(profileRepository.profiles.containsKey(_host.id), isFalse);
      expect(profileRepository.profiles[_secondHost.id], profile);
      expect(content.panes[0].displaySettings, isNull);
      expect(content.panes[1].displaySettings, profile);

      controller.resetTerminalDisplaySettingsForHost(
        targetTab.id,
        paneIndex: 1,
      );
      await _drainMicrotasks();

      final resetContent =
          container.read(workspaceTabControllerProvider).tabs.single.content
              as TerminalTabContent;
      expect(profileRepository.profiles.containsKey(_secondHost.id), isFalse);
      expect(resetContent.panes[1].displaySettings, isNull);
    },
  );

  test(
    'splits remote pane inside local tab by opening another ssh shell',
    () async {
      final service = _FakeSshSessionService();
      final localTerminal = _FakeLocalTerminalService();
      final container = _container(
        service: service,
        localTerminal: localTerminal,
        profiles: {
          _host.id: _profileFor(_host),
          _secondHost.id: _profileFor(_secondHost),
        },
      );
      addTearDown(container.dispose);

      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openLocalTerminal();
      await _drainMicrotasks();
      final localTab = container
          .read(workspaceTabControllerProvider)
          .activeTab!;

      controller.openTerminal(_secondHost);
      await _drainMicrotasks();
      final remoteTab = container
          .read(workspaceTabControllerProvider)
          .activeTab!;

      controller.mergeSinglePaneTabIntoSplit(
        sourceTabId: remoteTab.id,
        targetTabId: localTab.id,
        targetPaneIndex: 0,
        axis: Axis.horizontal,
        before: false,
      );
      controller.enableTerminalSplit(localTab.id, axis: Axis.vertical);
      await _drainMicrotasks();

      final content =
          container.read(workspaceTabControllerProvider).activeTab!.content
              as LocalTerminalTabContent;
      expect(content.panes, hasLength(3));
      expect(content.panes[2].endpoint?.hostId, _secondHost.id);
      expect(localTerminal.openShellCount, 1);
      expect(service.openShellCount, 2);
      expect(service.shellProfiles.last.hostId, _secondHost.id);
    },
  );

  test('reconnects mixed local tab panes with their own transports', () async {
    final service = _FakeSshSessionService();
    final localTerminal = _FakeLocalTerminalService();
    final container = _container(
      service: service,
      localTerminal: localTerminal,
      profiles: {
        _host.id: _profileFor(_host),
        _secondHost.id: _profileFor(_secondHost),
      },
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openLocalTerminal();
    await _drainMicrotasks();
    final localTab = container.read(workspaceTabControllerProvider).activeTab!;

    controller.openTerminal(_secondHost);
    await _drainMicrotasks();
    final remoteTab = container.read(workspaceTabControllerProvider).activeTab!;

    controller.mergeSinglePaneTabIntoSplit(
      sourceTabId: remoteTab.id,
      targetTabId: localTab.id,
      targetPaneIndex: 0,
      axis: Axis.horizontal,
      before: false,
    );

    controller.reconnect(localTab.id);
    await _drainMicrotasks();

    final content =
        container.read(workspaceTabControllerProvider).activeTab!.content
            as LocalTerminalTabContent;
    expect(content.panes.map((pane) => pane.lifecycle), [
      SessionLifecycleState.connected,
      SessionLifecycleState.connected,
    ]);
    expect(localTerminal.openShellCount, 2);
    expect(service.openShellCount, 2);
    expect(service.shellProfiles.last.hostId, _secondHost.id);
  });

  test('remote pane reconnect failure does not fail local sibling', () async {
    final service = _FakeSshSessionService();
    final localTerminal = _FakeLocalTerminalService();
    final container = _container(
      service: service,
      localTerminal: localTerminal,
      profiles: {
        _host.id: _profileFor(_host),
        _secondHost.id: _profileFor(_secondHost),
      },
    );
    addTearDown(container.dispose);

    final controller = container.read(workspaceTabControllerProvider.notifier);
    controller.openLocalTerminal();
    await _drainMicrotasks();
    final localTab = container.read(workspaceTabControllerProvider).activeTab!;

    controller.openTerminal(_secondHost);
    await _drainMicrotasks();
    final remoteTab = container.read(workspaceTabControllerProvider).activeTab!;

    controller.mergeSinglePaneTabIntoSplit(
      sourceTabId: remoteTab.id,
      targetTabId: localTab.id,
      targetPaneIndex: 0,
      axis: Axis.horizontal,
      before: false,
    );
    service.shellFailures.add(StateError('remote down'));

    controller.reconnect(localTab.id);
    await _drainMicrotasks();

    final tab = container.read(workspaceTabControllerProvider).activeTab!;
    final content = tab.content as LocalTerminalTabContent;
    expect(tab.lifecycle, SessionLifecycleState.failed);
    expect(content.panes[0].lifecycle, SessionLifecycleState.connected);
    expect(content.panes[1].lifecycle, SessionLifecycleState.failed);
    expect(localTerminal.openShellCount, 2);
    expect(service.openShellCount, 2);

    controller.setActiveTerminalPane(localTab.id, 0);
    final inserted = controller.insertIntoActiveTerminal('local ok');

    expect(inserted, isTrue);
    expect(localTerminal.shells.last.writes, ['local ok']);
  });
}

TerminalPaneSplit _expectSplit(TerminalPaneLayout layout, Axis axis) {
  final split = layout as TerminalPaneSplit;
  expect(split.axis, axis);
  return split;
}

void _expectLeaf(TerminalPaneLayout layout, int paneIndex) {
  final leaf = layout as TerminalPaneLeaf;
  expect(leaf.paneIndex, paneIndex);
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
  createdAt: DateTime.utc(2026),
);

final _secondHost = HostSummary(
  id: HostId('host-2'),
  displayName: 'Second Host',
  hostname: 'second.internal',
  username: 'deploy',
  port: 2222,
  authKinds: const {HostAuthKind.password},
  tags: const {},
  trustState: HostTrustState.trusted,
  createdAt: DateTime.utc(2026),
  sftpDefaultDirectory: '/var/www',
);

HostSummary _hostWithSftpDefault(String path) {
  return HostSummary(
    id: _host.id,
    displayName: _host.displayName,
    hostname: _host.hostname,
    username: _host.username,
    port: _host.port,
    authKinds: _host.authKinds,
    tags: _host.tags,
    trustState: _host.trustState,
    createdAt: _host.createdAt,
    sftpDefaultDirectory: path,
  );
}

StaticConnectionProfile _profileFor(HostSummary host) {
  return StaticConnectionProfile(
    hostId: host.id,
    hostname: host.hostname,
    port: host.port,
    username: host.username,
    authMethods: [staticPasswordAuth('secret')],
  );
}

ProviderContainer _container({
  required _FakeSshSessionService service,
  LocalTerminalService? localTerminal,
  _FakeTerminalHostDisplaySettingsRepository? terminalProfiles,
  StaticConnectionProfile? profile,
  Map<HostId, StaticConnectionProfile>? profiles,
  PlatformCapabilities? capabilities,
}) {
  return ProviderContainer(
    overrides: [
      if (capabilities != null)
        platformCapabilitiesProvider.overrideWithValue(capabilities),
      sshSessionServiceProvider.overrideWithValue(service),
      if (localTerminal != null)
        localTerminalServiceProvider.overrideWithValue(localTerminal),
      connectionProfileResolverProvider.overrideWithValue(
        StaticConnectionProfileResolver(
          profiles ?? {_host.id: profile ?? _profileFor(_host)},
        ),
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
