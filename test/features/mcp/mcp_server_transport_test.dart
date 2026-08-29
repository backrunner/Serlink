import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:serlink/features/mcp/data/mcp_server_transport.dart';

void main() {
  group('McpServerTransport', () {
    test('binds a random loopback port', () async {
      final transport = _transport('token-a');
      addTearDown(transport.stop);
      await transport.start();

      expect(transport.port, greaterThan(0));
    });

    test('accepts tool calls with the correct bearer token', () async {
      final transport = _transport('secret-token');
      addTearDown(transport.stop);
      await transport.start();

      final client = McpClient(
        const Implementation(name: 'test-client', version: '1.0.0'),
        options: const McpClientOptions(protocol: McpProtocol.stable),
      );
      final clientTransport = StreamableHttpClientTransport(
        Uri.parse('http://127.0.0.1:${transport.port}/mcp'),
        opts: const StreamableHttpClientTransportOptions(
          requestInit: {
            'headers': {'authorization': 'Bearer secret-token'},
          },
        ),
      );
      await client.connect(clientTransport);
      addTearDown(client.close);

      final result = await client.callTool(
        CallToolRequest(name: 'echo', arguments: {'text': 'hello'}),
      );
      final content = result.content.single;
      expect(content, isA<TextContent>());
      expect((content as TextContent).text, 'echo:hello');
      expect(result.isError, isFalse);
    });

    test('rejects requests without a valid bearer token', () async {
      final transport = _transport('secret-token');
      addTearDown(transport.stop);
      await transport.start();
      final httpClient = HttpClient();
      addTearDown(httpClient.close);

      Future<HttpClientResponse> post(String? authorization) async {
        final request = await httpClient.postUrl(
          Uri.parse('http://127.0.0.1:${transport.port}/mcp'),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set('accept', 'application/json, text/event-stream');
        if (authorization != null) {
          request.headers.set('authorization', authorization);
        }
        request.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {
              'protocolVersion': '2025-03-26',
              'capabilities': <String, Object?>{},
              'clientInfo': {'name': 'probe', 'version': '1.0.0'},
            },
          }),
        );
        return request.close();
      }

      // Without OAuth protected-resource metadata the package preserves its
      // historical behavior and answers failed authenticator checks with
      // 403 Forbidden rather than a 401 bearer challenge.
      final missing = await post(null);
      expect(missing.statusCode, HttpStatus.forbidden);
      await missing.drain<void>();

      final wrong = await post('Bearer wrong-token');
      expect(wrong.statusCode, HttpStatus.forbidden);
      await wrong.drain<void>();
    });

    test('client connect fails with a wrong bearer token', () async {
      final transport = _transport('secret-token');
      addTearDown(transport.stop);
      await transport.start();

      final client = McpClient(
        const Implementation(name: 'test-client', version: '1.0.0'),
        options: const McpClientOptions(protocol: McpProtocol.stable),
      );
      final clientTransport = StreamableHttpClientTransport(
        Uri.parse('http://127.0.0.1:${transport.port}/mcp'),
        opts: const StreamableHttpClientTransportOptions(
          requestInit: {
            'headers': {'authorization': 'Bearer wrong-token'},
          },
        ),
      );

      await expectLater(
        client.connect(clientTransport),
        throwsA(anything),
      );
    });
  });
}

McpServerTransport _transport(String token) {
  return McpServerTransport(
    bearerToken: token,
    serverFactory: (_) => _echoServer(),
  );
}

McpServer _echoServer() {
  final server = McpServer(
    const Implementation(name: 'echo-server', version: '0.0.1'),
    options: const McpServerOptions(protocol: McpProtocol.stable),
  );
  server.registerTool(
    'echo',
    description: 'Echoes the text argument back.',
    inputSchema: JsonSchema.object(
      properties: {'text': JsonSchema.string()},
      required: ['text'],
    ),
    callback: (args, extra) async {
      return CallToolResult.fromContent([
        TextContent(text: 'echo:${args['text']}'),
      ]);
    },
  );
  return server;
}
