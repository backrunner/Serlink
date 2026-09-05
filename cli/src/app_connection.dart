import 'dart:async';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

import 'discovery.dart';

/// Connects to the desktop backend only when a tool needs app-owned data.
/// Concurrent callers share one discovery/launch operation. Closing the helper
/// cancels polling and closes any handshake still in flight.
class SerlinkAppConnection {
  SerlinkAppConnection({
    required this.environment,
    this.discoveryArg,
    this.timeout = const Duration(seconds: 60),
    this.pollInterval = const Duration(milliseconds: 500),
    this.attemptTimeout = const Duration(seconds: 3),
    this.launchApp,
    void Function(String message)? log,
  }) : _log = log ?? ((_) {});

  final Map<String, String> environment;
  final String? discoveryArg;
  final Duration timeout;
  final Duration pollInterval;
  final Duration attemptTimeout;
  final Future<void> Function()? launchApp;
  final void Function(String message) _log;
  final Completer<void> _closed = Completer<void>();
  McpClient? _client;
  McpClient? _attemptClient;
  Future<McpClient>? _connecting;

  Future<McpClient> connect(Implementation clientInfo) async {
    _checkOpen();
    final client = _client;
    if (client != null) {
      return client;
    }
    final pending = _connecting;
    if (pending != null) {
      return pending;
    }
    final connecting = _connect(clientInfo);
    _connecting = connecting;
    try {
      return await connecting;
    } finally {
      _connecting = null;
    }
  }

  Future<McpClient> _connect(Implementation clientInfo) async {
    final watch = Stopwatch()..start();
    var launched = false;
    String? lastError;
    while (watch.elapsed < timeout) {
      _checkOpen();
      // Recheck every candidate on each pass, including when an older path
      // contains a stale discovery file and the app writes a different one.
      final explicit = environment['SERLINK_MCP_DISCOVERY'];
      final path = explicit != null && explicit.isNotEmpty
          ? explicit
          : discoveryArg;
      final candidates = path != null && path.isNotEmpty
          ? [path]
          : defaultDiscoveryCandidates(environment);
      if (candidates.isEmpty) {
        throw StateError(
          'Cannot locate Serlink: set HOME, --discovery, or '
          'SERLINK_MCP_DISCOVERY.',
        );
      }
      for (final candidate in candidates) {
        _checkOpen();
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) {
          break;
        }
        try {
          final client = await _tryConnect(
            candidate,
            clientInfo,
            remaining < attemptTimeout ? remaining : attemptTimeout,
          );
          _checkOpen();
          _client = client;
          client.onclose = () {
            if (identical(_client, client)) {
              _client = null;
            }
          };
          return client;
        } on Object catch (error) {
          _checkOpen();
          if ('$error' != lastError) {
            lastError = '$error';
            _log('serlink-mcp: waiting for Serlink: $lastError');
          }
        }
      }
      _checkOpen();
      var remaining = timeout - watch.elapsed;
      if (remaining <= Duration.zero) {
        break;
      }
      if (!launched) {
        launched = true;
        _log('serlink-mcp: tool requested; launching Serlink');
        await Future.any<void>([
          (launchApp?.call() ?? _launchDesktop()).timeout(remaining),
          _closed.future,
        ]);
        _checkOpen();
      }
      remaining = timeout - watch.elapsed;
      if (remaining > Duration.zero) {
        await Future.any<void>([
          Future<void>.delayed(
            remaining < pollInterval ? remaining : pollInterval,
          ),
          _closed.future,
        ]);
      }
    }
    _checkOpen();
    throw TimeoutException(
      'Could not connect to Serlink. Check that the app is installed and '
      'its agent server is enabled.',
      timeout,
    );
  }

  Future<McpClient> _tryConnect(
    String path,
    Implementation clientInfo,
    Duration timeout,
  ) async {
    final watch = Stopwatch()..start();
    final info = await DiscoveryInfo.readFile(path).timeout(timeout);
    _checkOpen();
    final remaining = timeout - watch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Reading Serlink discovery timed out.', timeout);
    }
    final transport = StreamableHttpClientTransport(
      info.url,
      opts: StreamableHttpClientTransportOptions(
        requestInit: {
          'headers': {'authorization': 'Bearer ${info.token}'},
        },
      ),
    );
    final client = McpClient(
      clientInfo,
      options: const McpClientOptions(protocol: McpProtocol.stable),
    );
    _attemptClient = client;
    try {
      await client.connect(transport).timeout(remaining);
      _checkOpen();
      return client;
    } on Object {
      await client.close();
      rethrow;
    } finally {
      _attemptClient = null;
    }
  }

  /// Discard a broken connection. Never replay a tool call: a command may
  /// already have executed before the transport reported its failure.
  Future<void> invalidate(McpClient client) async {
    if (identical(_client, client)) {
      _client = null;
    }
    await client.close();
  }

  Future<void> close() async {
    if (_closed.isCompleted) {
      return;
    }
    _closed.complete();
    final client = _client;
    final attempt = _attemptClient;
    _client = null;
    try {
      await attempt?.close();
    } finally {
      await client?.close();
    }
  }

  void _checkOpen() {
    if (_closed.isCompleted) {
      throw StateError('Serlink app connection is closed');
    }
  }

  Future<void> _launchDesktop() async {
    if (!Platform.isMacOS) {
      throw UnsupportedError(
        'Automatic app launch is only supported on macOS.',
      );
    }
    final app = environment['SERLINK_APP_PATH'];
    final target = app != null && app.isNotEmpty ? app : 'Serlink';
    // Keep the caller focused while Serlink starts for an actual tool call.
    final result = await Process.run('open', ['-g', '-a', target]);
    if (result.exitCode != 0) {
      throw StateError(
        'Could not launch Serlink (open exited ${result.exitCode}).',
      );
    }
  }
}
