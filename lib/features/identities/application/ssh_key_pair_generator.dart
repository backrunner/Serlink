import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Ed25519;
import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/export.dart'
    show
        FortunaRandom,
        KeyParameter,
        ParametersWithRandom,
        RSAKeyGenerator,
        RSAKeyGeneratorParameters,
        SHA256Digest;

enum GeneratedSshKeyType { ed25519, rsa3072 }

class GeneratedSshKeyPair {
  const GeneratedSshKeyPair({
    required this.type,
    required this.privateKeyPem,
    required this.publicKey,
    required this.fingerprint,
  });

  final GeneratedSshKeyType type;

  /// Unencrypted OpenSSH private key PEM. Serlink keeps this encrypted in the
  /// vault; it is never meant to leave the device.
  final String privateKeyPem;

  /// OpenSSH authorized_keys line (`<type> <base64> <comment>`).
  final String publicKey;

  /// OpenSSH-style `SHA256:...` fingerprint of the public key.
  final String fingerprint;
}

class SshKeyPairGenerator {
  const SshKeyPairGenerator();

  static const int rsaBits = 3072;

  Future<GeneratedSshKeyPair> generate(
    GeneratedSshKeyType type, {
    String comment = '',
  }) async {
    return switch (type) {
      GeneratedSshKeyType.ed25519 => _generateEd25519(comment),
      GeneratedSshKeyType.rsa3072 => _generateRsa(comment),
    };
  }

  Future<GeneratedSshKeyPair> _generateEd25519(String comment) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    final publicKey = Uint8List.fromList(
      (await keyPair.extractPublicKey()).bytes,
    );
    // OpenSSH stores the Ed25519 private key as seed concatenated with the
    // public key (64 bytes).
    final privateKey = Uint8List.fromList([...seed, ...publicKey]);
    return _finish(
      OpenSSHEd25519KeyPair(publicKey, privateKey, comment),
      comment,
      GeneratedSshKeyType.ed25519,
    );
  }

  Future<GeneratedSshKeyPair> _generateRsa(String comment) async {
    final random = Random.secure();
    final seed = Uint8List.fromList([
      for (var index = 0; index < 32; index += 1) random.nextInt(256),
    ]);
    final fortuna = FortunaRandom()..seed(KeyParameter(seed));
    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), rsaBits, 64),
          fortuna,
        ),
      );
    final pair = generator.generateKeyPair();
    final publicKey = pair.publicKey;
    final privateKey = pair.privateKey;
    return _finish(
      OpenSSHRsaKeyPair(
        publicKey.modulus!,
        publicKey.publicExponent!,
        privateKey.privateExponent!,
        privateKey.q!.modInverse(privateKey.p!),
        privateKey.p!,
        privateKey.q!,
        comment,
      ),
      comment,
      GeneratedSshKeyType.rsa3072,
    );
  }

  GeneratedSshKeyPair _finish(
    OpenSSHKeyPair keyPair,
    String comment,
    GeneratedSshKeyType type,
  ) {
    final publicKeyBytes = keyPair.toPublicKey().encode();
    final publicKeyLine = comment.isEmpty
        ? '${keyPair.name} ${base64.encode(publicKeyBytes)}'
        : '${keyPair.name} ${base64.encode(publicKeyBytes)} $comment';
    final digest = SHA256Digest().process(publicKeyBytes);
    final fingerprint = 'SHA256:${base64.encode(digest).replaceAll('=', '')}';
    return GeneratedSshKeyPair(
      type: type,
      privateKeyPem: keyPair.toPem(),
      publicKey: publicKeyLine,
      fingerprint: fingerprint,
    );
  }
}
