import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ids/entity_id.dart';
import '../../../core/security/local_file_security.dart';
import '../data/mcp_server_transport.dart';
import '../domain/mcp_contract.dart';
import 'agent_session_bridge.dart';

class McpServerState {
  const McpServerState({
    this.running = false,
    this.port,
    this.token,
    this.lastError,
  });

  final bool running;
  final int? port;
  final String? token;
  final String? lastError;

  McpServerState copyWith({
    bool? running,
    int? port,
    String? token,
    String? lastError,
    bool clearError = false,
  }) {
    return McpServerState(
      running: running ?? this.running,
      port: port ?? this.port,
      token: token ?? this.token,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }
}

/// Runs the embedded MCP server that lets external AI agents drive app-owned
/// SSH terminal sessions.
///
/// Started eagerly on platforms where `PlatformCapabilities.mcpServer` is
/// true. On direct (non-App-Store) builds a discovery file with the URL and
/// per-run bearer token is written to the application support directory so a
/// stdio helper can hand the endpoint to MCP clients.
typedef McpServerTransportFactory =
    McpServerTransport Function({
      required McpServer Function(String sessionId) serverFactory,
      required String bearerToken,
    });

class McpServerController extends Notifier<McpServerState> {
  McpServerController({
    McpServerTransportFactory? transportFactory,
    Future<File> Function()? discoveryFile,
  }) : _transportFactory = transportFactory ?? McpServerTransport.new,
       _discoveryFile = discoveryFile ?? _defaultDiscoveryFile;

  static const _uuid = Uuid();
  static const _discoveryFileName = 'mcp-server.json';

  final McpServerTransportFactory _transportFactory;
  final Future<File> Function() _discoveryFile;

  McpServerTransport? _transport;

  /// Live per-session MCP servers, keyed by streamable-HTTP session id.
  /// `RequestHandlerExtra.clientInfo` is null for stable-protocol stateful
  /// sessions, so tool callbacks resolve the client identity through the
  /// per-session server's negotiated version instead.
  final Map<String, McpServer> _serversBySessionId = {};

  /// Chained in-flight lifecycle operation; start/stop are serialized
  /// through it so concurrent calls cannot bind two servers or leak a
  /// transport that finished starting after a stop was requested.
  Future<void> _lifecycle = Future<void>.value();

  /// Intent flag set synchronously before any await, so a stop() landing
  /// mid-start still wins.
  var _wantRunning = false;

  @override
  McpServerState build() {
    ref.onDispose(() {
      unawaited(stop());
    });
    if (ref.watch(platformCapabilitiesProvider).mcpServer) {
      unawaited(
        Future<void>.microtask(() {
          if (ref.mounted) {
            unawaited(start());
          }
        }),
      );
    }
    return const McpServerState();
  }

  Future<void> start() {
    _wantRunning = true;
    return _enqueue(_startLocked);
  }

  Future<void> stop() {
    _wantRunning = false;
    return _enqueue(_stopLocked);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final run = _lifecycle.then((_) => action());
    _lifecycle = run;
    return run;
  }

  Future<void> _startLocked() async {
    if (_transport != null || !_wantRunning) {
      return;
    }
    final capabilities = ref.read(platformCapabilitiesProvider);
    if (!capabilities.mcpServer) {
      return;
    }
    final token = _uuid.v4();
    final version = ref.read(appPackageInfoProvider).value?.version ?? '1.0.0';
    final bridge = ref.read(agentSessionBridgeProvider);
    final transport = _transportFactory(
      bearerToken: token,
      serverFactory: (sessionId) {
        final server = _buildServer(bridge, version);
        _serversBySessionId[sessionId] = server;
        // StreamableMcpServer chains factory-set onclose handlers into its
        // own session-cleanup wiring, so this survives Protocol.connect.
        server.server.onclose = () {
          _serversBySessionId.remove(sessionId);
        };
        return server;
      },
    );
    try {
      await transport.start();
    } on Object catch (error) {
      if (ref.mounted) {
        state = McpServerState(lastError: '$error');
      }
      _log('mcp.server.start_failed', details: {'error': '$error'});
      return;
    }
    if (!_wantRunning || !ref.mounted) {
      // stop() was requested while the bind was in flight: tear the
      // just-started transport down instead of publishing a running state.
      try {
        await transport.stop();
      } on Object {
        // Best-effort; the server is loopback-only and dies with the app.
      }
      return;
    }
    _transport = transport;
    if (capabilities.mcpStdioHelper) {
      await _writeDiscoveryFile(port: transport.port, token: token);
    }
    if (!ref.mounted) {
      return;
    }
    state = McpServerState(running: true, port: transport.port, token: token);
    _log('mcp.server.start', details: {'port': transport.port});
  }

  Future<void> _stopLocked() async {
    final transport = _transport;
    _transport = null;
    _serversBySessionId.clear();
    if (transport != null) {
      try {
        await transport.stop();
      } on Object {
        // Stopping is best-effort; the server is loopback-only and dies with
        // the app anyway.
      }
      _log('mcp.server.stop');
    }
    await _deleteDiscoveryFile();
    if (ref.mounted) {
      state = const McpServerState();
    }
  }

  void _log(String event, {Map<String, Object?> details = const {}}) {
    if (!ref.mounted) {
      return;
    }
    unawaited(
      ref.read(offlineDiagnosticLoggerProvider).record(event, details: details),
    );
  }

  static Future<File> _defaultDiscoveryFile() async {
    final supportDir = await getApplicationSupportDirectory();
    return File('${supportDir.path}/$_discoveryFileName');
  }

  Future<void> _writeDiscoveryFile({
    required int port,
    required String token,
  }) async {
    try {
      final file = await _discoveryFile();
      final type = FileSystemEntity.typeSync(file.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw StateError('discovery file is a symbolic link');
      }
      // Create an empty private destination first. Besides preserving the
      // permission invariant, this keeps the write path compatible with
      // custom File implementations used by platform tests.
      await LocalFileSecurity.restrictFile(file);
      await file.writeAsString(
        jsonEncode({
          'url': 'http://127.0.0.1:$port/mcp',
          'token': token,
          'pid': pid,
        }),
        flush: true,
      );
    } on Object catch (error) {
      _log('mcp.server.discovery_file_failed', details: {'error': '$error'});
    }
  }

  Future<void> _deleteDiscoveryFile() async {
    try {
      final file = await _discoveryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Best-effort cleanup; a stale file points at a dead port and token.
    }
  }

  McpServer _buildServer(AgentSessionBridge bridge, String version) {
    final server = McpServer(
      Implementation(name: 'serlink', version: version),
      options: const McpServerOptions(
        protocol: McpProtocol.stable,
        instructions: serlinkMcpInstructions,
      ),
    );

    Future<CallToolResult> guard(
      Future<Object?> Function(String clientName) run,
      RequestHandlerExtra extra,
    ) async {
      // extra.clientInfo is null for stable-protocol stateful sessions in
      // mcp_dart, so resolve the identity negotiated by this session's own
      // McpServer instance first.
      final clientName =
          _serversBySessionId[extra.sessionId]?.server
              .getClientVersion()
              ?.name ??
          extra.clientInfo?.name ??
          'unknown';
      try {
        final payload = await run(clientName);
        return CallToolResult.fromContent([
          TextContent(text: jsonEncode(payload)),
        ]);
      } on McpBridgeException catch (error) {
        return CallToolResult(
          content: [TextContent(text: error.toString())],
          isError: true,
        );
      } on Object catch (error) {
        return CallToolResult(
          content: [TextContent(text: 'internal_error: $error')],
          isError: true,
        );
      }
    }

    serlinkMcpTools['serlink_list_hosts']!.register(
      server,
      callback: (args, extra) => guard((clientName) async {
        final hosts = await bridge.listHosts();
        return [
          for (final host in hosts)
            {
              'id': host.id.value,
              'displayName': host.displayName,
              'hostname': host.hostname,
              'port': host.port,
            },
        ];
      }, extra),
    );

    serlinkMcpTools['serlink_open_session']!.register(
      server,
      callback: (args, extra) => guard((clientName) async {
        final handle = await bridge.openSession(
          clientName: clientName,
          hostId: HostId(args['hostId'] as String),
        );
        var screen = '';
        try {
          screen = await bridge.readScreen(
            clientName: clientName,
            sessionId: handle.sessionId,
          );
        } on McpBridgeException {
          // Initial screen read is best-effort.
        }
        return {
          'sessionId': handle.sessionId.value,
          'hostId': handle.hostId.value,
          'state': handle.state.name,
          'screen': screen,
        };
      }, extra),
    );

    serlinkMcpTools['serlink_exec']!.register(
      server,
      callback: (args, extra) => guard((clientName) async {
        final timeoutMs = args['timeoutMs'] as num?;
        final output = await bridge.exec(
          clientName: clientName,
          sessionId: SessionId(args['sessionId'] as String),
          command: args['command'] as String,
          timeout: timeoutMs == null
              ? const Duration(seconds: 10)
              // Clamp so a client cannot stall a tool call (or spin the
              // settle loop) with an absurd timeout.
              : Duration(milliseconds: timeoutMs.toInt().clamp(500, 120000)),
        );
        return {'output': output};
      }, extra),
    );

    serlinkMcpTools['serlink_read_screen']!.register(
      server,
      callback: (args, extra) => guard((clientName) async {
        final lines = args['lines'] as num?;
        final screen = await bridge.readScreen(
          clientName: clientName,
          sessionId: SessionId(args['sessionId'] as String),
          lines: lines?.toInt() ?? 50,
        );
        return {'screen': screen};
      }, extra),
    );

    serlinkMcpTools['serlink_send_input']!.register(
      server,
      callback: (args, extra) => guard((clientName) async {
        await bridge.sendInput(
          clientName: clientName,
          sessionId: SessionId(args['sessionId'] as String),
          text: args['text'] as String,
        );
        return {'ok': true};
      }, extra),
    );

    serlinkMcpTools['serlink_close_session']!.register(
      server,
      callback: (args, extra) => guard((clientName) async {
        await bridge.closeSession(SessionId(args['sessionId'] as String));
        return {'ok': true};
      }, extra),
    );

    serlinkMcpTools['serlink_list_sessions']!.register(
      server,
      callback: (args, extra) => guard((clientName) async {
        return [
          for (final handle in bridge.sessions)
            {
              'sessionId': handle.sessionId.value,
              'hostId': handle.hostId.value,
              'state': handle.state.name,
              'clientName': handle.clientName,
              'openedAt': handle.openedAt.toUtc().toIso8601String(),
            },
        ];
      }, extra),
    );

    return server;
  }
}
