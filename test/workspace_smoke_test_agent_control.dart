part of 'workspace_smoke_test.dart';

void _agentControlTests() {
  for (final compact in [false, true]) {
    testWidgets(
      'SFTP agent badge identifies client and releases control (compact: $compact)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = compact
            ? const Size(390, 844)
            : const Size(1100, 850);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final ssh = _FakeSshSessionService();
        await _pumpLockedVaultApp(
          tester,
          capabilities: PlatformCapabilities(
            operatingSystem: compact ? 'ios' : 'windows',
            targetPlatform: compact
                ? TargetPlatform.iOS
                : TargetPlatform.windows,
          ),
          sshService: ssh,
        );
        await _submitVaultPassphrase(tester, 'correct horse battery staple');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SerlinkApp)),
        );
        final host = await container
            .read(hostWriteServiceProvider)
            .createPasswordHost(
              const PasswordHostDraft(
                displayName: 'Files',
                hostname: 'files.internal',
                port: 22,
                username: 'ops',
                password: 'fixture-password',
                tags: {},
              ),
            );
        final controller = container.read(
          workspaceTabControllerProvider.notifier,
        );
        final tab = controller.openSftp(host);
        final sessionId = (tab.content as SftpTabContent).sessionId;
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('sftp-agent-badge')), findsNothing);
        final bridge = container.read(agentSessionBridgeProvider);
        final attaching = bridge.attachSession(
          clientName: 'test-client',
          sessionId: sessionId,
        );
        await tester.pumpAndSettle();
        expect(find.text('Allow and remember'), findsOneWidget);
        await tester.tap(find.text('Allow and remember'));
        await tester.pumpAndSettle();
        final handle = await attaching;
        expect(handle.kind, AgentSessionKind.sftp);
        expect(find.byKey(const ValueKey('sftp-agent-badge')), findsOneWidget);
        expect(find.text('Agent · test-client'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('sftp-agent-badge-release')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('sftp-agent-badge')), findsNothing);
        expect(bridge.sessions, isEmpty);
        expect(
          container.read(workspaceTabControllerProvider).tabs.single.lifecycle,
          SessionLifecycleState.connected,
        );
        expect(
          container.read(workspaceRuntimeRegistryProvider).sftpFor(sessionId),
          isNotNull,
        );
        expect(ssh.sftp._done.isCompleted, isFalse);
        final reconnecting = bridge.attachSession(
          clientName: 'test-client',
          sessionId: sessionId,
        );
        await tester.pumpAndSettle();
        await reconnecting;
        expect(find.text('Allow and remember'), findsNothing);
        expect(find.byKey(const ValueKey('sftp-agent-badge')), findsOneWidget);
        controller.closeTab(tab.id);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('sftp-agent-badge')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
