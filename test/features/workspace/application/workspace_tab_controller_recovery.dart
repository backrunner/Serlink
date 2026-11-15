part of 'workspace_tab_controller_test.dart';

StaticConnectionProfile _recoveryProfile(
  HostSummary host, {
  int attempts = 3,
  Duration backoff = const Duration(seconds: 1),
  SshRemoteSessionProfile remoteSession = const SshRemoteSessionProfile(),
}) => StaticConnectionProfile(
  hostId: host.id,
  hostname: host.hostname,
  port: host.port,
  username: host.username,
  authMethods: [staticPasswordAuth('secret')],
  reconnectPolicy: SshReconnectPolicy(maxAttempts: attempts, backoff: backoff),
  remoteSession: remoteSession,
);

Future<void> _pumpRecovery(
  WidgetTester tester, [
  Duration duration = Duration.zero,
]) async {
  await tester.pump(duration);
  // Stream cancellation may complete outside the binding's fake clock.
  await tester.runAsync(_drainMicrotasks);
  await tester.pump();
}

void _remoteSessionRecoveryTests() {
  group('foreground SSH recovery', () {
    testWidgets('confirms a failed probe without replacing a healthy shell', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profile: _recoveryProfile(_host),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      var probes = 0;
      service.probeResult = (_) => ++probes > 1;

      final probing = controller.probeRemoteSessions();
      await _pumpRecovery(tester);
      expect(probes, 1);
      expect(
        container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
        SessionLifecycleState.connected,
      );
      await _pumpRecovery(tester, const Duration(seconds: 1));
      await probing;
      await _pumpRecovery(tester, const Duration(seconds: 5));
      expect(probes, 2);
      expect(service.openShellCount, 1);
      expect(service.shells.single._done.isCompleted, isFalse);
    });

    testWidgets('recovers only the dead split and keeps the selected tab', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profile: _recoveryProfile(_host),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      final tab = container.read(workspaceTabControllerProvider).activeTab!;
      controller.enableTerminalSplit(tab.id);
      await _pumpRecovery(tester);
      final panes =
          (container.read(workspaceTabControllerProvider).activeTab!.content
                  as TerminalTabContent)
              .panes;
      final runtime = container.read(workspaceRuntimeRegistryProvider);
      final healthyTerminal = runtime.terminalFor(panes[0].sessionId);
      healthyTerminal!.write('preserved output');
      // A second tab must not become deselected when the first recovers.
      controller.openTerminal(_host, reuseFailedTab: false);
      await _pumpRecovery(tester);
      final selected = container
          .read(workspaceTabControllerProvider)
          .activeTabId;
      service.probeResult = (id) => id != panes[1].sessionId;

      final probing = controller.probeRemoteSessions();
      await _pumpRecovery(tester);
      await _pumpRecovery(tester, const Duration(seconds: 1));
      await probing;
      await _pumpRecovery(tester, const Duration(seconds: 1));
      expect(service.openShellCount, 4);
      expect(service.shellProfiles.last.sessionId, panes[1].sessionId);
      expect(service.shells[0]._done.isCompleted, isFalse);
      expect(service.shells[1]._done.isCompleted, isTrue);
      expect(runtime.terminalFor(panes[0].sessionId), same(healthyTerminal));
      expect(healthyTerminal.buffer.getText(), contains('preserved output'));
      expect(
        container.read(workspaceTabControllerProvider).activeTabId,
        selected,
      );
    });

    testWidgets('uses each host policy after tabs merge into a split', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profiles: {
          _host.id: _recoveryProfile(_host),
          _secondHost.id: _recoveryProfile(_secondHost, attempts: 0),
        },
      );
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      final first = container.read(workspaceTabControllerProvider).activeTab!;
      controller.openTerminal(_secondHost);
      await _pumpRecovery(tester);
      final second = container.read(workspaceTabControllerProvider).activeTab!;
      controller.mergeSinglePaneTabIntoSplit(
        sourceTabId: second.id,
        targetTabId: first.id,
        targetPaneIndex: 0,
        axis: Axis.horizontal,
        before: false,
      );
      service.shells[0].completeDone();
      service.shells[1].completeDone();
      await _pumpRecovery(tester);
      await _pumpRecovery(tester, const Duration(seconds: 1));
      expect(service.openShellCount, 3);
      expect(service.shellProfiles.last.hostId, _host.id);
      final content =
          container.read(workspaceTabControllerProvider).activeTab!.content
              as TerminalTabContent;
      expect(content.panes.map((p) => p.lifecycle), [
        SessionLifecycleState.connected,
        SessionLifecycleState.disconnected,
      ]);
    });

    testWidgets(
      'defers background disconnects until grace and backoff finish',
      (tester) async {
        final service = _FakeSshSessionService();
        final container = _container(
          service: service,
          profile: _recoveryProfile(_host),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          workspaceTabControllerProvider.notifier,
        );
        controller.openTerminal(_host);
        await _pumpRecovery(tester);
        controller.pauseRemoteSessionRecovery();
        service.shells.single.completeDone();
        await _pumpRecovery(tester);
        await _pumpRecovery(tester, const Duration(minutes: 5));
        expect(service.openShellCount, 1);

        final resuming = controller.resumeRemoteSessions();
        await _pumpRecovery(tester, const Duration(milliseconds: 999));
        expect(service.openShellCount, 1);
        expect(service.probedSessionIds, isEmpty);
        await _pumpRecovery(tester, const Duration(milliseconds: 1));
        await resuming;
        expect(service.openShellCount, 1);
        await _pumpRecovery(tester, const Duration(seconds: 1));
        expect(service.openShellCount, 2);
      },
    );

    testWidgets('waits before probing a silently dead foreground socket', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profile: _recoveryProfile(_host),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      service.probeResult = (_) => false;
      controller.pauseRemoteSessionRecovery();
      final resuming = controller.resumeRemoteSessions();
      await _pumpRecovery(tester, const Duration(milliseconds: 999));
      expect(service.probedSessionIds, isEmpty);
      await _pumpRecovery(tester, const Duration(milliseconds: 1));
      expect(service.probedSessionIds, hasLength(1));
      await _pumpRecovery(tester, const Duration(seconds: 1));
      await resuming;
      await _pumpRecovery(tester, const Duration(seconds: 1));
      expect(service.probedSessionIds, hasLength(2));
      expect(service.openShellCount, 2);
    });

    testWidgets('retries failed reconnects within the configured budget', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profile: _recoveryProfile(_host, attempts: 2),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      service.shellFailures.addAll([
        StateError('offline'),
        StateError('still offline'),
      ]);
      service.shells.single.completeDone();
      await _pumpRecovery(tester);
      await _pumpRecovery(tester, const Duration(seconds: 1));
      expect(service.openShellCount, 2);
      await _pumpRecovery(tester, const Duration(seconds: 1));
      expect(service.openShellCount, 3);
      await _pumpRecovery(tester, const Duration(minutes: 1));
      expect(service.openShellCount, 3);
      expect(
        container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
        SessionLifecycleState.failed,
      );
    });

    testWidgets('reattaches the configured tmux session after a failed retry', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profile: _recoveryProfile(
          _host,
          remoteSession: const SshRemoteSessionProfile(
            enabled: true,
            manager: SshRemoteSessionManager.tmux,
            sessionName: 'coding',
          ),
        ),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      final attach = service.shells.single.writes.single;
      service.shellFailures.add(StateError('offline'));
      service.shells.single.completeDone();
      await _pumpRecovery(tester);
      await _pumpRecovery(tester, const Duration(seconds: 1));
      await _pumpRecovery(tester, const Duration(seconds: 1));
      expect(service.openShellCount, 3);
      expect(service.shells.last.writes, [attach]);
      expect(attach, contains("tmux new-session -A -s 'coding'"));
      expect(
        container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
        SessionLifecycleState.connected,
      );
    });

    testWidgets(
      'ignores an old probe after manual reconnect in the same pane',
      (tester) async {
        final service = _FakeSshSessionService();
        final container = _container(
          service: service,
          profile: _recoveryProfile(_host),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          workspaceTabControllerProvider.notifier,
        );
        controller.openTerminal(_host);
        await _pumpRecovery(tester);
        final tab = container.read(workspaceTabControllerProvider).activeTab!;
        final response = Completer<bool>();
        service.probeResult = (_) => response.future;
        final probing = controller.probeRemoteSessions();
        controller.reconnectTerminalPane(tab.id, 0);
        await _pumpRecovery(tester);
        response.complete(false);
        await _pumpRecovery(tester);
        await probing;
        await _pumpRecovery(tester, const Duration(seconds: 10));
        expect(service.openShellCount, 2);
        expect(service.probedSessionIds, hasLength(1));
        expect(
          container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
          SessionLifecycleState.connected,
        );
      },
    );

    testWidgets(
      'allows a new foreground probe while an older probe is pending',
      (tester) async {
        final service = _FakeSshSessionService();
        final container = _container(
          service: service,
          profile: _recoveryProfile(_host),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          workspaceTabControllerProvider.notifier,
        );
        controller.openTerminal(_host);
        await _pumpRecovery(tester);
        final response = Completer<bool>();
        service.probeResult = (_) => response.future;
        final oldProbe = controller.probeRemoteSessions();
        controller.pauseRemoteSessionRecovery();
        service.probeResult = (_) => true;
        final resuming = controller.resumeRemoteSessions();
        await _pumpRecovery(tester, const Duration(seconds: 1));
        await resuming;
        expect(service.probedSessionIds, hasLength(2));
        response.complete(false);
        await _pumpRecovery(tester);
        await oldProbe;
        await _pumpRecovery(tester, const Duration(seconds: 5));
        expect(service.openShellCount, 1);
        expect(
          container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
          SessionLifecycleState.connected,
        );
      },
    );

    testWidgets('cancels delayed recovery when backgrounded again or closed', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(
        service: service,
        profile: _recoveryProfile(_host),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      final tab = container.read(workspaceTabControllerProvider).activeTab!;
      service.shells.single.completeDone();
      await _pumpRecovery(tester);
      controller.pauseRemoteSessionRecovery();
      final resuming = controller.resumeRemoteSessions();
      await _pumpRecovery(tester, const Duration(milliseconds: 500));
      controller.pauseRemoteSessionRecovery();
      await _pumpRecovery(tester, const Duration(seconds: 5));
      await resuming;
      expect(service.openShellCount, 1);
      expect(service.probedSessionIds, isEmpty);
      controller.closeTab(tab.id);
      final secondResume = controller.resumeRemoteSessions();
      await _pumpRecovery(tester, const Duration(seconds: 10));
      await secondResume;
      expect(service.openShellCount, 1);
    });

    testWidgets(
      'does not spend retry budget while backgrounding during teardown',
      (tester) async {
        final service = _FakeSshSessionService();
        final container = _container(
          service: service,
          profile: _recoveryProfile(_host, attempts: 1),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          workspaceTabControllerProvider.notifier,
        );
        controller.openTerminal(_host);
        await _pumpRecovery(tester);
        final closing = Completer<void>();
        service.shells.single.closeBarrier = closing.future;
        service.shells.single.completeDone();
        await _pumpRecovery(tester);
        await _pumpRecovery(tester, const Duration(seconds: 1));
        controller.pauseRemoteSessionRecovery();
        closing.complete();
        await _pumpRecovery(tester);
        expect(service.openShellCount, 1);
        final resuming = controller.resumeRemoteSessions();
        await _pumpRecovery(tester, const Duration(seconds: 1));
        await resuming;
        await _pumpRecovery(tester, const Duration(seconds: 1));
        expect(service.openShellCount, 2);
      },
    );

    testWidgets(
      'recovers successive background losses with a fresh connected budget',
      (tester) async {
        final service = _FakeSshSessionService();
        final container = _container(
          service: service,
          capabilities: const PlatformCapabilities(
            operatingSystem: 'ios',
            targetPlatform: TargetPlatform.iOS,
          ),
          profile: _recoveryProfile(_host, attempts: 1),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          workspaceTabControllerProvider.notifier,
        );
        controller.openTerminal(_host);
        await _pumpRecovery(tester);
        for (var cycle = 0; cycle < 4; cycle += 1) {
          controller.pauseRemoteSessionRecovery();
          service.shells.last.completeDone();
          await _pumpRecovery(tester);
          final resuming = controller.resumeRemoteSessions();
          await _pumpRecovery(tester, const Duration(seconds: 1));
          await resuming;
          await _pumpRecovery(tester, const Duration(seconds: 1));
          expect(service.openShellCount, cycle + 2);
          expect(
            container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
            SessionLifecycleState.connected,
          );
        }
      },
    );

    testWidgets('contains probe exceptions and honors disabled reconnect', (
      tester,
    ) async {
      final service = _FakeSshSessionService();
      final container = _container(service: service);
      addTearDown(container.dispose);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      controller.openTerminal(_host);
      await _pumpRecovery(tester);
      service.probeResult = (_) => throw StateError('network unavailable');
      final probing = controller.probeRemoteSessions();
      await _pumpRecovery(tester);
      await _pumpRecovery(tester, const Duration(seconds: 1));
      await probing;
      await _pumpRecovery(tester, const Duration(seconds: 10));
      expect(service.probedSessionIds, hasLength(2));
      expect(service.openShellCount, 1);
      expect(
        container.read(workspaceTabControllerProvider).activeTab!.lifecycle,
        SessionLifecycleState.disconnected,
      );
    });
  });
}
