// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/ssh_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/core/logging/offline_diagnostic_logger.dart';
import 'package:serlink/core/security/secret_bytes.dart';
import 'package:serlink/features/ssh/data/dartssh2_ssh_session_service.dart';
import 'package:serlink/features/ssh/data/ssh_agent_client.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/identities/domain/identity_agent.dart';
import 'package:serlink/features/identities/application/ssh_key_pair_generator.dart';

void main() {
  test('builds password and keyboard-interactive auth material', () {
    final material = DartSsh2AuthMaterial.fromProfile(
      _profile([
        SshPasswordAuth(password: SecretBytes(utf8.encode('p@ss'))),
        SshKeyboardInteractiveAuth(
          responses: [SecretBytes(utf8.encode('otp'))],
        ),
      ]),
    );

    expect(material.password, 'p@ss');
    expect(material.keyboardInteractiveResponses, ['otp']);
    expect(material.identities, isEmpty);
  });

  test('builds OpenSSH certificate auth material', () {
    final keyPair = SSHKeyPair.fromPem(_legacyEcPrivateKey).single;
    final certificate = _certificateFor(keyPair);
    final material = DartSsh2AuthMaterial.fromProfile(
      _profile([
        SshOpenSshCertificateAuth(
          privateKeyPem: SecretBytes(utf8.encode(_legacyEcPrivateKey)),
          certificate: SecretBytes(utf8.encode(certificate)),
        ),
      ]),
    );

    expect(material.identities, hasLength(1));
    expect(
      material.identities.single.type,
      'ecdsa-sha2-nistp256-cert-v01@openssh.com',
    );
    expect(
      material.identities.single.toPublicKey().encode(),
      base64Decode(certificate.split(' ')[1]),
    );
  });

  test('rejects invalid OpenSSH certificate auth material', () {
    expect(
      () => DartSsh2AuthMaterial.fromProfile(
        _profile([
          SshOpenSshCertificateAuth(
            privateKeyPem: SecretBytes(utf8.encode(_legacyEcPrivateKey)),
            certificate: SecretBytes(utf8.encode('ssh-ed25519 bad')),
          ),
        ]),
      ),
      throwsA(
        isA<UnsupportedSshAuthException>().having(
          (error) => error.code,
          'code',
          'ssh_auth.certificate_invalid',
        ),
      ),
    );
  });

  test('builds SSH agent auth material from local agent identities', () async {
    final keyPair = SSHKeyPair.fromPem(_legacyEcPrivateKey).single;
    final agent = _FakeAgentClient([keyPair]);

    final material = DartSsh2AuthMaterial.fromProfile(
      _profile(const [SshAgentAuth()]),
      agentClient: agent,
    );

    expect(material.identities, hasLength(1));
    expect(material.identities.single.type, 'ecdsa-sha2-nistp256');
    final signature = await material.identities.single.sign(
      Uint8List.fromList([1, 2, 3]),
    );
    expect(signature.encode(), isNotEmpty);
    expect(agent.signRequests, 1);
  });

  test('rejects SSH agent auth when agent has no identities', () {
    expect(
      () => DartSsh2AuthMaterial.fromProfile(
        _profile(const [SshAgentAuth()]),
        agentClient: _FakeAgentClient(const []),
      ),
      throwsA(
        isA<UnsupportedSshAuthException>().having(
          (error) => error.code,
          'code',
          'ssh_auth.agent_empty',
        ),
      ),
    );
  });

  test(
    'selects an agent endpoint and offers only the configured public key',
    () async {
      final other = await const SshKeyPairGenerator().generate(
        GeneratedSshKeyType.ed25519,
      );
      final key = SSHKeyPair.fromPem(_legacyEcPrivateKey).single;
      final agent = _FakeAgentClient([
        SSHKeyPair.fromPem(other.privateKeyPem).single,
        key,
      ]);
      final material = DartSsh2AuthMaterial.fromAuthMethods([
        SshAgentAuth(
          agent: IdentityAgentConfig(
            socketPath: '/custom/agent.sock',
            publicKey:
                '${key.name} ${base64Encode(key.toPublicKey().encode())}',
          ),
        ),
      ], agentClient: agent);
      expect(material.identities, hasLength(1));
      expect(material.identities.single.shouldProbe, isTrue);
      expect(agent.lastSocketPath, '/custom/agent.sock');
      expect(agent.signRequests, 0);
      await material.identities.single.sign(Uint8List.fromList([1, 2, 3]));
      expect(agent.lastSocketPath, '/custom/agent.sock');
      expect(agent.signRequests, 1);
    },
  );

  test(
    'pairs a certificate with its matching agent key without a private key',
    () async {
      final key = SSHKeyPair.fromPem(_legacyEcPrivateKey).single;
      final certificate = _certificateFor(key);
      final agent = _FakeAgentClient([key]);
      final material = DartSsh2AuthMaterial.fromAuthMethods([
        SshOpenSshCertificateAuth(
          certificate: SecretBytes(utf8.encode(certificate)),
          agent: const IdentityAgentConfig(socketPath: '/external/agent.sock'),
        ),
      ], agentClient: agent);
      expect(material.identities.single.type, certificate.split(' ').first);
      expect(material.identities.single.shouldProbe, isTrue);
      expect(
        material.identities.single.toPublicKey().encode(),
        base64Decode(certificate.split(' ')[1]),
      );
      await material.identities.single.sign(Uint8List.fromList([4, 5, 6]));
      expect(agent.signRequests, 1);
      expect(agent.lastSocketPath, '/external/agent.sock');
    },
  );

  test('rejects a certificate whose key is missing from the agent', () async {
    final other = await const SshKeyPairGenerator().generate(
      GeneratedSshKeyType.ed25519,
    );
    final key = SSHKeyPair.fromPem(_legacyEcPrivateKey).single;
    expect(
      () => DartSsh2AuthMaterial.fromAuthMethods(
        [
          SshOpenSshCertificateAuth(
            certificate: SecretBytes(utf8.encode(_certificateFor(key))),
            agent: const IdentityAgentConfig(),
          ),
        ],
        agentClient: _FakeAgentClient(SSHKeyPair.fromPem(other.privateKeyPem)),
      ),
      throwsA(
        isA<UnsupportedSshAuthException>().having(
          (e) => e.code,
          'code',
          'ssh_auth.certificate_invalid',
        ),
      ),
    );
  });

  for (final algorithm in [
    'sk-ssh-ed25519@openssh.com',
    'sk-ecdsa-sha2-nistp256@openssh.com',
  ]) {
    test(
      'preserves $algorithm public keys and signatures from a hardware agent',
      () async {
        final blob = SSHMessageWriter()..writeUtf8(algorithm);
        if (algorithm.contains('ecdsa')) blob.writeUtf8('nistp256');
        blob.writeString(Uint8List(algorithm.contains('ecdsa') ? 65 : 32));
        blob.writeUtf8('ssh:');
        final signature = SSHMessageWriter()
          ..writeUtf8(algorithm)
          ..writeString(Uint8List(64))
          ..writeUint8(1)
          ..writeUint32(17);
        final encoded = signature.takeBytes();
        final agent = _HardwareAgent(blob.takeBytes(), encoded);
        final material = DartSsh2AuthMaterial.fromAuthMethods(const [
          SshHardwareKeyAuth(),
        ], agentClient: agent);
        expect(material.identities.single.type, algorithm);
        expect(material.identities.single.shouldProbe, isTrue);
        expect(
          (await material.identities.single.sign(Uint8List.fromList([1])))
              .encode(),
          encoded,
        );
      },
    );
  }

  test('rejects profiles with no supported auth methods', () {
    expect(
      () => DartSsh2AuthMaterial.fromProfile(_profile(const [])),
      throwsA(
        isA<UnsupportedSshAuthException>().having(
          (error) => error.code,
          'code',
          'ssh_auth.empty',
        ),
      ),
    );
  });

  test('local forwarding requires an active SSH session', () async {
    final service = DartSsh2SessionService();

    await expectLater(
      service.startLocalForward(
        sessionId: SessionId('missing-session'),
        localPort: 18080,
        remoteHost: '127.0.0.1',
        remotePort: 8080,
      ),
      throwsStateError,
    );
  });

  test(
    'logs connection failures without host user or secret details',
    () async {
      final logger = _CapturingDiagnosticLogger();
      final service = DartSsh2SessionService(
        socketFactory: (_, _, {timeout}) async {
          throw StateError('host=example.internal password=hunter2');
        },
        diagnosticLogger: logger,
      );

      await expectLater(
        service.testConnection(
          _profile([
            SshPasswordAuth(password: SecretBytes(utf8.encode('hunter2'))),
          ]),
        ),
        throwsStateError,
      );

      expect(logger.events.map((event) => event.event), [
        'ssh.connect.start',
        'ssh.connect.failure',
      ]);
      final serialized = jsonEncode([
        for (final event in logger.events) event.details,
      ]);
      expect(serialized, contains('password'));
      expect(serialized, contains('StateError'));
      expect(serialized, isNot(contains('example.internal')));
      expect(serialized, isNot(contains('ops')));
      expect(serialized, isNot(contains('hunter2')));
    },
  );

  test('remote forwarding requires an active SSH session', () async {
    final service = DartSsh2SessionService();

    await expectLater(
      service.startRemoteForward(
        sessionId: SessionId('missing-session'),
        bindHost: '127.0.0.1',
        bindPort: 18080,
        localHost: '127.0.0.1',
        localPort: 8080,
      ),
      throwsStateError,
    );
  });

  test(
    'a socket that closes before authentication never logs success',
    () async {
      final logger = _CapturingDiagnosticLogger();
      final socket = _ClosingSocket();
      final service = DartSsh2SessionService(
        socketFactory: (_, _, {timeout}) async => socket,
        diagnosticLogger: logger,
      );

      await expectLater(
        service.openShell(
          _profile([
            SshPasswordAuth(password: SecretBytes(utf8.encode('test-secret'))),
          ]),
        ),
        throwsA(isA<SSHAuthAbortError>()),
      );

      expect(logger.events.map((event) => event.event), [
        'ssh.connect.start',
        'ssh.transport.closed',
        'ssh.auth.summary',
        'ssh.connect.failure',
      ]);
      expect(
        logger.events.last.details,
        containsPair('stage', 'authentication'),
      );
      expect(
        logger.events.last.details,
        containsPair('code', 'ssh.authentication_aborted'),
      );
      expect(socket.closed, isTrue);
      final summary = logger.events
          .singleWhere((event) => event.event == 'ssh.auth.summary')
          .details;
      expect(summary, containsPair('authenticated', false));
      expect(summary, containsPair('signRequests', 0));
      expect(jsonEncode(summary), isNot(contains('test-secret')));
    },
  );

  test('dynamic forwarding requires an active SSH session', () async {
    final service = DartSsh2SessionService();

    await expectLater(
      service.startDynamicForward(
        sessionId: SessionId('missing-session'),
        bindHost: '127.0.0.1',
        bindPort: 1080,
      ),
      throwsStateError,
    );
  });

  test('stopping a missing local forward is a no-op', () async {
    final service = DartSsh2SessionService();

    await expectLater(
      service.stopLocalForward(sessionId: SessionId('missing-session')),
      completes,
    );
  });

  test('stopping missing remote and dynamic forwards is a no-op', () async {
    final service = DartSsh2SessionService();

    await expectLater(
      service.stopRemoteForward(sessionId: SessionId('missing-session')),
      completes,
    );
    await expectLater(
      service.stopDynamicForward(sessionId: SessionId('missing-session')),
      completes,
    );
  });
}

class _ClosingSocket implements SSHSocket {
  final _outgoing = StreamController<List<int>>();
  final _done = Completer<void>();
  bool closed = false;

  _ClosingSocket() {
    _outgoing.stream.listen((_) {});
  }

  @override
  Stream<Uint8List> get stream => const Stream.empty();
  @override
  StreamSink<List<int>> get sink => _outgoing.sink;
  @override
  Future<void> get done => _done.future;
  @override
  Future<void> close() async {
    if (!closed) {
      closed = true;
      _done.complete();
      await _outgoing.close();
    }
  }

  @override
  void destroy() => unawaited(close());
  @override
  Future<void> flush() async {}
}

ConnectionProfileSnapshot _profile(List<SshAuthMethod> authMethods) {
  return ConnectionProfileSnapshot(
    sessionId: SessionId('session-1'),
    hostId: HostId('host-1'),
    hostname: 'example.internal',
    port: 22,
    username: 'ops',
    authMethods: authMethods,
  );
}

const _legacyEcPrivateKey = '''
-----BEGIN EC PRIVATE KEY-----
MIIBaAIBAQQg7TXJD04t4e/CrwIdaxF1FJ+PSF0kTzMQs5TOp9L0MvKggfowgfcC
AQEwLAYHKoZIzj0BAQIhAP////8AAAABAAAAAAAAAAAAAAAA////////////////
MFsEIP////8AAAABAAAAAAAAAAAAAAAA///////////////8BCBaxjXYqjqT57Pr
vVV2mIa8ZR0GsMxTsPY7zjw+J9JgSwMVAMSdNgiG5wSTamZ44ROdJreBn36QBEEE
axfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpZP40Li/hp/m47n60p8D54W
K84zV2sxXs7LtkBoN79R9QIhAP////8AAAAA//////////+85vqtpxeehPO5ysL8
YyVRAgEBoUQDQgAEQ3EUZAOS4yK43BKX5gl1BPUWPN3CsU0xrptfxnItUD34jPc0
ybMM3pZ6HeBa89ariwVsl/wCYzZfgR64JAC1nQ==
-----END EC PRIVATE KEY-----
''';

class _FakeAgentClient implements SshAgentClient {
  _FakeAgentClient(List<SSHKeyPair> keyPairs) : _keyPairs = keyPairs;

  final List<SSHKeyPair> _keyPairs;
  int signRequests = 0;
  String? lastSocketPath;

  @override
  List<SshAgentIdentity> listIdentities({String? socketPath}) {
    lastSocketPath = socketPath;
    return [
      for (final keyPair in _keyPairs)
        SshAgentIdentity(
          publicKeyBlob: keyPair.toPublicKey().encode(),
          comment: 'test-key',
        ),
    ];
  }

  @override
  Uint8List sign({
    required Uint8List publicKeyBlob,
    required Uint8List data,
    required int flags,
    String? socketPath,
  }) {
    lastSocketPath = socketPath;
    signRequests += 1;
    final keyPair = _keyPairs.singleWhere(
      (candidate) =>
          _bytesEqual(candidate.toPublicKey().encode(), publicKeyBlob),
    );
    return keyPair.sign(data).encode();
  }
}

String _certificateFor(SSHKeyPair key) {
  final publicKey = key.toPublicKey().encode();
  final type = SSHMessageReader(publicKey).readUtf8();
  final writer = SSHMessageWriter()
    ..writeUtf8('$type-cert-v01@openssh.com')
    ..writeString(Uint8List(32))
    ..writeBytes(publicKey.sublist(4 + utf8.encode(type).length))
    ..writeUint64(1)
    ..writeUint32(1)
    ..writeUtf8('test-certificate')
    ..writeString(Uint8List(0))
    ..writeUint64(0)
    ..writeUint64(0x7fffffffffffffff)
    ..writeString(Uint8List(0))
    ..writeString(Uint8List(0))
    ..writeString(Uint8List(0))
    ..writeString(publicKey)
    ..writeString(Uint8List(0));
  return '$type-cert-v01@openssh.com ${base64Encode(writer.takeBytes())} test';
}

class _HardwareAgent implements SshAgentClient {
  _HardwareAgent(this.publicKey, this.signature);
  final Uint8List publicKey;
  final Uint8List signature;

  @override
  List<SshAgentIdentity> listIdentities({String? socketPath}) => [
    SshAgentIdentity(publicKeyBlob: publicKey, comment: 'hardware'),
  ];

  @override
  Uint8List sign({
    required Uint8List publicKeyBlob,
    required Uint8List data,
    required int flags,
    String? socketPath,
  }) => signature;
}

class _CapturedDiagnosticEvent {
  const _CapturedDiagnosticEvent({
    required this.event,
    required this.level,
    required this.details,
  });

  final String event;
  final DiagnosticLogLevel level;
  final Map<String, Object?> details;
}

class _CapturingDiagnosticLogger implements DiagnosticLogger {
  final events = <_CapturedDiagnosticEvent>[];

  @override
  Future<void> record(
    String event, {
    DiagnosticLogLevel level = DiagnosticLogLevel.info,
    Map<String, Object?> details = const {},
  }) async {
    events.add(
      _CapturedDiagnosticEvent(
        event: event,
        level: level,
        details: Map<String, Object?>.unmodifiable(details),
      ),
    );
  }
}

bool _bytesEqual(Uint8List left, Uint8List right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
