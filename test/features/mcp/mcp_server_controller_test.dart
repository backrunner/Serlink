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
import 'package:serlink/features/mcp/application/agent_session_bridge.dart';
import 'package:serlink/features/mcp/application/mcp_authorization_service.dart';
import 'package:serlink/features/mcp/application/mcp_server_controller.dart';
import 'package:serlink/features/mcp/data/command_risk_policy.dart';
import 'package:serlink/features/mcp/data/mcp_server_transport.dart';
import 'package:serlink/features/mcp/domain/agent_session.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  group('McpServerController', () {
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
          arguments: {
            'sessionId': 's1',
            'command': 'ls',
            'timeoutMs': 600000,
          },
        ),
      );
      expect(
        harness.bridge!.lastExecTimeout,
        const Duration(milliseconds: 120000),
      );
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
}) {
  return ProviderContainer(
    overrides: [
      platformCapabilitiesProvider.overrideWithValue(
        const PlatformCapabilities(
          operatingSystem: 'macos',
          targetPlatform: TargetPlatform.macOS,
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
    required super.securityModalService,
  });

  String? lastOpenClientName;
  String? lastExecClientName;
  Duration? lastExecTimeout;

  @override
  Future<AgentSessionHandle> openSession({
    required String clientName,
    required HostId hostId,
  }) async {
    lastOpenClientName = clientName;
    throw const McpBridgeException('connect_failed', 'captured');
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
