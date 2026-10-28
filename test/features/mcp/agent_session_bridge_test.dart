import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_store.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/mcp/application/agent_session_bridge.dart';
import 'package:serlink/features/mcp/application/mcp_request_context.dart';
import 'package:serlink/features/mcp/application/command_decision_guard.dart';
import 'package:serlink/features/mcp/domain/command_decision.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/features/mcp/data/command_risk_policy.dart';
import 'package:serlink/features/mcp/domain/agent_session.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
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
  group('existing workspace connections', () {
    test('hands an MCP-created connection back and attaches without another SSH login', () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final opened = await _openSession(bridge);
      await bridge.closeSession(
        opened.sessionId,
        clientName: _clientName,
        keepConnection: true,
      );
      expect(bridge.sessions, isEmpty);
      final borrowed = await bridge.attachSession(
        clientName: _clientName,
        sessionId: opened.sessionId,
      );
      expect(borrowed.borrowed, true);
      expect(service.openShellCount, 1);
      await bridge.closeSession(opened.sessionId, clientName: _clientName);
      expect(container.read(workspaceTabControllerProvider).tabs, hasLength(1));
    });
    test('locked vault rejects connection discovery and attachment', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
        unlocked: false,
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      await expectLater(
        bridge.listConnections(_clientName),
        throwsA(_bridgeException('vault_locked')),
      );
      await expectLater(
        bridge.attachSession(
          clientName: _clientName,
          sessionId: SessionId('unknown'),
        ),
        throwsA(_bridgeException('vault_locked')),
      );
    });

    test('borrowing one split pane preserves both panes on release', () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final controller = container.read(
        workspaceTabControllerProvider.notifier,
      );
      final tab = (await controller.openTerminal(_host))!;
      await _drainMicrotasks();
      controller.enableTerminalSplit(tab.id);
      await _drainMicrotasks();
      final connections = await bridge.listConnections(_clientName);
      expect(connections, hasLength(2));
      final id = SessionId(connections.last['sessionId'] as String);
      await bridge.attachSession(clientName: _clientName, sessionId: id);
      await bridge.closeSession(id, clientName: _clientName);
      final content =
          container.read(workspaceTabControllerProvider).tabs.single.content
              as TerminalTabContent;
      expect(content.panes, hasLength(2));
      expect(service.openShellCount, 2);
    });
    test(
      'lists and borrows a user connection without reconnecting or closing it',
      () async {
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService();
        final container = _container(service: service, modal: modal);
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final tab = (await container
            .read(workspaceTabControllerProvider.notifier)
            .openTerminal(_host))!;
        await _drainMicrotasks();
        final connections = await bridge.listConnections(_clientName);
        expect(connections, hasLength(1));
        expect(connections.single['attachable'], true);
        expect(connections.single.keys, isNot(contains('screen')));
        final id = (tab.content as TerminalTabContent).primaryPane.sessionId;
        final handle = await bridge.attachSession(
          clientName: _clientName,
          sessionId: id,
        );
        expect(handle.borrowed, true);
        expect(modal.accessCallCount, 1);
        expect(service.openShellCount, 1);
        await bridge.exec(
          clientName: _clientName,
          sessionId: id,
          command: 'pwd',
        );
        expect(service.shells.single.writes, ['pwd\r']);
        await expectLater(
          bridge.closeSession(id, clientName: 'other'),
          throwsA(_bridgeException('authorization_required')),
        );
        expect(bridge.sessions, hasLength(1));
        await bridge.closeSession(id, clientName: _clientName);
        expect(bridge.sessions, isEmpty);
        expect(
          container.read(workspaceTabControllerProvider).tabs.single.id,
          tab.id,
        );
        expect(
          (await bridge.listConnections(_clientName)).single['attachable'],
          true,
        );
      },
    );

    test('borrowed SFTP remains connected on release', () async {
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final tab = container
          .read(workspaceTabControllerProvider.notifier)
          .openSftp(_host);
      await _drainMicrotasks();
      final id = (tab.content as SftpTabContent).sessionId;
      final handle = await bridge.attachSession(
        clientName: _clientName,
        sessionId: id,
      );
      expect(handle.kind, AgentSessionKind.sftp);
      await bridge.closeSession(id, clientName: _clientName);
      expect(service.sftp.closed, false);
      expect(container.read(workspaceTabControllerProvider).tabs, hasLength(1));
    });

    test('cannot steal an MCP session or attach an unknown session', () async {
      final container = _container(
        service: _EchoSshSessionService(),
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);
      await expectLater(
        bridge.attachSession(clientName: 'other', sessionId: handle.sessionId),
        throwsA(_bridgeException('session_in_use')),
      );
      await expectLater(
        bridge.attachSession(
          clientName: _clientName,
          sessionId: SessionId('missing'),
        ),
        throwsA(_bridgeException('session_not_found')),
      );
      expect(bridge.sessionsFor('other'), isEmpty);
    });

    for (final action in ['deny', 'close', 'cancel']) {
      test('attachment handles $action while approval is pending', () async {
        final modal = _FakeSecurityModalService()
          ..accessGate = Completer<AgentAccessDecision>();
        final container = _container(
          service: _EchoSshSessionService(),
          modal: modal,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final tab = (await container
            .read(workspaceTabControllerProvider.notifier)
            .openTerminal(_host))!;
        await _drainMicrotasks();
        final id = (tab.content as TerminalTabContent).primaryPane.sessionId;
        final request = McpRequestContext();
        final future = request.run(
          () => bridge.attachSession(clientName: _clientName, sessionId: id),
        );
        final expectation = expectLater(
          future,
          throwsA(
            action == 'cancel'
                ? isA<McpApprovalException>()
                : _bridgeException(
                    action == 'deny'
                        ? 'authorization_denied'
                        : 'session_not_attached',
                  ),
          ),
        );
        await _drainMicrotasks();
        if (action == 'close') {
          container
              .read(workspaceTabControllerProvider.notifier)
              .closeTab(tab.id);
        }
        if (action == 'cancel') request.cancel();
        modal.accessGate!.complete(
          action == 'deny'
              ? AgentAccessDecision.deny
              : AgentAccessDecision.allow,
        );
        await expectation;
        expect(bridge.sessions, isEmpty);
        if (action != 'close') {
          expect(
            container.read(workspaceTabControllerProvider).tabs,
            hasLength(1),
          );
        }
      });
    }
  });

  group('opening connection lifetime', () {
    for (final outcome in ['cancel', 'timeout', 'revoke']) {
      test(
        '$outcome removes the pending tab and rejects late authentication',
        () async {
          final service = _EchoSshSessionService()
            ..shellGate = Completer<void>();
          final container = _container(
            service: service,
            modal: _FakeSecurityModalService(),
            attachTimeout: const Duration(milliseconds: 150),
          );
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final request = McpRequestContext();
          final future = request.run(() => _openSession(bridge));
          final expectation = expectLater(
            future,
            throwsA(
              outcome == 'cancel'
                  ? isA<McpApprovalException>()
                  : _bridgeException(
                      outcome == 'timeout'
                          ? 'connect_timeout'
                          : 'authorization_required',
                    ),
            ),
          );
          await _drainMicrotasks();
          expect(
            container.read(workspaceTabControllerProvider).tabs,
            hasLength(1),
          );
          if (outcome == 'cancel') request.cancel();
          if (outcome == 'revoke') {
            container.read(mcpAuthorizationServiceProvider).revokeAll();
            service.shellGate!.complete();
          }
          await expectation;
          expect(container.read(workspaceTabControllerProvider).tabs, isEmpty);
          expect(bridge.sessions, isEmpty);
          if (!service.shellGate!.isCompleted) service.shellGate!.complete();
          await _drainMicrotasks();
          expect(container.read(workspaceTabControllerProvider).tabs, isEmpty);
        },
      );
    }
  });
  group('MCP SFTP downloads', () {
    test(
      'uses visible authorized tab and downloads to a fresh local directory',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'mcp-download-test-',
        );
        addTearDown(() => root.delete(recursive: true));
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: _FakeSecurityModalService(),
          downloadDirectory: () async => root,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await bridge.openSession(
          clientName: _clientName,
          hostId: _host.id,
          kind: AgentSessionKind.sftp,
        );
        expect(
          container.read(workspaceTabControllerProvider).tabs.single.content,
          isA<SftpTabContent>(),
        );
        expect(
          (await bridge.listSftp(
            clientName: _clientName,
            sessionId: handle.sessionId,
            path: '/backup',
          )).single['size'],
          3,
        );
        final first = await bridge.downloadSftp(
          clientName: _clientName,
          sessionId: handle.sessionId,
          remotePath: '/backup/mail.tar.gz',
        );
        await _drainMicrotasks();
        final status = bridge.transferStatus(
          clientName: _clientName,
          sessionId: handle.sessionId,
          taskId: TransferTaskId(first['taskId'] as String),
        );
        expect(status['state'], 'completed');
        expect(status['transferredBytes'], 3);
        expect(await File(first['localPath'] as String).readAsBytes(), [
          1,
          2,
          3,
        ]);
        final second = await bridge.downloadSftp(
          clientName: _clientName,
          sessionId: handle.sessionId,
          remotePath: '/backup/mail.tar.gz',
        );
        expect(second['localPath'], isNot(first['localPath']));
        await _drainMicrotasks();
        await bridge.closeSession(handle.sessionId);
        await _drainMicrotasks();
        expect(bridge.sessions, isEmpty);
        expect(service.sftp.closed, isTrue);
      },
    );

    test(
      'rejects other clients, terminal sessions, and invalid remote paths',
      () async {
        final container = _container(
          service: _EchoSshSessionService(),
          modal: _FakeSecurityModalService(),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await bridge.openSession(
          clientName: _clientName,
          hostId: _host.id,
          kind: AgentSessionKind.sftp,
        );
        await expectLater(
          bridge.listSftp(
            clientName: 'another-client',
            sessionId: handle.sessionId,
            path: '/',
          ),
          throwsA(_bridgeException('authorization_required')),
        );
        await expectLater(
          bridge.downloadSftp(
            clientName: _clientName,
            sessionId: handle.sessionId,
            remotePath: 'relative/file',
          ),
          throwsA(_bridgeException('invalid_remote_path')),
        );
        final terminal = await _openSession(bridge);
        await expectLater(
          bridge.listSftp(
            clientName: _clientName,
            sessionId: terminal.sessionId,
            path: '/',
          ),
          throwsA(_bridgeException('not_sftp_session')),
        );
      },
    );

    test(
      'revocation during local destination lookup prevents download',
      () async {
        final root = await Directory.systemTemp.createTemp('mcp-revoke-test-');
        addTearDown(() => root.delete(recursive: true));
        final destination = Completer<Directory>();
        final container = _container(
          service: _EchoSshSessionService(),
          modal: _FakeSecurityModalService(),
          downloadDirectory: () => destination.future,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await bridge.openSession(
          clientName: _clientName,
          hostId: _host.id,
          kind: AgentSessionKind.sftp,
        );
        final download = bridge.downloadSftp(
          clientName: _clientName,
          sessionId: handle.sessionId,
          remotePath: '/backup/mail.tar.gz',
        );
        final expectation = expectLater(
          download,
          throwsA(_bridgeException('authorization_required')),
        );
        bridge.revokeGrant(handle.grantId);
        destination.complete(root);
        await expectation;
        expect(await root.list().toList(), isEmpty);
        expect(
          container.read(transferQueueControllerProvider).state.tasks,
          isEmpty,
        );
      },
    );
  });
  group('model command protection', () {
    test(
      'blocks semantically dangerous commands missed by local rules',
      () async {
        final model = _DecisionModel()..decision = CommandDecision.dangerous;
        final guard = await _enabledGuard(model);
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService();
        final container = _container(
          service: service,
          modal: modal,
          decisionGuard: guard,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        const command =
            'python3 -c "import shutil; shutil.rmtree(\'/srv/data\')"';
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: command,
          ),
          throwsA(_bridgeException('command_blocked')),
        );
        expect(model.commands, [command]);
        expect(service.shells.single.writes, isEmpty);
        expect(modal.commandCallCount, 0);
      },
    );

    for (final outcome in ['uncertain', 'unavailable']) {
      test('$outcome model result sends no terminal bytes', () async {
        final model = _DecisionModel();
        if (outcome == 'uncertain') {
          model.decision = CommandDecision.uncertain;
        }
        if (outcome == 'unavailable') {
          model.failure = StateError('fixture-key secret failure');
        }
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService();
        final container = _container(
          service: service,
          modal: modal,
          decisionGuard: await _enabledGuard(model),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'ls',
          ),
          throwsA(_bridgeException('command_blocked')),
        );
        expect(service.shells.single.writes, isEmpty);
        expect(modal.commandCallCount, 0);
      });
    }

    test(
      'MCP cancellation during validation prevents terminal input',
      () async {
        final model = _DecisionModel()..pending = Completer<CommandDecision>();
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: _FakeSecurityModalService(),
          decisionGuard: await _enabledGuard(model),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        final request = McpRequestContext();
        final command = request.run(
          () => bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'ls',
          ),
        );
        final expectation = expectLater(
          command,
          throwsA(isA<McpApprovalException>()),
        );
        while (model.commands.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        request.cancel();
        model.pending!.complete(CommandDecision.safe);
        await expectation;
        expect(service.shells.single.writes, isEmpty);
      },
    );

    test(
      'Ctrl-C interrupts immediately and cancels a pending safe result',
      () async {
        final model = _DecisionModel()..pending = Completer<CommandDecision>();
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: _FakeSecurityModalService(),
          decisionGuard: await _enabledGuard(model),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        final command = bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'ls',
        );
        final rejection = expectLater(
          command,
          throwsA(_bridgeException('command_blocked')),
        );
        await model.started.future;
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: '\x03',
        );
        expect(service.shells.single.writes, ['\x03']);
        model.pending!.complete(CommandDecision.safe);
        await rejection;
        expect(service.shells.single.writes, ['\x03']);
      },
    );

    test('local hard blocks do not call the model', () async {
      final model = _DecisionModel();
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
        decisionGuard: await _enabledGuard(model),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);
      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'mkfs.ext4 /dev/sda',
        ),
        throwsA(_bridgeException('command_blocked')),
      );
      expect(model.commands, isEmpty);
      expect(service.shells.single.writes, isEmpty);
    });

    test(
      'session-wide rule approval cannot bypass a new model judgment',
      () async {
        final model = _DecisionModel();
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService()
          ..commandDecision = AgentCommandDecision.allowSession;
        final container = _container(
          service: service,
          modal: modal,
          decisionGuard: await _enabledGuard(model),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        await bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'rm -rf /tmp/a',
        );
        model.decision = CommandDecision.dangerous;
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'rm -rf /srv/data',
          ),
          throwsA(_bridgeException('command_blocked')),
        );
        expect(model.commands, hasLength(2));
        expect(modal.commandCallCount, 1);
        expect(service.shells.single.writes, ['rm -rf /tmp/a\r']);
      },
    );

    for (final failure in ['revoked', 'closed', 'changed']) {
      test(
        '$failure while the model is pending prevents every input byte',
        () async {
          final model = _DecisionModel()
            ..pending = Completer<CommandDecision>();
          final guard = await _enabledGuard(model);
          final service = _EchoSshSessionService();
          final container = _container(
            service: service,
            modal: _FakeSecurityModalService(),
            decisionGuard: guard,
          );
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final handle = await _openSession(bridge);
          final result = bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'ls',
          );
          final expectation = expectLater(
            result,
            throwsA(
              _bridgeException(
                failure == 'revoked'
                    ? 'authorization_required'
                    : failure == 'closed'
                    ? 'session_not_found'
                    : 'command_blocked',
              ),
            ),
          );
          await model.started.future;
          if (failure == 'revoked') {
            bridge.revokeGrant(handle.grantId);
          }
          if (failure == 'closed') {
            await bridge.closeSession(handle.sessionId);
          }
          if (failure == 'changed') {
            await guard.saveSettings(enabled: false, model: 'jev-1.13.0');
          }
          model.pending!.complete(CommandDecision.safe);
          await expectation;
          expect(service.shells.single.writes, isEmpty);
        },
      );
    }

    test(
      'fragmented input and history keys cannot bypass model checks',
      () async {
        final model = _DecisionModel();
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: _FakeSecurityModalService(),
          decisionGuard: await _enabledGuard(model),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        for (final text in ['rm ', '-rf /', '\r', '\x1b[A\r']) {
          await expectLater(
            bridge.sendInput(
              clientName: _clientName,
              sessionId: handle.sessionId,
              text: text,
            ),
            throwsA(_bridgeException('command_blocked')),
          );
        }
        expect(service.shells.single.writes, isEmpty);
        expect(model.commands, isEmpty);
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: '\x03',
        );
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: 'ls\r',
        );
        expect(model.commands, ['ls\r']);
        expect(service.shells.single.writes, ['\x03', 'ls\r']);
      },
    );

    test(
      'enabling protection requires clearing previously unsubmitted input',
      () async {
        final model = _DecisionModel();
        final guard = CommandDecisionGuard(
          secrets: InMemorySecretStore(),
          model: model,
        );
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: _FakeSecurityModalService(),
          decisionGuard: guard,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: 'prefix ',
        );
        await guard.saveSettings(
          enabled: true,
          model: 'jev-1.13.0',
          apiKey: 'fixture-key',
        );
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'ls',
          ),
          throwsA(_bridgeException('command_blocked')),
        );
        expect(service.shells.single.writes, ['prefix ']);
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: '\x03',
        );
        await bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'ls',
        );
        expect(service.shells.single.writes, ['prefix ', '\x03', 'ls\r']);
      },
    );

    test('commands in one session are serialized across model waits', () async {
      final model = _DecisionModel()..pending = Completer<CommandDecision>();
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
        decisionGuard: await _enabledGuard(model),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);
      final first = bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'ls',
      );
      await model.started.future;
      final second = bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'pwd',
      );
      await _drainMicrotasks();
      expect(model.commands, ['ls']);
      final pending = model.pending!;
      model.pending = null;
      pending.complete(CommandDecision.safe);
      await Future.wait([first, second]);
      expect(model.commands, ['ls', 'pwd']);
      expect(service.shells.single.writes, ['ls\r', 'pwd\r']);
    });
  });

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

      expect(bridge.listHosts, throwsA(_bridgeException('vault_locked')));
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

    test(
      'openSession throws authorization_denied when the user denies',
      () async {
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
      },
    );

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

    test(
      'revokeGrant makes further calls fail with authorization_required',
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
      },
    );

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
      expect(container.read(workspaceTabControllerProvider).tabs, isEmpty);
      await expectLater(
        bridge.readScreen(clientName: _clientName, sessionId: handle.sessionId),
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

    test(
      'failed MCP open leaves no orphan tab before a later explicit retry',
      () async {
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
        expect(container.read(workspaceTabControllerProvider).tabs, isEmpty);

        final handle = await bridge.openSession(
          clientName: _clientName,
          hostId: _host.id,
        );

        expect(handle.state, AgentSessionState.connected);
        final tabs = container.read(workspaceTabControllerProvider).tabs;
        expect(tabs, hasLength(1));
        expect(service.openShellCount, 2);
      },
    );

    test(
      'exec and sendInput throw session_not_attached after a disconnect',
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
      },
    );

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
        bridge.readScreen(clientName: _clientName, sessionId: handle.sessionId),
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
      final panes = (tabs.single.content as TerminalTabContent).panes;
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
  CommandDecisionGuard? decisionGuard,
  WorkspaceTabController Function()? workspaceTabControllerFactory,
  Future<Directory> Function()? downloadDirectory,
  Duration attachTimeout = const Duration(seconds: 5),
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
          decisionGuard: decisionGuard,
          downloadDirectory: downloadDirectory,
          securityModalService: modal,
          attachTimeout: attachTimeout,
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
  Future<WorkspaceTabState?> openTerminal(
    HostSummary host, {
    bool reuseFailedTab = true,
  }) async {
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
  final sftp = _MemorySftpConnection();
  final List<_EchoShellSession> shells = [];
  final List<Object> shellFailures = [];
  var openShellCount = 0;
  Completer<void>? shellGate;

  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    openShellCount += 1;
    await shellGate?.future;
    if (shellFailures.isNotEmpty) {
      throw shellFailures.removeAt(0);
    }
    final shell = _EchoShellSession();
    shells.add(shell);
    return shell;
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) async =>
      sftp;

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

class _MemorySftpConnection implements SftpConnection {
  final _done = Completer<void>();
  bool closed = false;
  @override
  Future<void> get done => _done.future;
  @override
  Future<List<SftpEntry>> list(String path) async => [
    SftpEntry(
      name: 'mail.tar.gz',
      path: '$path/mail.tar.gz',
      type: SftpEntryType.file,
      size: 3,
    ),
  ];
  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) async* {
    await File(localPath).writeAsBytes([1, 2, 3]);
    yield TransferProgress(
      taskId: taskId,
      state: TransferState.completed,
      transferredBytes: 3,
      totalBytes: 3,
    );
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  Completer<AgentAccessDecision>? accessGate;

  @override
  Future<AgentAccessDecision> confirmAgentAccess(AgentAccessPrompt prompt) {
    accessCallCount += 1;
    return accessGate?.future ?? Future.value(accessDecision);
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

Future<CommandDecisionGuard> _enabledGuard(_DecisionModel model) async {
  final guard = CommandDecisionGuard(
    secrets: InMemorySecretStore(),
    model: model,
  );
  await guard.saveSettings(
    enabled: true,
    model: 'jev-1.13.0',
    apiKey: 'fixture-key',
  );
  return guard;
}

class _DecisionModel implements CommandDecisionModel {
  Object? failure;
  CommandDecision decision = CommandDecision.safe;
  Completer<CommandDecision>? pending;
  final started = Completer<void>();
  final List<String> commands = [];
  @override
  Future<CommandDecision> assess({
    required String command,
    required String model,
    required String apiKey,
  }) async {
    commands.add(command);
    if (failure != null) throw failure!;
    if (!started.isCompleted) started.complete();
    if (pending != null) return pending!.future;
    return decision;
  }
}
