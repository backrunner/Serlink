import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:serlink/features/mcp/data/mcp_server_transport.dart';

import 'package:serlink/features/mcp/domain/mcp_contract.dart';

import '../../cli/src/app_connection.dart';
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

    test('rejects non-loopback discovery endpoints', () {
      for (final url in [
        'https://127.0.0.1:5123/mcp',
        'http://192.0.2.1:5123/mcp',
        'http://127.0.0.1:5123/mcp?redirect=1',
        'http://user:secret@127.0.0.1:5123/mcp',
      ]) {
        expect(
          () => DiscoveryInfo.parse('{"url": "$url", "token": "abc"}'),
          throwsA(isA<FormatException>()),
          reason: url,
        );
      }
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

  _relayTests();
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

void _relayTests() {
  group('Standalone MCP server', () {
    for (final protocol in [McpProtocol.legacy, McpProtocol.stable]) {
      test('serves $protocol probes without discovery or app launch', () async {
        var launches = 0;
        final harness = await _startRelay(
          SerlinkAppConnection(
            environment: const {},
            launchApp: () async => launches++,
          ),
          protocol: protocol,
        );

        expect(harness.client.getServerVersion()?.name, 'serlink');
        expect(harness.client.getServerCapabilities()?.tools, isNotNull);
        expect(harness.client.getInstructions(), serlinkMcpInstructions);
        final tools = await harness.client.listTools();
        expect(
          tools.tools.map((tool) => tool.name),
          unorderedEquals(serlinkMcpTools.keys),
        );
        if (protocol == McpProtocol.legacy) {
          await harness.client.ping();
        } else {
          // Stateless MCP uses server/discover for availability checks.
          await harness.client.discoverServer();
        }
        expect(launches, 0);
        await harness.client.close();
        await harness.relay.done.timeout(const Duration(seconds: 1));
        expect(launches, 0);
      });
    }

    test('invalid tools and arguments never launch the app', () async {
      var launches = 0;
      final harness = await _startRelay(
        SerlinkAppConnection(
          environment: const {},
          launchApp: () async => launches++,
        ),
      );
      await expectLater(
        harness.client.callTool(const CallToolRequest(name: 'unknown')),
        throwsA(isA<McpError>()),
      );
      final invalid = await harness.client.callTool(
        const CallToolRequest(name: 'serlink_open_session'),
      );
      expect(invalid.isError, isTrue);
      await expectLater(
        harness.client.request(
          JsonRpcRequest(id: 99, method: 'custom/probe'),
          EmptyResult.fromJson,
        ),
        throwsA(isA<McpError>()),
      );
      expect(launches, 0);
    });

    test(
      'connects to a running app only on a tool call and keeps identity',
      () async {
        final dir = await _tempDirectory();
        var connections = 0;
        var launches = 0;
        String? clientName;
        final server = await _startBackend(
          onConnect: () => connections++,
          callback: (args, extra, server) async {
            clientName =
                server.server.getClientVersion()?.name ??
                extra.clientInfo?.name;
            return CallToolResult.fromContent([TextContent(text: 'ok')]);
          },
        );
        final discovery = await _writeDiscovery(dir, server);
        final harness = await _startRelay(
          SerlinkAppConnection(
            environment: const {},
            discoveryArg: discovery,
            launchApp: () async => launches++,
          ),
        );
        final tools = await harness.client.listTools();
        await harness.client.ping();
        expect(connections, 0);
        final result = await harness.client.callTool(_listHosts);
        expect((result.content.single as TextContent).text, 'ok');
        expect(clientName, 'test-client');
        await harness.client.callTool(_listHosts);
        // Stateless HTTP creates a backend per request: one discovery and
        // two tool calls. A duplicate connection would add another discovery.
        expect(connections, 3);
        expect(launches, 0);
        // Catalog and backend use exactly the same tool definitions.
        final direct = McpClient(
          const Implementation(name: 'catalog-check', version: '1.0.0'),
          options: const McpClientOptions(protocol: McpProtocol.legacy),
        );
        addTearDown(direct.close);
        await direct.connect(
          StreamableHttpClientTransport(
            _serverUrl(server),
            opts: const StreamableHttpClientTransportOptions(
              requestInit: {
                'headers': {'authorization': 'Bearer relay-token'},
              },
            ),
          ),
        );
        expect(
          tools.tools.map((tool) => tool.toJson()).toList(),
          (await direct.listTools()).tools
              .map((tool) => tool.toJson())
              .toList(),
        );
      },
    );

    test(
      'concurrent cold calls launch once and find a new default candidate',
      () async {
        final dir = await _tempDirectory();
        final candidates = defaultDiscoveryCandidates({'HOME': dir.path});
        // A stale first candidate must not hide the newly written second path.
        await File(candidates.first).create(recursive: true);
        await File(candidates.first).writeAsString('{}');
        var launches = 0;
        var connections = 0;
        final harness = await _startRelay(
          SerlinkAppConnection(
            environment: {'HOME': dir.path},
            pollInterval: const Duration(milliseconds: 10),
            launchApp: () async {
              launches++;
              final server = await _startBackend(
                onConnect: () => connections++,
              );
              await _writeDiscovery(dir, server, path: candidates.last);
            },
          ),
        );
        final results = await Future.wait([
          harness.client.callTool(_listHosts),
          harness.client.callTool(_listHosts),
        ]);
        expect(results.every((result) => result.isError != true), isTrue);
        expect(launches, 1);
        // Stateless HTTP creates a backend per request: one discovery and
        // two tool calls. A duplicate connection would add another discovery.
        expect(connections, 3);
      },
    );

    test('preserves tool errors, result metadata and progress', () async {
      final dir = await _tempDirectory();
      Map<String, dynamic>? requestMeta;
      final server = await _startBackend(
        callback: (args, extra, server) async {
          requestMeta = extra.meta;
          await extra.sendNotification(
            JsonRpcNotification(
              method: Method.notificationsProgress,
              params: {
                'progressToken': extra.meta!['progressToken'],
                'progress': 1,
                'total': 2,
                'message': 'waiting',
              },
            ),
          );
          return const CallToolResult(
            content: [TextContent(text: 'vault_locked')],
            isError: true,
            meta: {'detail': 'locked'},
          );
        },
      );
      final harness = await _startRelay(
        SerlinkAppConnection(
          environment: const {},
          discoveryArg: await _writeDiscovery(dir, server),
        ),
      );
      final progress = <Progress>[];
      final result = await harness.client.request(
        JsonRpcRequest(
          id: 44,
          method: Method.toolsCall,
          params: {'name': 'serlink_list_hosts'},
          meta: {'progressToken': 'caller-progress', 'custom': 'preserved'},
        ),
        CallToolResult.fromJson,
        RequestOptions(onprogress: progress.add),
      );
      expect(result.isError, isTrue);
      expect((result.content.single as TextContent).text, 'vault_locked');
      expect(result.meta, containsPair('detail', 'locked'));
      expect(requestMeta?['custom'], 'preserved');
      expect(progress.single.message, 'waiting');
    });

    test(
      'failed launch is a tool error and a later call can recover',
      () async {
        final dir = await _tempDirectory();
        final path = '${dir.path}/mcp-server.json';
        var launches = 0;
        final harness = await _startRelay(
          SerlinkAppConnection(
            environment: const {},
            discoveryArg: path,
            launchApp: () async {
              launches++;
              throw StateError('app not installed');
            },
          ),
        );
        final result = await harness.client.callTool(_listHosts);
        expect(result.isError, isTrue);
        expect(
          (result.content.single as TextContent).text,
          contains('app_unavailable'),
        );
        await harness.client.ping();
        expect((await harness.client.listTools()).tools, hasLength(7));
        final server = await _startBackend();
        await _writeDiscovery(dir, server, path: path);
        expect((await harness.client.callTool(_listHosts)).isError, isFalse);
        expect(launches, 1);
      },
    );

    test('a missing app times out without terminating the helper', () async {
      final dir = await _tempDirectory();
      var launches = 0;
      final harness = await _startRelay(
        SerlinkAppConnection(
          environment: {'HOME': dir.path},
          timeout: const Duration(milliseconds: 100),
          pollInterval: const Duration(milliseconds: 10),
          launchApp: () async => launches++,
        ),
      );
      final result = await harness.client.callTool(_listHosts);
      expect(
        (result.content.single as TextContent).text,
        contains('connect_timeout'),
      );
      expect(launches, 1);
      await harness.client.ping();
    });

    test('wrong bearer token cannot reach tools', () async {
      final dir = await _tempDirectory();
      var calls = 0;
      final server = await _startBackend(
        callback: (args, extra, server) async {
          calls++;
          return CallToolResult.fromContent([]);
        },
      );
      final path = await _writeDiscovery(dir, server, token: 'wrong');
      final harness = await _startRelay(
        SerlinkAppConnection(
          environment: const {},
          discoveryArg: path,
          timeout: const Duration(milliseconds: 100),
          pollInterval: const Duration(milliseconds: 10),
          launchApp: () async {},
        ),
      );
      expect((await harness.client.callTool(_listHosts)).isError, isTrue);
      expect(calls, 0);
      await harness.client.ping();
    });

    test('backend loss does not replay tools or stop local probes', () async {
      final dir = await _tempDirectory();
      var launches = 0;
      final server = await _startBackend();
      final path = await _writeDiscovery(dir, server);
      final harness = await _startRelay(
        SerlinkAppConnection(
          environment: const {},
          discoveryArg: path,
          launchApp: () async => launches++,
        ),
      );
      await harness.client.callTool(_listHosts);
      await server.stop();
      await harness.client.ping();
      await harness.client.listTools();
      final result = await harness.client.callTool(_listHosts);
      expect(result.isError, isTrue);
      expect(
        (result.content.single as TextContent).text,
        contains('app_connection_lost'),
      );
      expect(launches, 0);
      final restarted = await _startBackend();
      await _writeDiscovery(dir, restarted, path: path);
      expect((await harness.client.callTool(_listHosts)).isError, isFalse);
    });

    test('client disconnect cancels polling while the app starts', () async {
      final dir = await _tempDirectory();
      final launched = Completer<void>();
      final launchGate = Completer<void>();
      final harness = await _startRelay(
        SerlinkAppConnection(
          environment: {'HOME': dir.path},
          launchApp: () async {
            launched.complete();
            await launchGate.future;
          },
        ),
      );
      final call = expectLater(
        harness.client.callTool(_listHosts),
        throwsA(isA<McpError>()),
      );
      await launched.future;
      await harness.client.close();
      await harness.relay.done.timeout(const Duration(seconds: 1));
      launchGate.complete();
      await call;
    });

    test(
      'cancellation notifications cannot cancel a backend request id',
      () async {
        final dir = await _tempDirectory();
        final entered = Completer<void>();
        final release = Completer<void>();
        final server = await _startBackend(
          callback: (args, extra, server) async {
            entered.complete();
            await release.future;
            expect(extra.signal.aborted, isFalse);
            return CallToolResult.fromContent([TextContent(text: 'finished')]);
          },
        );
        final harness = await _startRelay(
          SerlinkAppConnection(
            environment: const {},
            discoveryArg: await _writeDiscovery(dir, server),
          ),
        );
        final call = harness.client.callTool(_listHosts);
        await entered.future;
        await harness.client.notification(
          JsonRpcNotification(
            method: Method.notificationsCancelled,
            params: const {'requestId': 999, 'reason': 'probe'},
          ),
        );
        await harness.client.ping();
        release.complete();
        expect((await call).isError, isFalse);
      },
    );
  });

  group('SerlinkAppConnection', () {
    test(
      'a stalled HTTP handshake is bounded by the connect deadline',
      () async {
        final dir = await _tempDirectory();
        final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => http.close(force: true));
        final subscription = http.listen((_) {}); // Deliberately never respond.
        addTearDown(subscription.cancel);
        final path = '${dir.path}/mcp-server.json';
        await File(path).writeAsString(
          jsonEncode({
            'url': 'http://127.0.0.1:${http.port}/mcp',
            'token': 'unused',
          }),
        );
        var launches = 0;
        final connection = SerlinkAppConnection(
          environment: const {},
          discoveryArg: path,
          timeout: const Duration(milliseconds: 100),
          launchApp: () async => launches++,
        );
        addTearDown(connection.close);
        await expectLater(
          connection
              .connect(const Implementation(name: 'test', version: '1'))
              .timeout(const Duration(seconds: 2)),
          throwsA(
            isA<TimeoutException>().having(
              (e) => e.duration,
              'deadline',
              const Duration(milliseconds: 100),
            ),
          ),
        );
        expect(launches, 0);
      },
    );
  });
}

const _listHosts = CallToolRequest(name: 'serlink_list_hosts');

Future<Directory> _tempDirectory() async {
  final dir = await Directory.systemTemp.createTemp('serlink-mcp-test');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

Future<({McpClient client, SerlinkMcpRelay relay})> _startRelay(
  SerlinkAppConnection connection, {
  McpProtocol protocol = McpProtocol.legacy,
}) async {
  final pair = _MemoryTransport.pair();
  final relay = await SerlinkMcpRelay.start(
    clientSideTransport: pair.$1,
    connection: connection,
  );
  addTearDown(relay.close);
  final client = McpClient(
    const Implementation(name: 'test-client', version: '1.0.0'),
    options: McpClientOptions(protocol: protocol),
  );
  addTearDown(client.close);
  await client.connect(pair.$2);
  return (client: client, relay: relay);
}

Uri _serverUrl(McpServerTransport server) =>
    Uri.parse('http://127.0.0.1:${server.port}/mcp');

Future<String> _writeDiscovery(
  Directory dir,
  McpServerTransport server, {
  String? path,
  String token = 'relay-token',
}) async {
  final file = File(path ?? '${dir.path}/mcp-server.json');
  await file.create(recursive: true);
  await file.writeAsString(
    jsonEncode({'url': '${_serverUrl(server)}', 'token': token}),
  );
  return file.path;
}

Future<McpServerTransport> _startBackend({
  void Function()? onConnect,
  Future<CallToolResult> Function(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
    McpServer server,
  )?
  callback,
}) async {
  final transport = McpServerTransport(
    bearerToken: 'relay-token',
    serverFactory: (_) {
      onConnect?.call();
      final server = McpServer(
        const Implementation(name: 'serlink', version: '1.0.0'),
        options: const McpServerOptions(protocol: McpProtocol.stable),
      );
      for (final tool in serlinkMcpTools.values) {
        tool.register(
          server,
          callback: (args, extra) async => callback != null
              ? callback(args, extra, server)
              : CallToolResult.fromContent([TextContent(text: 'ok')]),
        );
      }
      return server;
    },
  );
  await transport.start();
  addTearDown(transport.stop);
  return transport;
}
