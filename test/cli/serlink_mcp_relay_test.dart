import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:serlink/features/mcp/data/mcp_server_transport.dart';

import '../../cli/serlink_mcp.dart';
import '../../cli/src/discovery.dart';
import '../../cli/src/relay.dart';

void main() {
  group('DiscoveryInfo', () {
    test('parses a valid discovery file', () {
      final info = DiscoveryInfo.parse(
        '{"url": "http://127.0.0.1:5123/mcp", "token": "abc", "pid": 42}',
      );

      expect(info.url, Uri.parse('http://127.0.0.1:5123/mcp'));
      expect(info.token, 'abc');
      expect(info.pid, 42);
    });

    test('tolerates a missing pid', () {
      final info = DiscoveryInfo.parse(
        '{"url": "http://127.0.0.1:5123/mcp", "token": "abc"}',
      );

      expect(info.pid, isNull);
    });

    test('rejects malformed JSON', () {
      expect(
        () => DiscoveryInfo.parse('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-object document', () {
      expect(
        () => DiscoveryInfo.parse('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing url', () {
      expect(
        () => DiscoveryInfo.parse('{"token": "abc"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing token', () {
      expect(
        () => DiscoveryInfo.parse('{"url": "http://127.0.0.1:1/mcp"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an invalid url', () {
      expect(
        () => DiscoveryInfo.parse('{"url": "::", "token": "abc"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('readFile throws for a missing file', () async {
      final dir = await Directory.systemTemp.createTemp('serlink-mcp-test');
      addTearDown(() => dir.delete(recursive: true));

      expect(
        DiscoveryInfo.readFile('${dir.path}/mcp-server.json'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('resolveDiscoveryPath', () {
    test('prefers the SERLINK_MCP_DISCOVERY environment variable', () {
      final path = resolveDiscoveryPath(
        environment: const {
          'SERLINK_MCP_DISCOVERY': '/tmp/from-env.json',
          'HOME': '/nonexistent',
        },
        discoveryArg: '/tmp/from-arg.json',
      );

      expect(path, '/tmp/from-env.json');
    });

    test('falls back to the --discovery argument', () {
      final path = resolveDiscoveryPath(
        environment: const {'HOME': '/nonexistent'},
        discoveryArg: '/tmp/from-arg.json',
      );

      expect(path, '/tmp/from-arg.json');
    });

    test('uses the first existing default candidate', () async {
      final dir = await Directory.systemTemp.createTemp('serlink-mcp-test');
      addTearDown(() => dir.delete(recursive: true));
      final candidateDir = Directory(
        '${dir.path}/Library/Application Support/Serlink',
      );
      await candidateDir.create(recursive: true);
      final candidate = '${candidateDir.path}/mcp-server.json';
      await File(candidate).writeAsString('{}');

      final path = resolveDiscoveryPath(environment: {'HOME': dir.path});

      expect(path, candidate);
    });

    test('returns the first candidate when none exist yet', () {
      final path = resolveDiscoveryPath(
        environment: const {'HOME': '/definitely/not/there'},
      );

      expect(
        path,
        '/definitely/not/there/Library/Application Support/'
        'com.alkinum.serlink/mcp-server.json',
      );
    });

    test('returns null when HOME is unset', () {
      expect(resolveDiscoveryPath(environment: const {}), isNull);
    });
  });

  group('SerlinkMcpRelay', () {
    test('relays tools/list and tools/call to the embedded server', () async {
      final server = await _startEchoServer('relay-token');
      addTearDown(server.stop);

      final pair = _MemoryTransport.pair();
      final relay = await SerlinkMcpRelay.connect(
        clientSideTransport: pair.$1,
        remoteUrl: _serverUrl(server),
        bearerToken: 'relay-token',
        log: (_) {},
      );
      addTearDown(relay.close);

      final client = McpClient(
        const Implementation(name: 'test-client', version: '1.0.0'),
        options: const McpClientOptions(protocol: McpProtocol.legacy),
      );
      await client.connect(pair.$2);
      addTearDown(client.close);

      final tools = await client.listTools();
      expect(tools.tools.map((tool) => tool.name), contains('echo'));

      final result = await client.callTool(
        CallToolRequest(name: 'echo', arguments: {'text': 'hello'}),
      );
      final content = result.content.single;
      expect(content, isA<TextContent>());
      expect((content as TextContent).text, 'echo:hello');
      expect(result.isError, isFalse);
    });

    test('relays remote tool errors back to the caller', () async {
      final server = await _startEchoServer('relay-token');
      addTearDown(server.stop);

      final pair = _MemoryTransport.pair();
      final relay = await SerlinkMcpRelay.connect(
        clientSideTransport: pair.$1,
        remoteUrl: _serverUrl(server),
        bearerToken: 'relay-token',
        log: (_) {},
      );
      addTearDown(relay.close);

      final client = McpClient(
        const Implementation(name: 'test-client', version: '1.0.0'),
        options: const McpClientOptions(protocol: McpProtocol.legacy),
      );
      await client.connect(pair.$2);
      addTearDown(client.close);

      // The embedded server maps tool exceptions to an error CallToolResult;
      // the relay must pass that shape through untouched.
      final result = await client.callTool(
        CallToolRequest(name: 'boom', arguments: const {}),
      );
      expect(result.isError, isTrue);
      expect(result.content.single, isA<TextContent>());
    });

    test('mirrors the remote server identity and capabilities', () async {
      final server = await _startEchoServer('relay-token');
      addTearDown(server.stop);

      final pair = _MemoryTransport.pair();
      final relay = await SerlinkMcpRelay.connect(
        clientSideTransport: pair.$1,
        remoteUrl: _serverUrl(server),
        bearerToken: 'relay-token',
        log: (_) {},
      );
      addTearDown(relay.close);

      final client = McpClient(
        const Implementation(name: 'test-client', version: '1.0.0'),
        options: const McpClientOptions(protocol: McpProtocol.legacy),
      );
      await client.connect(pair.$2);
      addTearDown(client.close);

      expect(client.getServerVersion()?.name, 'echo-server');
      expect(client.getServerCapabilities()?.tools, isNotNull);
    });

    test('connect fails with a wrong bearer token', () async {
      final server = await _startEchoServer('relay-token');
      addTearDown(server.stop);

      final pair = _MemoryTransport.pair();
      await expectLater(
        SerlinkMcpRelay.connect(
          clientSideTransport: pair.$1,
          remoteUrl: _serverUrl(server),
          bearerToken: 'wrong-token',
          log: (_) {},
        ),
        throwsA(anything),
      );
    });

    test('relayForwardsNotification drops only cancellations', () {
      expect(
        relayForwardsNotification(
          JsonRpcNotification(
            method: Method.notificationsCancelled,
            params: const {'requestId': 1},
          ),
        ),
        isFalse,
      );
      expect(
        relayForwardsNotification(
          JsonRpcNotification(method: 'custom/probe'),
        ),
        isTrue,
      );
    });

    test(
      'a cancelled notification through the relay never reaches the remote',
      () async {
        final remoteNotifications = <JsonRpcNotification>[];
        final server = await _startEchoServer(
          'relay-token',
          onNotification: remoteNotifications.add,
        );
        addTearDown(server.stop);

        final pair = _MemoryTransport.pair();
        final relay = await SerlinkMcpRelay.connect(
          clientSideTransport: pair.$1,
          remoteUrl: _serverUrl(server),
          bearerToken: 'relay-token',
          log: (_) {},
        );
        addTearDown(relay.close);

        final client = McpClient(
          const Implementation(name: 'test-client', version: '1.0.0'),
          options: const McpClientOptions(protocol: McpProtocol.legacy),
        );
        await client.connect(pair.$2);
        addTearDown(client.close);

        // Forwarded requests get fresh remote-side request ids, so a
        // forwarded cancellation would match nothing — or collide with an
        // unrelated in-flight remote request. It must not cross the relay.
        await pair.$2.send(
          JsonRpcNotification(
            method: Method.notificationsCancelled,
            params: const {'requestId': 999, 'reason': 'client gave up'},
          ),
        );
        // Give the relay a chance to (wrongly) forward it.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(remoteNotifications, isEmpty);

        // The dropped notification must not disturb the relay.
        final result = await client.callTool(
          CallToolRequest(name: 'echo', arguments: {'text': 'still alive'}),
        );
        final content = result.content.single;
        expect(content, isA<TextContent>());
        expect((content as TextContent).text, 'echo:still alive');
      },
    );
  });

  group('pollForRelay', () {
    test(
      'picks up a discovery file appearing at the second default candidate',
      () async {
        final dir = await Directory.systemTemp.createTemp('serlink-mcp-test');
        addTearDown(() => dir.delete(recursive: true));
        final server = await _startEchoServer('relay-token');
        addTearDown(server.stop);

        // Only the SECOND candidate (`Application Support/Serlink`) gets the
        // discovery file, shortly after polling starts; the first candidate
        // never exists. The poll loop must re-check all candidates instead
        // of re-reading only the one resolved at startup.
        final secondCandidate =
            '${dir.path}/Library/Application Support/Serlink/mcp-server.json';
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 300), () async {
            final file = File(secondCandidate);
            await file.create(recursive: true);
            await file.writeAsString(
              '{"url": "${_serverUrl(server)}", "token": "relay-token"}',
            );
          }),
        );

        final pair = _MemoryTransport.pair();
        final relay = await pollForRelay(
          stdioTransport: pair.$1,
          environment: {'HOME': dir.path},
          timeout: const Duration(seconds: 10),
          pollInterval: const Duration(milliseconds: 100),
          log: (_) {},
        );
        addTearDown(() async => relay?.close());

        expect(relay, isNotNull);
      },
    );

    test('times out when no discovery file ever appears', () async {
      final dir = await Directory.systemTemp.createTemp('serlink-mcp-test');
      addTearDown(() => dir.delete(recursive: true));

      final pair = _MemoryTransport.pair();
      final relay = await pollForRelay(
        stdioTransport: pair.$1,
        environment: {'HOME': dir.path},
        timeout: const Duration(milliseconds: 300),
        pollInterval: const Duration(milliseconds: 50),
        log: (_) {},
      );

      expect(relay, isNull);
    });
  });
}

Uri _serverUrl(McpServerTransport transport) {
  return Uri.parse('http://127.0.0.1:${transport.port}/mcp');
}

Future<McpServerTransport> _startEchoServer(
  String token, {
  void Function(JsonRpcNotification notification)? onNotification,
}) async {
  final transport = McpServerTransport(
    bearerToken: token,
    serverFactory: (_) {
      final server = McpServer(
        const Implementation(name: 'echo-server', version: '0.0.1'),
        options: const McpServerOptions(protocol: McpProtocol.stable),
      );
      if (onNotification != null) {
        // Records every notification the remote side receives that has no
        // specific protocol handler, so tests can assert what crossed the
        // relay.
        server.server.fallbackNotificationHandler = (notification) async {
          onNotification(notification);
        };
      }
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
      server.registerTool(
        'boom',
        description: 'Always fails.',
        inputSchema: JsonSchema.object(),
        callback: (args, extra) async {
          throw StateError('boom');
        },
      );
      return server;
    },
  );
  await transport.start();
  return transport;
}

/// In-memory [Transport] pair used in place of the stdio transport so the
/// relay can be exercised in-process.
class _MemoryTransport implements Transport {
  _MemoryTransport();

  final StreamController<JsonRpcMessage> _incoming =
      StreamController<JsonRpcMessage>();
  late final _MemoryTransport _peer;
  StreamSubscription<JsonRpcMessage>? _subscription;
  bool _closed = false;

  static (_MemoryTransport, _MemoryTransport) pair() {
    final first = _MemoryTransport();
    final second = _MemoryTransport();
    first._peer = second;
    second._peer = first;
    return (first, second);
  }

  @override
  void Function()? onclose;

  @override
  void Function(Error error)? onerror;

  @override
  void Function(JsonRpcMessage message)? onmessage;

  @override
  String? get sessionId => null;

  @override
  Future<void> start() async {
    _subscription = _incoming.stream.listen(
      (message) => onmessage?.call(message),
      onDone: () => unawaited(close()),
    );
  }

  @override
  Future<void> send(JsonRpcMessage message, {int? relatedRequestId}) async {
    if (_closed || _peer._closed) {
      throw StateError('transport closed');
    }
    _peer._incoming.add(message);
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    if (!_peer._closed) {
      unawaited(_peer._incoming.close());
    }
    onclose?.call();
  }
}
