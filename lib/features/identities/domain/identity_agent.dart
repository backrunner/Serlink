/// Public configuration for any agent implementing the SSH agent protocol.
/// A missing endpoint uses the local system agent. No private key is stored.
class IdentityAgentConfig {
  const IdentityAgentConfig({this.socketPath, this.publicKey});

  final String? socketPath;
  final String? publicKey;

  Map<String, Object?> toJson() => {
    'socketPath': socketPath,
    'publicKey': publicKey,
  };

  factory IdentityAgentConfig.fromJson(Map<String, Object?> json) =>
      IdentityAgentConfig(
        socketPath: json['socketPath'] as String?,
        publicKey: json['publicKey'] as String?,
      );
}
