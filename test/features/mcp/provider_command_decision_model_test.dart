import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/data/provider_command_decision_model.dart';
import 'package:serlink/features/mcp/domain/command_decision.dart';

void main() {
  for (final provider in CommandDecisionProvider.values) {
    test('$provider uses its documented wire format and auth', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final local = Uri.parse('http://127.0.0.1:${server.port}/v1/systemone');
      final client = _Client(local);
      final connection = CommandDecisionConnection(
        provider: provider,
        accountId: provider == CommandDecisionProvider.cloudflare
            ? 'a' * 32
            : '',
        endpoint: provider == CommandDecisionProvider.local
            ? local.toString()
            : '',
      );
      final handled = server.first.then((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(
          request.headers.value('authorization'),
          provider == CommandDecisionProvider.gemini ||
                  provider == CommandDecisionProvider.local
              ? null
              : 'Bearer fixture-key',
        );
        expect(
          request.headers.value('x-goog-api-key'),
          provider == CommandDecisionProvider.gemini ? 'fixture-key' : null,
        );
        if (provider == CommandDecisionProvider.gemini) {
          expect(body.containsKey('state'), isFalse);
          expect(
            ((body['questions'] as Map)['command_risk'] as Map)['instructions'],
            isA<String>(),
          );
          expect(jsonDecode(body['input'] as String), {'command': 'ls -la'});
        } else {
          expect(body['state'], {'command': 'ls -la'});
        }
        expect(body['model'], provider.defaultModel);
        expect((body['questions'] as Map).keys, ['command_risk']);
        final response = _response()..['model'] = provider.defaultModel;
        if (provider == CommandDecisionProvider.gemini) {
          response.remove('model');
        }
        request.response.write(
          jsonEncode(
            provider == CommandDecisionProvider.cloudflare
                ? {'success': true, 'errors': <Object?>[], 'result': response}
                : response,
          ),
        );
        await request.response.close();
      });
      final model = ProviderCommandDecisionModel(clientFactory: () => client);
      expect(
        await model.assess(
          command: 'ls -la',
          model: provider.defaultModel,
          apiKey: provider == CommandDecisionProvider.local
              ? ''
              : 'fixture-key',
          connection: connection,
        ),
        CommandDecision.safe,
      );
      await handled;
      expect(client.requested.toString(), switch (provider) {
        CommandDecisionProvider.typesafe =>
          'https://api.typesafe.ai/v1/systemone',
        CommandDecisionProvider.gemini =>
          'https://generativelanguage.googleapis.com/v1beta/decisions',
        CommandDecisionProvider.cloudflare =>
          'https://api.cloudflare.com/client/v4/accounts/${'a' * 32}/ai/run/@cf/cloudflare/clef',
        CommandDecisionProvider.local => local.toString(),
      });
      expect(client.closed, isTrue);
    });
  }

  test(
    'local service works over real HTTP with an optional bearer token',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final handled = server.first.then((request) async {
        expect(request.uri.path, '/custom/inference');
        expect(request.headers.value('authorization'), 'Bearer local-token');
        await request.drain<void>();
        request.response.write(jsonEncode(_response()));
        await request.response.close();
      });
      expect(
        await ProviderCommandDecisionModel().assess(
          command: 'ls',
          model: 'clef',
          apiKey: 'local-token',
          connection: CommandDecisionConnection(
            provider: CommandDecisionProvider.local,
            endpoint: 'http://127.0.0.1:${server.port}/custom/inference',
          ),
        ),
        CommandDecision.safe,
      );
      await handled;
    },
  );

  for (final body in [
    {'success': false, 'result': _response()},
    {
      'success': true,
      'errors': [
        {'message': 'fixture-key'},
      ],
      'result': _response(),
    },
    {'success': true, 'result': <String, Object?>{}},
    _response(),
  ]) {
    test(
      'Cloudflare errors or invalid envelopes never authorize a command $body',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          await request.drain<void>();
          request.response.write(jsonEncode(body));
          await request.response.close();
        });
        final client = _Client(Uri.parse('http://127.0.0.1:${server.port}'));
        await expectLater(
          ProviderCommandDecisionModel(clientFactory: () => client).assess(
            command: 'ls',
            model: 'clef',
            apiKey: 'fixture-key',
            connection: CommandDecisionConnection(
              provider: CommandDecisionProvider.cloudflare,
              accountId: 'a' * 32,
            ),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'sanitized',
              'decision_provider_unavailable',
            ),
          ),
        );
        expect(client.closed, isTrue);
      },
    );
  }

  for (final endpoint in [
    'file:///tmp/model',
    'http://user:pass@localhost/run',
    'https://localhost/run?key=secret',
    'https://localhost/run#fragment',
    'localhost:8000',
    'http://',
  ]) {
    test(
      'reject invalid self-hosted endpoint $endpoint before network IO',
      () async {
        final client = _Client(Uri.parse('http://127.0.0.1:1'));
        await expectLater(
          ProviderCommandDecisionModel(clientFactory: () => client).assess(
            command: 'ls',
            model: 'clef',
            apiKey: '',
            connection: CommandDecisionConnection(
              provider: CommandDecisionProvider.local,
              endpoint: endpoint,
            ),
          ),
          throwsFormatException,
        );
        expect(client.requested, isNull);
        expect(client.closed, isTrue);
      },
    );
  }
}

Map<String, Object?> _response({
  String choice = 'safe',
  double safe = 1,
  double dangerous = 0,
  double uncertain = 0,
  double confidence = 1,
}) => {
  'model': 'jev-1.13.0',
  'answers': {
    'command_risk': {
      'type': 'choice',
      'choice': choice,
      'confidence': confidence,
      'probabilities': {
        'safe': safe,
        'dangerous': dangerous,
        'uncertain': uncertain,
      },
    },
  },
};

/// Route the real HTTP client to a local fixture; production has no endpoint override.
class _Client implements HttpClient {
  _Client(this.local);
  final Uri local;
  final HttpClient delegate = HttpClient();
  Uri? requested;
  bool closed = false;
  @override
  set connectionTimeout(Duration? timeout) =>
      delegate.connectionTimeout = timeout;
  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    requested = url;
    return delegate.postUrl(local);
  }

  @override
  void close({bool force = false}) {
    closed = true;
    delegate.close(force: force);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
