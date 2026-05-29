import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/core/security/secret_bytes.dart';
import 'package:serlink/features/ssh/data/dartssh2_ssh_session_service.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';

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
    final material = DartSsh2AuthMaterial.fromProfile(
      _profile([
        SshOpenSshCertificateAuth(
          privateKeyPem: SecretBytes(utf8.encode(_legacyEcPrivateKey)),
          certificate: SecretBytes(
            utf8.encode(
              'ecdsa-sha2-nistp256-cert-v01@openssh.com '
              'aGVsbG8= deploy@example',
            ),
          ),
        ),
      ]),
    );

    expect(material.identities, hasLength(1));
    expect(
      material.identities.single.type,
      'ecdsa-sha2-nistp256-cert-v01@openssh.com',
    );
    expect(
      utf8.decode(material.identities.single.toPublicKey().encode()),
      ['hello'].join(),
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

  test('rejects unsupported auth methods before opening a socket', () {
    expect(
      () => DartSsh2AuthMaterial.fromProfile(_profile(const [SshAgentAuth()])),
      throwsA(
        isA<UnsupportedSshAuthException>().having(
          (error) => error.code,
          'code',
          'ssh_auth.agent_unsupported',
        ),
      ),
    );
  });

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
