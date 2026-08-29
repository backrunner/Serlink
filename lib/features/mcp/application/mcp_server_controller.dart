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
    final version =
        ref.read(appPackageInfoProvider).value?.version ?? '1.0.0';
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
      // Restrict permissions BEFORE writing the token: restrictFile only
      // chmods, so creating the file empty first closes the window where a
      // token-bearing file would be world-readable under default Linux/macOS
      // umasks.
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
      options: const McpServerOptions(protocol: McpProtocol.stable),
    );

    Future<CallToolResult> guard(
      Future<Object?> Function(String clientName) run,
      RequestHandlerExtra extra,
    ) async {
      // extra.clientInfo is null for stable-protocol stateful sessions in
      // mcp_dart, so resolve the identity negotiated by this session's own
      // McpServer instance first.
      final clientName =
          _serversBySessionId[extra.sessionId]
              ?.server
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

    server.registerTool(
      'serlink_list_hosts',
      description:
          'List the SSH hosts configured in Serlink. Workflow: call this '
          'first, then serlink_open_session with a host id, then '
          'serlink_exec/serlink_read_screen to drive the session, and '
          'serlink_close_session when done. Fails with vault_locked while '
          'the Serlink vault is locked; ask the user to unlock it in the app.',
      inputSchema: JsonSchema.object(),
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

    server.registerTool(
      'serlink_open_session',
      description:
          'Open an SSH session to a Serlink host as a visible terminal tab '
          'in the Serlink app. The user must approve access in a Serlink '
          'dialog (and unlock the vault first if it is locked), so this call '
          'may block until the user responds. Credentials never leave the '
          'app; you drive the resulting terminal with serlink_exec, '
          'serlink_read_screen, and serlink_send_input. The user can take '
          'back control at any time by typing in the tab.',
      inputSchema: JsonSchema.object(
        properties: {
          'hostId': JsonSchema.string(
            description: 'Host id from serlink_list_hosts.',
          ),
        },
        required: ['hostId'],
      ),
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

    server.registerTool(
      'serlink_exec',
      description:
          'Run a shell command in an open Serlink session and return the '
          'terminal screen after the output settles. Risky commands require '
          'user confirmation in the Serlink app; destructive commands are '
          'blocked outright. The result is the last screen lines (including '
          'the echoed command), not a byte-exact output capture.',
      inputSchema: JsonSchema.object(
        properties: {
          'sessionId': JsonSchema.string(
            description: 'Session id from serlink_open_session.',
          ),
          'command': JsonSchema.string(description: 'Shell command to run.'),
          'timeoutMs': JsonSchema.integer(
            description:
                'Maximum time in milliseconds to wait for the output to '
                'settle (default 10000).',
          ),
        },
        required: ['sessionId', 'command'],
      ),
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

    server.registerTool(
      'serlink_read_screen',
      description:
          'Read the last lines of the terminal screen of an open Serlink '
          'session. Use after serlink_send_input or to poll long-running '
          'commands started with serlink_exec.',
      inputSchema: JsonSchema.object(
        properties: {
          'sessionId': JsonSchema.string(
            description: 'Session id from serlink_open_session.',
          ),
          'lines': JsonSchema.integer(
            description: 'Number of screen lines to return (default 50).',
          ),
        },
        required: ['sessionId'],
      ),
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

    server.registerTool(
      'serlink_send_input',
      description:
          'Send raw keystrokes to an open Serlink session, for interactive '
          'programs (e.g. answering a prompt or pressing keys in a TUI). '
          'Text containing newlines submits commands and is checked against '
          'the same risk policy as serlink_exec.',
      inputSchema: JsonSchema.object(
        properties: {
          'sessionId': JsonSchema.string(
            description: 'Session id from serlink_open_session.',
          ),
          'text': JsonSchema.string(
            description: 'Raw input text, e.g. "y\\n" or arrow-key escapes.',
          ),
        },
        required: ['sessionId', 'text'],
      ),
      callback: (args, extra) => guard((clientName) async {
        await bridge.sendInput(
          clientName: clientName,
          sessionId: SessionId(args['sessionId'] as String),
          text: args['text'] as String,
        );
        return {'ok': true};
      }, extra),
    );

    server.registerTool(
      'serlink_close_session',
      description:
          'Close a Serlink session opened with serlink_open_session. This '
          'closes the terminal tab in the Serlink app. Always close sessions '
          'when you are done with them.',
      inputSchema: JsonSchema.object(
        properties: {
          'sessionId': JsonSchema.string(
            description: 'Session id from serlink_open_session.',
          ),
        },
        required: ['sessionId'],
      ),
      callback: (args, extra) => guard((clientName) async {
        await bridge.closeSession(SessionId(args['sessionId'] as String));
        return {'ok': true};
      }, extra),
    );

    server.registerTool(
      'serlink_list_sessions',
      description:
          'List the Serlink sessions currently open for MCP clients, with '
          'their state. Use serlink_close_session for any session you no '
          'longer need.',
      inputSchema: JsonSchema.object(),
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
