/// serlink-mcp — standalone stdio MCP server for the Serlink desktop app.
///
/// MCP clients (e.g. Claude Code) launch this helper as a stdio MCP server.
/// It handles discovery, initialization, ping and tool enumeration itself.
/// Only tool calls connect to the desktop app's loopback HTTP endpoint,
/// launching the app on demand if it is not running.
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

import 'src/app_connection.dart';
import 'src/relay.dart';

const _usage = '''
serlink-mcp — standalone stdio MCP server for the Serlink desktop app.

Usage: serlink-mcp [--discovery <path>] [--connect-timeout <seconds>]

Options:
  --discovery <path>       Explicit path to the mcp-server.json discovery file.
  --connect-timeout <secs> Wait for Serlink on a tool call (default 60 seconds).
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

  final relay = await SerlinkMcpRelay.start(
    clientSideTransport: StdioServerTransport(stdin: stdin, stdout: stdout),
    connection: SerlinkAppConnection(
      environment: Platform.environment,
      discoveryArg: parsed.discoveryPath,
      timeout: Duration(seconds: parsed.connectTimeoutSeconds),
      log: _log,
    ),
    log: _log,
  );

  final signalSubscriptions = <StreamSubscription<void>>[
    ProcessSignal.sigint.watch().listen((_) => unawaited(relay.close())),
    ProcessSignal.sigterm.watch().listen((_) => unawaited(relay.close())),
  ];
  await relay.done;
  await relay.close();
  for (final subscription in signalSubscriptions) {
    await subscription.cancel();
  }
  exit(0);
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
