import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/hosts/application/host_store.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/mcp/application/agent_session_bridge.dart';
import 'package:serlink/features/mcp/application/mcp_command_approval.dart';
import 'package:serlink/features/mcp/application/mcp_request_context.dart';
import 'package:serlink/features/mcp/application/command_decision_guard.dart';
import 'package:serlink/features/mcp/domain/command_decision.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/secret_store.dart';
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
  group('project task approval', () {
    test(
      'one approval covers known project writes and reads, not dangerous input',
      () async {
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService()
          ..commandDecision = AgentCommandDecision.allowTask;
        final container = _container(
          service: service,
          modal: modal,
          bypass: false,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final session = await _openSession(bridge);
        Future<Map<String, Object?>> run(String command) => bridge.startCommand(
          clientName: _clientName,
          sessionId: session.sessionId,
          command: command,
          cwd: '/srv/app',
          wait: Duration.zero,
        );
        await run('cp src/a.txt out/a.txt');
        expect(modal.lastCommandPrompt!.taskDirectory, '/srv/app');
        expect(modal.lastCommandPrompt!.allowSession, isFalse);
        modal.commandDecision = AgentCommandDecision.deny;
        for (final command in [
          'git status --short',
          'git log --oneline',
          r"printf 'hello\n' | tee out/a.txt",
          "printf 'rm is data' > out/note.txt",
          'mkdir -p out/new',
        ]) {
          await run(command);
        }
        expect(modal.commandCallCount, 1);
        expect(service.commands, hasLength(6));
        for (final command in [
          'rm out/a.txt',
          'mv out/a.txt out/b.txt',
          'git reset --hard',
          'python3 -c "print(1)"',
          'printf x > /srv/other/a.txt',
          'printf x > .env',
          'cp /etc/passwd out/a.txt',
        ]) {
          await expectLater(
            run(command),
            throwsA(_bridgeException('command_denied')),
          );
          expect(modal.lastCommandPrompt!.taskDirectory, isNull);
        }
        expect(service.commands, hasLength(6));
      },
    );

    for (final change in [
      'mode',
      'vault',
      'model',
      'cwd',
      'session',
      'terminal',
    ]) {
      test('$change cannot inherit a project task permission', () async {
        final model = _DecisionModel();
        final guard = await _enabledGuard(model);
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService()
          ..commandDecision = AgentCommandDecision.allowTask;
        final container = _container(
          service: service,
          modal: modal,
          bypass: false,
          decisionGuard: guard,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        var session = await _openSession(bridge);
        await bridge.startCommand(
          clientName: _clientName,
          sessionId: session.sessionId,
          command: 'printf first > out.txt',
          cwd: '/srv/app',
          wait: Duration.zero,
        );
        var cwd = '/srv/app';
        switch (change) {
          case 'mode':
            await container.read(mcpCommandApprovalProvider).saveBypass(false);
          case 'vault':
            (container.read(
              vaultSessionControllerProvider.notifier,
            ) as _FakeVaultSessionController).setSnapshot(
              const VaultSessionState(
                vaultState: VaultState.unlocked,
                unlockGeneration: 2,
              ),
            );
          case 'model':
            await guard.saveSettings(enabled: true, model: 'jev-latest');
          case 'cwd':
            cwd = '/srv/other';
          case 'session':
            session = await _openSession(bridge);
          case 'terminal':
            break;
        }
        modal.commandDecision = AgentCommandDecision.deny;
        await expectLater(
          change == 'terminal'
              ? bridge.exec(
                  clientName: _clientName,
                  sessionId: session.sessionId,
                  command: 'pwd',
                )
              : bridge.startCommand(
                  clientName: _clientName,
                  sessionId: session.sessionId,
                  command: 'printf next > next.txt',
                  cwd: cwd,
                  wait: Duration.zero,
                ),
          throwsA(_bridgeException('command_denied')),
        );
        expect(modal.commandCallCount, 2);
        expect(service.commands, hasLength(1));
      });
    }

    test('project permission still requires a fresh model judgment', () async {
      final model = _DecisionModel();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowTask;
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: modal,
        bypass: false,
        decisionGuard: await _enabledGuard(model),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final session = await _openSession(bridge);
      await bridge.startCommand(
        clientName: _clientName,
        sessionId: session.sessionId,
        command: 'printf first > out.txt',
        cwd: '/srv/app',
        wait: Duration.zero,
      );
      model.decision = CommandDecision.dangerous;
      await expectLater(
        bridge.startCommand(
          clientName: _clientName,
          sessionId: session.sessionId,
          command: 'printf next > next.txt',
          cwd: '/srv/app',
          wait: Duration.zero,
        ),
        throwsA(_bridgeException('command_blocked')),
      );
      expect(model.commands, hasLength(2));
      expect(modal.commandCallCount, 1);
      expect(service.commands, hasLength(1));
    });

    test(
      'interrupted project approval cannot seed a task permission',
      () async {
        final modal = _FakeSecurityModalService()
          ..commandGate = Completer<AgentCommandDecision>();
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: modal,
          bypass: false,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final session = await _openSession(bridge);
        Future<Map<String, Object?>> run() => bridge.startCommand(
          clientName: _clientName,
          sessionId: session.sessionId,
          command: 'printf first > out.txt',
          cwd: '/srv/app',
          wait: Duration.zero,
        );
        final result = run();
        final rejected = expectLater(
          result,
          throwsA(_bridgeException('command_blocked')),
        );
        await modal.commandStarted.future;
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: session.sessionId,
          text: '\x03',
        );
        modal.commandGate!.complete(AgentCommandDecision.allowTask);
        await rejected;
        modal.commandGate = null;
        modal.commandDecision = AgentCommandDecision.deny;
        await expectLater(run(), throwsA(_bridgeException('command_denied')));
        expect(modal.commandCallCount, 2);
        expect(service.commands, isEmpty);
      },
    );
  });

  group('retained command output', () {
    test('managed script is intact, stays running through silence and can be polled', () async {
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowOnce;
      final container = _container(
        service: service,
        modal: modal,
        bypass: false,
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final session = await _openSession(bridge);
      final source = '#${'x' * 200000}\n\techo done\n';
      final initial = await bridge.startCommand(
        clientName: _clientName,
        sessionId: session.sessionId,
        command: source,
        cwd: '/srv/app',
        wait: Duration.zero,
      );
      final id = initial['commandId'] as String;
      expect(
        bridge
            .listCommands(clientName: _clientName, sessionId: session.sessionId)
            .single['commandId'],
        id,
      );
      await expectLater(
        bridge.commandStatus(
          clientName: 'other-client',
          sessionId: session.sessionId,
          commandId: id,
        ),
        throwsA(_bridgeException('authorization_required')),
      );
      var sourceCursor = 0;
      final recovered = StringBuffer();
      do {
        final sourcePage = await bridge.commandStatus(
          clientName: _clientName,
          sessionId: session.sessionId,
          commandId: id,
          cursor: sourceCursor,
          commandSource: true,
        );
        recovered.write(sourcePage['output']);
        sourceCursor = sourcePage['nextCursor'] as int;
        if (sourcePage['hasMore'] == false) break;
      } while (true);
      expect(recovered.toString(), source);
      expect(initial['state'], 'running');
      expect(initial['finished'], isFalse);
      expect(modal.lastCommandPrompt!.isolatedShell, isTrue);
      expect(modal.lastCommandPrompt!.workingDirectory, '/srv/app');
      for (var i = 0; i < 100 && !service.commands.single.inputClosed; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(utf8.decode(service.commands.single.bytes), source);
      expect(service.commandCwd, '/srv/app');
      final waiting = await bridge.commandStatus(
        clientName: _clientName,
        sessionId: session.sessionId,
        commandId: id,
        wait: const Duration(milliseconds: 5),
      );
      expect(waiting['finished'], isFalse);
      final text = 'very-long-context-中文🙂\n' * 7000;
      service.commands.single.out.add(utf8.encode(text));
      await service.commands.single.finish(9);
      var cursor = 0;
      final all = StringBuffer();
      Map<String, Object?> page;
      do {
        page = await bridge.commandStatus(
          clientName: _clientName,
          sessionId: session.sessionId,
          commandId: id,
          cursor: cursor,
          maxChars: 4097,
          wait: const Duration(milliseconds: 100),
        );
        all.write(page['output']);
        cursor = page['nextCursor'] as int;
      } while (page['finished'] != true || page['hasMore'] == true);
      expect(all.toString(), text);
      expect(page['exitCode'], 9);
      await bridge.releaseCommand(
        clientName: _clientName,
        sessionId: session.sessionId,
        commandId: id,
      );
      await expectLater(
        bridge.commandStatus(
          clientName: _clientName,
          sessionId: session.sessionId,
          commandId: id,
        ),
        throwsA(_bridgeException('command_not_found')),
      );
    });

    for (final change in ['close', 'revoke', 'vault', 'server']) {
      test(
        '$change invalidates retained output and closes the managed channel',
        () async {
          final service = _EchoSshSessionService();
          final container = _container(
            service: service,
            modal: _FakeSecurityModalService(),
          );
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final session = await _openSession(bridge);
          final initial = await bridge.startCommand(
            clientName: _clientName,
            sessionId: session.sessionId,
            command: 'echo hello',
            wait: Duration.zero,
          );
          final id = initial['commandId'] as String;
          switch (change) {
            case 'close':
              await bridge.closeSession(session.sessionId);
            case 'revoke':
              await bridge.revokeGrant(session.grantId);
            case 'vault':
              (container.read(
                vaultSessionControllerProvider.notifier,
              ) as _FakeVaultSessionController).setSnapshot(
                const VaultSessionState(
                  vaultState: VaultState.locked,
                  unlockGeneration: 2,
                ),
              );
            case 'server':
              bridge.cancelAllCommandJobs();
          }
          for (var i = 0; i < 100 && !service.commands.single.closed; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 2));
          }
          expect(service.commands.single.closed, isTrue);
          await expectLater(
            bridge.commandStatus(
              clientName: _clientName,
              sessionId: session.sessionId,
              commandId: id,
            ),
            throwsA(isA<McpBridgeException>()),
          );
        },
      );
    }

    test(
      'normal terminal output is paginated beyond the 100-line snapshot',
      () async {
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: _FakeSecurityModalService(),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final session = await _openSession(bridge);
        final initial = await bridge.execWithOutput(
          clientName: _clientName,
          sessionId: session.sessionId,
          command: 'echo start',
        );
        var cursor = initial['nextCursor'] as int;
        final text = List.generate(12000, (i) => 'context-$i\r\n').join();
        await service.shells.single.write(utf8.encode(text));
        final all = StringBuffer();
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (all.length < text.length) {
          if (DateTime.now().isAfter(deadline)) {
            fail('output capture did not catch up');
          }
          final page = await bridge.readOutput(
            clientName: _clientName,
            sessionId: session.sessionId,
            cursor: cursor,
            maxChars: 4096,
            wait: const Duration(milliseconds: 100),
          );
          all.write(page['output']);
          cursor = page['nextCursor'] as int;
        }
        expect(all.toString(), text);
        expect(initial['completionKnown'], isFalse);
      },
    );

    test('late channel open after Ctrl-C sends no script bytes', () async {
      final service = _EchoSshSessionService()
        ..commandOpenGate = Completer<void>();
      final container = _container(
        service: service,
        modal: _FakeSecurityModalService(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final session = await _openSession(bridge);
      final future = bridge.startCommand(
        clientName: _clientName,
        sessionId: session.sessionId,
        command: 'echo no',
        wait: Duration.zero,
      );
      final rejection = expectLater(
        future,
        throwsA(_bridgeException('command_blocked')),
      );
      while (service.commands.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await bridge.sendInput(
        clientName: _clientName,
        sessionId: session.sessionId,
        text: '\x03',
      );
      service.commandOpenGate!.complete();
      await rejection;
      expect(service.commands.single.bytes, isEmpty);
      expect(service.commands.single.closed, isTrue);
    });
  });

  group('command approval modes', () {
    for (final changeModel in [false, true]) {
      test(
        'configuration change during final storage read sends no bytes (model=$changeModel)',
        () async {
          final secrets = _PausingApprovalStore();
          final guard = CommandDecisionGuard(
            secrets: InMemorySecretStore(),
            model: _DecisionModel(),
          );
          final service = _EchoSshSessionService();
          final container = _container(
            service: service,
            modal: _FakeSecurityModalService(),
            secrets: secrets,
            decisionGuard: guard,
          );
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final handle = await _openSession(bridge);
          final result = bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'pwd',
          );
          final rejection = expectLater(
            result,
            throwsA(_bridgeException('command_blocked')),
          );
          await secrets.started.future;
          if (changeModel) {
            await guard.saveSettings(
              enabled: true,
              model: 'jev-latest',
              apiKey: 'fixture-key',
              dataSharingConsent: true,
            );
          } else {
            await container.read(mcpCommandApprovalProvider).saveBypass(false);
          }
          secrets.resume.complete();
          await rejection;
          expect(service.shells.single.writes, isEmpty);
        },
      );
    }
    test('session approval covers only the displayed command family in that session', () async {
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowSession;
      final container = _container(
        service: service,
        modal: modal,
        bypass: false,
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final first = await _openSession(bridge);
      await bridge.exec(
        clientName: _clientName,
        sessionId: first.sessionId,
        command: 'git status',
      );
      expect(modal.lastCommandPrompt!.sessionCommandPrefix, 'git status …');
      modal.commandDecision = AgentCommandDecision.deny;
      await bridge.exec(
        clientName: _clientName,
        sessionId: first.sessionId,
        command: 'git status --short',
      );
      expect(modal.commandCallCount, 1);
      for (final command in [
        'git log',
        'git status; rm file',
        'git status > output',
      ]) {
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: first.sessionId,
            command: command,
          ),
          throwsA(_bridgeException('command_denied')),
        );
      }
      expect(modal.commandCallCount, 4);
      final second = await _openSession(bridge);
      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: second.sessionId,
          command: 'git status',
        ),
        throwsA(_bridgeException('command_denied')),
      );
      expect(service.shells.last.writes, isEmpty);
    });

    for (final change in ['mode', 'vault', 'model']) {
      test('$change invalidates remembered command scopes', () async {
        final model = _DecisionModel();
        final guard = await _enabledGuard(model);
        final modal = _FakeSecurityModalService()
          ..commandDecision = AgentCommandDecision.allowSession;
        final container = _container(
          service: _EchoSshSessionService(),
          modal: modal,
          bypass: false,
          decisionGuard: guard,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        await bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'git status',
        );
        switch (change) {
          case 'mode':
            await container.read(mcpCommandApprovalProvider).saveBypass(false);
          case 'model':
            await guard.saveSettings(enabled: true, model: 'jev-latest');
          case 'vault':
            (container.read(
              vaultSessionControllerProvider.notifier,
            ) as _FakeVaultSessionController).setSnapshot(
              const VaultSessionState(
                vaultState: VaultState.unlocked,
                unlockGeneration: 2,
              ),
            );
        }
        modal.commandDecision = AgentCommandDecision.deny;
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'git status -s',
          ),
          throwsA(_bridgeException('command_denied')),
        );
        expect(modal.commandCallCount, 2);
      });
    }

    test('session permission never skips a fresh model assessment', () async {
      final model = _DecisionModel();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowSession;
      final service = _EchoSshSessionService();
      final container = _container(
        service: service,
        modal: modal,
        bypass: false,
        decisionGuard: await _enabledGuard(model),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final handle = await _openSession(bridge);
      await bridge.exec(
        clientName: _clientName,
        sessionId: handle.sessionId,
        command: 'git status',
      );
      model.decision = CommandDecision.dangerous;
      await expectLater(
        bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'git status -s',
        ),
        throwsA(_bridgeException('command_blocked')),
      );
      expect(model.commands, ['git status', 'git status -s']);
      expect(service.shells.single.writes, ['git status\r']);
      expect(modal.commandCallCount, 1);
    });

    test(
      'interrupted session approval cannot seed a remembered permission',
      () async {
        final modal = _FakeSecurityModalService()
          ..commandGate = Completer<AgentCommandDecision>();
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: modal,
          bypass: false,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        final result = bridge.exec(
          clientName: _clientName,
          sessionId: handle.sessionId,
          command: 'git status',
        );
        final rejection = expectLater(
          result,
          throwsA(_bridgeException('command_blocked')),
        );
        await modal.commandStarted.future;
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: '\x03',
        );
        modal.commandGate!.complete(AgentCommandDecision.allowSession);
        await rejection;
        modal.commandGate = null;
        modal.commandDecision = AgentCommandDecision.deny;
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'git status -s',
          ),
          throwsA(_bridgeException('command_denied')),
        );
        expect(modal.commandCallCount, 2);
        expect(service.shells.single.writes, ['\x03']);
      },
    );

    for (final command in [
      "rg 'rm|mkfs|delete' README.md",
      'git checkout -b feature/review',
      'git log --grep=rm',
    ]) {
      test(
        'bypass does not prompt for literal read arguments: $command',
        () async {
          final modal = _FakeSecurityModalService();
          final service = _EchoSshSessionService();
          final container = _container(service: service, modal: modal);
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final handle = await _openSession(bridge);
          await bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: command,
          );
          expect(modal.commandCallCount, 0);
          expect(service.shells.single.writes, ['$command\r']);
        },
      );
    }

    for (final bypass in [false, true]) {
      test(
        'ordinary command ${bypass ? 'bypasses' : 'waits for'} approval',
        () async {
          final service = _EchoSshSessionService();
          final modal = _FakeSecurityModalService()
            ..commandGate = Completer<AgentCommandDecision>();
          final container = _container(
            service: service,
            modal: modal,
            bypass: bypass,
          );
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final handle = await _openSession(bridge);
          final result = bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'pwd',
          );
          if (!bypass) {
            await modal.commandStarted.future;
            expect(service.shells.single.writes, isEmpty);
            expect(modal.lastCommandPrompt!.allowSession, isTrue);
            modal.commandGate!.complete(AgentCommandDecision.allowOnce);
          }
          await result;
          expect(modal.accessCallCount, 1);
          expect(modal.commandCallCount, bypass ? 0 : 1);
          expect(service.shells.single.writes, ['pwd\r']);
        },
      );
    }

    for (final command in [
      'rm report.csv',
      'find . -delete',
      'git reset --hard HEAD',
      'pwd\nrm report.csv',
    ]) {
      for (final raw in [false, true]) {
        test('bypass waits for approval of $command (raw=$raw)', () async {
          final service = _EchoSshSessionService();
          final modal = _FakeSecurityModalService()
            ..commandGate = Completer<AgentCommandDecision>();
          final container = _container(service: service, modal: modal);
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final handle = await _openSession(bridge);
          final Future<Object?> result = raw
              ? bridge.sendInput(
                  clientName: _clientName,
                  sessionId: handle.sessionId,
                  text: '$command\r',
                )
              : bridge.exec(
                  clientName: _clientName,
                  sessionId: handle.sessionId,
                  command: command,
                );
          await modal.commandStarted.future;
          expect(service.shells.single.writes, isEmpty);
          expect(modal.lastCommandPrompt!.allowSession, isFalse);
          modal.commandGate!.complete(AgentCommandDecision.allowOnce);
          await result;
          expect(service.shells.single.writes, ['$command\r']);
          modal.commandGate = null;
          modal.commandDecision = AgentCommandDecision.deny;
          await expectLater(
            bridge.exec(
              clientName: _clientName,
              sessionId: handle.sessionId,
              command: command,
            ),
            throwsA(_bridgeException('command_denied')),
          );
          expect(modal.commandCallCount, 2);
          expect(service.shells.single.writes, ['$command\r']);
        });
      }
    }

    for (final change in [
      'mode',
      'vault',
      'reunlock',
      'revoke',
      'close',
      'cancel',
      'timeout',
      'interrupt',
    ]) {
      test('$change during approval cannot send a command', () async {
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService()
          ..commandGate = Completer<AgentCommandDecision>();
        final container = _container(service: service, modal: modal);
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        final context = McpRequestContext();
        final result = context.run(
          () => bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'rm report.csv',
          ),
        );
        final expectedCode = switch (change) {
          'revoke' => 'authorization_required',
          'close' => 'session_not_found',
          'vault' || 'reunlock' => 'vault_locked',
          _ => 'command_blocked',
        };
        final expectation = expectLater(
          result,
          throwsA(
            change == 'cancel' || change == 'timeout'
                ? isA<McpApprovalException>()
                : _bridgeException(expectedCode),
          ),
        );
        await modal.commandStarted.future;
        switch (change) {
          case 'mode':
            await container.read(mcpCommandApprovalProvider).saveBypass(false);
          case 'revoke':
            await bridge.revokeGrant(handle.grantId);
          case 'vault':
          case 'reunlock':
            final vault = container.read(
              vaultSessionControllerProvider.notifier,
            ) as _FakeVaultSessionController;
            vault.setSnapshot(
              VaultSessionState(
                vaultState: change == 'vault'
                    ? VaultState.locked
                    : VaultState.unlocked,
                unlockGeneration: 2,
              ),
            );
          case 'close':
            await bridge.closeSession(handle.sessionId);
          case 'cancel':
            context.cancel();
          case 'timeout':
            modal.commandGate!.completeError(
              const McpApprovalException('approval_timeout'),
            );
          case 'interrupt':
            await bridge.sendInput(
              clientName: _clientName,
              sessionId: handle.sessionId,
              text: '\x03',
            );
        }
        if (change != 'timeout') {
          modal.commandGate!.complete(AgentCommandDecision.allowOnce);
        }
        await expectation;
        expect(
          service.shells.single.writes,
          change == 'interrupt' ? ['\x03'] : isEmpty,
        );
      });
    }

    test(
      'legacy session-wide decision cannot approve a dangerous command',
      () async {
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService()
          ..commandDecision = AgentCommandDecision.allowSession;
        final container = _container(service: service, modal: modal);
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        await expectLater(
          bridge.exec(
            clientName: _clientName,
            sessionId: handle.sessionId,
            command: 'rm report.csv',
          ),
          throwsA(_bridgeException('command_denied')),
        );
        expect(service.shells.single.writes, isEmpty);
      },
    );

    test(
      'bypass cannot submit fragments, history or standalone Enter',
      () async {
        final service = _EchoSshSessionService();
        final container = _container(
          service: service,
          modal: _FakeSecurityModalService(),
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);
        for (final text in [
          'r',
          'm report.csv',
          '\r',
          '\x1b[A\r',
          'ls\nrm ',
          '\x04',
          'r\t report.csv\r',
        ]) {
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
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: '\x03',
        );
        await bridge.sendInput(
          clientName: _clientName,
          sessionId: handle.sessionId,
          text: 'pwd\r',
        );
        expect(service.shells.single.writes, ['\x03', 'pwd\r']);
      },
    );
  });

  group('MCP discovery consent', () {
    for (final locked in [true, false]) {
      test(
        'vault ${locked ? 'locking' : 'generation change'} withdraws pending discovery',
        () async {
          final modal = _FakeSecurityModalService()
            ..accessGate = Completer<AgentAccessDecision>();
          final hosts = _MetadataHosts();
          final container = _container(
            service: _EchoSshSessionService(),
            modal: modal,
            hosts: hosts,
          );
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final request = McpRequestContext();
          final future = request.run(
            () => bridge.describeHosts(clientName: _clientName),
          );
          final expectation = expectLater(
            future,
            throwsA(_bridgeException('vault_locked')),
          );
          await _drainMicrotasks();
          final vault = container.read(
            vaultSessionControllerProvider.notifier,
          ) as _FakeVaultSessionController;
          vault.setSnapshot(
            VaultSessionState(
              vaultState: locked ? VaultState.locked : VaultState.unlocked,
              unlockGeneration: 2,
            ),
          );
          modal.accessGate!.complete(AgentAccessDecision.allow);
          await expectation;
          expect(hosts.readCount, 0);
          expect(
            container.read(mcpAuthorizationServiceProvider).grants,
            isEmpty,
          );
        },
      );
    }

    test(
      'denial returns no hosts or connections and never reads host records',
      () async {
        final modal = _FakeSecurityModalService()
          ..accessDecision = AgentAccessDecision.deny;
        final hosts = _MetadataHosts();
        final container = _container(
          service: _EchoSshSessionService(),
          modal: modal,
          hosts: hosts,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        await expectLater(
          bridge.describeHosts(clientName: _clientName),
          throwsA(_bridgeException('authorization_denied')),
        );
        await expectLater(
          bridge.listConnections(_clientName),
          throwsA(_bridgeException('authorization_denied')),
        );
        expect(hosts.readCount, 0);
        expect(container.read(mcpAuthorizationServiceProvider).grants, isEmpty);
      },
    );

    test('remembered client consent respects current privacy and excludes commands', () async {
      final modal = _FakeSecurityModalService();
      final container = _container(
        service: _EchoSshSessionService(),
        modal: modal,
        hosts: _MetadataHosts(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      final ordinary = await bridge.describeHosts(clientName: _clientName);
      expect(ordinary.single['hostname'], _host.hostname);
      expect(ordinary.single.containsKey('startupCommands'), false);
      expect(ordinary.single.containsKey('identityIds'), false);
      expect(modal.lastAccessPrompt?.discoveryStrict, false);
      await bridge.describeHosts(clientName: _clientName);
      expect(modal.accessCallCount, 1);
      await bridge.describeHosts(clientName: 'another-client');
      expect(modal.accessCallCount, 2);
      await container.read(mcpHostVisibilityProvider).saveStrict(true);
      final strict = await bridge.describeHosts(clientName: _clientName);
      expect(strict.single.keys, unorderedEquals(['id', 'displayName']));
      expect(modal.accessCallCount, 2);
      expect(modal.lastAccessPrompt?.rememberClient, true);
    });

    test('changing privacy updates metadata without reauthorizing a remembered client', () async {
      final modal = _FakeSecurityModalService();
      final container = _container(
        service: _EchoSshSessionService(),
        modal: modal,
        hosts: _MetadataHosts(),
      );
      addTearDown(container.dispose);
      final bridge = await _bridge(container);
      await container.read(mcpHostVisibilityProvider).saveStrict(true);
      await bridge.describeHosts(clientName: _clientName);
      await container.read(mcpHostVisibilityProvider).saveStrict(false);
      modal.accessDecision = AgentAccessDecision.deny;
      final hosts = await bridge.describeHosts(clientName: _clientName);
      expect(hosts.single['hostname'], _host.hostname);
      expect(modal.accessCallCount, 1);
      expect(modal.lastAccessPrompt?.discoveryStrict, true);
    });

    for (final change in ['revoke', 'privacy']) {
      test('$change during a metadata read prevents a late response', () async {
        final hosts = _MetadataHosts()..gate = Completer<List<HostConfig>>();
        final container = _container(
          service: _EchoSshSessionService(),
          modal: _FakeSecurityModalService(),
          hosts: hosts,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final future = bridge.describeHosts(clientName: _clientName);
        final expectation = expectLater(
          future,
          throwsA(_bridgeException('authorization_required')),
        );
        await _drainMicrotasks();
        if (change == 'revoke') {
          container.read(mcpAuthorizationServiceProvider).revokeAll();
        } else {
          await container.read(mcpHostVisibilityProvider).saveStrict(true);
        }
        hosts.gate!.complete([_metadataHost]);
        await expectation;
      });
    }
  });

  group('existing workspace connections', () {
    test('hands an MCP-created connection back and attaches without another SSH login', () async {
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService();
      final container = _container(service: service, modal: modal);
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
      expect(modal.accessCallCount, 1);
      expect(modal.lastAccessPrompt?.rememberClient, true);
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
        expect(modal.lastAccessPrompt?.rememberClient, true);
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
  group('MCP SFTP uploads', () {
    late Directory directory;
    late File file;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('serlink-upload-test-');
      file = File('${directory.path}/upload.bin');
      await file.writeAsBytes([0, 1, 127, 255]);
    });
    tearDown(() => directory.delete(recursive: true));

    test(
      'approves an upload and exposes completion to only its owner',
      () async {
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService();
        final container = _container(service: service, modal: modal);
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await bridge.openSession(
          clientName: _clientName,
          hostId: _host.id,
          kind: AgentSessionKind.sftp,
        );
        final result = await McpRequestContext().run(
          () => bridge.uploadSftp(
            clientName: _clientName,
            sessionId: handle.sessionId,
            localPath: file.path,
            remotePath: '/srv/upload.bin',
          ),
        );
        expect(modal.uploadCallCount, 1);
        expect(
          modal.lastUploadPrompt!.localPath,
          await file.resolveSymbolicLinks(),
        );
        expect(modal.lastUploadPrompt!.remotePath, '/srv/upload.bin');
        expect(modal.lastUploadPrompt!.sizeBytes, 4);
        final id = TransferTaskId(result['taskId'] as String);
        await _drainMicrotasks();
        expect(service.sftp.uploads.single.bytes, [0, 1, 127, 255]);
        final status = bridge.transferStatus(
          clientName: _clientName,
          sessionId: handle.sessionId,
          taskId: id,
        );
        expect(status['state'], 'completed');
        expect(status['transferredBytes'], 4);
        expect(
          () => bridge.transferStatus(
            clientName: 'other',
            sessionId: handle.sessionId,
            taskId: id,
          ),
          throwsA(_bridgeException('authorization_required')),
        );
        modal.uploadDecision = AgentAccessDecision.deny;
        await expectLater(
          bridge.uploadSftp(
            clientName: _clientName,
            sessionId: handle.sessionId,
            localPath: file.path,
            remotePath: '/srv/other.bin',
          ),
          throwsA(_bridgeException('upload_denied')),
        );
        expect(modal.uploadCallCount, 2);
        expect(service.sftp.uploads, hasLength(1));
      },
    );

    for (final change in [
      'deny',
      'revoke',
      'close',
      'vault',
      'reunlock',
      'cancel',
      'source',
    ]) {
      test('$change while approving never queues an upload', () async {
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService()
          ..uploadApprovalGate = Completer<AgentAccessDecision>();
        final container = _container(service: service, modal: modal);
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await bridge.openSession(
          clientName: _clientName,
          hostId: _host.id,
          kind: AgentSessionKind.sftp,
        );
        final request = McpRequestContext();
        final future = request.run(
          () => bridge.uploadSftp(
            clientName: _clientName,
            sessionId: handle.sessionId,
            localPath: file.path,
            remotePath: '/srv/upload.bin',
          ),
        );
        final code = switch (change) {
          'deny' => 'upload_denied',
          'revoke' || 'reunlock' => 'authorization_required',
          'close' => 'session_not_found',
          'vault' => 'vault_locked',
          'cancel' => 'request_cancelled',
          _ => 'local_file_changed',
        };
        final expectation = expectLater(
          future,
          throwsA(
            change == 'cancel'
                ? isA<McpApprovalException>().having(
                    (e) => e.code,
                    'code',
                    code,
                  )
                : _bridgeException(code),
          ),
        );
        await modal.uploadStarted.future;
        switch (change) {
          case 'revoke':
            await bridge.revokeGrant(handle.grantId);
          case 'close':
            await bridge.closeSession(handle.sessionId);
          case 'vault' || 'reunlock':
            (container.read(
              vaultSessionControllerProvider.notifier,
            ) as _FakeVaultSessionController).setSnapshot(
              VaultSessionState(
                vaultState: change == 'vault'
                    ? VaultState.locked
                    : VaultState.unlocked,
                unlockGeneration: 2,
              ),
            );
          case 'cancel':
            request.cancel();
          case 'source':
            await file.writeAsString('changed source');
        }
        modal.uploadApprovalGate!.complete(
          change == 'deny'
              ? AgentAccessDecision.deny
              : AgentAccessDecision.allow,
        );
        await expectation;
        expect(service.sftp.uploads, isEmpty);
        expect(
          container.read(transferQueueControllerProvider).state.tasks,
          isEmpty,
        );
      });
    }

    test(
      'rejects invalid paths, directories and inaccessible local files',
      () async {
        final modal = _FakeSecurityModalService();
        final container = _container(
          service: _EchoSshSessionService(),
          modal: modal,
        );
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await bridge.openSession(
          clientName: _clientName,
          hostId: _host.id,
          kind: AgentSessionKind.sftp,
        );
        for (final item in [
          (local: 'relative', remote: '/srv/file', code: 'invalid_local_path'),
          (local: file.path, remote: 'relative', code: 'invalid_remote_path'),
          (local: file.path, remote: '/srv/', code: 'invalid_remote_path'),
          (local: file.path, remote: '/srv/..', code: 'invalid_remote_path'),
          (
            local: directory.path,
            remote: '/srv/file',
            code: 'local_file_required',
          ),
          (
            local: '${directory.path}/missing',
            remote: '/srv/file',
            code: 'local_file_unavailable',
          ),
        ]) {
          await expectLater(
            bridge.uploadSftp(
              clientName: _clientName,
              sessionId: handle.sessionId,
              localPath: item.local,
              remotePath: item.remote,
            ),
            throwsA(_bridgeException(item.code)),
          );
        }
        expect(modal.uploadCallCount, 0);
      },
    );

    for (final close in [false, true]) {
      test(
        '${close ? 'session close' : 'cancel'} cancels an active upload',
        () async {
          final service = _EchoSshSessionService();
          final gate = service.sftp.uploadGate = Completer<void>();
          final container = _container(
            service: service,
            modal: _FakeSecurityModalService(),
          );
          addTearDown(container.dispose);
          final bridge = await _bridge(container);
          final handle = await bridge.openSession(
            clientName: _clientName,
            hostId: _host.id,
            kind: AgentSessionKind.sftp,
          );
          final result = await bridge.uploadSftp(
            clientName: _clientName,
            sessionId: handle.sessionId,
            localPath: file.path,
            remotePath: '/srv/upload.bin',
          );
          final id = TransferTaskId(result['taskId'] as String);
          await _drainMicrotasks();
          final cancelled = close
              ? bridge.closeSession(handle.sessionId)
              : bridge.cancelTransfer(
                  clientName: _clientName,
                  sessionId: handle.sessionId,
                  taskId: id,
                );
          gate.complete();
          await cancelled;
          expect(
            container
                .read(transferQueueControllerProvider)
                .state
                .byId(id)!
                .state,
            TransferState.canceled,
          );
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
        await bridge.revokeGrant(handle.grantId);
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

    test('a previous approval cannot bypass a new model judgment', () async {
      final model = _DecisionModel();
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowOnce;
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
    });

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
            await bridge.revokeGrant(handle.grantId);
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

    test('dangerous commands always require a fresh confirmation', () async {
      final service = _EchoSshSessionService();
      final modal = _FakeSecurityModalService()
        ..commandDecision = AgentCommandDecision.allowOnce;
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

      expect(modal.commandCallCount, 2);
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
        await bridge.revokeGrant(handle.grantId);

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

    test(
      'sendInput rejects fragments and screens submitted commands',
      () async {
        final service = _EchoSshSessionService();
        final modal = _FakeSecurityModalService();
        final container = _container(service: service, modal: modal);
        addTearDown(container.dispose);
        final bridge = await _bridge(container);
        final handle = await _openSession(bridge);

        await expectLater(
          bridge.sendInput(
            clientName: _clientName,
            sessionId: handle.sessionId,
            text: 'y',
          ),
          throwsA(_bridgeException('command_blocked')),
        );
        expect(service.shells.single.writes, isEmpty);
        expect(modal.commandCallCount, 0);

        await expectLater(
          bridge.sendInput(
            clientName: _clientName,
            sessionId: handle.sessionId,
            text: 'rm -rf /tmp/junk\n',
          ),
          throwsA(_bridgeException('command_denied')),
        );
        expect(service.shells.single.writes, isEmpty);
      },
    );

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

class _PausingApprovalStore extends InMemorySecretStore {
  final started = Completer<void>();
  final resume = Completer<void>();
  int reads = 0;

  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    final snapshot = await super.read(ref, protection: protection);
    if (ref == McpCommandApproval.storageKey && ++reads == 2) {
      started.complete();
      await resume.future;
    }
    return snapshot;
  }
}

const _clientName = 'test-client';

final _metadataHost = HostConfig(
  id: _host.id,
  displayName: _host.displayName,
  hostname: _host.hostname,
  username: _host.username,
  port: _host.port,
  authKinds: _host.authKinds,
  tags: {},
  trustState: _host.trustState,
  identityIds: [IdentityId('private-identity')],
  startupCommands: ['export TOKEN=private-startup-token'],
  jumpHostIds: [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _MetadataHosts implements HostRepository {
  int readCount = 0;
  Completer<List<HostConfig>>? gate;
  @override
  Future<List<HostConfig>> list() async {
    readCount++;
    return gate == null ? [_metadataHost] : await gate!.future;
  }

  @override
  Future<HostConfig?> read(HostId id) async => _metadataHost;
  @override
  Future<void> save(HostConfig host) => throw UnimplementedError();
  @override
  Future<void> delete(HostId id) => throw UnimplementedError();
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
  HostRepository? hosts,
  InMemorySecretStore? secrets,
  CommandDecisionGuard? decisionGuard,
  bool bypass = true,
  WorkspaceTabController Function()? workspaceTabControllerFactory,
  Future<Directory> Function()? downloadDirectory,
  Duration attachTimeout = const Duration(seconds: 5),
}) {
  return ProviderContainer(
    overrides: [
      secretStoreProvider.overrideWithValue(secrets ?? InMemorySecretStore()),
      if (hosts != null) hostRepositoryProvider.overrideWithValue(hosts),
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
      mcpCommandApprovalProvider.overrideWith((ref) {
        final approval = McpCommandApproval(ref.watch(secretStoreProvider));
        if (bypass) unawaited(approval.saveBypass(true));
        return approval;
      }),
      agentSessionBridgeProvider.overrideWith((ref) {
        final bridge = AgentSessionBridge(
          ref: ref,
          authorization: ref.watch(mcpAuthorizationServiceProvider),
          riskPolicy: CommandRiskPolicy(),
          commandApproval: ref.watch(mcpCommandApprovalProvider),
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

  void setSnapshot(VaultSessionState snapshot) => state = AsyncData(snapshot);

  @override
  Future<VaultSessionState> build() async => _state;
}

class _EchoSshSessionService implements SshSessionService, SshCommandService {
  final commands = <_CommandProcess>[];
  Completer<void>? commandOpenGate;
  String? commandCwd;
  @override
  Future<SshCommandProcess> openCommand({
    required SessionId sessionId,
    String? cwd,
  }) async {
    final process = _CommandProcess();
    commands.add(process);
    commandCwd = cwd;
    await commandOpenGate?.future;
    return process;
  }

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
  final uploads = <({String localPath, String remotePath, List<int> bytes})>[];
  Completer<void>? uploadGate;
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
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) async* {
    final bytes = await File(localPath).readAsBytes();
    uploads.add((localPath: localPath, remotePath: remotePath, bytes: bytes));
    await uploadGate?.future;
    yield TransferProgress(
      taskId: taskId,
      state: TransferState.completed,
      transferredBytes: bytes.length,
      totalBytes: bytes.length,
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
  AgentAccessPrompt? lastAccessPrompt;
  var commandCallCount = 0;
  Completer<AgentAccessDecision>? accessGate;
  Completer<AgentCommandDecision>? commandGate;
  final commandStarted = Completer<void>();
  AgentCommandPrompt? lastCommandPrompt;
  AgentAccessDecision uploadDecision = AgentAccessDecision.allow;
  AgentUploadPrompt? lastUploadPrompt;
  Completer<AgentAccessDecision>? uploadApprovalGate;
  final uploadStarted = Completer<void>();
  int uploadCallCount = 0;

  @override
  Future<AgentAccessDecision> confirmAgentUpload(AgentUploadPrompt prompt) {
    uploadCallCount++;
    lastUploadPrompt = prompt;
    if (!uploadStarted.isCompleted) uploadStarted.complete();
    return uploadApprovalGate?.future ?? Future.value(uploadDecision);
  }

  @override
  Future<AgentAccessDecision> confirmAgentAccess(AgentAccessPrompt prompt) {
    accessCallCount += 1;
    lastAccessPrompt = prompt;
    return accessGate?.future ?? Future.value(accessDecision);
  }

  @override
  Future<AgentCommandDecision> confirmAgentCommand(AgentCommandPrompt prompt) {
    commandCallCount += 1;
    lastCommandPrompt = prompt;
    if (!commandStarted.isCompleted) commandStarted.complete();
    return commandGate?.future ?? Future.value(commandDecision);
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
    dataSharingConsent: true,
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
    CommandDecisionConnection connection = const CommandDecisionConnection(),
  }) async {
    commands.add(command);
    if (failure != null) throw failure!;
    if (!started.isCompleted) started.complete();
    if (pending != null) return pending!.future;
    return decision;
  }
}

class _CommandProcess implements SshCommandProcess {
  final out = StreamController<List<int>>();
  final err = StreamController<List<int>>();
  final completed = Completer<void>();
  final bytes = <int>[];
  int interrupts = 0;
  bool inputClosed = false;
  bool closed = false;
  @override
  int? exitCode;
  @override
  String? get exitSignal => null;
  @override
  Stream<List<int>> get stdout => out.stream;
  @override
  Stream<List<int>> get stderr => err.stream;
  @override
  Future<void> get done => completed.future;
  @override
  Future<void> write(List<int> value) async {
    bytes.addAll(value);
  }

  @override
  Future<void> closeInput() async {
    inputClosed = true;
  }

  @override
  Future<void> interrupt() async {
    interrupts++;
  }

  Future<void> finish([int? code]) async {
    exitCode = code;
    if (!completed.isCompleted) completed.complete();
    unawaited(out.close());
    unawaited(err.close());
  }

  @override
  Future<void> close() async {
    closed = true;
    await finish();
  }
}
