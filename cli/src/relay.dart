import 'dart:async';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:serlink/features/mcp/domain/mcp_contract.dart';

import 'app_connection.dart';

/// Standalone stdio MCP server with a lazy connection to the desktop backend.
/// Initialization, discovery, ping and tool enumeration are all local. Only a
/// validated tool call can connect to or launch the app.
class SerlinkMcpRelay {
  SerlinkMcpRelay._(this._connection, this._log)
    : _localServer = McpServer(
        const Implementation(name: 'serlink', version: '1.0.0'),
        options: const McpServerOptions(
          protocol: McpProtocol.stable,
          instructions: serlinkMcpInstructions,
        ),
      );

  final SerlinkAppConnection _connection;
  final McpServer _localServer;
  final void Function(String message) _log;
  final Completer<void> _doneCompleter = Completer<void>();
  bool _closed = false;

  /// Starts serving immediately, without reading discovery or contacting the
  /// app. The helper owns [connection] and closes it when the client leaves.
  static Future<SerlinkMcpRelay> start({
    required Transport clientSideTransport,
    required SerlinkAppConnection connection,
    void Function(String message)? log,
  }) async {
    final relay = SerlinkMcpRelay._(connection, log ?? ((_) {}));
    for (final tool in serlinkMcpTools.values) {
      tool.register(
        relay._localServer,
        callback: (args, extra) => relay._callTool(tool.name, args, extra),
      );
    }
    relay._localServer.server.onclose = () => unawaited(relay.close());
    // Unsupported requests are rejected locally by the SDK. Notifications
    // never establish a backend connection; this includes cancellations,
    // whose request ids belong to the client-facing protocol session.
    try {
      await relay._localServer.connect(clientSideTransport);
    } on Object {
      await relay.close();
      rethrow;
    }
    return relay;
  }

  Future<void> get done => _doneCompleter.future;

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    try {
      await _connection.close();
    } on Object catch (error) {
      _log('serlink-mcp: error closing backend connection: $error');
    }
    try {
      await _localServer.close();
    } on Object catch (error) {
      _log('serlink-mcp: error closing helper: $error');
    } finally {
      _doneCompleter.complete();
    }
  }

  Future<CallToolResult> _callTool(
    String name,
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    final McpClient remote;
    try {
      remote = await _connection.connect(
        _localServer.server.getClientVersion() ??
            extra.clientInfo ??
            const Implementation(name: 'serlink-mcp', version: '1.0.0'),
      );
    } on Object catch (error) {
      final code = error is TimeoutException
          ? 'connect_timeout'
          : 'app_unavailable';
      return _toolError('$code: $error');
    }

    final progressToken = extra.meta?['progressToken'];
    try {
      // Preserve request metadata and progress tokens across the two protocol
      // sessions. The SDK assigns fresh request ids on the backend connection.
      return await remote.request(
        JsonRpcRequest(
          id: extra.requestId,
          method: Method.toolsCall,
          params: {'name': name, 'arguments': args},
          meta: extra.meta,
        ),
        CallToolResult.fromJson,
        RequestOptions(
          // An approval dialog can take as long as the user needs.
          timeoutEnabled: false,
          onprogress: progressToken == null
              ? null
              : (progress) {
                  unawaited(
                    extra
                        .sendNotification(
                          JsonRpcNotification(
                            method: Method.notificationsProgress,
                            params: {
                              'progressToken': progressToken,
                              'progress': progress.progress,
                              if (progress.total != null)
                                'total': progress.total,
                              if (progress.message != null)
                                'message': progress.message,
                            },
                          ),
                        )
                        .catchError((Object error) {
                          _log(
                            'serlink-mcp: failed to forward progress: $error',
                          );
                        }),
                  );
                },
        ),
      );
    } on Object catch (error) {
      await _connection.invalidate(remote);
      return _toolError(
        'app_connection_lost: $error. The tool call was not retried; '
        'its outcome may be unknown. Check the session before retrying.',
      );
    }
  }

  static CallToolResult _toolError(String message) =>
      CallToolResult(content: [TextContent(text: message)], isError: true);
}
