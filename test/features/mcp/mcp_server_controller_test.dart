import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/core/logging/offline_diagnostic_logger.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/mcp/application/agent_session_bridge.dart';
import 'package:serlink/features/mcp/application/agent_config_installer.dart';
import 'package:serlink/features/mcp/application/agent_skill_installer.dart';
import 'package:serlink/features/mcp/application/mcp_authorization_service.dart';
import 'package:serlink/features/mcp/application/mcp_server_controller.dart';
import 'package:serlink/features/mcp/data/command_risk_policy.dart';
import 'package:serlink/features/mcp/data/mcp_server_transport.dart';
import 'package:serlink/features/mcp/domain/agent_session.dart';
import 'package:serlink/features/mcp/domain/mcp_contract.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  group('McpServerController', () {
    test(
      'startup discovers agents and installs or updates global skills',
      () async {
        final home = Directory.systemTemp.createTempSync(
          'serlink-startup-skills-',
        );
        addTearDown(() => home.deleteSync(recursive: true));
        Directory('${home.path}/.claude').createSync();
        var content = 'skill v1';
        final scoped = _container(
          agentHome: home,
          skillContent: () async => content,
        );
        addTearDown(scoped.dispose);
        final controller = scoped.read(mcpServerControllerProvider.notifier);
        await controller.start();
        final skill = File('${home.path}/.claude/skills/serlink-mcp/SKILL.md');
        expect(skill.readAsStringSync(), 'skill v1');
        expect(
          scoped.read(mcpServerControllerProvider).agentSkills.single.target.id,
          'claude-code',
        );
        expect(File('${home.path}/.claude.json').existsSync(), isFalse);
        await controller.stop();
        content = 'skill v2';
        Directory('${home.path}/.codex').createSync();
        await controller.start();
        expect(skill.readAsStringSync(), 'skill v2');
        expect(
          File('${home.path}/.agents/skills/serlink-mcp/SKILL.md')
              .readAsStringSync(),
          'skill v2',
        );
        expect(
          scoped.read(mcpServerControllerProvider).agentSkills,
          hasLength(2),
        );
        await controller.stop();
      },
    );

    test(
      'App Store startup neither detects agents nor writes global skills',
      () async {
        final home = Directory.systemTemp.createTempSync(
          'serlink-sandbox-skills-',
        );
        addTearDown(() => home.deleteSync(recursive: true));
        Directory('${home.path}/.claude').createSync();
        final container = _container(
          agentHome: home,
          distribution: SerlinkDistribution.appStore,
        );
        addTearDown(container.dispose);
        final controller = container.read(mcpServerControllerProvider.notifier);
        await controller.start();
        await controller.refreshAgentSkills(synchronize: true);
        expect(container.read(mcpServerControllerProvider).running, isTrue);
        expect(
          container.read(mcpServerControllerProvider).agentSkills,
          isEmpty,
        );
        expect(Directory('${home.path}/.claude/skills').existsSync(), isFalse);
        await controller.stop();
      },
    );

    test('tool callbacks resolve the per-session client name', () async {
      final harness = _Harness();
      final container = _container(harness: harness);
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);
      await controller.start();
      final state = container.read(mcpServerControllerProvider);
      expect(state.running, isTrue);

      final client = await _connectClient(
        state.port!,
        state.token!,
        // Legacy initialization matches real-world stable-protocol stateful
        // sessions, where RequestHandlerExtra.clientInfo is null.
        protocol: McpProtocol.legacy,
      );
      addTearDown(client.close);

      final result = await client.callTool(
        CallToolRequest(
          name: 'serlink_open_session',
          arguments: {'hostId': 'host-1'},
        ),
      );

      // The capturing bridge refuses the open; only the resolved client name
      // matters here.
      expect(result.isError, isTrue);
      expect(harness.bridge!.lastOpenClientName, 'test-client');
    });

    test(
      'server sends agent behavior instructions at initialization',
      () async {
        final container = _container(harness: _Harness());
        addTearDown(container.dispose);
        final controller = container.read(mcpServerControllerProvider.notifier);
        await controller.start();
        final state = container.read(mcpServerControllerProvider);
        final client = await _connectClient(state.port!, state.token!);
        addTearDown(client.close);

        final instructions = client.getInstructions();
        expect(instructions, isNotNull);
        expect(instructions, contains('serlink_list_hosts'));
        expect(instructions, contains('serlink_open_session'));
        expect(instructions, contains('serlink_close_session'));
        expect(instructions, contains('NEVER connect to any host yourself'));
        expect(instructions, contains('vault_locked'));
        expect(instructions, contains('authorization_denied'));

        final tools = (await client.listTools()).tools;
        expect(
          tools.map((tool) => tool.name),
          unorderedEquals(serlinkMcpTools.keys),
        );
        for (final tool in tools) {
          final definition = serlinkMcpTools[tool.name]!;
          expect(tool.description, definition.description);
          expect(tool.inputSchema.toJson(), definition.inputSchema.toJson());
        }
      },
    );

    test('SFTP upload forwards both paths and the owning client', () async {
      final harness = _Harness();
      final container = _container(harness: harness);
      addTearDown(container.dispose);
      await container.read(mcpServerControllerProvider.notifier).start();
      final state = container.read(mcpServerControllerProvider);
      final client = await _connectClient(state.port!, state.token!);
      addTearDown(client.close);
      final result = await client.callTool(
        const CallToolRequest(
          name: 'serlink_sftp_upload',
          arguments: {
            'sessionId': 'sftp-1',
            'localPath': '/tmp/package.zip',
            'remotePath': '/srv/package.zip',
          },
        ),
      );
      expect(result.isError, isNot(true));
      expect(harness.bridge!.lastUpload, {
        'clientName': 'test-client',
        'sessionId': 'sftp-1',
        'localPath': '/tmp/package.zip',
        'remotePath': '/srv/package.zip',
      });
      expect((result.content.single as TextContent).text, contains('upload-1'));
    });

    test('serlink_list_hosts surfaces vault_locked through the tool', () async {
      final container = _container(harness: _Harness());
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);
      await controller.start();
      final state = container.read(mcpServerControllerProvider);
      final client = await _connectClient(state.port!, state.token!);
      addTearDown(client.close);

      final result = await client.callTool(
        const CallToolRequest(name: 'serlink_list_hosts'),
      );

      // The container has no vault, so the bridge must refuse rather than
      // leak the host list past the unlock gate.
      expect(result.isError, isTrue);
      final text = (result.content.single as TextContent).text;
      expect(text, contains('vault_locked'));
    });

    test('serlink_exec clamps timeoutMs to 500..120000', () async {
      final harness = _Harness();
      final container = _container(harness: harness);
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);
      await controller.start();
      final state = container.read(mcpServerControllerProvider);
      final client = await _connectClient(state.port!, state.token!);
      addTearDown(client.close);

      await client.callTool(
        CallToolRequest(
          name: 'serlink_exec',
          arguments: {'sessionId': 's1', 'command': 'ls', 'timeoutMs': 1},
        ),
      );
      expect(
        harness.bridge!.lastExecTimeout,
        const Duration(milliseconds: 500),
      );

      await client.callTool(
        CallToolRequest(
          name: 'serlink_exec',
          arguments: {'sessionId': 's1', 'command': 'ls', 'timeoutMs': 600000},
        ),
      );
      expect(
        harness.bridge!.lastExecTimeout,
        const Duration(milliseconds: 120000),
      );
    });

    test('job mode carries a multi-megabyte script and exposes paginated lifecycle tools', () async {
      final harness = _Harness();
      final container = _container(harness: harness);
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);
      await controller.start();
      final state = container.read(mcpServerControllerProvider);
      final client = await _connectClient(state.port!, state.token!);
      addTearDown(client.close);
      final script = '#${'x' * (3 * 1024 * 1024)}\necho done\n';
      final result = await client.callTool(
        CallToolRequest(
          name: 'serlink_exec',
          arguments: {
            'sessionId': 's1',
            'command': script,
            'mode': 'job',
            'cwd': '/srv/app',
            'timeoutMs': 900000,
          },
        ),
      );
      expect(result.isError, isNot(true));
      expect(harness.bridge!.lastScript, script);
      expect(harness.bridge!.lastCwd, '/srv/app');
      expect(harness.bridge!.lastExecTimeout, const Duration(seconds: 30));
      final payload =
          jsonDecode((result.content.single as TextContent).text) as Map;
      expect(payload['commandId'], 'job-1');
      expect(payload['finished'], isFalse);
      final status = await client.callTool(
        CallToolRequest(
          name: 'serlink_command_status',
          arguments: {
            'sessionId': 's1',
            'commandId': 'job-1',
            'cursor': 123,
            'waitMs': 900000,
          },
        ),
      );
      expect(status.isError, isNot(true));
      expect(harness.bridge!.lastCursor, 123);
      expect(harness.bridge!.lastExecTimeout, const Duration(seconds: 30));
      final statusPayload =
          jsonDecode((status.content.single as TextContent).text) as Map;
      expect(statusPayload['exitCode'], 7);
      await client.callTool(
        CallToolRequest(
          name: 'serlink_command_cancel',
          arguments: {'sessionId': 's1', 'commandId': 'job-1'},
        ),
      );
      expect(harness.bridge!.cancelled, isTrue);
      await client.callTool(
        CallToolRequest(
          name: 'serlink_command_release',
          arguments: {'sessionId': 's1', 'commandId': 'job-1'},
        ),
      );
      expect(harness.bridge!.released, isTrue);
    });

    test('long terminal input requests job transport without sending partial bytes', () async {
      final harness = _Harness();
      final container = _container(harness: harness);
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);
      await controller.start();
      final state = container.read(mcpServerControllerProvider);
      final client = await _connectClient(state.port!, state.token!);
      addTearDown(client.close);
      final result = await client.callTool(
        CallToolRequest(
          name: 'serlink_exec',
          arguments: {'sessionId': 's1', 'command': 'x' * 9000},
        ),
      );
      expect(result.isError, isTrue);
      expect(
        (result.content.single as TextContent).text,
        contains('command_requires_job_mode'),
      );
      expect(harness.bridge!.lastExecTimeout, isNull);
    });

    test('concurrent starts bind a single server', () async {
      final transports = <_FakeTransport>[];
      final container = _container(
        transportFactory: _recordingFactory(transports),
      );
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);

      // build() already queued an eager start; this manual start must not
      // bind a second server.
      final manual = controller.start();
      await _waitFor(() => transports.isNotEmpty);
      transports.single.completeStart();
      await manual;
      await _drainMicrotasks();

      expect(transports, hasLength(1));
      expect(transports.single.stopCount, 0);
      expect(container.read(mcpServerControllerProvider).running, isTrue);
    });

    test('stop during an in-flight start tears the transport down', () async {
      final transports = <_FakeTransport>[];
      final container = _container(
        transportFactory: _recordingFactory(transports),
      );
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);

      await _waitFor(() => transports.isNotEmpty);
      final stop = controller.stop();
      transports.single.completeStart();
      await stop;
      await _drainMicrotasks();

      expect(container.read(mcpServerControllerProvider).running, isFalse);
      expect(transports.single.stopCount, 1);
    });

    test('discovery file is restricted before the token is written', () async {
      final file = _RecordingFile(path: '/nonexistent/mcp-server.json');
      final container = _container(discoveryFile: () async => file);
      addTearDown(container.dispose);
      final controller = container.read(mcpServerControllerProvider.notifier);
      await controller.start();
      await _drainMicrotasks();

      expect(container.read(mcpServerControllerProvider).running, isTrue);
      // LocalFileSecurity.restrictFile creates-then-chmods the file; the
      // token-bearing write must come after that, never before.
      expect(file.calls, contains('create'));
      expect(
        file.calls.indexOf('create'),
        lessThan(file.calls.indexOf('writeAsString')),
      );
      expect(file.contents, contains('"token"'));
    });

    test('providers close their broadcast streams on dispose', () async {
      final container = ProviderContainer(
        overrides: [
          securityModalServiceProvider.overrideWithValue(
            _FakeSecurityModalService(),
          ),
        ],
      );
      final service = container.read(mcpAuthorizationServiceProvider);
      final bridge = container.read(agentSessionBridgeProvider);

      final grantsDone = expectLater(service.watchGrants, emitsDone);
      final sessionsDone = expectLater(bridge.watchSessions, emitsDone);
      container.dispose();
      await grantsDone;
      await sessionsDone;
    });
  });
}

class _Harness {
  _CapturingBridge? bridge;
}

McpServerTransportFactory _recordingFactory(List<_FakeTransport> transports) {
  return ({required serverFactory, required bearerToken}) {
    final transport = _FakeTransport(
      serverFactory: serverFactory,
      bearerToken: bearerToken,
    );
    transports.add(transport);
    return transport;
  };
}

ProviderContainer _container({
  McpServerTransportFactory? transportFactory,
  Future<File> Function()? discoveryFile,
  _Harness? harness,
  Directory? agentHome,
  SerlinkDistribution distribution = SerlinkDistribution.direct,
  Future<String> Function()? skillContent,
}) {
  final configHome =
      agentHome ??
      Directory.systemTemp.createTempSync('serlink-server-agents-');
  if (agentHome == null) {
    addTearDown(() => configHome.deleteSync(recursive: true));
  }
  return ProviderContainer(
    overrides: [
      platformCapabilitiesProvider.overrideWithValue(
        PlatformCapabilities(
          operatingSystem: 'macos',
          targetPlatform: TargetPlatform.macOS,
          distribution: distribution,
        ),
      ),
      agentConfigInstallerProvider.overrideWithValue(
        AgentConfigInstaller(homeDirectory: configHome.path),
      ),
      agentSkillInstallerProvider.overrideWith(
        (ref) => AgentSkillInstaller(
          configInstaller: ref.watch(agentConfigInstallerProvider),
          loadContent:
              skillContent ??
              () =>
                  File('assets/agent_skills/serlink-mcp/SKILL.md')
                      .readAsString(),
        ),
      ),
      appPackageInfoProvider.overrideWith((ref) async {
        return PackageInfo(
          appName: 'Serlink',
          packageName: 'com.alkinum.serlink',
          version: '1.2.3',
          buildNumber: '45',
        );
      }),
      offlineDiagnosticLoggerProvider.overrideWithValue(
        _NoopDiagnosticLogger(),
      ),
      agentSessionBridgeProvider.overrideWith((ref) {
        final bridge = _CapturingBridge(
          ref: ref,
          authorization: McpAuthorizationService(
            securityModalService: _FakeSecurityModalService(),
          ),
          riskPolicy: CommandRiskPolicy(),
          commandApproval: ref.watch(mcpCommandApprovalProvider),
          securityModalService: _FakeSecurityModalService(),
        );
        harness?.bridge = bridge;
        ref.onDispose(bridge.dispose);
        return bridge;
      }),
      mcpServerControllerProvider.overrideWith(
        () => McpServerController(
          transportFactory: transportFactory,
          discoveryFile: discoveryFile,
        ),
      ),
    ],
  );
}

Future<McpClient> _connectClient(
  int port,
  String token, {
  McpProtocol protocol = McpProtocol.stable,
}) async {
  final client = McpClient(
    const Implementation(name: 'test-client', version: '1.0.0'),
    options: McpClientOptions(protocol: protocol),
  );
  final transport = StreamableHttpClientTransport(
    Uri.parse('http://127.0.0.1:$port/mcp'),
    opts: StreamableHttpClientTransportOptions(
      requestInit: {
        'headers': {'authorization': 'Bearer $token'},
      },
    ),
  );
  await client.connect(transport);
  return client;
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for condition');
}

Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 8; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Bridge stub that records how tool callbacks invoked it instead of driving
/// real terminal sessions.
class _CapturingBridge extends AgentSessionBridge {
  _CapturingBridge({
    required super.ref,
    required super.authorization,
    required super.riskPolicy,
    required super.commandApproval,
    required super.securityModalService,
  });

  String? lastOpenClientName;
  String? lastExecClientName;
  Duration? lastExecTimeout;

  @override
  Future<List<Map<String, Object?>>> describeHosts({
    required String clientName,
  }) async {
    throw const McpBridgeException('vault_locked');
  }

  @override
  Future<List<HostSummary>> listHosts() {
    // Mirrors the real bridge's behavior when the vault is locked; the
    // unlock gating itself is covered in agent_session_bridge_test.dart.
    throw const McpBridgeException('vault_locked');
  }

  @override
  Future<AgentSessionHandle> openSession({
    required String clientName,
    required HostId hostId,
    AgentSessionKind kind = AgentSessionKind.terminal,
  }) async {
    lastOpenClientName = clientName;
    throw const McpBridgeException('connect_failed', 'captured');
  }

  String? lastScript;
  String? lastCwd;
  int? lastCursor;
  bool cancelled = false;
  bool released = false;
  Map<String, String>? lastUpload;

  @override
  Future<Map<String, Object?>> uploadSftp({
    required String clientName,
    required SessionId sessionId,
    required String localPath,
    required String remotePath,
  }) async {
    lastUpload = {
      'clientName': clientName,
      'sessionId': sessionId.value,
      'localPath': localPath,
      'remotePath': remotePath,
    };
    return {
      'taskId': 'upload-1',
      'localPath': localPath,
      'remotePath': remotePath,
    };
  }

  @override
  Future<Map<String, Object?>> startCommand({
    required String clientName,
    required SessionId sessionId,
    required String command,
    String? cwd,
    Duration wait = const Duration(seconds: 1),
    int maxChars = 65536,
  }) async {
    lastScript = command;
    lastCwd = cwd;
    lastExecTimeout = wait;
    return {
      'commandId': 'job-1',
      'finished': false,
      'state': 'running',
      'output': '',
      'nextCursor': 0,
    };
  }

  @override
  Future<Map<String, Object?>> commandStatus({
    required String clientName,
    required SessionId sessionId,
    required String commandId,
    int cursor = 0,
    int maxChars = 65536,
    Duration wait = Duration.zero,
    bool commandSource = false,
  }) async {
    lastCursor = cursor;
    lastExecTimeout = wait;
    return {
      'commandId': commandId,
      'finished': true,
      'exitCode': 7,
      'output': 'last page',
      'nextCursor': cursor + 9,
    };
  }

  @override
  Future<Map<String, Object?>> cancelCommand({
    required String clientName,
    required SessionId sessionId,
    required String commandId,
  }) async {
    cancelled = true;
    return {'cancelRequested': true};
  }

  @override
  Future<void> releaseCommand({
    required String clientName,
    required SessionId sessionId,
    required String commandId,
  }) async {
    released = true;
  }

  @override
  Future<Map<String, Object?>> execWithOutput({
    required String clientName,
    required SessionId sessionId,
    required String command,
    Duration timeout = const Duration(seconds: 10),
    int maxChars = 65536,
  }) async {
    lastExecTimeout = timeout;
    return {'output': 'fixture output', 'nextCursor': 14, 'hasMore': false};
  }

  @override
  Future<String> exec({
    required String clientName,
    required SessionId sessionId,
    required String command,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    lastExecClientName = clientName;
    lastExecTimeout = timeout;
    return 'ok-output';
  }
}

/// Transport whose start is gated by the test so start/stop interleavings
/// can be exercised deterministically.
class _FakeTransport extends McpServerTransport {
  _FakeTransport({required super.serverFactory, required super.bearerToken});

  final Completer<void> _startGate = Completer<void>();
  var stopCount = 0;

  void completeStart() {
    if (!_startGate.isCompleted) {
      _startGate.complete();
    }
  }

  @override
  Future<void> start() => _startGate.future;

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  int get port => 4321;
}

/// File stub that records the order of file operations so the test can
/// assert the token is only written after permissions are restricted.
class _RecordingFile extends Fake implements File {
  _RecordingFile({required this.path});

  @override
  final String path;

  final List<String> calls = [];
  var contents = '';

  @override
  Future<bool> exists() async {
    calls.add('exists');
    return false;
  }

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    calls.add('create');
    return this;
  }

  @override
  Future<File> writeAsString(
    Object contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    calls.add('writeAsString');
    this.contents = contents as String;
    return this;
  }
}

class _NoopDiagnosticLogger extends OfflineDiagnosticLogger {
  @override
  Future<void> record(
    String event, {
    DiagnosticLogLevel level = DiagnosticLogLevel.info,
    Map<String, Object?> details = const {},
  }) async {}
}

class _FakeSecurityModalService extends Fake implements SecurityModalService {}
