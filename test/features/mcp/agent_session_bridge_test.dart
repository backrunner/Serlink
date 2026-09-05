import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_store.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/mcp/application/agent_session_bridge.dart';
import 'package:serlink/features/mcp/data/command_risk_policy.dart';
import 'package:serlink/features/mcp/domain/agent_session.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/ssh/application/connection_profile_resolver.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';
import 'package:serlink/features/terminal/application/terminal_display_settings.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/workspace/application/workspace_runtime_registry.dart';
import 'package:serlink/features/workspace/application/workspace_tab_controller.dart';
import 'package:serlink/features/workspace/domain/workspace_tab.dart';

void main() {
  group('AgentSessionBridge', () {
    test('listHosts throws vault_locked when the vault is locked', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
        unlocked: false,
      );
      addTearDown(container.dispose);
      await container.read(vaultSessionControllerProvider.future);
      final bridge = await _bridge(container);

      expect(
        bridge.listHosts,
        throwsA(_bridgeException('vault_locked')),
      );
    });

    test('openSession throws vault_locked when the vault is locked', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
        unlocked: false,
      );
      addTearDown(container.dispose);
      await container.read(vaultSessionControllerProvider.future);
      final bridge = await _bridge(container);

      await expectLater(
        bridge.openSession(clientName: _clientName, hostId: _host.id),
        throwsA(_bridgeException('vault_locked')),
      );
    });

    test('openSession throws host_not_found for an unknown host', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);

      await expectLater(
        bridge.openSession(clientName: _clientName, hostId: HostId('missing')),
        throwsA(_bridgeException('host_not_found')),
      );
    });

    test('openSession throws authorization_denied when the user denies', () async {
      final modal = _FakeSecurityModalService()
        ..accessDecision = AgentAccessDecision.deny;
      final service = _EchoSshSessionService();
      final container = _container(service: service, modal: modal);
      addTearDown(container.dispose);
      final bridge = await _bridge(container);

      await expectLater(
        bridge.openSession(clientName: _clientName, hostId: _host.id),
        throwsA(_bridgeException('authorization_denied')),
      );
      expect(service.openShellCount, 0);
    });

    test('openSession opens a workspace tab and attaches', () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);

      final handle = await bridge.openSession(
        clientName: _clientName,
        hostId: _host.id,
      );

      expect(handle.state, AgentSessionState.connected);
      expect(handle.hostId, _host.id);
      expect(handle.clientName, _clientName);
      expect(service.openShellCount, 1);
      expect(
        container
            .read(workspaceRuntimeRegistryProvider)
            .hasAttachedTerminal(handle.sessionId),
        isTrue,
      );
      expect(bridge.sessionsFor(_clientName), [handle]);
      final screen = await bridge.readScreen(
        clientName: _clientName,
        sessionId: handle.sessionId,
      );
      expect(screen, isA<String>());
    });

    test('exec runs a safe command and returns the settled screen', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      final output = await bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'ls -la',
      );

      expect(output, contains('ls -la'));
    });

    test('exec throws session_not_found for an unknown session', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);

      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: SessionId('missing'),
          command: 'ls',
        ),
        throwsA(_bridgeException('session_not_found')),
      );
    });

    test('exec blocks destructive commands without sending input', () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'mkfs.ext4 /dev/sda1',
        ),
        throwsA(_bridgeException('command_blocked')),
      );
      expect(service.shells.single.writes, isEmpty);
    });

    test('exec throws command_denied when confirmation is denied', () async {
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.deny;
      final container = _container(service: service, modal: modal);
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'rm -rf /tmp/junk',
        ),
        throwsA(_bridgeException('command_denied')),
      );
      expect(service.shells.single.writes, isEmpty);
      expect(modal.commandCallCount, 1);
    });

    test('allowSession adds the rule to the session allowlist', () async {
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowSession;
      final container = _container(service: service, modal: modal);
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'rm -rf /tmp/a',
      );
      await bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'rm -rf /tmp/b',
      );

      expect(modal.commandCallCount, 1);
      expect(service.shells.single.writes, hasLength(2));
    });

    test('allowOnce does not skip the next confirmation', () async {
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowOnce;
      final container = _container(
        service: _EchoSshSessionService(),
        modal: modal,
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'rm -rf /tmp/a',
      );
      await bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'rm -rf /tmp/b',
      );

      expect(modal.commandCallCount, 2);
    });

    test('revokeGrant makes further calls fail with authorization_required',
        () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'ls',
      );
      bridge.revokeGrant(handle.grantId);

      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'ls',
        ),
        throwsA(_bridgeException('authorization_required')),
      );
      // The tab stays open; only agent access is cut.
      expect(
        container
            .read(workspaceRuntimeRegistryProvider)
            .hasAttachedTerminal(handle.sessionId),
        isTrue,
      );
      expect(service.shells.single.writes, hasLength(1));
    });

    test('sendInput sends raw text and policies newline input', () async {
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService();
      final container = _container(service: service, modal: modal);
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await bridge.sendInput(
        clientName: _clientName,
        sessionId: handle.sessionId,
        text: 'y',
      );
      expect(service.shells.single.writes, ['y']);
      expect(modal.commandCallCount, 0);

      await expectLater(
        bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: 'rm -rf /tmp/junk\n',
        ),
        throwsA(_bridgeException('command_denied')),
      );
      expect(service.shells.single.writes, ['y']);
    });

    test('closeSession closes the tab and forgets the handle', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await bridge.closeSession(handle.sessionId);

      expect(bridge.sessions, isEmpty);
      expect(
        container.read(workspaceTabControllerProvider).tabs,
        isEmpty,
      );
      await expectLater(
        bridge.readScreen(
          clientName: _clientName,
          sessionId: handle.sessionId,
        ),
        throwsA(_bridgeException('session_not_found')),
      );
    });

    test('watchSessions emits on open and close', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final emissions = <List<AgentSessionHandle>>[];
      final subscription = bridge.watchSessions.listen(emissions.add);

      final handle = await _openSession(bridge);
      await bridge.closeSession(handle.sessionId);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [
        [handle],
        <AgentSessionHandle>[],
      ]);
      await subscription.cancel();
    });

    test('openSession throws connect_failed when the returned tab is for '
        'another host', () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
        workspaceTabControllerFactory: _ForeignTabWorkspaceController.new,
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);

      await expectLater(
        bridge.openSession(clientName: _clientName, hostId: _host.id),
        throwsA(_bridgeException('connect_failed')),
      );
      expect(bridge.sessions, isEmpty);
      expect(service.openShellCount, 0);
    });

    test('openSession reuses a failed terminal tab for the same host', () async {
      final service = _EchoSshSessionService()
        ..shellFailures.add(StateError('boom'));
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);

      await expectLater(
        bridge.openSession(clientName: _clientName, hostId: _host.id),
        throwsA(_bridgeException('connect_failed')),
      );
      final failedTab = container
          .read(workspaceTabControllerProvider)
          .tabs
          .single;
      expect(failedTab.lifecycle, SessionLifecycleState.failed);

      final handle = await bridge.openSession(
        clientName: _clientName,
        hostId: _host.id,
      );

      expect(handle.state, AgentSessionState.connected);
      final tabs = container.read(workspaceTabControllerProvider).tabs;
      expect(tabs, hasLength(1));
      expect(tabs.single.id, failedTab.id);
      expect(service.openShellCount, 2);
    });

    test('exec and sendInput throw session_not_attached after a disconnect',
        () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);

      await service.shells.single.close();
      await _drainMicrotasks();

      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'ls',
        ),
        throwsA(_bridgeException('session_not_attached')),
      );
      await expectLater(
        bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: 'y',
        ),
        throwsA(_bridgeException('session_not_attached')),
      );
      expect(service.shells.single.writes, isEmpty);
      // The handle is kept: the user may reconnect the pane.
      expect(bridge.sessions, [handle]);
    });

    test('manually closing the tab forgets the session', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);
      final tabId = container
          .read(workspaceTabControllerProvider)
          .tabs
          .single
          .id;

      container.read(workspaceTabControllerProvider.notifier).closeTab(tabId);

      expect(bridge.sessions, isEmpty);
      await expectLater(
        bridge.readScreen(
          clientName: _clientName,
          sessionId: handle.sessionId,
        ),
        throwsA(_bridgeException('session_not_found')),
      );
      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'ls',
        ),
        throwsA(_bridgeException('session_not_found')),
      );
    });

    test('closeSession is a no-op for unknown sessions', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);

      await bridge.closeSession(SessionId('missing'));

      await expectLater(
        bridge.readScreen(
          clientName: _clientName,
          sessionId: SessionId('missing'),
        ),
        throwsA(_bridgeException('session_not_found')),
      );
      await expectLater(
        bridge.sendInput(
          clientName: _clientName,
          sessionId: SessionId('missing'),
          text: 'y',
        ),
        throwsA(_bridgeException('session_not_found')),
      );
    });

    test('closeSession closes only the agent pane in a split tab', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      final tabId = container
          .read(workspaceTabControllerProvider)
          .tabs
          .single
          .id;

      controller.enableTerminalSplit(tabId);
      await _drainMicrotasks();
      final splitContent =
          container.read(workspaceTabControllerProvider).tabs.single.content
              as TerminalTabContent;
      expect(splitContent.panes, hasLength(2));

      await bridge.closeSession(handle.sessionId);

      expect(bridge.sessions, isEmpty);
      final tabs = container.read(workspaceTabControllerProvider).tabs;
      expect(tabs, hasLength(1));
      final panes =
          (tabs.single.content as TerminalTabContent).panes;
      expect(panes, hasLength(1));
      expect(panes.single.sessionId, isNot(handle.sessionId));
    });
  });
}

const _clientName = 'test-client';

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

StaticConnectionProfile _profileFor(HostSummary host) {
  return StaticConnectionProfile(
    hostId: host.id,
    hostname: host.hostname,
    port: host.port,
    username: host.username,
    authMethods: [staticPasswordAuth('secret')],
  );
}

TypeMatcher<McpBridgeException> _bridgeException(String code) {
  return isA<McpBridgeException>().having((e) => e.code, 'code', code);
}

Future<AgentSessionBridge> _bridge(ProviderContainer container) async {
  await container.read(vaultSessionControllerProvider.future);
  return container.read(agentSessionBridgeProvider);
}

Future<AgentSessionHandle> _openSession(AgentSessionBridge bridge) {
  return bridge.openSession(clientName: _clientName, hostId: _host.id);
}

ProviderContainer _container({
  required _EchoSshSessionService service,
  required _FakeSecurityModalService modal,
  bool unlocked = true,
  WorkspaceTabController Function()? workspaceTabControllerFactory,
}) {
  return ProviderContainer(
    overrides: [
      vaultSessionControllerProvider.overrideWith(
        () => _FakeVaultSessionController(
          VaultSessionState(
            vaultState: unlocked ? VaultState.unlocked : VaultState.locked,
            unlockGeneration: unlocked ? 1 : 0,
          ),
        ),
      ),
      hostSummariesProvider.overrideWith((ref, generation) async => [_host]),
      connectionProfileResolverProvider.overrideWithValue(
        StaticConnectionProfileResolver({_host.id: _profileFor(_host)}),
      ),
      sshSessionServiceProvider.overrideWithValue(service),
      workspaceRuntimeRegistryProvider.overrideWith((ref) {
        final registry = WorkspaceRuntimeRegistry();
        ref.onDispose(() {
          unawaited(registry.dispose());
        });
        return registry;
      }),
      terminalHostDisplaySettingsRepositoryProvider.overrideWithValue(
        _FakeTerminalHostDisplaySettingsRepository(),
      ),
      terminalDisplaySettingsRepositoryProvider.overrideWithValue(
        _FakeTerminalDisplaySettingsRepository(),
      ),
      securityModalServiceProvider.overrideWithValue(modal),
      agentSessionBridgeProvider.overrideWith((ref) {
        final bridge = AgentSessionBridge(
          ref: ref,
          authorization: ref.watch(mcpAuthorizationServiceProvider),
          riskPolicy: CommandRiskPolicy(),
          securityModalService: modal,
          attachTimeout: const Duration(seconds: 5),
          attachPollInterval: const Duration(milliseconds: 10),
          settleQuietPeriod: const Duration(milliseconds: 50),
          settlePollInterval: const Duration(milliseconds: 10),
        );
        ref.listen(workspaceTabControllerProvider, (_, next) {
          bridge.reconcileWithWorkspace(next);
        });
        ref.onDispose(bridge.dispose);
        return bridge;
      }),
      if (workspaceTabControllerFactory != null)
        workspaceTabControllerProvider.overrideWith(
          workspaceTabControllerFactory,
        ),
    ],
  );
}

Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 8; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Workspace controller whose openTerminal installs a tab for a different
/// host and activates it, simulating a foreign tab the bridge could adopt.
class _ForeignTabWorkspaceController extends WorkspaceTabController {
  @override
  Future<WorkspaceTabState?> openTerminal(HostSummary host) async {
    final now = DateTime.utc(2026);
    final tab = WorkspaceTabState(
      id: WorkspaceTabId('foreign-tab'),
      hostId: HostId('other-host'),
      title: 'Other Host',
      content: TerminalTabContent(
        panes: [
          TerminalPaneState(
            sessionId: SessionId('foreign-session'),
            title: 'Other Host',
            lifecycle: SessionLifecycleState.connected,
          ),
        ],
      ),
      lifecycle: SessionLifecycleState.connected,
      createdAt: now,
      lastActivityAt: now,
    );
    state = state.copyWith(
      area: WorkspaceArea.sessions,
      tabs: [...state.tabs, tab],
      activeTabId: tab.id,
    );
    return tab;
  }
}

class _FakeVaultSessionController extends VaultSessionController {
  _FakeVaultSessionController(this._state);

  final VaultSessionState _state;

  @override
  Future<VaultSessionState> build() async => _state;
}

class _EchoSshSessionService implements SshSessionService {
  final List<_EchoShellSession> shells = [];
  final List<Object> shellFailures = [];
  var openShellCount = 0;

  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    openShellCount += 1;
    if (shellFailures.isNotEmpty) {
      throw shellFailures.removeAt(0);
    }
    final shell = _EchoShellSession();
    shells.add(shell);
    return shell;
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) {
    throw UnimplementedError();
  }

  @override
  Future<void> testConnection(ConnectionProfileSnapshot profile) async {}

  @override
  Future<bool> probeShell({required SessionId sessionId}) async => true;

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
}

/// Fake shell that echoes written bytes back on stdout, so input sent by the
/// bridge appears on the terminal screen like a real shell echo would.
class _EchoShellSession implements SshShellSession {
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final Completer<void> _done = Completer<void>();
  final List<String> writes = [];

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> write(List<int> bytes) async {
    writes.add(String.fromCharCodes(bytes));
    _stdout.add(bytes);
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {}

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
    await _stdout.close();
  }
}

class _FakeSecurityModalService implements SecurityModalService {
  AgentAccessDecision accessDecision = AgentAccessDecision.allow;
  AgentCommandDecision commandDecision = AgentCommandDecision.deny;
  var accessCallCount = 0;
  var commandCallCount = 0;

  @override
  Future<AgentAccessDecision> confirmAgentAccess(AgentAccessPrompt prompt) {
    accessCallCount += 1;
    return Future.value(accessDecision);
  }

  @override
  Future<AgentCommandDecision> confirmAgentCommand(AgentCommandPrompt prompt) {
    commandCallCount += 1;
    return Future.value(commandDecision);
  }

  @override
  Future<HostKeyDecision> confirmHostKey(HostKeyPrompt prompt) {
    return Future.value(HostKeyDecision.trustOnce);
  }

  @override
  Future<CertificateTrustDecision> confirmWebDavCertificate(
    WebDavTlsCertificateDetails certificate,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ExportDecision> confirmExport(ExportPreview preview) {
    throw UnimplementedError();
  }

  @override
  Future<DestructiveDecision> confirmDestructiveAction(String title) {
    throw UnimplementedError();
  }

  @override
  Future<bool> confirmMultilinePaste(String preview) async => true;
}

class _FakeTerminalHostDisplaySettingsRepository
    implements TerminalHostDisplaySettingsRepository {
  @override
  Future<void> deleteForHost(HostId hostId) async {}

  @override
  Future<TerminalDisplaySettings?> readForHost(HostId hostId) async => null;

  @override
  Future<void> saveForHost(
    HostId hostId,
    TerminalDisplaySettings settings,
  ) async {}
}

class _FakeTerminalDisplaySettingsRepository
    implements TerminalDisplaySettingsRepository {
  @override
  Future<void> delete() async {}

  @override
  Future<TerminalDisplaySettings?> read() async => null;

  @override
  Future<void> save(TerminalDisplaySettings settings) async {}
}
