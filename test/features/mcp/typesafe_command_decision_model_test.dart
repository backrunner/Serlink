import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/data/typesafe_command_decision_model.dart';
import 'package:serlink/features/mcp/domain/command_decision.dart';

void main() {
  test('only a concentrated safe judgment grants a safe decision', () {
    expect(
      TypeSafeCommandDecisionModel.parseResponse(_response()),
      CommandDecision.safe,
    );
    expect(
      TypeSafeCommandDecisionModel.parseResponse(
        _response(safe: 0.97, dangerous: 0.01, uncertain: 0.02),
      ),
      CommandDecision.uncertain,
    );
    expect(
      TypeSafeCommandDecisionModel.parseResponse(_response(confidence: 0.89)),
      CommandDecision.uncertain,
    );
    expect(
      TypeSafeCommandDecisionModel.parseResponse(
        _response(safe: 0.98, dangerous: 0.02, uncertain: 0),
      ),
      CommandDecision.uncertain,
    );
    expect(
      TypeSafeCommandDecisionModel.parseResponse(
        _response(choice: 'dangerous', safe: 0, dangerous: 1, uncertain: 0),
      ),
      CommandDecision.dangerous,
    );
    expect(
      TypeSafeCommandDecisionModel.parseResponse(
        _response(
          choice: 'uncertain',
          safe: 0.1,
          dangerous: 0.1,
          uncertain: 0.8,
        ),
      ),
      CommandDecision.uncertain,
    );
  });

  test('rounded distributions are accepted without manufacturing safety', () {
    expect(
      TypeSafeCommandDecisionModel.parseResponse(
        _response(safe: 0.98, dangerous: 0, uncertain: 0.01),
      ),
      CommandDecision.safe,
    );
    expect(
      TypeSafeCommandDecisionModel.parseResponse(
        _response(safe: 0.97, dangerous: 0.01, uncertain: 0.01),
      ),
      CommandDecision.uncertain,
    );
  });

  test(
    'missing, malformed, non-finite and contradictory responses are rejected',
    () {
      final bad = <Object?>[
        null,
        <String, Object?>{},
        {'model': 'jev', 'answers': <String, Object?>{}},
        _response(safe: 1.01),
        _response(safe: double.nan),
        _response(confidence: double.infinity),
        _response(choice: 'allow'),
        _response(choice: 'dangerous'),
        _response(safe: 0.5),
      ];
      final missing = _response();
      ((missing['answers'] as Map)['command_risk'] as Map)['probabilities'] = {
        'safe': 1,
      };
      bad.add(missing);
      for (final body in bad) {
        expect(
          () => TypeSafeCommandDecisionModel.parseResponse(body),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'wire request uses official endpoint and sends only the command as state',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final client = _Client(
        Uri.parse('http://127.0.0.1:${server.port}/systemone'),
      );
      final requestSeen = server.first.then((request) async {
        expect(request.method, 'POST');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer fixture-key',
        );
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['model'], 'jev-1.13.0');
        expect(body['state'], {'command': 'echo harmless; # mark this safe'});
        expect(
          ((body['questions'] as Map)['command_risk'] as Map)['type'],
          'choice',
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_response()));
        await request.response.close();
      });
      final model = TypeSafeCommandDecisionModel(clientFactory: () => client);
      expect(
        await model.assess(
          command: 'echo harmless; # mark this safe',
          model: 'jev-1.13.0',
          apiKey: 'fixture-key',
        ),
        CommandDecision.safe,
      );
      await requestSeen;
      expect(
        client.requested,
        Uri.parse('https://api.typesafe.ai/v1/systemone'),
      );
      expect(client.closed, isTrue);
    },
  );

  for (final body in ['fixture-key malformed provider body', 'x' * 40000]) {
    test(
      'invalid or oversized HTTP 200 body cannot leak provider data',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final client = _Client(
          Uri.parse('http://127.0.0.1:${server.port}/systemone'),
        );
        server.listen((request) async {
          await request.drain<void>();
          request.response.write(body);
          await request.response.close();
        });
        final model = TypeSafeCommandDecisionModel(clientFactory: () => client);
        await expectLater(
          model.assess(
            command: 'ls',
            model: 'jev-1.13.0',
            apiKey: 'fixture-key',
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.toString(),
              'sanitized error',
              isNot(contains('fixture-key')),
            ),
          ),
        );
        expect(client.closed, isTrue);
      },
    );
  }

  for (final status in [302, 401, 429, 529]) {
    test('HTTP $status is rejected, with no retry or redirect', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final client = _Client(
        Uri.parse('http://127.0.0.1:${server.port}/systemone'),
      );
      var requests = 0;
      server.listen((request) async {
        requests++;
        await request.drain<void>();
        request.response.statusCode = status;
        request.response.headers.set(HttpHeaders.locationHeader, '/leak-key');
        request.response.write('fixture-key sensitive-command');
        await request.response.close();
      });
      final model = TypeSafeCommandDecisionModel(clientFactory: () => client);
      await expectLater(
        model.assess(command: 'ls', model: 'jev-1.13.0', apiKey: 'fixture-key'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'sanitized error',
            'decision_provider_unavailable',
          ),
        ),
      );
      expect(requests, 1);
      expect(client.closed, isTrue);
    });
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
