/// serlink-mcp — stdio MCP relay for the Serlink desktop app.
///
/// MCP clients (e.g. Claude Code) launch this helper as a stdio MCP server.
/// It discovers the running Serlink app's loopback Streamable HTTP endpoint
/// from the app's discovery file and transparently relays JSON-RPC/MCP
/// messages between stdio and that endpoint, launching the app when it is
/// not running.
///
/// All diagnostics go to stderr; stdout is the MCP protocol channel.
///
/// Flags:
///   --discovery `path`       Explicit path to the discovery file
///                            (mcp-server.json).
///   --connect-timeout `secs` Seconds to wait for the app to start and accept
///                            connections (default 60).
///   --version                Print the helper version to stderr and exit 0.
///   --help                   Print usage to stderr and exit 0.
///
/// Environment:
///   SERLINK_MCP_DISCOVERY    Discovery file path; wins over --discovery.
///   SERLINK_APP_PATH         App name or .app path passed to `open -a`
///                            (default: Serlink).
library;

import 'dart:async';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

import 'src/discovery.dart';
import 'src/relay.dart';

const _usage = '''
serlink-mcp — stdio MCP relay for the Serlink desktop app.

Usage: serlink-mcp [--discovery <path>] [--connect-timeout <seconds>]

Options:
  --discovery <path>       Explicit path to the mcp-server.json discovery file.
  --connect-timeout <secs> Seconds to wait for Serlink to start (default 60).
  --version                Print the helper version.
  --help                   Show this message.

Environment:
  SERLINK_MCP_DISCOVERY    Discovery file path (overrides --discovery).
  SERLINK_APP_PATH         App name or path for `open -a` (default: Serlink).
''';

/// Version reported by `--version`.
const serlinkMcpVersion = '1.0.0';

void _log(String message) => stderr.writeln(message);

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    stderr.write(_usage);
    exit(2);
  }
  if (parsed.help) {
    stderr.write(_usage);
    exit(0);
  }
  if (parsed.version) {
    stderr.writeln('serlink-mcp $serlinkMcpVersion');
    exit(0);
  }

  // The MCP SDK logs verbosely to stderr by default; keep only warnings and
  // errors so stderr stays useful without drowning real problems in noise.
  setMcpLogHandler((loggerName, level, message) {
    if (level == LogLevel.warn || level == LogLevel.error) {
      _log('[$loggerName] $message');
    }
  });

  final environment = Platform.environment;
  final discoveryPath = resolveDiscoveryPath(
    environment: environment,
    discoveryArg: parsed.discoveryPath,
  );
  if (discoveryPath == null) {
    _log(
      'serlink-mcp: cannot locate the Serlink discovery file: HOME is not '
      'set and no --discovery path was given.',
    );
    exit(1);
  }

  final timeout = Duration(seconds: parsed.connectTimeoutSeconds);
  // A single stdio transport reused across connect attempts: it is only
  // started once a remote connection succeeds, so failed attempts leave it
  // untouched.
  final stdioTransport = StdioServerTransport(stdin: stdin, stdout: stdout);

  var attempt = await _tryConnect(stdioTransport, discoveryPath);
  if (attempt.error != null) {
    _log('serlink-mcp: ${attempt.error}');
  }
  var relay = attempt.relay;
  if (relay == null) {
    _log(
      'serlink-mcp: launching Serlink and waiting up to '
      '${timeout.inSeconds}s for its MCP server...',
    );
    await _launchApp(environment);
    relay = await pollForRelay(
      stdioTransport: stdioTransport,
      environment: environment,
      discoveryArg: parsed.discoveryPath,
      timeout: timeout,
    );
  }

  if (relay == null) {
    _log(
      'serlink-mcp: could not connect to the Serlink MCP server within '
      '${timeout.inSeconds}s. Is the Serlink app installed and able to '
      'start? Discovery file: $discoveryPath',
    );
    exit(1);
  }

  final signalSubscriptions = <StreamSubscription<void>>[
    ProcessSignal.sigint.watch().listen((_) => unawaited(relay!.close())),
    ProcessSignal.sigterm.watch().listen((_) => unawaited(relay!.close())),
  ];
  await relay.done;
  await relay.close();
  for (final subscription in signalSubscriptions) {
    await subscription.cancel();
  }
  exit(0);
}

/// Polls for the app to come up and connects the relay, returning null when
/// [timeout] elapses first.
///
/// Every iteration re-resolves the discovery path so a discovery file that
/// appears at ANY default candidate is picked up — the app may write either
/// candidate directory regardless of which one existed (or was missing) at
/// helper startup. An explicit `SERLINK_MCP_DISCOVERY`/`--discovery` path
/// is honored unchanged.
Future<SerlinkMcpRelay?> pollForRelay({
  required Transport stdioTransport,
  required Map<String, String> environment,
  String? discoveryArg,
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 500),
  void Function(String message)? log,
}) async {
  final logFn = log ?? _log;
  final deadline = DateTime.now().add(timeout);
  String? lastError;
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(pollInterval);
    final candidatePath = resolveDiscoveryPath(
      environment: environment,
      discoveryArg: discoveryArg,
    );
    if (candidatePath == null) {
      continue;
    }
    final attempt = await _tryConnect(stdioTransport, candidatePath);
    final relay = attempt.relay;
    if (relay != null) {
      return relay;
    }
    if (attempt.error != null && attempt.error != lastError) {
      lastError = attempt.error;
      logFn('serlink-mcp: still waiting: $lastError');
    }
  }
  return null;
}

/// Reads the discovery file and attempts one relay connection. On failure
/// the relay is null and [error] describes the reason.
Future<({SerlinkMcpRelay? relay, String? error})> _tryConnect(
  Transport stdioTransport,
  String discoveryPath,
) async {
  final DiscoveryInfo info;
  try {
    info = await DiscoveryInfo.readFile(discoveryPath);
  } on Object catch (error) {
    return (
      relay: null,
      error: 'cannot read discovery file $discoveryPath: $error',
    );
  }
  try {
    final relay = await SerlinkMcpRelay.connect(
      clientSideTransport: stdioTransport,
      remoteUrl: info.url,
      bearerToken: info.token,
      log: _log,
    );
    return (relay: relay, error: null);
  } on Object catch (error) {
    return (relay: null, error: 'connect to ${info.url} failed: $error');
  }
}

Future<void> _launchApp(Map<String, String> environment) async {
  if (!Platform.isMacOS) {
    _log('serlink-mcp: automatic app launch is only supported on macOS.');
    return;
  }
  final app = environment['SERLINK_APP_PATH'];
  final target = (app != null && app.isNotEmpty) ? app : 'Serlink';
  try {
    // -g opens the app in the background so it does not steal focus from
    // whatever the user is doing when the MCP client spawns this helper.
    final process = await Process.start('open', ['-g', '-a', target]);
    final code = await process.exitCode;
    if (code != 0) {
      _log('serlink-mcp: `open -a $target` exited with code $code.');
    }
  } on Object catch (error) {
    _log('serlink-mcp: failed to launch Serlink via `open -a $target`: $error');
  }
}

({bool help, bool version, String? discoveryPath, int connectTimeoutSeconds})?
_parseArgs(List<String> args) {
  var help = false;
  var version = false;
  String? discoveryPath;
  var connectTimeoutSeconds = 60;
  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    String? value;
    if (i + 1 < args.length) {
      value = args[i + 1];
    }
    switch (arg) {
      case '--help' || '-h':
        help = true;
      case '--version':
        version = true;
      case '--discovery':
        if (value == null) {
          return null;
        }
        discoveryPath = value;
        i++;
      case '--connect-timeout':
        final seconds = value == null ? null : int.tryParse(value);
        if (seconds == null || seconds <= 0) {
          return null;
        }
        connectTimeoutSeconds = seconds;
        i++;
      default:
        return null;
    }
    i++;
  }
  return (
    help: help,
    version: version,
    discoveryPath: discoveryPath,
    connectTimeoutSeconds: connectTimeoutSeconds,
  );
}
