import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../../../app/app_dependencies.dart';
import '../data/ssh_agent_client.dart';
import '../data/ssh_agent_discovery.dart';

export '../data/ssh_agent_discovery.dart'
    show DiscoveredSshAgent, sshAgentProviderHint;

class SshAgentIdentityChoice {
  const SshAgentIdentityChoice({
    required this.label,
    required this.fingerprint,
    required this.publicKey,
    this.socketPath,
  });

  final String label;
  final String fingerprint;
  final String publicKey;
  final String? socketPath;
}

typedef SshAgentIdentityLoader = Future<List<SshAgentIdentityChoice>> Function(
  String? socketPath,
);

final sshAgentIdentityLoaderProvider = Provider<SshAgentIdentityLoader>(
  (ref) => loadSshAgentIdentities,
);

typedef SshAgentEndpointLoader = Future<List<DiscoveredSshAgent>> Function();
final sshAgentEndpointLoaderProvider = Provider<SshAgentEndpointLoader>(
  (ref) =>
      () =>
          SshAgentDiscovery(logger: ref.read(offlineDiagnosticLoggerProvider))
              .discover(),
);

/// Derive the display fingerprint locally, including when reopening a saved
/// selection. Invalid or incomplete manual input has no display fingerprint.
String? sshAgentPublicKeyFingerprint(String publicKey) {
  final parts = publicKey.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return null;
  try {
    final blob = base64Decode(parts[1]);
    if (blob.isEmpty) return null;
    return 'SHA256:${base64Encode(SHA256Digest().process(blob)).replaceAll('=', '')}';
  } on FormatException {
    return null;
  }
}

/// Public identities stay inside the application. The picker exposes labels
/// and fingerprints; it never requests signatures or exports private keys.
Future<List<SshAgentIdentityChoice>> loadSshAgentIdentities(
  String? socketPath,
) async {
  final explicit = socketPath?.trim();
  final endpoints = explicit == null || explicit.isEmpty
      ? await SshAgentDiscovery().discover()
      : [
          DiscoveredSshAgent(
            socketPath: SshAgentSocketPathResolver.resolve(
              socketPath: explicit,
            )!,
            identities: await querySshAgentIdentities(
              SshAgentSocketPathResolver.resolve(socketPath: explicit)!,
            ),
          ),
        ];
  return [
    for (final endpoint in endpoints)
      for (final identity in endpoint.identities)
        SshAgentIdentityChoice(
          socketPath: endpoint.socketPath,
          label: identity.comment.trim().isEmpty
              ? identity.keyType
              : identity.comment.trim(),
          fingerprint:
              'SHA256:${base64Encode(SHA256Digest().process(identity.publicKeyBlob)).replaceAll('=', '')}',
          publicKey:
              '${identity.keyType} ${base64Encode(identity.publicKeyBlob)} ${identity.comment.replaceAll(RegExp(r'[\r\n]'), ' ')}'
                  .trim(),
        ),
  ];
}
