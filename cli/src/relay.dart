// The relay's local side is a custom protocol implementation (generic
// method forwarding), which is the documented carve-out for using the
// deprecated low-level `Server` class instead of `McpServer`.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:mcp_dart/mcp_dart.dart';

/// JSON-RPC result that passes the remote server's result payload through
/// untouched, so relayed responses keep their exact shape.
class RawResult implements BaseResultData {
  const RawResult(this._json);

  final Map<String, dynamic> _json;

  factory RawResult.fromJson(Map<String, dynamic> json) => RawResult(json);

  @override
  Map<String, dynamic>? get meta =>
      _json['_meta'] as Map<String, dynamic>?;

  @override
  Map<String, dynamic> toJson() => _json;
}

/// Transparent MCP relay: an MCP server on the client-facing [Transport]
/// (stdio in the compiled helper) bridged to the Serlink app's embedded
/// Streamable HTTP MCP server.
///
/// The relay performs no MCP handshakes of its own beyond what the two
/// endpoints require:
///
/// - Toward Serlink it is an [McpClient]; `connect` performs the full
///   negotiation (including the bearer-authenticated HTTP transport), so a
///   successful [connect] proves the app is reachable.
/// - Toward the MCP client it is a low-level [Server] that mirrors the
///   remote server's identity and capabilities, answers `initialize`,
///   `server/discover`, and `ping` locally, and forwards every other
///   request and notification through the generic [Protocol] fallback
///   handlers, preserving method names, params, `_meta`, and result JSON.
///
/// Progress notifications are re-issued toward the MCP client with the
/// original progress token. Protocol-level request timeouts are disabled on
/// forwarded requests because Serlink tool calls can block on user approval
/// dialogs; the MCP client enforces its own timeouts.
///
/// `notifications/cancelled` is intentionally not propagated in either
/// direction: forwarded requests get fresh request ids on the other side,
/// so a forwarded cancellation would match nothing — or worse, collide
/// with an unrelated in-flight request and cancel the wrong operation.
/// Dropping cancellations is a deliberate v1 limitation; wrong-namespace
/// forwarding is worse than not forwarding.
///
/// The local side intentionally uses the low-level `Server` protocol rather
/// than `McpServer`: the relay forwards arbitrary methods generically
/// instead of registering concrete tools, which is the custom protocol
/// implementation case `McpServer` does not cover.
class SerlinkMcpRelay {
  SerlinkMcpRelay._({
    required this._remoteClient,
    required this._localServer,
    required this._log,
  });

  final McpClient _remoteClient;
  final Server _localServer;
  final void Function(String message) _log;
  final Completer<void> _doneCompleter = Completer<void>();
  bool _closed = false;

  /// Connects to the Serlink app at [remoteUrl] with [bearerToken] and
  /// starts serving MCP on [clientSideTransport].
  ///
  /// Throws when the remote server is unreachable or rejects the token; in
  /// that case [clientSideTransport] is left untouched (never started), so
  /// callers can retry with the same transport.
  static Future<SerlinkMcpRelay> connect({
    required Transport clientSideTransport,
    required Uri remoteUrl,
    required String bearerToken,
    void Function(String message)? log,
  }) async {
    final logFn = log ?? (_) {};
    final httpTransport = StreamableHttpClientTransport(
      remoteUrl,
      opts: StreamableHttpClientTransportOptions(
        requestInit: {
          'headers': {'authorization': 'Bearer $bearerToken'},
        },
      ),
    );
    final remoteClient = McpClient(
      const Implementation(name: 'serlink-mcp', version: '1.0.0'),
      options: const McpClientOptions(protocol: McpProtocol.stable),
    );
    try {
      await remoteClient.connect(httpTransport);
    } on Object {
      try {
        await httpTransport.close();
      } on Object {
        // The transport is already broken; nothing to salvage.
      }
      rethrow;
    }

    final remoteVersion = remoteClient.getServerVersion();
    final localServer = Server(
      remoteVersion ?? const Implementation(name: 'serlink', version: '0.0.0'),
      options: McpServerOptions(
        capabilities:
            remoteClient.getServerCapabilities() ?? const ServerCapabilities(),
        protocol: McpProtocol.stable,
      ),
    );
    final relay = SerlinkMcpRelay._(
      remoteClient: remoteClient,
      localServer: localServer,
      log: logFn,
    );

    localServer.fallbackRequestHandler = relay._forwardToRemote;
    localServer.fallbackNotificationHandler =
        relay._forwardNotificationToRemote;
    remoteClient.fallbackRequestHandler = relay._forwardToLocalClient;
    remoteClient.fallbackNotificationHandler =
        relay._forwardNotificationToLocalClient;

    localServer.onclose = () {
      logFn('serlink-mcp: client-side transport closed');
      relay._finish();
    };
    remoteClient.onclose = () {
      logFn('serlink-mcp: connection to Serlink closed');
      relay._finish();
    };

    try {
      await localServer.connect(clientSideTransport);
    } on Object {
      try {
        await remoteClient.close();
      } on Object {
        // Best-effort cleanup of the remote half.
      }
      rethrow;
    }
    logFn('serlink-mcp: relaying to $remoteUrl');
    return relay;
  }

  /// Completes when either side of the relay closes.
  Future<void> get done => _doneCompleter.future;

  /// Closes both sides. Safe to call more than once.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    try {
      await _localServer.close();
    } on Object catch (error) {
      _log('serlink-mcp: error closing local server: $error');
    }
    try {
      await _remoteClient.close();
    } on Object catch (error) {
      _log('serlink-mcp: error closing remote connection: $error');
    }
    _finish();
  }

  void _finish() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  Future<BaseResultData> _forwardToRemote(JsonRpcRequest request) {
    final progressToken = request.meta?['progressToken'];
    return _remoteClient.request(
      request,
      RawResult.fromJson,
      RequestOptions(
        // Serlink tool calls can block on user approval, so only the MCP
        // client's own timeout applies.
        timeoutEnabled: false,
        onprogress: progressToken == null
            ? null
            : (progress) {
                unawaited(
                  _localServer
                      .notification(
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
                        _log('serlink-mcp: failed to forward progress: $error');
                      }),
                );
              },
      ),
    );
  }

  Future<BaseResultData> _forwardToLocalClient(JsonRpcRequest request) {
    return _localServer.request(
      request,
      RawResult.fromJson,
      RequestOptions(timeoutEnabled: false),
    );
  }

  Future<void> _forwardNotificationToRemote(
    JsonRpcNotification notification,
  ) async {
    if (!relayForwardsNotification(notification)) {
      _log(
        'serlink-mcp: dropping ${notification.method} '
        '(cancellation is not propagated across the relay)',
      );
      return;
    }
    await _remoteClient.notification(notification);
  }

  Future<void> _forwardNotificationToLocalClient(
    JsonRpcNotification notification,
  ) async {
    if (!relayForwardsNotification(notification)) {
      _log(
        'serlink-mcp: dropping ${notification.method} '
        '(cancellation is not propagated across the relay)',
      );
      return;
    }
    await _localServer.notification(notification);
  }
}

/// Whether the relay forwards [notification] to the other side.
///
/// `notifications/cancelled` is intentionally not propagated: forwarded
/// requests get fresh request ids on the other side, so a forwarded
/// cancellation would match nothing — or worse, collide with an unrelated
/// in-flight request and cancel the wrong operation. Dropping cancellations
/// is a deliberate v1 limitation; wrong-namespace forwarding is worse than
/// not forwarding.
bool relayForwardsNotification(JsonRpcNotification notification) {
  return notification.method != Method.notificationsCancelled;
}
