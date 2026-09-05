import 'dart:convert';
import 'dart:io';

/// Parsed contents of the Serlink MCP discovery file (`mcp-server.json`).
///
/// The direct-distribution Serlink app writes this file to its application
/// support directory on startup so stdio helpers can find the loopback
/// Streamable HTTP endpoint and its per-run bearer token.
class DiscoveryInfo {
  const DiscoveryInfo({required this.url, required this.token, this.pid});

  /// Streamable HTTP endpoint, e.g. `http://127.0.0.1:<port>/mcp`.
  final Uri url;

  /// Per-run bearer token required in the `Authorization` header.
  final String token;

  /// PID of the app process that wrote the file, when present.
  final int? pid;

  factory DiscoveryInfo.fromJson(Map<String, dynamic> json) {
    final urlValue = json['url'];
    if (urlValue is! String || urlValue.isEmpty) {
      throw const FormatException('discovery file is missing "url"');
    }
    final url = Uri.tryParse(urlValue);
    if (url == null || !_isAllowedEndpoint(url)) {
      throw FormatException('discovery file has an invalid "url": $urlValue');
    }
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('discovery file is missing "token"');
    }
    final pid = json['pid'];
    return DiscoveryInfo(url: url, token: token, pid: pid is int ? pid : null);
  }

  /// Discovery files are local trust-boundary inputs. The bearer token must
  /// never be sent to a remote host, redirected endpoint, or another URL
  /// scheme, even if a stale or tampered file contains one.
  static bool _isAllowedEndpoint(Uri url) {
    return url.scheme == 'http' &&
        const {'127.0.0.1', 'localhost', '::1'}.contains(url.host) &&
        url.userInfo.isEmpty &&
        url.path == '/mcp' &&
        url.query.isEmpty &&
        url.fragment.isEmpty;
  }

  /// Parses the discovery file contents, throwing [FormatException] on
  /// malformed JSON or missing/invalid fields.
  static DiscoveryInfo parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('discovery file must contain a JSON object');
    }
    return DiscoveryInfo.fromJson(decoded);
  }

  /// Reads and parses the discovery file at [path].
  ///
  /// Throws [FileSystemException] when the file is missing or unreadable and
  /// [FormatException] when the contents are malformed.
  static Future<DiscoveryInfo> readFile(String path) async {
    return parse(await File(path).readAsString());
  }
}

/// Default discovery file candidates, in priority order.
///
/// The first matches the bundle identifier (`com.alkinum.serlink`), the
/// second the application support directory name older builds used.
List<String> defaultDiscoveryCandidates(Map<String, String> environment) {
  final home = environment['HOME'];
  if (home == null || home.isEmpty) {
    return const [];
  }
  return [
    '$home/Library/Application Support/com.alkinum.serlink/mcp-server.json',
    '$home/Library/Application Support/Serlink/mcp-server.json',
  ];
}

/// Resolves the discovery file path. First match wins:
///
/// 1. `SERLINK_MCP_DISCOVERY` environment variable,
/// 2. the `--discovery` CLI argument ([discoveryArg]),
/// 3. the first existing default candidate, falling back to the first
///    candidate even when it does not exist yet (so callers can poll for it
///    after launching the app).
///
/// Returns null when no explicit path is given and no candidates can be
/// derived (e.g. `HOME` is unset).
String? resolveDiscoveryPath({
  required Map<String, String> environment,
  String? discoveryArg,
}) {
  final fromEnv = environment['SERLINK_MCP_DISCOVERY'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (discoveryArg != null && discoveryArg.isNotEmpty) {
    return discoveryArg;
  }
  final candidates = defaultDiscoveryCandidates(environment);
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return candidates.isEmpty ? null : candidates.first;
}
