import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/identities/application/ssh_key_pair_generator.dart';

void main() {
  const generator = SshKeyPairGenerator();

  for (final type in GeneratedSshKeyType.values) {
    test('generates a valid $type key pair', () async {
      final generated = await generator.generate(type, comment: 'serlink');

      final parsed = SSHKeyPair.fromPem(generated.privateKeyPem);
      expect(parsed, hasLength(1));
      final pair = parsed.single;
      final expectedType = switch (type) {
        GeneratedSshKeyType.ed25519 => 'ssh-ed25519',
        GeneratedSshKeyType.rsa3072 => 'ssh-rsa',
      };
      expect(pair.name, expectedType);

      final publicParts = generated.publicKey.split(' ');
      expect(publicParts[0], expectedType);
      expect(publicParts[2], 'serlink');
      expect(
        base64.decode(publicParts[1]),
        pair.toPublicKey().encode(),
      );

      expect(generated.fingerprint, startsWith('SHA256:'));
      expect(generated.fingerprint.length, greaterThan('SHA256:'.length + 40));
      expect(generated.fingerprint, isNot(contains('=')));
    });
  }

  test('omits the comment from the public key line when empty', () async {
    final generated = await generator.generate(GeneratedSshKeyType.ed25519);
    expect(generated.publicKey.split(' '), hasLength(2));
  });
}
