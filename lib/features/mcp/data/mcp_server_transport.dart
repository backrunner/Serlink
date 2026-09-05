import 'package:mcp_dart/mcp_dart.dart';

/// Loopback-only Streamable HTTP transport for the embedded MCP server.
///
/// Binds `127.0.0.1` on a random port, requires a per-run bearer token, and
/// keeps the package's DNS-rebinding protection enabled with an explicit
/// loopback host allowlist.
class McpServerTransport {
  McpServerTransport({
    required McpServer Function(String sessionId) serverFactory,
    required String bearerToken,
  }) : _server = StreamableMcpServer(
         serverFactory: serverFactory,
         host: '127.0.0.1',
         port: 0,
         path: '/mcp',
         eventStore: InMemoryEventStore(),
         authenticator: (request) {
           // Plain string compare is acceptable on a loopback-only server
           // with a random per-run token.
           return request.headers.value('authorization') ==
               'Bearer $bearerToken';
         },
         allowedHosts: const {'127.0.0.1', 'localhost'},
       );

  final StreamableMcpServer _server;

  Future<void> start() => _server.start();

  /// Actual bound port (the server is configured with port 0).
  int get port => _server.boundPort;

  Future<void> stop() => _server.stop();
}
